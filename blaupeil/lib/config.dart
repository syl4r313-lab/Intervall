/// Zentrale Stellschrauben. Alle „magischen Zahlen“ der App wohnen hier.
library;

// ---------------------------------------------------------------------------
// Funk-Kennung
// ---------------------------------------------------------------------------

/// Eigene 128-bit Service-UUID. Nur Geräte, die genau diese UUID funken,
/// werden überhaupt beachtet.
const String kServiceUuid = 'f4d9b6c5-107b-4830-9745-52907fb51ac9';

/// Präfix im Local Name.
const String kNamePrefix = 'BP-';

/// Maximale Länge der Kennung nach dem Präfix. Zusammen mit „BP-“ ergibt das
/// 8 Zeichen, mehr passt neben der 128-bit UUID nicht ins 31-Byte-Paket.
const int kMaxIdLength = 5;

// ---------------------------------------------------------------------------
// Scannen
// ---------------------------------------------------------------------------

/// iOS meldet 127, wenn kein RSSI verfügbar ist. Solche Werte fliegen raus.
const int kRssiUnavailable = 127;

/// Nach so vielen Sekunden ohne Signal wird ein Gerät in der Liste ausgegraut.
const Duration kStaleAfter = Duration(seconds: 10);

// ---------------------------------------------------------------------------
// RSSI-Glättung
// ---------------------------------------------------------------------------

/// Zeitkonstante des EMA-Filters in Sekunden. Zeitbasiert, weil iOS und
/// Android sehr unterschiedlich oft messen. Bei ca. 3,5 Messungen pro Sekunde
/// entspricht 1,0 s einem klassischen alpha von etwa 0,25.
const double kRssiTimeConstantS = 1.0;

// ---------------------------------------------------------------------------
// Entfernung
// ---------------------------------------------------------------------------

/// Referenzwert „RSSI bei 1 m“, falls noch nicht kalibriert.
const double kDefaultRssiAt1m = -59.0;

/// Pfadverlust-Exponent n. 2,0 freies Feld, 3,5 dicht bebauter Innenraum.
const double kDefaultPathLossExponent = 2.5;
const double kMinPathLossExponent = 2.0;
const double kMaxPathLossExponent = 3.5;

/// Grenzen der Entfernungsstufen in Metern.
const double kNearLimitM = 2.0;
const double kMidLimitM = 8.0;

/// Dauer der Kalibriermessung.
const Duration kCalibrationDuration = Duration(seconds: 10);

// ---------------------------------------------------------------------------
// Kompass
// ---------------------------------------------------------------------------

/// Zeitkonstante der Kompassglättung (Sinus/Kosinus-Mittelung) in Sekunden.
const double kHeadingTimeConstantS = 0.15;

/// Ab dieser gemeldeten Ungenauigkeit (Grad) bitten wir um die „Acht“.
const double kCompassAccuracyWarnDeg = 30.0;

// ---------------------------------------------------------------------------
// Peilung
// ---------------------------------------------------------------------------

/// Sektorgröße in Grad. 360 / 15 = 24 Sektoren.
const double kSectorSizeDeg = 15.0;

/// Sektoren, die höchstens so viele dB unter dem Maximum liegen, fließen in
/// die Richtungsbestimmung ein.
const double kStrongSectorWindowDb = 3.0;

/// Kontrast (Maximum minus Mittelwert) als Maß für die Konfidenz.
const double kContrastUsableDb = 4.0;
const double kContrastGoodDb = 8.0;

/// Ab so viel abgedeckter Drehung gilt die Messung als vollständig.
const double kMinCoverageDeg = 270.0;

/// Halbe Breite des Unschärfe-Fächers um den Pfeil, je Konfidenzstufe.
const double kSpreadGoodDeg = 20.0;
const double kSpreadUsableDeg = 30.0;
const double kSpreadUncertainDeg = 45.0;

/// Mindestanzahl Messwerte, damit eine Kalibrierung zählt.
const int kMinCalibrationSamples = 5;
