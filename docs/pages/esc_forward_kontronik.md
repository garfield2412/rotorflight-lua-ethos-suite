---
title: KONTRONIK
sidebar_label: KONTRONIK
---

# KONTRONIK

Reads a KONTRONIK BiDir ESC configuration through MSP217 and allows page-local edits.
Save is disabled: opening, reloading and editing never change the ESC or send MSP218.
Source: `src/rfsuite/app/pages/esc_forward_kontronik.lua`.

## Where to find it

*Configuration* â†’ *Setup* â†’ *ESC & Motors* â†’ *ESC Tools* (ESC Prog.) â†’ *KONTRONIK*.

The tile has no ESC protocol filter. It requires an active FC connection and declares
`lockedWhileArmed = true`; entry is blocked while armed. Parent menu availability applies.
On an incompatible ESC the page shows an incompatible reply instead of guessed values.

## Reading and availability

Reload starts a V4-r3 cyclic collection with empty direct MSP217 requests. The page
publishes configuration only after every pair has arrived. Every reply has exactly
96 payload bytes with checked zero padding. Blocks contain up to fourteen pairs and may arrive in any order. There is no on-wire version byte. The captured
41 pairs use 14/14/13 blocks; the 64-pair limit uses 14/14/14/14/8. A missing block is collected
on a later cycle.
Save and Tools are disabled. Received, unambiguous settings use normal choice/number
controls. Load Preset is visible but disabled. There are no preset execution, EEPROM/reboot commands or MSP218 write requests.
Only one page read may be pending at once. Values start as `--`, never local examples.

| Result | Display |
| --- | --- |
| Valid snapshot with data | Model / EEPROM summary; available fields are populated. |
| Valid empty snapshot or unavailable source data | Data unavailable; unavailable fields show `--`. |
| MSP error response | MSP error. |
| Overall collection deadline reached | Read timed out. |
| Wrong family/type or malformed payload | Incompatible reply. |
| Other queue/transport failure | Read failed. |
| Connection lost | Link unavailable; previous values are discarded. |

Model and parameters have independent availability **at capture time**. EEPROM version
requires available parameters. The firmware freezes one coherent snapshot; new E-frames
cannot change an in-progress read. Repeated identical metadata preserves collected
blocks; a new retrieval ID replaces the partial collection. Conflicting duplicates fail
the read. The page allows at most 30 seconds from the first enqueue, including retries
and snapshot changes. Global MSP timeouts remain unchanged. Reload may collect the
same frozen snapshot again until its 30-second firmware lifetime expires.

A completed configuration remains visible until Reload, disconnect, arming,
transport/handshake reset or leaving the page. It does not become empty because RF
transfer took more than two seconds. The two-second source freshness rule applies only
when the firmware captures data. Under ESC Live Status, **Param. age at capture** and
**Model age at capture** report those source ages in ms; **Read duration** separately
reports local elapsed read time in seconds, including queue wait, retries and restarts.
This is a captured configuration, not a claim of current live telemetry. Reopening
starts another read. Long model names are shortened for display only.

## Simulator

The simulator uses a synthetic KOLIBRI140+LV demo based on the capture: EEPROM
0402, 41 parameter pairs, BEC 5500 mV, ten poles, Brake Off and ESC gear ratio 1:1 (raw 100 at `0x204A`). Its cutoff
examples are NiMH 800 mV, LiPo 3000 mV and LiFePo 2300 mV; the minimum-input
alarm example is 14300 mV. These demo values are within known limits. The checksum
word is adjusted by the additive delta; this is not an authenticated ESC read.
Shared original Firmware/Suite capture vectors remain unchanged. It uses the same cyclic metadata plus three
blocks as a real read. Captured values remain visible after completion on
both simulator and radio; source freshness is evaluated only at capture. Live
telemetry/status rows outside MSP217 still show `--`.

## Local editing

The summary directly below the header shows the ESC model and available EEPROM
version, for example **KOLIBRI140+LV / EEPROM 4.02**. The protocol supplies no separately
identified ESC firmware version; the EEPROM version is therefore labelled explicitly.
The summary replaces the former technical snapshot labels.

