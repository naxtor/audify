import 'dart:math' as math;

List<double> mapLogarithmicMagnitudes({
  required List<double> rawMagnitudes,
  required int outputCount,
}) {
  if (rawMagnitudes.isEmpty || outputCount <= 0) {
    return <double>[];
  }

  return List<double>.generate(outputCount, (index) {
    final rawIndex = _logarithmicIndex(
      linearIndex: index,
      totalItems: outputCount,
      dataLength: rawMagnitudes.length,
    );
    return rawMagnitudes[rawIndex];
  }, growable: false);
}

List<double> smoothMagnitudes({
  required List<double> previous,
  required List<double> current,
  required double smoothing,
}) {
  return List<double>.generate(current.length, (index) {
    final previousValue = index < previous.length ? previous[index] : 0.0;
    return previousValue * smoothing + current[index] * (1 - smoothing);
  }, growable: false);
}

int _logarithmicIndex({
  required int linearIndex,
  required int totalItems,
  required int dataLength,
}) {
  final normalized = linearIndex / totalItems;
  final logIndex = (math.pow(dataLength, normalized) - 1).toInt();
  return logIndex.clamp(0, dataLength - 1);
}
