# KBiDir MSP 217 V4 validation


## Current implementation status - 2026-11-12

This section describes the current Suite state. Dated entries below preserve
implementation history and can describe rules subsequently superseded.

- Transport remains MSP217 kbidir-msp217-v4-r3: empty direct requests,96-byte
  responses,14 pairs per block, strict padding, coherent collection and bounded
  page deadline. Global queue timeouts and original shared vectors are unchanged.
- Local editor shows model/EEPROM, validated chemistry-specific cutoffs, joint RC
  endpoint diagnostics, conservative alarm capabilities and nine marked Expert
  fields. The existing Car/preset preview and one-time gearing notice remain.
- Telemetry ports follows Bluetooth and always has three rows: known missing
  connectors Not fitted, unresolved mappings Not readable. The captured KOLIBRI
  Front/Side0x2036 bytes support independent local edits, front-only Futaba,
  duplicate-active validation and unknown-code preservation. Other model layouts
  are not newly authorized by merely displaying their ports.
- Brake Off hides its dependents. Proportional brake Off additionally hides/locks
  Min/Max brake PWM; brake ramps remain available with Brake On. PWM0..100% and
  ramp100..10000ms edits follow the newer PDF, preserving captured outliers.
- RPM Control Off hides governor-specific fields in Standard and Expert mode.
  At idle up hides Max RPM. Re-enabling restores drafts; structural rebuilds keep
  Motor open and restore focus to the initiating switch/source rather than header.
- Explicit local governor changes prepare typed K-PROG helper intentions for
  Stick_PWM_min and both dead zones. Raw comparisons and percent commands stay
  separate. No read-time adjustment or actual device transaction is implemented.
- Bluetooth wording now uses one compact common hint plus independent re-enable
  labels. Only English resources were updated; other localization remains deferred.
- Simulator uses10 poles, gearing1:1, Brake Off, valid demo cutoffs and100ms brake
  ramp-down; its checksum is adjusted. Hardware reads/capture vectors are intact.
- New static K-KONFIG analysis proves PowerBox7/FrSky8 assignments and a distinct
  family250 packed three-port word, plus family-dependent byte layouts. The new
  inspector verifies the EXE hash,34 instruction anchors,15 literals,3 control
  routes,7 family-flag cases and6 name dispatches. No target execution occurred.
  USB-to-UART model/version/pointer correspondence remains unqualified, so the
  findings do not grant new Suite runtime capability.
- Current checks: Lua5.4.6 decoder/page2229, queue273, signature88 plus48 negative
  self-test gates; English tag/fit checks pass. X20PRO simulator checks cover
  port display/editing, dependency visibility, focus, brake parameters and Bluetooth
  wording. Governor helper metadata is covered by the harness, not hardware.
- Save, Load Preset and KBiDir MSP218 remain disabled. Still open: real write/preset
  contract and atomic verification, fresh G-frame endpoint capture, further model/
  EEPROM mappings, physical-radio memory/X18 visual checks and S.Port/FBUS/CRSF
  reliability/display timings. No comprehensive hardware comparison is claimed.

## Historical validation record

Local uncommitted work on `ESC_Kontronik_4.7`, 2026-11-11.
Revision **kbidir-msp217-v4-r3**: [contract](kbidir-msp217-v4-cyclic.md).

## Suite automated checks

| Check | Result |
| --- | --- |
| `lua bin/esc_kontronik_preview/verify_preview.lua` | 1411 decoder/page checks under Lua 5.4.6 |
| `lua bin/esc_kontronik_preview/verify_v4_queue.lua` | 273 actual queue/framing checks |
| `lua bin/esc_signature/verify_esc_signature.lua --self-test` | 88 checks; all 48 gate checks fail as expected with gates disabled |
| `lua bin/lua_syntax/verify_lua_syntax.lua` | All 443 runtime Lua files parse |
| `python bin/i18n/check-tags.py` | All English tags resolve |
| `python bin/i18n/check-fit.py` | X18 fits; existing 27 missing glyph metrics use W |

