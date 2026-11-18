import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/content_catalog_repository.dart';
import '../data/models/catalog_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';
import 'game_catalog.dart';

/// "Off-Watch Mind Games" hub (Stitch "offwatch_mind_games" redesign).
///
/// Seven tactile decompression games exist and are all fully playable, but
/// only **2** are shown/playable in any given week — a random (but
/// per-week-stable) pick, same window the server computes via
/// `rotation.featured_window` and Haven's preview row uses. This keeps the
/// catalog feeling fresh rather than dumping all seven on the player at
/// once. Before any sync — or offline — [weeklyGames] computes the same
/// pick client-side so the limit still holds.
///
/// (A "Celestial Wayfinder" featured-ritual placeholder used to sit above
/// this catalog — removed since it was never built; the slot can return
/// once a real constellation/wayfinding game exists.)
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

  /// The seven built-in games in their default catalog order — shared with
  /// Haven's preview row via [gameCatalog] so they can never drift apart.
  static const List<GameCatalogEntry> _games = gameCatalog;

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

  /// This week's 2 games: the server's real pick once synced (filtering the
  /// full catalog down to just those keys), else a client-computed
  /// [weeklyGames] fallback so the limit still applies offline/pre-sync.
  List<GameCatalogEntry> get _weeksGames {
    if (_featuredKeys.isEmpty) return weeklyGames(DateTime.now());
    return [for (final g in _games) if (_featuredKeys.contains(g.key)) g];
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

  void _openGame(BuildContext context, GameCatalogEntry game) {
    if (!game.ready) {
      _comingSoon(context, game.title);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => game.screenBuilder()));
  }

  @override
  Widget build(BuildContext context) {
    final games = _weeksGames;
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
                          Text(
                            '${games.length} of ${_games.length} this week',
                            style: AppTextStyles.caption,
                          ),
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
  });

  final String icon;
  final Color accent;
  final String title;
  final String badge;
  final String description;
  final String meta;
  final VoidCallback onTap;
  final bool ready;

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
