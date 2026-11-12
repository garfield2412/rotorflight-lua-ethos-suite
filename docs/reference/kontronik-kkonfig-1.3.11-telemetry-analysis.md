# K-KONFIG 1.3.11: static telemetry-port analysis

Status: 2026-11-12. Static Windows executable evidence only. The executable was
not launched; no USB/radio/ESC connection or device writes were performed. No new
Suite model permissions, codecs or firmware test vectors are introduced here.

## Source and reproducibility

Examined `C:/Program Files (x86)/Kontronik/KKonfig_V1.3.11.exe`,3432960 bytes,
x86 native PE, preferred image base0x00400000. SHA256:
`59675dd9b603ad2b86b7435965f5f9f5ac7331ae8eaf7748cf8d33dd53fed5ee`.
Addresses below are preferred virtual addresses, not file offsets or UART pointers.

Read-only evidence extractor:
`bin/kontronik_konfig_inspect/inspect_telemetry.py`.
Dependencies: Python, pefile, capstone. Run:

```powershell
python bin/kontronik_konfig_inspect/inspect_telemetry.py --output .codex-tmp/kkonfig-telemetry-evidence.json
```

The extractor checks the exact executable hash,34 instruction anchors,15 UTF-16
literals,3 WM_COMMAND dispatch entries,7 numeric family-flag cases and6 family-name
dispatch entries, then disassembles the relevant ranges
with imported API names. It neither loads the target as a library nor executes it.
The JSON is reproducible local scratch evidence; no third-party binary is committed.
A different binary deliberately fails instead of reusing stale addresses. The
small family-decision fragment is evaluated as integer/flag operations in Python,
without native execution or calls; unknown instructions are rejected.

## What the selection handlers actually do

The controls are created at runtime. Their Win32 IDs and dispatch entries are:

| Control | Label ID | Handler |
| --- | --- | --- |
| 0x07FB | 243, normally Telemetry front | 0x0040CC20, through0x00402F8C |
| 0x07FC | 244, normally Telemetry side | 0x0040D2E0, through0x00402F98 |
| 0x07FE | 246, Telemetry Middle | inline0x00402FA4..0x0040306F |

The handlers react to notification9 (CBN_SELENDOK), retrieve the selected text
with CB_GETCURSEL/CB_GETLBTEXT and match literal protocol names with wcsstr.
Raw values below are established by the assignments/masks after those comparisons,
not inferred from the resource-string or combo-box order.

All examined branches modify the same local WORD at0x0041248E, offset0x36 from
the EEPROM buffer base0x00412458. They call0x00407C70 to refresh the display.
Actual device storage follows the separate full-EEPROM/USB path, including
0x0040E2C0 and WriteFile at IAT0x00410080. Port selection itself is a local buffer
edit, not an MSP217/218 message or an encoded UART parameter write.

### Protocol codes proved in selection code

| Protocol | Assigned code | Example instruction evidence |
| --- | --- | --- |
| Off | 0 | byte clear0x0040CC84; middle mask0x00402FF2 |
| KONTRONIK | 1 | 0x0040CCD6 /0x0040D59B |
| Graupner | 2 | 0x0040CD15 /0x0040D5F1 |
| Futaba | 3 | 0x0040CD6B; middle shifted value0x60 at0x00403028 |
| Multiplex | 4 | 0x0040CDC1 /0x0040D647 |
| Mikado | 5 | 0x0040CE17 /0x0040D69D |
| Jeti | 6 | 0x0040CE6D /0x0040D6F3 |
| PowerBox | 7 | 0x0040CEC3 /0x0040D751 |
| FrSky | 8 | 0x0040CF4B; middle shifted value0x100 at0x0040305C |

These prove command-buffer codes in this program version and branch. They do not
prove that every ESC/EEPROM version accepts all nine protocols on every port.

## Model branch and packing differences

K-KONFIG derives a numeric family from `(deviceInfo >> 12) & 0xFFF` at
0x00406D93..0x00406DAB and the low12 bits separately (including rated-current
checks). This USB device-info value is not the MSP217 model-name string.

| Internal family | Flag / display evidence | Telemetry interpretation in this EXE |
| --- | --- | --- |
| 500 /550 (0x1F4/0x226) | shared flag0x00412455; KOLIBRI / LV or HV | Front low byte, Side high byte |
| 225 /245 (0x0E1/0x0F5) | shared flag0x004124C5; KOSMIKIND / HV | BEC-side low byte, LED-side high byte |
| 250 (0x0FA) | flag0x004124C4; KOSMIK / HV | three5-bit fields, see below |
| 700 (0x2BC) | flag0x00412454; KOLIBRIX / LV | byte-oriented special branch; not fully qualified |

