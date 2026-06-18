// lib/src/widgets/bar_spectrum_visualizer.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../audify_controller.dart';
import '../frequency_data.dart';
import 'spectrum_magnitude_mapper.dart';

class BarSpectrumVisualizer extends StatefulWidget {
  final AudifyController controller;
  final Color color;
  final Color? glowColor;
  final Gradient? gradient;
  final int barCount;
  final double barWidth;
  final double gap;
  final double smoothing;
  final bool mirror;

  const BarSpectrumVisualizer({
    super.key,
    required this.controller,
    this.color = Colors.purpleAccent,
    this.glowColor,
    this.gradient,
    this.barCount = 32,
    this.barWidth = 4.0,
    this.gap = 6.0,
    this.smoothing = 0.75,
    this.mirror = false,
  });

  @override
  State<BarSpectrumVisualizer> createState() => _BarSpectrumVisualizerState();
}

class _BarSpectrumVisualizerState extends State<BarSpectrumVisualizer>
    with SingleTickerProviderStateMixin {
  List<double> _magnitudes = [];
  List<double> _smoothedMagnitudes = [];
  late AnimationController _animationController;
  StreamSubscription<FrequencyData>? _frequencyDataSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat();

    _resetMagnitudes();
    _subscribeToController();
  }

  @override
  void didUpdateWidget(BarSpectrumVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barCount != widget.barCount) {
      _resetMagnitudes();
    }
    if (oldWidget.controller != widget.controller) {
      _subscribeToController();
    }
  }

  void _resetMagnitudes() {
    _magnitudes = List.filled(widget.barCount, 0.0);
    _smoothedMagnitudes = List.filled(widget.barCount, 0.0);
  }

  void _subscribeToController() {
    _frequencyDataSubscription?.cancel();
    _frequencyDataSubscription = widget.controller.frequencyDataStream.listen((
      data,
    ) {
      if (mounted) {
        setState(() {
          _updateMagnitudes(data);
        });
      }
    });
  }

  void _updateMagnitudes(FrequencyData data) {
    final rawMags = data.rawMagnitudes;
    if (rawMags.isEmpty) return;

    _magnitudes = mapLogarithmicMagnitudes(
      rawMagnitudes: rawMags,
      outputCount: widget.barCount,
    );
    _smoothedMagnitudes = smoothMagnitudes(
      previous: _smoothedMagnitudes,
      current: _magnitudes,
      smoothing: widget.smoothing,
    );
  }

  @override
  void dispose() {
    _frequencyDataSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarSpectrumPainter(
        magnitudes: _smoothedMagnitudes,
        color: widget.color,
        glowColor: widget.glowColor ?? widget.color.withValues(alpha: 0.5),
        gradient: widget.gradient,
        barWidth: widget.barWidth,
        gap: widget.gap,
        mirror: widget.mirror,
        animation: _animationController,
      ),
    );
  }
}

class _BarSpectrumPainter extends CustomPainter {
  final List<double> magnitudes;
  final Color color;
  final Color glowColor;
  final Gradient? gradient;
  final double barWidth;
  final double gap;
  final bool mirror;
  final Animation<double> animation;

  _BarSpectrumPainter({
    required this.magnitudes,
    required this.color,
    required this.glowColor,
    this.gradient,
    required this.barWidth,
    required this.gap,
    required this.mirror,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (magnitudes.isEmpty) return;

    final totalWidth = magnitudes.length * (barWidth + gap) - gap;
    final startX = (size.width - totalWidth) / 2;
    final centerY = mirror ? size.height / 2 : size.height;

    for (int i = 0; i < magnitudes.length; i++) {
      final magnitude = magnitudes[i].clamp(0.0, 1.0);
      final barHeight =
          magnitude * (mirror ? size.height / 2 : size.height) * 0.9;
      final x = startX + i * (barWidth + gap);

      // Draw glow effect
      if (magnitude > 0.05) {
        final glowPaint = Paint()
          ..color = glowColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
          ..style = PaintingStyle.fill;

        final glowRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - 2,
            centerY - barHeight - 2,
            barWidth + 4,
            barHeight + 4,
          ),
          const Radius.circular(4),
        );

        canvas.drawRRect(glowRect, glowPaint);

        if (mirror) {
          final glowRectMirror = RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 2, centerY - 2, barWidth + 4, barHeight + 4),
            const Radius.circular(4),
          );
          canvas.drawRRect(glowRectMirror, glowPaint);
        }
      }

      // Draw main bar
      final paint = Paint()..style = PaintingStyle.fill;

      if (gradient != null) {
        paint.shader = gradient!.createShader(
          Rect.fromLTWH(x, centerY - barHeight, barWidth, barHeight),
        );
      } else {
        paint.color = color;
      }

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - barHeight, barWidth, barHeight),
        const Radius.circular(3),
      );

      canvas.drawRRect(rect, paint);

      // Draw mirror
      if (mirror) {
        final mirrorPaint = Paint()..style = PaintingStyle.fill;

        if (gradient != null) {
          mirrorPaint.shader = gradient!.createShader(
            Rect.fromLTWH(x, centerY, barWidth, barHeight),
          );
        } else {
          mirrorPaint.color = color.withValues(alpha: 0.5);
        }

        final mirrorRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY, barWidth, barHeight),
          const Radius.circular(3),
        );

        canvas.drawRRect(mirrorRect, mirrorPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarSpectrumPainter oldDelegate) {
    return true;
  }
}
