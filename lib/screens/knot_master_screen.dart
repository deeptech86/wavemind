import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../data/games/knot_puzzle.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';

/// "Knot Master 3D" — a tactile loop-tying focus puzzle.
///
/// Loops are scattered at random each round. The player drags the rope's
/// working end from the anchor through every other loop — in any order they
/// like — and finally back to the anchor, forming a closed loop. The single
/// rule: a newly-run line may never cross a line already run. A clean segment
/// ticks a light haptic, a crossing fouls the knot with a sharp buzz, and
/// closing a clean loop plays a short celebratory sequence.
///
/// Haptics use [HapticFeedback] from `flutter/services.dart` (no extra package).
/// This game intentionally awards no Fleet Knots — only mood check-ins,
/// breathing sessions and journal entries feed that economy.
class KnotMasterScreen extends StatefulWidget {
  const KnotMasterScreen({super.key, Random? random}) : _random = random;

  final Random? _random;

  @override
  State<KnotMasterScreen> createState() => _KnotMasterScreenState();
}

class _KnotMasterScreenState extends State<KnotMasterScreen>
    with TickerProviderStateMixin {
  late final Random _random = widget._random ?? Random();
  late KnotPuzzle _puzzle = KnotPuzzle.random(random: _random);

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  /// Drives the red flash of the crossing lines the instant a knot fouls,
  /// before the failure banner is revealed.
  late final AnimationController _flashCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  /// Gate for the failure UI — held back for one brief flash after an overlap
  /// so the crossing reads clearly before the "Try Again" state appears.
  bool _failureRevealed = false;

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  void _connect(int loopId) {
    if (!_puzzle.isInProgress) return;
    final result = _puzzle.connect(loopId);
    switch (result) {
      case KnotStepResult.connected:
        HapticFeedback.lightImpact();
        setState(() {});
      case KnotStepResult.closed:
        _playSuccessHaptics();
        setState(() {});
      case KnotStepResult.overlap:
        HapticFeedback.heavyImpact();
        _flashCtrl.forward(from: 0).then((_) => _flashCtrl.reverse());
        setState(() => _failureRevealed = false);
        Future.delayed(const Duration(milliseconds: 620), () {
          if (!mounted) return;
          setState(() => _failureRevealed = true);
        });
      case KnotStepResult.rejected:
        break;
    }
  }

  /// A short ascending celebratory sequence on securing the loop.
  Future<void> _playSuccessHaptics() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.heavyImpact();
  }

  void _newRound() {
    HapticFeedback.selectionClick();
    _flashCtrl.value = 0;
    setState(() {
      _puzzle = KnotPuzzle.random(random: _random);
      _failureRevealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showFailure = _puzzle.isFailed && _failureRevealed;
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
              const BackHeader(title: 'Knot Master 3D'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _KnotIntro(),
                      const SizedBox(height: 16),
                      _KnotProgress(puzzle: _puzzle),
                      const SizedBox(height: 16),
                      _KnotArena(
                        puzzle: _puzzle,
                        pulse: _pulseCtrl,
                        flash: _flashCtrl,
                        onConnect: _connect,
                      ),
                      const SizedBox(height: 16),
                      if (_puzzle.isSuccess)
                        const _KnotSecuredBanner()
                      else if (showFailure)
                        const _KnotFouledBanner()
                      else
                        _KnotHint(puzzle: _puzzle),
                      const SizedBox(height: 16),
                      _NewRoundButton(phase: _puzzle.phase, onTap: _newRound),
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

class _KnotIntro extends StatelessWidget {
  const _KnotIntro();

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
              const Icon(Icons.touch_app_outlined,
                  size: 14, color: AppColors.teal),
              const SizedBox(width: 6),
              Text(
                'TACTILE FOCUS',
                style: AppTextStyles.badge.copyWith(color: AppColors.teal),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Close the Loop', style: AppTextStyles.cardHeading),
          const SizedBox(height: 8),
          Text(
            'Run the rope through every loop — in any order you like — then '
            'close it back onto the anchor. Keep the line clean: if a new pass '
            'crosses one already run, the knot fouls and you lay a fresh one.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _KnotProgress extends StatelessWidget {
  const _KnotProgress({required this.puzzle});

  final KnotPuzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final fouled = puzzle.isFailed;
    final accent = fouled ? AppColors.stormRed : AppColors.teal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Lines run', style: AppTextStyles.caption),
            Text(
              '${puzzle.segmentsDrawn} / ${puzzle.totalSegments}',
              style: AppTextStyles.badge.copyWith(
                fontSize: 12,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: puzzle.fraction,
            minHeight: 8,
            backgroundColor: AppColors.cardSurface,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
    );
  }
}

class _KnotArena extends StatelessWidget {
  const _KnotArena({
    required this.puzzle,
    required this.pulse,
    required this.flash,
    required this.onConnect,
  });

  final KnotPuzzle puzzle;
  final Animation<double> pulse;
  final Animation<double> flash;
  final ValueChanged<int> onConnect;

  static const double _targetSlot = 56;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Portrait-ish arena; clamp to non-negative to survive the zero-size
        // warm-up frame on Android launch.
        final height = max(0.0, width * 0.92);
        return SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.deepNavy,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppColors.tealBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: Stack(
                children: [
                  // The rope path, painted beneath the loops.
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: flash,
                      builder: (context, _) => CustomPaint(
                        painter: _RopePainter(
                          puzzle: puzzle,
                          size: Size(width, height),
                          flash: flash.value,
                        ),
                      ),
                    ),
                  ),
                  for (final target in puzzle.targets)
                    _buildTarget(target, width, height),
                  if (puzzle.isInProgress)
                    _buildRopeEnd(width, height),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The draggable working end of the rope, parked on the loop the path
  /// currently ends at.
  Widget _buildRopeEnd(double width, double height) {
    final end = puzzle.targets
        .firstWhere((t) => t.id == puzzle.currentEndId)
        .position;
    final frontier = Offset(end.dx * width, end.dy * height);
    const knob = 28.0;
    return Positioned(
      left: frontier.dx - knob / 2,
      top: frontier.dy - knob / 2,
      width: knob,
      height: knob,
      child: Draggable<int>(
        data: puzzle.currentEndId,
        feedback: _RopeEndKnob(pulse: pulse, dragging: true),
        childWhenDragging: const SizedBox.shrink(),
        child: _RopeEndKnob(pulse: pulse),
      ),
    );
  }

  Widget _buildTarget(KnotTarget target, double width, double height) {
    final cx = target.position.dx * width;
    final cy = target.position.dy * height;
    final isAnchor = target.id == puzzle.startId;
    final linked = puzzle.isLinked(target.id);
    final candidate = puzzle.isCandidate(target.id);
    final isEnd = target.id == puzzle.currentEndId;

    // Highlight the two loops involved in a foul, once failed.
    final crossing = puzzle.crossing;
    final fouled = puzzle.isFailed &&
        crossing != null &&
        (crossing.newSegment.fromId == target.id ||
            crossing.newSegment.toId == target.id ||
            crossing.hitSegment.fromId == target.id ||
            crossing.hitSegment.toId == target.id);

    return Positioned(
      left: cx - _targetSlot / 2,
      top: cy - _targetSlot / 2,
      width: _targetSlot,
      height: _targetSlot,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => candidate,
        onAcceptWithDetails: (_) => onConnect(target.id),
        builder: (context, incoming, rejected) {
          final hovering = incoming.isNotEmpty;
          return AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              final Color ring;
              double glow = 0;
              if (fouled) {
                ring = AppColors.stormRed;
                glow = 0.7;
              } else if (candidate) {
                // Anchor-to-close glows seafoam; open loops glow teal. Every
                // open loop is fair game, so they all carry a soft steady pull.
                ring = isAnchor ? AppColors.seafoam : AppColors.teal;
                glow = (hovering ? 0.9 : 0.3) + pulse.value * 0.3;
              } else if (linked) {
                ring = AppColors.seafoam;
              } else {
                ring = AppColors.glassBorder;
              }
              return _TargetLoop(
                ring: ring,
                linked: linked && !isAnchor,
                isAnchor: isAnchor,
                isEnd: isEnd,
                hovering: hovering,
                glow: glow,
              );
            },
          );
        },
      ),
    );
  }
}

class _TargetLoop extends StatelessWidget {
  const _TargetLoop({
    required this.ring,
    required this.linked,
    required this.isAnchor,
    required this.isEnd,
    required this.hovering,
    required this.glow,
  });

  final Color ring;
  final bool linked;
  final bool isAnchor;
  final bool isEnd;
  final bool hovering;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final filled = linked || (isAnchor && isEnd);
    return Center(
      child: Container(
        width: hovering ? 48 : 40,
        height: hovering ? 48 : 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.seafoamFaint : AppColors.glassFillFaint,
          border: Border.all(color: ring, width: filled ? 3 : 2),
          boxShadow: glow > 0
              ? [
                  BoxShadow(
                    color: ring.withValues(alpha: glow * 0.7),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: _loopIcon(),
      ),
    );
  }

  Widget _loopIcon() {
    if (isAnchor) {
      return Icon(Icons.anchor, size: 18, color: ring);
    }
    if (linked) {
      return const Icon(Icons.check, size: 18, color: AppColors.seafoam);
    }
    return const SizedBox.shrink();
  }
}

/// The draggable working end of the rope — a glowing seafoam knob the player
/// drags onto the next loop.
class _RopeEndKnob extends StatelessWidget {
  const _RopeEndKnob({required this.pulse, this.dragging = false});

  final Animation<double> pulse;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final spread = dragging ? 3.0 : (1.0 + pulse.value * 2.0);
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.seafoam,
            border: Border.all(color: AppColors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.seafoamGlow,
                blurRadius: 12,
                spreadRadius: spread,
              ),
            ],
          ),
          child: const Icon(
            Icons.drag_indicator,
            size: 14,
            color: AppColors.onAccent,
          ),
        );
      },
    );
  }
}

