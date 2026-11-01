/// Central registry of bundled asset paths (exported from the Figma design).
///
/// Keeping paths here avoids magic strings scattered across widgets.
abstract final class AppAssets {
  static const String _icons = 'assets/icons';
  static const String _images = 'assets/images';
  static const String _audio = 'assets/audio';

  // Icons (Lucide-style line icons exported as SVG, colors baked to design).
  static const String anchorWordmark = '$_icons/anchor_wordmark.svg';
  static const String anchor = '$_icons/anchor.svg';
  static const String compass = '$_icons/compass.svg';
  static const String waves = '$_icons/waves.svg';
  static const String wavesNav = '$_icons/waves_nav.svg';
  static const String bookOpenText = '$_icons/book_open_text.svg';
  static const String circleX = '$_icons/circle_x.svg';
  static const String sailboat = '$_icons/sailboat.svg';
  static const String pen = '$_icons/pen.svg';
  static const String users = '$_icons/users.svg';
  static const String chartLine = '$_icons/chart_line.svg';
  static const String decoWaves = '$_icons/deco_waves.svg';

  // Feature-screen icons (added for the seven inner screens).
  static const String arrowLeft = '$_icons/arrow_left.svg';
  static const String cloudRainWind = '$_icons/cloud_rain_wind.svg';
  static const String cloudFog = '$_icons/cloud_fog.svg';
  static const String moonStar = '$_icons/moon_star.svg';
  static const String wind = '$_icons/wind.svg';
  static const String mail = '$_icons/mail.svg';
  static const String volumeOff = '$_icons/volume_off.svg';
  static const String pause = '$_icons/pause.svg';
  static const String helpCircle = '$_icons/help_circle.svg';
  static const String mapPin = '$_icons/map_pin.svg';
  static const String lightbulbOff = '$_icons/lightbulb_off.svg';
  static const String lock = '$_icons/lock.svg';
  static const String mic = '$_icons/mic.svg';
  static const String camera = '$_icons/camera.svg';
  static const String info = '$_icons/info.svg';
  static const String clock = '$_icons/clock.svg';
  static const String shell = '$_icons/shell.svg';
  static const String sparkles = '$_icons/sparkles.svg';
  static const String refreshCw = '$_icons/refresh_cw.svg';
  static const String smilePlus = '$_icons/smile_plus.svg';
  static const String send = '$_icons/send.svg';
  static const String insightsChart = '$_icons/insights_chart.svg';

  // Raster imagery.
  static const String onboardingSailboat = '$_images/onboarding_sailboat.png';

  /// Default profile-photo placeholder shown until a sailor picks their own
  /// photo — a seated meditation silhouette against a sunset-over-water
  /// gradient, drawn in-house (vector, not a licensed stock photo).
  static const String avatar = '$_images/avatar_placeholder.svg';

  // --- Audio (Stage 2) ------------------------------------------------------
  // Placeholder royalty-free beds synthesized locally (pure-Python `wave`),
  // plus macOS `say`-generated narration. All to be swapped for real narration
  // / sound design later. See assets/audio/ and scratchpad/synth_audio.py.

  /// Seamlessly-looping ambient beds (mono 22.05 kHz WAV).
  static const String audioRollingDeepSea = '$_audio/rolling_deep_sea.wav';
  static const String audioSteelHullRain = '$_audio/steel_hull_rain.wav';
  static const String audioFoghornBell = '$_audio/foghorn_bell.wav';

  /// Calming breathing-pace pad looped under the Tidal Breath exercise.
  static const String audioTidalBreath = '$_audio/tidal_breath.wav';

  /// Spoken-word narration placeholder for the featured Lighthouse chapter
  /// (macOS `say -v Daniel`, encoded to AAC/M4A via `afconvert`).
  static const String audioLighthouseChapter = '$_audio/lighthouse_chapter.m4a';
}
