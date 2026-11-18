import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../data/games/calm_your_waves.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/glass_icon_button.dart';

/// Tile-face designs, one per possible pair at the top level (32 pairs = the
/// full 64-tile board). Index `i` is the icon for design id `i`.
const List<String> _designIcons = [
  AppAssets.anchor,
  AppAssets.arrowLeft,
  AppAssets.bookOpenText,
  AppAssets.camera,
  AppAssets.chartLine,
  AppAssets.circleX,
  AppAssets.clock,
  AppAssets.cloudFog,
  AppAssets.cloudRainWind,
  AppAssets.compass,
  AppAssets.decoWaves,
  AppAssets.helpCircle,
  AppAssets.info,
  AppAssets.insightsChart,
  AppAssets.lightbulbOff,
  AppAssets.lock,
  AppAssets.mail,
  AppAssets.mapPin,
  AppAssets.mic,
  AppAssets.moonStar,
  AppAssets.pause,
  AppAssets.pen,
  AppAssets.refreshCw,
  AppAssets.sailboat,
  AppAssets.send,
  AppAssets.shell,
  AppAssets.smilePlus,
  AppAssets.sparkles,
  AppAssets.users,
  AppAssets.volumeOff,
  AppAssets.waves,
  AppAssets.wind,
];

/// "Calm Your Waves" — a flash-and-recall memory-match game (Figma node 10:5
/// "mindful-game", now wired to real play).
///
/// Every tile on the board flashes face up for a moment at the start of a
/// level, then flips back down. The player taps pairs of tiles from memory;
/// a correct pair disappears, a wrong pair flips back after a brief peek.
/// Levels climb from 2 pairs (4 tiles) to the full 32 pairs (64 tiles) — see
/// [CalmYourWaves.pairCountsByLevel].
///
/// Reached from the guided-breathing screen (its info control) and from
/// Haven/Off-Watch Games, as an adjacent grounding activity. This game
/// intentionally awards no Fleet Knots — only mood check-ins, breathing
/// sessions and journal entries feed that economy (see Knot Master 3D).
class MindfulGameScreen extends StatefulWidget {
  const MindfulGameScreen({super.key, Random? random}) : _random = random;

  final Random? _random;

  @override
  State<MindfulGameScreen> createState() => _MindfulGameScreenState();
}

class _MindfulGameScreenState extends State<MindfulGameScreen> {
  late final Random _random = widget._random ?? Random();
  late CalmYourWaves _game = CalmYourWaves.level(0, random: _random);

  bool _previewing = true;
  Timer? _previewTimer;
  Timer? _mismatchTimer;

  @override
  void initState() {
    super.initState();
    _startPreview();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _mismatchTimer?.cancel();
    super.dispose();
  }

  /// Flashes every tile face up, then flips the board back down. A full 3
  /// seconds to actually memorize the board, regardless of level size — a
  /// split-second flash isn't enough time to take in a big board.
  static const Duration _previewDuration = Duration(seconds: 3);

  void _startPreview({double scale = 1.0}) {
    _previewTimer?.cancel();
    setState(() => _previewing = true);
    final ms = _previewDuration.inMilliseconds * scale;
    _previewTimer = Timer(Duration(milliseconds: ms.round()), () {
      if (!mounted) return;
      setState(() => _previewing = false);
    });
  }

