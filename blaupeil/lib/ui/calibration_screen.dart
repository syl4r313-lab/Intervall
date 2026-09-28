import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/beacon_scanner.dart';
import '../config.dart';
import '../signal/bearing_estimator.dart' show median;
import '../state/providers.dart';

/// Kalibrierung: Sender in 1 m Abstand, 10 Sekunden messen, Median merken.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  String? _key;
  final _samples = <double>[];
  StreamSubscription<BeaconSighting>? _sub;
  Timer? _timer;
  DateTime? _startedAt;
  double? _result;
  String? _message;

  bool get _running => _timer != null;

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final key = _key;
    if (key == null) return;
    _samples.clear();
    _sub = ref.read(sightingsProvider).listen((s) {
      if (s.key == key) _samples.add(s.rssi.toDouble());
    });
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (DateTime.now().difference(_startedAt!) >= kCalibrationDuration) {
        _stop();
      } else {
        setState(() {});
      }
    });
    setState(() {
      _result = null;
      _message = null;
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;
    setState(() {
      if (_samples.length < kMinCalibrationSamples) {
        _message =
            'Zu wenige Messwerte (${_samples.length}). Ist der Sender '
            'aktiv und in der Nähe?';
      } else {
        _result = median(_samples);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final beacons = ref.watch(beaconRegistryProvider).values.toList();
    final settings = ref.watch(settingsProvider);
    final t = Theme.of(context).textTheme;
    final progress = _startedAt == null || !_running
        ? 0.0
        : DateTime.now().difference(_startedAt!).inMilliseconds /
              kCalibrationDuration.inMilliseconds;

    return Scaffold(
      appBar: AppBar(title: const Text('Kalibrieren')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Lege das Sender-Handy in genau 1 m Abstand vor dich. Halte dein '
              'Handy flach vor die Brust und schau zum Sender. Dann '
              '${kCalibrationDuration.inSeconds} Sekunden stillhalten.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Aktueller Wert: ${settings.rssiAt1m.toStringAsFixed(1)} dBm'
              '${settings.calibrated ? '' : ' (Standard)'}',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _key,
              decoration: const InputDecoration(
                labelText: 'Sender',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final b in beacons)
                  DropdownMenuItem(value: b.key, child: Text(b.label)),
              ],
              onChanged: _running ? null : (k) => setState(() => _key = k),
            ),
            if (beacons.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Noch kein Sender gefunden.'),
              ),
            const SizedBox(height: 24),
            if (_running) ...[
              LinearProgressIndicator(value: progress, minHeight: 12),
              const SizedBox(height: 8),
              Text(
                '${_samples.length} Messwerte …',
                textAlign: TextAlign.center,
              ),
            ] else
              FilledButton.icon(
                onPressed: _key == null ? null : _start,
                icon: const Icon(Icons.timer),
                label: Text('${kCalibrationDuration.inSeconds} s messen'),
              ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              Text(
                'Median: ${_result!.toStringAsFixed(1)} dBm '
                'aus ${_samples.length} Messwerten',
                style: t.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await ref
                      .read(settingsProvider.notifier)
                      .setRssiAt1m(_result!);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.save),
                label: const Text('Als Referenz speichern'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
