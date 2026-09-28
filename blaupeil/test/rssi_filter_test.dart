import 'dart:math' as math;

import 'package:blaupeil/signal/rssi_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026);

  test('Erster Wert wird unverändert übernommen', () {
    final f = RssiFilter(timeConstantS: 1.0);
    expect(f.update(-70, t0), -70);
  });

  test('Nach genau einer Zeitkonstante sind 63 % des Sprungs erreicht', () {
    final f = RssiFilter(timeConstantS: 1.0);
    f.update(-70, t0);
    final v = f.update(-60, t0.add(const Duration(seconds: 1)));
    expect(v, closeTo(-70 + 10 * (1 - math.exp(-1)), 1e-9)); // ca. -63,68
  });

  test('Zeitbasiert: viele kurze Schritte wirken wie ein langer', () {
    final a = RssiFilter(timeConstantS: 1.0)..update(-80, t0);
    final b = RssiFilter(timeConstantS: 1.0)..update(-80, t0);
    // Android-Takt: zehn Messungen à 100 ms
    for (var i = 1; i <= 10; i++) {
      a.update(-60, t0.add(Duration(milliseconds: 100 * i)));
    }
    // iPhone-Takt: eine Messung nach 1 s
    b.update(-60, t0.add(const Duration(seconds: 1)));
    expect(a.value!, closeTo(b.value!, 1e-9));
  });

  test('Konstantes Signal bleibt konstant', () {
    final f = RssiFilter();
    for (var i = 0; i < 20; i++) {
      f.update(-65, t0.add(Duration(milliseconds: 250 * i)));
    }
    expect(f.value, -65);
  });
}
