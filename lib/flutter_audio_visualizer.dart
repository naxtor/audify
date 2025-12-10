/// Flutter Audio Visualizer Plugin
///
/// A high-performance audio visualizer for Flutter with trap/dubstep style visualizations.
///
/// ## Main Interface
///
/// The primary app-facing interface is [AudioVisualizerController]. Use this to:
/// - Initialize audio capture
/// - Start/stop visualization
/// - Access FFT, waveform, and frequency band data streams
///
/// ## Example Usage
///
/// ```dart
/// final controller = AudioVisualizerController();
///
/// // Initialize with system audio
/// await controller.initialize(audioSessionId: 0);
///
/// // Start capturing
/// await controller.startCapture();
///
/// // Use with visualizer widgets
/// CircularSpectrumVisualizer(
///   controller: controller,
///   size: 300,
///   color: Colors.purpleAccent,
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
export 'src/audio_visualizer_controller.dart';

// Export data models
export 'src/frequency_data.dart';

// Export visualizer widgets
export 'src/widgets/circular_spectrum_visualizer.dart';
export 'src/widgets/bar_spectrum_visualizer.dart';
