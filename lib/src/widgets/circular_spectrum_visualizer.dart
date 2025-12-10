// lib/src/widgets/circular_spectrum_visualizer.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../audio_visualizer_controller.dart';
import '../frequency_data.dart';

class CircularSpectrumVisualizer extends StatefulWidget {
  final AudioVisualizerController controller;
  final double size;
  final Color color;
  final Color? glowColor;
  final double barWidth;
  final double gap;
  final int barCount;
  final double smoothing;
  final bool showCenterDot;

  const CircularSpectrumVisualizer({
    super.key,
    required this.controller,
    this.size = 300,
    this.color = Colors.purpleAccent,
    this.glowColor,
    this.barWidth = 4.0,
    this.gap = 2.0,
    this.barCount = 60,
    this.smoothing = 0.7,
    this.showCenterDot = true,
  });

  @override
  State<CircularSpectrumVisualizer> createState() =>
      _CircularSpectrumVisualizerState();
}

class _CircularSpectrumVisualizerState extends State<CircularSpectrumVisualizer>
    with SingleTickerProviderStateMixin {
  List<double> _magnitudes = [];
  List<double> _smoothedMagnitudes = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat();

    _magnitudes = List.filled(widget.barCount, 0.0);
    _smoothedMagnitudes = List.filled(widget.barCount, 0.0);

    widget.controller.frequencyDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _updateMagnitudes(data);
        });
      }
    });
  }

  void _updateMagnitudes(FrequencyData data) {
    // Distribute frequency bands across circular bars
    final rawMags = data.rawMagnitudes;
    if (rawMags.isEmpty) return;

    // Take logarithmic distribution for better visual representation
    for (int i = 0; i < widget.barCount; i++) {
      final index = _getLogIndex(i, widget.barCount, rawMags.length);
      if (index < rawMags.length) {
        _magnitudes[i] = rawMags[index];
      }
    }

    // Apply smoothing
    for (int i = 0; i < widget.barCount; i++) {
      _smoothedMagnitudes[i] = _smoothedMagnitudes[i] * widget.smoothing +
          _magnitudes[i] * (1 - widget.smoothing);
    }
  }

  int _getLogIndex(int linearIndex, int totalBars, int dataLength) {
    // Logarithmic mapping for better frequency distribution
    final normalized = linearIndex / totalBars;
    final logIndex = (math.pow(dataLength, normalized) - 1).toInt();
    return logIndex.clamp(0, dataLength - 1);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _CircularSpectrumPainter(
          magnitudes: _smoothedMagnitudes,
          color: widget.color,
          glowColor: widget.glowColor ?? widget.color.withValues(alpha: 0.5),
          barWidth: widget.barWidth,
          gap: widget.gap,
          animation: _animationController,
        ),
      ),
    );
  }
}

class _CircularSpectrumPainter extends CustomPainter {
  final List<double> magnitudes;
  final Color color;
  final Color glowColor;
  final double barWidth;
  final double gap;
  final Animation<double> animation;

  _CircularSpectrumPainter({
    required this.magnitudes,
    required this.color,
    required this.glowColor,
    required this.barWidth,
    required this.gap,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.6;
    final maxBarHeight = size.width / 2 * 0.35;

    // Draw glow effect
    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = barWidth + 4;

    // Draw main bars
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final angleStep = (2 * math.pi) / magnitudes.length;

    for (int i = 0; i < magnitudes.length; i++) {
      final angle = i * angleStep - math.pi / 2; // Start from top
      final magnitude = magnitudes[i].clamp(0.0, 1.0);
      final barHeight = magnitude * maxBarHeight;

      // Calculate start and end points
      final startX = center.dx + radius * math.cos(angle);
      final startY = center.dy + radius * math.sin(angle);
      final endX = center.dx + (radius + barHeight) * math.cos(angle);
      final endY = center.dy + (radius + barHeight) * math.sin(angle);

      // Draw glow
      if (magnitude > 0.1) {
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), glowPaint);
      }

      // Draw bar
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularSpectrumPainter oldDelegate) {
    return true;
  }
}
