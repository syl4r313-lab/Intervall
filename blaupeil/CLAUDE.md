# Projekt: BlauPeil (Bluetooth-Peilung mit Kompass, Flutter)

## Ziel

Eine plattformübergreifende App für Android und iOS, die andere Handys per Bluetooth Low Energy (BLE) findet und die ungefähre Richtung zum Zielgerät auf einer Kompassrose anzeigt. Prinzip: Funkpeilung nach Art der Amateurfunk-„Fuchsjagd“. Die Nutzerin dreht sich einmal im Kreis, die App merkt sich zu jeder Himmelsrichtung die Signalstärke, und dort, wo das Signal am lautesten „ruft“, zeigt der Pfeil hin.

Erwartete Genauigkeit: Richtung etwa ±20 bis 45 Grad, Entfernung nur als grobe Stufe (nah / mittel / fern). Das ist ehrliches Topfschlagen, kein GPS. Die UI muss diese Unschärfe sichtbar machen.

Alle Kombinationen sollen funktionieren: Android findet Android, Android findet iPhone, iPhone findet Android, iPhone findet iPhone.

## Grundprinzip: Nur Geräte, die mitmachen

- Die App hat zwei Rollen: **Sender** (das Gerät, das gefunden werden will) und **Sucher**.
- Gesucht werden ausschließlich Geräte, auf denen die App im Sendermodus läuft. Fremde Geräte werden nicht erfasst.
- Identifikation über eine feste, eigene 128-bit Service-UUID plus eine kurze Kennung im Local Name, nicht über MAC-Adressen (die wechseln Android und iOS regelmäßig).
- Sendermodus ist jederzeit sichtbar und mit einem Tipp beendbar.

## Tech-Stack

- Flutter (aktuelle stabile Version), Dart mit Null Safety
- State Management: Riverpod
- Pakete (jeweils aktuelle stabile Version, vor Einsatz auf pub.dev prüfen):
  - `flutter_blue_plus` für das Scannen (Central-Rolle)
  - `flutter_ble_peripheral` für das Senden (Peripheral-Rolle), da `flutter_blue_plus` kein Advertising kann
  - `flutter_compass` für die Himmelsrichtung
  - `permission_handler` für Berechtigungen
  - `shared_preferences` für Einstellungen und Kalibrierwerte
- Keine Netzwerkzugriffe, keine Analytics, keine Speicherung von Standortdaten
- Falls ein Paket sich als unzuverlässig erweist: plattformspezifischen Code über Platform Channels schreiben (Kotlin für Android, Swift für iOS), statt stundenlang um das Paket herumzubasteln

## Plattform-Besonderheiten (wichtig)

**iOS kann beim Senden nur zwei Dinge funken:** Service-UUIDs und einen Local Name. Service Data, Manufacturer Data oder TxPower lassen sich mit CoreBluetooth nicht mitschicken. Deshalb gilt für beide Plattformen dasselbe schlanke Format:

- Service-UUID: feste App-UUID (in `config.dart` definieren)
- Local Name: `BP-` plus Kennung, insgesamt maximal 8 Zeichen, weil eine 128-bit UUID bereits den Großteil des 31-Byte-Pakets belegt
- Den Referenzwert „RSSI bei 1 m“ kennt deshalb nur der Sucher, und zwar aus seiner eigenen Kalibrierung (Default −59 dBm)

**iOS im Hintergrund:** Ein iPhone im Sendermodus funkt nur zuverlässig, solange die App im Vordergrund ist. Im Hintergrund verschiebt iOS die UUID in einen „Overflow-Bereich“ und lässt den Local Name weg. Die App zeigt im Sendermodus deshalb einen Hinweis: „Bitte App geöffnet und Bildschirm an lassen, sonst bist du schwer zu finden.“ Zusätzlich: Wake Lock bzw. `idleTimerDisabled`, solange der Sendermodus aktiv ist.

**iOS beim Scannen:** Für laufende RSSI-Updates muss Duplikat-Filterung aus sein (`continuousUpdates: true` in `flutter_blue_plus` bzw. `CBCentralManagerScanOptionAllowDuplicatesKey`). RSSI-Werte von 127 bedeuten „nicht verfügbar“ und werden verworfen.

