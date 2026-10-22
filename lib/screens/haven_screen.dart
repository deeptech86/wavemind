import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/ambient_pulse_background.dart';
import '../widgets/tide_bottom_nav.dart';
import 'guided_breathing_screen.dart';
import 'story_playback_screen.dart';

/// "Safe Haven" hub (Stitch "haven_calming_drills" redesign).
///
/// Replaces the old direct-to-breathing "Breathe" tab: the hub gathers the
/// Tidal Breath regulation session, watch-reset drills, sleep lore / sea
/// stories, and ambient soundscapes. The Tidal Breath CTA and the story cards
/// navigate to working screens, and (Stage 2) the Ambient Cabin Soundscape
/// tiles toggle real looping playback of their generated beds — one at a time,
/// with a meditative glow behind the active tile. The watch-reset drills remain
/// presentational.
class HavenScreen extends StatefulWidget {
  const HavenScreen({super.key});

  @override
  State<HavenScreen> createState() => _HavenScreenState();
}

class _HavenScreenState extends State<HavenScreen> {
  /// Soundscape tile index -> looping ambient bed. Only one plays at a time.
  static const List<String> _soundAssets = [
    AppAssets.audioRollingDeepSea,
    AppAssets.audioSteelHullRain,
    AppAssets.audioFoghornBell,
  ];

  final AudioPlayer _ambientPlayer = AudioPlayer();
  int? _activeSound;
  bool _ambientPlaying = false;

