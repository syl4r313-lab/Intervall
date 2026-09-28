# Manueller Testplan BlauPeil

Bluetooth lässt sich nicht im Simulator testen, also braucht es echte Geräte:
mindestens ein Android-Handy und ein iPhone, besser je zwei.

## Vorbereitung

- [ ] Auf allen Geräten Bluetooth an, auf Android zusätzlich der Standortdienst.
- [ ] App frisch installiert, Berechtigungsdialoge einmal durchlaufen.
- [ ] Optional: [nRF Connect](https://www.nordicsemi.com/Products/Development-tools/nRF-Connect-for-mobile)
      als neutraler Zeuge, um zu sehen, was tatsächlich gefunkt wird.

## 1. Berechtigungen

| # | Schritt | Erwartung | Android | iOS |
|---|---------|-----------|---------|-----|
| 1.1 | Rolle „Ich will gefunden werden“ wählen | Erklärtext, dann Systemdialog(e) | ☐ | ☐ |
| 1.2 | Rolle „Ich suche“ wählen | Erklärtext, dann Bluetooth und Standort | ☐ | ☐ |
| 1.3 | Berechtigung ablehnen | Hinweis, App bleibt auf der Startseite | ☐ | ☐ |
| 1.4 | Dauerhaft ablehnen, erneut wählen | Knopf „Einstellungen“ öffnet die App-Einstellungen | ☐ | ☐ |

## 2. Sender, geprüft mit nRF Connect

| # | Schritt | Erwartung | Android | iOS |
|---|---------|-----------|---------|-----|
| 2.1 | Kennung `TEST1`, Senden starten | nRF Connect zeigt `BP-TEST1` mit der Service-UUID aus `config.dart` | ☐ | ☐ |
| 2.2 | Anzeige in der App | „Dein Gerät ist gerade sichtbar“, auf iOS zusätzlich „App geöffnet lassen“ | ☐ | ☐ |
| 2.3 | Android: Benachrichtigung | Sichtbar, Tipp auf „Beenden“ stoppt das Senden, App merkt es binnen 2 s | ☐ | n/a |
| 2.4 | Senden beenden | Gerät verschwindet aus nRF Connect | ☐ | ☐ |
| 2.5 | Android: Bluetooth-Name nach dem Beenden | Wieder der ursprüngliche Name | ☐ | n/a |
| 2.6 | Android: App während des Sendens per Taskmanager beenden, neu starten | Bluetooth-Name wird zurückgesetzt | ☐ | n/a |
| 2.7 | Zurück-Taste während des Sendens | Senden endet | ☐ | ☐ |
| 2.8 | Bildschirm bleibt an, solange gesendet wird | ja | ☐ | ☐ |

## 3. Alle vier Kombinationen

Für jede Zeile: Sender auf Gerät A, Sucher auf Gerät B, Abstand etwa 3 m.
„Vordergrund“ heißt App offen, Bildschirm an. „Hintergrund“ heißt App
minimiert oder Bildschirm aus.

| Sender → Sucher | Sender im | Erscheint in Liste | RSSI stabil | Peilung trifft (±45°) | Notizen |
|-----------------|-----------|--------------------|-------------|-----------------------|---------|
| Android → Android | Vordergrund | ☐ | ☐ | ☐ | |
| Android → Android | Hintergrund | ☐ | ☐ | ☐ | Erwartung: funktioniert dank Foreground Service |
| Android → iPhone  | Vordergrund | ☐ | ☐ | ☐ | |
| Android → iPhone  | Hintergrund | ☐ | ☐ | ☐ | Erwartung: funktioniert |
| iPhone → Android  | Vordergrund | ☐ | ☐ | ☐ | |
| iPhone → Android  | Hintergrund | ☐ | ☐ | ☐ | Erwartung: schlecht bis gar nicht, Name fehlt |
| iPhone → iPhone   | Vordergrund | ☐ | ☐ | ☐ | |
| iPhone → iPhone   | Hintergrund | ☐ | ☐ | ☐ | Erwartung: allenfalls „Unbenannter Sender“ |

## 4. Geräteliste

| # | Schritt | Erwartung | ☐ |
|---|---------|-----------|---|
| 4.1 | Zwei Sender unterschiedlich weit weg | Näherer steht oben | ☐ |
| 4.2 | Einen Sender beenden | Nach 10 s ausgegraut, „Seit … s kein Signal“ | ☐ |
| 4.3 | Bluetooth am Sucher ausschalten | Banner „Bluetooth ist aus“ | ☐ |
| 4.4 | Entfernungsstufe bei 1 m / 5 m / 15 m | nah / mittel / fern (grob) | ☐ |

## 5. Kompass und Peilung

| # | Schritt | Erwartung | ☐ |
|---|---------|-----------|---|
| 5.1 | Handy langsam drehen | „N“ bleibt nach Norden ausgerichtet, kein Springen bei 0/360° | ☐ |
| 5.2 | Kompass verwirren (Magnet in der Nähe) | Hinweis „in Form einer Acht bewegen“ erscheint | ☐ |
| 5.3 | Volle Drehung in 15 s, Sender im Freien 10 m entfernt | Pfeil innerhalb ±45°, Konfidenz mindestens „brauchbar“ | ☐ |
| 5.4 | Nur halbe Drehung, dann „Auswerten“ | „Messung unvollständig“, Knopf „Weiterdrehen“ | ☐ |
| 5.5 | Nach der Peilung weiterdrehen | Pfeil bleibt auf die Himmelsrichtung ausgerichtet | ☐ |
| 5.6 | Drei Peilungen auf dem Weg zum Sender | Signal wird lauter, Stufe wechselt Richtung „nah“ | ☐ |
| 5.7 | Gleiche Messung im Innenraum | Fächer breiter, Konfidenz eher „unsicher“ (plausibel) | ☐ |

## 6. Kalibrierung und Einstellungen

| # | Schritt | Erwartung | ☐ |
|---|---------|-----------|---|
| 6.1 | Sender in 1 m, 10 s messen | Median wird angezeigt, typischerweise −50 bis −70 dBm | ☐ |
| 6.2 | Speichern, App neu starten | Wert bleibt erhalten | ☐ |
| 6.3 | Kein Sender aktiv, Kalibrierung starten | Meldung „Zu wenige Messwerte“ | ☐ |
| 6.4 | n von 2,0 auf 3,5 schieben | Entfernungsangaben werden kleiner | ☐ |
| 6.5 | „Zurück auf −59 dBm“ | Standardwert wieder aktiv | ☐ |

## Protokoll

| Datum | Geräte (Modell, OS) | Umgebung | Auffälligkeiten |
|-------|---------------------|----------|-----------------|
| | | | |
