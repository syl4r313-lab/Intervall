# Intervall

Eine schlichte App fürs Intervallfasten, mit einem Ziel: 10 kg abnehmen.

**→ https://syl4r313-lab.github.io/Intervall/**

Die App besteht im Kern aus einer einzigen Datei — `index.html`. Kein Setup, kein
Konto, keine Werbung. Die Daten liegen ausschließlich im Browser (localStorage)
und verlassen das Gerät nicht.

## Benutzen

Die Adresse oben aufrufen. Beim ersten Start das aktuelle Gewicht eintragen; das
Ziel wird automatisch auf 10 kg weniger gesetzt.

Auf dem Handy über das Teilen-Menü „Zum Home-Bildschirm hinzufügen" — dann startet
sie im eigenen Fenster ohne Browserleiste, mit eigenem Symbol. Am Rechner bieten
Chrome und Edge in der Adressleiste ein Installieren-Symbol an.

Ein Service Worker legt die App lokal ab, sie läuft also auch ohne Internet.
Beim Start wird trotzdem kurz nach einer neueren Fassung geschaut, damit
Änderungen ankommen.

Alternativ genügt weiterhin ein Doppelklick auf `index.html` — dann ohne
Installation und ohne Service Worker.

## Veröffentlichen

`.github/workflows/pages.yml` schiebt bei jedem Push auf den Standard-Branch die
Dateien nach GitHub Pages. Nichts zu bauen, die Dateien gehen unverändert online.

## Was drin ist

**Fasten**

- Protokoll wählen: 14:10, 16:8, 18:6 oder 20:4
- Timer mit Ring, zeigt die verbleibende Zeit bis zum Ziel
- Start- und Zielzeit auf einen Blick, danach das Essensfenster
- Übersicht der letzten 7 Tage und Liste der letzten Fastenzeiten

Der Timer rechnet immer aus dem gespeicherten Startzeitpunkt. Er läuft also
korrekt weiter, wenn der Browser geschlossen, das Handy gesperrt oder die Seite
neu geladen wird.

**Wenn der Knopf vergessen wurde.** Der Timer ist nicht die einzige Quelle —
jede Zeit lässt sich von Hand setzen:

- *Startzeit korrigieren* erscheint während eines laufenden Fastens und
  verschiebt den Start nachträglich auf die richtige Uhrzeit.
- *Zeit nachtragen* trägt ein komplettes Fasten für einen beliebigen Tag ein,
  auch wenn das Handy gar nicht dabei war.
- Ein Tippen auf eine Zeile im Verlauf öffnet sie zum Ändern oder Löschen.

Endet ein Fasten rechnerisch vor seinem Start, ist der Folgetag gemeint — die
übliche Nacht zwischen Abendessen und Mittag. Zeiten in der Zukunft werden
abgelehnt.

**Erinnerung ans Ende.** Während eines laufenden Fastens erscheint
*Kalender-Erinnerung für HH:MM Uhr*. Ein Tippen erzeugt einen Termin mit Alarm
zur Zielzeit; ab da meldet sich der Kalender des Geräts — auch bei geschlossener
App und ohne Internet.

Bewusst kein Web-Push: Eine Push-Nachricht wird von einem Server verschickt, und
eine statisch ausgelieferte Seite hat keinen. Ein App-eigener Timer hilft nicht,
weil das Betriebssystem die App im Hintergrund einfriert — also genau dann, wenn
die Erinnerung gebraucht wird. Der Kalender löst das ohne Server und ohne
laufende Kosten.

**Gewicht**

- Aktuelles Gewicht, bereits abgenommene Kilos, Rest bis zum Ziel
- Fortschrittsbalken über die 10 kg
- Verlaufskurve mit eingezeichneter Ziellinie
- Liste aller Einträge mit Differenz zum vorherigen Wert

Pro Tag ein Eintrag — ein zweiter Eintrag am selben Tag überschreibt den ersten.
Das Datum lässt sich ändern, um Werte nachzutragen.

## Daten

Alles liegt unter dem Schlüssel `intervall.v1` im localStorage des Browsers.
Das bedeutet auch: andere Browser oder ein anderes Gerät sehen die Daten nicht,
und wer die Browserdaten löscht, löscht auch den Verlauf. Der Knopf
„Alle Daten löschen" unten setzt die App auf Anfang zurück.

## Hinweis

Die App ist ein Werkzeug zum Nachhalten, keine medizinische Beratung.
Bei Vorerkrankungen, Schwangerschaft oder Medikamenteneinnahme vorher ärztlich abklären.