Shared fixture: `bin/esc_kontronik_preview/kbidir_msp217_v4_vectors.json`.
Firmware owns these bytes. r3 uses no wire version byte: signature/type/status,
retrieval ID at offset 3, metadata model at 31, block pairs at 11. Every reply has
96 bytes. Full blocks contain 14 pairs plus one zero byte. KOLIBRI blocks are
14/14/13; the maximum snapshot uses 14/14/14/14/8.
Both checkouts contain the identical final fixture, SHA-256
`41108ec4b3e4701427d920094e8ba0845cd520645358a8c320c84a8336f2a62d`.
Both Suite harnesses passed on that exact file; its hash was unchanged before/after
those runs. All 17 response payloads, including replacement metadata, were decoded.

Checks cover empty requests, 41/0/64 pairs, short final blocks, exact 96-byte lengths and every padding byte,
invalid headers/counts/offsets/reserved/status, ordered unknown and duplicate pointers,
ambiguous fields, blocks before metadata, unknown IDs, out-of-order collection,
identical and conflicting duplicates, repeated metadata, missing middle response
recovered during the next cycle, snapshot replacement without mixing IDs, and a
30-second overall deadline including pending requests. Cancellation rejects late replies.
Completed configuration remains visible beyond source freshness age.

The separate queue harness uses actual unchanged common.lua and queue.lua with both
MSP framing versions and 6/58-byte receive chunks. A served middle response is dropped;
the retry receives the next item and missing pairs arrive in the next cycle. At most
one request is pending. Timings are synthetic, not RF measurements. Global queue
retry and timeout values were not changed.

Local editor checks cover immutable captured data, independent local draft, dependencies,
chemistry cutoffs, decimals, model/EEPROM summary, disabled Save/presets/MSP218,
Reload reset, lifecycle cleanup and signed-widget limits.

## Simulator

V4-r3 menu acceptance repeated successfully on 2026-11-11 with X20PRO EU
nightly26 / ETHOS 26.2.0-RC1, 800x480. Deployed English i18n/soundpack/sensors,
restarted the WASM host on the existing radio folder, waited for full startup,
dismissed Checklist warning and verified real task.status heartbeats before entry.
No background-task, RF-model or Suite code setting was changed to bypass the guard.

The earlier alert comes from app/tool.lua's guard: no task.status received, or its
updatedAt is over three seconds old. Merely registering the task is insufficient.
The earlier log showed 16.840 seconds loading background.lua; this fresh boot took
0.359 seconds for that load and 0.536 seconds for main load/init. The exact reason
for missing heartbeats in the earlier process cannot be established retrospectively;
persistent model-task disablement was not reproduced. The intended startup now
produces 4–5 status callbacks per 1.5–1.6 second observation, running=true, sport.

Actual menu route: SYS -> Rotorflight -> Setup -> scroll -> ESC & Motors ->
ESC Prog. -> KONTRONIK. The first entry received Metadata plus three blocks,
all 96 bytes and one ID, offsets 0/14/28 and counts 14/14/13 (41 total).
A subsequent Reload independently repeated the same complete flow with ID 2.
The screen shows KOLIBRI140+LV / EEPROM 4.02, LiPo, and cell cutoff 2300 mV.
Save and Tools/Presets are grey; tapping both leaves the page unchanged, adds
zero requests and sends no MSP218. No Lua error appeared in the checked log.
Observers wrapped existing reply callbacks solely to log traffic; they did not
supply replies or alter the decoder. All temporary bus observers were detached.

Evidence is in ignored `simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/`:
`kbidir-r3-snapshot.png` (first menu entry), `kbidir-r3-verified.png` (Reload and
disabled buttons), `kbidir-r3-traffic-excerpt.log` (captured traffic before the host
500-line log rollover), and `kbidir-r3-validation.log` (final raw heartbeat log).
No images are stored in reference/validation documentation.
At that earlier menu check, runtime codec SHA-256 remained
`54f997aa0f9cdbbdbcd9e27249cf0a52abd030b0a004b320668e85dd7f9b04f5`;
global MSP queue files have no diff. X18 WASM is not cached; smallest-screen
evidence remains pixel-fit and value-column tests. These are simulator checks,
not measurements on any actual RF link.

