import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_assets.dart';
import '../data/games/fog_signal_echo.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';

/// "Fog Signal Echo" — a call-and-repeat pattern-memory game.
///
/// The game calls out a growing sequence of foghorn signals, framed as
/// compass-relative bearings (Bow / Starboard / Stern / Port — exactly what
/// a real fog signal tells you at sea). The sailor echoes the pattern back
/// in order; a wrong tap just replays the current round for another try,
/// never a hard fail. Reaching the target round count completes the
/// session.
///
/// The four pitches are the single bundled `foghorn_bell.wav` ambient
/// sample (already used in Haven), pitch-shifted per signal via just_audio
/// — no extra audio assets needed. This game intentionally awards no Fleet
/// Knots, same as Knot Master and Cabin Dominoes — only mood check-ins,
/// breathing sessions and journal entries feed that economy.
class FogSignalEchoScreen extends StatefulWidget {
  const FogSignalEchoScreen({super.key, Random? random})
    : _random = random;

  final Random? _random;

  @override
  State<FogSignalEchoScreen> createState() => _FogSignalEchoScreenState();
}

enum _Phase { idle, playingSequence, listening, correct, wrong, complete }

class _FogSignalEchoScreenState extends State<FogSignalEchoScreen> {
  late final FogSignalEcho _game = FogSignalEcho(random: widget._random);
  final AudioPlayer _player = AudioPlayer();

  _Phase _phase = _Phase.idle;
  FogSignal? _activeSignal;
  bool _audioReady = false;

  static const Map<FogSignal, double> _pitches = {
    FogSignal.bow: 1.3,
    FogSignal.starboard: 1.0,
    FogSignal.port: 0.75,
    FogSignal.stern: 0.55,
  };

  static const Map<FogSignal, String> _labels = {
    FogSignal.bow: 'Bow',
    FogSignal.starboard: 'Starboard',
    FogSignal.stern: 'Stern',
    FogSignal.port: 'Port',
  };

