import 'package:blaupeil/ble/beacon_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Name bauen und zurücklesen', () {
    final name = BeaconPayload.buildLocalName('ANNA');
    expect(name, 'BP-ANNA');
    expect(name.length, lessThanOrEqualTo(8));
    expect(BeaconPayload.parseLocalName(name), 'ANNA');
  });

  test('Fremde Namen werden ignoriert', () {
    expect(BeaconPayload.parseLocalName('Pixel 8'), isNull);
    expect(BeaconPayload.parseLocalName('BP-'), isNull);
    expect(BeaconPayload.parseLocalName('BP-TOOLONG'), isNull);
    expect(BeaconPayload.parseLocalName(null), isNull);
  });

  test('Eingaben werden bereinigt', () {
    expect(BeaconPayload.sanitizeId('ab-c 12xyz'), 'ABC12');
    expect(() => BeaconPayload.buildLocalName(''), throwsArgumentError);
  });
}
