import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/tide_bottom_nav.dart';
import 'community_connect_screen.dart';
import 'haven_screen.dart';
import 'journal_entry_screen.dart';
import 'off_watch_games_screen.dart';
import 'story_playback_screen.dart';
import 'weekly_insights_screen.dart';

/// Main app dashboard shown after onboarding — the "Helm" (Stitch
/// "helm_dashboard" redesign).
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const TideBottomNav(active: TideTab.helm),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashboardHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StoryPromoBanner(
                        onTap: () => _open(
                          context,
                          const StoryPlaybackScreen(
                            story: SeaStories.lighthouse,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SectionHeader(
                        'Mental Helm Controls',
                        trailing: 'Customize',
                      ),
                      const SizedBox(height: 16),
                      _FeatureGrid(
                        onHaven: () => _open(context, const HavenScreen()),
                        onJournal: () =>
                            _open(context, const JournalEntryScreen()),
                        onCrew: () =>
                            _open(context, const CommunityConnectScreen()),
                        onReflect: () =>
                            _open(context, const WeeklyInsightsScreen()),
                      ),
                      const SizedBox(height: 24),
                      _MindGamesSection(
                        onSeeAll: () =>
                            _open(context, const OffWatchGamesScreen()),
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

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Decorative full-bleed wave strip.
        SizedBox(
          height: 16,
          width: double.infinity,
          child: SvgPicture.asset(
            AppAssets.decoWaves,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _UserProfileBar(),
              SizedBox(height: 16),
              _VoyageBanner(),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserProfileBar extends StatelessWidget {
  const _UserProfileBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ahoy, First Mate', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 4),
              Text(
                'Marcus Thorne',
                style: AppTextStyles.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.cream,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(AppAssets.avatar, fit: BoxFit.cover),
        ),
      ],
    );
  }
}

class _VoyageBanner extends StatelessWidget {
  const _VoyageBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      ),
      child: Row(
        children: [
          SvgPicture.asset(AppAssets.compass, width: 24, height: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Day 42 at Sea', style: AppTextStyles.labelStrong),
                const SizedBox(height: 2),
                Text(
                  'Voyage: Yokohama to Valparaiso',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Off-Watch Story promo banner
// ---------------------------------------------------------------------------

class _StoryPromoBanner extends StatelessWidget {
  const _StoryPromoBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealFaint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                  border: Border.all(color: AppColors.tealBorder),
                ),
                child: SvgPicture.asset(
                  AppAssets.moonStar,
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    AppColors.seafoam,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'OFF-WATCH STORY',
                            style: AppTextStyles.badge.copyWith(
                              color: AppColors.sand,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('14 min', style: AppTextStyles.caption),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The Lighthouse at Cape Horn',
                      style: AppTextStyles.cardTitleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.seafoam,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 20,
                  color: AppColors.onAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.cream),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Text(
            trailing!,
            style: AppTextStyles.caption.copyWith(color: AppColors.seafoam),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Feature grid
// ---------------------------------------------------------------------------

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.onHaven,
    required this.onJournal,
    required this.onCrew,
    required this.onReflect,
  });

  final VoidCallback onHaven;
  final VoidCallback onJournal;
  final VoidCallback onCrew;
  final VoidCallback onReflect;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 12);
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FeatureTile(
                  icon: AppAssets.waves,
                  iconColor: AppColors.seafoam,
                  title: 'Haven',
                  subtitle: 'Calm Drills, Stories & Tidal Breath',
                  badge: '3 Ready',
                  onTap: onHaven,
                ),
              ),
              gap,
              Expanded(
                child: _FeatureTile(
                  icon: AppAssets.bookOpenText,
                  iconColor: AppColors.teal,
                  title: 'Journal & Log',
                  subtitle: 'Shift debrief & private thoughts',
                  onTap: onJournal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FeatureTile(
                  icon: AppAssets.anchor,
                  iconColor: AppColors.seafoam,
                  title: 'Crew & Fleet',
                  subtitle: 'Anchor pool & spirit leaderboard',
                  onTap: onCrew,
                ),
              ),
              gap,
              Expanded(
                child: _FeatureTile(
                  icon: AppAssets.chartLine,
                  iconColor: AppColors.sand,
                  title: 'Reflect',
                  subtitle: 'Weekly swell horizon & trends',
                  onTap: onReflect,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final String icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        icon,
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.seafoamFaint,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        border: Border.all(color: AppColors.seafoamBorder),
                      ),
                      child: Text(
                        badge!,
                        style: AppTextStyles.badge.copyWith(fontSize: 9),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: AppTextStyles.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.caption, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Off-Watch Mind Games
// ---------------------------------------------------------------------------

class _MindGamesSection extends StatelessWidget {
  const _MindGamesSection({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OFF-WATCH MIND GAMES',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.cream,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tactile cognitive focus & sensory decompression',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  'See All',
                  style: AppTextStyles.caption.copyWith(color: AppColors.seafoam),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _GameCard(
                duration: '2 min',
                durationColor: AppColors.sand,
                category: 'Pattern Puzzle',
                title: 'Celestial Wayfinder',
                subtitle: 'Polynesian star alignment puzzle',
                icon: Icons.auto_awesome,
                onTap: onSeeAll,
              ),
              const SizedBox(width: 12),
              _GameCard(
                duration: '5 min',
                durationColor: AppColors.seafoam,
                category: 'Stress Relief',
                title: 'Knot Master 3D',
                subtitle: 'Tactile rope detangling focus',
                icon: Icons.gesture,
                onTap: onSeeAll,
              ),
              const SizedBox(width: 12),
              _GameCard(
                duration: '3 min',
                durationColor: AppColors.teal,
                category: 'Audio Focus',
                title: 'Sonar Echo Ping',
                subtitle: 'Memory rhythm for post-watch drift',
                icon: Icons.graphic_eq,
                onTap: onSeeAll,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.duration,
    required this.durationColor,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String duration;
  final Color durationColor;
  final String category;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          width: 208,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      duration,
                      style: AppTextStyles.badge.copyWith(color: durationColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      category,
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.deepNavy,
                    borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                    border: Border.all(color: AppColors.glassBorderSoft),
                  ),
                  child: Center(
                    child: Icon(icon, size: 28, color: durationColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTextStyles.cardTitleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
