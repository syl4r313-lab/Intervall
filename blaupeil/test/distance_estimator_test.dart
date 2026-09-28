import 'package:blaupeil/signal/distance_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RSSI gleich Referenzwert ergibt 1 m', () {
    expect(
      estimateDistanceM(-59, rssiAt1m: -59, pathLossExponent: 2.5),
      closeTo(1.0, 1e-9),
    );
  });

  test('25 dB schwächer bei n = 2,5 ergibt 10 m', () {
    expect(
      estimateDistanceM(-84, rssiAt1m: -59, pathLossExponent: 2.5),
      closeTo(10.0, 1e-9),
    );
  });

  test('20 dB schwächer bei n = 2,0 ergibt 10 m', () {
    expect(
      estimateDistanceM(-79, rssiAt1m: -59, pathLossExponent: 2.0),
      closeTo(10.0, 1e-9),
    );
  });

  test('Stufen: nah, mittel, fern', () {
    expect(bandFor(1.5), DistanceBand.near);
    expect(bandFor(2.0), DistanceBand.mid);
    expect(bandFor(8.0), DistanceBand.mid);
    expect(bandFor(8.1), DistanceBand.far);
  });

  test('Text enthält Stufe und „ca.“', () {
    final e = estimateDistance(-74, rssiAt1m: -59, pathLossExponent: 2.5);
    expect(e.band, DistanceBand.mid); // 10^0,6 = ca. 4 m
    expect(e.text, 'mittel (ca. 4 m)');
  });
}
