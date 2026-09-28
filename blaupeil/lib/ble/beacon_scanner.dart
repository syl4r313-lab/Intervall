import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../config.dart';
import 'beacon_payload.dart';

/// Eine einzelne Messung: wer, wie laut, wann.
class BeaconSighting {
  const BeaconSighting({
    required this.key,
    required this.id,
    required this.rssi,
    required this.at,
  });

  /// Stabiler Schlüssel für die Liste: die Kennung, falls bekannt.
  final String key;

  /// Kennung aus dem Local Name, `null` wenn der Name fehlt.
  final String? id;
  final int rssi;
  final DateTime at;
}

/// Sucher: liefert Messungen von Geräten im Sendermodus.
abstract class BeaconScanner {
  Stream<BeaconSighting> get sightings;
  Future<void> start();
  Future<void> stop();
}

class FbpBeaconScanner implements BeaconScanner {
  final _controller = StreamController<BeaconSighting>.broadcast();
  StreamSubscription<List<ScanResult>>? _sub;
  final _guid = Guid(kServiceUuid);

  @override
  Stream<BeaconSighting> get sightings => _controller.stream;

  @override
  Future<void> start() async {
    if (_sub != null) return;
    _sub = FlutterBluePlus.onScanResults.listen(_onResults);
    // Android drosselt Apps, die öfter als 5-mal in 30 s einen Scan starten.
    // Deshalb einmal starten und laufen lassen, nicht periodisch neu starten.
    //
    // continuousUpdates: iOS filtert sonst Duplikate und liefert pro Gerät nur
    // eine einzige Meldung (CBCentralManagerScanOptionAllowDuplicatesKey).
    await FlutterBluePlus.startScan(
      withServices: [_guid],
      continuousUpdates: true,
      oneByOne: true,
      androidScanMode: AndroidScanMode.lowLatency,
      // Ohne neverForLocation verlangt Android für Scanergebnisse die genaue
      // Standortberechtigung. Wir leiten ja tatsächlich eine Richtung ab.
      androidUsesFineLocation: true,
    );
  }

  void _onResults(List<ScanResult> results) {
    for (final r in results) {
      // 127 heißt bei iOS „kein Wert“.
      if (r.rssi == kRssiUnavailable) continue;
      final ad = r.advertisementData;
      if (!ad.serviceUuids.contains(_guid)) continue;
      final name = ad.advName.isNotEmpty ? ad.advName : r.device.platformName;
      final id = BeaconPayload.parseLocalName(name);
      // Ohne Namen (z. B. iPhone-Sender im Hintergrund) bleibt nur die
      // Geräteadresse als Schlüssel. Die wechselt gelegentlich, reicht aber
      // für eine laufende Suche.
      final key = id ?? '?${r.device.remoteId.str}';
      _controller.add(
        BeaconSighting(key: key, id: id, rssi: r.rssi, at: r.timeStamp),
      );
    }
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await FlutterBluePlus.stopScan();
  }
}
