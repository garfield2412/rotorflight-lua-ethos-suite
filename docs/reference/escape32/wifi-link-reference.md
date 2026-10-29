# ESCape32 Wi-Fi Link: protocol reference for the Rotorflight draft

Status: source-verified reference, 2026-10-29. This document records an existing
ESC-side read/write implementation and the work required to port its transport
to the Vantac RF007. No RF007 hardware validation is claimed.

## What is established

The official Wi-Fi Link is an ESP32 configurator with a real UART transmit and
receive implementation. Its browser UI reads ESC settings, changes values and
requests persistent saves through the ESCape32 text CLI. The UART/CLI path is
therefore an existing implementation, not a newly invented ESC protocol.

The remaining question is whether the RF007 can provide the same electrical and
timing behavior on its motor connector, while correctly handing over and
restoring DShot resources. MCU pin mapping, a successful ARM build and our
fake-serial tests do not answer that physical question.

Reference paths:

```text
Official implementation:
Browser <-> Wi-Fi / WebSocket <-> ESP32 UART <-> ESCape32 CLI

Rotorflight draft:
Ethos Suite <-> radio MSPv2 <-> Rotorflight session core
             <-> RF007 serial adapter (not implemented) <-> ESCape32 CLI
```

The draft needs no Wi-Fi module or WebSocket connection in the flight controller.
It reuses the ESC-facing CLI behavior and replaces the browser/ESP32 bridge.

## Pinned primary sources

