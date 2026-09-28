import 'dart:async';

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../signal/circular_stats.dart';

class HeadingReading {
  const HeadingReading({required this.headingDeg, this.accuracyDeg});

  /// Geglätteter Azimut, 0° = Norden, im Uhrzeigersinn.
  final double headingDeg;

  /// Gemeldete Ungenauigkeit in Grad, `null` wenn unbekannt.
  final double? accuracyDeg;

  bool get needsCalibration =>
      accuracyDeg != null && accuracyDeg! > kCompassAccuracyWarnDeg;
}

/// Rohdaten des Kompasses. Abstrakt, damit die Signalverarbeitung ohne Gerät
/// testbar bleibt.
abstract class HeadingSource {
  Stream<({double heading, double? accuracy})> get raw;
}

/// iOS: CoreLocation-Heading. Android: Rotationsvektor-Sensor.
class FlutterCompassSource implements HeadingSource {
  @override
  Stream<({double heading, double? accuracy})> get raw =>
      (FlutterCompass.events ?? const Stream<CompassEvent>.empty())
          .where((e) => e.heading != null)
          .map((e) => (heading: e.heading!, accuracy: e.accuracy));
}

final headingSourceProvider = Provider<HeadingSource>(
  (ref) => FlutterCompassSource(),
);

/// Geglätteter Azimut als Stream.
/// autoDispose: ohne Zuschauer wird der Sensor abgeschaltet, das schont den Akku.
final headingProvider = StreamProvider.autoDispose<HeadingReading>((ref) {
  final smoother = CircularSmoother(timeConstantS: kHeadingTimeConstantS);
  return ref.watch(headingSourceProvider).raw.map((e) {
    final h = smoother.update(normalizeDeg(e.heading), DateTime.now());
    return HeadingReading(headingDeg: h, accuracyDeg: e.accuracy);
  });
});