/// Paints the rope along the loops in the order the player linked them, plus —
/// on a foul — the crossing pair in flashing red.
class _RopePainter extends CustomPainter {
  _RopePainter({
    required this.puzzle,
    required this.size,
    required this.flash,
  });

  final KnotPuzzle puzzle;
  final Size size;
  final double flash;

  Offset _center(int id) {
    final t = puzzle.targets.firstWhere((t) => t.id == id);
    return Offset(t.position.dx * size.width, t.position.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = puzzle.path;
    final fouled = puzzle.isFailed;

    // The clean rope run so far.
    if (path.length >= 2) {
      final line = Path()..moveTo(_center(path.first).dx, _center(path.first).dy);
      for (var i = 1; i < path.length; i++) {
        final c = _center(path[i]);
        line.lineTo(c.dx, c.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = fouled
              ? Color.lerp(AppColors.sand, AppColors.stormRed, flash * 0.6)!
              : AppColors.sand
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // On a foul, overlay the two offending segments in bright flashing red.
    final crossing = puzzle.crossing;
    if (fouled && crossing != null) {
      final red = Paint()
        ..color = AppColors.stormRed.withValues(alpha: 0.5 + flash * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      for (final seg in [crossing.hitSegment, crossing.newSegment]) {
        canvas.drawLine(_center(seg.fromId), _center(seg.toId), red);
      }
    }

    // The anchor cleat.
    canvas.drawCircle(
      _center(puzzle.startId),
      7,
      Paint()..color = fouled ? AppColors.stormRed : AppColors.sand,
    );
  }

  @override
  bool shouldRepaint(_RopePainter old) =>
      old.puzzle != puzzle ||
      old.puzzle.path.length != puzzle.path.length ||
      old.flash != flash ||
      old.size != size;
}

class _KnotHint extends StatelessWidget {
  const _KnotHint({required this.puzzle});

  final KnotPuzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final closing = puzzle.canClose;
    final text = closing
        ? 'Every loop is linked. Drag the rope end back onto the anchor to '
            'close the knot — mind the lines already run.'
        : 'Drag the glowing rope end onto any open loop; the order is yours. '
            'Just keep each new pass from crossing a line already run.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealFaintSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.tealBorder),
      ),
      child: Row(
        children: [
          Icon(closing ? Icons.anchor : Icons.swipe,
              size: 20, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: AppColors.cream),
            ),
          ),
        ],
      ),
    );
  }
}

