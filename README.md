# Audify

A high-performance audio visualizer plugin for Flutter with beautiful trap/dubstep style visualizations including circular spectrum and bar spectrum displays.

[![Pub Version](https://img.shields.io/badge/pub-v1.1.0-blue)](https://pub.dev/packages/audify)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

![circular spectrum with image demo](https://raw.githubusercontent.com/naxtor/audify/main/assets/gifs/ezgif-875108c491fd79d4.gif)
![Visucircular spectrumalizer without image demo](https://raw.githubusercontent.com/naxtor/audify/main/assets/gifs/ezgif-870cd2280d788ec7.gif)
![bar spectrum demo](https://raw.githubusercontent.com/naxtor/audify/main/assets/gifs/ezgif-8a2139feeeb5b77d.gif)
![bar spectrum mirror demo](https://raw.githubusercontent.com/naxtor/audify/main/assets/gifs/ezgif-8e35589604b8f3a6.gif)

## Key Highlights

**🎧 No Audio File Required!**  
Unlike other visualizer libraries, this plugin **captures and visualizes ANY audio playing on your device** - whether it's from Spotify, YouTube, local music players, or any other app. No need to import or manage audio files in your Flutter app!

## Features

🎵 **Real-time Audio Visualization**
- Circular spectrum visualizer with smooth 60 FPS animations and optional center image/album artwork
- Vertical bar spectrum with optional mirror effect
- Visualizes **system-wide audio** - works with any audio source on the device

🚀 **High Performance**
- Native FFT processing for optimal performance
  - Android: Visualizer API (captures system audio output)
  - iOS: Accelerate framework (vDSP) with AVAudioEngine
- Smooth animations with configurable smoothing
- Minimal CPU usage (<5%)
- Adaptive sizing for non-square containers

🎨 **Highly Customizable**
- Customizable colors, gradients, and glow effects
- Adjustable bar count, width, and spacing
- Multiple visualization styles and layouts
- Add album artwork or any image to circular visualizer center

📱 **Cross-Platform Support**
- ✅ Android (API 21+)
- ✅ iOS (12.0+)

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  audify: ^1.1.0
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

> **💡 Pro Tip:** This plugin captures **system-wide audio**! You don't need to import audio files or use a specific audio player. Just play music from any app (Spotify, YouTube, local player, etc.) and the visualizer will react to it automatically.

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
import 'package:audify/audify.dart';

final controller = AudifyController();

// Initialize with system audio (audioSessionId: 0 captures all audio)
await controller.initialize(audioSessionId: 0);

// Start capturing - now it will visualize ANY audio playing on the device!
await controller.startCapture();
```

### 3. Use Visualizer Widgets

```dart
SizedBox(
  width: 300,
  height: 300,
  child: CircularSpectrumVisualizer(
    controller: controller,
    color: Colors.purpleAccent,
  ),
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
import 'package:audify/audify.dart';
import 'package:permission_handler/permission_handler.dart';

class VisualizerPage extends StatefulWidget {
  @override
  State<VisualizerPage> createState() => _VisualizerPageState();
}

class _VisualizerPageState extends State<VisualizerPage> {
  late AudifyController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AudifyController();
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
            ? SizedBox(
                width: 300,
                height: 300,
                child: CircularSpectrumVisualizer(
                  controller: _controller,
                  color: Colors.purpleAccent,
                  barCount: 40,
                ),
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
// Wrap in SizedBox to control size
SizedBox(
  width: 300,
  height: 300,
  child: CircularSpectrumVisualizer(
    controller: _controller,
    color: Colors.purpleAccent,
    glowColor: Colors.purple.withValues(alpha: 0.6),
    barCount: 40,
    barWidth: 2.0,
    gap: 2.0,
    smoothing: 0.7,  
    centerImage: AssetImage('assets/album_art.png'), // Optional album artwork
  ),
)
```

**Properties:**
- `controller` (required): `AudifyController` - Controls the audio data stream
- `color`: `Color` - Primary color of the visualizer bars (default: `Colors.purpleAccent`)
- `glowColor`: `Color?` - Glow effect color (default: primary color with 50% opacity)
- `barCount`: `int` - Number of bars in the circle (default: 40)
- `barWidth`: `double` - Width of each bar in pixels (default: 2.0)
- `gap`: `double` - Gap between bars in pixels (default: 2.0)
- `smoothing`: `double` - Smoothing factor 0.0-1.0, higher = smoother (default: 0.7)
- `centerImage`: `ImageProvider?` - Optional image to display in the center (album artwork, logo, etc.)

**Adaptive Sizing:**
The visualizer automatically adapts to its parent container size. Wrap it in a `SizedBox`, `Container`, or any sized widget to control dimensions. Works perfectly in both square and non-square containers.

### Bar Spectrum

```dart
// Wrap in SizedBox to control size
SizedBox(
  width: double.infinity,
  height: 200,
  child: BarSpectrumVisualizer(
    controller: _controller,
    color: Colors.cyan,
    glowColor: Colors.cyanAccent.withValues(alpha: 0.5),
    barWidth: 4.0,
    gap: 6.0,
    mirror: true,  // Mirror effect
    smoothing: 0.75,
    gradient: LinearGradient(
      colors: [Colors.blue, Colors.cyan, Colors.teal],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    ),
  ),
)
```

**Properties:**
- `controller` (required): `AudifyController` - Controls the audio data stream
- `color`: `Color` - Primary color of the bars (default: `Colors.purpleAccent`)
- `glowColor`: `Color?` - Glow effect color (default: primary color with 50% opacity)
- `gradient`: `Gradient?` - Optional gradient to apply to bars (overrides color)
- `barCount`: `int` - Number of frequency bars to display (default: 32)
- `barWidth`: `double` - Width of each bar in pixels (default: 4.0)
- `gap`: `double` - Gap between bars in pixels (default: 6.0)
- `smoothing`: `double` - Smoothing factor 0.0-1.0, higher = smoother (default: 0.75)
- `mirror`: `bool` - Enable mirror effect (default: false)

**Adaptive Sizing:**
The visualizer automatically adapts to its parent container size. Use `double.infinity` for width or height to fill available space, or wrap in a `SizedBox` for precise control.

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

### AudifyController

#### Constructor

```dart
AudifyController({
  AudifyPlatform? platform,           // Optional: Custom platform for testing
  int minProcessIntervalMs = 16,      // Optional: Frame throttle interval (default: 16ms / ~60 FPS)
})
```

**Parameters:**
- `platform`: Custom platform implementation (mainly for testing with mocks)
- `minProcessIntervalMs`: Minimum milliseconds between FFT processing. Lower = smoother but more CPU usage

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

### Configure Frame Throttling

Control how frequently FFT data is processed to optimize CPU usage:

```dart
// Default: 16ms (~60 FPS)
final controller = AudifyController();

// Custom throttle interval (in milliseconds)
final controller = AudifyController(minProcessIntervalMs: 33);  // ~30 FPS - better battery life
final controller = AudifyController(minProcessIntervalMs: 16);  // ~60 FPS - smooth (default)
final controller = AudifyController(minProcessIntervalMs: 8);   // ~120 FPS - ultra smooth (higher CPU)
```

**When to adjust:**
- **Lower values** (8-12ms): Ultra-smooth visualizations on powerful devices
- **Default** (16ms): Balanced performance for most use cases
- **Higher values** (25-33ms): Better battery life, still smooth enough for most music

### Adjust Capture Size

```dart
// Lower = faster, Higher = more detail
await _controller.initialize(captureSize: 1024);  // Fast
await _controller.initialize(captureSize: 4096);  // Detailed
```

### Reduce Bar Count

```dart
// Fewer bars = better performance
SizedBox(
  width: 300,
  height: 300,
  child: CircularSpectrumVisualizer(
    controller: controller,
    barCount: 30,  // Fast - fewer bars
  ),
)

SizedBox(
  width: 300,
  height: 300,
  child: CircularSpectrumVisualizer(
    controller: controller,
    barCount: 80,  // Detailed - more bars
  ),
)
```

### Adjust Smoothing

```dart
// Higher = smoother but less responsive
SizedBox(
  width: 300,
  height: 300,
  child: CircularSpectrumVisualizer(
    controller: controller,
    smoothing: 0.9,  // Very smooth
  ),
)

SizedBox(
  width: 300,
  height: 300,
  child: CircularSpectrumVisualizer(
    controller: controller,
    smoothing: 0.5,  // More responsive
  ),
)
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

**Made with ❤️ for the Flutter community**

- Native FFT processing on Android (Visualizer API) and iOS (AVAudioEngine + Accelerate framework)
- Inspired by trap/dubstep music visualizers

## Support

If you find this package helpful, please give it a ⭐ on [GitHub](https://github.com/naxtor/audify)!

For bugs or feature requests, please [open an issue](https://github.com/naxtor/audify/issues).

