import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/games/matchstick_puzzle.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';

const double _digitW = 46;
const double _digitH = 80;

/// "Matchstick Puzzle" — relocate exactly one seven-segment matchstick.
///
/// A row of digits (and, for the "fix the equation" challenge, fixed
/// `+`/`-`/`=` signs) is drawn from matchsticks. Drag a lit stick onto an
/// empty slot — in that same digit, or a different one — to relocate it.
/// The puzzle only allows one relocation per round: get it right and the
/// round is solved; get it wrong and the board quietly resets so the player
/// can try again, no hard fail. Puzzles rotate between three challenges (see
/// [MatchPuzzleType]): fix a false equation, find the biggest number
/// reachable in one move, or turn a digit into a different valid digit.
///
/// This game intentionally awards no Fleet Knots, same as Knot Master, Fog
/// Signal Echo, Stone Cairn Balance and Cabin Dominoes — only mood
/// check-ins, breathing sessions and journal entries feed that economy.
class MatchstickPuzzleScreen extends StatefulWidget {
  const MatchstickPuzzleScreen({super.key, Random? random}) : _random = random;

  final Random? _random;

  @override
  State<MatchstickPuzzleScreen> createState() => _MatchstickPuzzleScreenState();
}

enum _Phase { idle, wrong, solved }

/// Identifies a stick by which digit token and which of its seven segments
/// it sits in — the payload a [Draggable] carries.
class _StickRef {
  const _StickRef(this.tokenIndex, this.segment);
  final int tokenIndex;
  final int segment;
}

class _MatchstickPuzzleScreenState extends State<MatchstickPuzzleScreen> {
  late final Random _random = widget._random ?? Random();
  late final List<MatchstickPuzzle> _bank = MatchstickPuzzle.bank();
  late int _puzzleIndex = _random.nextInt(_bank.length);
  late MatchstickPuzzle _puzzle = _bank[_puzzleIndex];

  MatchMove? _hintMove;
  _Phase _phase = _Phase.idle;

  Timer? _wrongTimer;
  Timer? _hintTimer;

  @override
  void dispose() {
    _wrongTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _onDrop(int fromToken, int fromSegment, int toToken, int toSegment) {
    if (_phase != _Phase.idle) return;

    final result = _puzzle.move(fromToken, fromSegment, toToken, toSegment);
    if (result == MoveResult.invalid) {
      HapticFeedback.heavyImpact();
      return;
    }

    _hintTimer?.cancel();
    setState(() => _hintMove = null);

    if (_puzzle.isSolved) {
      HapticFeedback.mediumImpact();
      setState(() => _phase = _Phase.solved);
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _phase = _Phase.wrong);
    _wrongTimer?.cancel();
    _wrongTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _puzzle.reset();
        _phase = _Phase.idle;
      });
    });
  }

  void _showHint() {
    if (_phase != _Phase.idle) return;
    final solutions = _puzzle.findSolutions();
    if (solutions.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _hintMove = solutions[_random.nextInt(solutions.length)]);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _hintMove = null);
    });
  }

  void _newPuzzle() {
    HapticFeedback.selectionClick();
    _wrongTimer?.cancel();
    _hintTimer?.cancel();
    var next = _random.nextInt(_bank.length);
    while (_bank.length > 1 && next == _puzzleIndex) {
      next = _random.nextInt(_bank.length);
    }
    setState(() {
      _puzzleIndex = next;
      _puzzle = _bank[next];
      _hintMove = null;
      _phase = _Phase.idle;
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
              const BackHeader(title: 'Matchstick Puzzle'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MatchIntro(prompt: _puzzle.prompt),
                      const SizedBox(height: 16),
                      _Board(
                        puzzle: _puzzle,
                        hint: _hintMove,
                        locked: _phase != _Phase.idle,
                        onDrop: _onDrop,
                      ),
                      const SizedBox(height: 16),
                      _StatusBanner(phase: _phase),
                      const SizedBox(height: 16),
                      _ActionRow(onHint: _showHint, onNewPuzzle: _newPuzzle),
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

class _MatchIntro extends StatelessWidget {
  const _MatchIntro({required this.prompt});

  final String prompt;

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
              const Icon(Icons.local_fire_department_outlined,
                  size: 14, color: AppColors.stormRed),
              const SizedBox(width: 6),
              Text(
                'LOGIC FOCUS',
                style: AppTextStyles.badge.copyWith(color: AppColors.stormRed),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Shift One Stick', style: AppTextStyles.cardHeading),
          const SizedBox(height: 8),
          Text(
            prompt,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Drag a lit matchstick onto an empty slot — in this digit or '
            'another — to relocate it.',
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.puzzle,
    required this.hint,
    required this.locked,
    required this.onDrop,
  });

  final MatchstickPuzzle puzzle;
  final MatchMove? hint;
  final bool locked;
  final void Function(int fromToken, int fromSegment, int toToken, int toSegment) onDrop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.deepNavy,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.tealBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < puzzle.tokenCount; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              puzzle.isDigitToken(i)
                  ? _MatchstickDigit(
                      tokenIndex: i,
                      segments: puzzle.segmentsAt(i),
                      hint: hint,
                      locked: locked,
                      onDrop: onDrop,
                    )
                  : _OperatorGlyph(symbol: puzzle.operatorAt(i)),
            ],
          ],
        ),
      ),
    );
  }
}

