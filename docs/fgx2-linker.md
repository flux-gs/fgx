# FGX2 multi-segment linker (`toolchain/src/ld/fgx_ld.py`)

`fgx_ld.py` is the back end that turns per-segment Merlin32 output into an
FGX2/FGX3 binary. FGX2 is the multi-bank format: the loader places each segment in a
bank chosen at spawn, so the linker has to leave the **bank bytes** of cross-segment
references (a `JSL` operand, a long pointer) for the loader to patch once the
banks are known. The binary layout is in `docs/userland-abi.md` section 2.2 and
`include/loader.s` (`FGX2_*` EQUs).

## Pipeline

```
   src/userland/<name>/<name>.c  (+ per-TU sources named in manifest.json)
                           |
                           |  tools/ninja/gen.py's direct_link_edges:
                           |  fcc compiles each TU to <stem>.s + <stem>.data.s
                           v
                tools/<name>-fgx2/<stem>.s, <stem>.data.s
                           |
                           |  dynamic: toolchain/src/ld/fgx_dyn.py
                           |  static:  toolchain/src/ld/fgx_static.py
                           |  (--lib against libc.so/libfgx.so and
                           |   libtermlib/libcurses/libutil.so as named,
                           |   or the matching build/static_libs/*.s)
                           v
          tools/<name>-fgx2/dyn.ld/ or static.ld/
                     dyn.json              (the generated manifest)
                     seg0, seg1, ...       (raw bytes, in work subdirs)
                     seg0_Output.txt, ...  (per-seg Merlin listings)
                           |
                           |  toolchain/src/ld/fgx_ld.py dyn.json
                           |  (the back end both drivers call)
                           v
                     bin/<name>.bin         (FGX3 header + segtab +
                                            seg data + reloc table)
```

`tools/ninja/gen.py` emits the per-tool edges: a `dynlink` edge runs
`fgx_dyn.py` for every tool that names libraries in `manifest.json`'s
`"libs"` (against `libc.so`, `libfgx.so`, and `libtermlib.so`/`libcurses.so`/
`libutil.so` as named), and a `staticlink` edge runs `fgx_static.py` for the
13 manifest records marked `"static": true` (against the matching
`build/static_libs/<lib>.s` instead). Both write their per-segment sources,
raw segment bytes, and Merlin listings into `tools/<name>-fgx2/dyn.ld/` or
`tools/<name>-fgx2/static.ld/`, then call `fgx_ld.py` to produce
`bin/<name>.bin`.

## Manifest

`fgx_ld.py` reads a JSON manifest (positional argument). No tool in the tree
carries a hand-written one: `fgx_dyn.py` / `fgx_static.py` generate it
(`tools/<name>-fgx2/dyn.ld/dyn.json` or `static.ld/`). The authoritative schema
is the docstring at the top of `fgx_ld.py`; the core fields:

| Field | Meaning |
|-------|---------|
| `output` | output file, manifest-relative |
| `format` | `FGX2` (default) or `FGX3`; the drivers write `FGX3` |
| `n_data_segment` | segment holding globals/strings; its bank is DBR at entry |
| `entry_offset` | PC offset of the entry point |
| `flags` | header byte 10 (bit 1 library, bit 2 dynamic program) |
| `segments[]` | `bin`, `listing` (Merlin `-V` listing scanned for macro rows), `kind` (`CODE`/`DATA`/`RODATA`), `bss`, `org`, optional `offsets` (makes the segment placeable at a page offset), optional manual `xrefs` |
| `stack_frames` | fcc `.s` outputs from which the bank-0 stack size (header byte 14) is computed |
| `library` | present when linking a shared library (`libc.so` etc.): core/template segments, block table, exports; a trailer follows the relocs |
| `dynamic`, `imports` | a dynamic program: its imports and their sites go in a trailer |

## Source-side conventions (macros)