## Firmware and real RF acceptance

Firmware r3 current-worktree host harness passed **35 tests, no skips**, including five
joint scenarios using actual C-generated replies through the current Suite reader.
Command (from firmware root):

```text
python src/test/kbidir_replay.py --simulate-integrated-head --compiler C:/Github/rotorflight-firmware/obj/zig-new/ziglang/zig.exe cc
```

Coverage includes fixed lengths/padding, length-getter purity, getter cursor advance,
probes/truncated copies consuming items, repeated/mixed batch requests near capacity,
frozen data and expiry/session replacement, private MSP218 discard protection before
false commit (including previously selected 4-way target), and legacy dispatch.
This uses extracted production C with host stubs, not physical RF.

`msp.c` was compared without normalization using Python
`subprocess.check_output(['git','show','1dbc4242fdaea50a1d4e5c1d69d9975cf6fd0484:src/main/msp/msp.c'])`
against `Path('src/main/msp/msp.c').read_bytes()`. Result: **byte equal**.
`git check-attr eol -- src/main/msp/msp.c` reports `lf`. Both SHA-256 values:
`756da0bd246903ccf9fcddbbb1fa35c215046b5e51ec4f51299eb2ecd4308047`.

An STM32F7X2 build attempt compiled `esc_sensor.c` but failed during LTO linking
(GCC 9.3.1 internal compiler error: resolution sub id not in object file). A second
external build was using the same object tree concurrently, so this is not reliable
source validation. Our duplicate build has exited. A clean, isolated full target build
is still required; no firmware was flashed.
Actual radio/FC/ESC measurements remain required before release.
No accessible radio/FC COM endpoint was available in the earlier device inventory.

| Intended link | Scenario | Block reliability and completion time |
| --- | --- | --- |
| S.Port | 41 and 64 pairs, loss and snapshot switch | Pending hardware |
| FBUS | 41 and 64 pairs, loss and snapshot switch | Pending hardware |
| CRSF | 41 and 64 pairs, loss and snapshot switch | Pending hardware |

Measure first-fragment delay, largest fragment gap, per-block duration, retries,
whole-read success and Reload-to-visible completion with sample count and link load.
Verify the V4 firmware private-discard/false-commit behavior and legacy batch
framing/cursor consumption against the baseline. No synthetic test substitutes for RF acceptance.

## ESC alarm editing switch

The page-local Edit ESC alarms switch defaults to off. Its on-transition shows an
ESC-programming notice explaining independence from Rotorflight alarms and their
usual lack of benefit for Rotorflight. Off disables all six threshold widgets and
rejects their setters; values remain in the local draft. Reload/close/disconnect
reset the switch and close the notice. No MSP request is emitted by the switch.
The page harness covers gating, notice transitions, retained drafts, reset and
notice cleanup. X20PRO simulator entry through the real Suite menu additionally
verified off -> notice -> on -> off visually; English dialog text fits without
clipping. Evidence PNGs kbidir-alarms-off, kbidir-alarms-warning, kbidir-alarms-on
and kbidir-alarms-off-again remain in ignored simulator scratch storage.

## K-PROG field rules

The extended Suite harness covers 0x2056 raw30 ->3.0Ah independently of 0x202C,
raw snapshot preservation, all three corrected cutoff pointers and limits, native
bound changes in place without cross-chemistry clamping, invalid new values versus
received out-of-range values, brake/governor transitions, and joint RC ordering and
spacing in both directions. Missing/ambiguous endpoints and cutoffs remain unavailable.
Alarm cases include exact KOLIBRI0402 and reconstructed KOSMIK0401 layouts,
legacy0400, unknown models/versions, missing/duplicate pointers, and unknown rated
current locks that local alarm opt-in cannot override. All edits emit no transport.
No Model Type preview selector or preset execution is exposed.

The manufacturer PDF was read visually (pages7–11); the APK analysis supplies the
RC cross-field conditions. The page documentation records limits, differences and
remaining model questions. No wire-format bytes or global timeout changes were made.

