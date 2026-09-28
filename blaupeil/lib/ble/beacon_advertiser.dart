import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config.dart';
import 'beacon_payload.dart';

class AdvertiserStatus {
  const AdvertiserStatus({required this.advertising, this.error});
  final bool advertising;
  final String? error;
}

/// Sendermodus: macht dieses Gerät für Sucher sichtbar.
abstract class BeaconAdvertiser {
  Future<void> start(String id);
  Future<void> stop();
  Future<AdvertiserStatus> status();
}

/// Plattform-Implementierung.
///
/// Android: eigener Kotlin-Code (BeaconAdvertiserService). Grund:
/// `flutter_ble_peripheral` kann auf Android weder einen eigenen Local Name
/// funken (Android kennt nur „Gerätename mitsenden“) noch einen Foreground
/// Service starten, ohne den Android den Sender im Standby schlafen legt.
///
/// iOS: `flutter_ble_peripheral`, das setzt CBAdvertisementDataLocalNameKey
/// und die Service-UUID, mehr erlaubt CoreBluetooth ohnehin nicht.
class PlatformBeaconAdvertiser implements BeaconAdvertiser {
  static const _android = MethodChannel('de.blaupeil/advertiser');
  final _peripheral = FlutterBlePeripheral();

  @override
  Future<void> start(String id) async {
    final name = BeaconPayload.buildLocalName(id);
    if (Platform.isAndroid) {
      await _android.invokeMethod<void>('start', {
        'localName': name,
        'serviceUuid': kServiceUuid,
      });
    } else {
      await _peripheral.start(
        advertiseData: AdvertiseDataCore(
          serviceUuid: kServiceUuid,
          localName: name,
        ),
      );
    }
    // iOS: idleTimerDisabled, damit das iPhone nicht in den Hintergrund
    // rutscht und dort den Local Name verliert. Android: Bildschirm an hilft
    // zusätzlich zum Foreground Service bei aggressiven Energiesparern.
    await WakelockPlus.enable();
  }

  @override
  Future<void> stop() async {
    try {
      if (Platform.isAndroid) {
        await _android.invokeMethod<void>('stop');
      } else {
        await _peripheral.stop();
      }
    } finally {
      await WakelockPlus.disable();
    }
  }

  @override
  Future<AdvertiserStatus> status() async {
    if (Platform.isAndroid) {
      final m = await _android.invokeMapMethod<String, Object?>('status');
      return AdvertiserStatus(
        advertising: m?['advertising'] == true,
        error: m?['error'] as String?,
      );
    }
    return AdvertiserStatus(advertising: await _peripheral.isAdvertising);
  }
}
