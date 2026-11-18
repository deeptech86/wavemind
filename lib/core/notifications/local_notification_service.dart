import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../screens/home_dashboard_screen.dart'
    show daysRemainingInChallengeWeek;
import 'notification_service.dart';

/// On-device scheduled notifications — no server involvement. Every reminder
/// is scheduled against the device's own timezone (via `flutter_timezone`),
/// so each sailor sees 7am/9am/noon/3pm in *their* actual local time with no
/// backend changes needed.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'wavemind_reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription =
      'Daily meditation, mood check-in, and challenge reminders.';

  // Stable ids so re-scheduling overwrites rather than duplicates.
  static const _idMeditation = 1;
  static const _idMoodMorning = 2;
  static const _idMoodMidday = 3;
  static const _idCompetitionBase = 100; // + DateTime.weekday (1..7)
  static const _idSignupWelcome = 999;
  // Separate ids for the debug preview below, so it never collides with (or
  // overwrites) a real scheduled reminder.
  static const _idPreviewBase = 2000;

  /// The three fixed-content daily reminders — single source of truth for
  /// both [scheduleDailyReminders] and [previewAll].
  static const _dailyReminders = [
    (
      id: _idMeditation,
      hour: 7,
      minute: 0,
      title: 'Morning calm',
      body: 'A few minutes of guided breathing before the day gets loud.',
      target: NotificationTarget.meditation,
    ),
    (
      id: _idMoodMorning,
      hour: 9,
      minute: 0,
      title: 'How are you feeling?',
      body: 'Log your morning mood in the crew journal.',
      target: NotificationTarget.moodCheckIn,
    ),
    (
      id: _idMoodMidday,
      hour: 12,
      minute: 0,
      title: 'Midday check-in',
      body: "A quick pulse check — how's the voyage going so far today?",
      target: NotificationTarget.moodCheckIn,
    ),
  ];

  bool _tzReady = false;

  Future<void> _ensureTimezone() async {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
    _tzReady = true;
  }

  @override
  Future<void> initialize({
    void Function(NotificationTarget target)? onNotificationTap,
  }) async {
    await _ensureTimezone();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: (details) {
        final target = _targetFromPayload(details.payload);
        if (target != null) onNotificationTap?.call(target);
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final target = _targetFromPayload(
        launchDetails!.notificationResponse?.payload,
      );
      if (target != null) onNotificationTap?.call(target);
    }

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
      ),
    );
  }

  NotificationTarget? _targetFromPayload(String? payload) {
    for (final target in NotificationTarget.values) {
      if (target.name == payload) return target;
    }
    return null;
  }

  @override
  Future<bool> requestPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      return await androidImpl.requestNotificationsPermission() ?? false;
    }
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosImpl != null) {
      return await iosImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> showSignupWelcome() async {
    await _ensureTimezone();
    await _plugin.show(
      _idSignupWelcome,
      'Welcome aboard, sailor!',
      "Your crew log is ready — we'll check in with gentle reminders along "
          'the way.',
      _details,
    );
  }

  @override
  Future<void> scheduleDailyReminders() async {
    await _ensureTimezone();
    for (final r in _dailyReminders) {
      await _scheduleDaily(
        id: r.id,
        hour: r.hour,
        minute: r.minute,
        title: r.title,
        body: r.body,
        target: r.target,
      );
    }
    await _scheduleCompetitionCountdown();
  }

  /// Fires every reminder immediately (via `.show()`, not scheduling) so
  /// their content/formatting can be previewed on-device without waiting for
  /// the real trigger times. Debug/QA utility — not part of the
  /// [NotificationService] interface since it's local-notification-specific.
  Future<void> previewAll() async {
    await _ensureTimezone();
    var id = _idPreviewBase;
    for (final r in _dailyReminders) {
      await _plugin.show(
        id++,
        r.title,
        r.body,
        _details,
        payload: r.target.name,
      );
    }
    final daysLeft = daysRemainingInChallengeWeek();
    await _plugin.show(
      id++,
      _competitionTitle(daysLeft),
      _competitionBody,
      _details,
      payload: NotificationTarget.competition.name,
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required NotificationTarget target,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOf(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // iOS-only legacy param (unused by the AndroidFlutterLocalNotifications
      // path this app runs on today); `absoluteTime` is the documented
      // correct value for a zoned DateTime like ours.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: target.name,
    );
  }

  /// Schedules one 3pm countdown notification per day over the next week,
  /// each with that day's actual "N days left" count baked into the text —
  /// a single repeating daily schedule can't vary its content per day, so
  /// this reschedules a rolling week of one-off notifications instead.
  /// Date-based (not state-based), so it self-corrects across week
  /// boundaries; calling it again later just overwrites the same 7 ids.
  Future<void> _scheduleCompetitionCountdown() async {
    final now = tz.TZDateTime.now(tz.local);
    for (var offset = 0; offset < 7; offset++) {
      final day = now.add(Duration(days: offset));
      final fireAt = tz.TZDateTime(tz.local, day.year, day.month, day.day, 15);
      if (!fireAt.isAfter(now)) continue; // 3pm already passed today.

      final daysLeft = daysRemainingInChallengeWeek(day);
      final id = _idCompetitionBase + day.weekday;
      await _plugin.zonedSchedule(
        id,
        _competitionTitle(daysLeft),
        _competitionBody,
        fireAt,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // iOS-only legacy param (unused by the AndroidFlutterLocalNotifications
        // path this app runs on today); `absoluteTime` is the documented
        // correct value for a zoned DateTime like ours.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: NotificationTarget.competition.name,
      );
    }
  }

  static const _competitionBody =
      "Your crew's counting on you — log in and keep your Fleet Knots "
      'climbing.';

  static String _competitionTitle(int daysLeft) => daysLeft == 0
      ? 'Last day of the challenge!'
      : '$daysLeft day${daysLeft == 1 ? '' : 's'} left this week';

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancel(_idMeditation);
    await _plugin.cancel(_idMoodMorning);
    await _plugin.cancel(_idMoodMidday);
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(_idCompetitionBase + weekday);
    }
  }
}