X20PRO simulator menu entry verified the corrected LiPo1200mV capture (outside limits),
an in-place switch to LiFePo2300mV, the RC endpoint-valid diagnostic with1101/1501/1101us,
and the alarm display3.0Ah for an explicitly synthetic 0x2056 raw30 reply override.
That override existed only in a temporary simulator observer and was detached;
original shared vectors and runtime simulator source pairs are unchanged. Current
alarm fields remain grey after opt-in while rated limits are unknown. Screenshots
kbidir-kprog-chemistry-final, kbidir-kprog-endpoints-final, kbidir-kprog-alarm-3ah and
kbidir-kprog-alarm-capability are in ignored simulator scratch storage.

## Expert settings

Nine expert-only fields are classified from actual descendants of the APK's
initially gone idcBatteryExperts/idcMotorExperts XML containers and the A6
OnClick_BtnExpert handler. The K-PROG analysis section13 lists every widget mapping
and unresolved features. Expert remains a local draft opt-in, off by default.

Harness tests cover default read-only fields, explicit opt-in, restoration of all
expert values and three cutoff targets, preservation of standard/alarm drafts,
locked/stale callbacks, no hidden edit resurrection, Reload/close/disconnect/arming
resets, missing/ambiguous data and unknown device/version locks. Expert cannot
bypass brake/governor dependencies, alarm opt-in or rated-current locks and never
queues transport or enables Save/presets. Existing snapshot/source bytes stay intact.

X20PRO simulator verified real menu entry, off/default-grey fields, explicit on,
a local low-voltage action edit Slow down -> Shut down, and off restoring Slow down
with the field grey again. Ignored scratch screenshots: kbidir-expert-default,
kbidir-expert-locked, kbidir-expert-edited and kbidir-expert-reset. No images are
added to reference documentation. No transport, MCU or RF acceptance is implied.

## Chemistry cutoff defaults

APK extractData case3/4/5 and PDF EEPROM order confirm the existing corrected
NiMH/LiPo/LiFePo pointer mapping. The supplied KOLIBRI capture contains1200mV for
LiPo; the manufacturer PDF default is3000mV. These are deliberately distinct.
The native field default and read-only Cutoff default row now use800/3000/2300mV,
including after chemistry changes and Expert opt-out. Tests cover explicit local
application without raw-data mutation or requests, restoration of the captured
value and retention of the manufacturer default. X20PRO simulator screenshot
kbidir-cutoff-default-lipo.png verifies LiPo, current1200mV and default3000mV
simultaneously. The image remains in ignored simulator scratch storage.

## Simulator demo within known limits

Runtime simulator examples are now explicitly synthetic, based on the KOLIBRI
capture: NiMH800mV, LiPo3000mV, LiFePo2300mV and input-alarm14300mV.
The checksum word is adjusted by the additive delta12200; original wire fixtures
remain byte-identical. The Suite harness verifies all41 demo pairs against the
capture plus these explicit changes, all three chemistry limits, valid RC endpoints
and no transport on chemistry changes. Actual simulator menu entry displays
Within known limits and LiPo Cell cutoff3000mV, matching Cutoff default3000mV.
Evidence kbidir-demo-known-limits.png and kbidir-demo-lipo3000.png stays in ignored
simulator scratch storage. Real received outliers remain covered by original fixtures.

## Removed redundant limit-status row

Removed the Known limits row, its cached display state, per-draft status scan and
three unused English strings. Numeric range/step checks, faithful received values,
chemistry defaults and the separate joint RC endpoint diagnostic remain unchanged.
Targeted decoder/page, real-queue, syntax and English tag/fit checks pass.

## Expert field markers

The updated task confirms exactly the existing nine expert fields. All nine
English field labels and Expert Settings * now end with a literal asterisk.
The harness resolves actual English labels, checks exactly ten marked widgets,
checks standard/alarm labels remain unmarked, and repeats the assertions with
Expert off, on and after opt-out. X20PRO screenshots kbidir-expert-markers-off,
kbidir-expert-markers-on and kbidir-expert-field-markers confirm the persistent
switch marker and battery expert labels; captures remain in ignored scratch.
No field classification, capability, reset, wire or write behavior changed.


## Default parameter set preview (2026-11-11)

