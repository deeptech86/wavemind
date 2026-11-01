import 'package:flutter/material.dart';

/// Central color palette for Wavemind, extracted verbatim from the Figma
/// design file (fileKey H1FxgO720R6jkN2ZwdkSkk).
///
/// This is the single source of truth for color across the app. Screens and
/// widgets must reference these tokens rather than hardcoding hex values so the
/// theme stays consistent as new screens are added.
abstract final class AppColors {
  // --- Core surfaces (deep-sea navy) ---------------------------------------
  /// Deepest navy — app base / bottom nav background.
  static const Color deepNavy = Color(0xFF070F2B);

  /// Home dashboard gradient bottom.
  static const Color navyBlue = Color(0xFF1B2A5B);

  /// Elevated card / banner surface on the dashboard.
  static const Color cardSurface = Color(0xFF1F3160);

  // --- App-wide (sunrise-over-water) background gradient stops -------------
  static const Color welcomeTop = Color(0xFF0A1E36); // deep navy
  static const Color welcomeMid = Color(0xFF2E5C70); // ocean teal @ 70%
  static const Color welcomeBottom = Color(0xFFE09F67); // sunset amber

  /// Flat fill behind all navigation chrome (bottom nav bar / app bars).
  /// Deliberately NOT part of the gradient — a solid deep-navy plate.
  static const Color navBarBackground = Color(0xFF0A1E36);

  // --- Accents --------------------------------------------------------------
  /// Primary accent — CTA buttons, active tab (sea-foam green).
  static const Color seafoam = Color(0xFF57CC99);

  /// Secondary accent — mood card, decorative waves (teal).
  static const Color teal = Color(0xFF38A3A5);

  /// Alert accent — the "High Storm" mood state (warm coral red).
  static const Color stormRed = Color(0xFFFF6B6B);

  /// Neutral sand accent — the "Choppy Water" mood state.
  static const Color sand = Color(0xFFDFD3C3);

  // --- Text -----------------------------------------------------------------
  /// Warm cream — headline & section labels.
  static const Color cream = Color(0xFFF5EBE6);

  /// Slightly warmer cream — fine print on the welcome screen.
  static const Color creamSoft = Color(0xFFEBE3D6);

  /// Body copy on the welcome (over-water) background.
  static const Color bodyMist = Color(0xFFC7D4E0);

  /// Muted blue-grey — secondary/subtitle text on dark surfaces.
  static const Color muted = Color(0xFF8D9CB0);

  /// Light teal text used inside the mood card.
  static const Color tealTint = Color(0xFFE2F1F1);

  /// Ink used for text/icons that sit on the seafoam CTA.
  static const Color onAccent = Color(0xFF070F2B);

  static const Color white = Color(0xFFFFFFFF);

  // --- Glass / translucent overlays ----------------------------------------
  static const Color glassFill = Color(0x0FFFFFFF); // white @ ~6%
  static const Color glassBorder = Color(0x21FFFFFF); // white @ ~13%

  /// Fainter fills/borders used on cards & tiles across the feature screens.
  static const Color glassFillFaint = Color(0x08FFFFFF); // white @ 3%
  static const Color glassBorderSoft = Color(0x14FFFFFF); // white @ 8%

  /// Dark scrim used inside the teal encouragement box input.
  static const Color overlayDark = Color(0x30000000); // black @ 19%

  // --- Accent tints (chips, badges, borders, selectable states) ------------
  static const Color seafoamFaint = Color(0x2157CC99); // seafoam @ 13%
  static const Color seafoamBorder = Color(0x3057CC99); // seafoam @ 19%
  static const Color tealFaint = Color(0x2138A3A5); // teal @ 13%
  static const Color tealFaintSoft = Color(0x1438A3A5); // teal @ 8%
  static const Color tealBorder = Color(0x4038A3A5); // teal @ 25%
  static const Color sandFaint = Color(0x21DFD3C3); // sand @ 13%
  static const Color stormFaint = Color(0x21FF6B6B); // storm red @ 13%
  static const Color mutedFaint = Color(0x218D9CB0); // muted @ 13%

  /// Drop shadow beneath raised cards / CTAs.
  static const Color cardShadow = Color(0x4D070F2B); // #070F2B @ 30%

  // --- Meditative playback glows (Stage 2 audio-synced animations) ----------
  /// Soft seafoam glow core for the pulsing background while audio plays.
  static const Color seafoamGlow = Color(0x4D57CC99); // seafoam @ 30%
  /// Fainter teal glow ring that trails the seafoam core.
  static const Color tealGlow = Color(0x3338A3A5); // teal @ 20%

  // --- Gradients ------------------------------------------------------------
  /// The single app-wide screen background gradient
  /// (#0A1E36 → #2E5C70 @70% → #E09F67 @100%). Used on every screen.
  static const LinearGradient appBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [welcomeTop, welcomeMid, welcomeBottom],
    stops: [0.0, 0.7, 1.0],
  );

  /// Teal→seafoam orb at the centre of the guided-breathing arena.
  static const LinearGradient breatheOrbGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, seafoam],
  );
}