class _OperatorGlyph extends StatelessWidget {
  const _OperatorGlyph({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: _digitH,
      child: Center(
        child: Text(
          symbol,
          style: AppTextStyles.cardHeading.copyWith(color: AppColors.cream),
        ),
      ),
    );
  }
}

enum _SegVisual { unlit, lit, hintFrom, hintTo }

class _MatchstickDigit extends StatelessWidget {
  const _MatchstickDigit({
    required this.tokenIndex,
    required this.segments,
    required this.hint,
    required this.locked,
    required this.onDrop,
  });

  final int tokenIndex;
  final Set<int> segments;
  final MatchMove? hint;
  final bool locked;
  final void Function(int fromToken, int fromSegment, int toToken, int toSegment) onDrop;

  static bool _isHorizontal(int seg) => seg == 0 || seg == 3 || seg == 6;

  _SegVisual _visualFor(int seg, bool lit) {
    final h = hint;
    if (h != null && h.fromToken == tokenIndex && h.fromSegment == seg) {
      return _SegVisual.hintFrom;
    }
    if (h != null && h.toToken == tokenIndex && h.toSegment == seg) {
      return _SegVisual.hintTo;
    }
    return lit ? _SegVisual.lit : _SegVisual.unlit;
  }

  @override
  Widget build(BuildContext context) {
    const size = Size(_digitW, _digitH);
    return SizedBox(
      width: _digitW,
      height: _digitH,
      child: Stack(
        children: [
          for (var seg = 0; seg < 7; seg++) _buildSegment(seg, size),
        ],
      ),
    );
  }