Lua 5.4.6: `verify_preview.lua` passes 1535 checks, including initially unselected
explicit targets 2/3/4/5/6, all four documented masks, F5A notice/fallback,
retained snapshot/drafts, expert toggles retaining masks, dependency/device/alarm
locks, stale callbacks, reload/close/arming/disconnect resets and a disabled
Load Preset button whose callback emits no request. `verify_v4_queue.lua` passes
273 checks; signature harness with `--self-test` passes 88 checks and all 48
negative gate checks. English i18n tags and X18 fit checks pass.

X20PRO EU nightly26 WASM: entered through the real Suite menu with background
task running. Verified initial `--`, local-preview label, visible choices through F5A
(Car lies below the popup fold and is covered by the harness), disabled Load Preset and F5A missing-mask notice.
Model/EEPROM summary remained KOLIBRI140+LV / EEPROM 4.02. Local ignored evidence:
`simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/preset-initial.png`,
`preset-choices.png`, `preset-f5a.png` and `preset-simulator.log` in the same folder.
No Lua error/stack traceback was found in the captured log. No images are embedded
in reference/validation documents.

These are software/simulator checks. RF block reliability and display duration
on S.Port, FBUS and CRSF remain unmeasured. Actual preset loading remains pending
hardware qualification and approval of a separate write contract. Wire format
V4-r3 and global queue timeouts were not changed.


## Suite implementation review (2026-11-11)

Reviewed against AGENTS.md, memory/module-lifecycle guidance, the shared
field-layout pool, retained session bus behavior and the standard ESC vendor page.
The dedicated collector remains necessary: the generic vendor editor performs
legacy reads/writes and does not model cyclic V4 snapshot assembly.

Fixed two related chemistry-transition defects: a cutoff above signed native
widget bounds could reach minimum/maximum setters, and static-to-static transitions
could retain the previous chemistry's text. Numeric representability now uses one
predicate in initial build and transitions. The explicit expected-offset argument
to decodeBlock now enforces correlation; cyclic callers still accept blocks in any
order. Wire format, global timeouts and write prohibitions are unchanged.

Lua 5.4.6: 1545 decoder/page checks, 273 real-queue software checks and 88 signature
checks pass; signature self-test confirms all 48 negative gates. The number-widget
mock checks signed bounds on constructor and bound updates. Regression cases cover
overlarge U32 cutoffs, static-to-static and static-to-number transitions and expert
opt-out. All source Lua files pass syntax compilation. No i18n source or generated
locale files were changed during this review.

X20PRO EU nightly26 simulator: real-menu entry, populated model/EEPROM summary,
initially empty target, disabled Load Preset/Save and conditional F5A notice verified.
Removed developer notice rows leave no empty rows. Ignored local evidence:
`simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/review-initial.png`,
`review-choice.png`, `review-f5a.png`, `review-simulator.log`.
These checks do not establish real-radio memory stability or RF reliability.
X18 visual operation and physical ESC/model capability checks remain pending.


## Unknown application type: Forward/Backward (2026-11-11)

The central local-edit predicate always locks fwd_bckwd; received values remain
visible. No target, Car preview and Expert cannot grant permission. Rotation is
independent. Lua 5.4.6: 1637 decoder/page checks pass, including both received bit
values across open, close/reopen, Reload, cleared/Car preview and Expert, rejected
setters, unchanged raw capture and absence of transport writes. Queue harness:
273 checks pass. Changed page passes Lua syntax compilation.

X20PRO EU nightly26 WASM: real-menu entry and Motor panel show Forward/Backward
Off disabled, while Reverse Rotation is enabled. Local ignored screenshots:
`simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/forward-readonly.png` and
`forward-readonly-click.png`; log in `forward-readonly.log` in that folder.
RF/hardware qualification remains pending. Wire format, queue timeouts, Save,
Load Preset and MSP218 restrictions are unchanged; no i18n changes were made.


## Main Gear Ratio confirmation (2026-11-11)

Simulator-only pointer 0x204A is raw100 (1:1); additive checksum word is
0xFFFD1C8D. Shared original vectors remain byte-identical, SHA256
41108EC4B3E4701427D920094E8BA0845CD520645358A8C320C84A8336F2A62D,
and the hardware fixture still projects raw950 to 9.50.

