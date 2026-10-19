# FGX Kernel Calling Conventions

This document is normative for kernel assembly. Violations produce "memory
corruption" symptoms whose cause is a caller-side assumption about which
scratch state survives a JSR.

Kernel C (the far and tty banks, and the vfs/ufs modules, compiled by fcc) has
its own rules: the kernel-C direct page, the shared fcc register file, and the
asm->C entry and exit macros are in `include/kernelc.s`.

## Register conventions

- **A, X, Y are CALLER-SAVED** unless a routine's header comment explicitly
  says otherwise. If the caller needs A/X/Y to survive a JSR, wrap with
  `PHA/PLA`, `PHX/PLX`, `PHY/PLY`.
- **Native-mode width (M / X flags) is preserved across calls** when the
  callee follows the project pattern of `PHP / REP #$30 / MX %00 / ... / PLP`.
  Routines that don't preserve P must say so in their header.
- **DBR is the live core kernel bank in core-kernel context.** The kernel is
  relocated at boot (see [memory-map.md](memory-map.md)), so it is not a fixed
  `$02`: syscall entry sets it with `PHK`/`PLB` (`src/kernel/syscall.s`), and
  kernel statics are addressed DBR-relative so they land in the live copy.
  Never bake a kernel bank byte (`LDAL`/`STAL` to a `$02xxxx` address). Code
  in the far and tty banks runs with DBR set to its own bank: asm entries set
  it on entry, kernel-C slots have it switched on the calling side (`KC_ENTER`
  in `include/kernelc.s`), and the caller's DBR is restored on return.
  Routines that change DBR (MVN does) must restore it before returning.

## Direct-page scratch (the recurring trap)

DP is partitioned by **module ownership** in `include/dpmap.s`. Each module
owns a band of DP slots. The shared scratch slots -- `_shTmp0/1/2`,
`_libcTmp0/1/2`, `_fsTmp0/1/2`, `_conTmp*` -- are conceptually
**caller-saved** (like a hardware register).

**This means callees may freely overwrite them.** Callers that need a value
to survive a foreign JSR must **NOT** keep that value in shared DP scratch.

### The hard rule

> If a value must survive a JSR to anything outside your own module, it does
> NOT live in `_shTmp*`, `_libcTmp*`, `_fsTmp*`, or `_conTmp*`.
>
> Put it in a dedicated kernel-bank static, or push it on the stack.

Concrete pattern in tree:

```asm
; src/kernel/syscall.s -- _Sys_Read keeps its arguments in dedicated statics
_Sys_RdFd      DS  2                ; saved fd
_Sys_RdRem     DS  2                ; remaining-bytes counter
_Sys_RdMax     DS  2                ; original count (return value)
_Sys_RdBufOff  DS  2                ; caller-buf offset

_Sys_Read      MX  %00
               ...
               STA  _Sys_RdFd       ; fd: survives _Fcb_LookupPtr, which eats _shTmp0
               STX  _Sys_RdBufOff
               STY  _Sys_RdRem
               STY  _Sys_RdMax
               ...
               LDA  _Sys_RdFd
               JSR  _Fcb_LookupPtr
               ...
               LDA  _Sys_RdFd       ; still the fd
```

### Common eaters (memorize)

- `Kmalloc` / `Kfree` clobber **`_libcTmp0/1/2`** and leave `_libcTmp2`
  pointing at the chunk header. This means **anything that allocates eats
  `_libcTmp2`**, including transitively:
  - `_Fcb_Alloc` (via `Kmalloc`), `_Fcb_Free` (via `Kfree`)
  - `Fs_Open`, `Fs_Close`
- `_Fcb_LookupPtr` clobbers **`_shTmp0`** (computes the `fd*3` byte offset).
  This means **anything that takes an fd argument eats `_shTmp0`**, including
  `Fs_Close`, `_Fcb_Alloc` and `_Fcb_Free`.
- `_Sys_CopyPathToBuf` clobbers **`_libcTmp2` and `Y`** (walks the path).
- `Con_Write` clobbers **A, X, Y** (the parser and rasterizer use X
  heavily). Wrap X in `PHX/PLX` if it must survive.

## The `Clobbers:` header rule

Every public routine's header comment ends with a `Clobbers:` line. Format:

```asm
;------------------------------------------------------------------------------
; Routine_Name - one-line description.
;
; Input:   A = ..., X = ..., Y = ...
; Output:  C=1 + ... | C=0 + ... on error
; MX:      Caller %XX, callee preserves caller's M/X via PHP/PLP
; Clobbers: A, X, Y, _shTmp0/1/2, _libcTmp2, _fcbPtr
;           (transitive: callees include Fs_Read, _Fcb_LookupPtr)
;------------------------------------------------------------------------------
```

Rules:

1. **List every shared DP slot the routine writes to**, transitively (i.e.,
   include slots written by callees that are themselves shared scratch). If
   you call `Kmalloc`, `_libcTmp2` goes on your clobber list even if your
   own code never touches it.
2. **Don't list module-private DP slots** the caller is not expected to know
   about. (Console internal `_conScratch*`, for example.)
3. **List register clobbers** (A/X/Y) only if the routine doesn't preserve
   them. Default assumption is "all three caller-saved" -> no need to list.
   If the routine guarantees X is preserved, say so explicitly.
4. **Note transitive callees** when they're the source of the eater list, so
   reviewers can trace.

## Patterns by routine class

### Syscall handlers with internal loops

(`_Sys_Read`, `_Sys_Write`, `_Sys_ListDir`, etc.)

These call into Fs_*, Con_*, Kmalloc -- eaters everywhere. **All loop state
goes in dedicated kernel-bank statics**. Naming convention: `_Sys_<Name>_<Field>`,
e.g. `_Sys_RdFd`, `_Sys_LdBufOff`. Allocate the slots in `syscall.s` near the
existing `_Sys_*` block.

If the handler builds a long-pointer in `_libcTmp2` for `[caller_bank:offset]`
writes, **re-establish `_libcTmp2` AFTER each foreign JSR** -- not just once
at routine entry. Foreign JSRs that call into the allocator (transitively or
directly) leave `_libcTmp2` pointing at heap chunks.

### Kernel utility routines (`Fs_*`, `_Fcb_*`, `Kmalloc`, `Kfree`)

Caller-saved DP. Callee uses whatever shared scratch it needs. Header lists
the clobber set. No expectation that scratch survives the call.

### Block-driver primitives (`Blk_Read`, `Blk_Write`)

Clobber A, X, Y and DBR: the final MVN leaves DBR at the destination bank,
which is the live kernel bank unless the caller named a bank of its own (see
the headers in `src/drivers/block/block.s`). RAM-class devices also clobber
`_libcTmp2`. Use
`_blkBuf`, `_blkNum` (caller-set), `_devPtr`, `_blkTrampPtr`, `_blkEntryPtr`.

### Console primitives (`Con_Write`, `Con_GetKey`, `Con_PutChar`)

Console module owns `_conTmp*`, `_conScratch*`, `_conStrPtr`. **Con_Write
clobbers X** (rasterizer scratch). Callers wrap.

## When to add a new dedicated static vs use existing scratch

**Use shared scratch (`_shTmp*` / `_libcTmp*`) when:**
- The value's lifetime is entirely within a tight code block -- no JSR
  in between the write and the last read.
- You're writing the inner-most leaf routine.

**Use a dedicated kernel-bank static (or the stack) when:**
- A loop body calls into another module.
- A multi-step computation crosses any JSR.
- Multiple calls in a routine need to compare values.
- The routine is a syscall handler dispatched from the user side.

If in doubt, do not use shared scratch. Core-bank static space is tight (the
statics must end below `$FE00`, enforced by an `ERR` in `include/memmap.s`), so
a value with a short lifetime can go on the stack instead; either costs less
than diagnosing "memory corruption".

## Adding the convention to a new routine

1. Write the routine.
2. Trace every JSR in the body. For each, look at its `Clobbers:` line.
   Union the sets.
3. In your routine's header, write your `Clobbers:` line as: your direct
   writes + the transitive set from your callees.
4. For each value you store in shared scratch (`_shTmp*`, `_libcTmp*`,
   `_fsTmp*`) that you read AFTER a JSR call, audit: is that slot in the
   callee's clobber set? If yes -- bug, move to a dedicated static.

## See also

- `include/dpmap.s` -- authoritative DP layout
- `include/kernelc.s` -- kernel-C direct page, register file and entry rules
- [memory-map.md](memory-map.md) -- where the kernel banks and statics live