  @override
  void initState() {
    super.initState();
    _ambientPlayer.playingStream.listen((playing) {
      if (mounted) setState(() => _ambientPlaying = playing);
    });
    // Ease into Haven with a calm ambient bed already playing. Placeholder
    // track for now — swap AppAssets.audioRollingDeepSea for a dedicated
    // "calm" bed once one is supplied.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _toggleSound(0);
    });
  }

  @override
  void dispose() {
    _ambientPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleSound(int index) async {
    // Tapping the active tile stops it; tapping another switches the bed.
    if (_activeSound == index) {
      setState(() => _activeSound = null);
      await _ambientPlayer.stop();
      return;
    }
    setState(() => _activeSound = index);
    try {
      await _ambientPlayer.setAsset(_soundAssets[index]);
      await _ambientPlayer.setLoopMode(LoopMode.one);
      await _ambientPlayer.play();
    } catch (_) {
      // No audio hardware (tests / unsupported): keep the visual selection.
    }
  }

  /// Today's rotating pair of sleep-lore stories: the first renders as the
  /// featured card, any remaining as compact list rows. See [dailyLore].
  List<Widget> _buildTodaysLore(BuildContext context) {
    final todays = dailyLore(DateTime.now(), SeaStories.all);
    if (todays.isEmpty) return const [];
    final widgets = <Widget>[
      _FeaturedLore(
        title: todays.first.title,
        subtitle: todays.first.teaserSubtitle,
        badge: "Tonight's Pick",
        onTap: () => _openStory(todays.first),
      ),
    ];
    for (final story in todays.skip(1)) {
      widgets
        ..add(const SizedBox(height: 12))
        ..add(
          _LoreItem(
            title: story.title,
            subtitle: story.teaserSubtitle,
            onTap: () => _openStory(story),
          ),
        );
    }
    return widgets;
  }

  Future<void> _openStory(StoryData story) async {
    // Hand the audio focus to the narration screen.
    if (_activeSound != null) {
      setState(() => _activeSound = null);
      await _ambientPlayer.stop();
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryPlaybackScreen(story: story),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const TideBottomNav(active: TideTab.breathe),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HavenHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TidalBreathHero(
                        onCastSwell: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const GuidedBreathingScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SectionHeader(
                        title: 'Watch Reset Drills',
                        trailing: '3 Active Drills',
                      ),
                      const SizedBox(height: 12),
                      const _DrillsRow(),
                      const SizedBox(height: 24),
                      const _SectionHeader(
                        title: 'Sleep Lore & Horizon Tales',
                        trailing: '350MB Cached',
                      ),
                      const SizedBox(height: 12),
                      ..._buildTodaysLore(context),
                      const SizedBox(height: 24),
                      const _SectionHeader(
                        title: 'Ambient Cabin Soundscapes',
                        trailing: 'Continuous Mix',
                      ),
                      const SizedBox(height: 12),
                      _SoundscapeGrid(
                        active: _activeSound,
                        playing: _ambientPlaying,
                        onToggle: _toggleSound,
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

class _HavenHeader extends StatelessWidget {
  const _HavenHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.seafoam,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'BEAUFORT 3 • GENTLE SWELL',
                          style: AppTextStyles.badge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const _MiniPill(icon: Icons.cloud_off, label: 'Offline Cached'),
            ],
          ),
          const SizedBox(height: 14),
          Text('Safe Haven', style: AppTextStyles.headerTitle),
          const SizedBox(height: 4),
          Text(
            'Calm waters, sea lore & off-watch decompression',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.muted),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.cream),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          trailing,
          style: AppTextStyles.caption.copyWith(color: AppColors.seafoam),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tidal Breath hero
// ---------------------------------------------------------------------------

class _TidalBreathHero extends StatelessWidget {
  const _TidalBreathHero({required this.onCastSwell});

  final VoidCallback onCastSwell;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.teal, AppColors.cardSurface],
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 10),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.overlayDark,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  AppAssets.waves,
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(
                    AppColors.seafoam,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 6),
                Text('OFF-WATCH REGULATION', style: AppTextStyles.badge),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Tidal Breath', style: AppTextStyles.cardHeading),
          const SizedBox(height: 6),
          Text(
            'Ride the rhythmic ocean swell to down-regulate your vagus nerve.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.tealTint),
          ),
          const SizedBox(height: 16),
          _MiniOrb(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: AppColors.seafoam,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '4-7-8 Ocean Pace • 5 min',
                  style: AppTextStyles.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: InkWell(
              onTap: onCastSwell,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cast Swell',
                      style: AppTextStyles.buttonSmall.copyWith(
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.play_arrow,
                      size: 18,
                      color: AppColors.teal,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniOrb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.seafoam.withValues(alpha: 0.15),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.seafoam.withValues(alpha: 0.25),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.breatheOrbGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal,
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(
                AppAssets.wind,
                width: 22,
                height: 22,
                colorFilter: const ColorFilter.mode(
                  AppColors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Watch reset drills (static)
// ---------------------------------------------------------------------------

class _DrillsRow extends StatelessWidget {
  const _DrillsRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 172,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _DrillCard(
            icon: AppAssets.cloudRainWind,
            iconColor: AppColors.stormRed,
            tag: 'High Stress',
            tagColor: AppColors.stormRed,
            title: 'Heavy Weather Reset',
            body:
                'Emergency somato-sensory grounding drill for pitch swells '
                'and storm watches.',
            meta: '3 min • Audio guide',
          ),
          SizedBox(width: 12),
          _DrillCard(
            icon: AppAssets.volumeOff,
            iconColor: AppColors.sand,
            tag: 'Noise Relief',
            tagColor: AppColors.sand,
            title: 'Engine Sound-Down',
            body:
                'Progressive somatic muscle release after 6 continuous hours '
                'in high decibels.',
            meta: '7 min • Guided',
          ),
          SizedBox(width: 12),
          _DrillCard(
            icon: AppAssets.anchor,
            iconColor: AppColors.seafoam,
            tag: 'Bunk Pre-Sleep',
            tagColor: AppColors.seafoam,
            title: 'Anchor Drop',
            body:
                'Head-to-toe gravity surrender to sleep steadily within '
                'rolling bunk quarters.',
            meta: '10 min • Body scan',
          ),
        ],
      ),
    );
  }
}

class _DrillCard extends StatelessWidget {
  const _DrillCard({
    required this.icon,
    required this.iconColor,
    required this.tag,
    required this.tagColor,
    required this.title,
    required this.body,
    required this.meta,
  });

  final String icon;
  final Color iconColor;
  final String tag;
  final Color tagColor;
  final String title;
  final String body;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
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
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  icon,
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.glassFillFaint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  tag,
                  style: AppTextStyles.badge.copyWith(
                    color: tagColor,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTextStyles.cardTitleSmall,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              body,
              style: AppTextStyles.caption.copyWith(height: 1.35),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  meta,
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.glassFill,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 16,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sleep lore & sea stories
// ---------------------------------------------------------------------------

class _FeaturedLore extends StatelessWidget {
  const _FeaturedLore({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
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
              _LoreThumb(size: 80),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sandFaint,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      child: Text(
                        badge,
                        style: AppTextStyles.badge.copyWith(
                          color: AppColors.sand,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: AppTextStyles.cardTitleSmall,
                      maxLines: 1,
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
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.seafoam,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 18,
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

class _LoreThumb extends StatelessWidget {
  const _LoreThumb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.welcomeMid, AppColors.deepNavy],
        ),
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        AppAssets.moonStar,
        width: size * 0.4,
        height: size * 0.4,
        colorFilter: ColorFilter.mode(
          AppColors.cream.withValues(alpha: 0.85),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _LoreItem extends StatelessWidget {
  const _LoreItem({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _LoreThumb(size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyStrong,
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
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.glassFill,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 16,
                  color: AppColors.white,
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
// Ambient soundscapes (visual toggle only)
// ---------------------------------------------------------------------------

class _SoundscapeGrid extends StatelessWidget {
  const _SoundscapeGrid({
    required this.active,
    required this.playing,
    required this.onToggle,
  });

  final int? active;
  final bool playing;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    const tiles = [
      (Icons.water, 'Rolling Deep Sea', 'Low Frequency'),
      (Icons.grain, 'Steel Hull Rain', 'White Noise'),
      (Icons.notifications_active_outlined, 'Foghorn & Bell', 'Distant Anchor'),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _SoundTile(
              icon: tiles[i].$1,
              label: tiles[i].$2,
              sub: tiles[i].$3,
              selected: active == i,
              playing: active == i && playing,
              onTap: () => onToggle(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.selected,
    required this.playing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.seafoamFaint : AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        child: AmbientPulseBackground(
          playing: playing,
          period: const Duration(seconds: 6),
          intensity: 0.8,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusTile),
              border: Border.all(
                color: selected ? AppColors.seafoamBorder : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.glassFill,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected ? AppColors.seafoam : AppColors.cream,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
