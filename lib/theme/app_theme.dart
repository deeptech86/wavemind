import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Assembles the app-wide [ThemeData] from the centralized color and
/// typography tokens. Wavemind is a dark, deep-sea themed experience, so we
/// expose a single dark theme.
abstract final class AppTheme {
  /// Common radii used across cards, buttons and tiles.
  static const double radiusButton = 16;
  static const double radiusCard = 20;
  static const double radiusTile = 16;

  /// Large radius for hero surfaces (story cover art, feature heroes).
  static const double radiusLarge = 24;

  /// Fully-rounded radius for pills, chips and segmented controls.
  static const double radiusPill = 999;

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.seafoam,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.teal,
      onSecondary: AppColors.white,
      surface: AppColors.cardSurface,
      onSurface: AppColors.white,
    ).copyWith(surfaceTint: Colors.transparent);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.deepNavy,
      textTheme: AppTextStyles.textTheme,
      splashFactory: InkRipple.splashFactory,
    );
  }
}
