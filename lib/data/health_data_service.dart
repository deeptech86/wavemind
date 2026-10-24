import 'dart:io' show Platform;

import 'package:health/health.dart';

/// Platform availability of a phone-level health store.
enum HealthAvailability {
  /// A usable health store is present (HealthKit on iOS, Health Connect on
  /// Android) and can be queried.
  available,

  /// Android only: Health Connect is missing or needs a provider update. The
  /// user should be sent to the Play Store via [HealthDataService.installHealthStore].
  needsInstall,

  /// No health store exists on this platform (e.g. desktop/web). The feature
  /// should be hidden rather than surfaced as an error.
  unsupported,
}

/// A single live read of smartwatch-sourced health metrics.
///
/// This is a throwaway, in-memory value object. It is NEVER written to a
/// database, repository, cache, or backend — by design. Each field is nullable
/// so the UI can distinguish "fetched: no data" from "not fetched yet".
class HealthSnapshot {
  const HealthSnapshot({this.steps, this.sleep, this.restingHeartRate});

  /// Today's cumulative step count, or null if unavailable.
  final int? steps;

  /// Last night's total time asleep, or null if unavailable.
  final Duration? sleep;

  /// Most recent resting/heart-rate reading in bpm (stretch metric), or null.
  final int? restingHeartRate;

  bool get hasAnyData =>
      steps != null || sleep != null || restingHeartRate != null;
}

/// A deliberately stateless, read-only wrapper over the `health` package.
///
/// It intentionally does NOT follow the repository/caching pattern used by
/// [WellnessRepository]. There is no local field holding health values, no
/// persistence, and no backend call anywhere in this file. Every metric is
/// fetched live from the platform health store on demand and handed straight
/// to in-memory widget state, where it disappears on navigation / restart.
///
/// This privacy posture is a client requirement, not an implementation detail
/// to "optimize" later with a cache.
class HealthDataService {
  HealthDataService({Health? health}) : _health = health ?? Health();

  final Health _health;

  /// Read-only set of metrics TideWell surfaces. Steps and sleep are the core
  /// ask; heart rate is a trivial stretch add via the same permission grant.
  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.HEART_RATE,
  ];

  /// READ access only for every type — TideWell never requests WRITE.
  static final List<HealthDataAccess> _permissions = List.filled(
    _types.length,
    HealthDataAccess.READ,
  );

  bool _configured = false;

  /// Lazily runs the one-time plugin [Health.configure] before any call that
  /// touches the platform channel.
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Reports whether a usable health store exists on this device.
  Future<HealthAvailability> availability() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return HealthAvailability.unsupported;
    }
    await _ensureConfigured();
    if (Platform.isIOS) return HealthAvailability.available;

    // Android: inspect the Health Connect SDK status.
    final status = await _health.getHealthConnectSdkStatus();
    return switch (status) {
      HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        HealthAvailability.needsInstall,
      HealthConnectSdkStatus.sdkUnavailable => HealthAvailability.needsInstall,
      null => HealthAvailability.needsInstall,
    };
  }

  /// True if all requested READ permissions are already granted. May return
  /// null on iOS, where the system deliberately hides read-authorization state.
  Future<bool?> hasPermissions() async {
    await _ensureConfigured();
    return _health.hasPermissions(_types, permissions: _permissions);
  }

  /// Triggers the platform permission dialog. Returns true if access was
  /// granted. Safe to call repeatedly.
  Future<bool> requestPermissions() async {
    await _ensureConfigured();
    return _health.requestAuthorization(_types, permissions: _permissions);
  }

  /// Android only: sends the user to the Play Store to install/update Health
  /// Connect. A no-op on other platforms.
  Future<void> installHealthStore() async {
    if (!Platform.isAndroid) return;
    await _ensureConfigured();
    await _health.installHealthConnect();
  }

  /// Fetches a fresh snapshot of today's steps, last night's sleep, and the
  /// latest heart rate. Any individual metric that fails or is missing comes
  /// back null rather than throwing, so a partial read still renders.
  Future<HealthSnapshot> readToday({DateTime? now}) async {
    await _ensureConfigured();
    final reference = now ?? DateTime.now();

    final steps = await _readTodaySteps(reference);
    final sleep = await _readLastNightSleep(reference);
    final heartRate = await _readLatestHeartRate(reference);

    return HealthSnapshot(
      steps: steps,
      sleep: sleep,
      restingHeartRate: heartRate,
    );
  }

  Future<int?> _readTodaySteps(DateTime reference) async {
    final startOfDay = DateTime(reference.year, reference.month, reference.day);
    try {
      return await _health.getTotalStepsInInterval(startOfDay, reference);
    } catch (_) {
      return null;
    }
  }

  Future<Duration?> _readLastNightSleep(DateTime reference) async {
    // Look back 24h and total the "asleep" intervals. This covers last night's
    // main sleep without needing a detailed stage breakdown.
    final from = reference.subtract(const Duration(hours: 24));
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.SLEEP_ASLEEP],
        startTime: from,
        endTime: reference,
      );
      if (points.isEmpty) return null;
      var total = Duration.zero;
      for (final p in points) {
        total += p.dateTo.difference(p.dateFrom);
      }
      return total == Duration.zero ? null : total;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _readLatestHeartRate(DateTime reference) async {
    final from = reference.subtract(const Duration(hours: 24));
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: from,
        endTime: reference,
      );
      if (points.isEmpty) return null;
      // Most-recent reading wins.
      points.sort((a, b) => a.dateTo.compareTo(b.dateTo));
      final value = points.last.value;
      if (value is NumericHealthValue) {
        return value.numericValue.round();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Converts a live [HealthSnapshot] into Fleet Knots points for a manual
  /// sync. Pure function (no platform channel), exposed for unit testing.
  ///
  /// Formula (client sample: "1000 steps = 100 points, 8 hours sleep = 100
  /// points"), applied as consistent floor-blocks so partial blocks don't
  /// count:
  ///   stepsPoints = (steps ~/ 1000) * 100
  ///   sleepPoints = (sleepMinutes ~/ 480) * 100   // 480 min == 8h
  ///   total       = stepsPoints + sleepPoints
  ///
  /// A null/missing metric contributes 0 rather than erroring.
  static int pointsForSync(HealthSnapshot snapshot) {
    final steps = snapshot.steps ?? 0;
    final sleepMinutes = snapshot.sleep?.inMinutes ?? 0;
    final stepsPoints = (steps ~/ 1000) * 100;
    final sleepPoints = (sleepMinutes ~/ 480) * 100;
    return stepsPoints + sleepPoints;
  }

  /// Formats a sleep [Duration] as a compact "7h 42m" label. Pure function,
  /// exposed for unit testing (no platform channel involved).
  static String formatSleepDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}
