# BlauPeil

Handys per Bluetooth Low Energy finden und die ungefähre Richtung auf einer
Kompassrose anzeigen. Das Prinzip stammt aus der Amateurfunk-Fuchsjagd: Du
drehst dich einmal im Kreis wie ein Leuchtturm, die App notiert zu jeder
Himmelsrichtung, wie laut das Signal ankommt, und der Pfeil zeigt dorthin, wo
es am lautesten „ruft“. Dein eigener Körper spielt dabei den Schirm, der das
Signal von hinten dämpft.

**Status:** Prototyp zum Testen auf echten Geräten. Die Signalverarbeitung ist
mit Unit-Tests abgesichert, das Funkverhalten muss sich im Feld noch beweisen
(siehe [TESTPLAN.md](TESTPLAN.md)).

## Was man erwarten darf

| Größe       | Genauigkeit                                  |
|-------------|----------------------------------------------|
| Richtung    | etwa ±20 bis 45 Grad, je nach Umgebung        |
| Entfernung  | nur als Stufe: nah (< 2 m), mittel (2 bis 8 m), fern (> 8 m) |

Das ist ehrliches Topfschlagen, kein GPS. Die App zeigt die Unschärfe offen an:
Um den Pfeil liegt ein Fächer, dessen Breite von der Konfidenz abhängt, und das
gemessene Signalprofil ist als Fläche in der Rose zu sehen. Ein schmaler Zacken
heißt „ziemlich sicher“, eine runde Kartoffel heißt „keine Ahnung“.

## Benutzung

1. Auf dem Handy, das gefunden werden soll: **„Ich will gefunden werden“**,
   Kennung eingeben (bis zu 5 Zeichen), **Senden starten**.
2. Auf dem suchenden Handy: **„Ich suche“**. Die Liste zeigt alle BlauPeil-Sender
   in Reichweite, sortiert nach Signalstärke. Gerät antippen.
3. **Peilung starten**, Handy flach vor die Brust halten und sich in 10 bis 20
   Sekunden einmal langsam um die eigene Achse drehen. Der Ring am Rand füllt
   sich mit jedem erfassten Sektor.
4. Pfeil folgen, nach ein paar Schritten **Neu peilen**. Wird das Signal
   lauter, wird es wärmer.

Für bessere Entfernungsangaben einmal **kalibrieren** (Linealsymbol in der
Geräteliste): Sender in 1 m Abstand, 10 Sekunden messen, fertig.

## APK holen, ohne selbst zu bauen

Bei jedem Push, der `blaupeil/` betrifft, baut GitHub Actions
(`.github/workflows/blaupeil.yml`) eine APK. Unter **Actions → BlauPeil prüfen
und APK bauen → letzter Lauf → Artifacts → blaupeil-apk** liegt sie als ZIP.
Entpacken, aufs Android-Handy kopieren, installieren („Installation aus
unbekannten Quellen“ erlauben).

## Selbst bauen

Voraussetzung: Flutter (stabile Version, getestet mit 3.47.5).

```bash
cd blaupeil
flutter pub get
flutter test          # Unit-Tests der Signalverarbeitung
```

**Android**

```bash
flutter build apk
# Ergebnis: build/app/outputs/flutter-apk/app-release.apk
```

Die APK lässt sich direkt installieren. Mindestversion ist Android 8 (API 26).

**iOS**

Bauen geht nur auf einem Mac mit Xcode.

```bash
cd blaupeil/ios && pod install && cd ..
open ios/Runner.xcworkspace
```

In Xcode unter *Signing & Capabilities* ein Team wählen, dann auf ein
angeschlossenes iPhone installieren. Mit einem kostenlosen Apple-Account läuft
die App 7 Tage, danach neu installieren. Für mehrere Testgeräte ist TestFlight
über den kostenpflichtigen Developer Account der bequemere Weg.

Bluetooth funktioniert weder im Simulator noch im Emulator. Getestet wird auf
echten Geräten, am besten mit zwei oder mehr.

## Wie die Geräte sich erkennen

- Feste 128-bit Service-UUID (`lib/config.dart`) plus Local Name `BP-XXXXX`.
- Gesucht werden ausschließlich Geräte, die diese UUID funken. Fremde Geräte
  fallen schon im Scan-Filter durch.
- Keine MAC-Adressen, keine Netzwerkzugriffe, keine Analytics, keine
  Speicherung von Standortdaten.

## Plattform-Eigenheiten, die Absicht sind

**Android, Sender:** Android kann keinen frei wählbaren Local Name funken,
nur den Bluetooth-Namen des Geräts. BlauPeil benennt das Handy deshalb für die
Dauer des Sendens in `BP-…` um und stellt den alten Namen beim Beenden wieder
her. Stürzt die App mitten im Senden ab, holt der nächste App-Start den Namen
zurück. Der Sender läuft als Foreground Service mit Benachrichtigung, darin
gibt es auch einen Knopf zum Beenden. Code:
`android/app/src/main/kotlin/de/blaupeil/blaupeil/BeaconAdvertiserService.kt`.

**iOS, Sender:** Ein iPhone funkt nur zuverlässig, solange BlauPeil im
Vordergrund ist. Im Hintergrund verschiebt iOS die UUID in einen
Overflow-Bereich und lässt den Namen weg. Die App hält deshalb den Bildschirm
an und weist darauf hin.

**iOS, Sucher:** Duplikat-Filter aus (`continuousUpdates`), sonst käme pro
Gerät nur eine einzige Messung an. RSSI 127 bedeutet „kein Wert“ und wird
verworfen.

**Android, Sucher:** Der Scan wird einmal gestartet und läuft durch. Android
drosselt Apps, die öfter als 5-mal in 30 Sekunden neu scannen.
`BLUETOOTH_SCAN` ist bewusst ohne `neverForLocation` deklariert, weil die App
aus Signalstärken tatsächlich eine Richtung ableitet.

## Aufbau

```
lib/
  config.dart                 alle Stellschrauben und Schwellen
  ble/                        Senden, Scannen, Namensformat
  sensors/compass_provider.dart
  signal/                     Glättung, Entfernung, Peilung, Winkelmathematik
  state/providers.dart        Riverpod-Provider, Einstellungen, Geräteliste
  ui/                         Bildschirme
test/                         Unit-Tests der Signalverarbeitung
```

Die Peilung im Detail (`lib/signal/bearing_estimator.dart`): Messpaare aus
Azimut und RSSI landen in 24 Sektoren à 15 Grad, pro Sektor zählt der Median.
Leere Sektoren werden aus den Nachbarn interpoliert, dann wird ringförmig
geglättet. Die Richtung ist der gewichtete Kreismittelwert aller Sektoren bis
3 dB unter dem Maximum. Der Abstand zwischen Maximum und Mittelwert ergibt die
Konfidenz: unter 4 dB unsicher, 4 bis 8 dB brauchbar, darüber gut.
