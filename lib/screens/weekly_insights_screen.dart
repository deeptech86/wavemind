import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../data/health_data_service.dart';
import '../data/wellness_repository.dart';
import '../data/wellness_stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/tide_bottom_nav.dart';

/// "Sailing Wellness Log" insights (Figma node 3:346 "weekly-insights").
///
/// Stage 4: the Weekly Emotional Wave chart and the Breathe Streak / Sea Logs
/// stats are derived from real on-device data for the trailing 7 days. With no
/// data yet (fresh install) the chart shows a friendly empty state.
class WeeklyInsightsScreen extends StatefulWidget {
  const WeeklyInsightsScreen({
    super.key,
    WellnessRepository? repository,
    HealthDataService? healthService,
  }) : _repository = repository,
       _healthService = healthService;

  final WellnessRepository? _repository;

  /// Optional injection point for tests. In production the Watch Vitals card
  /// builds its own [HealthDataService]; nothing it reads is ever persisted.
  final HealthDataService? _healthService;

  @override
  State<WeeklyInsightsScreen> createState() => _WeeklyInsightsScreenState();
}

class _WeeklyInsightsScreenState extends State<WeeklyInsightsScreen> {
  late final WellnessRepository _repo =
      widget._repository ?? WellnessRepository();

  WeeklyInsightsData _data = WeeklyInsightsData.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repo.weeklyInsights();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const TideBottomNav(active: TideTab.insights),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Sailing Wellness Log',
                  style: AppTextStyles.headerTitle,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ChartCard(data: _data, loading: _loading),
                      const SizedBox(height: 20),
                      _StreaksRow(data: _data),
                      const SizedBox(height: 20),
                      _WatchHealthCard(service: widget._healthService),
                      const SizedBox(height: 20),
                      const _TipCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.data, required this.loading});

  final WeeklyInsightsData data;
  final bool loading;

  /// Single-letter weekday labels for the trailing 7 days ending today.
  static List<String> _trailingDayLabels({DateTime? now}) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S']; // Mon..Sun
    final today = WellnessStats.dayOf(now ?? DateTime.now());
    return [
      for (var i = WellnessStats.weekLength - 1; i >= 0; i--)
        letters[today.subtract(Duration(days: i)).weekday - 1],
    ];
  }

  String get _trendLabel {
    final points = data.waveScores.whereType<double>().toList();
    if (points.length < 2) return 'Charting Course';
    final delta = points.last - points.first;
    if (delta > 0.25) return 'Steady Ascent';
    if (delta < -0.25) return 'Dipping Swell';
    return 'Holding Steady';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Weekly Emotional Wave',
                  style: AppTextStyles.cardTitleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (data.hasAnyMood)
                Text(
                  _trendLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.seafoam,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.seafoam,
                      ),
                    ),
                  )
                : data.hasAnyMood
                ? CustomPaint(
                    painter: _WaveChartPainter(data.waveScores),
                    size: Size.infinite,
                  )
                : const _EmptyWave(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in _trailingDayLabels())
                Text(
                  d,
                  style: AppTextStyles.navLabel.copyWith(
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Friendly empty state shown when no mood has been logged in the trailing week.
class _EmptyWave extends StatelessWidget {
  const _EmptyWave();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(AppAssets.waves, width: 28, height: 28),
          const SizedBox(height: 8),
          Text(
            'Log your emotional swell to chart your week.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

/// Paints the trailing-week mood line over a 1–5 scale. Null days are gaps —
/// consecutive logged days are connected; isolated days render as dots.
class _WaveChartPainter extends CustomPainter {
  _WaveChartPainter(this.scores);

  final List<double?> scores;

  static const double _minScore = 1;
  static const double _maxScore = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final n = scores.length;
    if (n == 0) return;

    final gridPaint = Paint()
      ..color = AppColors.glassBorderSoft
      ..strokeWidth = 1;
    // Three faint horizontal guide lines (low / mid / high).
    for (final frac in const [0.0, 0.5, 1.0]) {
      final y = size.height * frac;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double dx(int i) => n == 1 ? size.width / 2 : size.width * i / (n - 1);
    double dy(double score) {
      final t = (score - _minScore) / (_maxScore - _minScore);
      // Higher score == calmer == higher on screen (smaller y). Inset slightly.
      final usable = size.height - 12;
      return 6 + usable * (1 - t);
    }

    final linePaint = Paint()
      ..color = AppColors.seafoam
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = AppColors.seafoam;
    final fillPaint = Paint()
      ..color = AppColors.seafoamFaint
      ..style = PaintingStyle.fill;

    // Draw connected segments across runs of consecutive non-null points.
    var i = 0;
    while (i < n) {
      if (scores[i] == null) {
        i++;
        continue;
      }
      var j = i;
      final run = <Offset>[];
      while (j < n && scores[j] != null) {
        run.add(Offset(dx(j), dy(scores[j]!)));
        j++;
      }
      if (run.length == 1) {
        canvas.drawCircle(run.first, 3.5, dotPaint);
      } else {
        final path = Path()..moveTo(run.first.dx, run.first.dy);
        for (final pt in run.skip(1)) {
          path.lineTo(pt.dx, pt.dy);
        }
        // Soft area fill under the line segment.
        final fill = Path.from(path)
          ..lineTo(run.last.dx, size.height)
          ..lineTo(run.first.dx, size.height)
          ..close();
        canvas.drawPath(fill, fillPaint);
        canvas.drawPath(path, linePaint);
        for (final pt in run) {
          canvas.drawCircle(pt, 3, dotPaint);
        }
      }
      i = j;
    }
  }

  @override
  bool shouldRepaint(_WaveChartPainter oldDelegate) =>
      oldDelegate.scores != scores;
}

class _StreaksRow extends StatelessWidget {
  const _StreaksRow({required this.data});

  final WeeklyInsightsData data;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StreakCard(
              label: 'Breathe Streak',
              value: '${data.breathStreakDays} '
                  '${data.breathStreakDays == 1 ? 'Day' : 'Days'}',
              valueColor: AppColors.seafoam,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StreakCard(
              label: 'Sea Logs Filed',
              value: '${data.seaLogsFiled} Total',
              valueColor: AppColors.cream,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.headerTitle.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

/// Internal phase for the live smartwatch health read. Mirrors the permission
/// flow: checking -> (unsupported | needsInstall | disconnected | denied) and,
/// once authorized, loading -> ready.
enum _WatchPhase {
  checking,
  unsupported,
  needsInstall,
  disconnected,
  denied,
  loading,
  ready,
}

/// Live, read-only smartwatch vitals (today's steps + last night's sleep,
/// plus heart rate when present).
///
/// Everything here lives in ephemeral widget state: the [HealthSnapshot] is
/// fetched from HealthKit / Health Connect each time the card initializes and
/// is never written to any database, repository, or backend. Navigating away
/// or restarting the app drops it, which is the intended privacy behavior — a
/// loading spinner on each visit is correct, not a bug to cache around.
class _WatchHealthCard extends StatefulWidget {
  const _WatchHealthCard({HealthDataService? service}) : _service = service;

  final HealthDataService? _service;

  @override
  State<_WatchHealthCard> createState() => _WatchHealthCardState();
}

class _WatchHealthCardState extends State<_WatchHealthCard> {
  late final HealthDataService _service =
      widget._service ?? HealthDataService();

  _WatchPhase _phase = _WatchPhase.checking;
  HealthSnapshot _snapshot = const HealthSnapshot();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (mounted) setState(() => _phase = _WatchPhase.checking);
    try {
      final availability = await _service.availability();
      if (!mounted) return;
      switch (availability) {
        case HealthAvailability.unsupported:
          setState(() => _phase = _WatchPhase.unsupported);
          return;
        case HealthAvailability.needsInstall:
          setState(() => _phase = _WatchPhase.needsInstall);
          return;
        case HealthAvailability.available:
          break;
      }
      final granted = await _service.hasPermissions();
      if (!mounted) return;
      if (granted == true) {
        await _loadData();
      } else {
        setState(() => _phase = _WatchPhase.disconnected);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _WatchPhase.unsupported);
    }
  }

  Future<void> _connect() async {
    if (mounted) setState(() => _phase = _WatchPhase.checking);
    try {
      final granted = await _service.requestPermissions();
      if (!mounted) return;
      if (granted) {
        await _loadData();
      } else {
        setState(() => _phase = _WatchPhase.denied);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _WatchPhase.denied);
    }
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _phase = _WatchPhase.loading);
    try {
      final snapshot = await _service.readToday();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _phase = _WatchPhase.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _WatchPhase.ready);
    }
  }

  Future<void> _install() async {
    try {
      await _service.installHealthStore();
    } catch (_) {
      // Best effort — re-check availability after the user returns.
    }
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    // No health store on this platform: hide the surface entirely.
    if (_phase == _WatchPhase.unsupported) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Watch Vitals',
                  style: AppTextStyles.cardTitleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_phase == _WatchPhase.ready)
                GestureDetector(
                  onTap: _loadData,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.refresh,
                      size: 20,
                      color: AppColors.seafoam,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Live from your paired watch — never stored.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _WatchPhase.checking:
      case _WatchPhase.loading:
        return const SizedBox(
          height: 56,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.seafoam,
              ),
            ),
          ),
        );
      case _WatchPhase.needsInstall:
        return _WatchMessage(
          icon: Icons.download_rounded,
          message:
              'Health Connect is required to read your watch data on Android. '
              'Install or update it to continue.',
          actionLabel: 'Get Health Connect',
          onAction: _install,
        );
      case _WatchPhase.disconnected:
        return _WatchMessage(
          icon: Icons.watch_outlined,
          message:
              'Connect your smartwatch to see today’s steps and last night’s '
              'sleep here. We only ever read this data — never write or store '
              'it.',
          actionLabel: 'Connect Watch',
          onAction: _connect,
        );
      case _WatchPhase.denied:
        return _WatchMessage(
          icon: Icons.lock_outline,
          message:
              'Access was declined. Grant read access to steps and sleep to '
              'view your watch vitals.',
          actionLabel: 'Try Again',
          onAction: _connect,
        );
      case _WatchPhase.ready:
        if (!_snapshot.hasAnyData) {
          return _WatchMessage(
            icon: Icons.info_outline,
            message:
                'No step or sleep data available yet. Wear your watch and '
                'sync, then refresh.',
            actionLabel: 'Refresh',
            onAction: _loadData,
          );
        }
        return _WatchMetrics(snapshot: _snapshot);
      case _WatchPhase.unsupported:
        return const SizedBox.shrink();
    }
  }
}

