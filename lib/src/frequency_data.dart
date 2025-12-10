// lib/src/frequency_data.dart
import 'dart:math' as math;

class FrequencyData {
  /// Frequency bands magnitudes (0.0 - 1.0)
  /// Typically 7 bands: sub bass, bass, low mids, mids, high mids, presence, brilliance
  final List<double> bands;

  /// Raw FFT magnitudes for all frequency bins
  final List<double> rawMagnitudes;

  FrequencyData({required this.bands, required this.rawMagnitudes});

  /// Get smoothed bands using exponential moving average
  List<double> getSmoothedBands(List<double>? previousBands, double smoothing) {
    if (previousBands == null || previousBands.length != bands.length) {
      return bands;
    }

    final smoothed = <double>[];
    for (int i = 0; i < bands.length; i++) {
      final smoothedValue =
          previousBands[i] * smoothing + bands[i] * (1 - smoothing);
      smoothed.add(smoothedValue);
    }
    return smoothed;
  }

  /// Get peak value across all bands
  double get peak {
    if (bands.isEmpty) return 0.0;
    return bands.reduce(math.max);
  }

  /// Get average value across all bands
  double get average {
    if (bands.isEmpty) return 0.0;
    return bands.reduce((a, b) => a + b) / bands.length;
  }

  /// Get specific band by index (0-6)
  double getBand(int index) {
    if (index < 0 || index >= bands.length) return 0.0;
    return bands[index];
  }

  /// Get sub bass (20-60 Hz)
  double get subBass => bands.isNotEmpty ? bands[0] : 0.0;

  /// Get bass (60-250 Hz)
  double get bass => bands.length > 1 ? bands[1] : 0.0;

  /// Get low mids (250-500 Hz)
  double get lowMids => bands.length > 2 ? bands[2] : 0.0;

  /// Get mids (500-2000 Hz)
  double get mids => bands.length > 3 ? bands[3] : 0.0;

  /// Get high mids (2000-4000 Hz)
  double get highMids => bands.length > 4 ? bands[4] : 0.0;

  /// Get presence (4000-6000 Hz)
  double get presence => bands.length > 5 ? bands[5] : 0.0;

  /// Get brilliance (6000-20000 Hz)
  double get brilliance => bands.length > 6 ? bands[6] : 0.0;
}
