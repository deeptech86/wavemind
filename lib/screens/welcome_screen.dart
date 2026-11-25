import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'login_screen.dart';

/// Onboarding / splash screen (Figma node 3:10 "welcome").
///
/// A sunrise-over-water gradient framing the Wavemind wordmark, a circular
/// illustration, the product promise, and the primary "Embark" call to action.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _embark(BuildContext context) {
    // "Embark" opens Login first; new sailors reach Signup from the
    // "New here? Sign up" link there.
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _IllustrationFrame(),
                        const SizedBox(height: 32),
                        const _TextContent(),
                        const SizedBox(height: 32),
                        _CtaSection(onEmbark: () => _embark(context)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 280px frosted-glass circle wrapping the 260px onboarding photo.
class _IllustrationFrame extends StatelessWidget {
  const _IllustrationFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.glassFill,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(130),
              // Full-bleed logo art (already square, no matte to crop) — fit
              // as-is, unlike the old photo asset this replaced.
              child: Image.asset(
                AppAssets.appLogoMark,
                width: 260,
                height: 260,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextContent extends StatelessWidget {
  const _TextContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppAssets.wordmarkGlyph, width: 20, height: 20),
            const SizedBox(width: 8),
            Text('Wavemind', style: AppTextStyles.wordmark),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Your anchor in open waters',
          textAlign: TextAlign.center,
          style: AppTextStyles.tagline,
        ),
        const SizedBox(height: 16),
        Text(
          'A mental wellness companion built specifically for sailors. '
          'Find stillness, trace your waves, and connect with your crew on '
          'long voyages.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ],
    );
  }
}

class _CtaSection extends StatelessWidget {
  const _CtaSection({required this.onEmbark});

  final VoidCallback onEmbark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
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
            color: AppColors.seafoam,
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              onTap: onEmbark,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
                child: Center(
                  child: Text('Embark', style: AppTextStyles.buttonLarge),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'In partnership with International Maritime Welfare',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.creamSoft),
        ),
      ],
    );
  }
}
