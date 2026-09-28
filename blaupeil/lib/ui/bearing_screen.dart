import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/beacon_scanner.dart';
import '../config.dart';
import '../sensors/compass_provider.dart';
import '../signal/bearing_estimator.dart';
import '../signal/circular_stats.dart';
import '../signal/distance_estimator.dart';
import '../state/providers.dart';

enum _Phase { idle, measuring, done }

class BearingScreen extends ConsumerStatefulWidget {
  const BearingScreen({super.key, required this.beaconKey});

  final String beaconKey;

  @override
  ConsumerState<BearingScreen> createState() => _BearingScreenState();
}

class _BearingScreenState extends ConsumerState<BearingScreen> {
  final _estimator = BearingEstimator();
  StreamSubscription<BeaconSighting>? _sub;
  _Phase _phase = _Phase.idle;
  BearingResult? _result;
  double? _heading;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(sightingsProvider).listen(_onSighting);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onSighting(BeaconSighting s) {
    if (s.key != widget.beaconKey || _phase != _Phase.measuring) return;
    final h = _heading;
    if (h == null) return;
    _estimator.addSample(h, s.rssi.toDouble());
    // Einmal komplett herum: automatisch auswerten.
    if (_estimator.coverageDeg >= 360) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _startMeasuring({bool keepSamples = false}) {
    if (!keepSamples) _estimator.reset();
    setState(() {
      _phase = _Phase.measuring;
      if (!keepSamples) _result = null;
    });
  }

  void _finish() {
    setState(() {
      _result = _estimator.estimate();
      _phase = _Phase.done;
    });
  }

  Color _confidenceColor(Confidence c, ColorScheme scheme) => switch (c) {
    Confidence.good => Colors.green.shade600,
    Confidence.usable => Colors.amber.shade700,
    Confidence.uncertain => scheme.error,
  };

  String _relativeText(double bearing, double heading) {
    final d = signedDeltaDeg(heading, bearing);
    if (d.abs() <= 15) return 'geradeaus';
    if (d.abs() >= 150) return 'hinter dir';
    return 'etwa ${d.abs().round()}° ${d > 0 ? 'rechts' : 'links'}';
  }

  @override
  Widget build(BuildContext context) {
    final headingAsync = ref.watch(headingProvider);
    final reading = headingAsync.value;
    _heading = reading?.headingDeg;

    final beacon = ref.watch(beaconRegistryProvider)[widget.beaconKey];
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();

    final result = _result;
    final bearing = result?.bearingDeg;
    final confColor = result == null
        ? scheme.primary
        : _confidenceColor(result.confidence, scheme);

    final instruction = switch (_phase) {
      _Phase.idle =>
        'Handy flach vor die Brust halten. Nach dem Start '
            'drehst du dich langsam einmal im Kreis (10 bis 20 Sekunden).',
      _Phase.measuring =>
        'Langsam weiterdrehen … '
            '${_estimator.coverageDeg.round()}° von 360° erfasst.',
      _Phase.done =>
        result == null || bearing == null
            ? 'Keine Richtung erkennbar. Bitte neu peilen.'
            : !result.isComplete
            ? 'Messung unvollständig (${result.coverageDeg.round()}°). '
                  'Bitte weiterdrehen, bis mindestens '
                  '${kMinCoverageDeg.round()}° erfasst sind.'
            : 'Der Pfeil zeigt die wahrscheinlichste Richtung. Nach ein '
                  'paar Schritten erneut peilen: wird das Signal lauter, '
                  'bist du auf dem richtigen Weg.',
    };

    return Scaffold(
      appBar: AppBar(title: Text(beacon?.label ?? 'Peilung')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(instruction, style: t.bodyLarge),
            if (reading?.needsCalibration ?? false)
              Card(
                color: scheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.all_inclusive),
                  title: const Text(
                    'Kompass ungenau. Bitte das Handy ein paar '
                    'Mal in Form einer Acht bewegen.',
                  ),
                ),
              ),
            if (headingAsync.hasError)
              Text(
                'Kein Kompass verfügbar.',
                style: TextStyle(color: scheme.error),
              )
            else if (reading == null)
              // Geräte ohne Magnetometer liefern nie einen Wert.
              const Text('Warte auf Kompassdaten …'),
            if (beacon != null && beacon.isStale(now))
              Text(
                'Seit ${now.difference(beacon.lastSeen).inSeconds} s kein '
                'Signal von ${beacon.label}.',
                style: TextStyle(color: scheme.error),
              ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: CompassRosePainter(
                  headingDeg: _heading ?? 0,
                  filledSectors: _estimator.filledSectors,
                  sectorSizeDeg: _estimator.sectorSizeDeg,
                  profile: result?.sectorProfile ?? const [],
                  bearingDeg: bearing,
                  spreadDeg: result?.confidence.spreadDeg ?? 0,
                  targetColor: confColor,
                  scheme: scheme,
                  labelStyle: t.titleMedium!,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (result != null && bearing != null)
                  Chip(
                    avatar: Icon(Icons.circle, color: confColor, size: 16),
                    label: Text(
                      'Konfidenz: ${result.confidence.label} '
                      '(${result.contrastDb.toStringAsFixed(1)} dB)',
                    ),
                  ),
                if (result != null && bearing != null && _heading != null)
                  Chip(
                    avatar: const Icon(Icons.navigation, size: 16),
                    label: Text(
                      '${_relativeText(bearing, _heading!)} · '
                      '±${result.confidence.spreadDeg.round()}°',
                    ),
                  ),
                if (beacon != null)
                  Chip(
                    avatar: const Icon(Icons.social_distance, size: 16),
                    label: Text(
                      estimateDistance(
                        beacon.smoothedRssi,
                        rssiAt1m: settings.rssiAt1m,
                        pathLossExponent: settings.pathLossExponent,
                      ).text,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ..._buttons(result),
          ],
        ),
      ),
    );
  }

  List<Widget> _buttons(BearingResult? result) {
    switch (_phase) {
      case _Phase.idle:
        return [
          FilledButton.icon(
            onPressed: _heading == null ? null : _startMeasuring,
            icon: const Icon(Icons.threesixty),
            label: const Text('Peilung starten'),
          ),
        ];
      case _Phase.measuring:
        return [
          FilledButton.icon(
            onPressed: _estimator.sampleCount == 0 ? null : _finish,
            icon: const Icon(Icons.check),
            label: const Text('Auswerten'),
          ),
        ];
      case _Phase.done:
        return [
          if (result != null && !result.isComplete) ...[
            FilledButton.icon(
              onPressed: () => _startMeasuring(keepSamples: true),
              icon: const Icon(Icons.rotate_right),
              label: const Text('Weiterdrehen'),
            ),
            const SizedBox(height: 12),
          ],
          if (result != null && !result.isComplete)
            OutlinedButton.icon(
              onPressed: _startMeasuring,
              icon: const Icon(Icons.refresh),
              label: const Text('Neu peilen'),
            )
          else
            FilledButton.icon(
              onPressed: _startMeasuring,
              icon: const Icon(Icons.refresh),
              label: const Text('Neu peilen'),
            ),
        ];
    }
  }
}

/// Kompassrose. Alles wird in Weltkoordinaten (0° = Norden) gedacht und um
/// den aktuellen Azimut gedreht, so zeigt „N“ immer nach Norden und der
/// Zielpfeil dreht sich live mit.
class CompassRosePainter extends CustomPainter {
  CompassRosePainter({
    required this.headingDeg,
    required this.filledSectors,
    required this.sectorSizeDeg,
    required this.profile,
    required this.bearingDeg,
    required this.spreadDeg,
    required this.targetColor,
    required this.scheme,
    required this.labelStyle,
  });

