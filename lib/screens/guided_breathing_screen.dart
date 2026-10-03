import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_assets.dart';
import '../data/wellness_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/ambient_pulse_background.dart';
import '../widgets/back_header.dart';

/// "Tidal Breath" guided breathing (Figma node 3:182 "guided-breathing").
///
/// A concentric breathing arena, the current guide cue, a session pace pill,
/// and the play / mute / info controls.
///
/// Stage 2 wires real audio: a calming breathing-pace pad loops underneath the
/// visual exercise while the session runs. "Run in background" here means the
/// loop plays continuously *underneath the on-screen session* while the user
/// stays on this screen — it is not an OS background-audio service, so it does
/// not survive app backgrounding / screen lock (out of scope for Stage 2).
///
/// The breathing circle animation is driven by an [AnimationController] that
/// only runs while audio is actually playing, so motion, mute and pause stay
/// coherent with what the user hears rather than animating as decoration.
///
/// Reached from the Haven hub's "Cast Swell" CTA (not a top-level tab), so it
/// carries no bottom navigation.
class GuidedBreathingScreen extends StatefulWidget {
  const GuidedBreathingScreen({super.key, WellnessRepository? repository})
    : _repository = repository;

  final WellnessRepository? _repository;

  @override
  State<GuidedBreathingScreen> createState() => _GuidedBreathingScreenState();
}

class _GuidedBreathingScreenState extends State<GuidedBreathingScreen>
    with SingleTickerProviderStateMixin {
  /// One full breathe (inhale + exhale) cycle, matched to the session pace.
  static const Duration _breathCycle = Duration(seconds: 8);

  /// A session counts as "meaningfully progressed" (and is logged once to the
  /// streak ledger) after this much actual playing time — roughly four full
  /// breath cycles, enough to register as a real regulation session rather than
  /// an accidental tap.
  static const int _completionThresholdSeconds = 30;

  final AudioPlayer _player = AudioPlayer();
  late final WellnessRepository _repo =
      widget._repository ?? WellnessRepository();
  late final AnimationController _breathCtrl = AnimationController(
    vsync: this,
    duration: _breathCycle,
  );

  bool _isPlaying = false;
  bool _muted = false;
  bool _sessionRecorded = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    _player.playingStream.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
      _syncMotion();
    });
    try {
      await _player.setAsset(AppAssets.audioTidalBreath);
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (_) {
      // No audio hardware (tests / unsupported): leave the session paused.
    }
  }

  /// Keep the breathing animation and session timer in lockstep with playback.
  void _syncMotion() {
    if (_isPlaying) {
      if (!_breathCtrl.isAnimating) {
        _breathCtrl.repeat(reverse: true);
      }
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
        if (!_sessionRecorded &&
            _elapsed.inSeconds >= _completionThresholdSeconds) {
          _sessionRecorded = true;
          // Fire-and-forget: the ledger write awards the breathing-session
          // knots and feeds the streak. Failures degrade silently (see repo).
          _repo.recordBreathingSession(durationSeconds: _elapsed.inSeconds);
        }
      });
    } else {
      _breathCtrl.stop();
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _player.setVolume(_muted ? 0 : 1);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _breathCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  static String _fmt(Duration d) {
    final m = (d.inSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
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
              const BackHeader(title: 'Tidal Breath'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _BreathingArena(
                        controller: _breathCtrl,
                        playing: _isPlaying,
                      ),
                      const SizedBox(height: 32),
                      _GuideDirection(controller: _breathCtrl),
                      const SizedBox(height: 32),
                      _SessionPill(elapsed: _fmt(_elapsed)),
                      const SizedBox(height: 32),
                      _Controls(
                        isPlaying: _isPlaying,
                        muted: _muted,
                        onPlayPause: _togglePlay,
                        onMute: _toggleMute,
                        onInfo: () {},
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

class _BreathingArena extends StatelessWidget {
  const _BreathingArena({required this.controller, required this.playing});

  final AnimationController controller;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft meditative glow, only while audio plays.
          Positioned.fill(
            child: AmbientPulseBackground(
              playing: playing,
              period: Duration(seconds: 8),
              intensity: 0.7,
              alignment: Alignment.center,
            ),
          ),
          _ring(220, AppColors.glassBorderSoft),
          _ring(170, AppColors.glassBorder),
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              // Ease the raw 0..1 controller into a gentle breathe (0.82..1.12).
              final eased = Curves.easeInOut.transform(controller.value);
              final scale = 0.82 + 0.30 * eased;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.breatheOrbGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal,
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.wind,
                  width: 28,
                  height: 28,
                  colorFilter: const ColorFilter.mode(
                    AppColors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
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

class _GuideDirection extends StatelessWidget {
  const _GuideDirection({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // While animating, swap the cue in step with the breathe direction;
        // at rest it stays on the inhale cue (its original static copy).
        final inhaling = controller.status != AnimationStatus.reverse;
        return Column(
          children: [
            Text(
              inhaling ? 'Inhale with the Swell' : 'Exhale into the Trough',
              textAlign: TextAlign.center,
              style: AppTextStyles.breatheHeadline,
            ),
            const SizedBox(height: 8),
            Text(
              inhaling
                  ? 'Hold as the crest approaches'
                  : 'Release as the water draws back',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyRegular,
            ),
          ],
        );
      },
    );
  }
}

class _SessionPill extends StatelessWidget {
  const _SessionPill({required this.elapsed});

  final String elapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(elapsed, style: AppTextStyles.timerValue),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.glassBorder,
          ),
          Flexible(
            child: Text(
              'Session Pace: Ocean Rise (6s)',
              style: AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.isPlaying,
    required this.muted,
    required this.onPlayPause,
    required this.onMute,
    required this.onInfo,
  });

  final bool isPlaying;
  final bool muted;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleButton(
          size: 48,
          color: AppColors.cardSurface,
          iconData: muted ? Icons.volume_off : Icons.volume_up,
          iconSize: 20,
          iconColor: muted ? AppColors.muted : AppColors.white,
          onTap: onMute,
        ),
        const SizedBox(width: 24),
        _CircleButton(
          size: 64,
          color: AppColors.white,
          iconData: isPlaying ? Icons.pause : Icons.play_arrow,
          iconSize: 26,
          iconColor: AppColors.deepNavy,
          onTap: onPlayPause,
        ),
        const SizedBox(width: 24),
        _CircleButton(
          size: 48,
          color: AppColors.cardSurface,
          svgIcon: AppAssets.helpCircle,
          iconSize: 20,
          iconColor: AppColors.white,
          onTap: onInfo,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.size,
    required this.color,
    required this.iconSize,
    required this.iconColor,
    required this.onTap,
    this.iconData,
    this.svgIcon,
  }) : assert(iconData != null || svgIcon != null);

  final double size;
  final Color color;
  final IconData? iconData;
  final String? svgIcon;
  final double iconSize;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: iconData != null
                ? Icon(iconData, size: iconSize, color: iconColor)
                : SvgPicture.asset(
                    svgIcon!,
                    width: iconSize,
                    height: iconSize,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  ),
          ),
        ),
      ),
    );
  }
}
