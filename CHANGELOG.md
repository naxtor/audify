## 1.0.0

* **Initial stable release** with full Android and iOS support
* **Features:**
  - Real-time audio visualization with 60 FPS performance
  - Two visualizer types: CircularSpectrum and BarSpectrum
  - 7 frequency bands optimized for music visualization
  - Customizable colors, gradients, and glow effects
* **Android Implementation:**
  - Native Visualizer API for FFT processing
  - Support for API 21+
  - Can target specific audio sessions
* **iOS Implementation:**
  - AVAudioEngine for real-time audio capture
  - Accelerate framework (vDSP) for hardware-accelerated FFT
  - Support for iOS 12.0+
  - System-wide audio capture
* **Performance:**
  - < 5% CPU usage on modern devices
  - Smooth 60 FPS rendering
  - Configurable smoothing and capture size
* **API:**
  - Simple `AudioVisualizerController` interface
  - Stream-based data delivery
  - Comprehensive frequency band extraction
* Production-ready with zero flutter analyze warnings
