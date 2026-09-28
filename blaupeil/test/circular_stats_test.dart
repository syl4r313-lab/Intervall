import 'package:blaupeil/signal/circular_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('circularMeanDeg', () {
    test('Mittelwert über den 0/360-Sprung: 350° und 10° ergeben 0°', () {
      final m = circularMeanDeg([350, 10])!;
      expect(angularDistanceDeg(m, 0), lessThan(1e-9));
    });

    test('Gewichte ziehen den Mittelwert zur schwereren Seite', () {
      final m = circularMeanDeg([0, 90], [3, 1])!;
      expect(m, greaterThan(0));
      expect(m, lessThan(45));
    });

    test('Gegenüberliegende Winkel heben sich auf', () {
      expect(circularMeanDeg([0, 180]), isNull);
    });
  });

  test('normalizeDeg und signedDeltaDeg', () {
    expect(normalizeDeg(-30), 330);
    expect(normalizeDeg(725), 5);
    expect(signedDeltaDeg(350, 10), 20);
    expect(signedDeltaDeg(10, 350), -20);
  });

  test('CircularSmoother springt über 0/360 nicht durch 180°', () {
    final s = CircularSmoother(timeConstantS: 0.5);
    final t0 = DateTime(2026);
    s.update(355, t0);
    final v = s.update(5, t0.add(const Duration(milliseconds: 200)));
    expect(angularDistanceDeg(v, 0), lessThan(6));
  });
}
