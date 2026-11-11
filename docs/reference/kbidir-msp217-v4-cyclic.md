# KBiDir MSP 217 cyclic read contract, version 4

Revision **kbidir-msp217-v4-r3**. Firmware and Suite must deploy the same revision.
The revision label is documentation only. There is no schema or read-only byte
on the wire. All multibyte integers are unsigned little endian.

## Firmware baseline and legacy routing

`src/main/msp/msp.c` must be byte-for-byte identical to the agreed original
firmware revision `1dbc4242fdaea50a1d4e5c1d69d9975cf6fd0484`. Remove the draft
KBiDir dispatch and copy-completion additions from that file. Verify byte equality
against the baseline Git blob, using the repository's checkout line endings when
comparing working-tree bytes. Report the exact comparison used.

- The Suite sends only direct MSP 217 requests with an empty payload. The original
  output handler does not expose request bytes or the caller to the ESC getter.
  A nonempty MSP 217 request can therefore consume a normal cycle element.
  A batch containing 217 is handled by the original MSP_MULTIPLE_MSP code.
- For selected KBiDir, `escGetParamBufferLength()` returns 96 and has no cursor,
  snapshot or UART side effects. `escGetParamBuffer()` produces the next complete
  96-byte reply and advances the cursor once when it provides the buffer. MSP
  sizing probes, normal reads and failed/truncated copies can consume items.
  Returning the read length alone must never consume one.
- For selected KBiDir, `escGetParamUpdBuffer()` returns a private discard buffer
  of at least 96 bytes, before any vendor-specific buffer preparation.
  The unmodified MSP 218 handler may copy request bytes into that buffer.
  `escCommitParameters()` returns false for KBiDir before any 4-way branch,
  callback, scheduled action or shared parameter mutation. The write returns
  an MSP error and does not start or queue programming, change the snapshot or
  move the read cursor. The discard buffer is never used as a source of data.
- Existing ESC protocols keep their ID, CLI mapping and parameter paths.
  Keep the KBiDir ID appended. This wire revision does not require any change
  to PG registration, the global MSP API version or the firmware version.

Reads operate on the existing UART cache. No MSP 217 request starts a new
UART exchange or sends a command to the ESC.

## Fixed reply layout

Byte 0 is the KBiDir family signature `0x4C`. Byte 1 is the item type
(`0x00` for Metadata, `0x01` for Block). Byte 2 is status, always zero.
Offsets are zero-based. Metadata fields:

| Offset | Type | Meaning |
| --- | --- | --- |
| 0 | U8 | Family signature `4C` |
| 1 | U8 | Item type `00` |
| 2 | U8 | Status `00` |
| 3 | U32 | Nonzero retrieval ID |
| 7 | U32 | ESC session ID within this FC boot |
| 11 | U32 | Frozen EEPROM generation |
| 15 | U16 | Total pair count N, 0–64 |
| 17 | U16 | Raw BCD EEPROM version |
| 19 | U32 | Parameter source age in ms at capture |
| 23 | U32 | Model source age in ms at capture |
| 27 | U8 | Availability flags |
| 28 | U8 | Model length L, 0–31 |
| 29 | U16 | Frozen-slot lifetime, 30000 ms |
| 31 | L bytes | Printable ASCII model, no NUL terminator |

Block fields:

| Offset | Type | Meaning |
| --- | --- | --- |
| 0 | U8 | Family signature `4C` |
| 1 | U8 | Item type `01` |
| 2 | U8 | Status `00` |
| 3 | U32 | Served retrieval ID |
| 7 | U16 | Served first-pair offset |
| 9 | U8 | Pair count C, 1–14 |
| 10 | U8 | Reserved zero |
| 11 | C × 6 bytes | Encoded pointer U16 followed by raw value U32 |

| Item | Meaningful bytes | Padding |
| --- | --- | --- |
| Metadata | 31 + L, with L in 0â€“31 | All remaining bytes through offset 95 are zero |
| Block | 11 + 6 Ã— C, with C in 1â€“14 | All remaining bytes through offset 95 are zero |

