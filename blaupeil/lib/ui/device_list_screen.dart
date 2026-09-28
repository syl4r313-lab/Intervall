import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/beacon_scanner.dart';
import '../signal/distance_estimator.dart';
import '../state/providers.dart';
import 'bearing_screen.dart';
import 'calibration_screen.dart';
import 'settings_screen.dart';

class DeviceListScreen extends ConsumerStatefulWidget {
  const DeviceListScreen({super.key});

  @override
  ConsumerState<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends ConsumerState<DeviceListScreen> {
  late final BeaconScanner _scanner;
  Timer? _tick;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanner = ref.read(scannerProvider);
    _startScan();
    // Sekundentakt, damit verstummte Geräte rechtzeitig ausgegraut werden.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _startScan() async {
    setState(() => _error = null);
    try {
      await _scanner.start();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Suche ließ sich nicht starten. Ist '
              'Bluetooth an (und auf Android der Standortdienst)?\n$e',
        );
      }
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scanner.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beacons = ref.watch(beaconRegistryProvider).values.toList()
      ..sort((a, b) => b.smoothedRssi.compareTo(a.smoothedRssi));
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sender in der Nähe'),
        actions: [
          IconButton(
            tooltip: 'Kalibrieren',
            icon: const Icon(Icons.straighten),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalibrationScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Einstellungen',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<BluetoothAdapterState>(
            stream: FlutterBluePlus.adapterState,
            builder: (context, snap) {
              final st = snap.data;
              if (st == null || st == BluetoothAdapterState.on) {
                return const SizedBox.shrink();
              }
              return MaterialBanner(
                content: const Text('Bluetooth ist aus. Bitte einschalten.'),
                actions: [
                  TextButton(
                    onPressed: _startScan,
                    child: const Text('Erneut suchen'),
                  ),
                ],
              );
            },
          ),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(onPressed: _startScan, child: const Text('Nochmal')),
              ],
            ),
          if (!settings.calibrated)
            ListTile(
              dense: true,
              leading: const Icon(Icons.info_outline),
              title: const Text(
                'Entfernungen sind noch nicht kalibriert '
                '(Standard −59 dBm bei 1 m).',
              ),
            ),
          Expanded(
            child: beacons.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemCount: beacons.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final b = beacons[i];
                      final stale = b.isStale(now);
                      final d = estimateDistance(
                        b.smoothedRssi,
                        rssiAt1m: settings.rssiAt1m,
                        pathLossExponent: settings.pathLossExponent,
                      );
                      final color = stale ? scheme.outline : null;
                      return ListTile(
                        minTileHeight: 72,
                        enabled: !stale,
                        leading: Icon(
                          stale ? Icons.signal_wifi_off : Icons.cell_tower,
                          color: color,
                        ),
                        title: Text(
                          b.label,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        subtitle: Text(
                          stale
                              ? 'Seit ${now.difference(b.lastSeen).inSeconds} s '
                                    'kein Signal'
                              : '${b.smoothedRssi.round()} dBm · ${d.text}',
                          style: TextStyle(color: color),
                        ),
                        trailing: const Icon(Icons.explore),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BearingScreen(beaconKey: b.key),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Suche läuft …',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Noch kein Sender in Reichweite. Auf dem gesuchten Handy muss '
              'BlauPeil im Modus „Ich will gefunden werden“ laufen.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
