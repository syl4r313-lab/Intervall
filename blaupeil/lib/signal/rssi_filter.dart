import '../config.dart';
import 'circular_stats.dart';

/// Glättet RSSI-Werte eines Geräts mit einem zeitbasierten EMA.
///
/// Zeitbasiert statt messungsbasiert, weil ein iPhone je nach Lage ein paar
/// Messungen pro Sekunde liefert und ein Android-Gerät im Low-Latency-Scan
/// deutlich mehr. Ein festes alpha würde auf Android viel nervöser reagieren.
class RssiFilter {
  RssiFilter({this.timeConstantS = kRssiTimeConstantS});

  final double timeConstantS;
  double? _value;
  DateTime? _last;

  double? get value => _value;

  double update(double rssi, DateTime at) {
    if (_value == null) {
      _value = rssi;
    } else {
      final dt = at.difference(_last!).inMicroseconds / 1e6;
      _value = _value! + emaAlpha(dt, timeConstantS) * (rssi - _value!);
    }
    _last = at;
    return _value!;
  }

  void reset() {
    _value = null;
    _last = null;
  }
}