Wi-Fi Link snapshot:
[40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f](https://github.com/neoxic/ESCape32-WiFi-Link/tree/40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f).
Use these immutable links when comparing a future implementation.

| Source | Verified behavior | Consequence for the draft |
| --- | --- | --- |
| [main.c:113](https://github.com/neoxic/ESCape32-WiFi-Link/blob/40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f/main/main.c#L113) | recvbuf reads UART bytes and recognizes LF-terminated OK/ERROR replies | Receive the actual ESC response, including its terminal status |
| [main.c:140](https://github.com/neoxic/ESCape32-WiFi-Link/blob/40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f/main/main.c#L140) | sendbuf resets queued UART events, flushes stale input and submits TX bytes | Establish a clean transaction boundary without discarding an active reply |
| [main.c:226](https://github.com/neoxic/ESCape32-WiFi-Link/blob/40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f/main/main.c#L226) | Text WebSocket frames pass ordinary CLI commands to UART and return their response | Wi-Fi is a transport wrapper around the text CLI |
| [main.c:408](https://github.com/neoxic/ESCape32-WiFi-Link/blob/40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f/main/main.c#L408) | UART is configured as 38400 baud, 8 data bits, no parity, 1 stop bit, no flow control, with the ESP-IDF half-duplex mode | Preserve serial framing and verify TX-to-RX turnaround |
| [root.html:400](https://github.com/neoxic/ESCape32-WiFi-Link/blob/40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f/main/root.html#L400) | Opening the configuration view requests identity and the settings listing | Settings readback is implemented by the reference |
| [root.html:621](https://github.com/neoxic/ESCape32-WiFi-Link/blob/40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f/main/root.html#L621) | Parameter edits issue a setter; an empty edit requests a getter | Read and write use the same text-command interface |
| [root.html:637](https://github.com/neoxic/ESCape32-WiFi-Link/blob/40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f/main/root.html#L637) | Saving issues a separate save command | RAM changes and persistent saves are distinct actions |
| [README pinouts](https://github.com/neoxic/ESCape32-WiFi-Link/blob/40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f/README.md#pinouts) | ESP32-C3 defaults RX4/TX2; ESP32-S2 defaults RX16/TX33 | Separate ESP32 RX/TX GPIOs and their wiring cannot be assumed equivalent to RF007 PA9 |

The ESP-IDF constant UART_MODE_RS485_HALF_DUPLEX is a software driver mode in
this source. Its name alone is not evidence that an external RS485 transceiver
or an RS485 electrical bus is required. Inspect actual reference wiring and the
RF007 signal path before choosing an adapter circuit or GPIO mode.

## ESC-side protocol and entry

The [official CLI documentation](https://github.com/neoxic/ESCape32/wiki/Configuration#cli-command-line-interface)
specifies the signal-line console, 38400/8N1, LF line endings and no ESC echo.
It documents holding the signal high for two seconds during ESC startup to
enter CLI. The RF007 must remain powered during that startup sequence.

The reference UART initialization does not establish a complete FC power-up,
DShot handover or recovery procedure. Do not assume that an ESC already
operating in DShot can be switched into CLI without restarting it.

For the user's revision, verify the ESC-side implementations:
[17.3 io.c](https://github.com/neoxic/ESCape32/blob/1d718c143380c3eb7e6581478990e1496632e5b8/src/io.c)
and [17.3 prog.c](https://github.com/neoxic/ESCape32/blob/1d718c143380c3eb7e6581478990e1496632e5b8/src/prog.c).
The parameter/CLI and checkcfg sources are byte-identical between the pinned
17.2 and 17.3 snapshots; schema 1 explicitly accepts those two patches only.

A normal settings exchange contains a command line, zero or more data lines,
and the final success/error line. Applied values may be normalized by checkcfg;
use readback as the displayed result. Save completion is not proof of
persistence through a later power cycle.

The Wi-Fi WebSocket handler includes the submitted command before the returned
UART response in its outgoing frame. That browser-facing prefix is not an ESC
echo and must not be fed into the FC's CLI response parser.

## Settings protocol, bootloader and draft scope

The Wi-Fi bridge also recognizes adapter commands such as _probe, _info,
_setwrp and _update and has a separate binary firmware-update path. These are
not the parameter-read protocol and must not be mixed into the draft's
whitelisted CLI requests. Firmware update, flash protection and motor execution
remain outside the draft.

ESCape32 17.3 defines 47 configuration entries. The Wi-Fi UI can obtain the
settings listing; the Suite currently exposes nine numeric keys:
revdir, timing, freq_min, freq_max, duty_spup, duty_ramp, duty_rate, prot_temp,
prot_curr. This is an implementation scope choice, not a nine-setting limit of
the CLI. Adding more keys requires schema, dependency, UI and test work.

The radio-side session envelope, MSP2 0x5FE0 contract v1, belongs to our fork.
The Wi-Fi project does not define that command. It also does not establish
compatibility with AM32 EEPROM blocks or the MSP 217/218 vendor payloads.

## Porting the reference to the FC

| ESP32 reference behavior | Required Rotorflight behavior |
| --- | --- |
| Dedicated UART owned by the configurator | Acquire the selected motor pin, relevant timer/DMA and serial resources exclusively |
| Event-queue waits and blocking reads | Nonblocking reads, bounded work per scheduler tick and explicit deadlines |
| A stack buffer sized for a browser request and reply | Retain the core's bounded parser/buffers; do not place an unbounded settings listing into MSP |
| UART input flush before sending | Drain stale data at a defined new transaction/session boundary; preserve partial active replies |
| CLI terminal-status detection | Incremental line parsing across arbitrary RX splits, with length/overflow/error checks |
| A separate browser save action | Explicit SAVE, request deduplication and status recovery after lost acknowledgments |
| Adapter remains attached to the ESC | Verified transition back to the FC motor output, or an explicit restart-required latch |

Do not copy the ESP32 FreeRTOS waits, 1200-byte WebSocket buffer, bootloader
branch, or unrestricted command passthrough into a flight-controller hot path.
The existing C session core already provides the bounded parameter protocol;
the next implementation task is the physical adapter and its recovery path.

On RF007 the official default MOTOR1 is PA09, TIM1_CH2 AF1, DMA2 Stream6 Channel0.
Its electrical receive path is still unverified. The existing KISS path is
TX-only and ESCSERIAL has no assigned timer pin in the board defaults.
A timer-based adapter and PA9's USART1_TX alternate function are candidates to
evaluate; neither is selected or validated by this document. USART1 also has
configured PB6/PB7 resources, so ownership must be checked before any reuse.

## Next implementation and acceptance

1. Read the actual FC resource/timer/DMA map and inspect the board signal path.
   Record the ESC hardware target and how FC power is maintained while the ESC
   is restarted. Do not substitute board defaults for the running configuration.
2. Select and justify the serial transport and its resource handover. Implement
   it behind the existing experimental boundary with bounded RX/TX processing.
3. Demonstrate identity plus one parameter read over the real RF007 motor port.
   Preserve timestamped TX/RX evidence and terminal replies. If a Wi-Fi Link is
   available, compare the same ESC's static settings through each adapter in
   separate sessions; do not attach two active drivers to the signal line.
4. Exercise SET normalization, dependent-key readback and exactly one explicit
   SAVE. Restart the ESC, identify it again and verify persistence.
5. Test split/late/error replies, lost radio responses, owner timeout and exit
   during each phase. Confirm other motor/servo/timer users are unaffected.
6. Verify normal DShot/RPM/telemetry operation after release. The current core
   retains an inhibit after unconfirmed recovery until an FC restart; an
   ESC-only power cycle does not clear that latch. A future recovery mechanism
   needs an explicit positive verification before removing the inhibit.
7. Record real FC/ESC bench results separately from C/Lua tests and ARM builds.
   Advertise validated target/read/write capabilities only after the relevant
   hardware behavior has been demonstrated.

Task entrypoints: [Suite agent](suite-agent.md), [firmware agent](firmware-agent.md),
[RF007 hardware task](https://github.com/garfield2412/rotorflight-firmware/blob/draft/escape32-forward-programming/.agents/tasks/escape32-rf007.md)
and [Wi-Fi port task](https://github.com/garfield2412/rotorflight-firmware/blob/draft/escape32-forward-programming/.agents/tasks/escape32-wifi-port.md).