/// Steps / sleep (/ heart-rate) readout once a live snapshot is in hand.
class _WatchMetrics extends StatelessWidget {
  const _WatchMetrics({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _WatchMetric(
                  label: "Today’s Steps",
                  value: snapshot.steps != null
                      ? _formatSteps(snapshot.steps!)
                      : '—',
                  valueColor: AppColors.seafoam,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WatchMetric(
                  label: 'Last Night’s Sleep',
                  value: snapshot.sleep != null
                      ? HealthDataService.formatSleepDuration(snapshot.sleep!)
                      : '—',
                  valueColor: AppColors.cream,
                ),
              ),
            ],
          ),
        ),
        if (snapshot.restingHeartRate != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.favorite,
                size: 16,
                color: AppColors.stormRed,
              ),
              const SizedBox(width: 6),
              Text(
                '${snapshot.restingHeartRate} bpm',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.cream),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Groups thousands with a thin separator, e.g. 8,421.
  static String _formatSteps(int steps) {
    final digits = steps.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

class _WatchMetric extends StatelessWidget {
  const _WatchMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.headerTitle.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

/// A message + single action button, shared by the not-connected / denied /
/// install / no-data states.
class _WatchMessage extends StatelessWidget {
  const _WatchMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.seafoam),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.seafoamFaint,
              foregroundColor: AppColors.seafoam,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                side: const BorderSide(color: AppColors.seafoamBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(actionLabel, style: AppTextStyles.buttonSmall),
          ),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(AppAssets.circleX, width: 20, height: 20),
              const SizedBox(width: 8),
              Text('Helmsman Advice', style: AppTextStyles.labelMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your mood drops slightly when external weather swell peaks. Try a '
            'brief 2-minute Tidal Breathe set right before stepping on deck for '
            'watch.',
            style: AppTextStyles.bodySmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
