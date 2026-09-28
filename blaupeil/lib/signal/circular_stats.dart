import 'dart:math' as math;

/// Winkelmathematik in Grad. Kompasswinkel sind zyklisch: 359° und 1° liegen
/// nebeneinander, ihr arithmetisches Mittel (180°) zeigt aber genau verkehrt
/// herum. Deshalb wird hier grundsätzlich über Sinus und Kosinus gemittelt.

const double _degToRad = math.pi / 180.0;
const double _radToDeg = 180.0 / math.pi;

/// Bringt einen Winkel in den Bereich [0, 360).
double normalizeDeg(double deg) {
  final r = deg % 360.0;
  return r < 0 ? r + 360.0 : r;
}

/// Kürzester vorzeichenbehafteter Abstand von [from] nach [to], in (-180, 180].
double signedDeltaDeg(double from, double to) {
  var d = normalizeDeg(to - from);
  if (d > 180.0) d -= 360.0;
  return d;
}

/// Betrag des kürzesten Abstands zweier Winkel, in [0, 180].
double angularDistanceDeg(double a, double b) => signedDeltaDeg(a, b).abs();

/// Gewichteter Kreismittelwert. Liefert `null`, wenn sich die Vektoren
/// gegenseitig aufheben (z. B. 0° und 180° mit gleichem Gewicht).
double? circularMeanDeg(List<double> anglesDeg, [List<double>? weights]) {
  assert(weights == null || weights.length == anglesDeg.length);
  var s = 0.0;
  var c = 0.0;
  for (var i = 0; i < anglesDeg.length; i++) {
    final w = weights == null ? 1.0 : weights[i];
    s += w * math.sin(anglesDeg[i] * _degToRad);
    c += w * math.cos(anglesDeg[i] * _degToRad);
  }
  if (s.abs() < 1e-9 && c.abs() < 1e-9) return null;
  return normalizeDeg(math.atan2(s, c) * _radToDeg);
}

/// Zeitbasierte Glättung eines Winkels über Sinus/Kosinus. So verursacht der
/// Sprung von 359° auf 0° keine Pirouette des Zeigers.
class CircularSmoother {
  CircularSmoother({required this.timeConstantS});

  final double timeConstantS;
  double? _s;
  double? _c;
  DateTime? _last;

  double? get value =>
      _s == null ? null : normalizeDeg(math.atan2(_s!, _c!) * _radToDeg);

  double update(double angleDeg, DateTime at) {
    final s = math.sin(angleDeg * _degToRad);
    final c = math.cos(angleDeg * _degToRad);
    if (_s == null) {
      _s = s;
      _c = c;
    } else {
      final dt = at.difference(_last!).inMicroseconds / 1e6;
      final alpha = emaAlpha(dt, timeConstantS);
      _s = _s! + alpha * (s - _s!);
      _c = _c! + alpha * (c - _c!);
    }
    _last = at;
    return value!;
  }
}

/// Glättungsfaktor eines zeitkontinuierlichen EMA: je länger seit der letzten
/// Messung, desto mehr Gewicht bekommt die neue.
double emaAlpha(double dtSeconds, double timeConstantS) {
  if (dtSeconds <= 0) return 0.0;
  return 1.0 - math.exp(-dtSeconds / timeConstantS);
}