**Android beim Scannen:** Android drosselt Apps, die öfter als 5-mal in 30 Sekunden einen Scan starten. Scan einmal starten und laufen lassen. Scan-Modus Low Latency.

**Android beim Senden:** Sender als Foreground Service mit Notification, damit das System ihn nicht schlafen legt.

## Berechtigungen und Konfiguration

**Android (`AndroidManifest.xml`)**
- `BLUETOOTH_SCAN` (ohne `neverForLocation`, da die App Signalstärken zur Ortung nutzt), `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`
- `ACCESS_FINE_LOCATION`
- `FOREGROUND_SERVICE` plus passender Service-Typ
- minSdk 26

**iOS (`Info.plist`)**
- `NSBluetoothAlwaysUsageDescription` mit verständlicher deutscher Begründung
- `NSLocationWhenInUseUsageDescription` für die Kompassrichtung
- `UIBackgroundModes`: `bluetooth-peripheral` und `bluetooth-central` (hilft begrenzt, ersetzt aber nicht den Vordergrund-Hinweis)
- Deployment Target iOS 13 oder höher

Berechtigungen erst anfragen, wenn die Rolle gewählt wird, jeweils mit kurzer Begründung im Klartext.

## Projektstruktur

```
lib/
  main.dart
  config.dart                  // UUID, Filterparameter, Schwellen, Sektorgröße
  ble/
    beacon_advertiser.dart     // Sendermodus
    beacon_scanner.dart        // Scan, Filter auf Service-UUID + Präfix "BP-"
    beacon_payload.dart        // Aufbau und Parsen des Local Name
  sensors/
    compass_provider.dart      // Azimut als Stream
  signal/
    rssi_filter.dart           // Glättung (EMA oder 1D-Kalman)
    distance_estimator.dart    // Log-Distanz-Modell
    bearing_estimator.dart     // Peilung aus (Azimut, RSSI)-Paaren
    circular_stats.dart        // Winkelmathematik
  ui/
    role_select_screen.dart
    sender_screen.dart
    device_list_screen.dart
    bearing_screen.dart        // Kompassrose + Pfeil (CustomPainter)
    calibration_screen.dart
    settings_screen.dart
test/
  circular_stats_test.dart
  bearing_estimator_test.dart
  distance_estimator_test.dart
  rssi_filter_test.dart
```

BLE und Kompass hinter abstrakten Klassen kapseln, damit die gesamte Signalverarbeitung ohne Gerät testbar ist.

## Signalverarbeitung

**Glättung**
- RSSI schwankt stark (Mehrwegeausbreitung, Körperabschattung). Pro Gerät ein 1D-Kalman-Filter oder EMA (alpha ca. 0,2 bis 0,3), Parameter in `config.dart`.
- iOS und Android liefern unterschiedlich viele Messungen pro Sekunde. Filter zeitbasiert statt messungsbasiert auslegen.

**Entfernung (nur grob)**
- Log-Distanz-Modell: `d = 10 ^ ((rssiAt1m - rssi) / (10 * n))`
- `n` zwischen 2,0 (freies Feld) und 3,5 (Innenraum), Default 2,5, in den Einstellungen wählbar
- Ausgabe als Stufe: nah (< 2 m), mittel (2 bis 8 m), fern (> 8 m), zusätzlich Zahl mit „ca.“

**Kompass**
- `flutter_compass` liefert den Heading-Wert (iOS über CoreLocation, Android über den Rotationsvektor-Sensor)
- Glätten über Sinus/Kosinus-Mittelung, damit der Sprung bei 0/360 Grad keine Pirouetten verursacht
- Bei ungenauer Kompassmeldung Hinweis anzeigen: Handy in einer Acht bewegen