Edits belong to an independent draft; the received raw snapshot is unchanged. Reload,
leaving the page, disconnect, arming and transport/handshake reset discard the draft.
No field setter queues transport requests. Save and preset execution remain disabled.
Missing/ambiguous values remain `--`. Current values outside provisional UI ranges are
preserved without clamping; those ranges do not authorize future ESC writes.

Proportional brake follows Brake. Governor source, maximum RPM, startup, gain and
resistance follow RPM Control; maximum RPM also requires stored target mode. Disabled
setters reject edits. Chemistry selection uses separate captured/local cutoff values;
switching does not copy one chemistry's threshold into another. Alarm and Bluetooth
settings remain local. **Edit ESC alarms** defaults to off and gates the alarm
threshold controls. Switching it on shows a notice that these alarms are programmed
on the ESC, are independent of Rotorflight alarms and are usually not useful with
Rotorflight. Switching it off retains the draft values; Reload and leaving the page
reset it. This switch only unlocks local editing; it does not enable or disable ESC
hardware alarms while Save is unavailable. Live/status measurements stay static.
Draft widget callbacks reuse the standard field-layout pool and detach on close.

## Fields

Fields without a recognized, unique pointer show `--`. Duplicate pointers are ambiguous,
even if both values match. All unknown and duplicate pairs remain in the decoded ordered
raw snapshot. BitStatus ambiguity also hides every field derived from that word.

| Field | Meaning / receive representation |
| --- | --- |
| Battery Type | Chemistry from BitStatus bits 2â€“3: NiCd/NiMH, LiPo or LiFePo. |
| Low voltage action | Slow down or shutdown, BitStatus bit 8. |
| Cell cutoff | NiMH `0x2008`, LiPo `0x200A`, LiFePo `0x200C`, in mV. |
| Discharge Limit | Raw value /10 Ah; zero means off. |
| Reverse Rotation | BitStatus bit 10. |
| Forward/Backward | BitStatus bit 13; local editing requires explicit Car preview. |
| Pole Count | Actual received pole count, not a selection index. |
| Main Gear Ratio 1: | Raw ratio /100. |
| Brake | BitStatus bit 0. |
| Proportional brake | BitStatus bit 1. |
| RPM Control | ESC speed control, BitStatus bit 5. |
| Max RPM source | Idle-up or stored target, BitStatus bit 6. |
| Max RPM | Full U32 maximum speed. |
| Startup Time | Received milliseconds /1000 seconds. |
| P-Gain | Received governor gain. |
| Motor resistance | Received compensation in mOhm. |
| PWM minimum | `floor((raw+20)*100/4096)` percent. |
| Slew Rate Up | Received milliseconds. |
| Slew Rate Down | Received milliseconds. |
| Smooth idle up | BitStatus bit 14. |
| Alternate Startup | BitStatus bit 17. |
| Startup current limit | Received amperes. |
| Actual Impulse Length | `--`; this measurement is not part of the configuration snapshot. |
| Off Position | Received throttle endpoint in microseconds. |
| Max Position | Received throttle endpoint in microseconds. |
| Brake Position | Received brake endpoint in microseconds. |
| BEC Voltage | Received millivolts. |
| Bluetooth: Re-enable with button | BitStatus bit 18. |
| Bluetooth: Re-enable at motor stop | BitStatus bit 19. |
| ESC model | Independently available ASCII identification. |
| EEPROM version | Four raw BCD hexadecimal digits, distinct from payload version. |
| Param. age at capture | Parameter source age at the frozen capture, in milliseconds. |
| Model age at capture | Model source age at the frozen capture, in milliseconds. |
| Read duration | Local elapsed time until the whole read completed, in seconds. |
| Programming / operating state | `--`; not supplied by MSP 217. |
| Events, live measurements and statistics | `--` on this page; ordinary live telemetry continues through the existing sensor path. |
| Alarm max discharge | `0x2056` raw /10 Ah; one decimal, independent of Discharge Limit. |
| Min. input voltage | Received mV threshold. |
| Alarm max motor current | Received A threshold. |
| Alarm max ESC temperature | Received degrees Celsius. |
| Alarm max BEC temperature | Received degrees Celsius. |
| Alarm max BEC current | Received mA threshold. |

