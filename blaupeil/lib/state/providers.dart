import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/beacon_advertiser.dart';
import '../ble/beacon_scanner.dart';
import '../config.dart';
import '../signal/rssi_filter.dart';

// ---------------------------------------------------------------------------
// Einstellungen
// ---------------------------------------------------------------------------

/// Wird in main() mit der geladenen Instanz überschrieben.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('in main() überschreiben'),
);

class Settings {
  const Settings({
    required this.rssiAt1m,
    required this.pathLossExponent,
    required this.calibrated,
    required this.senderId,
  });

  final double rssiAt1m;
  final double pathLossExponent;
  final bool calibrated;
  final String senderId;

  Settings copyWith({
    double? rssiAt1m,
    double? pathLossExponent,
    bool? calibrated,
    String? senderId,
  }) => Settings(
    rssiAt1m: rssiAt1m ?? this.rssiAt1m,
    pathLossExponent: pathLossExponent ?? this.pathLossExponent,
    calibrated: calibrated ?? this.calibrated,
    senderId: senderId ?? this.senderId,
  );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _kRssi = 'rssiAt1m';
  static const _kN = 'pathLossExponent';
  static const _kId = 'senderId';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Settings build() {
    final p = ref.watch(sharedPreferencesProvider);
    final rssi = p.getDouble(_kRssi);
    return Settings(
      rssiAt1m: rssi ?? kDefaultRssiAt1m,
      pathLossExponent: p.getDouble(_kN) ?? kDefaultPathLossExponent,
      calibrated: rssi != null,
      senderId: p.getString(_kId) ?? '',
    );
  }

  Future<void> setRssiAt1m(double v) async {
    state = state.copyWith(rssiAt1m: v, calibrated: true);
    await _prefs.setDouble(_kRssi, v);
  }

  Future<void> resetCalibration() async {
    state = state.copyWith(rssiAt1m: kDefaultRssiAt1m, calibrated: false);
    await _prefs.remove(_kRssi);
  }

  Future<void> setPathLossExponent(double n) async {
    state = state.copyWith(pathLossExponent: n);
    await _prefs.setDouble(_kN, n);
  }

  Future<void> setSenderId(String id) async {
    state = state.copyWith(senderId: id);
    await _prefs.setString(_kId, id);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);

// ---------------------------------------------------------------------------
// BLE
// ---------------------------------------------------------------------------

final advertiserProvider = Provider<BeaconAdvertiser>(
  (ref) => PlatformBeaconAdvertiser(),
);

final scannerProvider = Provider<BeaconScanner>((ref) {
  final s = FbpBeaconScanner();
  ref.onDispose(s.stop);
  return s;
});

/// Rohe Messungen aller Sender, für Peilung und Kalibrierung.
final sightingsProvider = Provider<Stream<BeaconSighting>>(
  (ref) => ref.watch(scannerProvider).sightings,
);

class TrackedBeacon {
  TrackedBeacon({required this.key, required this.id});

  final String key;
  final String? id;
  final RssiFilter filter = RssiFilter();
  int lastRssi = 0;
  DateTime lastSeen = DateTime.fromMillisecondsSinceEpoch(0);

  String get label => id != null ? '$kNamePrefix$id' : 'Unbenannter Sender';
  double get smoothedRssi => filter.value ?? lastRssi.toDouble();

  bool isStale(DateTime now) => now.difference(lastSeen) > kStaleAfter;
}

/// Alle bisher gesehenen Sender mit geglättetem RSSI.
class BeaconRegistry extends Notifier<Map<String, TrackedBeacon>> {
  @override
  Map<String, TrackedBeacon> build() {
    final sub = ref.watch(sightingsProvider).listen(_onSighting);
    ref.onDispose(sub.cancel);
    return {};
  }

  void _onSighting(BeaconSighting s) {
    final b = state[s.key] ?? TrackedBeacon(key: s.key, id: s.id);
    b.filter.update(s.rssi.toDouble(), s.at);
    b.lastRssi = s.rssi;
    b.lastSeen = s.at;
    state = {...state, s.key: b};
  }

  void clear() => state = {};
}

final beaconRegistryProvider =
    NotifierProvider<BeaconRegistry, Map<String, TrackedBeacon>>(
      BeaconRegistry.new,
    );
