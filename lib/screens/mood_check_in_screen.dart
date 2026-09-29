import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';
import '../widgets/tide_bottom_nav.dart';

/// "Log Emotional Swell" mood check-in (Figma node 3:107 "mood-check-in").
///
/// A visual translation of the design: pick an inner water state, review the
/// day's influence factors, then secure the entry in the logbook.
class MoodCheckInScreen extends StatelessWidget {
  const MoodCheckInScreen({super.key});

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
              const BackHeader(title: 'Log Emotional Swell'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Select current inner water state',
                        style: AppTextStyles.sectionPrompt,
                      ),
                      const SizedBox(height: 20),
                      const _SwellSelector(),
                      const SizedBox(height: 20),
                      Text(
                        '2. Influence Factors on Watch',
                        style: AppTextStyles.sectionPrompt,
                      ),
                      const SizedBox(height: 20),
                      const _ContextFactors(),
                      const SizedBox(height: 20),
                      _SaveButton(
                        onTap: () => Navigator.of(context).maybePop(),
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

class _SwellState {
  const _SwellState({
    required this.label,
    required this.icon,
    required this.fill,
    required this.color,
    this.selected = false,
  });

  final String label;
  final String icon;
  final Color fill;
  final Color color;
  final bool selected;
}

class _SwellSelector extends StatelessWidget {
  const _SwellSelector();

  static const List<_SwellState> _states = [
    _SwellState(
      label: 'Calm Sea',
      icon: AppAssets.waves,
      fill: AppColors.seafoamFaint,
      color: AppColors.seafoam,
    ),
    _SwellState(
      label: 'Gentle Swell',
      icon: AppAssets.waves,
      fill: AppColors.tealFaint,
      color: AppColors.teal,
      selected: true,
    ),
    _SwellState(
      label: 'Choppy Water',
      icon: AppAssets.waves,
      fill: AppColors.sandFaint,
      color: AppColors.sand,
    ),
    _SwellState(
      label: 'High Storm',
      icon: AppAssets.cloudRainWind,
      fill: AppColors.stormFaint,
      color: AppColors.stormRed,
    ),
    _SwellState(
      label: 'Drifting',
      icon: AppAssets.cloudFog,
      fill: AppColors.mutedFaint,
      color: AppColors.muted,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final s in _states) _SwellChip(state: s)],
    );
  }
}

class _SwellChip extends StatelessWidget {
  const _SwellChip({required this.state});

  final _SwellState state;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: state.fill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Container(
          width: 105,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: state.selected ? AppColors.teal : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              SvgPicture.asset(
                state.icon,
                width: 28,
                height: 28,
                colorFilter: ColorFilter.mode(state.color, BlendMode.srcIn),
              ),
              const SizedBox(height: 8),
              Text(
                state.label,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextFactors extends StatelessWidget {
  const _ContextFactors();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _FactorRow(
          icon: AppAssets.moonStar,
          title: 'Voyage Sleep Quality',
          subtitle: 'Restless',
          rating: 2,
        ),
        SizedBox(height: 10),
        _FactorRow(
          icon: AppAssets.wind,
          title: 'Outside Sea Weather',
          subtitle: 'Heavy Gales',
          rating: 4,
        ),
        SizedBox(height: 10),
        _FactorRow(
          icon: AppAssets.mail,
          title: 'Shore Homesickness',
          subtitle: 'Severe',
          rating: 5,
        ),
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rating,
  });

  final String icon;
  final String title;
  final String subtitle;
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(child: SvgPicture.asset(icon, width: 20, height: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${'★' * rating}${'☆' * (5 - rating)}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.teal),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 10),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Center(
              child: Text(
                'Secure in Logbook',
                style: AppTextStyles.buttonLarge.copyWith(
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