Groups remain Basic, Motor, Remote Control, Bluetooth, ESC Live Status and Alarm.
Brake Off hides Proportional brake; switching On restores its retained local
value. The separate RC Brake Position remains visible for endpoint validation.
With RPM Control Off, its
source, maximum RPM, startup, gain and resistance fields are hidden; switching On
restores their retained local values. No
write permission or model-specific programming capability is inferred from their presence.
ESC alarm thresholds do not change Rotorflight or Suite alert settings.

## Related

- [Approved KBiDir MSP 217 contract](../reference/kbidir-msp217-v4-cyclic.md)
- [K-PROG receive representations and limitations](../reference/kontronik-kprog-1.5-analysis.md)

*Checked against local branch ESC_Kontronik_4.7, Lua 5.4.6 and X20PRO EU nightly26
WASM simulator on 2026-11-11. RF/hardware acceptance is pending; no released-firmware
compatibility is asserted.*

## K-PROG field behavior and known limits

Source: KONTRONIK Bluetooth Module Serial Protocol, 2026-04-01, pages 7–11,
checked visually against the supplied `KONTRONIK_Bluetooth_Doc_20260401_BW.pdf`.
APK behavior is documented in the related K-PROG analysis. This page uses a local
draft; its limits do not authorize ESC programming.

The discharge alarm is distinct from the capacity limiter: raw `30` at `0x2056`
means **3.0 Ah**. Both use independent tenths-of-Ah ticks. Raw snapshot pairs stay
unchanged. The cutoff mapping is corrected to NiMH/LiPo/LiFePo pointers
`0x2008/0x200A/0x200C`; `0x200E` is the brake slew parameter, not a cell cutoff.
The original KOLIBRI capture contains a LiPo value of 1200 mV, outside the documented
range. Real reads preserve such values; the synthetic simulator demo uses 3000 mV.

| Local field | PDF-based draft bounds/resolution |
| --- | --- |
| NiMH cutoff | 700–1200 mV, 100 mV |
| LiPo cutoff | 2700–3500 mV, 100 mV |
| LiFePo cutoff | 1800–2600 mV, 100 mV |
| Gear ratio | 1.00–655.35, 0.01 |
| Governor startup | 4–60 s, 1 s (received milliseconds remain visible) |
| P gain | 0–10 |
| Motor resistance | 1–1000 mOhm |
| Minimum PWM | 2–100 percent |
| PWM rise/fall | 200–60000 ms, 100 ms |
| Startup current | 10–100 A |
| BEC target | 5000–8000 mV, 100 mV |
| Minimum-input alarm | 12000–60000 mV, 100 mV |
| ESC/BEC temperature alarms | 20–100 Celsius |
| Discharge alarm | 0–100.0 Ah, 0.1 Ah |

Each chemistry retains its own received and edited cutoff. A chemistry transition
changes its target, bounds and step together; missing/ambiguous targets stay `--`.
Received values outside the bounds remain visible. Values exceeding the native
signed number-widget range use static text, including after chemistry changes.
The original received value can
be restored, but a different new edit outside the bounds or step is rejected.
Braking/governor transitions preserve disabled child values and never
write the APK's internal governor adjustments. Explicit RPM Control changes
prepare local typed helper intentions only, as described below.

**RC endpoint check** evaluates Off, Max and Brake jointly. Off and Max must be
500–2500 us and at least 100 us apart. For increasing pulses Off must be at least
Brake; for decreasing pulses Off must be at most Brake, even with brake off.
With brake on, Brake must be 500–2500 us and at least 200 us from Max in the same
direction. Missing/ambiguous data gives `--`. Invalid combinations are reported
while the endpoint controls stay editable for correction. Current pulse stays a
separate unavailable measurement; no Set Off/Max/Brake capture actions are offered.

