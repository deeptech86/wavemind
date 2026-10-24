import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Shared form building blocks for the auth + profile screens, so login,
/// signup, and the crew-profile editor all draw from one styling source
/// (previously these lived as private widgets inside `profile_screen.dart`).

/// A labelled text field in the app's glass-on-navy style.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.optional = false,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.textCapitalizationWords = false,
    this.validator,
    this.onFieldSubmitted,
    this.fillColor = AppColors.cardSurface,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  /// Appends a muted "(optional)" tag to the label when true.
  final bool optional;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;

  /// Capitalises the first letter of each word (used for names / fleet).
  final bool textCapitalizationWords;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  /// Override when the field sits on a surface that is already
  /// [AppColors.cardSurface] (its default), so the field stays visible
  /// against its container instead of blending into it.
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: AppTextStyles.caption),
            if (optional) ...[
              const SizedBox(width: 6),
              Text(
                '(optional)',
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          textCapitalization: textCapitalizationWords
              ? TextCapitalization.words
              : TextCapitalization.none,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          cursorColor: AppColors.seafoam,
          style: AppTextStyles.body.copyWith(color: AppColors.white),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: fillColor,
            hintText: hint,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTile),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTile),
              borderSide: const BorderSide(color: AppColors.glassBorderSoft),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTile),
              borderSide: const BorderSide(color: AppColors.seafoam),
            ),
            errorStyle: AppTextStyles.caption.copyWith(color: AppColors.stormRed),
          ),
        ),
      ],
    );
  }
}

/// The primary seafoam CTA button, with a built-in busy spinner.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
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
        color: AppColors.seafoam,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onAccent,
                      ),
                    )
                  : Text(
                      label,
                      style: AppTextStyles.buttonLarge.copyWith(
                        color: AppColors.onAccent,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline, dismissible-feeling error banner with an optional retry action.
class InlineErrorBanner extends StatelessWidget {
  const InlineErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.stormFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.stormRed),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.stormRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.cream),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.seafoam,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A light client-side email check. The backend validates authoritatively.
String? validateEmail(String? v) {
  final value = v?.trim() ?? '';
  if (value.isEmpty) return 'Please enter an email.';
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  return ok ? null : 'Please enter a valid email.';
}

/// Wordmark + title + subtitle block shared by the Login and Signup screens.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.anchorWordmark, width: 20, height: 20),
            const SizedBox(width: 8),
            Text('Tidewell', style: AppTextStyles.wordmark),
          ],
        ),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.tagline),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.bodyMist),
        ),
      ],
    );
  }
}

/// "New here? Sign up" / "Already have an account? Log in" cross-link.
class SwitchAuthLink extends StatelessWidget {
  const SwitchAuthLink({
    super.key,
    required this.lead,
    required this.action,
    required this.onTap,
  });

  final String lead;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            lead,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.creamSoft),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(
            action,
            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.seafoam),
          ),
        ),
      ],
    );
  }
}
