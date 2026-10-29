# Agentenauftrag: ESCape32 in RF Ethos Suite

## Ziel und Arbeitsbereich

Implementiere die Suite-Seite des [ESCape32-Drafts](../escape32-forward-programming-draft.md).
Gegenstück: [Firmware-Auftrag](firmware-agent.md).
Arbeite im Repository garfield2412/rotorflight-lua-ethos-suite auf einem eigenen
Implementierungsbranch, ausgehend vom aktuellen Draft-Branch. Lies zuerst
AGENTS.md und die für geänderte Pfade geltenden Regeln. Prüfe den aktuellen Code;
die im Draft genannten Revisionen sind Recherche-Snapshots.

Dieser Auftrag umfasst Lua-Codec, Sessionsteuerung, Seite, Menü, Übersetzungen,
Simulator-Fixtures, Tests und Dokumentation. Änderungen an Rotorflight-C oder
ESCape32-Firmware gehören zum Firmware-Auftrag beziehungsweise in einen
separaten Auftrag. Firmware-Flashing gehört nicht zum Umfang.

## 1. Gemeinsamen Vertrag übernehmen

Der Firmware-Agent liefert zuerst einen versionierten MSP-Vertragsentwurf mit
Byte-Layouts und Testvektoren. Prüfe ihn gegen den tatsächlichen MSP-Transport der
Suite und melde Größen-, Fragmentierungs- oder Queue-Probleme zurück.

Der Vertrag muss CAPS, OPEN, STATUS, GET, SET, SAVE und CLOSE abdecken:
Command-IDs, Byte-Reihenfolge, Längen, Capability-Bits, Sessiontoken,
Request-IDs, Parametertypen, Skalierung, Status, Fehler, Zeitlimits und
Wiederholungsregeln. GET/SET/SAVE-Ergebnisse müssen eindeutig zuordenbar sein.
CAPS muss ohne Änderung an Motorpins oder Start einer Programmiersession
abfragbar sein.

Implementiere keine geratenen produktiven Command-IDs oder ESC-Signaturen.
Bis ein versionierter Vertrag vorliegt, arbeite an Transport-Mocks,
Sessionmodell und Tests ohne aktive Geräteanbindung. Markiere einen noch nicht
abgestimmten Transport als experimentell und halte ihn standardmäßig aus.
Ein unbekannter oder ablehnender FC darf keine Schreibnachrichten auslösen.

Übernimm dieselben versionierten Testvektoren wie die Firmware-Seite. Dokumentiere
die gemeinsame Vertragsversion und die getesteten Companion-Commit-SHAs.

## 2. Vorhandene Architektur prüfen

Lies insbesondere:
- src/rfsuite/lib/msp_4wif_esc_fwd_prog.lua
- src/rfsuite/lib/msp_esc_parameters_am32.lua
- src/rfsuite/app/pages/esc_forward_4way.lua
- src/rfsuite/app/pages/esc_forward_vendor.lua
- src/rfsuite/app/esc_protocol_guard.lua
- MSP-Bus, Queue, Scheduler und lib/require.lua
- docs/memory-and-module-lifecycle.md und docs/i18n-locales.md

Übernimm Lifecycle- und Bus-Konventionen. Nutze den vorhandenen
Vierweg-Selektor nicht zum CLI-Eintritt: Er aktiviert einen anderen Transport.
Ermittle die aktuelle Menüquelle; ältere Generatorhinweise können veraltet sein.

## 3. Umsetzung in prüfbaren Schritten

1. Erstelle einen eigenständigen ESCape32-Codec, vorgesehen unter
   src/rfsuite/lib/msp_esc_parameters_escape32.lua. Validiere Antwortlängen,
   Versionen, Typen und Grenzen vor dem Decodieren. Transportiere Rohwerte
   verlustfrei; wandle Anzeigeeinheiten nur an definierter Stelle um.
2. Implementiere ein ereignisgesteuertes Sessionmodell mit genau einem
   ausstehenden Geräteauftrag. Unterscheide Verbindungsfehler,
   nicht unterstützte Firmware, unbekannte ESC-Revision, Eintritt mit
   ausstehendem ESC-Einschalten, bereit, beschäftigt, Ergebnis unbekannt,
   Lesebestätigung und erforderlichen Neustart.
