import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../data/models/mood_check_in.dart';
import '../data/models/mood_state.dart';
import '../data/wellness_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';
import '../widgets/tide_bottom_nav.dart';

/// "Log Emotional Swell" mood check-in (Figma node 3:107 "mood-check-in").
///
/// Stage 4: the inner-water state and the three influence-factor ratings are
/// now interactive, and "Secure in Logbook" persists the check-in on-device
/// (awarding Fleet Knots).
class MoodCheckInScreen extends StatefulWidget {
  const MoodCheckInScreen({super.key, WellnessRepository? repository})
    : _repository = repository;

  final WellnessRepository? _repository;

  @override
  State<MoodCheckInScreen> createState() => _MoodCheckInScreenState();
}

class _MoodCheckInScreenState extends State<MoodCheckInScreen> {
  late final WellnessRepository _repo =
      widget._repository ?? WellnessRepository();

  // Defaults preserve the original design's shown state.
  MoodState _selected = MoodState.gentleSwell;
  int _sleepQuality = 2;
  int _seaWeather = 4;
  int _homesickness = 5;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await _repo.saveMoodCheckIn(
      MoodCheckIn(
        state: _selected,
        sleepQuality: _sleepQuality,
        seaWeather: _seaWeather,
        homesickness: _homesickness,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    navigator.maybePop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Swell logged in your logbook. +30 knots')),
    );
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
                      _SwellSelector(
                        selected: _selected,
                        onSelect: (s) => setState(() => _selected = s),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '2. Influence Factors on Watch',
                        style: AppTextStyles.sectionPrompt,
                      ),
                      const SizedBox(height: 20),
                      _ContextFactors(
                        sleepQuality: _sleepQuality,
                        seaWeather: _seaWeather,
                        homesickness: _homesickness,
                        onSleep: (v) => setState(() => _sleepQuality = v),
                        onWeather: (v) => setState(() => _seaWeather = v),
                        onHome: (v) => setState(() => _homesickness = v),
                      ),
                      const SizedBox(height: 20),
                      _SaveButton(saving: _saving, onTap: _saving ? null : _save),
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

/// Visual metadata for each selectable inner-water state.
class _SwellStyle {
  const _SwellStyle({
    required this.state,
    required this.icon,
    required this.fill,
    required this.color,
  });

  final MoodState state;
  final String icon;
  final Color fill;
  final Color color;
}

class _SwellSelector extends StatelessWidget {
  const _SwellSelector({required this.selected, required this.onSelect});

  final MoodState selected;
  final ValueChanged<MoodState> onSelect;

  static const List<_SwellStyle> _styles = [
    _SwellStyle(
      state: MoodState.calmSea,
      icon: AppAssets.waves,
      fill: AppColors.seafoamFaint,
      color: AppColors.seafoam,
    ),
    _SwellStyle(
      state: MoodState.gentleSwell,
      icon: AppAssets.waves,
      fill: AppColors.tealFaint,
      color: AppColors.teal,
    ),
    _SwellStyle(
      state: MoodState.choppyWater,
      icon: AppAssets.waves,
      fill: AppColors.sandFaint,
      color: AppColors.sand,
    ),
    _SwellStyle(
      state: MoodState.highStorm,
      icon: AppAssets.cloudRainWind,
      fill: AppColors.stormFaint,
      color: AppColors.stormRed,
    ),
    _SwellStyle(
      state: MoodState.drifting,
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
      children: [
        for (final s in _styles)
          _SwellChip(
            style: s,
            selected: s.state == selected,
            onTap: () => onSelect(s.state),
          ),
      ],
    );
  }
}

class _SwellChip extends StatelessWidget {
  const _SwellChip({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final _SwellStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.fill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 105,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.teal : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              SvgPicture.asset(
                style.icon,
                width: 28,
                height: 28,
                colorFilter: ColorFilter.mode(style.color, BlendMode.srcIn),
              ),
              const SizedBox(height: 8),
              Text(
                style.state.label,
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
  const _ContextFactors({
    required this.sleepQuality,
    required this.seaWeather,
    required this.homesickness,
    required this.onSleep,
    required this.onWeather,
    required this.onHome,
  });

  final int sleepQuality;
  final int seaWeather;
  final int homesickness;
  final ValueChanged<int> onSleep;
  final ValueChanged<int> onWeather;
  final ValueChanged<int> onHome;

  // Subtitle wording per rating (1..5) for each factor.
  static const List<String> _sleepLabels = [
    'Sleepless', 'Restless', 'Broken', 'Fair', 'Deep Rest',
  ];
  static const List<String> _weatherLabels = [
    'Dead Calm', 'Light Air', 'Moderate', 'Heavy Gales', 'Severe Storm',
  ];
  static const List<String> _homeLabels = [
    'Settled', 'Mild', 'Noticeable', 'Strong', 'Severe',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FactorRow(
          icon: AppAssets.moonStar,
          title: 'Voyage Sleep Quality',
          subtitle: _sleepLabels[sleepQuality - 1],
          rating: sleepQuality,
          onRate: onSleep,
        ),
        const SizedBox(height: 10),
        _FactorRow(
          icon: AppAssets.wind,
          title: 'Outside Sea Weather',
          subtitle: _weatherLabels[seaWeather - 1],
          rating: seaWeather,
          onRate: onWeather,
        ),
        const SizedBox(height: 10),
        _FactorRow(
          icon: AppAssets.mail,
          title: 'Shore Homesickness',
          subtitle: _homeLabels[homesickness - 1],
          rating: homesickness,
          onRate: onHome,
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
    required this.onRate,
  });

  final String icon;
  final String title;
  final String subtitle;
  final int rating;
  final ValueChanged<int> onRate;

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
          _StarRating(rating: rating, onRate: onRate),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.onRate});

  final int rating;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onRate(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                i <= rating ? Icons.star : Icons.star_border,
                size: 18,
                color: AppColors.teal,
              ),
            ),
          ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback? onTap;

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
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
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
