import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A soft, slow pulsing "breathing glow" that renders behind playback content.
///
/// The animation is tied to playback state: the driving [AnimationController]
/// only repeats while [playing] is true and freezes (and fades out) when
/// paused/stopped. This keeps the meditative motion coherent with whether
/// audio is actually sounding, rather than running as decoration regardless.
///
/// Uses only existing Wavemind palette tokens (seafoam / teal glows) layered
/// over whatever gradient already sits behind it — it paints additively with
/// translucent radial glows and never introduces a new opaque background.
class AmbientPulseBackground extends StatefulWidget {
  const AmbientPulseBackground({
    super.key,
    required this.playing,
    this.glowColor = AppColors.seafoamGlow,
    this.trailColor = AppColors.tealGlow,
    this.period = const Duration(seconds: 7),
    this.intensity = 1.0,
    this.alignment = const Alignment(0, -0.2),
    this.child,
  });

  /// Whether audio is currently sounding. Drives whether the pulse animates.
  final bool playing;

  /// Core glow color (defaults to a translucent seafoam).
  final Color glowColor;

  /// Trailing ripple color (defaults to a fainter translucent teal).
  final Color trailColor;

  /// Duration of one full breathe (expand + contract) cycle.
  final Duration period;

  /// Overall strength multiplier (0..1+) for the glow opacity/size.
  final double intensity;

  /// Where the glow is centered within the painted area.
  final Alignment alignment;

  /// Optional foreground content painted on top of the glow.
  final Widget? child;

  @override
  State<AmbientPulseBackground> createState() => _AmbientPulseBackgroundState();
}

class _AmbientPulseBackgroundState extends State<AmbientPulseBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    _syncToPlayback();
  }

  @override
  void didUpdateWidget(AmbientPulseBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
    }
    if (oldWidget.playing != widget.playing) {
      _syncToPlayback();
    }
  }

  void _syncToPlayback() {
    if (widget.playing) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            // Fade the whole glow in while playing and out when paused so a
            // frozen frame doesn't linger as static decoration.
            child: AnimatedOpacity(
              opacity: widget.playing ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _PulsePainter(
                      t: _controller.value,
                      glowColor: widget.glowColor,
                      trailColor: widget.trailColor,
                      intensity: widget.intensity,
                      alignment: widget.alignment,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.t,
    required this.glowColor,
    required this.trailColor,
    required this.intensity,
    required this.alignment,
  });

  /// Normalized phase 0..1 of the breathe cycle.
  final double t;
  final Color glowColor;
  final Color trailColor;
  final double intensity;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final center = alignment.alongSize(size);
    final maxRadius = math.max(size.width, size.height);

    // Smooth 0..1..0 breathe curve.
    final breathe = (math.sin(2 * math.pi * t - math.pi / 2) + 1) / 2;

    // Core glow — grows and brightens on the in-breath.
    final coreRadius = maxRadius * (0.45 + 0.22 * breathe);
    final coreOpacity = (0.35 + 0.65 * breathe) * intensity;
    _paintGlow(canvas, center, coreRadius, glowColor, coreOpacity);

    // Trailing ripple — a second, larger ring offset in phase.
    final trailBreathe =
        (math.sin(2 * math.pi * t - math.pi / 2 + math.pi * 0.6) + 1) / 2;
    final trailRadius = maxRadius * (0.6 + 0.3 * trailBreathe);
    final trailOpacity = (0.2 + 0.4 * trailBreathe) * intensity;
    _paintGlow(canvas, center, trailRadius, trailColor, trailOpacity);
  }

  void _paintGlow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    if (radius <= 0) return;
    final clamped = opacity.clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: color.a * clamped),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.t != t ||
      old.glowColor != glowColor ||
      old.trailColor != trailColor ||
      old.intensity != intensity ||
      old.alignment != alignment;
}
