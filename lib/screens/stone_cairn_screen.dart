import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_assets.dart';
import '../data/games/stone_cairn.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';

/// Width a stone renders at, shared by the tray and the tower so a stone is
/// always the same true-to-scale size wherever it's drawn — the whole point
/// being that the player can judge which stone is actually bigger before
/// deciding which one goes under which.
double _stoneWidth(double radius) => 44.0 + radius * 62.0;

/// Stones are flattened river pebbles, not round rocks — noticeably wider
/// than tall, like the ones in a classic balanced-rock cairn photo.
double _stoneHeight(double radius) => _stoneWidth(radius) / 2.3;

/// How much each stone overlaps the one below it, as a fraction of its own
/// height — real stacked pebbles nestle into each other rather than just
/// touching edge-to-edge.
const double _nestOverlap = 0.78;

/// "Stone Cairn Balance" — a single vertical tower of stones, side-view, like
/// a classic balanced river-stone cairn.
///
/// A scatter of irregular, flattened stones, varied in size and drawn true
/// to scale, waits in the tray below the tower. Drag any stone onto the
/// tower and it joins the top of the stack, leaning a little toward
/// whichever side it was dropped on, with a small bounce and a soft thud
/// pitched a little lower for bigger stones. Balance is real, if simplified
/// (see [StoneCairn.dropOnTop]): stack a meaningfully bigger stone on a
/// smaller one, or drop one too far off-center, and the whole tower topples
/// with a clatter — every stone falls back to the tray and the player
/// starts the tower over. [StoneCairn.isComplete] tracks whether every
/// stone has joined the (currently standing) tower at least once, and
/// picking an already-placed stone back up just restacks it on top.
///
/// This game intentionally awards no Fleet Knots, same as Knot Master, Fog
/// Signal Echo and Cabin Dominoes — only mood check-ins, breathing sessions
/// and journal entries feed that economy.
class StoneCairnScreen extends StatefulWidget {
  const StoneCairnScreen({super.key, Random? random}) : _random = random;

  final Random? _random;

  @override
  State<StoneCairnScreen> createState() => _StoneCairnScreenState();
}

class _StoneCairnScreenState extends State<StoneCairnScreen> {
  late final Random _random = widget._random ?? Random();
  late StoneCairn _cairn = StoneCairn.generate(random: _random);
  final AudioPlayer _settlePlayer = AudioPlayer();
  final AudioPlayer _collapsePlayer = AudioPlayer();
  bool _settleAudioReady = false;
  bool _collapseAudioReady = false;

  /// Bumped for a stone every time it (re)joins the tower, folded into that
  /// stone's widget key so its settle-pop animation always restarts rather
  /// than reusing one that already finished.
  final Map<int, int> _settleTick = {};

  /// Snapshot of the tower's layout the instant before it topples — null
  /// while the tower is standing (or empty). While non-null, the tower
  /// renders these tumbling instead of the normal stack.
  List<_StoneLayout>? _fallingLayouts;
  int _fallToken = 0;
  Timer? _collapseTimer;

