import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central typography for TideWell.
///
/// The design uses two typefaces, both available as Google Fonts (so they are
/// exact matches — no substitution required):
///   * **Outfit**  — display / headings / feature titles
///   * **Figtree** — body copy, labels, buttons, captions
///
/// Every named style below maps 1:1 to a text role in the Figma file. Screens
/// reference these instead of constructing [TextStyle]s inline.
abstract final class AppTextStyles {
  // --- Display / headings (Outfit) -----------------------------------------

  /// "Tidewell" wordmark — Outfit Bold 32.
  static TextStyle wordmark = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  /// Welcome tagline "Your anchor in open waters" — Outfit Medium 22.
  static TextStyle tagline = GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.cream,
  );

  /// User name on the dashboard — Outfit SemiBold 24.
  static TextStyle displayName = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Card heading, e.g. mood prompt — Outfit SemiBold 18.
  static TextStyle cardHeading = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Feature-tile title / section header — Outfit SemiBold 16.
  static TextStyle titleMedium = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Top-of-screen page title (top-level tabs) — Outfit Bold 22.
  static TextStyle headerTitle = GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  /// Back-header title on pushed sub-screens — Outfit SemiBold 20.
  static TextStyle screenTitle = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Large centred breathing cue — Outfit SemiBold 28.
  static TextStyle breatheHeadline = GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Numbered section prompt, e.g. "1. Select..." — Outfit Regular 16.
  static TextStyle sectionPrompt = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.cream,
  );

  /// Small card title — Outfit SemiBold 15.
  static TextStyle cardTitleSmall = GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Inline label heading, e.g. "Helmsman Advice" — Outfit SemiBold 14.
  static TextStyle labelMedium = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Author/name tag, e.g. chat handle — Outfit SemiBold 13.
  static TextStyle nameTag = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.cream,
  );

  /// Journal seaprompt copy — Outfit Medium 14.
  static TextStyle promptMedium = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.white,
  );

  /// Large numeric stat, e.g. game timer / match count — Outfit Bold 18.
  static TextStyle statValue = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  // --- Body & labels (Figtree) ---------------------------------------------

  /// Welcome body copy — Figtree Regular 15, 1.5 line-height.
  static TextStyle body = GoogleFonts.figtree(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.bodyMist,
  );

  /// Greeting / medium body — Figtree Regular 14.
  static TextStyle bodyMedium = GoogleFonts.figtree(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  /// Slightly larger body copy — Figtree Regular 16.
  static TextStyle bodyRegular = GoogleFonts.figtree(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.cream,
  );

  /// Emphasised 14px label, e.g. list-item title — Figtree SemiBold 14.
  static TextStyle bodyStrong = GoogleFonts.figtree(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Numeric timer value in the session pill — Figtree Bold 18.
  static TextStyle timerValue = GoogleFonts.figtree(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.seafoam,
  );

  /// Small status badge / chip, e.g. "STEADY VIBE" — Figtree SemiBold 11.
  static TextStyle badge = GoogleFonts.figtree(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.seafoam,
  );

  /// Small supporting copy — Figtree Regular 13.
  static TextStyle bodySmall = GoogleFonts.figtree(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  /// Caption / subtitle — Figtree Regular 12.
  static TextStyle caption = GoogleFonts.figtree(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  /// Emphasised inline label, e.g. "Day 42 at Sea" — Figtree Bold 15.
  static TextStyle labelStrong = GoogleFonts.figtree(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  /// Primary button label — Figtree Bold 16.
  static TextStyle buttonLarge = GoogleFonts.figtree(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.onAccent,
  );

  /// Small button label — Figtree Bold 13.
  static TextStyle buttonSmall = GoogleFonts.figtree(
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  /// Status-bar clock — Figtree SemiBold 14.
  static TextStyle statusBar = GoogleFonts.figtree(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// Bottom-nav tab label — Figtree 11 (regular inactive / semibold active).
  static TextStyle navLabel = GoogleFonts.figtree(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  /// Builds a Material [TextTheme] from the styles above so the app's
  /// [ThemeData] carries the same fonts everywhere by default.
  static TextTheme get textTheme => TextTheme(
    displaySmall: wordmark,
    headlineMedium: displayName,
    headlineSmall: tagline,
    titleLarge: cardHeading,
    titleMedium: titleMedium,
    bodyLarge: body,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: buttonLarge,
    labelSmall: navLabel,
  );
}
