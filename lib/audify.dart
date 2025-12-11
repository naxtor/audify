/// Audify - Flutter Audio Visualizer Plugin
///
/// A high-performance audio visualizer for Flutter with trap/dubstep style visualizations.
///
/// ## Main Interface
///
/// The primary app-facing interface is [AudifyController]. Use this to:
/// - Initialize audio capture
/// - Start/stop visualization
/// - Access FFT, waveform, and frequency band data streams
///
/// ## Example Usage
///
/// ```dart
/// final controller = AudifyController();
///
/// // Initialize with system audio
/// await controller.initialize(audioSessionId: 0);
///
/// // Start capturing
/// await controller.startCapture();
///
/// // Use with visualizer widgets
/// SizedBox(
///   width: 300,
///   height: 300,
///   child: CircularSpectrumVisualizer(
///     controller: controller,
///     color: Colors.purpleAccent,
///   ),
/// )
///
/// // Clean up when done
/// await controller.dispose();
/// ```
///
/// ## Available Widgets
///
/// - [CircularSpectrumVisualizer] - Ring-style spectrum display
/// - [BarSpectrumVisualizer] - Vertical bars with optional mirror
///
/// See README.md for complete documentation.
library;

// Export the main app-facing controller (primary interface)
export 'src/audify_controller.dart';

// Export data models
export 'src/frequency_data.dart';

// Export visualizer widgets
export 'src/widgets/circular_spectrum_visualizer.dart';
export 'src/widgets/bar_spectrum_visualizer.dart';
