# IIgs lessons learned — for iigs-mcp ingestion

These notes capture practical traps and patterns that the Apple IIgs reference
manuals don't quite warn against — extrapolated from the FGX project's debug
log and intended for broader applicability to any Apple IIgs 65816 native-mode
project. They are **strong suggestions** based on one project's hard-won
experience, not authoritative rules.

**Status:** lessons-learned, not verified canonical references. Each item names
the symptom that surfaced it, the underlying mechanism, and the recommended
pattern. Where the manuals partly cover the topic, the relevant doc page is
cited so the reader can cross-check.

**Coverage:**

| File | Scope |
|---|---|
| [`lessons_65816_native_mode.md`](lessons_65816_native_mode.md) | 65816 native-mode architecture traps (DBR, DP, MVN, JML[abs], stale flags, native-mode dispatch setup) |
| [`lessons_iigs_hardware_firmware.md`](lessons_iigs_hardware_firmware.md) | IIgs-specific hardware/firmware patterns (Toolbox heartbeat vs direct VBL, keyboard polling, Toolbox bring-up from raw boot, ROM detection, CPU speed measurement, SHR write paths) |
| [`lessons_mame_iigs_workflow.md`](lessons_mame_iigs_workflow.md) | MAME-as-IIgs-emulator quirks (slot timing, autoboot character drops, TAY zero-extend non-compliance, debug workflows) |
| [`lessons_merlin32_quirks.md`](lessons_merlin32_quirks.md) | Merlin32 assembler pitfalls (string encoding, MX-tracker drift, addressing-mode folding, expression evaluation, link files, ORG padding, structural directives) |
| [`hires-beam-timer.md`](hires-beam-timer.md) | A sub-frame-resolution timer from the Mega II video beam counter (TN #39): design, portable pseudo-code, the 65816 read sequence, and the atomicity / bank-explicit-MMIO / validate-live gotchas |

Each lesson is structured as:
- **Symptom** — what the bug looks like at runtime
- **Mechanism** — why it happens (mapped to hardware/architecture/assembler
  behavior where possible)
- **Recommended pattern** — the workaround/idiom that works

Cross-references to iigs-mcp doc pages use the `doc_id:page` convention,
e.g. `toolbox_ref_vol1:661` for SetHeartBeat.

## Provenance

These lessons were extracted from the FGX project (a 2.11BSD port to the Apple
IIgs, its machine-dependent core written in Merlin32 65816, tested under MAME) over
~6 months of incremental development. The bugs cited are real; the
attributed FGX-internal artifact names are illustrative of when each lesson
crystallized, not necessary for understanding the lesson.
