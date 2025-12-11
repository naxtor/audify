## 1.0.1

**Summary:** Maintenance release addressing pub.dev feedback, adding Swift Package Manager support, comprehensive test coverage, and code cleanup. No breaking changes - fully backward compatible.

* **Package Improvements:**
  - ✅ Fixed pubspec description length to meet pub.dev guidelines (60-180 characters)
  - ✅ Added Swift Package Manager (SPM) support for iOS
  - ✅ Created `ios/audify/Package.swift` for SPM compatibility  
  - ✅ Updated CocoaPods podspec to reference new file structure
  - ✅ Both CocoaPods and SPM are now supported for maximum compatibility
  - ✅ Updated iOS .gitignore for SPM artifacts (.build/, .swiftpm/)

* **Code Cleanup & Architecture:**
  - Removed unused `ios/Classes/` directory (replaced by `ios/audify/Sources/audify/`)
  - Removed unused `ios/Resources/` directory (moved to SPM structure)
  - Removed unused `ios/Assets/` directory (empty)
  - Removed unused platform interface abstraction layer:
    - `lib/src/audify_platform_interface.dart`
    - `lib/src/audify_method_channel.dart`
    - `plugin_platform_interface` dependency
  - Simplified architecture: `AudifyController` directly uses `MethodChannel`
  - Cleaner codebase with 7 fewer files

* **Testing & Quality:**
  - ✅ Added comprehensive unit tests (44 tests, 100% passing)
  - ✅ `test/audify_controller_test.dart`: Controller lifecycle, streams, error handling (14 tests)
  - ✅ `test/frequency_data_test.dart`: Data model, calculations, smoothing algorithms (30 tests)
  - ✅ All tests validated with `flutter test`
  - ✅ Zero analysis errors with `flutter analyze`
  - ✅ Code formatted with `dart format`

* **Compatibility & Safety:**
  - ✅ **No breaking changes** - all public APIs unchanged
  - ✅ **100% backward compatible** - existing apps work without modifications
  - ✅ iOS/Android implementations unchanged (only file organization improved)
  - ✅ Widget APIs unchanged (`CircularSpectrumVisualizer`, `BarSpectrumVisualizer`)
  - ✅ Performance characteristics unchanged
  - ✅ Example app tested on both Android and iOS
  - ✅ Ready for production use

## 1.0.0

* **Initial stable release** with full Android and iOS support
* **Features:**
  - Real-time audio visualization with 60 FPS performance
  - Two visualizer types: CircularSpectrum and BarSpectrum
  - 7 frequency bands optimized for music visualization
  - Customizable colors, gradients, and glow effects
  - **System-wide audio capture** - visualizes ANY audio playing on the device (no audio file import needed!)
  - Album artwork support with `centerImage` parameter in CircularSpectrumVisualizer
  - Adaptive sizing for non-square containers
  - Both visualizers automatically adapt to parent container size (wrap in `SizedBox` or `Container` to control dimensions)
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
  - Simple `AudifyController` interface
  - Stream-based data delivery
  - Comprehensive frequency band extraction
* Production-ready with zero flutter analyze warnings