  Widget _buildSegment(int seg, Size digitSize) {
    final rect = segmentRect(seg, digitSize);
    final lit = segments.contains(seg);
    final visual = _visualFor(seg, lit);
    final horizontal = _isHorizontal(seg);

    final stick = SizedBox(
      width: rect.width,
      height: rect.height,
      child: CustomPaint(painter: _StickPainter(visual: visual, horizontal: horizontal)),
    );

    if (lit) {
      return Positioned.fromRect(
        key: ValueKey('match_stick_${tokenIndex}_$seg'),
        rect: rect,
        child: Draggable<_StickRef>(
          data: _StickRef(tokenIndex, seg),
          maxSimultaneousDrags: locked ? 0 : 1,
          feedback: Transform.scale(
            scale: 1.4,
            child: SizedBox(
              width: rect.width,
              height: rect.height,
              child: CustomPaint(
                painter: _StickPainter(visual: _SegVisual.lit, horizontal: horizontal),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: SizedBox(
              width: rect.width,
              height: rect.height,
              child: CustomPaint(
                painter: _StickPainter(visual: _SegVisual.unlit, horizontal: horizontal),
              ),
            ),
          ),
          child: stick,
        ),
      );
    }

    return Positioned.fromRect(
      key: ValueKey('match_slot_${tokenIndex}_$seg'),
      rect: rect.inflate(5),
      child: DragTarget<_StickRef>(
        onWillAcceptWithDetails: (_) => !locked,
        onAcceptWithDetails: (details) =>
            onDrop(details.data.tokenIndex, details.data.segment, tokenIndex, seg),
        builder: (context, candidates, rejected) {
          final hovering = candidates.isNotEmpty;
          return Center(
            child: SizedBox(
              width: rect.width,
              height: rect.height,
              child: CustomPaint(
                painter: _StickPainter(
                  visual: visual,
                  horizontal: horizontal,
                  hovering: hovering,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The seven-segment slot geometry, shared by the painter and the drag
/// regions so what's drawn always lines up with what's draggable/droppable.
Rect segmentRect(int seg, Size size) {
  const t = 8.0;
  const gap = 3.0;
  final w = size.width;
  final h = size.height;
  switch (seg) {
    case 0: // top
      return Rect.fromLTWH(gap, 0, w - gap * 2, t);
    case 1: // topLeft
      return Rect.fromLTWH(0, gap, t, h / 2 - gap * 1.5);
    case 2: // topRight
      return Rect.fromLTWH(w - t, gap, t, h / 2 - gap * 1.5);
    case 3: // middle
      return Rect.fromLTWH(gap, h / 2 - t / 2, w - gap * 2, t);
    case 4: // bottomLeft
      return Rect.fromLTWH(0, h / 2 + gap * 0.5, t, h / 2 - gap * 1.5);
    case 5: // bottomRight
      return Rect.fromLTWH(w - t, h / 2 + gap * 0.5, t, h / 2 - gap * 1.5);
    case 6: // bottom
      return Rect.fromLTWH(gap, h - t, w - gap * 2, t);
    default:
      throw ArgumentError('invalid segment $seg');
  }
}

class _StickPainter extends CustomPainter {
  _StickPainter({
    required this.visual,
    required this.horizontal,
    this.hovering = false,
  });

  final _SegVisual visual;
  final bool horizontal;
  final bool hovering;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2));

    if (visual == _SegVisual.unlit) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hovering ? 2 : 1.2
          ..color = hovering ? AppColors.seafoam : AppColors.glassBorderSoft,
      );
      return;
    }

    final fill = switch (visual) {
      _SegVisual.hintFrom || _SegVisual.hintTo => AppColors.sand,
      _ => AppColors.matchWood,
    };
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.matchWoodDark.withValues(alpha: 0.5),
    );
    final headCenter = horizontal
        ? Offset(rect.left + rect.height / 2, rect.center.dy)
        : Offset(rect.center.dx, rect.top + rect.width / 2);
    canvas.drawCircle(headCenter, rect.shortestSide * 0.65, Paint()..color = AppColors.matchHead);
  }

  @override
  bool shouldRepaint(covariant _StickPainter old) =>
      old.visual != visual || old.hovering != hovering;
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.phase});

  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, caption) = switch (phase) {
      _Phase.solved => (
          Icons.verified,
          AppColors.seafoam,
          'Solved!',
          'That single move made it work. Try another puzzle below.',
        ),
      _Phase.wrong => (
          Icons.replay,
          AppColors.sand,
          'Not quite',
          'That move didn\'t solve it — resetting for another try.',
        ),
      _Phase.idle => (
          Icons.touch_app_outlined,
          AppColors.muted,
          'Ready when you are',
          'Drag any lit matchstick onto an empty slot to move it.',
        ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.cardTitleSmall.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: AppTextStyles.caption.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.onHint, required this.onNewPuzzle});

  final VoidCallback onHint;
  final VoidCallback onNewPuzzle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(icon: Icons.lightbulb_outline, label: 'Hint', onTap: onHint),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionButton(icon: Icons.refresh, label: 'New Puzzle', onTap: onNewPuzzle),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
