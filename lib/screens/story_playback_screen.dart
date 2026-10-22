import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_assets.dart';
import '../data/models/catalog_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/ambient_pulse_background.dart';
import '../widgets/back_header.dart';
import '../widgets/glass_icon_button.dart';

/// Immutable content for a single narrated sea story. The playback screen is
/// driven entirely by this model so it can host any story in the catalog, not
/// just the featured "Lighthouse at Cape Horn".
///
/// As of Stage 2 the player drives real narration via [audioAsset]; the static
/// [currentTime]/[remainingTime]/[progress] fields remain as the design's
/// resting-state presentation values (and fallbacks before the player reports
/// a duration).
class StoryData {
  const StoryData({
    required this.title,
    required this.series,
    required this.narrator,
    required this.coordinates,
    required this.swellNote,
    required this.vibeTags,
    required this.chapterProgress,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.chapterTimestamp,
    required this.excerpt,
    required this.currentTime,
    required this.remainingTime,
    required this.progress,
    this.tuningNote = '432Hz Tuning Active',
    this.audioAsset = AppAssets.audioLighthouseChapter,
    required this.teaserSubtitle,
    this.storyId,
    this.remoteMediaUrl,
    this.localAudioFile,
  });

  final String title;
  final String series;
  final String narrator;
  final String coordinates;
  final String swellNote;
  final List<StoryVibe> vibeTags;
  final String chapterProgress; // e.g. "Chapter 2 of 4"
  final int chapterNumber; // e.g. 2
  final String chapterTitle; // e.g. "The Keeper's Lantern"
  final String chapterTimestamp; // e.g. "08:42 — 22:00"
  final List<String> excerpt; // one entry per paragraph
  final String currentTime; // e.g. "08:42"
  final String remainingTime; // e.g. "-13:18"
  final double progress; // 0..1 of the current chapter
  final String tuningNote;

  /// Short blurb shown in Haven's "Sleep Lore & Horizon Tales" teaser list —
  /// independent of the in-player copy so each story reads well as a one-line
  /// pitch (narrator credit for some, theme description for others).
  final String teaserSubtitle;

  /// Bundled narration track for this story — the permanent offline fallback.
  /// Stage 2 ships a single spoken-word placeholder (the Lighthouse chapter)
  /// that every story currently reuses; swap per-story paths here when real
  /// narration lands. Used whenever [localAudioFile] is null.
  final String audioAsset;

  /// Catalog story id (server-driven stories only); null for bundled stories.
  final String? storyId;

  /// Server media URL to download lazily (`/media/...`); null for bundled.
  final String? remoteMediaUrl;

  /// Absolute path to a downloaded narration file. When set, playback uses it
  /// (via `setFilePath`) instead of the bundled [audioAsset].
  final String? localAudioFile;

  /// True when this story is backed by downloadable server media.
  bool get hasRemoteMedia =>
      (storyId != null && storyId!.isNotEmpty) &&
      (remoteMediaUrl != null && remoteMediaUrl!.isNotEmpty);

  StoryData copyWith({String? localAudioFile}) => StoryData(
    title: title,
    series: series,
    narrator: narrator,
    coordinates: coordinates,
    swellNote: swellNote,
    vibeTags: vibeTags,
    chapterProgress: chapterProgress,
    chapterNumber: chapterNumber,
    chapterTitle: chapterTitle,
    chapterTimestamp: chapterTimestamp,
    excerpt: excerpt,
    currentTime: currentTime,
    remainingTime: remainingTime,
    progress: progress,
    tuningNote: tuningNote,
    audioAsset: audioAsset,
    teaserSubtitle: teaserSubtitle,
    storyId: storyId,
    remoteMediaUrl: remoteMediaUrl,
    localAudioFile: localAudioFile ?? this.localAudioFile,
  );
}