Lua 5.4.6: 1681 decoder/page checks and 273 queue checks pass. Covered snapshot
loading and same/invalid values without prompting, confirmation/cancellation,
unchanged received data, no transport messages, and stale confirmation after
Reload, close/reopen, disconnect and arming. Source syntax and existing i18n tags
validate; no locale files changed. German inline copy is temporary until final i18n.

X20PRO EU nightly26 WASM: checked the full German message and both button labels,
Cancel retaining1.00 and Confirm applying2.00 only to the displayed draft.
Ignored evidence under simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/:
gear-proposal.png, gear-cancelled.png, gear-confirmed.png, gear-confirmation.log.
The initial source encoding defect was corrected to UTF-8 and deploy repeated
successfully. No Lua errors were found in the final captured log. RF/hardware
qualification remains open; no ESC or FC gearing writes were implemented.


## Revised Car preview local edit rule (2026-11-11)

Supersedes the earlier unconditional Forward/Backward lock above, following the
updated Suite task. Explicit Car6 permits only local draft editing; no selection
and targets2/3/4/5 stay locked. Expert cannot bypass the selected target. Leaving
Car retains the edited draft, while Reload/reopen clear the target and restore
received values. Rotation remains independent. Actual writes remain prohibited.

Lua 5.4.6: 1827 decoder/page checks and 273 queue checks pass. Tests exercise both
received bit values, all targets with Expert off/on, leaving/returning to Car,
locked setters, missing/ambiguous data, raw snapshot preservation and no transport
messages. Changed page passes syntax compilation. No i18n files changed.

X20PRO EU nightly26 WASM: selected Car, opened Forward/Backward, edited Off to On,
then cleared the target. On remained visible but disabled; Rotation stayed enabled.
Ignored local evidence under simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/:
car-selection.png, car-forward-enabled.png, car-forward-edit.png,
car-away-locked.png and car-preview.log. No Lua errors in the captured log.
Hardware/RF qualification is still pending; no MSP218 or FC setting writes added.


## One-time gear notice (2026-11-11)

The gear confirmation is acknowledged only by Confirm, once per page visit.
Further valid plus/minus edits apply locally without reopening the dialog.
Cancel does not acknowledge it. Reload, close, disconnect and arming reset the
acknowledgment. Preview and Expert toggles retain it. Lua 5.4.6: 1837 page/decoder
checks pass, including repeated increments/decrements, bounds after acknowledgment,
preview/Expert persistence and a new confirmation after Reload. Page syntax passes.
No i18n files, wire format, queue timeouts or write capabilities were changed.


## Telemetry ports (2026-11-12)

Implemented the captured KOLIBRI140+LV / EEPROM0402 two-port mapping only:
frei0 pointer0x2036, low byte Front and high byte Side. Raw0x0100 displays
Front Off / Side KONTRONIK. K-PROG-proven codes0..6 are selectable except
Futaba3 on Side. Duplicate active selections are rejected in both directions;
Off may be used on both. Local editing preserves the other byte, upper U32 bits,
unknown raw codes and the immutable captured snapshot. Expert/alarm switches do
not grant capabilities. Missing/ambiguous pointer, unknown EEPROM or unknown
model cannot grant editing. Unknown received codes are shown raw and read-only.

Physical documented KOSMIK HV-I three-port layouts show BEC side / LED side /
Middle as Not readable: pointer/code mappings remain open. Static K-KONFIG help
lists Off/Futaba/FrSky for Middle but supplies no EEPROM code proof. frei1 is not
assigned to Middle. Manufacturer manual links, executable hash and APK evidence
are recorded in the K-PROG analysis addendum. No complete hardware model sweep
is claimed or required. Other model spellings/layouts and modern codes remain open.

Executed with Lua5.4.6:1927 decoder/page checks,273 real-queue software checks,
88 signature checks plus48 negative self-test gates. Changed page syntax and
English i18n tags validate. Existing locale files and shared V4-r3 vectors are
unchanged. No write messages are generated; Save/MSP218/global timeouts unchanged.

