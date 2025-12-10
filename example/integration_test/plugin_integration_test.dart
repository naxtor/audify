// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_audio_visualizer/flutter_audio_visualizer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AudioVisualizerController initialization test', (
    WidgetTester tester,
  ) async {
    final controller = AudioVisualizerController();

    // Test initialization
    await controller.initialize(audioSessionId: 0, captureSize: 2048);
    expect(controller.isInitialized, true);
    expect(controller.isCapturing, false);

    // Clean up
    await controller.dispose();
  });
}
