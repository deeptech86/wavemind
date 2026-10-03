import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
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
  const WeeklyInsightsScreen({super.key, WellnessRepository? repository})
    : _repository = repository;

  final WellnessRepository? _repository;

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