  void _tap(int index) {
    if (_previewing) return;
    final result = _game.tap(index);
    switch (result) {
      case CalmTapResult.ignored:
        break;
      case CalmTapResult.picked:
        HapticFeedback.selectionClick();
        setState(() {});
      case CalmTapResult.matched:
        HapticFeedback.lightImpact();
        setState(() {});
      case CalmTapResult.mismatch:
        HapticFeedback.heavyImpact();
        setState(() {});
        _mismatchTimer?.cancel();
        _mismatchTimer = Timer(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          setState(() => _game.clearMismatch());
        });
    }
  }

  void _hint() {
    if (_previewing || _game.hasPendingMismatch || _game.isComplete) return;
    HapticFeedback.selectionClick();
    _startPreview(scale: 0.5);
  }

  void _shuffle() {
    _mismatchTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() => _game = _game.retryLevel());
    _startPreview();
  }

  void _nextLevel() {
    HapticFeedback.mediumImpact();
    setState(() => _game = _game.nextLevel());
    _startPreview();
  }

  void _playAgain() {
    HapticFeedback.mediumImpact();
    setState(() => _game = _game.restart());
    _startPreview();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          child: SizedBox.expand(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  _Header(onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 24),
                  _StatsRow(game: _game),
                  const SizedBox(height: 16),
                  _Progress(game: _game),
                  const SizedBox(height: 24),
                  _Board(game: _game, previewing: _previewing, onTap: _tap),
                  const SizedBox(height: 24),
                  if (_game.isComplete)
                    _CompleteBanner(
                      hasNextLevel: _game.hasNextLevel,
                      onNext: _game.hasNextLevel ? _nextLevel : _playAgain,
                    )
                  else
                    _ActionRow(onHint: _hint, onShuffle: _shuffle),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GlassIconButton(icon: AppAssets.arrowLeft, onTap: onBack),
            Flexible(
              child: Text(
                'Calm Your Waves',
                textAlign: TextAlign.center,
                style: AppTextStyles.headerTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GlassIconButton(
              icon: AppAssets.info,
              iconColor: AppColors.cream,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Memorize the flash, then match every pair',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.game});

  final CalmYourWaves game;

  @override
  Widget build(BuildContext context) {
    final levelNumber = game.levelIndex + 1;
    final levelTotal = CalmYourWaves.pairCountsByLevel.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LEVEL',
                style: AppTextStyles.caption.copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                '$levelNumber / $levelTotal',
                style: AppTextStyles.statValue,
              ),
            ],
          ),
          Container(width: 1, height: 32, color: AppColors.glassBorder),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAIRS MATCHED',
                style: AppTextStyles.caption.copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                '${game.matchedPairs} / ${game.pairCount}',
                style: AppTextStyles.statValue.copyWith(
                  color: AppColors.seafoam,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.game});

  final CalmYourWaves game;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Board cleared', style: AppTextStyles.caption),
            Text(
              '${(game.fraction * 100).round()}%',
              style: AppTextStyles.badge.copyWith(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: game.fraction,
            minHeight: 8,
            backgroundColor: AppColors.cardSurface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.seafoam),
          ),
        ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.game,
    required this.previewing,
    required this.onTap,
  });

  final CalmYourWaves game;
  final bool previewing;
  final ValueChanged<int> onTap;

  static const double _spacing = 10;

  static int _columnsFor(int tileCount) => sqrt(tileCount).round().clamp(2, 8);

  @override
  Widget build(BuildContext context) {
    final mismatch = game.pendingMismatch;
    final columns = _columnsFor(game.tileCount);
    // Tiles stay the same physical size on every level: the extent is sized
    // against the biggest board (the final level), so a 4-tile board just
    // renders a smaller, centered grid rather than oversized blocks.
    final maxTileCount = CalmYourWaves.pairCountsByLevel.last * 2;
    final maxColumns = _columnsFor(maxTileCount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileExtent =
            (constraints.maxWidth - (maxColumns - 1) * _spacing) / maxColumns;
        final gridWidth = columns * tileExtent + (columns - 1) * _spacing;

        return Center(
          child: SizedBox(
            width: gridWidth,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: game.tileCount,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: _spacing,
                mainAxisSpacing: _spacing,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, i) {
                final design = game.designs[i];
                final matched = game.isMatched(i);
                final faceUp = previewing || game.isFaceUp(i);
                final wrong = !previewing && mismatch.contains(i);
                return _GameTile(
                  key: ValueKey('calm_tile_$i'),
                  icon: _designIcons[design % _designIcons.length],
                  matched: matched,
                  faceUp: faceUp,
                  wrong: wrong,
                  onTap: matched ? null : () => onTap(i),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    super.key,
    required this.icon,
    required this.matched,
    required this.faceUp,
    required this.wrong,
    required this.onTap,
  });

  final String icon;
  final bool matched;
  final bool faceUp;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: matched ? 0.22 : 1,
        duration: const Duration(milliseconds: 250),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _background(),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border(), width: wrong ? 2 : 1),
            boxShadow: matched
                ? const [BoxShadow(color: AppColors.teal, blurRadius: 6)]
                : null,
          ),
          child: Center(
            child: faceUp || matched
                ? SvgPicture.asset(
                    icon,
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(
                      matched ? AppColors.white : _iconColor(),
                      BlendMode.srcIn,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Color _background() {
    if (matched) return AppColors.teal;
    if (wrong) return AppColors.stormFaint;
    if (faceUp) return AppColors.seafoamFaint;
    return AppColors.cardSurface;
  }

  Color _border() {
    if (matched) return AppColors.seafoam;
    if (wrong) return AppColors.stormRed;
    if (faceUp) return AppColors.seafoamBorder;
    return AppColors.glassBorderSoft;
  }

  Color _iconColor() => wrong ? AppColors.stormRed : AppColors.seafoam;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.onHint, required this.onShuffle});

  final VoidCallback onHint;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: AppAssets.sparkles,
            label: 'Hint',
            onTap: onHint,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionButton(
            icon: AppAssets.refreshCw,
            label: 'Shuffle',
            onTap: onShuffle,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(icon, width: 16, height: 16),
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

class _CompleteBanner extends StatelessWidget {
  const _CompleteBanner({required this.hasNextLevel, required this.onNext});

  final bool hasNextLevel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final title = hasNextLevel ? 'Board cleared!' : 'All Waves Calmed!';
    final body = hasNextLevel
        ? 'Every pair found. Ready for a bigger board?'
        : 'You cleared the full 32-pair board. Cast off and calm it again.';
    final label = hasNextLevel ? 'Next Level' : 'Play Again';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                      title,
                      style: AppTextStyles.cardTitleSmall
                          .copyWith(color: AppColors.seafoam),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: AppColors.seafoam,
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            child: InkWell(
              onTap: onNext,
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      AppAssets.refreshCw,
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                        AppColors.onAccent,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: AppTextStyles.buttonLarge
                          .copyWith(color: AppColors.onAccent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