X20PRO EU nightly26 WASM: entered through the Suite menu, opened Telemetry ports,
verified Front Off / Side KONTRONIK, changed Front to Graupner and verified Side
remained KONTRONIK. Ignored local screenshots under
simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/: telemetry-list.png,
telemetry-reference.png, telemetry-front-edited.png; log telemetry-ports.log.
RF measurements and actual ESC programming remain outside this software result.


## Governor field visibility (2026-11-12)

RPM Control Off hides its source, max RPM, startup, gain and resistance rows.
Re-enabling restores retained draft values. A state transition schedules one
form rebuild and keeps the Motor panel open; idle wakeups do not rebuild it.
Hidden callbacks remain gated/detached. Missing RPM Control does not infer Off.
Lua5.4.6:1934 decoder/page checks and273 queue checks pass, including visibility,
retained40000 RPM target, rejected hidden callback and no transport messages.
No localization or write capability changed. This final visibility adjustment
has not yet received an additional simulator visual check.


## Brake dependent visibility (2026-11-12)

The same dependency-based visibility rule now hides Proportional brake when
Brake is Off. On restores the retained draft; Expert cannot reveal the hidden
child, and stale hidden callbacks cannot change it. RC Brake Position remains
independent and visible for joint endpoint validation. Lua5.4.6:1943 page/decoder
checks and273 queue checks pass; page syntax passes. X20PRO EU nightly26 simulator
verified Proportional brake visible with Brake On and absent after selecting Off;
Motor panel stays open. Local ignored screenshots: brake-fields-before.png and
brake-fields-hidden.png in simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/.
No writes or localization changes introduced.


## Max RPM visibility in At idle up mode (2026-11-12)

Matches K-PROG MainActivity.updateUI lines2370-2378: Max RPM is hidden when
how_adj_max_rpm=0, independent of Expert. Switching to stored target mode restores
the retained local value; other governor fields remain available with RPM Control
On. The existing setter gate continues to reject hidden edits. A genuine source
transition schedules a form rebuild with Motor open. Lua5.4.6:1982 decoder/page
checks pass, including Expert off/on, retained45000 RPM and stale callback rejection.
Page syntax validates. No additional simulator visual check performed for this
change. No write, protocol, timeout or localization changes.


## Focus after visibility rebuild (2026-11-12)

The form rebuild now records the initiating Brake/RPM Control/RPM-source key,
opens Motor and focuses the replacement control after field construction and
state updates. ETHOS scrolls that control into view, avoiding the page-header
jump; exact pixel offset is not saved. Invalidation clears the pending focus.
Lua5.4.6:1985 decoder/page checks and273 queue checks pass. X20PRO EU nightly26
simulator confirms RPM Control stays visible/focused after switching Off.
Ignored evidence: focus-before.png and focus-rpm-off.png under
simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/. No i18n or transport changes.


## Compact Bluetooth wording (2026-11-12)

The English Bluetooth section now shows one full-width compact hint,
Bluetooth turns off at motor start, followed by Re-enable with button and
Re-enable at motor stop. The original independent bit18/19 controls are unchanged.
Updated English source/generated locale only; other locales remain deferred.
Lua5.4.6:1992 decoder/page checks pass, including one shared hint and independent
local setters without transport. English tag and X18 fit checks pass.
X20PRO EU nightly26 simulator visually confirms all three lines fit without
truncation. Ignored local screenshot: bluetooth-wording.png under
simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/. No writes added.


## Additional brake parameters (2026-11-12)

Added Min/Max brake PWM (0x3040/0x3042, K-PROG percentage conversion) and brake
ramp up/down (0x200E/0x203E, ms). PDF2026-04-01 pages8,10,11 were rendered and
visually checked: PWM0..100% and ramps100..10000ms with100ms steps. APK differences
(PWM2..100%, ramps up to60000ms) are recorded in the analysis/page documentation.
Received values are preserved, including KOLIBRI105ms off-raster ramp-down.
Simulator-only ramp-down now100ms, checksum0xFFFD1C8F; original vectors unchanged.