class _KnotSecuredBanner extends StatelessWidget {
  const _KnotSecuredBanner();

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
          const Icon(Icons.verified, size: 22, color: AppColors.seafoam),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Knot secured!',
                  style: AppTextStyles.cardTitleSmall
                      .copyWith(color: AppColors.seafoam),
                ),
                const SizedBox(height: 2),
                Text(
                  'A clean, non-crossing loop through every point. '
                  'Cast off and tie another.',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KnotFouledBanner extends StatelessWidget {
  const _KnotFouledBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.stormRed.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.stormRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 22, color: AppColors.stormRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lines fouled',
                  style: AppTextStyles.cardTitleSmall
                      .copyWith(color: AppColors.stormRed),
                ),
                const SizedBox(height: 2),
                Text(
                  'That pass crossed a line already run. Shake it out and '
                  'try a fresh lay.',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewRoundButton extends StatelessWidget {
  const _NewRoundButton({required this.phase, required this.onTap});

  final KnotPhase phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    switch (phase) {
      case KnotPhase.success:
        label = 'Tie Another Knot';
        color = AppColors.seafoam;
      case KnotPhase.failed:
        label = 'Try Again';
        color = AppColors.seafoam;
      case KnotPhase.inProgress:
        label = 'New Layout';
        color = AppColors.glassFill;
    }
    final accented = phase != KnotPhase.inProgress;
    final fg = accented ? AppColors.onAccent : AppColors.white;
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
                  accented ? null : Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  AppAssets.refreshCw,
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.buttonLarge.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