  static const Map<FogSignal, Color> _colors = {
    FogSignal.bow: AppColors.seafoam,
    FogSignal.starboard: AppColors.teal,
    FogSignal.stern: AppColors.sand,
    FogSignal.port: AppColors.cream,
  };

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      await _player.setAsset(AppAssets.audioFoghornBell);
      if (!mounted) return;
      setState(() => _audioReady = true);
    } catch (_) {
      // Audio is a sensory layer, not the game logic — play on in silence
      // rather than block the puzzle if the asset can't load.
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playTone(FogSignal signal) async {
    if (!_audioReady) return;
    try {
      await _player.setPitch(_pitches[signal]!);
      await _player.seek(Duration.zero);
      unawaited(_player.play());
      await Future.delayed(const Duration(milliseconds: 450));
      await _player.pause();
    } catch (_) {
      // Non-fatal — the visual highlight still carries the round.
    }
  }

  Future<void> _start() async {
    _game.reset();
    _game.nextRound();
    await _playSequenceThenListen();
  }

  Future<void> _playSequenceThenListen() async {
    setState(() => _phase = _Phase.playingSequence);
    for (final signal in _game.sequence) {
      if (!mounted) return;
      setState(() => _activeSignal = signal);
      await _playTone(signal);
      if (!mounted) return;
      setState(() => _activeSignal = null);
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.listening);
  }

  Future<void> _onTapSignal(FogSignal signal) async {
    if (_phase != _Phase.listening) return;
    setState(() => _activeSignal = signal);
    unawaited(_playTone(signal));
    final matched = _game.echo(signal);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _activeSignal = null);

    if (!matched) {
      setState(() => _phase = _Phase.wrong);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      _game.retryRound();
      await _playSequenceThenListen();
      return;
    }

    if (!_game.roundComplete) return; // still echoing this round

    if (_game.isComplete) {
      setState(() => _phase = _Phase.complete);
      return;
    }

    setState(() => _phase = _Phase.correct);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _game.nextRound();
    await _playSequenceThenListen();
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
              const BackHeader(title: 'Fog Signal Echo'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _EchoIntro(),
                      const SizedBox(height: 16),
                      _EchoProgress(round: _game.round, target: _game.targetRounds),
                      const SizedBox(height: 16),
                      _SignalCompass(
                        active: _activeSignal,
                        interactive: _phase == _Phase.listening,
                        labels: _labels,
                        colors: _colors,
                        onTap: _onTapSignal,
                      ),
                      const SizedBox(height: 16),
                      _EchoStatusBanner(phase: _phase),
                      const SizedBox(height: 16),
                      _EchoActionButton(phase: _phase, onTap: _start),
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

class _EchoIntro extends StatelessWidget {
  const _EchoIntro();

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
              const Icon(
                Icons.graphic_eq,
                size: 14,
                color: AppColors.teal,
              ),
              const SizedBox(width: 6),
              Text(
                'AUDITORY CALM',
                style: AppTextStyles.badge.copyWith(color: AppColors.teal),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Echo the Signal', style: AppTextStyles.cardHeading),
          const SizedBox(height: 8),
          Text(
            'Listen for the foghorn bearing — Bow, Starboard, Stern, Port — '
            'then tap them back in the same order. Each round adds one more '
            'signal. A missed echo just replays the pattern — no penalty, '
            'just listen again.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _EchoProgress extends StatelessWidget {
  const _EchoProgress({required this.round, required this.target});

  final int round;
  final int target;

  @override
  Widget build(BuildContext context) {
    final fraction = target == 0 ? 0.0 : (round / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Round', style: AppTextStyles.caption),
            Text(
              '$round / $target',
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
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.cardSurface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
          ),
        ),
      ],
    );
  }
}

/// The four signal pads arranged like a compass rose: Bow at the top,
/// Stern at the bottom, Port and Starboard either side.
class _SignalCompass extends StatelessWidget {
  const _SignalCompass({
    required this.active,
    required this.interactive,
    required this.labels,
    required this.colors,
    required this.onTap,
  });

  final FogSignal? active;
  final bool interactive;
  final Map<FogSignal, String> labels;
  final Map<FogSignal, Color> colors;
  final ValueChanged<FogSignal> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _pad(FogSignal.bow),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _pad(FogSignal.port)),
            const SizedBox(width: 12),
            Expanded(child: _pad(FogSignal.starboard)),
          ],
        ),
        const SizedBox(height: 12),
        _pad(FogSignal.stern),
      ],
    );
  }

  Widget _pad(FogSignal signal) {
    final isActive = active == signal;
    final color = colors[signal]!;
    return Semantics(
      button: true,
      enabled: interactive,
      label: '${labels[signal]} signal',
      child: GestureDetector(
        onTap: interactive ? () => onTap(signal) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 64,
          decoration: BoxDecoration(
            color: isActive ? color : AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusTile),
            border: Border.all(
              color: isActive ? color : AppColors.glassBorderSoft,
              width: isActive ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            labels[signal]!,
            style: AppTextStyles.cardTitleSmall.copyWith(
              color: isActive ? AppColors.onAccent : AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _EchoStatusBanner extends StatelessWidget {
  const _EchoStatusBanner({required this.phase});

  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, caption) = switch (phase) {
      _Phase.idle => (
          Icons.graphic_eq,
          AppColors.muted,
          'Ready when you are',
          'Tap "Start Listening" to hear the first signal.',
        ),
      _Phase.playingSequence => (
          Icons.hearing,
          AppColors.teal,
          'Listen…',
          'Watch (and listen) for each bearing in order.',
        ),
      _Phase.listening => (
          Icons.touch_app_outlined,
          AppColors.seafoam,
          'Your turn',
          'Echo the pattern back in the same order.',
        ),
      _Phase.correct => (
          Icons.verified,
          AppColors.seafoam,
          'Clean echo!',
          'One more signal joins the pattern.',
        ),
      _Phase.wrong => (
          Icons.replay,
          AppColors.sand,
          'Try again',
          'That bearing was off — listen to the round once more.',
        ),
      _Phase.complete => (
          Icons.military_tech,
          AppColors.seafoam,
          'Session complete!',
          'You held the full pattern through every round.',
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

class _EchoActionButton extends StatelessWidget {
  const _EchoActionButton({required this.phase, required this.onTap});

  final _Phase phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final busy = phase == _Phase.playingSequence || phase == _Phase.listening;
    final label = switch (phase) {
      _Phase.idle => 'Start Listening',
      _Phase.complete => 'Play Again',
      _ => 'Listening…',
    };
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.buttonLarge.copyWith(
                  color: busy ? AppColors.muted : AppColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