/// A labelled mood/voice chip shown beneath the story title.
class StoryVibe {
  const StoryVibe(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

/// Catalog of narrated sea stories. Stage 1 only fully authors the featured
/// Lighthouse tale; the others carry enough data to render the same player.
abstract final class SeaStories {
  static const StoryData lighthouse = StoryData(
    title: 'The Lighthouse at Cape Horn',
    series: 'Tales of the Roaring Forties',
    narrator: 'Capt. Torben Lind',
    coordinates: "55°58′S • 67°17′W",
    swellNote: 'Cape Horn Swell 2.4m',
    vibeTags: [
      StoryVibe(Icons.nightlight_round, 'Deep Sleep', AppColors.seafoam),
      StoryVibe(Icons.mic_none, 'Warm Baritone', AppColors.sand),
      StoryVibe(Icons.headphones, 'Binaural Ocean Waves', AppColors.teal),
    ],
    chapterProgress: 'Chapter 2 of 4',
    chapterNumber: 2,
    chapterTitle: "The Keeper's Lantern",
    chapterTimestamp: '08:42 — 22:00',
    excerpt: [
      '"The wick catches with a soft crackle, shielded from forty knots of '
          'Antarctic gale by two inches of frosted Belgian plate glass. Below, '
          'the dark Drake Passage rolls on in ceaseless, rhythmic breathing..."',
      'Listen closely as Captain Torben details the ancient clockwork '
          'counterweights that kept the prism rotating without shore power for '
          'one hundred and twelve solitary winters. Let the steady pendulum '
          'swing settle your pulse.',
    ],
    currentTime: '08:42',
    remainingTime: '-13:18',
    progress: 0.4,
    teaserSubtitle: 'Narrated by Capt. Torben Lind • 22 min',
  );

  static const StoryData starsOverPacific = StoryData(
    title: 'Stars Over the Pacific',
    series: 'Horizon Tales',
    narrator: 'Amaia Rangi',
    coordinates: "09°12′S • 140°06′W",
    swellNote: 'Gentle Tide Drift 0.8m',
    vibeTags: [
      StoryVibe(Icons.nightlight_round, 'Deep Sleep', AppColors.seafoam),
      StoryVibe(Icons.headphones, 'Soft Tide Drift', AppColors.teal),
    ],
    chapterProgress: 'Chapter 1 of 3',
    chapterNumber: 1,
    chapterTitle: 'Reading the Swell',
    chapterTimestamp: '00:00 — 18:00',
    excerpt: [
      '"The navigators of old read the ocean like a page — each long swell a '
          'sentence pointing home beneath the wheeling Southern stars."',
    ],
    currentTime: '00:00',
    remainingTime: '-18:00',
    progress: 0.0,
    teaserSubtitle: 'Polynesian wayfinding & quiet tide drift • 18 min',
  );

  static const StoryData stElmosLight = StoryData(
    title: "St. Elmo's Light",
    series: 'Horizon Tales',
    narrator: 'Old Deck Folklore',
    coordinates: "48°20′N • 05°45′W",
    swellNote: 'Light Drizzle on Rigging',
    vibeTags: [
      StoryVibe(Icons.nightlight_round, 'Restless Watch', AppColors.seafoam),
      StoryVibe(Icons.mic_none, 'Soft Lullaby', AppColors.sand),
    ],
    chapterProgress: 'Chapter 1 of 2',
    chapterNumber: 1,
    chapterTitle: 'A Glow on the Mast',
    chapterTimestamp: '00:00 — 15:00',
    excerpt: [
      '"They say the pale blue fire that dances on the masthead is a saint\'s '
          'own blessing — a quiet light for the sleepless on anchor watch."',
    ],
    currentTime: '00:00',
    remainingTime: '-15:00',
    progress: 0.0,
    teaserSubtitle: 'Folkloric lullaby for restless anchor watch • 15 min',
  );

  /// Every authored story, in catalog order. [dailyLore] rotates a window of
  /// these for Haven's teaser list.
  static const List<StoryData> all = [lighthouse, starsOverPacific, stElmosLight];
}

/// Picks a deterministic, date-driven rotation of [count] stories from
/// [catalog] — no persistence or backend needed. The same local calendar day
/// always yields the same set (so it's stable across app restarts/navigation
/// within a day), and the window advances by one story per day, wrapping
/// around so every story gets fair rotation over time.
List<StoryData> dailyLore(
  DateTime date,
  List<StoryData> catalog, {
  int count = 2,
}) {
  if (catalog.isEmpty) return const [];
  final localMidnight = DateTime(date.year, date.month, date.day);
  final dayIndex = localMidnight.millisecondsSinceEpoch ~/ 86400000;
  final start = dayIndex % catalog.length;
  final n = count < catalog.length ? count : catalog.length;
  return List.generate(n, (i) => catalog[(start + i) % catalog.length]);
}

/// Chooses which stories to surface in Haven's lore list. [dailyLore] is used
/// only as a tie-breaker: if the (server-driven or bundled) [source] holds more
/// than two active stories it rotates a deterministic daily window of two;
/// otherwise every active story is shown directly, in order.
List<StoryData> loreForDisplay(List<StoryData> source, DateTime date) {
  if (source.length > 2) return dailyLore(date, source);
  return source;
}

/// Client-authored presentation for a story, keyed by catalog id. The server
/// owns media + title + core teaser copy + the active flag; the richer vibe
/// chips / chapter framing stay here so new server stories still render in the
/// full player (unknown ids fall back to [_defaultDecoration]).
class _StoryDecoration {
  const _StoryDecoration({
    required this.vibeTags,
    required this.chapterProgress,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.chapterTimestamp,
  });

  final List<StoryVibe> vibeTags;
  final String chapterProgress;
  final int chapterNumber;
  final String chapterTitle;
  final String chapterTimestamp;

  // Constant for every story today (only one narration placeholder ships).
  // Promote to constructor params when per-story values are needed.
  final String tuningNote = '432Hz Tuning Active';

  /// Bundled narration used as the offline fallback for this story id.
  final String bundledAsset = AppAssets.audioLighthouseChapter;
}

const _StoryDecoration _defaultDecoration = _StoryDecoration(
  vibeTags: [
    StoryVibe(Icons.nightlight_round, 'Deep Sleep', AppColors.seafoam),
    StoryVibe(Icons.headphones, 'Binaural Ocean Waves', AppColors.teal),
  ],
  chapterProgress: 'Chapter 1',
  chapterNumber: 1,
  chapterTitle: 'Horizon Tale',
  chapterTimestamp: '00:00 — End',
);

const Map<String, _StoryDecoration> _storyDecorations = {
  'lighthouse': _StoryDecoration(
    vibeTags: [
      StoryVibe(Icons.nightlight_round, 'Deep Sleep', AppColors.seafoam),
      StoryVibe(Icons.mic_none, 'Warm Baritone', AppColors.sand),
      StoryVibe(Icons.headphones, 'Binaural Ocean Waves', AppColors.teal),
    ],
    chapterProgress: 'Chapter 2 of 4',
    chapterNumber: 2,
    chapterTitle: "The Keeper's Lantern",
    chapterTimestamp: '08:42 — 22:00',
  ),
  'stars_over_pacific': _StoryDecoration(
    vibeTags: [
      StoryVibe(Icons.nightlight_round, 'Deep Sleep', AppColors.seafoam),
      StoryVibe(Icons.headphones, 'Soft Tide Drift', AppColors.teal),
    ],
    chapterProgress: 'Chapter 1 of 3',
    chapterNumber: 1,
    chapterTitle: 'Reading the Swell',
    chapterTimestamp: '00:00 — 18:00',
  ),
  'st_elmos_light': _StoryDecoration(
    vibeTags: [
      StoryVibe(Icons.nightlight_round, 'Restless Watch', AppColors.seafoam),
      StoryVibe(Icons.mic_none, 'Soft Lullaby', AppColors.sand),
    ],
    chapterProgress: 'Chapter 1 of 2',
    chapterNumber: 1,
    chapterTitle: 'A Glow on the Mast',
    chapterTimestamp: '00:00 — 15:00',
  ),
};

/// Builds a playable [StoryData] from a server [CatalogStory], merging the
/// server-driven fields with the client-authored decoration for its id. The
/// bundled asset is carried as [StoryData.audioAsset] (offline fallback); the
/// downloadable file is resolved lazily on play.
StoryData storyDataFromCatalog(CatalogStory story) {
  final deco = _storyDecorations[story.id] ?? _defaultDecoration;
  final excerpt = story.excerpt.isNotEmpty
      ? story.excerpt
      : const ['A quiet tale for the night watch.'];
  return StoryData(
    title: story.title,
    series: story.series,
    narrator: story.narrator,
    coordinates: story.coordinates,
    swellNote: story.swellNote,
    vibeTags: deco.vibeTags,
    chapterProgress: deco.chapterProgress,
    chapterNumber: deco.chapterNumber,
    chapterTitle: deco.chapterTitle,
    chapterTimestamp: deco.chapterTimestamp,
    excerpt: excerpt,
    currentTime: '00:00',
    remainingTime: '-${story.durationLabel}',
    progress: 0.0,
    tuningNote: deco.tuningNote,
    audioAsset: deco.bundledAsset,
    teaserSubtitle: story.teaserSubtitle,
    storyId: story.id,
    remoteMediaUrl: story.mediaUrl,
  );
}

/// Story playback session (Stitch "story_lighthouse_cape_horn" redesign).
///
/// Stage 2: the transport controls (play/pause, ±skip), the waveform/scrubber
/// progress and the elapsed/remaining readouts are bound to a real [AudioPlayer]
/// playing the story's narration, and the speed chip sets real playback speed.
/// The sleep timer, gentle-fadeout toggle and ambient-blend slider remain
/// presentational placeholders for a later stage.
class StoryPlaybackScreen extends StatefulWidget {
  const StoryPlaybackScreen({super.key, required this.story});

  final StoryData story;

  @override
  State<StoryPlaybackScreen> createState() => _StoryPlaybackScreenState();
}

class _StoryPlaybackScreenState extends State<StoryPlaybackScreen> {
  static const List<String> _speeds = ['0.8x Pace', '1.0x Pace', '1.2x Pace'];
  static const List<double> _speedValues = [0.8, 1.0, 1.2];
  static const Duration _skipBack = Duration(seconds: 15);
  static const Duration _skipForward = Duration(seconds: 30);
  static const List<String> _timers = [
    '15m Sleep Timer',
    '30m Sleep Timer',
    '45m Sleep Timer',
    'Timer Off',
  ];

  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _isFavourite = false;
  bool _gentleFadeout = true;
  int _speedIndex = 1;
  int _timerIndex = 1;
  double _blend = 45;
  bool _excerptExpanded = true;
  Duration _duration = Duration.zero;

  StoryData get _story => widget.story;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    // Reflect player state in the UI (play/pause icon + pulse animation).
    _player.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
    // Loop back to the start when narration completes so the screen settles
    // on a paused, ready-to-replay state rather than dead-ending.
    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        await _player.pause();
        await _player.seek(Duration.zero);
      }
    });
    try {
      // Prefer a lazily-downloaded catalog file; fall back to the bundled
      // asset whenever no local file is available (offline / not yet fetched).
      final local = _story.localAudioFile;
      if (local != null && local.isNotEmpty) {
        await _player.setFilePath(local);
      } else {
        await _player.setAsset(_story.audioAsset);
      }
      await _player.setSpeed(_speedValues[_speedIndex]);
      await _player.play();
    } catch (_) {
      // No audio hardware (e.g. tests / unsupported platform): fail quietly and
      // leave the transport controls in their paused state.
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      // Restart from the top if we finished.
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> _skip(Duration delta) async {
    final target = _player.position + delta;
    final total = _duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (total > Duration.zero && target > total ? total : target);
    await _player.seek(clamped);
  }

  Future<void> _cycleSpeed() async {
    final next = (_speedIndex + 1) % _speeds.length;
    setState(() => _speedIndex = next);
    await _player.setSpeed(_speedValues[next]);
  }

  static String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
              BackHeader(
                title: 'Story Playback Session',
                trailing: GlassIconButton(
                  icon: AppAssets.sparkles,
                  iconColor: AppColors.cream,
                  onTap: () {},
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UtilityBar(
                        timerLabel: _timers[_timerIndex],
                        onTimer: () => setState(
                          () =>
                              _timerIndex = (_timerIndex + 1) % _timers.length,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _CoverArt(story: _story, playing: _isPlaying),
                      const SizedBox(height: 16),
                      _TrackDetails(
                        story: _story,
                        favourite: _isFavourite,
                        onFavourite: () =>
                            setState(() => _isFavourite = !_isFavourite),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final total = _duration;
                          final progress = total.inMilliseconds > 0
                              ? (position.inMilliseconds / total.inMilliseconds)
                                    .clamp(0.0, 1.0)
                              : 0.0;
                          final remaining = total > position
                              ? total - position
                              : Duration.zero;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Waveform(progress: progress),
                              const SizedBox(height: 8),
                              _Scrubber(
                                currentTime: _fmt(position),
                                remainingTime: '-${_fmt(remaining)}',
                                chapterProgress: _story.chapterProgress,
                                value: progress,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _TransportControls(
                        isPlaying: _isPlaying,
                        onPlayPause: _togglePlay,
                        onSkipBack: () => _skip(-_skipBack),
                        onSkipForward: () => _skip(_skipForward),
                      ),
                      const SizedBox(height: 16),
                      _TuningCard(
                        speedLabel: _speeds[_speedIndex],
                        onSpeed: _cycleSpeed,
                        gentleFadeout: _gentleFadeout,
                        onFadeout: (v) => setState(() => _gentleFadeout = v),
                        blend: _blend,
                        onBlend: (v) => setState(() => _blend = v),
                      ),
                      const SizedBox(height: 16),
                      _ChapterCard(
                        story: _story,
                        expanded: _excerptExpanded,
                        onToggle: () => setState(
                          () => _excerptExpanded = !_excerptExpanded,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _FooterDecks(),
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
// Utility bar (offline chip + sleep timer)
// ---------------------------------------------------------------------------

class _UtilityBar extends StatelessWidget {
  const _UtilityBar({required this.timerLabel, required this.onTimer});

  final String timerLabel;
  final VoidCallback onTimer;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(
          child: _Pill(
            icon: Icons.cloud_done_outlined,
            label: 'Offline Cached',
            color: AppColors.seafoam,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: _Pill(
            icon: Icons.bedtime_outlined,
            label: timerLabel,
            color: AppColors.sand,
            onTap: onTimer,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: pill,
    );
  }
}

// ---------------------------------------------------------------------------
// Cover art
// ---------------------------------------------------------------------------

class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.story, required this.playing});

  final StoryData story;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.welcomeMid, AppColors.deepNavy],
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              offset: Offset(0, 12),
              blurRadius: 20,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Stack(
            children: [
              // Decorative beacon motif (no bundled photo in Stage 1).
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 0.9,
                      colors: [
                        AppColors.sand.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Meditative glow that breathes while narration is playing.
              Positioned.fill(
                child: AmbientPulseBackground(
                  playing: playing,
                  period: const Duration(seconds: 8),
                ),
              ),
              Center(
                child: SvgPicture.asset(
                  AppAssets.moonStar,
                  width: 64,
                  height: 64,
                  colorFilter: ColorFilter.mode(
                    AppColors.cream.withValues(alpha: 0.9),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 40,
                  child: SvgPicture.asset(
                    AppAssets.decoWaves,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _Pill(
                  icon: Icons.graphic_eq,
                  label: story.tuningNote,
                  color: AppColors.seafoam,
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.overlayDark,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    story.coordinates,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.cream,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: _Pill(
                  icon: Icons.waves,
                  label: story.swellNote,
                  color: AppColors.cream,
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
// Track details + vibe chips
// ---------------------------------------------------------------------------

class _TrackDetails extends StatelessWidget {
  const _TrackDetails({
    required this.story,
    required this.favourite,
    required this.onFavourite,
  });

  final StoryData story;
  final bool favourite;
  final VoidCallback onFavourite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(story.title, style: AppTextStyles.headerTitle),
                  const SizedBox(height: 4),
                  Text(
                    '${story.series} • Narrated by ${story.narrator}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: onFavourite,
              icon: Icon(
                favourite ? Icons.favorite : Icons.favorite_border,
                color: favourite ? AppColors.stormRed : AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final vibe in story.vibeTags)
              _VibeChip(icon: vibe.icon, label: vibe.label, color: vibe.color),
          ],
        ),
      ],
    );
  }
}

class _VibeChip extends StatelessWidget {
  const _VibeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Waveform + scrubber
// ---------------------------------------------------------------------------

class _Waveform extends StatelessWidget {
  const _Waveform({required this.progress});

  final double progress;

  // Static bar heights (fraction of the 48px track).
  static const List<double> _bars = [
    0.3, 0.5, 0.8, 0.4, 0.7, 1.0, 0.6, 0.9, 0.5, 0.8, 1.0, 0.6, 0.4, 0.9, //
    0.7, 0.5, 1.0, 0.8, 0.4, 0.7, 0.6, 0.9, 0.5, 0.7, 0.3, 0.6, 0.4, 0.2,
  ];

  @override
  Widget build(BuildContext context) {
    final playedCount = (_bars.length * progress).round();
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < _bars.length; i++)
            _Bar(
              height: _bars[i] * 36,
              played: i <= playedCount,
              needle: i == playedCount,
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.played,
    required this.needle,
  });

  final double height;
  final bool played;
  final bool needle;

  @override
  Widget build(BuildContext context) {
    final Color color = needle
        ? AppColors.white
        : played
        ? AppColors.seafoam
        : AppColors.glassBorder;
    return Container(
      width: needle ? 2.5 : 2,
      height: needle ? 36 : height.clamp(3, 36),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.currentTime,
    required this.remainingTime,
    required this.chapterProgress,
    required this.value,
  });

  final String currentTime;
  final String remainingTime;
  final String chapterProgress;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.seafoam,
            inactiveTrackColor: AppColors.glassBorder,
            thumbColor: AppColors.white,
            overlayColor: AppColors.seafoamFaint,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(value: value.clamp(0, 1), onChanged: (_) {}),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentTime,
              style: AppTextStyles.caption.copyWith(color: AppColors.seafoam),
            ),
            Text(chapterProgress, style: AppTextStyles.caption),
            Text(remainingTime, style: AppTextStyles.caption),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transport controls
// ---------------------------------------------------------------------------

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSkipBack,
    required this.onSkipForward,
  });

  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SkipButton(icon: Icons.replay_10, label: '15s', onTap: onSkipBack),
        const SizedBox(width: 28),
        Material(
          color: AppColors.seafoam,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPlayPause,
            child: SizedBox(
              width: 76,
              height: 76,
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 38,
                color: AppColors.onAccent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 28),
        _SkipButton(icon: Icons.forward_30, label: '30s', onTap: onSkipForward),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: AppColors.white),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.muted,
                  fontSize: 9,
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
// Tuning card (speed, fadeout, ambient blend)
// ---------------------------------------------------------------------------

class _TuningCard extends StatelessWidget {
  const _TuningCard({
    required this.speedLabel,
    required this.onSpeed,
    required this.gentleFadeout,
    required this.onFadeout,
    required this.blend,
    required this.onBlend,
  });

  final String speedLabel;
  final VoidCallback onSpeed;
  final bool gentleFadeout;
  final ValueChanged<bool> onFadeout;
  final double blend;
  final ValueChanged<double> onBlend;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Flexible(
                child: InkWell(
                  onTap: onSpeed,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.speed,
                          size: 15,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            speedLabel,
                            style: AppTextStyles.bodyStrong,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Gentle Fadeout',
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: gentleFadeout,
                      onChanged: onFadeout,
                      activeThumbColor: AppColors.onAccent,
                      activeTrackColor: AppColors.seafoam,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grain, size: 16, color: AppColors.seafoam),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Hull Rain & Ocean Blend',
                        style: AppTextStyles.bodyStrong,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${blend.round()}%',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.seafoam,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.seafoam,
              inactiveTrackColor: AppColors.glassBorder,
              thumbColor: AppColors.white,
              overlayColor: AppColors.seafoamFaint,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(value: blend, max: 100, onChanged: onBlend),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter excerpt card
// ---------------------------------------------------------------------------

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.story,
    required this.expanded,
    required this.onToggle,
  });

  final StoryData story;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  story.chapterNumber.toString().padLeft(2, '0'),
                  style: AppTextStyles.badge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chapter ${story.chapterNumber}: ${story.chapterTitle}',
                      style: AppTextStyles.cardTitleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Timestamp: ${story.chapterTimestamp}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              InkResponse(
                onTap: onToggle,
                radius: 20,
                child: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < story.excerpt.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Text(
                story.excerpt[i],
                style: AppTextStyles.body.copyWith(
                  color: i == 0 ? AppColors.cream : AppColors.bodyMist,
                  fontStyle: i == 0 ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _ElementBadge(
                  icon: Icons.water_drop,
                  label: 'Rain on Skylight',
                ),
                _ElementBadge(icon: Icons.sailing, label: 'Timber Creaks'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ElementBadge extends StatelessWidget {
  const _ElementBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.teal),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer quick-nav decks
// ---------------------------------------------------------------------------

class _FooterDecks extends StatelessWidget {
  const _FooterDecks();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(
            child: _FooterDeck(
              icon: Icons.graphic_eq,
              iconColor: AppColors.sand,
              title: 'Voice Equalizer',
              subtitle: 'Warm Cabin Lows',
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _FooterDeck(
              icon: Icons.air,
              iconColor: AppColors.seafoam,
              title: 'Respiration Cue',
              subtitle: '4s Tide In • 6s Tide Out',
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterDeck extends StatelessWidget {
  const _FooterDeck({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
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
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