The alarm opt-in cannot override capability locks. Local editing of capacity,
minimum voltage and temperature alarms currently requires the exact captured
KOLIBRI140+LV / EEPROM 0402 / 41-pair layout or KOSMIK200+HV / EEPROM 0401 /
39-pair layout, matching the unique EEPROM-version pointer, layout markers,
checksum pointer and individual parameter pointer. Legacy 0400, unknown versions,
unknown models and ambiguous metadata cannot unlock alarms. Received fields stay
visible; unsupported or unresolved fields remain locked. The reconstructed KOSMIK
UART fixture is provenance-marked and is not an independent raw-byte capture.

Motor- and BEC-current alarm edits remain locked: the PDF requires model-specific
I_NENN/IB_MAX limits, absent from MSP217. A JIVE name alone neither grants BEC
features nor proves a universal BEC-current restriction; APK identification disables
that alarm but has override paths. No broad name-substring capability is inferred.

Open model/version questions: APK cutoff limits (LiPo 2800–4000, LiFePo 2000–3500),
P gain 2–20, ramps 100–30000, resistance 2–100 and minimum-input alarm 700–4400
conflict with the newer PDF. Real supported ESC versions need confirmation before
writes. The limiter retains zero=off from the APK despite PDF's raw minimum 1.
Maximum RPM has no universal PDF limit; its existing broad local range is provisional.
BEC capability and limits for other variants, JIVE details, KOLIBRI/UHV telemetry
outputs and expert-mode features are unresolved and are not enabled by inference.

Model Type denotes a command loading a whole default set. Neither model name nor
snapshot reveals the last preset. **Default parameter set** therefore starts at
`--` (no target selected). The selection previews field availability using explicit targets
Glider (2), Powered aircraft (3), Helicopter (4), F5A (5) and Car (6).

| Preview | Additional disabled controls |
| --- | --- |
| Glider | ESC governor group; Forward/Backward |
| Powered aircraft | Forward/Backward |
| Helicopter | Brake group; PWM rise/fall; Forward/Backward; Brake Position |
| Car | ESC governor group |
| None / F5A | No additional mask |

Forward/Backward shows its received or locally edited value. Local changes require
explicit **Car (6)** preview and the ordinary edit checks. With `--` or any other
preview (including F5A), the field and setter remain locked. Expert cannot bypass
that rule. Leaving Car preserves the draft while locking the field; returning to
Car allows editing it again. Reload/reopening resets the selector to `--` and the
value to the new received snapshot. Reverse Rotation keeps its separate rules.
Car grants no write authorization and does not establish the active ESC preset;
real Car writes require independent qualification under a future write contract.

F5A shows that no K-PROG field mask is documented. All ordinary capability,
missing/ambiguous-pointer, dependency, arming, expert and alarm locks still apply.
Changing or clearing the target preserves the snapshot and all draft values;
expert toggles retain the selected mask (expert opt-out still resets expert edits).
Reload, close, disconnect and arming clear the target. No preset is inferred,
no factory values are simulated, and **Load Preset** remains visibly disabled.
Save remains disabled; none of these actions queues a request or MSP218.

Actual loading awaits a positive hardware test and approved write contract.
The future workflow must confirm full replacement, ask the ESC to load its defaults
(type-5 command, address 0), verify completion, reread all parameters/endpoints,
discard the old draft after confirmed execution and guide the user to RC endpoint
setup. The current page implements none of those write operations.

## Expert settings

The page-local `Expert Settings *` switch starts off. The literal `*` marks
all nine expert field labels and remains on the switch in both states. Standard
fields, including the discharge alarm, stay unmarked. Expert controls remain
visible but read-only: low-voltage action, cell cutoff, discharge limiter,
minimum PWM, PWM rise/fall, soft start, alternate startup and startup current.
The exact APK widget evidence is recorded in the K-PROG analysis, section13.
Ordinary controls, including chemistry selection and the separate ESC alarm
opt-in, retain their existing behavior.

Explicitly enabling the switch only unlocks local draft controls for a recognized
captured device/layout. It cannot bypass missing/ambiguous pointers, brake/governor
rules, arming/link state, alarm opt-in or unknown alarm current limits. No preset
mask or device permission is reset. Unknown layouts keep the switch unavailable.

