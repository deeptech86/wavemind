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

/// "Knot Master 3D" — a tactile rope-tying focus puzzle.
///
/// The player drags the rope's working end through a sequence of loop /
/// anchor-point targets in the correct order to tie a (simplified) bowline.
/// Each correct thread ticks a light haptic, a foul move a sharp one, and
/// securing the knot plays a short celebratory haptic sequence. The threading
/// order is randomized every round so it stays replayable.
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
    with SingleTickerProviderStateMixin {
  late final Random _random = widget._random ?? Random();
  late KnotPuzzle _puzzle = KnotPuzzle.shuffled(random: _random);

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  /// The id of the target that just received a foul drop, flashed briefly.
  int? _foulTargetId;

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _thread(int targetId) {
    if (_puzzle.isComplete) return;
    final result = _puzzle.registerTarget(targetId);
    switch (result) {
      case KnotStepResult.correct:
        HapticFeedback.lightImpact();
        setState(() => _foulTargetId = null);
      case KnotStepResult.completed:
        _playSuccessHaptics();
        setState(() => _foulTargetId = null);
      case KnotStepResult.wrong:
        HapticFeedback.heavyImpact();
        setState(() => _foulTargetId = targetId);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          setState(() => _foulTargetId = null);
        });
    }
  }

  /// A short ascending celebratory sequence on completing the knot.
  Future<void> _playSuccessHaptics() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.heavyImpact();
  }

  void _newRound() {
    HapticFeedback.selectionClick();
    setState(() {
      _puzzle = KnotPuzzle.shuffled(random: _random);
      _foulTargetId = null;
    });
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
                        foulTargetId: _foulTargetId,
                        onThread: _thread,
                      ),
                      const SizedBox(height: 16),
                      if (_puzzle.isComplete)
                        const _KnotSecuredBanner()
                      else
                        const _KnotHint(),
                      const SizedBox(height: 16),
                      _NewRoundButton(
                        complete: _puzzle.isComplete,
                        onTap: _newRound,
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
          Text('Tie the Bowline', style: AppTextStyles.cardHeading),
          const SizedBox(height: 8),
          Text(
            'Drag the rope end through each glowing loop in order. Feel the '
            'line seat home with every true pass; a foul pass buzzes back.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.bodyMist),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Rope seated', style: AppTextStyles.caption),
            Text(
              '${puzzle.progress} / ${puzzle.totalSteps}',
              style: AppTextStyles.badge.copyWith(
                fontSize: 12,
                color: AppColors.teal,
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
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
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
    required this.foulTargetId,
    required this.onThread,
  });

  final KnotPuzzle puzzle;
  final Animation<double> pulse;
  final int? foulTargetId;
  final ValueChanged<int> onThread;

  static const double _targetSize = 52;

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
                  // The rope threaded so far, painted beneath the loops.
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RopePainter(
                        puzzle: puzzle,
                        size: Size(width, height),
                      ),
                    ),
                  ),
                  for (final target in puzzle.targets)
                    _buildTarget(target, width, height),
                  if (!puzzle.isComplete) _buildRopeEnd(width, height),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The draggable working end of the rope, parked at the current frontier
  /// (the anchor before anything is threaded, otherwise the last seated loop).
  Widget _buildRopeEnd(double width, double height) {
    final Offset frontier;
    if (puzzle.progress == 0) {
      frontier = Offset(width * 0.12, height * 0.9);
    } else {
      final t = puzzle.targets
          .firstWhere((t) => t.id == puzzle.order[puzzle.progress - 1]);
      frontier = Offset(t.position.dx * width, t.position.dy * height);
    }
    const knob = 28.0;
    final handle = _RopeEndKnob(pulse: pulse);
    return Positioned(
      left: frontier.dx - knob / 2,
      top: frontier.dy - knob / 2,
      width: knob,
      height: knob,
      child: Draggable<int>(
        data: 0,
        feedback: _RopeEndKnob(pulse: pulse, dragging: true),
        childWhenDragging: const SizedBox.shrink(),
        child: handle,
      ),
    );
  }

  Widget _buildTarget(KnotTarget target, double width, double height) {
    final cx = target.position.dx * width;
    final cy = target.position.dy * height;
    final threaded = puzzle.isThreaded(target.id);
    final isNext = puzzle.isNext(target.id);
    final isFoul = foulTargetId == target.id;

    return Positioned(
      left: cx - _targetSize / 2,
      top: cy - _targetSize / 2,
      width: _targetSize,
      height: _targetSize,
      child: DragTarget<int>(
        onAcceptWithDetails: (_) => onThread(target.id),
        builder: (context, candidate, rejected) {
          final hovering = candidate.isNotEmpty;
          return AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              final glow = isNext ? (0.4 + pulse.value * 0.6) : 0.0;
              final Color ring;
              if (isFoul) {
                ring = AppColors.stormRed;
              } else if (threaded) {
                ring = AppColors.seafoam;
              } else if (isNext) {
                ring = AppColors.teal;
              } else {
                ring = AppColors.glassBorder;
              }
              return _TargetLoop(
                ring: ring,
                filled: threaded,
                hovering: hovering,
                glow: glow,
                ordinal: puzzle.order.indexOf(target.id) + 1,
                showOrdinal: isNext || hovering,
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
    required this.filled,
    required this.hovering,
    required this.glow,
    required this.ordinal,
    required this.showOrdinal,
  });

  final Color ring;
  final bool filled;
  final bool hovering;
  final double glow;
  final int ordinal;
  final bool showOrdinal;

  @override
  Widget build(BuildContext context) {
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
        child: filled
            ? const Icon(Icons.check, size: 18, color: AppColors.seafoam)
            : showOrdinal
                ? Text(
                    '$ordinal',
                    style: AppTextStyles.badge.copyWith(color: ring),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}

/// The draggable working end of the rope — a glowing seafoam knob the player
/// drags onto the next lit loop.
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

/// Paints the rope from a fixed anchor through each already-threaded loop.
class _RopePainter extends CustomPainter {
  _RopePainter({required this.puzzle, required this.size});

  final KnotPuzzle puzzle;
  final Size size;

  Offset get _anchor => Offset(size.width * 0.12, size.height * 0.9);

  Offset _targetCenter(int id) {
    final t = puzzle.targets.firstWhere((t) => t.id == id);
    return Offset(t.position.dx * size.width, t.position.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(_anchor.dx, _anchor.dy);
    for (var i = 0; i < puzzle.progress; i++) {
      final c = _targetCenter(puzzle.order[i]);
      path.lineTo(c.dx, c.dy);
    }

    final rope = Paint()
      ..color = AppColors.sand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, rope);

    // Anchor cleat. The draggable working-end knob is a real widget overlaid on
    // top of this painter (see [_RopeEndKnob]).
    canvas.drawCircle(
      _anchor,
      7,
      Paint()..color = AppColors.sand,
    );
  }

  @override
  bool shouldRepaint(_RopePainter old) =>
      old.puzzle.progress != puzzle.progress || old.size != size;
}

class _KnotHint extends StatelessWidget {
  const _KnotHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealFaintSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.tealBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.swipe, size: 20, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Drag the glowing rope end onto the numbered loop that is lit '
              'next. Breathe slow — the rope follows your hand.',
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
                  'A fair, true bowline. Cast off and tie another.',
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

class _NewRoundButton extends StatelessWidget {
  const _NewRoundButton({required this.complete, required this.onTap});

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
              border: complete
                  ? null
                  : Border.all(color: AppColors.glassBorder),
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
                  complete ? 'Tie Another Knot' : 'Reset Rope',
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
