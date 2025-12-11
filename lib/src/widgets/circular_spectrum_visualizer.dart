// lib/src/widgets/circular_spectrum_visualizer.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../audify_controller.dart';
import '../frequency_data.dart';

class CircularSpectrumVisualizer extends StatefulWidget {
  final AudifyController controller;
  final Color color;
  final Color? glowColor;
  final double barWidth;
  final double gap;
  final int barCount;
  final double smoothing;
  final ImageProvider? centerImage;

  const CircularSpectrumVisualizer({
    super.key,
    required this.controller,
    this.color = Colors.purpleAccent,
    this.glowColor,
    this.barWidth = 2.0,
    this.gap = 2.0,
    this.barCount = 40,
    this.smoothing = 0.7,
    this.centerImage,
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
  ui.Image? _resolvedImage;

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

    _loadImage();
  }

  @override
  void didUpdateWidget(CircularSpectrumVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.centerImage != widget.centerImage) {
      _loadImage();
    }
  }

  void _loadImage() async {
    if (widget.centerImage == null) {
      setState(() => _resolvedImage = null);
      return;
    }

    final imageStream = widget.centerImage!.resolve(const ImageConfiguration());
    imageStream.addListener(
      ImageStreamListener((ImageInfo info, bool synchronousCall) {
        if (mounted) {
          setState(() => _resolvedImage = info.image);
        }
      }),
    );
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
    return CustomPaint(
      painter: _CircularSpectrumPainter(
        magnitudes: _smoothedMagnitudes,
        color: widget.color,
        glowColor: widget.glowColor ?? widget.color.withValues(alpha: 0.5),
        barWidth: widget.barWidth,
        gap: widget.gap,
        animation: _animationController,
        centerImage: _resolvedImage,
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
  final ui.Image? centerImage;

  _CircularSpectrumPainter({
    required this.magnitudes,
    required this.color,
    required this.glowColor,
    required this.barWidth,
    required this.gap,
    required this.animation,
    this.centerImage,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Simple padding to ensure bars don't overflow
    const padding = 16.0;

    // Use the smaller dimension to ensure circle fits in both width and height
    final minDimension = size.width < size.height ? size.width : size.height;

    // Available radius after padding (using smaller dimension)
    final maxRadius = (minDimension / 2) - padding;

    // Use 55% for inner circle, 45% for bar length
    final radius = maxRadius * 0.55;
    final maxBarHeight = maxRadius * 0.45;

    // Draw center image if provided (using the exact same radius calculation)
    if (centerImage != null) {
      final imageSize = radius * 2 * 0.85; // 85% of inner circle diameter
      final imageRect = Rect.fromCenter(
        center: center,
        width: imageSize,
        height: imageSize,
      );

      // Create circular clip path
      final clipPath = Path()..addOval(imageRect);
      canvas.save();
      canvas.clipPath(clipPath);

      // Draw the image scaled to fit
      paintImage(
        canvas: canvas,
        rect: imageRect,
        image: centerImage!,
        fit: BoxFit.cover,
      );

      canvas.restore();
    }

    // Draw glow effect
    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
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