Switching off restores every expert-only value and all three chemistry cutoff
drafts from the received snapshot. Standard-field edits, the selected chemistry
and separate alarm draft/opt-in remain intact. Re-enabling cannot resurrect hidden
edits. Reload, close, disconnect and arming reset expert mode; locked/stale setters
are ignored. This switch sends no transport request and never enables Save,
Load Preset or MSP218. Governor helper intentions are prepared locally as described
below; real execution and further telemetry-output mappings remain unavailable.

### Cell cutoff: received value versus default

The documented per-cell defaults are NiMH **800 mV**, LiPo **3000 mV** and
LiFePo **2300 mV**. The read-only Cutoff default row shows the selected chemistry's
default; the number field's native reset/default uses that same value. Switching
chemistry alone preserves its captured/local cutoff and does not load a preset.
In the original KOLIBRI capture LiPo contains 1200 mV; a real read preserves it
until explicitly edited. The adjusted simulator
example starts with 3000 mV. Applying the 3000 mV default
changes only the local draft. Expert opt-out restores captured values, whereas
factory defaults remain 800/3000/2300. No snapshot or shared fixture is modified.


## Main Gear Ratio confirmation

The simulator-only ESC ratio is **1:1**. Hardware reads and the original shared
capture retain their received values (the KOLIBRI capture has raw 950 = 9.50).
The first valid different ratio opens a confirmation dialog before updating the
local draft. Confirm applies the proposed ESC draft ratio and acknowledges the
notice for this page visit; further plus/minus edits do not prompt again. Cancel
retains the previous value and requires confirmation on the next attempt. Reading a snapshot, choosing the same value and invalid edits do not prompt.
The dialog explains that Rotorflight calculates rotor speed using the ratio
configured in the flight controller. Neither ESC nor FC gearing is written.
Reload, close, disconnect and arming reset acknowledgment, discard pending confirmation and ignore stale
actions. The dialog and its Confirm/Cancel buttons use English; localization is deferred
to the final i18n pass.


## Telemetry ports

The **Telemetry ports** section follows **Bluetooth interface** and separates physical connector evidence from
EEPROM decoding. English labels are temporary until the final localization pass.

For the captured **KOLIBRI140+LV / EEPROM0402 /41-pair** layout, **Front** reads
bits0..7 and **Side** bits8..15 of the unique pointer0x2036 (`frei0`). The captured
word0x0100 therefore means Front **Off**, Side **KONTRONIK**. Choices use only
K-PROG-proven raw codes: Off0, KONTRONIK1, Graupner2, Futaba3 (front only),
Multiplex4, Mikado5 and Jeti6. Duplicate active protocols are rejected in both
setters; multiple Off ports are permitted. Changes affect only the local draft,
retain the other byte and upper U32 bits, and never alter the captured snapshot.
Expert and alarm switches grant no additional port capabilities.

Unknown codes are shown as `Raw 0xNN` without an editable selection and remain
unchanged when the other port is edited. Missing/ambiguous pointers, unsupported
EEPROM/layouts and unknown models cannot grant editing. An unavailable mapping
shows **Not readable**. Reload/disconnect/arming/close follow the normal draft
cleanup rules. Save remains disabled and no MSP218 is sent.

Documented KOLIBRI140 LV-I/HV-I models can show Front/Side; documented60/90 LV-I
and90 HV-I can show Front. Their wire-name/version associations require captures
before editing is enabled. Futaba is never offered on Side.
Documented KOSMIK HV-I variants (170/210, COOL170/210/250 and DuoCOOL/WaterCOOL300)
show **BEC side**, **LED side**, **Middle** without editable choices. Middle is
physically documented for Off/Futaba/FrSky; its raw pointer/codes are unresolved.
The old KOSMIK200+HV capture does not establish this newer integrated layout.
`frei1`0x2038 is not assigned to Middle. Additional model spellings and modern
PowerBox/FrSky codes await specific evidence. A complete hardware model comparison
is not required for these evidence-limited controls.

Sources and static K-KONFIG help provenance are recorded in section9 and the
telemetry evidence addendum of the K-PROG analysis.


RPM Off hides the five governor-specific rows in both Standard and Expert mode.
The six motor-expert fields (minimum PWM, PWM rise/fall, soft start, alternate
startup and startup current) are outside K-PROG's governor group and retain their
Expert/model capability rules. No additional RPM-off dependency is inferred.


