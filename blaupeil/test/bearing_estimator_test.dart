import 'dart:math' as math;

import 'package:blaupeil/signal/bearing_estimator.dart';
import 'package:blaupeil/signal/circular_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Normalverteiltes Rauschen (Box-Muller) mit festem Seed.
double _gauss(math.Random r) =>
    math.sqrt(-2 * math.log(1 - r.nextDouble())) *
    math.cos(2 * math.pi * r.nextDouble());

/// Simuliert eine Drehung: der Körper schirmt nach hinten ab, also ist das
/// Signal in Blickrichtung zum Sender am stärksten.
BearingEstimator _spin({
  required double targetDeg,
  required int seed,
  double startDeg = 0,
  double sweepDeg = 360,
  double noiseDb = 3,
  double depthDb = 8,
  int samples = 200,
}) {
  final rnd = math.Random(seed);
  final est = BearingEstimator();
  for (var i = 0; i < samples; i++) {
    final az = normalizeDeg(startDeg + sweepDeg * i / samples);
    final gain = depthDb * math.cos((az - targetDeg) * math.pi / 180);
    est.addSample(az, -65 + gain + noiseDb * _gauss(rnd));
  }
  return est;
}

void main() {
  test('Synthetisches Maximum wird auf ±15° getroffen', () {
    for (final target in [0.0, 37.0, 90.0, 181.0, 275.0, 352.0]) {
      for (var seed = 1; seed <= 5; seed++) {
        final r = _spin(targetDeg: target, seed: seed).estimate();
        expect(r.bearingDeg, isNotNull);
        expect(
          angularDistanceDeg(r.bearingDeg!, target),
          lessThanOrEqualTo(15),
          reason: 'Ziel $target°, Seed $seed, Ergebnis ${r.bearingDeg}',
        );
        expect(r.isComplete, isTrue);
      }
    }
  });

  test('Deutlicher Kontrast ergibt Konfidenz „gut“', () {
    final r = _spin(targetDeg: 120, seed: 7, depthDb: 12).estimate();
    expect(r.confidence, Confidence.good);
  });

  test('Flaches Signal ohne Richtung ergibt „unsicher“', () {
    final r = _spin(targetDeg: 0, seed: 3, depthDb: 0, noiseDb: 1).estimate();
    expect(r.confidence, Confidence.uncertain);
  });

  test('Halbe Drehung wird als unvollständig erkannt', () {
    final r = _spin(targetDeg: 90, seed: 2, sweepDeg: 180).estimate();
    expect(r.isComplete, isFalse);
    expect(r.coverageDeg, lessThan(270));
  });

  test('Lücken werden interpoliert, auch über 0/360', () {
    final est = BearingEstimator();
    est.addSample(340, -60);
    est.addSample(20, -60);
    est.addSample(180, -80);
    final r = est.estimate();
    expect(r.sectorProfile, hasLength(24));
    expect(angularDistanceDeg(r.bearingDeg!, 0), lessThanOrEqualTo(15));
  });

  test('Ohne Messwerte gibt es keine Richtung', () {
    final r = BearingEstimator().estimate();
    expect(r.bearingDeg, isNull);
    expect(r.coverageDeg, 0);
  });

  test('Median', () {
    expect(median([3, 1, 2]), 2);
    expect(median([4, 1, 2, 3]), 2.5);
  });
}
