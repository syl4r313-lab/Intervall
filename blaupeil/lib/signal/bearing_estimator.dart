import 'dart:math' as math;

import '../config.dart';
import 'circular_stats.dart';

enum Confidence {
  uncertain('unsicher'),
  usable('brauchbar'),
  good('gut');

  const Confidence(this.label);
  final String label;

  static Confidence fromContrast(double contrastDb) {
    if (contrastDb > kContrastGoodDb) return Confidence.good;
    if (contrastDb >= kContrastUsableDb) return Confidence.usable;
    return Confidence.uncertain;
  }

  /// Halbe Breite des Fächers, der die Unschärfe im UI zeigt.
  double get spreadDeg => switch (this) {
    Confidence.good => kSpreadGoodDeg,
    Confidence.usable => kSpreadUsableDeg,
    Confidence.uncertain => kSpreadUncertainDeg,
  };
}

class BearingResult {
  const BearingResult({
    required this.bearingDeg,
    required this.contrastDb,
    required this.confidence,
    required this.coverageDeg,
    required this.sectorProfile,
  });

  /// Geschätzte Himmelsrichtung zum Sender, 0° = Norden. `null`, wenn sich
  /// nichts sagen lässt.
  final double? bearingDeg;
  final double contrastDb;
  final Confidence confidence;

  /// Wie viel der Drehung mit Messwerten belegt ist.
  final double coverageDeg;

  /// Geglättetes Profil pro Sektor in dBm (für die Anzeige), leer ohne Ergebnis.
  final List<double> sectorProfile;

  bool get isComplete => coverageDeg >= kMinCoverageDeg;
}

/// Peilung nach Fuchsjagd-Art: Messwerte (Azimut, RSSI) sammeln, in Sektoren
/// einsortieren und dort nachsehen, wo das Signal am lautesten ruft.
class BearingEstimator {
  BearingEstimator({this.sectorSizeDeg = kSectorSizeDeg})
    : sectorCount = (360 / sectorSizeDeg).round() {
    _sectors = List.generate(sectorCount, (_) => <double>[]);
  }

  final double sectorSizeDeg;
  final int sectorCount;
  late final List<List<double>> _sectors;

  int get sampleCount => _sectors.fold(0, (n, s) => n + s.length);

  void reset() {
    for (final s in _sectors) {
      s.clear();
    }
  }

  /// Rohwerte, nicht die EMA-geglätteten: der Filter hinkt hinterher und würde
  /// die Richtung während der Drehung verschmieren. Gegen Ausreißer hilft der
  /// Median pro Sektor.
  void addSample(double azimuthDeg, double rssi) {
    _sectors[sectorIndex(azimuthDeg)].add(rssi);
  }

  int sectorIndex(double azimuthDeg) =>
      (normalizeDeg(azimuthDeg) / sectorSizeDeg).floor() % sectorCount;

  double sectorCenterDeg(int i) => (i + 0.5) * sectorSizeDeg;

  /// Welche Sektoren schon mindestens einen Messwert haben.
  List<bool> get filledSectors => [for (final s in _sectors) s.isNotEmpty];

  double get coverageDeg =>
      filledSectors.where((f) => f).length * sectorSizeDeg;

  BearingResult estimate() {
    final coverage = coverageDeg;
    final medians = <double?>[
      for (final s in _sectors) s.isEmpty ? null : _median(s),
    ];
    final filled = medians.whereType<double>().length;
    if (filled < 2) {
      return BearingResult(
        bearingDeg: null,
        contrastDb: 0,
        confidence: Confidence.uncertain,
        coverageDeg: coverage,
        sectorProfile: const [],
      );
    }

    final interpolated = _interpolateGaps(medians);
    final smoothed = _smoothCircular(interpolated);

    final maxV = smoothed.reduce(math.max);
    final meanV = smoothed.reduce((a, b) => a + b) / smoothed.length;
    final contrast = maxV - meanV;

    // Alle Sektoren bis 3 dB unter dem Maximum, gewichtet nach linearer
    // Leistung: ein Sektor 3 dB unter dem Maximum zählt halb so viel.
    final angles = <double>[];
    final weights = <double>[];
    for (var i = 0; i < sectorCount; i++) {
      if (smoothed[i] >= maxV - kStrongSectorWindowDb) {
        angles.add(sectorCenterDeg(i));
        weights.add(math.pow(10, (smoothed[i] - maxV) / 10).toDouble());
      }
    }

    return BearingResult(
      bearingDeg: circularMeanDeg(angles, weights),
      contrastDb: contrast,
      confidence: Confidence.fromContrast(contrast),
      coverageDeg: coverage,
      sectorProfile: smoothed,
    );
  }

  /// Leere Sektoren linear zwischen den nächsten belegten Nachbarn füllen,
  /// über die 0/360-Grenze hinweg.
  List<double> _interpolateGaps(List<double?> values) {
    final n = values.length;
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      if (values[i] != null) {
        out[i] = values[i]!;
        continue;
      }
      var back = 1;
      while (values[(i - back + n) % n] == null) {
        back++;
      }
      var fwd = 1;
      while (values[(i + fwd) % n] == null) {
        fwd++;
      }
      final a = values[(i - back + n) % n]!;
      final b = values[(i + fwd) % n]!;
      out[i] = a + (b - a) * back / (back + fwd);
    }
    return out;
  }

  /// Gleitender Mittelwert über ±1 Sektor, ringförmig.
  List<double> _smoothCircular(List<double> v) {
    final n = v.length;
    return [
      for (var i = 0; i < n; i++)
        (v[(i - 1 + n) % n] + v[i] + v[(i + 1) % n]) / 3.0,
    ];
  }

  static double _median(List<double> values) {
    final s = [...values]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2.0;
  }
}

/// Median einer Werteliste, auch für die Kalibrierung.
double median(List<double> values) {
  if (values.isEmpty) throw ArgumentError('Leere Liste hat keinen Median');
  return BearingEstimator._median(values);
}