With RPM Control On and source **At idle up**, Max RPM is hidden in both
Standard and Expert mode. Selecting **Stored in EEPROM** restores the retained
local Max RPM value; other governor fields stay subject to their usual rules.


When Brake, RPM Control or its target source changes field visibility, the page
keeps Motor expanded and restores focus to the triggering control. ETHOS scrolls
that field into view instead of returning the viewport to the page header.


Bluetooth interface shows the compact shared hint **Bluetooth turns off at motor
start**, followed by **Re-enable with button** and **Re-enable at motor stop**.
Each option controls its own received status bit; they remain independent.


## Additional brake controls

With Brake On, Motor shows four additional standard local controls:

| Control | Received pointer / display | New local edits |
| --- | --- | --- |
| Min brake PWM | 0x3040, raw0..4096 converted to percent | 0..100 percent, whole percent |
| Max brake PWM | 0x3042, raw0..4096 converted to percent | 0..100 percent, whole percent |
| Brake ramp up | 0x200E, milliseconds | 100..10000ms, step100ms |
| Brake ramp down | 0x203E, milliseconds | 100..10000ms, step100ms |

PWM display follows K-PROG floor((raw+20)*100/4096). The captured KOLIBRI values
are2%,99%,500ms and105ms. Received outliers/off-raster values remain visible;
new edits follow the2026-04-01 PDF, and an original captured value can be restored.
The simulator-only ramp-down sample uses100ms with adjusted checksum. Shared
capture bytes remain unchanged. New min/max PWM edits cannot cross each other.

Brake Off hides all four controls while preserving their drafts, and re-enabling
restores them with the existing focus handling. Proportional brake Off additionally hides and locks Min/Max brake PWM while
retaining their draft values. The brake ramps remain available with Brake On.
This is an intentional Suite rule based on the PDF meaning; the older K-PROG UI
does not add that lock. Expert cannot bypass it and is not required for editing. Helicopter preview locks the entire brake group;
missing/ambiguous pointers show --. No setters send transport messages.

Older K-PROG clamps brake PWM to2..100% and ramps to100..60000ms; those differ
from the newer manufacturer PDF used for these local bounds. Real programming
and firmware-specific qualification remain outside this read-only transport.


## Internal governor follow-up intentions

An explicit, accepted local RPM Control change now prepares the same conditional
helper values as K-PROG adjustData. Reading/reloading does not prepare or execute
adjustments. The captured raw snapshot is never modified.

| Governor | Pointer / helper | Accepted captured raw range | Proposed command value |
| --- | --- | --- | --- |
| On | 0x3020 Stick_PWM_min | 1280..1536 | 33 percent |
| On | 0x201C lower dead zone | 1280..1536 | 1365 raw |
| On | 0x201E upper dead zone | 0 | 0 raw |
| Off | 0x3020 Stick_PWM_min | 40..400 | 1 percent |
| Off | 0x201C lower dead zone | 1..500 | 327 raw |
| Off | 0x201E upper dead zone | 1..320 | 204 raw |

Only mismatches are proposed. Command units stay explicit:33/1 are percentage
commands, not received EEPROM ticks. The page does not guess their resulting raw
readback. Each toggle recomputes the final intentions against the original capture;
returning to a compatible captured mode removes obsolete proposals. Missing or
ambiguous required inputs mark the entire preparation unavailable, never partially
complete. A rejected/locked RPM setter does not change the intentions.

These are internal local draft metadata, not new editable helper fields or transport
messages. Reload, close, disconnect and arming discard them with the draft. Actual
execution, percent conversion and atomic verification need the separately approved
firmware write contract and hardware qualification. Save/MSP218 remain disabled.


Telemetry ports always shows three rows. Known physical ports keep their model-
specific names and existing capability checks. A documented absent port shows
**Not fitted** without an editable control (for example Middle on the reference
KOLIBRI). An existing port with unresolved encoding shows **Not readable**.
Unknown models use neutral **Port 1/Port 2/Port 3** rows, all Not readable; absence
is never inferred for an unknown model. No additional mapping or edit permission
is granted by displaying the third row.
