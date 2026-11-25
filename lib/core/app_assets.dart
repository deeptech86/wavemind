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

  /// Brand glyph shown beside the "Wavemind" wordmark (Welcome, Login, Signup)
  /// — the recolored wave/face mark, matching the app icon and feature
  /// graphic.
  static const String wordmarkGlyph = '$_images/wordmark_glyph.png';

  /// Full-bleed recolored wave/face logo (same art as the Play Store icon
  /// and feature graphic) — the Welcome screen's circular hero illustration.
  static const String appLogoMark = '$_images/app_logo_mark.png';

  // --- Audio ------------------------------------------------------------
  // A mix of licensed Epidemic Sound tracks (ambient soundscapes + the Tidal
  // Breath score) and placeholder beds synthesized locally (pure-Python
  // `wave`) for sounds that aren't part of the licensed set. See
  // assets/audio/ and tool/synth_audio.py.

  static const String audioFoghornBell = '$_audio/foghorn_bell.wav';

  /// Licensed meditation score ("A New Beginning" — Jakob Ahlbom) looped
  /// under the Tidal Breath exercise.
  static const String audioTidalBreath = '$_audio/tidal_breath.mp3';

  /// The ten licensed Ambient Cabin Soundscape beds — ids match
  /// `backend/app/seed.py`'s `_SOUND_SEED` and `haven_screen.dart`'s
  /// bundled-fallback / catalog-id maps.
  static const String audioAmbientSlowDrift = '$_audio/ambient_slow_drift.mp3';
  static const String audioAmbientForestBirdsong =
      '$_audio/ambient_forest_birdsong.mp3';
  static const String audioAmbientClosedEyesSpeak =
      '$_audio/ambient_closed_eyes_speak.mp3';
  static const String audioAmbientDecemberImHome =
      '$_audio/ambient_december_im_home.mp3';
  static const String audioAmbientDeltaWaveDrone =
      '$_audio/ambient_delta_wave_drone.mp3';
  static const String audioAmbientEverbloom = '$_audio/ambient_everbloom.mp3';
  static const String audioAmbientGentleSolace =
      '$_audio/ambient_gentle_solace.mp3';
  static const String audioAmbientRecoveryAgain =
      '$_audio/ambient_recovery_again.mp3';
  static const String audioAmbientQuietSpa = '$_audio/ambient_quiet_spa.mp3';
  static const String audioAmbientLappingLake =
      '$_audio/ambient_lapping_lake.mp3';

  /// Spoken-word narration placeholder for the featured Lighthouse chapter
  /// (macOS `say -v Daniel`, encoded to AAC/M4A via `afconvert`).
  static const String audioLighthouseChapter = '$_audio/lighthouse_chapter.m4a';

  /// Short, non-looping stone-on-stone thud for Stone Cairn Balance, pitched
  /// per stone via `setPitch` so repeated placements don't sound identical.
  static const String audioStoneSettle = '$_audio/stone_settle.wav';

  /// Tumbling-stones clatter played when a Stone Cairn Balance tower topples.
  static const String audioStoneCollapse = '$_audio/stone_collapse.wav';
}
