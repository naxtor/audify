# Flutter Audio Visualizer

A high-performance audio visualizer plugin for Flutter with beautiful trap/dubstep style visualizations including circular spectrum and bar spectrum displays.

[![Pub Version](https://img.shields.io/pub/v/flutter_audio_visualizer)](https://pub.dev/packages/flutter_audio_visualizer)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

🎵 **Real-time Audio Visualization**
- Circular spectrum visualizer with smooth 60 FPS animations
- Vertical bar spectrum with optional mirror effect

🚀 **High Performance**
- Native FFT processing for optimal performance
  - Android: Visualizer API
  - iOS: Accelerate framework (vDSP)
- Smooth animations with configurable smoothing
- Minimal CPU usage (<5%)

🎨 **Highly Customizable**
- Customizable colors, gradients, and glow effects
- Adjustable bar count, width, and spacing
- Multiple visualization styles and layouts

📱 **Cross-Platform Support**
- ✅ Android (API 21+)
- ✅ iOS (12.0+)

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_audio_visualizer: ^1.0.0
  permission_handler: ^11.0.1  # For runtime permissions
```

Run:

```bash
flutter pub get
```

## Platform Setup

### Android

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

### iOS

Add permission to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to visualize audio.</string>
```

## Quick Start

### 1. Request Permission

```dart
import 'package:permission_handler/permission_handler.dart';

final status = await Permission.microphone.request();
if (!status.isGranted) {
  // Handle permission denied
  return;
}
```

### 2. Create and Initialize Controller

```dart
import 'package:flutter_audio_visualizer/flutter_audio_visualizer.dart';

final controller = AudioVisualizerController();

// Initialize with system audio
await controller.initialize(audioSessionId: 0);

// Start capturing
await controller.startCapture();
```

### 3. Use Visualizer Widgets

```dart
CircularSpectrumVisualizer(
  controller: controller,
  size: 300,
  color: Colors.purpleAccent,
)
```

### 4. Clean Up

```dart
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_audio_visualizer/flutter_audio_visualizer.dart';
import 'package:permission_handler/permission_handler.dart';

class VisualizerPage extends StatefulWidget {
  @override
  State<VisualizerPage> createState() => _VisualizerPageState();
}

class _VisualizerPageState extends State<VisualizerPage> {
  late AudioVisualizerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AudioVisualizerController();
    _initialize();
  }

  Future<void> _initialize() async {
    // Request permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    // Initialize and start
    await _controller.initialize(audioSessionId: 0);
    await _controller.startCapture();
    
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isInitialized
            ? CircularSpectrumVisualizer(
                controller: _controller,
                size: 300,
                color: Colors.purpleAccent,
                barCount: 60,
              )
            : CircularProgressIndicator(),
      ),
    );
  }
}
```

## Visualizer Widgets

### Circular Spectrum

```dart
CircularSpectrumVisualizer(
  controller: _controller,
  size: 300,
  color: Colors.purpleAccent,
  glowColor: Colors.purple.withValues(alpha: 0.6),
  barCount: 60,
  barWidth: 4.0,
  gap: 2.0,
  smoothing: 0.7,
  showCenterDot: true,
)
```

### Bar Spectrum

```dart
BarSpectrumVisualizer(
  controller: _controller,
  width: 300,
  height: 200,
  color: Colors.cyan,
  glowColor: Colors.cyanAccent.withValues(alpha: 0.5),
  barWidth: 4.0,
  gap: 2.0,
  mirror: true,  // Mirror effect
  smoothing: 0.7,
  gradient: LinearGradient(
    colors: [Colors.blue, Colors.cyan, Colors.teal],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  ),
)
```

## Advanced Usage

### Using Frequency Band Data

```dart
// Listen to processed frequency bands
_controller.frequencyDataStream.listen((FrequencyData data) {
  print('Sub Bass: ${data.subBass}');
  print('Bass: ${data.bass}');
  print('Peak: ${data.peak}');
  print('Average: ${data.average}');
});
```

### Using Raw FFT Data

```dart
// Listen to raw FFT magnitudes
_controller.fftStream.listen((List<double> fft) {
  // Process FFT data yourself
  final magnitudes = fft; // 0.0 to 1.0
});
```

### Custom Audio Session (Android)

```dart
// For visualizing specific MediaPlayer
// Get audioSessionId from your MediaPlayer
final audioSessionId = audioPlayer.audioSessionId;

await _controller.initialize(audioSessionId: audioSessionId);
```

## Frequency Bands

The plugin extracts 7 frequency bands optimized for music visualization:

| Band | Frequency Range | Description |
|------|----------------|-------------|
| **Sub Bass** | 20-60 Hz | Deep bass frequencies |
| **Bass** | 60-250 Hz | Bass and kick drums |
| **Low Mids** | 250-500 Hz | Low midrange |
| **Mids** | 500-2000 Hz | Vocals and instruments |
| **High Mids** | 2000-4000 Hz | Upper midrange |
| **Presence** | 4000-6000 Hz | Clarity and presence |
| **Brilliance** | 6000-20000 Hz | High frequencies |

## API Reference

### AudioVisualizerController

#### Methods

| Method | Parameters | Description |
|--------|------------|-------------|
| `initialize()` | `audioSessionId`, `captureSize` | Initialize the visualizer |
| `startCapture()` | - | Start capturing audio data |
| `stopCapture()` | - | Stop capturing audio data |
| `dispose()` | - | Release all resources |

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `fftStream` | `Stream<List<double>>` | Raw FFT magnitudes (0.0-1.0) |
| `frequencyDataStream` | `Stream<FrequencyData>` | Processed frequency bands |
| `isInitialized` | `bool` | Initialization status |
| `isCapturing` | `bool` | Capture status |

### FrequencyData

Access specific frequency bands:

```dart
data.subBass      // 20-60 Hz
data.bass         // 60-250 Hz
data.lowMids      // 250-500 Hz
data.mids         // 500-2000 Hz
data.highMids     // 2000-4000 Hz
data.presence     // 4000-6000 Hz
data.brilliance   // 6000-20000 Hz
data.peak         // Peak across all bands
data.average      // Average across all bands
```

## Performance Optimization

### Adjust Capture Size

```dart
// Lower = faster, Higher = more detail
await _controller.initialize(captureSize: 1024);  // Fast
await _controller.initialize(captureSize: 4096);  // Detailed
```

### Reduce Bar Count

```dart
// Fewer bars = better performance
CircularSpectrumVisualizer(barCount: 30)  // Fast
CircularSpectrumVisualizer(barCount: 120) // Detailed
```

### Adjust Smoothing

```dart
// Higher = smoother but less responsive
CircularSpectrumVisualizer(smoothing: 0.9)  // Very smooth
CircularSpectrumVisualizer(smoothing: 0.5)  // More responsive
```

## Troubleshooting

**No visualization appears:**
- Ensure microphone permission is granted
- Verify audio is playing on the device
- Check that controller is initialized and started

**Poor performance:**
- Reduce `captureSize` (e.g., 1024 or 512)
- Lower `barCount` in visualizers
- Increase `smoothing` value (0.7-0.9)

**Permission errors:**
- Add permissions to AndroidManifest.xml (Android) or Info.plist (iOS)
- Request runtime permission using `permission_handler`

## Platform Differences

**iOS vs Android:**
- iOS captures system-wide audio (all apps)
- Android can target specific audio sessions
- Both achieve equivalent performance

## Example App

Run the complete example:

```bash
cd example
flutter run
```

Features all visualizer types with customization options.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- 📦 [pub.dev](https://pub.dev/packages/flutter_audio_visualizer)
- 🐛 [Issue Tracker](https://github.com/yourusername/flutter_audio_visualizer/issues)  
- ⭐ Star on GitHub if you find this useful!

---

**Made with ❤️ for the Flutter community**

- FFT processing: [fftea](https://pub.dev/packages/fftea)
- Inspired by trap/dubstep music visualizers

## Support

If you find this package helpful, please give it a ⭐ on [GitHub](https://github.com/naxtor/flutter_audio_visualizer)!

For bugs or feature requests, please [open an issue](https://github.com/naxtor/flutter_audio_visualizer/issues).

