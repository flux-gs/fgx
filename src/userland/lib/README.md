# FGX userland library convention

> **T5-A A2 (2026-07-09): the libc pile lives in `toolchain/lib/` ONLY.**
> `libc.s`, `libc_data.s`, `args.s`, `args_data.s` were dual-tree copies
> policed by a build.sh drift guard; they are now unified — every link file
> PUTs `toolchain/lib/` directly (`../../../toolchain/lib/...` from a tool
> dir) and the guard + sync chore are retired.  This directory keeps the
> FGX1 crt0s (`crt0.s`, `crt0_c.s`) and C-side sources (`regexp.c`,
> `termcap.c`, headers).  The conventions below still govern the pile's
> file shape wherever it lives.

## The `_data.s` sibling rule

Every library `.s` file that owns **DBR-accessed state** (own-bank
storage read via `LDA:` / `STA:` absolute addressing) ships as a pair:

| File | Holds | Multi-bank lives in |
|---|---|---|
| `libname.s` | Code only — routines, EQU constants used by code | `seg0` (code segment) |
| `libname_data.s` | DS / DA / ASC / HEX storage declarations | `seg1` (data segment) |

This shape mirrors BSD/Unix object files (`.text` / `.data` / `.bss`
sections) and explicit `-llibname` link declarations: every binary
states exactly which library halves it pulls in.

## How to use a state-bearing library

Every binary's link.s (or top-level `.s`) MUST PUT both halves,
typically adjacent:

```
                PUT     ../lib/crt0.s
                PUT     <binary>.s
                PUT     ../lib/libc.s        ; code
                PUT     ../lib/libc_data.s   ; DBR storage
                PUT     ../lib/args.s        ; code
                PUT     ../lib/args_data.s   ; DBR storage
```

The data file MUST be PUT *after* its code sibling so the EQUs and
constants defined in the code file are visible to the data file's
declarations.

## Why two files (and not a single-file wrapper)?

Merlin32's nested `PUT` loses forward-reference visibility: a link.s
that PUTs `outer.s` which PUTs `inner.s` can't `STZ` a label defined
in `inner.s`. (Verified empirically — see commit history for the
slice 4.5 work and resume notes.)

So every binary must declare both halves directly. That's also the
right architecture for multi-bank FGX2: `seg0.link.s` PUTs the code
halves; `seg1.link.s` PUTs the data halves; both segments assemble
cleanly with full label visibility within themselves.

## Multi-bank FGX2 layout

For a multi-bank binary (n_data_segment = 1) the split is symmetric:

```
* seg0.link.s
                PUT     ../lib/crt0.s
                PUT     <fcc-output>.s
                PUT     ../lib/libc.s
                PUT     ../lib/args.s
                ;  ↑ code only — these files have no DS/DA storage now.

* seg1.link.s
                PUT     <fcc-output>.data.s
                PUT     ../lib/libc_data.s
                PUT     ../lib/args_data.s
```

The seg1.link.s defines any constants the data files reference, since
the code files (which originally defined those EQUs) aren't included
in seg1.

## Adding a new state-bearing library

When you add `mylib.s` that wants to keep state in own-bank storage:

1. Create `mylib_data.s` with all the DS/DA/ASC/HEX declarations.
2. Keep code + EQUs in `mylib.s`.
3. Update every binary's link.s (or top-level .s) that PUTs `mylib.s`
   to also PUT `mylib_data.s` on the next line.
4. If the library's EQUs are used by the data declarations, the
   single-bank case just relies on `mylib.s` being PUT first. The
   multi-bank case needs those EQUs defined in `seg1.link.s` as
   shown above.

## Files following this convention today

- `args.s` + `args_data.s` (slice 4.5)
- `libc.s` + `libc_data.s` (slice 4.5)

`crt0.s` is a special case — single file, no DBR state of its own
(it walks the kernel's argv frame and populates `args_data.s`'s
storage; crt0 itself owns only a few internal scratch slots which
stay inline because no other file references them).
