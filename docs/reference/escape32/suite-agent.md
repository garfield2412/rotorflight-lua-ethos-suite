# Agentenauftrag: ESCape32 in RF Ethos Suite

## Ziel und Arbeitsbereich

Implementiere die Suite-Seite des [ESCape32-Drafts](../escape32-forward-programming-draft.md).
Gegenstück: [Firmware-Auftrag](firmware-agent.md).
Arbeite im Repository garfield2412/rotorflight-lua-ethos-suite auf einem eigenen
Implementierungsbranch, ausgehend vom aktuellen Draft-Branch. Lies zuerst
AGENTS.md und die für geänderte Pfade geltenden Regeln. Prüfe den aktuellen Code;
die im Draft genannten Revisionen sind Recherche-Snapshots.

Dieser Auftrag umfasst Lua-Codec, Sessionsteuerung, Seite, Menü,
Simulator-Fixtures, Tests und Dokumentation. Änderungen an Rotorflight-C oder
ESCape32-Firmware gehören zum Firmware-Auftrag beziehungsweise in einen
separaten Auftrag. Firmware-Flashing gehört nicht zum Umfang.

## Sprache dieses Drafts

Ausdrückliche Nutzervorgabe: Für diesen Draft ausschließlich englische UI-Texte
verwenden. Texte direkt in der experimentellen Seite halten; keine Sprachdateien
für ESCape32 ändern. Die spätere Lokalisierung gehört erst in die produktive
Integration. Diese Vorgabe gilt vor den allgemeinen i18n-Empfehlungen.

## Geprüfte Referenz und aktueller Folgeauftrag

Lies die [Wi-Fi-Link-Referenz](wifi-link-reference.md). Der offizielle ESP32-Link
implementiert bereits Lesen, Ändern und Speichern über die 38400/8N1-CLI.
Unsere Suite benötigt dafür keinen Wi-Fi- oder WebSocket-Client. Sie bleibt
MSPv2-Client des FC; der Firmware-Agent portiert den seriellen Teil auf RF007.

Codec, Sessionsteuerung, Seite und Contract v1 existieren bereits. Als Nächstes
den realen FC-Adapter integrieren und seine gemeldeten Zustände wahrheitsgemäß
anzeigen. Ein Protokolltest oder eine erkannte ESC17.3-Identität darf fehlende
Hardware-Capabilities nicht ersetzen. Schema 1 bleibt exakt 17.2/17.3; andere
Revisionen sind identity-only. Das aktuelle UI umfasst neun von 47 Einstellungen;
weitere Keys gehören in einen eigenen Schema-/UI-/Testschritt.

## 1. Gemeinsamen Vertrag übernehmen

Übernimm den vorhandenen Contract v1 auf fork-lokalem MSP2 0x5FE0 mit
Byte-Layouts und Testvektoren. Prüfe ihn gegen den tatsächlichen MSP-Transport der
Suite und melde Größen-, Fragmentierungs- oder Queue-Probleme zurück.

Der Vertrag muss CAPS, OPEN, STATUS, GET, SET, SAVE und CLOSE abdecken:
Command-IDs, Byte-Reihenfolge, Längen, Capability-Bits, Sessiontoken,
Request-IDs, Parametertypen, Skalierung, Status, Fehler, Zeitlimits und
Wiederholungsregeln. GET/SET/SAVE-Ergebnisse müssen eindeutig zuordenbar sein.
CAPS muss ohne Änderung an Motorpins oder Start einer Programmiersession
abfragbar sein.

Implementiere keine geratenen produktiven Command-IDs oder ESC-Signaturen.
Der vorhandene v1-Vertrag ist die Grundlage. Vertragsänderungen erst gemeinsam
mit Firmware, Fixtures und Companion-Pin abstimmen. Halte den experimentellen
Hardwarepfad bis zum konkreten Nachweis gesperrt.
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
7. Ergänze Menü, englische Hilfe und Seitendokumentation erst mit
   wahrheitsgemäßer Capability-/Experiment-Gating-Logik.

BEC, Eingangs-/Telemetriemodus, Brushed-Modus, Reset, freie CLI-Befehle,
Motoransteuerung und Firmware-Flash bleiben außerhalb dieser ersten Seite.
Führe keine automatische Änderung dieser Einstellungen zur Verbindungsherstellung aus.

## Abnahme mit dem realen Firmwareadapter

- Bestehenden bytegenauen Vertrag beibehalten; nötige Änderungen zuerst mit
  Firmware und Koordinator abstimmen, Fixtures und Companion-Pin gemeinsam ändern.
- WAIT_POWER/Busy, echte Identität, Readback/Normalisierung, Save-bestätigt und
  Restart erforderlich anzeigen. Nach lost OPEN/CLOSE die bestehende
  idempotente Recovery verwenden; kein ungeprüftes zweites SAVE.
- Der Wi-Fi-Link zeigt bei Öffnen die vollständige Einstellungenliste. Die
  Suite lädt weiter einzelne begrenzte Keys; weder show-Text noch WebSocket-
  Requestpräfixe als MSP-Parameterblock oder ESC-Echo behandeln.
- Mit realem RF007 zuerst info/GET, dann die neun freigegebenen Werte prüfen.
  Verfügbare Wi-Fi-Messwerte nur aus einer getrennten Referenzsession vergleichen.
- Erweiterung von Feldumfang, BEC, Modi oder Bootloader folgt nicht automatisch
  aus der Wi-Fi-Referenz. Keine neuen Sprachdateien für diesen Draft anlegen.

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