**Peilung (Kernalgorithmus)**
1. Nutzerin hält das Handy flach vor die Brust. Der Körper dient als Abschirmung nach hinten, das ist gewollt.
2. Nutzerin dreht sich in 10 bis 20 Sekunden einmal um 360 Grad.
3. Jede RSSI-Messung wird mit dem aktuellen Azimut gepaart.
4. Paare in 24 Sektoren à 15 Grad einsortieren, pro Sektor Median bilden.
5. Leere Sektoren aus den Nachbarn interpolieren, danach zirkulär glätten (Fenster ±1 Sektor).
6. Richtung = gewichteter Kreismittelwert der stärksten Sektoren (alle innerhalb 3 dB unter dem Maximum).
7. Konfidenz = Kontrast zwischen Maximum und Mittelwert in dB. Unter 4 dB „unsicher“, 4 bis 8 dB „brauchbar“, über 8 dB „gut“.
8. Wurden weniger als ca. 270 Grad abgedeckt, Messung als unvollständig markieren und zum Weiterdrehen auffordern.

Nach der Messung zeigt der Pfeil auf die ermittelte Himmelsrichtung und dreht sich live mit dem Kompass mit. Nach ein paar Schritten erneut peilen lassen („warm/kalt“-Prinzip).

## UI

- **Rollenwahl:** zwei große Buttons, „Ich will gefunden werden“ / „Ich suche“
- **Sender:** Kennung eingeben (max. 5 Zeichen nach „BP-“), Start/Stopp, deutlicher Hinweis „Dein Gerät ist gerade sichtbar“, auf iOS zusätzlich „App geöffnet lassen“
- **Geräteliste:** gefundene Kennungen mit geglättetem RSSI und Entfernungsstufe, sortiert nach Signalstärke, Geräte ohne Signal seit 10 Sekunden ausgrauen
- **Peilung:** Kompassrose mit Norden, Zielpfeil, Konfidenz als Farbe und Text, Fortschrittsring für die 360-Grad-Drehung, Entfernungsstufe
- **Kalibrierung:** Sender in 1 m Abstand, 10 Sekunden messen, Median als `rssiAt1m` speichern
- Material 3 auf Android, auf iOS dasselbe Layout (keine getrennten Cupertino-Screens nötig)
- Dunkelmodus, große Touch-Ziele, alle Texte auf Deutsch

## Tests

- `circular_stats`: Mittelwert über den 0/360-Sprung (350° und 10° → 0°)
- `bearing_estimator`: synthetische Daten mit Maximum bei bekanntem Winkel plus Rauschen, Ergebnis innerhalb ±15°; unvollständige Drehung wird erkannt
- `distance_estimator` und `rssi_filter` mit festen Beispielwerten
- Manueller Testplan als `TESTPLAN.md`: alle vier Plattformkombinationen, jeweils Sender im Vordergrund und im Hintergrund

## Meilensteine

1. Projektgerüst, Rollenwahl, Berechtigungsfluss auf beiden Plattformen
2. Sendermodus, sichtbar in einem generischen BLE-Scanner (z. B. nRF Connect) von Android und iOS aus
3. Scanner mit Geräteliste und geglättetem RSSI, getestet mit beiden Plattformen als Sender
4. Kompass mit sauberem Azimut
5. Peilalgorithmus plus Unit-Tests
6. Peilbildschirm mit Kompassrose
7. Kalibrierung und Einstellungen
8. `TESTPLAN.md` und README mit Build-Anleitung für beide Plattformen

## Build-Hinweise

- Android: `flutter build apk` genügt, APK lässt sich direkt installieren
- iOS: Build nur auf einem Mac mit Xcode möglich. Zum Installieren auf echten iPhones ist ein Apple-Account nötig (kostenloser Account: App läuft 7 Tage; für Verteilung an mehrere Geräte TestFlight über den kostenpflichtigen Developer Account)
- Bluetooth funktioniert nicht im Simulator oder Emulator, getestet wird auf echten Geräten

## Arbeitsweise für Claude Code

- Meilensteine nacheinander umsetzen und nach jedem Schritt kurz zusammenfassen, was fertig ist
- Keine zusätzlichen Features ohne Rückfrage
- Kommentare im Code auf Deutsch, Bezeichner auf Englisch
- Magische Zahlen zentral in `config.dart`
- Plattformunterschiede im Code mit einem kurzen Kommentar begründen, damit später niemand „aufräumt“, was absichtlich so ist
