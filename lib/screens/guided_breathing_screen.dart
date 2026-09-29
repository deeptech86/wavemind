import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';

/// "Tidal Breath" guided breathing (Figma node 3:182 "guided-breathing").
///
/// A static translation of the design: a concentric breathing arena, the
/// current guide cue, a session pace pill, and the play/mute/info controls.
///
/// As of the Haven redesign this is a nested regulation session reached from
/// the Haven hub's "Cast Swell" CTA (rather than a top-level tab), so it no
/// longer carries the bottom navigation. The mind-games cross-link has moved
/// to the dedicated Off-Watch Mind Games hub.
class GuidedBreathingScreen extends StatelessWidget {
  const GuidedBreathingScreen({super.key});

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
                      const _BreathingArena(),
                      const SizedBox(height: 32),
                      const _GuideDirection(),
                      const SizedBox(height: 32),
                      const _SessionPill(),
                      const SizedBox(height: 32),
                      _Controls(onInfo: () {}),
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
  const _BreathingArena();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(220, AppColors.glassBorderSoft),
          _ring(170, AppColors.glassBorder),
          Container(
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
  const _GuideDirection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Inhale with the Swell',
          textAlign: TextAlign.center,
          style: AppTextStyles.breatheHeadline,
        ),
        const SizedBox(height: 8),
        Text(
          'Hold as the crest approaches',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyRegular,
        ),
      ],
    );
  }
}

class _SessionPill extends StatelessWidget {
  const _SessionPill();

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
          Text('03:24', style: AppTextStyles.timerValue),
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
  const _Controls({required this.onInfo});

  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleButton(
          size: 48,
          color: AppColors.cardSurface,
          icon: AppAssets.volumeOff,
          iconSize: 20,
          iconColor: AppColors.white,
          onTap: () {},
        ),
        const SizedBox(width: 24),
        _CircleButton(
          size: 64,
          color: AppColors.white,
          icon: AppAssets.pause,
          iconSize: 24,
          iconColor: AppColors.deepNavy,
          onTap: () {},
        ),
        const SizedBox(width: 24),
        _CircleButton(
          size: 48,
          color: AppColors.cardSurface,
          icon: AppAssets.helpCircle,
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
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.onTap,
  });

  final double size;
  final Color color;
  final String icon;
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
            child: SvgPicture.asset(
              icon,
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
