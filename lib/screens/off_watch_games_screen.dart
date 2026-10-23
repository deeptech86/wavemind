import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../data/content_catalog_repository.dart';
import '../data/models/catalog_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';
import 'cabin_dominoes_screen.dart';
import 'knot_master_screen.dart';
import 'mindful_game_screen.dart';
import 'sextant_horizon_screen.dart';

/// Immutable catalog entry for one of the five built-in off-watch games. The
/// set of games is fixed in the app; the server only controls which are
/// *featured* this week (a spotlight, never a gate — all five stay playable).
class _GameEntry {
  const _GameEntry({
    required this.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.badge,
    required this.description,
    required this.meta,
    required this.ready,
  });

  final String key;
  final String icon;
  final Color accent;
  final String title;
  final String badge;
  final String description;
  final String meta;
  final bool ready;
}

/// "Off-Watch Mind Games" hub (Stitch "offwatch_mind_games" redesign).
///
/// A featured focus ritual plus the catalog of five tactile decompression
/// games. Four are wired through and playable; "Fog Signal Echo" and the
/// featured ritual remain presentational and surface a "coming soon" cue.
///
/// Which games carry a "Featured this week" spotlight (and sort first) is
/// driven by the content catalog's `featured_game` flags, synced on open.
/// Before any sync — or offline — all five show normally in their default
/// order. Featuring never hides a game.
class OffWatchGamesScreen extends StatefulWidget {
  const OffWatchGamesScreen({super.key, ContentCatalogRepository? catalog})
    : _catalog = catalog;

  final ContentCatalogRepository? _catalog;

  @override
  State<OffWatchGamesScreen> createState() => _OffWatchGamesScreenState();
}

class _OffWatchGamesScreenState extends State<OffWatchGamesScreen> {
  late final ContentCatalogRepository _catalog =
      widget._catalog ?? ContentCatalogRepository();

  /// The five built-in games in their default catalog order.
  static const List<_GameEntry> _games = [
    _GameEntry(
      key: GameKeys.calmYourWaves,
      icon: AppAssets.waves,
      accent: AppColors.seafoam,
      title: 'Calm Your Waves',
      badge: 'Ready',
      description:
          'Match soothing ocean pairs to quiet the mind between watches.',
      meta: '2-4m • Memory match',
      ready: true,
    ),
    _GameEntry(
      key: GameKeys.knotMaster,
      icon: AppAssets.anchor,
      accent: AppColors.teal,
      title: 'Knot Master 3D',
      badge: 'Ready',
      description:
          'Run the rope through every loop and close it clean — no crossing '
          'lines — with haptic feedback.',
      meta: 'Haptics on • 4-6m',
      ready: true,
    ),
    _GameEntry(
      key: GameKeys.fogSignalEcho,
      icon: AppAssets.cloudFog,
      accent: AppColors.sand,
      title: 'Fog Signal Echo',
      badge: 'Auditory Calm',
      description:
          'Sound & pitch pattern recognition imitating foghorns echoing '
          'through dense squalls.',
      meta: 'Binaural Low-Hz • 6m',
      ready: false,
    ),
    _GameEntry(
      key: GameKeys.sextantHorizon,
      icon: AppAssets.compass,
      accent: AppColors.seafoam,
      title: 'Sextant Horizon Balance',
      badge: 'Ready',
      description:
          'Gentle gyroscopic horizon leveler keeping the spirit bubble '
          'centered against swell roll.',
      meta: 'Gyro sensory • 3-5m',
      ready: true,
    ),
    _GameEntry(
      key: GameKeys.cabinDominoes,
      icon: AppAssets.shell,
      accent: AppColors.sand,
      title: 'Cabin Dominoes',
      badge: 'Ready',
      description:
          'Cozy pass-and-play dominoes to challenge an off-watch crewmate on '
          'one device, no internet.',
      meta: 'Pass & play • 2 crew',
      ready: true,
    ),
  ];

