import 'dart:ui' show Offset;

/// Pure, UI- and sensor-independent model for the "Sextant Horizon Balance"
/// bubble-level game.
///
/// The device's tilt (accelerometer x / y) is mapped to a bubble offset inside a
/// circular vial. While the bubble stays within [tolerance] of dead centre, a
/// "calm meter" accumulates toward [targetHold]; drift lets it decay gently so a
/// steady hand is rewarded without punishing a single wobble. Completion is
/// reached once the accumulated centred time meets [targetHold].
///
/// Keeping this Flutter-/sensors_plus-free makes the mapping and meter logic
/// unit-testable without a real sensor stream.
class SextantBalance {
  SextantBalance({
    this.tolerance = 0.18,
    this.targetHold = const Duration(seconds: 20),
    this.sensitivity = 0.11,
    this.decayFactor = 0.5,
  }) : assert(tolerance > 0 && tolerance < 1),
       assert(sensitivity > 0),
       assert(decayFactor >= 0 && decayFactor <= 1);

  /// Normalized radius (in vial-radius units) within which the bubble counts as
  /// centred.
  final double tolerance;

  /// Total centred time required to fill the calm meter.
  final Duration targetHold;

  /// Scales raw accelerometer magnitude (roughly m/s^2) into the normalized
  /// `[-1, 1]` vial space. Gravity on a fully-tilted axis is ~9.8, so a modest
  /// factor keeps small, calm tilts usable.
  final double sensitivity;

  /// Fraction of the forward fill rate at which the meter drains while the
  /// bubble is off-centre (`0` = never drains, `1` = drains as fast as it fills).
  final double decayFactor;

  double _heldSeconds = 0;

  /// Accumulated centred time, clamped to [targetHold].
  Duration get held =>
      Duration(milliseconds: (_heldSeconds * 1000).round());

  /// Calm-meter fill fraction in `[0, 1]`.
  double get progress =>
      (_heldSeconds / targetHold.inMilliseconds * 1000).clamp(0.0, 1.0);

  /// Whether the calm meter is full.
  bool get isComplete => _heldSeconds * 1000 >= targetHold.inMilliseconds;

  /// Maps raw accelerometer readings to a normalized bubble offset.
  ///
  /// A level device reads ~`(0, 0, 9.8)`, so x/y are near zero and the bubble
  /// sits centred. Tilting pushes the corresponding axis. The y axis is negated
  /// so tilting the top of the device away from you moves the bubble "up" toward
  /// the horizon, matching a physical spirit level. Both axes clamp to `[-1, 1]`.
  Offset bubbleOffset(double accelX, double accelY) {
    final nx = (accelX * sensitivity).clamp(-1.0, 1.0);
    final ny = (-accelY * sensitivity).clamp(-1.0, 1.0);
    return Offset(nx, ny);
  }

  /// Whether [bubble] (normalized offset) is within the centred [tolerance].
  bool isCentered(Offset bubble) => bubble.distance <= tolerance;

  /// Advances the calm meter by [delta], filling while [centered] and draining
  /// (scaled by [decayFactor]) otherwise. Returns the new [progress].
  double tick(Duration delta, {required bool centered}) {
    final seconds = delta.inMicroseconds / Duration.microsecondsPerSecond;
    if (centered) {
      _heldSeconds += seconds;
    } else {
      _heldSeconds -= seconds * decayFactor;
    }
    final maxSeconds = targetHold.inMilliseconds / 1000;
    _heldSeconds = _heldSeconds.clamp(0.0, maxSeconds);
    return progress;
  }

  /// Resets the calm meter to empty for a new session.
  void reset() => _heldSeconds = 0;
}
