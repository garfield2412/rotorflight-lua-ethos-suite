---
title: ESCape32
sidebar_label: ESCape32
sidebar_position: 5
---

# ESCape32

Experimental ESCape32 settings page using a dedicated Rotorflight CLI-session
bridge. It does not use the AM32/four-way bootloader and does not flash firmware.

## Where to find it

*Configuration* → *Tools* → *Developer* → *ESCape32*

Hidden until Developer mode is enabled. The tile has `lockedWhileArmed = true`
and is greyed out until the flight controller answers. It has no ESC telemetry
protocol gate: the page explicitly checks its own backend capabilities before
offering an ESC target or opening a session. Unknown arming state also prevents
session entry and editing.

The companion draft currently has **no validated production hardware adapter**.
Its default capabilities report only the protocol core, so this page reports
backend unavailable and sends no OPEN/GET/SET/SAVE. A supported adapter must
explicitly report validated CLI, read support and a target mask. Write controls
also require write capability, a writable session and schema 1 for ESC revision
17.2 or 17.3, matched explicitly. Revision 17.4 and other unreviewed revisions
show identity only; claiming schema 1 alone does not unlock them.

The nine parameter definitions and their validation are identical in the pinned
[17.2 source](https://github.com/neoxic/ESCape32/tree/734097d2825deb49328342335e931ec18ce5823d)
and [17.3 source](https://github.com/neoxic/ESCape32/tree/1d718c143380c3eb7e6581478990e1496632e5b8).
Recognizing 17.3 does not establish a working CLI receive path on a Vantac RF007
motor pad or grant any hardware capability.

## Settings

| Control | What it does |
| --- | --- |
| Check support | Performs a side-effect-free capability query. No motor pins are changed. |
| ESC target | Offers only targets present in the validated-target mask. |
| Open session | Starts the dedicated CLI session. Keep the FC powered and power the selected ESC when prompted. |
| ESC identity | Shows the revision, patch and schema returned by the FC. |
| Parameter | Selects one whitelisted key; choosing a key sends no write. |
| Raw value | Edits the integer stored by ESCape32. Requires a successful read first; Apply is disabled outside the selected parameter's range. |
| Scaled value | Shows the engineering value and unit for the selected raw value. |
| Read value | Reads the selected parameter. It does not claim that RAM matches persistent flash. |
| Apply to ESC RAM | Writes the local edit and uses the applied/read-back value returned by the FC. Normalized values replace the local edit. |
| Save ESC flash | Explicitly saves applied RAM changes. Enabled only for a writable, dirty session; no blind retry follows a missing acknowledgment. |
| Check result | Polls an existing operation. After a lost OPEN reply it replays exactly the same OPEN identity instead of starting a different session. |
| Close session | Requests session release. A required ESC restart remains visible; failed close acknowledgments do not imply restored motor readiness. |
| Help | Explains power sequencing, raw units, volatile changes, save semantics and recovery. |

Schema 1 raw values:

| Key | Raw range | Scaled display |
| --- | --- | --- |
| revdir | 0–1 | Boolean 0/1 |
| timing | 1–31 | Raw × 0.9375 degrees |
| freq_min | 16–48 | kHz |
| freq_max | 16–96 | kHz |
| duty_spup | 1–100 | Percent |
| duty_ramp | 0–100 | kERPM |
| duty_rate | 1–100 | Raw × 0.1 percent/ms |
| prot_temp | 0–140 | Degrees C |
| prot_curr | 0–999 | A |

## Notes

Save OK confirms completion of the CLI save operation. It does **not** verify
persistence across an ESC power cycle. Confirm persistence by restarting the
ESC, reopening an identified session and reading the values again.

The page sends bounded STATUS heartbeats while an active session is idle.
On exit it requests CLOSE and removes its handlers and subscriptions. Link loss
or missing close acknowledgment relies on the FC's owner watchdog; it must not
be interpreted as proof that the ESC has returned from CLI to normal operation.
The firmware may retain an arming inhibit until positive recovery or restart.
In the current companion core a failed transport recovery latches that inhibit
until the FC restarts. An ESC-only power cycle does not clear that FC latch;
restart both ESC and FC before normal operation when recovery is required.

BEC, input/telemetry mode, brushed mode, factory reset, arbitrary CLI commands,
motor control and firmware flashing are not exposed. The page never changes
these settings to establish a connection.

## Related

- [Implementation draft](../../../../reference/escape32-forward-programming-draft.md)
- [Suite agent task](../../../../reference/escape32/suite-agent.md)
- [Companion firmware draft](https://github.com/garfield2412/rotorflight-firmware/tree/draft/escape32-forward-programming)
- [ESCape32 configuration](https://github.com/neoxic/ESCape32/wiki/Configuration)

*Documented against the ESCape32 draft, experimental fork-local MSP contract v1
(0x5FE0). Protocol/session/form-double tests run under Lua 5.4; actual Ethos
simulator rendering and FC/ESC bench validation remain outstanding.*