In `toolchain/lib/macros.s` (and the kernel's copy, `include/macros.s`). Macro
arguments are **semicolon-separated** (a Merlin32 quirk). The linker finds
these by name in the `Macro` rows of each segment's listing and computes the
patch address from the invocation address plus a per-macro delta, rather than
from planted labels (Merlin32 does no `]N` substitution in label positions).

| Macro | Emits | Linker | Loader |
|-------|-------|--------|--------|
| `FGX2_EXPORT <name>` | nothing | records `<name>` at this address | -- |
| `FGX2_FARCALL <name>` | `JSL $000000` | resolves `<name>` across all segments, patches +1..+2 | writes the bank at +3 |
| `FGX2_FARJUMP <name>` | `JML $000000` | as `FGX2_FARCALL` | writes the bank at +3 |
| `FGX2_LONG_PTR <tag>;<name>;<seg>` | 4 bytes (offset, bank, pad) | patches the offset | writes the bank at +2 |
| `FGX2_ABS_OFFSET <tag>;<name>;<seg>` | 2-byte offset | patches it | -- |
| `FGX2_IMPORT_JSL <tag>;<name>;<seg>` | `JSL $000000` | resolves `<name>` in segment `<seg>` only | writes the bank at +3 |
| `FGX2_XREF_JSL_BANK <tag>;<seg>;<off>` | `JSL <off>` | literal offset, no lookup | writes the bank at +3 |
| `FGX2_CALLEE_ENTER <tag>;<seg>` | `PHB / SEP / LDA #$00 / PHA / PLB / REP` | -- | writes `<seg>`'s bank into the `LDA` immediate (+4) |
| `FGX2_CALLEE_LEAVE` | `PLB / RTL` | -- | -- |
| `LIBC_EXPORT <name>` | nothing | as `FGX2_EXPORT` (libc.s's own spelling) | -- |

fcc emits `FGX2_EXPORT`, `FGX2_FARCALL` and `FGX2_LONG_PTR` (plus the
bookkeeping macros `FGX2_MODE` and `FGX2_RELOC_COUNT`).
A program keeps one data bank in DBR throughout, so fcc code needs no callee
DBR switch; `FGX2_IMPORT_JSL`, `FGX2_XREF_JSL_BANK` and `FGX2_CALLEE_ENTER` /
`LEAVE` remain for hand-written segmented assembly.

Each patched bank byte becomes one 4-byte reloc entry `(src_seg, offset,
tgt_seg)`. A reloc whose `tgt_seg` has bit 7 set (`FGX2_RELOC_ADDOFF`) is an
offset relocation instead: the loader adds that segment's load offset to the
16-bit word, which is how a placeable segment (`FGX2_SEGF_PLACE`) loads at a
page offset.

## Library selection and GC

A program links only the library code and data it can reach.  The libraries
are compiled with `fcc --sections` (libc and the other shared libraries in
library mode, `fcc --libso`), which wraps every function and data item in
`FGX_SECT <label>` ... `FGX_ENDS` (empty macros; the bytes are unchanged).
`toolchain/src/ld/fgx_gc.py` (apple/fgx#457) keeps a section when anything
live names one of its labels:

- a section's references are the identifier tokens of its rows outside
  comments -- Merlin spells every symbol reference as its label, so a
  function reached only through a pointer is kept by the live data item that
  holds it;
- the roots are everything outside a section: the program's own code and
  data, the hand-written runtime and library files;
- a library code section named by an exported name of a root code file
  yields to it, as 2.11BSD's ld takes an archive member only for a name
  still undefined; a library tentative definition yields under K&R A.10.2's
  common extension.

The two link drivers call it.  `toolchain/src/ld/fgx_static.py` keeps the
live sections of the `--lib` libraries and of libc's library-mode compile,
and packs the libc functions as libc.so's are (fgx_libso).
`toolchain/src/ld/fgx_dyn.py` keeps the fcc runtime units the program
reaches and builds each needed library's reachability bitmap over its
block-table rows from the names the program imports.

**A wrong prune is loud:** a dropped section still referenced by label is an
undefined symbol at merlin32.  `fgx_gc.py --self-test` (in the gate) keeps a
function reached only through a pointer table and drops code named only by
dead code or comments; `toolchain/tests/sections.py` (the gate's fcc stage)
proves `--sections` changes nothing else.  `/testbin/gcprobe` runs the
pointer paths into libc on the machine.

## Output format

What `src/kernel/far/loader.s` (`Load_Binary`) reads; field meanings are in
`docs/userland-abi.md` section 2.2.

| Offset           | Size  | Field                                      |
|------------------|-------|--------------------------------------------|
| 0                | 4     | `"FGX2"` or `"FGX3"`                       |
| 4                | 2     | reserved                                   |
| 6                | 1     | `n_segments`                               |
| 7                | 1     | `n_data_segment`                           |
| 8                | 2     | `entry_offset`                             |
| 10               | 1     | `flags`                                    |
| 11               | 2     | `reloc_count`                              |
| 13               | 1     | `abi_version` (FGX3; 0 in FGX2)            |
| 14               | 1     | bank-0 stack pages                         |
| 15               | 1     | soft-stack banks                           |
| 16 + 8k          | 8     | segment table entry: size, bss, kind, flags, reserved |
| 16 + 8N          | sum   | concatenated segment bytes                 |
| (tail)           | 4R    | reloc entries: `src_seg, offset, tgt_seg`  |
| (after relocs)   | --    | library or dynamic-program trailer, when flagged |

Caps: 8 segments (`fgx_ld.py`'s `MAX_SEGS`; the kernel loader enforces the same
cap as `FGX2_MAX_SEGS`), 65535 relocs (16-bit count, streamed in 64-entry
batches).
