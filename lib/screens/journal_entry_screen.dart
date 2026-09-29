import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';
import '../widgets/tide_bottom_nav.dart';
import 'mood_check_in_screen.dart';

/// "Captain's Private Log" journal entry (Figma node 3:235 "journal-entry").
class JournalEntryScreen extends StatelessWidget {
  const JournalEntryScreen({super.key});

  static const String _entry =
      'The watch tonight was exceptionally still. The swell was long and slow, '
      'almost rocking the entire hull with a rhythmic hum. I spent ten minutes '
      'on the bridge wing just listening to the spray cutting past the bow.\n\n'
      'It made the distance from home feel a little more manageable. Writing '
      'this down to lock away the noise of the generator deck below...';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const TideBottomNav(active: TideTab.log),
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
                title: "Captain's Private Log",
                trailing: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Save',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.seafoam,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: _CoordinatesStamp(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MoodLauncher(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MoodCheckInScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _PromptCard(),
                      const SizedBox(height: 20),
                      const _WritingSlate(text: _entry),
                      const SizedBox(height: 20),
                      const _SlateTools(),
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

class _CoordinatesStamp extends StatelessWidget {
  const _CoordinatesStamp();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(AppAssets.mapPin, width: 16, height: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Coord: 32°14'N, 64°49'W · Wind Force 4",
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.cream),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Compact launcher for the mood check-in flow. The Helm redesign dropped the
/// standalone "Log Swell" card, so daily emotional-swell logging now lives here
/// inside the logbook where it belongs conceptually.
class _MoodLauncher extends StatelessWidget {
  const _MoodLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.teal,
      borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SvgPicture.asset(
                AppAssets.smilePlus,
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.white,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Emotional Swell',
                      style: AppTextStyles.cardTitleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Record how the sea within you feels today',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.tealTint,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(AppAssets.lightbulbOff, width: 20, height: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY SEAPROMPT', style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  'What sound of the rigging or water brought you peace today?',
                  style: AppTextStyles.promptMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WritingSlate extends StatelessWidget {
  const _WritingSlate({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(color: AppColors.white, height: 1.6),
      ),
    );
  }
}

class _SlateTools extends StatelessWidget {
  const _SlateTools();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              SvgPicture.asset(AppAssets.lock, width: 20, height: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Encrypted in local ship vault',
                  style: AppTextStyles.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            SvgPicture.asset(AppAssets.mic, width: 20, height: 20),
            const SizedBox(width: 8),
            SvgPicture.asset(AppAssets.camera, width: 20, height: 20),
          ],
        ),
      ],
    );
  }
}