Family detection is at0x00406DD8..0x00406E6D. Family-name selection is at
0x00406EA6..0x00406F96 (including the jump table at0x00407BC8/0x00407BD8).
The KOSMIKIND branch reverses the generic Front/Side control byte orientation:
handler0x0040CF70..0x0040D125 writes the high byte, and0x0040D51F..0x0040D775
writes the low byte. In this branch the controls are relabelled LED-side/BEC-side.
Both KOLIBRI500 and550 instead share flag0x00412455; the flag is set at the
common join for both comparisons, not just the adjacent family550 comparison.
The extractor checks all seven family cases to guard this distinction.

### Packed KOSMIK-family250 word

For family250 the program relabels control0x07FB as **LED-side** (resource404)
and0x07FC as **BEC-side** (resource405), at0x00407AA6..0x00407B3D.
The display path at0x00409019..0x00409150 independently reads back these fields:

| Physical port | Bits | Decode | Assigned protocols in examined handler |
| --- | --- | --- | --- |
| BEC side | 0..4 | word &0x1F | 0,1,2,4,5,6,7 |
| Middle | 5..9 | (word >>5) &0x1F | 0,3,8 |
| LED side | 10..14 | (word >>10) &0x1F | 0,1,2,4,5,6,7 |

Middle selection uses the same WORD, masks with0x7C1F, then inserts0x60 for
Futaba or0x100 for FrSky. Readback masks0x03E0 and checks those same constants
at0x004090E1..0x0040913F. This is code-level evidence, beyond the help listing.
No examined middle-port handler accesses the adjacent WORD/frei1 at offset0x38.

Illustrative arithmetic, **not hardware or shared firmware test vectors**:

| Word | Reference LV byte interpretation | Packed family250 interpretation |
| --- | --- | --- |
| 0x0100 | Front Off / Side KONTRONIK | BEC Off / Middle FrSky / LED Off |
| 0x0060 | Front raw0x60 / Side Off | BEC Off / Middle Futaba / LED Off |
| 0x0400 | Front Off / Side Multiplex | BEC Off / Middle Off / LED KONTRONIK |

This incompatibility is the main reason to keep layout-qualified decoding.

## Restrictions and implementation cautions

- Reference LV Front supports assignments0..8 in this executable. Its Side
  handler assigns0,1,2,4,5,6,7, without Futaba/FrSky assignment branches.
- The KOSMIKIND225/245 high/low byte handlers have no Futaba/FrSky assignment
  branch and no enabled Middle selector. KOLIBRI500/550 instead share their own
  branch. Exact USB-family/firmware associations still need to be matched to
  UART models before enabling these as Suite capabilities.
- Packed outer-port handlers reject several duplicate-active choices by comparing
  the opposite field. These checks are not a trustworthy generic validator:
  some branches use inconsistent masks/comparison constants, and the Middle
  handler does not implement a global three-port uniqueness check.
- Several assignments clear bits beyond the intended field: middle mask0x7C1F
  and LED-side mask0x03FF also clear bit15. A future Suite bitfield editor must
  preserve unowned bits rather than blindly copying these mutations.
- Literal text matching is language-dependent (for example the handler contains
  German Aus). Resource/UI behavior must not be copied as Suite decision logic.
- The family700 path is special; this pass establishes its existence and name,
  not a complete supported-port list. No KOLIBRIX permission is inferred.

## What is established, and what still blocks a Suite model mapping

Established statically: PowerBox7 and FrSky8 assignments; family-dependent byte orientations;
family250 three-field packing; Middle uses the same word as the outer ports;
physical BEC/LED labels and numeric family guards in this exact executable.

Not established by this pass:

1. A complete correspondence between numeric USB families and the exact UART
   model strings/EEPROM versions seen by Rotorflight, particularly family250.
   The KOSMIK/HV label is evidence; equating it universally with every HV-I variant
   would be an inference.
2. That the WORD at USB buffer offset0x36 is serialized as UART pointer0x2036
   for each new layout. The reference LV case corroborates it, but the program
   edits a full binary EEPROM buffer, not a list of UART encoded pointers.
3. Actual readback for a known port/protocol change on a new model/version.
4. Complete safe cross-port constraints, unknown/reserved-bit behavior and
   support in present-day firmware.

Next targeted comparison, when a suitable controller is available: record its
USB family/device-info, exact UART model/EEPROM and a full before/after E-frame;
change only Middle Off/Futaba/FrSky in K-KONFIG, then compare the changed word.
Similarly compare KOLIBRI and KOSMIKIND ports with a single known protocol. Hardware writes
need a separate explicit instruction; this analysis performed none.

No new Suite runtime mapping is enabled. The existing KOLIBRI reference remains
unchanged, while documented-but-unqualified ports continue to show Not readable.


## Executed verification

The extractor passed all34 instruction anchors,15 literal checks,3 control
routes,7 family-flag evaluations and6 family-name dispatch checks against the
exact SHA256 above. A scratch copy with one altered byte was rejected before
disassembly, as required. Python syntax/import checks pass. The Suite runtime,
shared firmware vectors and locale resources were not changed by this analysis;
no new radio or hardware acceptance test is claimed. All artifacts remain local
and uncommitted.