Every KBiDir reply is exactly **96 bytes** of MSP payload, including one padding byte in a full
14-pair block. The fixed size keeps sizing and output consistent in the
unmodified MSP batch handler. Firmware clears padding for every reply. The Suite
validates the size, signature, item type, meaningful fields and zero padding
before accepting any data. For a block, C = min(14, N - offset) with offsets
0, 14, 28 and so on while offset < N. Preserve unknown and duplicate pointers,
order and all U32 value bits.

Availability and capture metadata:

- Flag bit 0 means parameters are available, requiring 1–64 pairs and fresh source
  data at capture under the two-second freshness limit. When unavailable or stale,
  bits 0 and 2 are clear, N/version/generation are zero and parameter age is `FFFFFFFF`.
- Flag bit 1 means the model is available, requiring L=1–31 and fresh model data
  at capture. Otherwise L is zero and model age is `FFFFFFFF`. Model and parameter
  availability are independent. Model bytes are printable ASCII `20`–`7E`;
  preserve spaces without trimming.
- Flag bit 2 means the BCD EEPROM version is available and requires bit 0.
  Otherwise version is zero. Fresh parameters without a known version are valid.
  The BCD version is distinct from model identification and contract revision.
- Flag bits 3–7 are zero. Available ages never use the absent sentinel.
- An empty snapshot has flags/N/L/version/generation zero and both ages `FFFFFFFF`.
  It still contains retrieval/session IDs and completes immediately without blocks.
  This is distinct from MSP error, timeout and malformed/incompatible reply.

## Cycle and Suite collection

Keep at most one pending Suite request. Wait for valid Metadata before collecting;
accept validated blocks for that ID in any order. Repeated identical Metadata keeps
the partial collection. A new ID replaces it. Ignore blocks from an unknown ID.
Identical duplicate blocks contribute no new pairs; conflicting duplicates or changed
Metadata for the same ID invalidate the collection. Publish only after all N pairs
are present, preserving their original offset order. Cancel on deadline, disconnect,
session reset or page close and ignore late callbacks. The deadline starts at the first
enqueue for a Reload and is not extended by retries or snapshot changes. Capture ages
and retrieval duration stay separate; completed configuration is not live telemetry.
Each new 30000 ms frozen snapshot starts with Metadata. After its last Block,
the next reply is the same Metadata and the cycle repeats. Empty snapshots
return Metadata only. New UART data updates the separate live cache.
Session change or expiration invalidates the snapshot and the next read gets
Metadata for a new retrieval ID. A retry can return a later cycle item.

A batch probe can consume Metadata or a Block without returning it to the Suite.
The Suite waits for Metadata, collects blocks in any order for one ID, ignores
identical duplicates and publishes only after receiving all pairs. Missing
items may arrive on later cycles. There is no delivery guarantee while another
client repeatedly advances the cursor. Use the existing page-local 30-second
deadline, clear partial data on snapshot change, and report an incomplete read
as a timeout. Reload may initially receive the existing frozen snapshot.

## Acceptance before release

- Compare `msp.c` against the agreed baseline, including both MSP parameter
  handlers and the unmodified batch handler. Build the intended target.
- Share 96-byte fixtures for Metadata, first and last Block, empty and maximum
  snapshots. Test bad padding and length, a lost middle Block, duplicate and
  skipped items, expiry, session change and bounded collection timeout. Verify
  41 pairs in blocks of 14/14/13 and 64 pairs in blocks of 14/14/14/14/8.
- Exercise direct reads, nonempty requests, batch sizing and output, repeated
  MSP 217 entries in a batch and mixed batches near the output capacity.
  Confirm that every returned KBiDir item is 96 bytes and a sizing probe may
  consume an item. Verify the legacy batch remains correctly framed and that
  the Suite can recover on a later cycle. Report any limitation of the
  original batch handler exposed by these tests before release.
- Send MSP 218 with empty, short, exact-length and overlong payloads while
  KBiDir is selected, including when a legacy 4-way target was previously
  selected. Verify the error, bounded discard buffer, unchanged shared
  buffers, unchanged cursor/snapshot and no UART TX or queued programming.
  Check that existing protocols still read and write through their own paths.
- Validate RF completion and recovery on the actual links before hardware release.
