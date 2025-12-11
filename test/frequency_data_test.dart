import 'package:flutter_test/flutter_test.dart';
import 'package:audify/src/frequency_data.dart';

void main() {
  group('FrequencyData Construction', () {
    test('creates with valid data', () {
      final data = FrequencyData(
        bands: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7],
        rawMagnitudes: List.generate(1024, (i) => i / 1024),
      );

      expect(data.bands.length, 7);
      expect(data.rawMagnitudes.length, 1024);
    });

    test('creates with empty bands', () {
      final data = FrequencyData(
        bands: [],
        rawMagnitudes: [],
      );

      expect(data.bands.length, 0);
      expect(data.rawMagnitudes.length, 0);
    });
  });

  group('FrequencyData Band Getters', () {
    late FrequencyData data;

    setUp(() {
      data = FrequencyData(
        bands: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7],
        rawMagnitudes: [],
      );
    });

    test('subBass returns first band', () {
      expect(data.subBass, 0.1);
    });

    test('bass returns second band', () {
      expect(data.bass, 0.2);
    });

    test('lowMids returns third band', () {
      expect(data.lowMids, 0.3);
    });

    test('mids returns fourth band', () {
      expect(data.mids, 0.4);
    });

    test('highMids returns fifth band', () {
      expect(data.highMids, 0.5);
    });

    test('presence returns sixth band', () {
      expect(data.presence, 0.6);
    });

    test('brilliance returns seventh band', () {
      expect(data.brilliance, 0.7);
    });

    test('getBand returns correct value for valid index', () {
      expect(data.getBand(0), 0.1);
      expect(data.getBand(3), 0.4);
      expect(data.getBand(6), 0.7);
    });

    test('getBand returns 0.0 for invalid index', () {
      expect(data.getBand(-1), 0.0);
      expect(data.getBand(7), 0.0);
      expect(data.getBand(100), 0.0);
    });
  });

  group('FrequencyData Band Getters - Edge Cases', () {
    test('empty bands return 0.0', () {
      final data = FrequencyData(bands: [], rawMagnitudes: []);

      expect(data.subBass, 0.0);
      expect(data.bass, 0.0);
      expect(data.lowMids, 0.0);
      expect(data.mids, 0.0);
      expect(data.highMids, 0.0);
      expect(data.presence, 0.0);
      expect(data.brilliance, 0.0);
    });

    test('partial bands return 0.0 for missing bands', () {
      final data = FrequencyData(bands: [0.1, 0.2], rawMagnitudes: []);

      expect(data.subBass, 0.1);
      expect(data.bass, 0.2);
      expect(data.lowMids, 0.0);
      expect(data.mids, 0.0);
      expect(data.highMids, 0.0);
      expect(data.presence, 0.0);
      expect(data.brilliance, 0.0);
    });
  });

  group('FrequencyData Calculations', () {
    test('peak returns maximum value', () {
      final data = FrequencyData(
        bands: [0.1, 0.5, 0.3, 0.8, 0.2, 0.4, 0.6],
        rawMagnitudes: [],
      );

      expect(data.peak, 0.8);
    });

    test('peak returns 0.0 for empty bands', () {
      final data = FrequencyData(bands: [], rawMagnitudes: []);

      expect(data.peak, 0.0);
    });

    test('average returns correct average', () {
      final data = FrequencyData(
        bands: [0.2, 0.4, 0.6],
        rawMagnitudes: [],
      );

      expect(data.average, closeTo(0.4, 0.001));
    });

    test('average returns 0.0 for empty bands', () {
      final data = FrequencyData(bands: [], rawMagnitudes: []);

      expect(data.average, 0.0);
    });

    test('average handles single band', () {
      final data = FrequencyData(bands: [0.5], rawMagnitudes: []);

      expect(data.average, 0.5);
    });

    test('average handles all zeros', () {
      final data = FrequencyData(
        bands: [0.0, 0.0, 0.0],
        rawMagnitudes: [],
      );

      expect(data.average, 0.0);
    });
  });

  group('FrequencyData Smoothing', () {
    test('getSmoothedBands returns original bands when no previous data', () {
      final data = FrequencyData(
        bands: [0.5, 0.6, 0.7],
        rawMagnitudes: [],
      );

      final smoothed = data.getSmoothedBands(null, 0.8);

      expect(smoothed, equals([0.5, 0.6, 0.7]));
    });

    test('getSmoothedBands applies exponential moving average', () {
      final data = FrequencyData(
        bands: [0.5, 0.6, 0.7],
        rawMagnitudes: [],
      );

      final previous = [0.1, 0.2, 0.3];
      final smoothed = data.getSmoothedBands(previous, 0.5);

      // With 0.5 smoothing: (0.1 * 0.5) + (0.5 * 0.5) = 0.3
      expect(smoothed[0], closeTo(0.3, 0.001));
      expect(smoothed[1], closeTo(0.4, 0.001));
      expect(smoothed[2], closeTo(0.5, 0.001));
    });

    test('getSmoothedBands with high smoothing factor favors previous', () {
      final data = FrequencyData(
        bands: [1.0, 1.0, 1.0],
        rawMagnitudes: [],
      );

      final previous = [0.0, 0.0, 0.0];
      final smoothed = data.getSmoothedBands(previous, 0.9);

      // With 0.9 smoothing: (0.0 * 0.9) + (1.0 * 0.1) = 0.1
      expect(smoothed[0], closeTo(0.1, 0.001));
    });

    test('getSmoothedBands with low smoothing factor favors current', () {
      final data = FrequencyData(
        bands: [1.0, 1.0, 1.0],
        rawMagnitudes: [],
      );

      final previous = [0.0, 0.0, 0.0];
      final smoothed = data.getSmoothedBands(previous, 0.1);

      // With 0.1 smoothing: (0.0 * 0.1) + (1.0 * 0.9) = 0.9
      expect(smoothed[0], closeTo(0.9, 0.001));
    });

    test('getSmoothedBands returns original when previous length mismatch', () {
      final data = FrequencyData(
        bands: [0.5, 0.6, 0.7],
        rawMagnitudes: [],
      );

      final previous = [0.1, 0.2]; // Different length
      final smoothed = data.getSmoothedBands(previous, 0.5);

      expect(smoothed, equals([0.5, 0.6, 0.7]));
    });

    test('getSmoothedBands handles zero smoothing factor', () {
      final data = FrequencyData(
        bands: [0.5, 0.6, 0.7],
        rawMagnitudes: [],
      );

      final previous = [0.1, 0.2, 0.3];
      final smoothed = data.getSmoothedBands(previous, 0.0);

      // With 0.0 smoothing, should use 100% current values
      expect(smoothed, equals([0.5, 0.6, 0.7]));
    });

    test('getSmoothedBands handles full smoothing factor', () {
      final data = FrequencyData(
        bands: [0.5, 0.6, 0.7],
        rawMagnitudes: [],
      );

      final previous = [0.1, 0.2, 0.3];
      final smoothed = data.getSmoothedBands(previous, 1.0);

      // With 1.0 smoothing, should use 100% previous values
      expect(smoothed, equals([0.1, 0.2, 0.3]));
    });
  });

  group('FrequencyData Real-world Scenarios', () {
    test('handles typical audio visualization data', () {
      // Simulate typical FFT output: higher values in bass, lower in treble
      final data = FrequencyData(
        bands: [0.8, 0.7, 0.5, 0.4, 0.3, 0.2, 0.1],
        rawMagnitudes: List.generate(1024, (i) => (1024 - i) / 1024),
      );

      expect(data.subBass, greaterThan(data.brilliance));
      expect(data.bass, greaterThan(data.highMids));
      expect(data.peak, 0.8);
      expect(data.average, closeTo(0.43, 0.01));
    });

    test('handles silence (all zeros)', () {
      final data = FrequencyData(
        bands: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        rawMagnitudes: List.filled(1024, 0.0),
      );

      expect(data.peak, 0.0);
      expect(data.average, 0.0);
      expect(data.subBass, 0.0);
      expect(data.brilliance, 0.0);
    });

    test('handles maximum amplitude', () {
      final data = FrequencyData(
        bands: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        rawMagnitudes: List.filled(1024, 1.0),
      );

      expect(data.peak, 1.0);
      expect(data.average, 1.0);
      expect(data.subBass, 1.0);
      expect(data.brilliance, 1.0);
    });

    test('handles realistic smoothing over multiple frames', () {
      final data1 = FrequencyData(bands: [0.8, 0.6, 0.4], rawMagnitudes: []);
      final data2 = FrequencyData(bands: [0.2, 0.4, 0.6], rawMagnitudes: []);

      // Simulate smoothing over two frames
      final smoothed1 = data1.getSmoothedBands(null, 0.7);
      final smoothed2 = data2.getSmoothedBands(smoothed1, 0.7);

      // Second frame should be influenced by first frame due to smoothing
      expect(smoothed2[0], greaterThan(0.2)); // Higher than raw value
      expect(smoothed2[0], lessThan(0.8)); // Lower than first frame
    });
  });
}