  final double headingDeg;
  final List<bool> filledSectors;
  final double sectorSizeDeg;
  final List<double> profile;
  final double? bearingDeg;
  final double spreadDeg;
  final Color targetColor;
  final ColorScheme scheme;
  final TextStyle labelStyle;

  /// Weltwinkel in Bildschirm-Radiant (0 = rechts, im Uhrzeigersinn).
  double _screenRad(double worldDeg) =>
      (worldDeg - headingDeg - 90) * math.pi / 180;

  Offset _polar(Offset c, double r, double worldDeg) {
    final a = _screenRad(worldDeg);
    return c + Offset(math.cos(a), math.sin(a)) * r;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final ringW = outer * 0.07;
    final ringR = outer - ringW / 2;
    final roseR = outer - ringW - 6;

    // Hintergrund
    canvas.drawCircle(
      c,
      roseR,
      Paint()..color = scheme.surfaceContainerHighest.withValues(alpha: 0.6),
    );

    // Fortschrittsring: ein Bogen pro Sektor
    final ringRect = Rect.fromCircle(center: c, radius: ringR);
    final gap = 1.5 * math.pi / 180;
    for (var i = 0; i < filledSectors.length; i++) {
      final start = _screenRad(i * sectorSizeDeg) + gap / 2;
      canvas.drawArc(
        ringRect,
        start,
        sectorSizeDeg * math.pi / 180 - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringW
          ..color = filledSectors[i]
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.5),
      );
    }

