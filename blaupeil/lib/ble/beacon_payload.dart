import '../config.dart';

/// Aufbau und Parsen des Local Name „BP-XXXXX“.
///
/// iOS kann beim Senden nur Service-UUIDs und einen Local Name funken. Damit
/// alle vier Plattformkombinationen gleich funktionieren, steckt die Kennung
/// auf beiden Plattformen ausschließlich im Local Name.
class BeaconPayload {
  static final RegExp _allowed = RegExp(r'^[A-Z0-9]+$');

  /// Großbuchstaben und Ziffern, höchstens [kMaxIdLength] Zeichen.
  static String sanitizeId(String raw) {
    final up = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return up.length > kMaxIdLength ? up.substring(0, kMaxIdLength) : up;
  }

  static bool isValidId(String id) =>
      id.isNotEmpty && id.length <= kMaxIdLength && _allowed.hasMatch(id);

  static String buildLocalName(String id) {
    if (!isValidId(id)) {
      throw ArgumentError('Ungültige Kennung: "$id"');
    }
    return '$kNamePrefix$id';
  }

  /// Liefert die Kennung ohne Präfix oder `null`, wenn der Name nicht passt.
  static String? parseLocalName(String? name) {
    if (name == null || !name.startsWith(kNamePrefix)) return null;
    final id = name.substring(kNamePrefix.length);
    return isValidId(id) ? id : null;
  }
}