  /// Keys spotlighted this week; empty until a sync lands (default display).
  Set<String> _featuredKeys = const {};

  @override
  void initState() {
    super.initState();
    _loadAndSync();
  }

  Future<void> _loadAndSync() async {
    final cached = await _catalog.loadCached();
    if (!mounted) return;
    if (cached.featuredGames.isNotEmpty) {
      setState(() => _featuredKeys = _keysOf(cached.featuredGames));
    }
    final fresh = await _catalog.sync();
    if (!mounted || fresh == null) return;
    setState(() => _featuredKeys = _keysOf(fresh.featuredGames));
  }

  static Set<String> _keysOf(List<FeaturedGame> games) =>
      {for (final g in games) g.gameKey};

  @override
  void dispose() {
    _catalog.dispose();
    super.dispose();
  }

  /// Games ordered featured-first (spotlight), preserving default order within
  /// each group. All five are always present.
  List<_GameEntry> get _orderedGames {
    final featured = [for (final g in _games) if (_featuredKeys.contains(g.key)) g];
    final rest = [for (final g in _games) if (!_featuredKeys.contains(g.key)) g];
    return [...featured, ...rest];
  }

  void _comingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.cardSurface,
          content: Text(
            '$name drops anchor in a future update.',
            style: AppTextStyles.bodyStrong,
          ),
        ),
      );
  }

  void _openGame(BuildContext context, _GameEntry game) {
    switch (game.key) {
      case GameKeys.calmYourWaves:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MindfulGameScreen()),
        );
      case GameKeys.knotMaster:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const KnotMasterScreen()),
        );
      case GameKeys.sextantHorizon:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SextantHorizonScreen()),
        );
      case GameKeys.cabinDominoes:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CabinDominoesScreen()),
        );
      default:
        _comingSoon(context, game.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final games = _orderedGames;
    final tiles = <Widget>[];
    for (var i = 0; i < games.length; i++) {
      final game = games[i];
      if (i > 0) tiles.add(const SizedBox(height: 12));
      tiles.add(
        _CatalogTile(
          icon: game.icon,
          accent: game.accent,
          title: game.title,
          badge: game.badge,
          description: game.description,
          meta: game.meta,
          ready: game.ready,
          featured: _featuredKeys.contains(game.key),
          onTap: () => _openGame(context, game),
        ),
      );
    }

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
              const BackHeader(title: 'Off-Watch Mind Games'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _IntroCard(),
                      const SizedBox(height: 20),
                      _FeaturedRitual(
                        onPlay: () =>
                            _comingSoon(context, 'Celestial Wayfinder'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.grid_view,
                            size: 18,
                            color: AppColors.seafoam,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Maritime Mind Catalog',
                              style: AppTextStyles.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('5 in fleet', style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...tiles,
                      const SizedBox(height: 20),
                      const _NightVisionNotice(),
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

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              const Icon(
                Icons.bedtime_outlined,
                size: 14,
                color: AppColors.seafoam,
              ),
              const SizedBox(width: 6),
              Text(
                'DOG WATCH DECOMPRESSION',
                style: AppTextStyles.badge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Decompress Between Watches',
            style: AppTextStyles.cardHeading,
          ),
          const SizedBox(height: 8),
          Text(
            'Tactile, low-stimulation focus puzzles designed to decelerate '
            'heart rate and untangle mental strain without blue-light fatigue.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 15,
                color: AppColors.seafoam,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Zero latency • Works completely detached from shore networks',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturedRitual extends StatelessWidget {
  const _FeaturedRitual({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.seafoamBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 10),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.seafoam),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'FEATURED FOCUS RITUAL',
                        style: AppTextStyles.badge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sandFaint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  'Astrometry Mode',
                  style: AppTextStyles.badge.copyWith(color: AppColors.sand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Celestial Wayfinder', style: AppTextStyles.cardHeading),
          const SizedBox(height: 4),
          Text(
            'Nautical astrometry: align the night constellation grid to true '
            'magnetic north.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 14),
          const _ConstellationArena(),
          const SizedBox(height: 14),
          const _RitualStats(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.seafoam,
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              child: InkWell(
                onTap: onPlay,
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        size: 20,
                        color: AppColors.onAccent,
                      ),
                      const SizedBox(width: 8),
                      Text('Play Alignment', style: AppTextStyles.buttonLarge),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstellationArena extends StatelessWidget {
  const _ConstellationArena();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.deepNavy,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.tealBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(128, AppColors.tealBorder),
          _ring(96, AppColors.glassBorder),
          _ring(64, AppColors.sandFaint),
          const _Star(alignment: Alignment(-0.5, -0.5), size: 9),
          const _Star(alignment: Alignment(0.55, -0.4), size: 7),
          const _Star(alignment: Alignment(0.45, 0.5), size: 7),
          const _Star(alignment: Alignment(-0.45, 0.55), size: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.overlayDark,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: AppColors.tealBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.navigation_outlined,
                  size: 14,
                  color: AppColors.seafoam,
                ),
                const SizedBox(width: 6),
                Text(
                  'Bearing: 194° S by W',
                  style: AppTextStyles.caption.copyWith(color: AppColors.cream),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color),
      ),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.alignment, required this.size});

  final Alignment alignment;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.sand,
          boxShadow: [
            BoxShadow(
              color: AppColors.sand.withValues(alpha: 0.6),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _RitualStats extends StatelessWidget {
  const _RitualStats();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: const [
            Expanded(
              child: _Stat(
                label: 'Difficulty',
                value: 'Calm Seas',
                color: AppColors.seafoam,
              ),
            ),
            VerticalDivider(color: AppColors.glassBorder, width: 1),
            Expanded(
              child: _Stat(
                label: 'Cognitive Load',
                value: '-28% HRV',
                color: AppColors.teal,
              ),
            ),
            VerticalDivider(color: AppColors.glassBorder, width: 1),
            Expanded(
              child: _Stat(
                label: 'Est. Time',
                value: '5-8 mins',
                color: AppColors.sand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyStrong.copyWith(color: color),
        ),
      ],
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.badge,
    required this.description,
    required this.meta,
    required this.onTap,
    this.ready = false,
    this.featured = false,
  });

  final String icon;
  final Color accent;
  final String title;
  final String badge;
  final String description;
  final String meta;
  final VoidCallback onTap;
  final bool ready;

  /// Spotlight flag from the server's weekly featured set. Adds a "Featured
  /// this week" marker + highlighted border; never affects playability.
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: featured
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(color: AppColors.seafoamBorder),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                ),
                child: SvgPicture.asset(
                  icon,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (featured) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 12,
                            color: AppColors.seafoam,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'FEATURED THIS WEEK',
                            style: AppTextStyles.badge.copyWith(
                              color: AppColors.seafoam,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.cardTitleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Badge(label: badge, accent: accent, filled: ready),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(meta, style: AppTextStyles.caption),
                        ),
                        Text(
                          ready ? 'Play' : 'Preview',
                          style: AppTextStyles.caption.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 16, color: accent),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.accent,
    required this.filled,
  });

  final String label;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.seafoamFaint : AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: filled ? AppColors.seafoamBorder : AppColors.glassBorder,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.badge.copyWith(color: accent, fontSize: 9),
      ),
    );
  }
}

class _NightVisionNotice extends StatelessWidget {
  const _NightVisionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sandFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.nightlight_round, size: 20, color: AppColors.sand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BRIDGE SAFE SPECTRUM',
                  style: AppTextStyles.badge.copyWith(color: AppColors.sand),
                ),
                const SizedBox(height: 4),
                Text(
                  'Colors and lumens are calibrated to protect night vision '
                  'before the midnight watch handover.',
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