    // Signalprofil: je weiter außen, desto lauter
    if (profile.isNotEmpty) {
      final lo = profile.reduce(math.min);
      final hi = profile.reduce(math.max);
      final span = math.max(hi - lo, 1.0);
      final path = Path();
      for (var i = 0; i <= profile.length; i++) {
        final k = i % profile.length;
        final r = roseR * (0.25 + 0.7 * (profile[k] - lo) / span);
        final p = _polar(c, r, (k + 0.5) * sectorSizeDeg);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()..color = scheme.secondary.withValues(alpha: 0.18),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = scheme.secondary.withValues(alpha: 0.6),
      );
    }

    // Unschärfe-Fächer um die Peilung
    if (bearingDeg != null) {
      final rect = Rect.fromCircle(center: c, radius: roseR);
      canvas.drawArc(
        rect,
        _screenRad(bearingDeg! - spreadDeg),
        2 * spreadDeg * math.pi / 180,
        true,
        Paint()..color = targetColor.withValues(alpha: 0.22),
      );
    }

    // Striche alle 15°, lange alle 90°
    final tick = Paint()
      ..color = scheme.onSurfaceVariant
      ..strokeCap = StrokeCap.round;
    for (var d = 0; d < 360; d += 15) {
      final major = d % 90 == 0;
      tick.strokeWidth = major ? 3 : 1.5;
      canvas.drawLine(
        _polar(c, roseR, d.toDouble()),
        _polar(c, roseR * (major ? 0.86 : 0.92), d.toDouble()),
        tick,
      );
    }

    // Himmelsrichtungen (deutsch: O für Osten)
    const labels = {0: 'N', 90: 'O', 180: 'S', 270: 'W'};
    labels.forEach((deg, text) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: labelStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: deg == 0 ? Colors.red.shade400 : scheme.onSurface,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = _polar(c, roseR * 0.74, deg.toDouble());
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    });

    // Zielpfeil
    if (bearingDeg != null) {
      final tip = _polar(c, roseR * 0.9, bearingDeg!);
      final tail = _polar(c, roseR * 0.15, bearingDeg! + 180);
      final left = _polar(c, roseR * 0.62, bearingDeg! - 9);
      final right = _polar(c, roseR * 0.62, bearingDeg! + 9);
      canvas.drawLine(
        tail,
        tip,
        Paint()
          ..color = targetColor
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..close(),
        Paint()..color = targetColor,
      );
    }

    // Blickrichtung des Handys: fest oben
    final top = Offset(c.dx, c.dy - outer + 2);
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy + ringW * 1.8)
        ..lineTo(top.dx - ringW * 0.7, top.dy)
        ..lineTo(top.dx + ringW * 0.7, top.dy)
        ..close(),
      Paint()..color = scheme.onSurface,
    );
    canvas.drawCircle(c, 5, Paint()..color = scheme.onSurface);
  }

  @override
  bool shouldRepaint(CompassRosePainter old) => true;
}
