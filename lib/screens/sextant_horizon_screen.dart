import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/games/sextant_balance.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';

/// "Sextant Horizon Balance" — a tilt-controlled bubble-level calming game.
///
/// The device accelerometer drives a spirit bubble inside a circular vial; the
/// player keeps it centred on the horizon. Centred time fills a "calm meter"
/// (with gentle decay while off-centre); filling it completes the session.
///
/// The accelerometer stream is read via [accelerometerEventStream] and mapped by
/// the pure [SextantBalance] model. The subscription is cancelled on dispose. If
/// the stream errors or is unavailable (e.g. no sensor / permission), the screen
/// degrades to a clear fallback message instead of crashing. On an emulator the
/// default reading is static (no tilt) until values are injected — the meter
/// still responds correctly whenever real sensor deltas arrive.
///
/// This game intentionally awards no Fleet Knots.
class SextantHorizonScreen extends StatefulWidget {
  const SextantHorizonScreen({super.key});

  @override
  State<SextantHorizonScreen> createState() => _SextantHorizonScreenState();
}

class _SextantHorizonScreenState extends State<SextantHorizonScreen> {
  final SextantBalance _balance = SextantBalance();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _ticker;
  Duration _lastTick = Duration.zero;
  final Stopwatch _clock = Stopwatch();

  /// Normalized bubble offset in `[-1, 1]` per axis.
  Offset _bubble = Offset.zero;
  bool _centered = true;
  double _progress = 0;
  bool _complete = false;

  /// True once the accelerometer stream reports an error / is unavailable.
  bool _sensorUnavailable = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _clock
      ..reset()
      ..start();
    _lastTick = Duration.zero;
    _subscribeSensor();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _onTick);
  }

  void _subscribeSensor() {
    try {
      _accelSub = accelerometerEventStream().listen(
        _onAccelerometer,
        onError: (Object _) => _handleSensorFailure(),
        cancelOnError: true,
      );
    } catch (_) {
      _handleSensorFailure();
    }
  }

  void _handleSensorFailure() {
    if (!mounted) return;
    setState(() => _sensorUnavailable = true);
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (!mounted || _complete) return;
    final bubble = _balance.bubbleOffset(event.x, event.y);
    final centered = _balance.isCentered(bubble);
    setState(() {
      _bubble = bubble;
      _centered = centered;
    });
  }

  void _onTick(Timer _) {
    if (!mounted || _complete) return;
    final now = _clock.elapsed;
    final delta = now - _lastTick;
    _lastTick = now;
    final progress = _balance.tick(delta, centered: _centered);
    final done = _balance.isComplete;
    setState(() {
      _progress = progress;
      if (done && !_complete) {
        _complete = true;
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _restart() {
    HapticFeedback.selectionClick();
    _balance.reset();
    setState(() {
      _progress = 0;
      _complete = false;
      _lastTick = _clock.elapsed;
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _ticker?.cancel();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Sextant Horizon Balance'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SextantIntro(),
                      const SizedBox(height: 16),
                      if (_sensorUnavailable)
                        const _SensorFallback()
                      else ...[
                        _CalmMeter(progress: _progress, centered: _centered),
                        const SizedBox(height: 16),
                        _VialArena(
                          bubble: _bubble,
                          tolerance: _balance.tolerance,
                          centered: _centered,
                          complete: _complete,
                        ),
                        const SizedBox(height: 16),
                        if (_complete)
                          const _BalanceAchieved()
                        else
                          _StatusLine(centered: _centered),
                        const SizedBox(height: 16),
                        _RestartButton(
                          complete: _complete,
                          onTap: _restart,
                        ),
                      ],
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

class _SextantIntro extends StatelessWidget {
  const _SextantIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore_outlined,
                  size: 14, color: AppColors.seafoam),
              const SizedBox(width: 6),
              Text(
                'VESTIBULAR RESET',
                style: AppTextStyles.badge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Hold the Horizon', style: AppTextStyles.cardHeading),
          const SizedBox(height: 8),
          Text(
            'Tilt the deck gently to float the spirit bubble back to centre. '
            'Hold it steady on the horizon to let the calm meter fill.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.bodyMist),
          ),
        ],
      ),
    );
  }
}

class _CalmMeter extends StatelessWidget {
  const _CalmMeter({required this.progress, required this.centered});

  final double progress;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Calm meter', style: AppTextStyles.caption),
            Text(
              '${(progress * 100).round()}%',
              style: AppTextStyles.badge.copyWith(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.cardSurface,
            valueColor: AlwaysStoppedAnimation<Color>(
              centered ? AppColors.seafoam : AppColors.sand,
            ),
          ),
        ),
      ],
    );
  }
}

