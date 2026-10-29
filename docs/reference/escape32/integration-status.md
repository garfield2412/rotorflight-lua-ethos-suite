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
- SHA256: 30641d53d2179d945718c8c1abf1f0527ae9c7b43d8a95d5c580d28e3b0fbf22

Firmware-Codebasis der Integration:
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
