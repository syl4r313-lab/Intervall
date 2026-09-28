import 'dart:math' as math;

import '../config.dart';

enum DistanceBand {
  near('nah'),
  mid('mittel'),
  far('fern');

  const DistanceBand(this.label);
  final String label;
}

class DistanceEstimate {
  const DistanceEstimate(this.meters, this.band);
  final double meters;
  final DistanceBand band;

  /// Zahl mit „ca.“, bewusst grob gerundet. Mehr Nachkommastellen würden eine
  /// Genauigkeit vortäuschen, die das Funksignal nicht hergibt.
  String get text {
    final m = meters < 10
        ? meters.toStringAsFixed(0)
        : (meters / 5).round() * 5;
    return '${band.label} (ca. $m m)';
  }
}

/// Log-Distanz-Modell: d = 10 ^ ((rssiAt1m - rssi) / (10 * n)).
double estimateDistanceM(
  double rssi, {
  required double rssiAt1m,
  required double pathLossExponent,
}) {
  return math.pow(10, (rssiAt1m - rssi) / (10 * pathLossExponent)).toDouble();
}

DistanceBand bandFor(double meters) {
  if (meters < kNearLimitM) return DistanceBand.near;
  if (meters <= kMidLimitM) return DistanceBand.mid;
  return DistanceBand.far;
}

DistanceEstimate estimateDistance(
  double rssi, {
  required double rssiAt1m,
  required double pathLossExponent,
}) {
  final d = estimateDistanceM(
    rssi,
    rssiAt1m: rssiAt1m,
    pathLossExponent: pathLossExponent,
  );
  return DistanceEstimate(d, bandFor(d));
}