class _VialArena extends StatelessWidget {
  const _VialArena({
    required this.bubble,
    required this.tolerance,
    required this.centered,
    required this.complete,
  });

  final Offset bubble;
  final double tolerance;
  final bool centered;
  final bool complete;

  static const double _bubbleSize = 46;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = max(0.0, constraints.maxWidth);
        final radius = size / 2;
        // Keep the bubble inside the vial rim.
        final travel = max(0.0, radius - _bubbleSize / 2 - 6);
        final dx = bubble.dx * travel;
        final dy = bubble.dy * travel;
        final toleranceDiameter = tolerance * 2 * travel + _bubbleSize;

        final bubbleColor =
            complete ? AppColors.seafoam : (centered ? AppColors.seafoam : AppColors.sand);

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.deepNavy,
                border: Border.all(color: AppColors.tealBorder, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Centre tolerance ring (the target).
                  Container(
                    width: toleranceDiameter,
                    height: toleranceDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: centered
                            ? AppColors.seafoamBorder
                            : AppColors.glassBorder,
                        width: 2,
                      ),
                      color: centered
                          ? AppColors.seafoamFaint
                          : Colors.transparent,
                    ),
                  ),
                  // Horizon crosshair lines.
                  Container(width: size * 0.7, height: 1,
                      color: AppColors.glassBorder),
                  Container(width: 1, height: size * 0.7,
                      color: AppColors.glassBorder),
                  // The spirit bubble.
                  Transform.translate(
                    offset: Offset(dx, dy),
                    child: Container(
                      width: _bubbleSize,
                      height: _bubbleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bubbleColor.withValues(alpha: 0.85),
                        border:
                            Border.all(color: AppColors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: bubbleColor.withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.centered});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    final color = centered ? AppColors.seafoam : AppColors.sand;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Row(
        children: [
          Icon(
            centered ? Icons.check_circle_outline : Icons.waves,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              centered
                  ? 'Level on the horizon — hold it there.'
                  : 'Swell is rolling. Ease the bubble back to centre.',
              style: AppTextStyles.caption.copyWith(color: AppColors.cream),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceAchieved extends StatelessWidget {
  const _BalanceAchieved();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.seafoamFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.seafoamBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.self_improvement,
              size: 22, color: AppColors.seafoam),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Horizon held.',
                  style: AppTextStyles.cardTitleSmall
                      .copyWith(color: AppColors.seafoam),
                ),
                const SizedBox(height: 2),
                Text(
                  'Steady inner ear, steady mind. Reset to settle again.',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.cream),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorFallback extends StatelessWidget {
  const _SensorFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sandFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sensors_off, size: 22, color: AppColors.sand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motion sensor unavailable',
                  style: AppTextStyles.cardTitleSmall
                      .copyWith(color: AppColors.sand),
                ),
                const SizedBox(height: 4),
                Text(
                  'This device did not report tilt data, so the horizon leveler '
                  'cannot run here. Try on a physical phone with a motion '
                  'sensor.',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.cream),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestartButton extends StatelessWidget {
  const _RestartButton({required this.complete, required this.onTap});

  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppColors.seafoam : AppColors.glassFill;
    final fg = complete ? AppColors.onAccent : AppColors.white;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              border:
                  complete ? null : Border.all(color: AppColors.glassBorder),
            ),
            child: Center(
              child: Text(
                complete ? 'Settle Again' : 'Reset Meter',
                style: AppTextStyles.buttonLarge.copyWith(color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
