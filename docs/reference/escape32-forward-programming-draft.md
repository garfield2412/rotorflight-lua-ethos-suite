# Draft: ESCape32 forward programming through RF Ethos Suite

Status: experimental fork implementation in progress; no production hardware adapter. Researched 2026-10-29.
Scope: read and change ESC settings from the transmitter through Rotorflight.
Firmware flashing is a separate bootloader workflow and is outside this draft.

## Finding

ESCape32 motor operation with Rotorflight and ESCape32 parameter programming are
different capabilities. Bidirectional DShot provides RPM feedback; it does not
provide a general settings read/write channel. The inspected upstream/base Rotorflight snapshot
does not contain an ESCape32 parameter backend; this fork now adds the protocol
core and MSP bridge, while its physical motor-pad adapter remains pending. Adding a vendor page or assigning
an existing AM32 signature in this repository cannot enable it.

Recommended implementation: a bounded, asynchronous Rotorflight bridge to the
ESCape32 CLI on the selected motor signal line, exposed through a negotiated MSP
session API. The Suite remains the UI and MSP client. The fork already contains that companion
protocol core; physical FC/ESC programming still requires the validated adapter.

## Inspected revisions and sources

All code findings below refer to these snapshots, not every released build:

- Suite master: [16924948eb18515e138ad2240bd3712a0c8a90ec](https://github.com/garfield2412/rotorflight-lua-ethos-suite/tree/16924948eb18515e138ad2240bd3712a0c8a90ec).
- Rotorflight master: [7b54df9e1f34f0bbc825cbfe7df17a0a59cbd032](https://github.com/rotorflight/rotorflight-firmware/tree/7b54df9e1f34f0bbc825cbfe7df17a0a59cbd032).
- ESCape32 master: [72004effbb3cfd90aa127eedc23a7aa22e5fad78](https://github.com/neoxic/ESCape32/tree/72004effbb3cfd90aa127eedc23a7aa22e5fad78).
- Schema 1 compatibility: [ESCape32 17.2](https://github.com/neoxic/ESCape32/tree/734097d2825deb49328342335e931ec18ce5823d)
  and [ESCape32 17.3 / rel17](https://github.com/neoxic/ESCape32/tree/1d718c143380c3eb7e6581478990e1496632e5b8).
  Both use identical prog.c (blob 21885a08a0d0d1e6c022e8db91d1685a24589127)
  and util.c/checkcfg (blob d450d1f4a9a569701914ec327666b05111d38d43),
  so the nine allowed keys, ranges and scales are unchanged. The runtime uses
  an explicit 17.2/17.3 allowlist; unreviewed 17.4 and other revisions remain
  blocked. Correction: the originally inspected master 72004eff was already
  after 17.3; treating that snapshot as evidence for a 17.2-only gate was wrong.
- [ESCape32 Configuration](https://github.com/neoxic/ESCape32/wiki/Configuration)
  and [Settings](https://github.com/neoxic/ESCape32/wiki/Settings), accessed on the
  research date. These wiki pages track current firmware and can change.
- [Rotorflight RPM measurement](https://rotorflight.org/docs/2.1.0/setup/rpm-measurement)
  documents ESCape32 bidirectional DShot operation.

Primary implementation references:

- [ESCape32 io.c](https://github.com/neoxic/ESCape32/blob/72004effbb3cfd90aa127eedc23a7aa22e5fad78/src/io.c):
  entryirq, DShot commands, serialfunc, crsffunc, cliirq.
- [ESCape32 prog.c](https://github.com/neoxic/ESCape32/blob/72004effbb3cfd90aa127eedc23a7aa22e5fad78/src/prog.c):
  CFG_MAP, execcmd and execcrsfcmd.
- [Rotorflight esc_sensor.c](https://github.com/rotorflight/rotorflight-firmware/blob/7b54df9e1f34f0bbc825cbfe7df17a0a59cbd032/src/main/sensors/esc_sensor.c):
  signatures, four-way detection, escGetParamBufferLength, escCommitParameters.
- [Rotorflight msp.c](https://github.com/rotorflight/rotorflight-firmware/blob/7b54df9e1f34f0bbc825cbfe7df17a0a59cbd032/src/main/msp/msp.c):
  MSP_ESC_PARAMETERS, MSP_SET_ESC_PARAMETERS and MSP_SET_4WIF_ESC_FWD_PROG.
- Suite integration examples:
  `src/rfsuite/lib/msp_4wif_esc_fwd_prog.lua`,
  `src/rfsuite/lib/msp_esc_parameters_am32.lua`,
  `src/rfsuite/app/pages/esc_forward_4way.lua`,
  `src/rfsuite/app/pages/esc_forward_vendor.lua`.

## Available ESC interfaces

| Interface | What it provides | Consequence for this integration |
| --- | --- | --- |
| DShot / bidirectional DShot | Motor commands, RPM feedback and selected settings commands | Useful for a limited command page; no general parameter readback |
| CLI | Text commands at 38400 baud, 8N1, LF, on the signal line | Preferred full-settings proof of concept |
| Native serial | Motor control and telemetry; default SERIAL_BR is 460800 | The inspected serialfunc has no generic settings get/set commands |
| CRSF configuration | Device discovery, parameter metadata, reads and writes | Alternative backend requiring CRSF input and telemetry routing |
| Bootloader | Firmware update | Separate work; do not reuse AM32 flash/EEPROM addresses |

### CLI details

The documented entry method holds the signal line high for two seconds during
ESC startup. The inspected entryirq changes to CLI after approximately one second
of high level; use the documented two-second window for the prototype and verify
it on hardware. Do not assume that an already running ESC can enter CLI without
a power cycle.

CLI replies are LF-delimited and terminate with `OK\n` or `ERROR\n`.
Examples of the ESC-side exchange (not existing MSP commands):

```text
> info
< ESCape32 rev<revision>.<patch> [<target>]
< ...telemetry...
< OK
> get timing
< timing: 16
< OK
> set timing 18
< timing: 18
< OK
> save
< OK
```

The actual returned value is authoritative: `set` invokes checkcfg and may
normalize the requested value. `save` is a separate persistence operation.
Whitelist settings operations in the FC; never expose an unrestricted console:
the same CLI also contains a `throt` command that can drive a motor.

The wiki's Betaflight KISS passthrough example is a PC/serial workflow. It is not
evidence that text CLI is already tunneled through the Suite's wireless MSP path.
Bidirectional signal-line receive capability must be demonstrated on the target
FC. A one-way passthrough cannot support reliable readback.

### DShot subset

The inspected implementation includes persistent direction commands 7/8,
3D-mode commands 9/10 and save command 12. These handlers require repeated
commands. Commands 20/21 change the runtime direction override and should not be
presented as equivalent to persisted revdir.

The current wiki also describes nonstandard cycling commands 40–43 and reset 47.
They advance presets with audible feedback; they are not an arbitrary numeric
setter with machine-readable confirmation. Verify the ESC revision, Rotorflight
command validation, repetition and timing before offering them. Do not show an
assumed current timing or PWM frequency after a write-only DShot command.

### CRSF alternative

The ESC configuration requires both input_mode and telem_mode set to CRSF, with
unique telem_phid values for multiple ESCs. In the inspected implementation those
mode values are 5 and 4 respectively; they are separate enums.

The backend supports discovery and parameter reads/writes through CRSF extended
frames. This gives dynamic metadata, but is not a transparent replacement for a
normal Rotorflight DShot motor connection. An ELRS receiver link alone does not
route parameter frames to an ESC behind the FC. An explicit bridge, compatible
wiring and arbitration with receiver/telemetry traffic are still required.
Check target build exclusions as well as revision; CRSF configuration is
conditionally compiled in io.c.

## Existing Wi-Fi Link reference and remaining FC work

The [Wi-Fi Link reference analysis](escape32/wifi-link-reference.md) records the
official ESP32 implementation at immutable commit
40af21ccfafd9cb8d1c9b951d57b54f3e36bd21f. It already sends and receives the same
38400/8N1 text CLI: identity/settings reads, parameter writes and a separate save.
Its serial receive code recognizes LF-terminated OK/ERROR replies. This is
source evidence for a real ESC-facing implementation, not a claim that our
RF007 adapter has been implemented or bench-tested.

The ESP32's browser/WebSocket layer is replaced by Suite/MSP in our design.
Port the serial behavior into a nonblocking FC adapter; do not copy ESP32 waits,
browser buffers or the separate bootloader protocol. Check actual RF007 signal
routing, DShot handover and recovery. The available CLI exposes more settings
than the nine-key Suite whitelist; the limited UI is a draft scope decision.

See the [RF007 Wi-Fi port task](https://github.com/garfield2412/rotorflight-firmware/blob/draft/escape32-forward-programming/.agents/tasks/escape32-wifi-port.md)
for the next concrete firmware implementation and acceptance steps.

## Existing Suite / Rotorflight boundary

The Suite uses MSP 217 for parameter reads, 218 for writes, and 244 to select a
four-way programming target. The current four-way detection maps recognized
AM32 and BLHeli_S devices to their own payload layouts and signatures.
ESCape32 is absent from that mapping.

The parameter header is two bytes: signature and version/flags. The inspected FC
uses a 128-byte parameter buffer. It is inappropriate to send an unbounded
`show` response as this payload, copy an AM32 block layout, invent an ESCape32
signature, or treat acceptance of MSP 244 as capability detection. In a build
without four-way support its selector implementation can return success without
selecting anything.

The existing selector's release convention and cleanup patterns are useful
references, but its automatic bootloader entry must not be called for a CLI
session. Keep four-way and CLI ownership mutually exclusive.

## Implemented companion contract and pending hardware adapter

The fork implements these operations in experimental MSP2 0x5FE0, contract v1.
This is a fork-local allocation, not an upstream ESCape32/MSP standard. Exact
layouts and golden vectors are in bin/escape32/contract-v1.json and the matching
firmware fixture; capabilities remain core-only until the adapter is validated.

| Contract operation | Request data | Reply / behavior |
| --- | --- | --- |
| CAPS | Contract version | Supported backend, target capabilities and bounded transfer limits |
| OPEN | Target motor index, backend | Session token; asynchronous entry status |
| STATUS | Session token | State, error, ESC identity, outstanding request result |
| GET | Session token, request ID, allowed key | Bounded typed value or explicit unsupported error |
| SET | Session token, request ID, key, typed value | Applied value after readback; marks session dirty |
| SAVE | Session token, request ID | Confirmed CLI completion; persistence verification still separate |
| CLOSE | Session token | Release resources and report whether ESC power cycling is required |

Implementation requirements:

1. Acquire exclusive programming ownership only while disarmed, with motor
   overrides inactive. Hold a firmware-side arming inhibit throughout the session.
   Validate the motor output mapping and receive support before changing pins.
2. Stop conflicting DShot/telemetry output, configure the selected line for CLI
   entry, and prompt for ESC power-up while the FC remains powered. If ESC power
   also powers the FC, require a demonstrated alternative power arrangement.
   Do not claim an automatic ESC power cycle without switching hardware.
3. Perform timing, parsing and serial traffic in an asynchronous state machine.
   MSP handlers start/poll work; they must not wait seconds for CLI entry or
   serial replies. Use bounded preallocated RX/TX storage and response lengths.
4. Verify identity using info before permitting reads or writes. Unknown ESCs,
   unknown revisions and unsupported parameter schemas remain identity-only;
   parameter GET/SET/SAVE stay blocked.
5. Permit only known numeric setting keys initially. Parse complete replies,
   including the final status; reject truncation, malformed values and excess
   length. Handle numeric overflow before conversion.
6. Keep a session generation/token and per-request ID. Duplicate SET/SAVE
   retries return the recorded result rather than blindly repeating a flash
   save. Expired tokens and stale target replies must be rejected.
7. After SET, read the affected key and dependent values. A timeout after a
   write means outcome unknown, not failure with unchanged settings. Re-read
   before offering another save. MSP acknowledgment alone proves no persistence.
8. Close on explicit exit, owner timeout or transport loss. Restore FC pin,
   timer and telemetry ownership through a single cleanup path. If CLI cannot
   return to motor operation in place, retain the appropriate arming inhibit
   until ESC restart/reinitialization is verified. Never automatically resume a
   previous motor override.
9. Reject short, long and mismatched MSP payloads before accessing the parser.
   Return distinct unsupported, busy, power-cycle-needed, timeout, protocol,
   normalized-value and verification-failed outcomes.

Conceptual adapter lifecycle (exact wire states remain in the v1 fixture):

```text
IDLE -> ACQUIRE -> WAIT_ESC_POWER -> IDENTIFY -> READY
READY -> READ / SET / SAVE -> VERIFY -> READY
any active state -> ERROR or CLOSING -> RELEASE
RELEASE -> IDLE or RESTART_REQUIRED
```

The implemented v1 contract uses 14-byte maximum requests, fixed 32-byte replies,
a 10000 ms owner lease and 2000 ms CLI transaction deadlines. A real transport
must be measured against these limits; the ESP32 reference's blocking receive
wait is not the FC deadline policy. If block-oriented
MSP 217/218 reuse is preferred upstream, specify a new negotiated signature,
version, bounded schema and completion status first; do not silently overload
the existing vendor blocks.

## Suite integration and maintained requirements

- Maintain `src/rfsuite/lib/msp_esc_parameters_escape32.lua` for the agreed API.
  Follow the existing bus/queue conventions and module lifecycle rules.
- Maintain `src/rfsuite/app/pages/esc_forward_escape32.lua` with target selection,
  power-up guidance, identity, settings, pending changes, save and verified
  results. Use an explicit CLI session selector rather than the existing
  automatic four-way selector.
- Gate the page on an actual capability response. API version alone and ESC
  telemetry identity are insufficient. Hide or clearly disable unsupported
  actions; preserve offline navigation behavior.
- Start read-only. Enable editing only with an identified, supported schema.
  Suggested initial keys: revdir, timing, freq_min, freq_max, duty_spup,
  duty_ramp, duty_rate, prot_temp and prot_curr. Obtain limits and dependencies
  from the verified revision/schema, not copied AM32 offsets.
- Leave BEC voltage, input/telemetry mode, brushed mode, reset and throttle
  execution outside the first editable subset. These need their own hardware
  and recovery handling.
- Show values with ESCape32 units. For example timing is a raw setting using
  15 degrees / 16 per unit; duty_rate has decimal scaling. Do not confuse the
  underlying integer with the displayed engineering value.
- Publish requests only on actions or bounded polls, cache visible values, and
  reuse buffers. On close, cancel page work, release the session, unsubscribe,
  remove handlers and close progress dialogs. Ignore late callbacks.
- Add menu entries in the actual current menu source; verify the live MENUS
  structure because AGENTS.md explicitly notes stale generator references.
  Keep this draft's UI strings in English without locale-file changes. Document the page under
  docs/pages/setup/esc_motors/esc_tools/escape32.md, including the index and help.

The draft branch now includes a developer-only Suite page, a v1 session codec
and a companion FC protocol/CLI core. The page lives under Tools → Developer
so the existing armed-state menu policy remains intact. Capability discovery
keeps all hardware session actions disabled when no validated adapter exists.
The physical motor-pad CLI adapter remains unimplemented; see the companion
branch and the separate implementation/validation records for current evidence.

## Delivery steps and acceptance criteria

1. **Transport proof:** FC bench build enters CLI on one selected motor output,
   reads info and one setting bidirectionally. Record FC target, ESC target,
   revision, wiring and power sequence. Motor remains inhibited.
2. **Read-only bridge:** negotiate CAPS, read all supported keys, exercise timeout
   and cleanup over USB and the intended radio/MSP transport.
3. **Write prototype:** change one setting, verify the applied value, save once,
   power-cycle and verify persistence. Confirm the other ESC is untouched.
4. **Suite page:** add codecs, simulator fixtures, English UI text and documentation;
   then exercise the page on the smallest supported display.
5. **Hardware acceptance:** verify repeated entry/exit, two ESCs, link loss during
   entry/set/save, reboot, unknown revision, unsupported target, line stuck high,
   partial/error replies, stale session replies and duplicate request IDs.

Firmware tests should cover malformed MSP lengths, bounds, exclusive ownership,
arming rejection, parser terminal status and cleanup on every failure.
Suite harnesses should cover capability absence, stale callbacks, normalized
values, outcome-unknown writes, readback mismatch and close during a request.

Hardware validation and functional end-to-end testing with a real FC/ESC remain
outstanding. Host tests exercise the C core and Suite Lua with a fake serial
adapter; they do not establish physical transport support. No ESC was programmed
or flashed in this environment.

