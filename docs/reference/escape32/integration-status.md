# ESCape32: Implementierungs- und Prüfstand

Stand: 2026-10-29. Experimenteller Integrationsdraft; keine Freigabe für reale
ESC-Programmierung. Beide Implementierungsaufträge wurden von getrennten Agenten
bearbeitet und durch den koordinierenden Agenten geprüft.

## Implementiert

Die Suite enthält einen versionierten MSP-Codec, Sessionsteuerung und eine
experimentelle Seite im Entwicklermenü. Sie fragt Fähigkeiten ab und erlaubt
einen Sessionstart ausschließlich bei bestätigtem CLI-/Lese-Backend und gültigem
Motorziel. Ohne validierten Hardwareadapter bleibt die Geräteprogrammierung
gesperrt. Unbekannte ESC-Schemata erlauben keine Parameteränderungen.

Der Firmware-Draft enthält einen portablen, asynchronen CLI-Parser und Sessionkern,
einen optionalen MSP-/Scheduler-Anschluss, begrenzte Puffer und eine strukturierte
Parameter-Whitelist. CAPS/OPEN/STATUS/GET/SET/SAVE/CLOSE verwenden den gemeinsamen
experimentellen Vertrag v1 auf MSP2 0x5FE0. Diese ID ist nur für die Fork-Drafts
vorgesehen und noch nicht upstream zugeteilt.

Die Firmwarefunktion ist standardmäßig deaktiviert. Auch bei Aktivierung von
USE_ESCAPE32_FORWARD_PROGRAMMING wird ohne Adapter nur der Core gemeldet; es
erfolgt kein Motorpin-Zugriff.

Suite und Firmware verwenden identische Vertragsfixtures:

- Suite: bin/escape32/contract-v1.json
- Firmware: src/test/fixtures/escape32-contract-v1.json
- SHA256: c89371c13c94d7e6aeec6f372c704306114c010f143554a5b4472d516f6f84ff

