# KBiDir MSP 217 V4 validation


## Current implementation status - 2026-11-12

This section describes the current Suite state; dated entries below record the
implementation history and can describe rules subsequently superseded.

- MSP217 uses kbidir-msp217-v4-r3: direct empty requests, exactly96 response
  bytes, at most14 pairs per block and strict zero padding. The collector has
  one pending request, recovers missing blocks on later cycles, checks duplicates
  and publishes only a complete coherent snapshot. Unknown and duplicate pointers
  retain their order; ambiguous projected fields remain unavailable.
- The page shows ESC model/EEPROM version and permits validated local edits.
  Chemistry-specific cutoffs, brake/governor dependencies, joint RC endpoint
  diagnostics, conservative device/alarm capabilities and nine marked expert
  controls are implemented. Expert opt-out restores captured expert values.
- Default parameter set starts unselected. Documented masks apply locally;
  F5A reports its missing mask. Only explicit Car6 permits local Forward/Backward
  edits. Other targets lock the field without losing the draft. Rotation is separate.
- The first Main Gear Ratio change requires confirmation; Confirm acknowledges
  the English notice for subsequent edits in that page visit. Cancel keeps the
  previous value. Reload/close/disconnect/arming reset acknowledgment and reject
  stale confirmations. Neither ESC nor FC gearing is written.
- Simulator-only examples use10 poles and ESC gearing1:1, with corrected checksum
  and cutoffs within known limits. Original shared firmware/capture vectors are
  unchanged. Save and Load Preset remain disabled; the Suite sends no KBiDir MSP218.
  Global queue timeouts and V4-r3 wire format remain unchanged.
- Current executed tests: Lua5.4.6 decoder/page1837, real-queue software273,
  signature88 plus48 negative self-test gates; English tag/fit checks pass.
  Prior X20PRO simulator checks verified the actual menu path, populated capture,
  disabled actions, Car editing/locking and gear confirmation/cancellation.
  The final one-time gear acknowledgment change is covered by the page harness.
- Still open: S.Port/FBUS/CRSF block reliability and end-to-end display timings,
  physical-radio memory stability, X18 visual verification, model/EEPROM capability
  questions and any future write/preset contract. Simulator/software tests do not
  qualify those hardware paths. Further localization is deferred; existing English
  resources are included without adding other locales in this commit.

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