All four controls are standard Brake children, hidden with Brake Off and locked
by the Helicopter mask. Proportional brake Off does not add another condition.
Local edits preserve raw capture, min/max edits cannot cross, missing/ambiguous
pointers remain unavailable and stale hidden setters cannot mutate the draft.

Executed Lua5.4.6:2036 decoder/page checks,273 queue checks,88 signature checks plus
48 negative gates. Cases include KOLIBRI capture conversion, KOSMIK0/4096 PWM
boundaries, both ramp mappings, bounds/raster, crossed min/max, retained drafts,
preview locks, missing/duplicate pointers and no transport. Both changed modules
pass syntax checks; existing i18n tags pass. No locale resources changed in this task.

X20PRO EU nightly26: real menu entry, Brake default Off, enabling Brake reveals
Min2%, Max99%, ramp up500ms, ramp down100ms. Screenshot brake-parameters.png under
simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/ (ignored). Firmware/RF and real
programming qualification remain open. MSP217 V4-r3/global timeouts unchanged;
Save, presets and MSP218 stay disabled. Changes remain local and uncommitted.


## Proportional brake PWM visibility (2026-11-12)

Explicit Suite extension over the APK: Min/Max brake PWM require both Brake and
Proportional brake On. Proportional Off hides both rows and rejects their setters;
Expert cannot bypass. Re-enabling restores drafts. Brake ramps depend only on
Brake. Rebuild focus returns to the proportional switch. Lua5.4.6:2042 page/decoder
and273 queue checks pass, including hidden stale setters, retained min40/max60,
Expert restrictions, independent ramps and no transport. X20PRO EU nightly26
simulator confirms the two PWM rows absent with Proportional Off and present
with On; focus stays at the switch. Local ignored screenshots proportional-off.png
and proportional-on.png under simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/.
No localization, wire-format, timeout or write capability changes.


## Local governor helper intentions (2026-11-12)

Inspected MainActivity.OnClick_CBRPMcontrol/adjustData and Util.between; accepted
ranges are inclusive. The local planner conditionally proposes three helper
commands in APK order: Stick_PWM_min0x3020 percent33/1, lower dead zone0x201C
raw1365/327, upper dead zone0x201E raw0/204 for Governor On/Off. Raw acceptance
ranges remain separate from command values/units. It emits no MSP message and
never fabricates raw readback for percentage commands.

The page invokes preparation only after an accepted rpm_ctl change, recomputing
against the original capture on each toggle. Missing/ambiguous required inputs
mark the whole plan unavailable. Initial/repeated reads do not trigger adjustments,
even when the received helpers mismatch K-PROG's expectations. Local draft metadata
is discarded on Reload, close, disconnect and arming; masks/locked callbacks
cannot change it. Actual firmware transaction, conversions and verification are
not implemented: they remain gated by the future write contract and hardware tests.

Executed Lua5.4.6:2219 decoder/page checks. Covered inclusive boundaries and
single outside-range cases for both modes, exact ordered proposals, percent/raw
separation, absent/duplicate pointers, toggle/reversion, rejected setter, read-time
outliers, missing-plan status and all lifecycle resets without writes. Queue273,
signature88 plus48 negative gate self-tests pass. Both changed modules pass syntax
compilation. No UI widgets or locale resources changed for this internal feature;
no new simulator visual check needed. MSP217/global timeouts/Save/MSP218 unchanged.


## Consistent three-row telemetry section (2026-11-12)

Always render three port rows. Known absent ports use Not fitted; existing but
unresolved ports use Not readable; unknown models use neutral Port1/2/3 labels
without asserting absence. No additional model encoding or edit permission.
Lua5.4.6:2229 decoder/page checks,273 queue checks; page syntax and diff whitespace
checks pass. Covered one/two/three-port and unknown models, absence vs unresolved
and static-only placeholder rows. X20PRO EU nightly26 simulator confirms reference
Front Off / Side KONTRONIK / Middle Not fitted; screenshot telemetry-three-rows.png
in simulators/X20PRO_EU@nightly26/scripts/rfsuite.user/ (ignored). Existing port
setters and write restrictions unchanged. No localization files changed.