3. Beginne mit einer lesenden Seite unter
   src/rfsuite/app/pages/esc_forward_escape32.lua. Zeige nur nachgewiesene
   Motorziele und die tatsächlich gelesene ESC-Identität. CAPS entscheidet über
   Unterstützung; API-Version und Telemetrie-Signatur allein reichen nicht.
4. Ergänze nach erfolgreicher lesender Integration lokale Änderungen, explizites
   Anwenden und explizites Speichern. Vorgesehene erste Parameter:
   revdir, timing, freq_min, freq_max, duty_spup, duty_ramp, duty_rate,
   prot_temp, prot_curr. Grenzen, Abhängigkeiten und Skalierung müssen zum
   unterstützten Firmware-Schema passen.
5. Zeige normalisierte Werte als tatsächlich angewendete Werte. Unterscheide
   lokal geändert, im ESC-RAM bestätigt, Save bestätigt und nach ESC-Neustart
   auf Persistenz geprüft. Ein MSP-ACK ist keine Persistenzbestätigung.
6. Bei SET-/SAVE-Timeout ist das Ergebnis unbekannt. Kein automatisches erneutes
   Flash-Save; Status und Readback gemäß Vertrag abfragen. Ungeklärte Vorgänge
   verhindern weitere widersprüchliche Änderungen.
7. Ergänze Menü, Übersetzungsquellen, Hilfe und Seitendokumentation erst mit
   wahrheitsgemäßer Capability-/Experiment-Gating-Logik.

BEC, Eingangs-/Telemetriemodus, Brushed-Modus, Reset, freie CLI-Befehle,
Motoransteuerung und Firmware-Flash bleiben außerhalb dieser ersten Seite.
Führe keine automatische Änderung dieser Einstellungen zur Verbindungsherstellung aus.

## 4. Schließen, Linkverlust und Ressourcen

Sperre Einstieg und Bearbeitung entsprechend Arming-/Override-Status; die
maßgebliche Durchsetzung bleibt im FC. Ein Linkverlust darf nie durch die UI
als erfolgreiche Freigabe bestätigt werden.

Beim Verlassen: CLOSE anfordern, lokale Aufträge entkoppeln, späte Callbacks
durch eine Sessiongeneration ignorieren, Subscriber/Handler entfernen und
Dialoge schließen. Bei fehlendem CLOSE-ACK auf den FC-Watchdog hinweisen und
keine wiederhergestellte Motorbereitschaft behaupten. Ein noch ausstehender
ESC-Neustart muss sichtbar bleiben.

Keine Tabellen, Strings, Handler oder Requests pro Wakeup neu erzeugen, wenn
sich der Zustand nicht geändert hat. Polling begrenzen und vorhandene
Queue-/Retry-Semantik prüfen. Nur geänderte Felder und Statusanzeigen aktualisieren.

## 5. Prüfungen und Abnahme

Ergänze gezielte Lua-5.4-Harnesses nach Repository-Konvention für:
- fehlende/inkompatible CAPS und unbekannte ESC-Schemata;
- gültige und fehlerhafte Vertragsvektoren, Skalierung und Wertebereiche;
- Zielwechsel, abgelaufene Tokens und späte Antworten einer alten Session;
- normalisierte SET-Werte, Readback-Abweichung und unbekannten Schreibausgang;
- doppelte Request-IDs ohne erneutes Save und Close während eines Auftrags;
- Linkverlust und Neustartpflicht ohne fälschlich erfolgreiche Freigabe.

Führe alle bestehenden Harnesses aus, die geänderte Runtime-Dateien laden.
Prüfe betroffene Generatoren auf Drift. Führe check-tags.py und check-fit.py
bei entsprechenden Änderungen aus. Teste die Seite im verfügbaren Ethos-
Simulator, insbesondere auf 480x320; dokumentiere fehlendes Tooling ausdrücklich.

Aktualisiere docs/pages/setup/esc_motors/esc_tools/escape32.md, Seitenindex und
Hilfe nach den geltenden Regeln. Dokumentiere Menüpfad, Gating, unterstützte
Companion-Firmware und erforderlichen ESC-Power-Cycle.

Liefere Commits und einen reviewfähigen Draft-PR beziehungsweise Vergleich:
konkretes Verhalten, gemeinsame Vertragsversion, Companion-Commit, tatsächlich
ausgeführte Tests, Simulatorbilder falls verfügbar und offene Hardwareprüfungen.
Keine End-to-End-Freigabe ohne echten FC/ESC über den vorgesehenen Funktransport.