  final GlobalKey _towerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      await _settlePlayer.setAsset(AppAssets.audioStoneSettle);
      if (!mounted) return;
      setState(() => _settleAudioReady = true);
    } catch (_) {
      // Audio is a sensory layer, not the game logic — stack on in silence
      // rather than block the sandbox if the asset can't load.
    }
    try {
      await _collapsePlayer.setAsset(AppAssets.audioStoneCollapse);
      if (!mounted) return;
      setState(() => _collapseAudioReady = true);
    } catch (_) {
      // Non-fatal — the fall animation still carries the feedback.
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _settlePlayer.dispose();
    _collapsePlayer.dispose();
    super.dispose();
  }

  Future<void> _playSettle(Stone stone) async {
    if (!_settleAudioReady) return;
    try {
      final pitch = (1.5 - stone.radius * 0.6).clamp(0.7, 1.4);
      await _settlePlayer.setPitch(pitch);
      await _settlePlayer.seek(Duration.zero);
      unawaited(_settlePlayer.play());
    } catch (_) {
      // Non-fatal — the settle animation still carries the feedback.
    }
  }

  Future<void> _playCollapse() async {
    if (!_collapseAudioReady) return;
    try {
      await _collapsePlayer.seek(Duration.zero);
      unawaited(_collapsePlayer.play());
    } catch (_) {
      // Non-fatal — the fall animation still carries the feedback.
    }
  }

  /// How far off the tower's central axis [globalPosition] sits, as a
  /// `[-1, 1]` fraction — dropping right on the axis gives 0; dropping
  /// within ~18% of the tower's width either side of it maxes out the lean.
  double _offsetFractionFor(Offset globalPosition, RenderBox box) {
    if (box.size.width == 0) return 0;
    final local = box.globalToLocal(globalPosition);
    final deviation = local.dx - box.size.width / 2;
    final sensitivity = box.size.width * 0.18;
    return (deviation / sensitivity).clamp(-1.0, 1.0);
  }

  void _onDrop(int id, Offset globalPosition) {
    final box = _towerKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    final offsetFraction = _offsetFractionFor(globalPosition, box);
    final stone = _cairn.byId(id);
    final outcome = _cairn.dropOnTop(id, offsetFraction: offsetFraction);

    if (outcome == DropOutcome.unstable) {
      final snapshot = _computeLayout(_cairn, box.size.width, box.size.height);
      setState(() {
        _fallingLayouts = snapshot;
        _fallToken++;
      });
      HapticFeedback.heavyImpact();
      unawaited(_playCollapse());
      _showToppledMessage();
      _collapseTimer?.cancel();
      _collapseTimer = Timer(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() {
          _cairn.collapse();
          _fallingLayouts = null;
          _settleTick.clear();
        });
      });
      return;
    }

    setState(() => _settleTick[id] = (_settleTick[id] ?? 0) + 1);
    HapticFeedback.lightImpact();
    unawaited(_playSettle(stone));
  }

  void _showToppledMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.cardSurface,
          content: Text(
            'The cairn toppled — too top-heavy or off-balance. Starting the '
            'tower over.',
            style: AppTextStyles.bodyStrong,
          ),
        ),
      );
  }

  void _newStones() {
    HapticFeedback.selectionClick();
    _collapseTimer?.cancel();
    setState(() {
      _cairn = _cairn.newRound(random: _random);
      _settleTick.clear();
      _fallingLayouts = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unplaced =
        _cairn.stones.where((s) => !_cairn.isPlaced(s.id)).toList();
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
              const BackHeader(title: 'Stone Cairn Balance'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _CairnIntro(),
                      const SizedBox(height: 16),
                      _CairnProgress(cairn: _cairn),
                      const SizedBox(height: 16),
                      _CairnTower(
                        towerKey: _towerKey,
                        cairn: _cairn,
                        settleTick: _settleTick,
                        fallingLayouts: _fallingLayouts,
                        fallToken: _fallToken,
                        onDrop: _onDrop,
                      ),
                      const SizedBox(height: 16),
                      if (unplaced.isNotEmpty)
                        _StoneTray(stones: unplaced)
                      else
                        const _CairnCompleteBanner(),
                      const SizedBox(height: 16),
                      _NewStonesButton(onTap: _newStones),
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

class _CairnIntro extends StatelessWidget {
  const _CairnIntro();

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
              const Icon(Icons.spa_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(
                'BALANCE FOCUS',
                style: AppTextStyles.badge.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Build Your Cairn', style: AppTextStyles.cardHeading),
          const SizedBox(height: 8),
          Text(
            'Drag each stone onto the tower — it settles on top, leaning a '
            'little toward whichever side you drop it. Keep bigger stones '
            'low and your drops centered, or the tower topples and you '
            'start again.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _CairnProgress extends StatelessWidget {
  const _CairnProgress({required this.cairn});

  final StoneCairn cairn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Stones placed', style: AppTextStyles.caption),
            Text(
              '${cairn.placedCount} / ${cairn.stoneCount}',
              style: AppTextStyles.badge.copyWith(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: cairn.fraction,
            minHeight: 8,
            backgroundColor: AppColors.cardSurface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.muted),
          ),
        ),
      ],
    );
  }
}

/// One stone's computed placement within the tower, in normalized `[0,1]`
/// arena coordinates.
class _StoneLayout {
  const _StoneLayout({
    required this.stone,
    required this.centerX,
    required this.centerY,
    required this.widthPx,
    required this.heightPx,
  });

  final Stone stone;
  final double centerX;
  final double centerY;
  final double widthPx;
  final double heightPx;
}

/// Where the bottom-most stone's base rests, as a fraction down the arena —
/// leaves room below for the pedestal shadow.
const double _groundY = 0.9;

/// How far a stone's lean nudges it off-axis, as a fraction of its own
/// width — kept small so the tower stays visually centered, like a real
/// cairn rather than a scattered pile.
const double _leanFraction = 0.22;

/// Computes each stacked stone's placement, bottom to top. A free function
/// (not tied to the tower widget) so a toppling drop can snapshot the
/// about-to-fall layout before [StoneCairn.collapse] clears the stack.
List<_StoneLayout> _computeLayout(StoneCairn cairn, double width, double height) {
  final layouts = <_StoneLayout>[];
  var bottomY = _groundY;
  for (final id in cairn.stackOrder) {
    final stone = cairn.byId(id);
    final widthPx = _stoneWidth(stone.radius);
    final heightPx = _stoneHeight(stone.radius);
    final heightFrac = heightPx / height;
    final centerYFrac = bottomY - heightFrac / 2;
    final leanPx = stone.offsetFraction * widthPx * _leanFraction;
    final centerXFrac = 0.5 + leanPx / width;
    layouts.add(
      _StoneLayout(
        stone: stone,
        centerX: centerXFrac,
        centerY: centerYFrac,
        widthPx: widthPx,
        heightPx: heightPx,
      ),
    );
    bottomY -= heightFrac * _nestOverlap;
  }
  return layouts;
}

class _CairnTower extends StatelessWidget {
  const _CairnTower({
    required this.towerKey,
    required this.cairn,
    required this.settleTick,
    required this.fallingLayouts,
    required this.fallToken,
    required this.onDrop,
  });

  final GlobalKey towerKey;
  final StoneCairn cairn;
  final Map<int, int> settleTick;
  final List<_StoneLayout>? fallingLayouts;
  final int fallToken;
  final void Function(int id, Offset globalPosition) onDrop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = max(0.0, width * 1.25);
        final falling = fallingLayouts;
        final layouts =
            falling == null ? _computeLayout(cairn, width, height) : null;
        return DragTarget<int>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) => onDrop(details.data, details.offset),
          builder: (context, incoming, rejected) {
            return Container(
              key: towerKey,
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.deepNavy,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: incoming.isNotEmpty
                      ? AppColors.seafoamBorder
                      : AppColors.tealBorder,
                  width: incoming.isNotEmpty ? 2 : 1,
                ),
              ),
              child: Stack(
                children: [
                  // A soft contact shadow where the tower meets the ground —
                  // this is a side-view elevation, not a top-down scatter.
                  Positioned(
                    left: width * 0.5 - width * 0.3,
                    top: height * _groundY - 6,
                    width: width * 0.6,
                    height: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: RadialGradient(
                          colors: [
                            AppColors.deepNavy.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                  if (cairn.placedCount == 0 && falling == null)
                    Align(
                      alignment: const Alignment(0, -0.2),
                      child: Text(
                        'Drag a stone here to start the tower',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.muted),
                      ),
                    ),
                  if (falling != null)
                    for (final layout in falling)
                      _FallingStone(
                        key: ValueKey('falling_${layout.stone.id}_$fallToken'),
                        layout: layout,
                        arenaSize: Size(width, height),
                      )
                  else
                    for (final layout in layouts!)
                      _PlacedStone(
                        key: ValueKey(
                          'stone_${layout.stone.id}_'
                          '${settleTick[layout.stone.id] ?? 0}',
                        ),
                        layout: layout,
                        arenaSize: Size(width, height),
                      ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PlacedStone extends StatelessWidget {
  const _PlacedStone({
    super.key,
    required this.layout,
    required this.arenaSize,
  });

  final _StoneLayout layout;
  final Size arenaSize;

  @override
  Widget build(BuildContext context) {
    final stone = layout.stone;
    final left = layout.centerX * arenaSize.width - layout.widthPx / 2;
    final top = layout.centerY * arenaSize.height - layout.heightPx / 2;
    final color =
        AppColors.stoneTones[stone.toneIndex % AppColors.stoneTones.length];
    final shape = _StoneShape(
      seed: stone.shapeSeed,
      color: color,
      width: layout.widthPx,
      height: layout.heightPx,
    );

    return Positioned(
      left: left,
      top: top,
      width: layout.widthPx,
      height: layout.heightPx,
      child: Draggable<int>(
        data: stone.id,
        feedback: SizedBox(
          width: layout.widthPx,
          height: layout.heightPx,
          child: Transform.rotate(angle: stone.tilt, child: shape),
        ),
        childWhenDragging: const SizedBox.shrink(),
        child: _SettlePop(
          child: Transform.rotate(angle: stone.tilt, child: shape),
        ),
      ),
    );
  }
}

/// A stone tumbling off the tower the instant it topples — animates from its
/// last standing position down past the bottom of the frame (clipped by the
/// tower's own [Clip.antiAlias]) with a sideways drift and extra spin, both
/// derived deterministically from the stone so a collapse always looks the
/// same for the same stone/lean but different stones scatter differently.
class _FallingStone extends StatelessWidget {
  const _FallingStone({super.key, required this.layout, required this.arenaSize});

  final _StoneLayout layout;
  final Size arenaSize;

  static const Duration duration = Duration(milliseconds: 750);

  @override
  Widget build(BuildContext context) {
    final stone = layout.stone;
    final startLeft = layout.centerX * arenaSize.width - layout.widthPx / 2;
    final startTop = layout.centerY * arenaSize.height - layout.heightPx / 2;
    final rng = Random(stone.shapeSeed);
    final driftSign = stone.offsetFraction.abs() > 0.05
        ? stone.offsetFraction.sign
        : (stone.id.isEven ? 1.0 : -1.0);
    final driftPx = driftSign * (24 + rng.nextDouble() * 56);
    final spin = driftSign * (1.1 + rng.nextDouble() * 1.8);
    final color =
        AppColors.stoneTones[stone.toneIndex % AppColors.stoneTones.length];
    final shape = _StoneShape(
      seed: stone.shapeSeed,
      color: color,
      width: layout.widthPx,
      height: layout.heightPx,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeIn,
      child: shape,
      builder: (context, progress, child) {
        final fallPx = progress * progress * arenaSize.height * 1.4;
        return Positioned(
          left: startLeft + driftPx * progress,
          top: startTop + fallPx,
          width: layout.widthPx,
          height: layout.heightPx,
          child: Transform.rotate(
            angle: stone.tilt + spin * progress,
            child: child,
          ),
        );
      },
    );
  }
}

/// Scales a freshly-built child up from a slight squash with a bouncy
/// overshoot — the "settling" feedback a dropped stone gets. Relies on being
/// given a fresh [Key] by the caller each time it should replay.
class _SettlePop extends StatelessWidget {
  const _SettlePop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

class _StoneTray extends StatelessWidget {
  const _StoneTray({required this.stones});

  final List<Stone> stones;

  @override
  Widget build(BuildContext context) {
    // Sized to fit the biggest possible stone (radius 1.0) so every stone —
    // tray or tower — renders at the exact same true-to-scale pixel size;
    // smaller stones just leave more breathing room in their own slot.
    final trayHeight = _stoneHeight(1.0) + 24;
    return SizedBox(
      height: trayHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final stone = stones[i];
          final width = _stoneWidth(stone.radius);
          final height = _stoneHeight(stone.radius);
          final color = AppColors
              .stoneTones[stone.toneIndex % AppColors.stoneTones.length];
          final shape =
              _StoneShape(seed: stone.shapeSeed, color: color, width: width, height: height);
          return SizedBox(
            width: width + 8,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Draggable<int>(
                data: stone.id,
                feedback:
                    SizedBox(width: width, height: height, child: shape),
                childWhenDragging: Opacity(opacity: 0.25, child: shape),
                child: shape,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A flattened, irregular river-stone silhouette derived deterministically
/// from [seed] (so the same stone always renders the same jagged outline),
/// shaded for a bit of glossy depth like a water-worn pebble.
class _StoneShape extends StatelessWidget {
  const _StoneShape({
    required this.seed,
    required this.color,
    required this.width,
    required this.height,
  });

  final int seed;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _StonePainter(seed: seed, baseColor: color)),
    );
  }
}

class _StonePainter extends CustomPainter {
  _StonePainter({required this.seed, required this.baseColor});

  final int seed;
  final Color baseColor;

  static const int _vertices = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width / 2 * 0.94;
    final ry = size.height / 2 * 0.9;

    final pts = <Offset>[
      for (var i = 0; i < _vertices; i++)
        () {
          final angle = (i / _vertices) * 2 * pi;
          final jitter = 0.86 + rng.nextDouble() * 0.14;
          return Offset(
            cx + cos(angle) * rx * jitter,
            cy + sin(angle) * ry * jitter,
          );
        }(),
    ];

    final path = Path()
      ..moveTo(
        (pts.first.dx + pts.last.dx) / 2,
        (pts.first.dy + pts.last.dy) / 2,
      );
    for (var i = 0; i < pts.length; i++) {
      final curr = pts[i];
      final next = pts[(i + 1) % pts.length];
      final mid = Offset((curr.dx + next.dx) / 2, (curr.dy + next.dy) / 2);
      path.quadraticBezierTo(curr.dx, curr.dy, mid.dx, mid.dy);
    }
    path.close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(baseColor, Colors.white, 0.35)!,
          baseColor,
          Color.lerp(baseColor, Colors.black, 0.32)!,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Color.lerp(baseColor, Colors.black, 0.4)!.withValues(
          alpha: 0.55,
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _StonePainter old) =>
      old.seed != seed || old.baseColor != baseColor;
}

class _CairnCompleteBanner extends StatelessWidget {
  const _CairnCompleteBanner();

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
          const Icon(Icons.check_circle, size: 22, color: AppColors.seafoam),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cairn complete!',
                  style: AppTextStyles.cardTitleSmall
                      .copyWith(color: AppColors.seafoam),
                ),
                const SizedBox(height: 2),
                Text(
                  'Every stone found a place in the tower. Pick any of them '
                  'back up to restack, or start a fresh cairn below.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewStonesButton extends StatelessWidget {
  const _NewStonesButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh, size: 18, color: AppColors.white),
                const SizedBox(width: 8),
                Text(
                  'New Stones',
                  style: AppTextStyles.buttonLarge
                      .copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