Erste getestete Firmware-Codebasis (aktuelle 17.3-Erweiterung siehe unten):
[9c6273aa0afc61277a9cfeca96bb2b82740a1267](https://github.com/garfield2412/rotorflight-firmware/commit/9c6273aa0afc61277a9cfeca96bb2b82740a1267).
Spätere reine Dokumentationscommits ändern diese getestete Codebasis nicht.

## Unabhängig geprüft

Der Koordinator hat den realen C-Kern als Shared Library kompiliert und die reale
Lua-Sessionsteuerung darüber mit einem injizierten Fake-Serial-Adapter verbunden.
Der Test prüft gemeinsame Byte-Layouts, echte C-Antworten im Lua-Codec, Sessionstart,
Lesen, normalisierte Schreibwerte, alle neun Firmware-Readbacks, Speichern,
Keepalive, Abschluss sowie absichtlich verlorene SAVE-/CLOSE-Antworten.
Wiederholte Anfragen verursachen keinen zusätzlichen SAVE.

Diese Prüfung hat zwei Integrationslücken sichtbar gemacht und deren Korrektur
bestätigt: fehlender Keepalive während einer offenen, ruhenden Seite und falsche
Einordnung eines bereits abgeschlossenen CLOSE nach verlorenem ACK.

Der Firmware-Harness besteht lokal mit strikten C11-Warnungen sowie ASan/UBSan.
Lokal war LeakSanitizer wegen ptrace nicht ausführbar; ASan/UBSan wurden mit
ASAN_OPTIONS=detect_leaks=0 ausgeführt. In GitHub Actions besteht der vollständige
Sanitizer-Lauf ohne diese lokale Einschränkung.

[Firmware-CI Run 40829033784](https://github.com/garfield2412/rotorflight-firmware/actions/runs/40829033784)
ist erfolgreich abgeschlossen: nativer Core sowie vollständiger STM32F7X2-Build
mit deaktiviertem und aktiviertem experimentellem Feature.

GNU size in diesen beiden Builds (Bytes):

| Feature | text | data | bss |
| --- | ---: | ---: | ---: |
| aus | 444762 | 11152 | 121444 |
| an | 448634 | 11152 | 121668 |

Diese Messung beschreibt den gebauten MCU-Target, keine Laufzeit-Stackmessung.

Die Suite-Agentenprüfung umfasst Codec-/Session- und Seiten-Harnesses,
Übersetzungstags, Textbreiten sowie bestehende Menü-, Arming-, Offline-,
ESC-Signatur-, Schutz- und Lifecycle-Regressionsprüfungen. Der dabei gefundene
Konflikt zwischen dynamischer Sichtbarkeit und Arming-Sperren wurde durch einen
statischen Eintrag im bestehenden Entwicklermenü vermieden.

## Veröffentlichte Suite und CI

Suite-Codecommit des ersten Integrationsstands:
[8931e492c5cb86bacb9417c8a1d19fcf9c332b2c](https://github.com/garfield2412/rotorflight-lua-ethos-suite/commit/8931e492c5cb86bacb9417c8a1d19fcf9c332b2c).
[Companion-Bridge-CI 40830302494](https://github.com/garfield2412/rotorflight-lua-ethos-suite/actions/runs/40830302494)
ist erfolgreich: 136 Codec-/Session-Checks, 25 Seitenchecks und der echte
C/Lua-Cross-Repository-Test gegen den gepinnten Firmware-Codecommit.
[Theme-/Locale-CI 40830302399](https://github.com/garfield2412/rotorflight-lua-ethos-suite/actions/runs/40830302399)
ist ebenfalls erfolgreich, einschließlich Übersetzungstags in allen Locales.

Lokal bestanden außerdem alle tool.lua-referenzierenden bestehenden Harnesses,
167 Instruction-Budget-Checks sowie der ESC-Signatur-Selbsttest mit 88 positiven
Checks und 48 korrekt abgewiesenen sabotierten Gates. Die 24 geänderten Locale-
Dateien wurden unabhängig semantisch gegen den Ausgangscommit verglichen:
ausschließlich das neue ESCape32-Objekt wurde ergänzt.

## Tests wiederholen

Voraussetzungen: Python 3, Host-GCC und Lua 5.4. Beide Draft-Branches lokal auschecken.
Aus dem Suite-Verzeichnis, mit angepasstem Firmwarepfad:

```sh
lua5.4 bin/escape32/verify_escape32.lua
lua5.4 bin/escape32/verify_escape32_page.lua
python3 bin/escape32/verify_bridge.py --firmware ../escape32-firmware
```

Aus dem Firmware-Verzeichnis:

```sh
sh src/test/run_escape32_tests.sh
CFLAGS='-fsanitize=address,undefined -fno-omit-frame-pointer -g' sh src/test/run_escape32_tests.sh
```

Der Suite-Workflow .github/workflows/escape32-bridge.yml pinnt den geprüften
Firmware-Codecommit und führt den Cross-Repository-Test erneut aus. Bei einer
Vertragsänderung müssen Fixture, beide Implementierungen und Companion-Pin
zusammen geprüft und aktualisiert werden.

## Offene Hardwarearbeit

Es fehlt ein echter, validierter bidirektionaler Motorpad-Adapter. Der vorhandene
KISS-Passthrough bietet hierfür keinen ausreichenden RX-/Recoverypfad. Der nächste
Hardwareauftrag muss eine konkrete FC-/Board-/Pad-/ESC-Kombination, die unabhängige
FC-Versorgung während des ESC-Einschaltens, die Zweidraht-/Eindraht-Pegel und den
Halbduplex-Turnaround prüfen. Er muss Timer-/DMA-/Pin-Ownership einschließlich
gemeinsam genutzter Ressourcen und die sichere Rückkehr zum Motorbetrieb abdecken.

Bei nicht bestätigter Recovery hält der aktuelle Core den Restart-Latch bis zum
FC-Neustart. Ein ESC-Power-Cycle allein hebt ihn nicht auf. Ein künftiger Adapter
benötigt einen belegten, expliziten Recoverypfad; einfaches Löschen des Inhibits
ist keine Lösung.

Reale Funk-/ESC-Benchtests, Persistenzprüfung nach echtem Power-Cycle und visuelle
Abnahme im Ethos-Simulator stehen aus. Die lokalen UI-Harnesses ersetzen keine
Simulatorbilder. Weitere MCU-Familien wurden nicht gebaut. Es wurde kein ESC
geflasht oder programmiert und kein Draft in master gemergt.

## RF007 und ESCape32 17.3

Nutzerkonfiguration: Vantac RF007, DShot am Motor-/ESC-Throttle-Ausgang,
ESCape32 Revision 17 Patch 3. Offizieller Target-Default: MOTOR1 PA09,
TIM1_CH2 AF1, DMA2 Stream6 Channel0; MCU STM32F722RET6/STM32F7X2.
Tatsächliche Laufzeit-Resources und elektrische Rückrichtung sind noch am
konkreten Board zu prüfen; Target-Defaults ersetzen keinen Hardware-Nachweis.

Der [RF007-Hardwareauftrag](https://github.com/garfield2412/rotorflight-firmware/blob/draft/escape32-forward-programming/.agents/tasks/escape32-rf007.md)
enthält Quellen, Ressourcen, RX-/Timer-Grenzen und die Bench-Abnahme.

Schema1 ist jetzt in beiden Implementierungen ausdrücklich für 17.2 und 17.3
freigegeben. Unbekannte 17.4/16.3 bleiben für GET, SET und SAVE gesperrt.
Neue lokale Tests: 163 Codec-/Session-Checks, 46 Seitenchecks, portabler C-Kern
mit ASan/UBSan sowie echter C/Lua-Test mit Hauptidentität 17.3 erfolgreich.
Die Hardware-Capabilities bleiben unverändert gesperrt.

Beleg: prog.c (Parameter/CLI) und util.c (checkcfg) sind in
[17.2](https://github.com/neoxic/ESCape32/tree/734097d2825deb49328342335e931ec18ce5823d)
und [17.3](https://github.com/neoxic/ESCape32/tree/1d718c143380c3eb7e6581478990e1496632e5b8)
byteidentisch, ebenso common.h und defs.h. Das korrigiert die frühere falsche
Beschreibung des master72004eff-Stands als 17.2; er lag bereits nach 17.3.

Aktueller Firmware-Codecommit:
[118af7e9bb516e4b4eda6c24f2f49cf60cd88480](https://github.com/garfield2412/rotorflight-firmware/commit/118af7e9bb516e4b4eda6c24f2f49cf60cd88480).
Der Suite-Companion-Workflow pinnt diesen Stand. Neue Remote-CI-Ergebnisse
werden nach Abschluss ergänzt; die früheren CI-Links oben beziehen sich auf
den jeweils ausdrücklich genannten ursprünglichen Codecommit.
