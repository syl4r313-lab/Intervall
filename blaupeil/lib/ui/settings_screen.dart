import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../state/providers.dart';
import 'calibration_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _environment(double n) {
    if (n < 2.3) return 'freies Feld';
    if (n < 2.8) return 'gemischt';
    if (n < 3.2) return 'Innenraum';
    return 'dicht bebauter Innenraum';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Umgebung (Pfadverlust n)', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Je mehr Wände und Menschen, desto schneller wird das Signal '
            'leiser. Das beeinflusst nur die Entfernungsschätzung.',
          ),
          Slider(
            value: s.pathLossExponent,
            min: kMinPathLossExponent,
            max: kMaxPathLossExponent,
            divisions: ((kMaxPathLossExponent - kMinPathLossExponent) * 10)
                .round(),
            label: s.pathLossExponent.toStringAsFixed(1),
            onChanged: n.setPathLossExponent,
          ),
          Text(
            'n = ${s.pathLossExponent.toStringAsFixed(1)} '
            '(${_environment(s.pathLossExponent)})',
            textAlign: TextAlign.center,
          ),
          const Divider(height: 48),
          Text('Referenz bei 1 m', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${s.rssiAt1m.toStringAsFixed(1)} dBm'
            '${s.calibrated ? ' (kalibriert)' : ' (Standard)'}',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalibrationScreen()),
            ),
            icon: const Icon(Icons.straighten),
            label: const Text('Kalibrieren'),
          ),
          const SizedBox(height: 8),
          if (s.calibrated)
            TextButton(
              onPressed: n.resetCalibration,
              child: Text(
                'Zurück auf '
                '${kDefaultRssiAt1m.toStringAsFixed(0)} dBm',
              ),
            ),
        ],
      ),
    );
  }
}
