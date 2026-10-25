# FGX Userland ABI

This is the contract every FGX user binary obeys: the binary file formats, the
runtime memory model, the 65816 calling conventions (fcc's C convention and the
register convention of hand assembly and the syscall boundary), the syscall
table, process startup, and the C library's shape.

The kernel-internal calling conventions live in `docs/calling-conventions.md`.
This document is strictly the **user / kernel** boundary and the userland
runtime.

If a fact here contradicts the source (`include/loader.s`, `include/fs.s`,
`include/errno.s`, `toolchain/lib/*.s`, `src/kernel/syscall.s`,
`src/kernel/far/loader.s`), trust the source -- this document follows.

---

## 1. Memory model

The full bank map is `docs/memory-map.md`; the EQUs are in `include/kernel.s`
and `include/loader.s`. What a user process sees:

### 1.1 Banks

| What | Where |
|------|-------|
| Program segments | Each segment of an FGX2/FGX3 binary is loaded into a bank from the user pool (`BANK_USER_FIRST..BANK_USER_LAST`, `$0A..$41`, `include/loader.s`; the pool is a 2.11BSD-style resource map in `src/kernel/bank.s`). The **data segment** goes in the bank spawn/exec allocated for the process; a placeable code segment (`FGX2_SEGF_PLACE`) may share a bank with other texts at a page offset, and a program's code segment already resident for another process is shared rather than loaded again. |
| Soft-stack bank | Granted at spawn when FGX2 header byte 15 asks for it (`FGX2_OFF_SOFTBANK`); holds the soft frames of recursive functions (section 3.6). |
| Shared libraries | `libc.so.1.0` and the other `/lib/*.so.1.0` have banks of their own, held by the shared-library registry (`ld.mod`); see section 6.3. |
| Direct page and hardware stack | Bank `$00` (section 1.2). |
| Heap | libc's `malloc` (`toolchain/lib/libc_c/malloc.c`) grows the break in the data bank with `sbrk(2)` (`SYS_BRK`); a request of `$F000` bytes or more gets dedicated bank-aligned memory from `SYS_MALLOC32`. |

### 1.2 Direct page and stack

A task's **direct page is the first page of its stack reservation** in bank
`$00`, immediately below `TCB_StackBase` (`include/kernel.s`, "THE USER DIRECT
PAGE RIDES WITH THE STACK"). The reservation is carved from the bank-0 stack
arena by `Task_AllocStack`, sized from the binary's header byte 14 (bank-0
stack pages, which `fgx_ld.py` computes from fcc's frame call graph; 0 = the
loader default). The kernel restores this `D` on every syscall return.

fcc-compiled code and libc own most of the direct page; the map is the header
of `toolchain/lib/fcc_runtime.s` (`$78-$97` the callee-saved band
`_fcc_img16..31`, `$98-$B7` the far-pointer register band `_fcc_fpr0..7`,
`$C0-$DF` the promoted-local file, `$E0-$FF` libc and runtime scratch).
Hand-written code linked with them must not keep live state in those cells
across a call, and must leave the band as it found it.

The dispatcher keeps user SP intact across syscalls (saved to `_Sys_UserSP`,
restored on exit). fcc's prologue checks the new S against `_fcc_stkfloor`
(DP `$B9`, kernel-seeded) and kills the process with exit status 134
(`TASK_EXIT_STKOFLOW`) on overflow.

### 1.3 Process startup state

When a freshly loaded program first executes (`Load_Binary`,
`src/kernel/far/loader.s`):

- **Native mode**.  The register width is not part of the contract: on the
  spawn path (`_Task_FirstRun`, `src/kernel/sched.s`) user code is entered
  with **MX = %00** and IRQs enabled, and crt0 `REP`s to **%00** regardless
  (section 5.1).
- **PB:PC** = segment 0's bank : header `entry_offset`.
- **DBR** = the data segment's bank (`n_data_segment`).
- **D** = the task's direct page (section 1.2).
- **S** points at the BSD-shaped argv/envp frame on the bank-0 stack
  (section 4.4).

---

## 2. Binary file formats -- FGX1, FGX2, FGX3

The loader (`src/kernel/far/loader.s`, `Load_Binary`) reads the first 4 bytes
and dispatches on the magic (`'FGX1'`, `'FGX2'`, `'FGX3'`, high-ASCII
accepted). All three share the syscall ABI of section 4.

| Format | Use |
|--------|-----|
| FGX1   | Single-segment legacy format. The loader still accepts it; nothing in the build produces one, and fcc cannot. |
| FGX2   | Multi-segment (1..8 segments) with a reloc table the loader applies at spawn. |
| FGX3   | **Every C tool and shared library.** Byte-identical to FGX2 plus a **mandatory `abi_version` stamp** at byte 13 (`FGX_ABI_CURRENT = 2`). `fmt` defaults to `FGX3` in `tools/ninja/gen.py`. |

### 2.1 FGX1 -- single-segment

A flat file: a 16-byte header, then code + data, contiguous, no relocation
table. The loader copies the post-header bytes into the chosen bank at offset 0.

| Offset | Size | Field                                            |
|--------|------|--------------------------------------------------|
| 0..3   | 4    | Magic `'FGX1'`                                   |
| 4..6   | 3    | Original load address (informational)            |
| 7      | 1    | reserved (0)                                     |
| 8..9   | 2    | Entry-point offset within bank                   |
| 10..11 | 2    | Text size (bytes copied from file into bank)     |
| 12..13 | 2    | BSS size (bytes zeroed after text)               |
| 14     | 1    | Stack pages hint (0 = default)                   |
| 15     | 1    | Future flags (0)                                 |

Source: `include/loader.s` `FGX1_OFF_*`. The binary must be bank-relocatable:
every internal reference is 16-bit or DBR-relative, except `JSL SYS_TRAMP`
(`$00:0328`) and `JSL $E10000` (Toolbox). `src/userland/ls/ls.link.s` and
`src/userland/date/date.link.s` are leftover FGX1 link files that the ninja
build does not reference.

### 2.2 FGX2 / FGX3 -- multi-segment

An FGX2/FGX3 binary describes 1..8 segments. The header is followed by a
segment table, then the segments' raw bytes concatenated, then a reloc table the
loader applies once every segment's runtime bank is known, then (for a shared
library or a dynamic program) a trailer.

**Header (16 bytes):**

| Offset | Size | Field                                                |
|--------|------|------------------------------------------------------|
| 0..3   | 4    | Magic `'FGX2'` or `'FGX3'`                           |
| 4..5   | 2    | reserved (0)                                         |
| 6      | 1    | `n_segments` (1..8; `FGX2_MAX_SEGS = 8`)             |
| 7      | 1    | `n_data_segment` -- segment whose bank is DBR at entry (`fgx_ld` validates the range) |
| 8..9   | 2    | `entry_offset` -- PC offset within **segment 0**     |
| 10     | 1    | flags: bit 1 = shared library (`FGX2_FLAG_LIB`), bit 2 = dynamic program |
| 11..12 | 2    | `reloc_count`                                        |
| 13     | 1    | `abi_version` -- **mandatory in FGX3** (`FGX3_OFF_ABI`); 0 in FGX2 |
| 14     | 1    | bank-0 hardware-stack pages (`FGX2_OFF_STACK`), computed by `fgx_ld.py`; 0 = loader default |
| 15     | 1    | soft-stack banks wanted (`FGX2_OFF_SOFTBANK`), set by `fgx_ld.py` when the program has soft frames |

**Segment table** -- `n_segments` x 8-byte entries after the header:

| Offset | Size | Field                                                |
|--------|------|------------------------------------------------------|
| +0..1  | 2    | text size (bytes copied from file into bank)         |
| +2..3  | 2    | bss size (bytes zeroed after text)                   |
| +4     | 1    | kind: 0=CODE, 1=DATA, 2=RODATA; anything else is `ENOEXEC` |
| +5     | 1    | flags: bit 0 = `FGX2_SEGF_PLACE` (may load at a page offset) |
| +6..7  | 2    | reserved (0)                                         |

**Reloc table** -- `reloc_count` x 4-byte entries, applied in 64-entry batches
(`FGX2_RELOC_BATCH`), so the count may use the full 16 bits:

| Offset | Size | Field                                                |
|--------|------|------------------------------------------------------|
| +0     | 1    | `src_seg` -- segment whose bytes get patched         |
| +1..2  | 2    | offset within `src_seg`                              |
| +3     | 1    | `tgt_seg`; bit 7 clear = write `tgt_seg`'s bank into the byte at the offset; bit 7 set (`FGX2_RELOC_ADDOFF`) = add segment `tgt_seg & $7F`'s load offset to the 16-bit word there |

Source of truth: `include/loader.s` `FGX2_*` / `FGX3_*` EQUs.

**Cross-segment references.** A cross-segment `JSL`/`JML` or 4-byte long
pointer is assembled with a zero bank byte; `fgx_ld.py` resolves the offset at
link time and emits a reloc for the bank byte, which the loader patches at
spawn. The Merlin macros that produce these shapes (`FGX2_EXPORT`,
`FGX2_FARCALL`, `FGX2_LONG_PTR`, and the hand-assembly forms
`FGX2_IMPORT_JSL` / `FGX2_CALLEE_ENTER`) and the linker pipeline are in
`docs/fgx2-linker.md`.

### 2.3 How a binary is built

`tools/ninja/gen.py` compiles each translation unit with fcc and links the
result with `toolchain/src/ld/fgx_dyn.py` (dynamic, the default) or
`fgx_static.py` (a manifest tool marked `"static"`), which generate the link
manifest and call `fgx_ld.py`. See `docs/fgx2-linker.md` and
`docs/developing-userland.md`.

---

## 3. 65816 calling conventions (userland)

Two conventions meet in userland. **C code** -- every tool, libc, and the
shared libraries -- uses fcc's stack convention (section 3.6). **Hand-written
assembly** -- `toolchain/lib/libc.s`, crt0, the runtime helpers -- and **the
syscall boundary** use the register convention of sections 3.1-3.5.

### 3.1 Mode and width

- **Native mode** throughout. The kernel never switches userland to
  emulation mode.
- **Default `MX = %00`** (M=16, X=16) at entry to every public routine.
- Routines that need 8-bit accesses use the `SEP #$20 / MX %10 / ... /
  REP #$20 / MX %00` guard. Callers must not assume their MX state survives a
  call unless the callee uses the PHP/PLP discipline below.

### 3.2 PHP / PLP discipline

A routine that wants to preserve the caller's exact M/X bits does:

```asm
my_routine      MX  %00
                PHP                  ; capture caller's flags
                REP  #$30
                MX  %00              ; assembler tracking only
                ...
                PLP                  ; restore caller flags
                SEC                  ; (or CLC) explicit result-C
                RTS
```

`PLP` overwrites C. A routine that reports success/failure in C must set C
explicitly after the PLP, or stash the result across it.

### 3.3 Register conventions

- **A, X, Y are caller-saved.**
- **`$78-$97`, the band `_fcc_img16..31`, is callee-saved.** A function that
  writes a band word pushes the caller's value after `_fcc_fb` in its prologue
  and pulls it back in its epilogue (section 3.6, Frames).
- **DBR and D survive** a syscall (the dispatcher saves and restores them).
- **Carry (C)** is the success/failure signal of a syscall: `C = 1` success,
  `C = 0` failure with the errno in `A`.

### 3.4 Argument passing (register convention)

Syscalls and the hand-written register-convention routines take arguments in
**A, X, Y**. Pointers travel in **X or Y** (offsets in the caller's data bank,
or offset + bank in X/Y where the syscall says so); counts, scalars and return
values in **A**.

### 3.5 The X-clobber-on-syscall-exit hazard

The dispatcher's exit path executes `LDX _Sys_UserSP / TXS` to restore the user
stack pointer (`src/kernel/syscall.s`), which **overwrites any X the handler
meant to return**:

- **Syscalls do not return data in X** (`SYS_TICKS` is the one exception; see
  the note after the table in section 4.3).
- A second 16-bit return slot uses **Y** -- e.g. `SYS_MALLOC` returns
  `A.lo = bank, Y = offset`.

### 3.6 C convention (cc-target)

What fcc emits for a call from C to C. Every libc function except the four in
`libc.s` (section 6.1) is C and is called this way.

**Pointers.** Every C pointer, including a function pointer, is a **4-byte
slot**: 16-bit offset at +0, bank at +2, pad byte +3 = 0 (`type_size_bytes`,
`toolchain/src/cc/main.c`).

**`sizeof`.**

| Type                          | sizeof |
|-------------------------------|--------|
| `char`                        | 1      |
| `short`, `int`                | 2      |
| `long`, `float`               | 4      |
| `long long`, `double`, `long double` | 8 |
| any pointer                   | 4      |
| `struct`                      | `char` fields byte-packed, wider fields at even offsets, total rounded up to even |

**Arguments.** All arguments go on the **stack, pushed right-to-left** (the
first argument nearest the return address), **caller pops**. `char`/`short`/
`int` push 2 bytes, `long` 4, a pointer 4 (offset word, then bank word above
it); a `struct` argument passes by value at its full size.

**Calls.** Every call between functions is `JSL`/`RTL`: a call to another
segment or to a library is `FGX2_FARCALL <name>`, whose bank byte the loader
patches (section 2.2). Never assemble a `JSL` with a baked bank byte for an
intra-program call -- segments are relocated at spawn. An indirect call holds
the callee's offset and bank in a far-pointer register and enters it with a
two-frame `RTL` (a return frame, then the target frame), so the callee sees the
same 3-byte return frame as a direct `JSL` (`emit_call_indirect`,
`toolchain/src/cc/emit.c`).

**Return values.**

| C type                    | Where                                  |
|---------------------------|----------------------------------------|
| `char` / `short` / `int`  | A                                      |
| `long`                    | A = low word, `_fcc_long_hi` (DP `$EC`) = high word |
| `T *` (any pointer)       | `_fcc_fpr0` (DP `$98`: offset +0, bank +2); the offset also in A |
| `void`                    | --                                     |
| `struct` / `union`        | not supported: fcc rejects a function returning a struct by value ("return-by-value struct not supported") |

**Frames.** The prologue saves `_fcc_fb` (`PEI`), then each band word the
function uses (`PEI _fcc_img16`...), carves locals with
`TSC / SEC / SBC #framesize-saves / TCS`, checks the stack floor, and seeds the
frame base `_fcc_fb`; arguments and locals are read `n,S`, and `framesize`
counts the band pushes so an argument's `n+framesize,S` still reaches it.  A
function that calls another C function keeps its loop-hot locals in the band;
one that calls none keeps them in `$C0-$DF`, which any callee may reuse. `D` is never pointed at
the frame -- the direct page belongs to the runtime (section 1.2). Locals live
on the bank-0 hardware stack, so `&local` has bank 0. A function on a
call-graph cycle (recursion) keeps all its locals instead in a **soft frame**
in the dedicated soft-stack bank, addressed `[_fcc_sfp],Y`
(`toolchain/lib/fcc_runtime.s`).

**Pointer arithmetic and comparison.** The bank byte is invariant under
`+`/`-`; crossing a bank boundary by arithmetic is undefined. `q - p` is
defined only when the banks match. `p == q` compares offset and bank; `NULL` is
offset 0, bank 0. `<`/`>` are defined only when the banks match.

**setjmp / longjmp.** `jmp_buf` is a 48-byte buffer (`<setjmp.h>`,
`typedef struct { char _jb[48]; } jmp_buf;`) holding PB, DBR, `_fcc_fb`, PC,
SP, D, `_fcc_sfp`, the 32-bit signal mask and the callee-saved band, in the
layout `libc.s` writes. A
bare `jmp_buf` identifier still decays to its address, so `setjmp(env)` /
`longjmp(env, v)` compile unchanged.

Both are **compiler builtins** (`parse_expr.c` / `parse_stmt.c`), intercepted
by name: fcc evaluates `env` to its address in `X` and calls libc's `setjmp` /
`longjmp` in the caller's frame -- an ordinary C wrapper could not work, since
its frame is gone by the time `longjmp` fires. `setjmp` returns its result in
`A` (0 on the direct call; the `longjmp` value on resume, 1 if that value was
0) and is usable in any expression. `longjmp` reinstalls the saved signal mask
(`SYS_SIGSETMASK`), restores S, D and DBR, and resumes at the saved PB:PC. The
mask is BSD's contract (2.11BSD `setjmp(3)`, `examples/2.11BSD/usr/man/man3/setjmp.3`: "Setjmp and
longjmp save and restore the signal mask"); FGX provides no `_setjmp`/`_longjmp`. The band is
saved and restored as 4.3BSD-Reno's i386 setjmp saves `ebx`, `esi`, `edi` and `ebp`: the functions a
`longjmp` unwinds never run the epilogues that would have restored their callers' band words.

The `jmp_buf` **must have static storage** (a file-scope global or a `static`
local): the asm addresses it DBR-relative, and an automatic buffer would be in
bank `$00`. fcc **fails closed** with a compile error on a stack-local
`jmp_buf`.

**BSD porting concessions.** `<sys/types.h>` provides
`u_char`/`u_short`/`u_int`/`u_long`/`caddr_t`, `size_t` (`unsigned long`),
`ssize_t`, `off_t` and `time_t` (`long`); there is no `intptr_t`. K&R
definitions and implicit `int` are the native dialect and are accepted
silently; implicit *function* declarations get a warning (once per name per
TU). `errno` is a libc data cell that the syscall wrappers set on failure.

---

## 4. Syscall ABI

### 4.1 Trampoline

All syscalls go through one address:

```asm
SYS_TRAMP       EQU     $000328
```

(`include/kernel.s`; the trampoline is a `JML _Sys_JslEntry` planted at boot,
`src/kernel/syscall.s`.) Calling shape:

```asm
                LDA     #<arg_a>
                LDX     #<arg_x>
                LDY     #<arg_y>
                JSL     SYS_TRAMP
                DFB     SYS_<NAME>          ; syscall number, see section 4.3
                ; on return: C=1 + A = result, or C=0 + A = errno
```

The dispatcher reads the number byte from `[PB:PC]` and advances the return
address past it, so `RTL` lands on the caller's next instruction. **The
`DFB <syscall>` is part of the call's encoding.** C code reaches syscalls
through libc's wrappers (`__syscall` in `toolchain/lib/libc_c/`).

### 4.2 Dispatcher state changes

The dispatcher (`src/kernel/syscall.s`, `_Sys_JslEntry`):

- saves the caller's DBR, A/X/Y and SP, and switches DBR to the kernel bank;
- runs the handler on the task's kernel stack and kernel direct page, which
  live in one of the kernel-image slots (`FGX_KSLOT_*`, `include/kernel.s`);
  the slot stack's bottom-word canary is checked at every syscall entry;
- dispatches through `_Syscall_Table`, refusing a number above `SYS_NUM_MAX`
  with `ENOSYS`;
- on exit: checks pending signals (delivery may divert the return to the
  user's trampoline, section 6A), honours a pending reschedule (section 4.7),
  then forces `MX %00`, restores the user D, SP and DBR, reloads the handler's
  A (and Y) and `RTL`s.

The user-visible contract: "C = 1 on success, A = result; C = 0 on failure,
A = errno; X is destroyed; D, DBR, SP and MX = %00 on return".

### 4.3 Syscall catalog

This table is **generated from `include/loader.s`** -- the single source of
truth for syscall numbers, names, and the ABI described in each EQU comment --
by `tools/gen_syscall_table.py`, and verified in sync by `ninja` (the
kernel-check edge). To add or change a syscall, edit `loader.s`; do not
hand-edit the table below. Errnos live in `include/errno.s` and follow 2.11BSD
numbering (`vendor/2.11BSD/usr/sys/h/errno.h`). `SYS_NUM_MAX` is the highest
implemented number (`SYS_FCHMOD`, 130); the dispatcher returns `ENOSYS` above
it.

<!-- BEGIN GENERATED: syscall-table (regenerated by tools/gen_syscall_table.py from include/loader.s — do not edit by hand) -->
| # | Name | Description (from `include/loader.s`) |
|---|------|--------------------------------------|
| 1 | `SYS_EXIT` | exit(status): A.lo=status -> does not return |
| 2 | `SYS_FORK` | fork() -> parent: A=child pid; child: A=0 |
| 3 | `SYS_READ` | read(fd,buf,len): A=fd X=buf(own bank) Y=len -> A=bytes (0=EOF); C=1 for fd>0, C=0+A=errno on bad fd |
| 4 | `SYS_WRITE` | write(fd,buf,len): A=fd X=buf Y=len -> A=bytes_written; C=1 ok |
| 5 | `SYS_OPEN` | open(path,flags): A=path(own-bank) X=O_* flags Y=mode (creating opens; umask applied) -> C=1+A=fd; C=0+A=errno |
| 6 | `SYS_CLOSE` | close(fd): A=fd -> C=1 ok; C=0+A=errno |
| 7 | `SYS_WAIT` | wait(status): X=status_buf(own-bank) -> A=exited pid; C=0+A=ECHILD if no children |
| 8 | `SYS_LDCTL` | ldctl(service, block): the shared-library registry (ld.mod): A=service X/Y=the 50-byte block (<sys/ldctl.h>) offset/bank; ENOSYS until ld.mod loads |
| 9 | `SYS_LINK` | link(target,linkname): A=target X=linkname, both in the caller's bank. 2.11BSD's own number (init_sysent.c:119), a stub until now |
| 10 | `SYS_UNLINK` | unlink(path): A=path -> C=1 ok; C=0+A=errno |
| 11 | `SYS_EXECVE` | execve(path,argv,envp): A=path X=argv Y=envp -> does not return on success |
| 12 | `SYS_CHDIR` | chdir(path): A=path -> C=1 ok; C=0+A=errno |
| 15 | `SYS_CHMOD` | chmod(path,mode): A=path X=mode. 2.11BSD's own number (init_sysent.c:125), which the table had kept as a stub |
| 16 | `SYS_CHOWN` | chown(path,uid,gid): A=path X=uid Y=gid. THREE arguments, as 2.11BSD's own comment says: "16 = chown; now 3 args" |
| 17 | `SYS_BRK` | brk(2), fork train Stage S. A=the NEW break offset (absolute, as BSD's syscall has always taken it -- libc does sbrk's addition), Y.lo=the sbrk bank. Returns C=1 + A=OLD break + Y=sbrk bank (the heap descriptor lives at dataBank:$FFFA/$FFFC/$FFFE; grown spans are NOT zero-filled, see #361). C=0 + A=errno: ENOMEM below HEAP_BASE (`end') or past HEAP_LIM, EINVAL for a bank that is not this task's. libc layers brk()/sbrk() on this. |
| 18 | `SYS_STAT` | stat(path,buf): A=path X=stat_buf(own-bank) -> C=1 ok; C=0+A=errno |
| 19 | `SYS_LSEEK` | lseek: A.lo=fd A.hi=whence X=off.lo16 Y.lo=off.hi8 -> C=1+A=newpos.lo16 Y=newpos.hi8; C=0+A=errno |
| 20 | `SYS_GETPID` | getpid() -> A=pid |
| 21 | `SYS_MOUNT` | mount(type,dir,flags,data): A = caller-bank offset of libc's 4-word argument block, dir and data in the same bank. 2.11BSD's number (init_sysent.c:131), 4.3BSD-Reno's arguments -- see _Sys_Mount |
| 22 | `SYS_UMOUNT` | umount(spec): A=spec. THE DEVICE, not the directory -- 2.11BSD's interface, and what umount(8) passes after normalising with getmntinfo(3) |
| 23 | `SYS_SETUID` | setuid(uid): A=uid -> C=1+A=0; C=0+A=EPERM. root sets real+effective+saved; non-root may set only the effective id, and only to its real or saved-set id (POSIX rule). |
| 24 | `SYS_GETUID` | getuid() -> A=REAL uid, Y=EFFECTIVE uid, C=1. Both, as V7/2.11BSD getuid returns r0/r1 — that is why there is no SYS_GETEUID: libc's geteuid() issues this and reads the Y return. 0/0 for a boot-context caller with no u-area. |
| 25 | `SYS_SETGID` | setgid(gid): same rule on the gid triple. FGX-local number — BSD's setgid=46 is spent on SYS_VFORK. |
| 26 | `SYS_SETEUID` | seteuid(uid): effective only, same permission rule. FGX-local. |
| 27 | `SYS_SETEGID` | setegid(gid): effective only. FGX-local. |
| 28 | `SYS_FSTAT` | fstat(fd,buf): A=fd X=stat_buf -> C=1 ok, C=0+A=errno (EBADF). Same stat struct as SYS_STAT |
| 33 | `SYS_ACCESS` | — |
| 37 | `SYS_KILL` | kill(pid,sig): A=pid X=sig -> C=1 ok |
| 39 | `SYS_GETPPID` | getppid() -> A=ppid |
| 41 | `SYS_DUP` | dup(fd): A=fd -> A=newfd (lowest free); C=1 ok, C=0+A=errno (EBADF/EMFILE) |
| 43 | `SYS_POSIX_SPAWN` | FGX-specific: posix_spawn(path,argv,envp) (slice-3: argv/envp are caller-bank ptrs to NULL-term arrays of 16-bit ptrs. Slot 45 retired.) |
| 44 | `SYS_POSIX_SPAWNX` | FGX: posix_spawn + file_actions. A=path, X=argv, Y=file_actions ptr (NULL = no actions, equivalent to SYS_POSIX_SPAWN; envp = empty). Actions are applied to the *child's* fd table only -- parent's fds are never touched. Matches the POSIX posix_spawn_file_actions_t shape. |
| 46 | `SYS_VFORK` | vfork(): the child shares the parent's whole image + stack; parent blocks (WCHAN_VFORK) until the child execve()s or _exit()s. Child: C=1+A=0; parent (on resume): C=1+A=child pid. (BSD's number 66 is squatted by SYS_POLLKEY, so FGX-local 46.) |
| 47 | `SYS_GETGID` | getgid() -> A=REAL gid, Y=EFFECTIVE gid, C=1. Same two-value return and no-u-area rule as SYS_GETUID; getegid() reads the Y return. |
| 48 | `SYS_SIGNAL` | signal(sig, handler) — slice-2 stub |
| 49 | `SYS_LISTDIR` | FGX-specific: listdir(path, buf, sz) |
| 50 | `SYS_GETKEY` | FGX-specific: read one raw key from console (blocking, no echo, no line discipline). Used by userland line editors that want arrow keys / ctrl sequences themselves. |
| 51 | `SYS_UPTIME` | FGX-specific: copy 6-byte boot wall-clock (ReadTimeHex layout) into caller-bank buf at A. Userland pairs with its own ReadTimeHex call to compute time-since-boot. |
| 52 | `SYS_TICKS` | FGX-specific: return 32-bit kernel tick counter (60 Hz). A = lo16, X = hi16 on return; C=1 always. Atomic w.r.t. VBL IRQ. |
| 53 | `SYS_KSTAT` | FGX-specific diagnostic: copy a 16-byte kernel-stat struct into the caller-bank buffer at A. Layout: [0..3] total Kmalloc count [4..7] total Kfree count [8..11] cur bytes USED [12..15] total Blk_Read count All four are little-endian 32-bit. |
| 55 | `SYS_BORDER` | FGX-specific: set IIgs border color. A.lo = color index 0..15 (writes the low nibble of $E0C034; high nibble preserved). |
| 56 | `SYS_SETPAL` | FGX-specific: rewrite palette 0's fg or bg slots to a 12-bit RGB. A.lo = role (0=fg, 1=bg). X = 12-bit RGB (bits 11..8 R, 7..4 G, 3..0 B). fg writes palette 0 slots 3/7/11/15; bg writes slots 0/4/8/12. Takes effect at the next SHR scanout. |
| 57 | `SYS_FONTLOAD` | FGX-specific: load a bitmap font from a .FNT file. A = caller-bank path offset (NUL-term). On success: rebuild PreExp cache, repaint screen, set CurrentFontName from the path basename (lowercased, .fnt extension stripped). Returns: C=1+A=0 ok; C=0+A=errno on Fs_Open/read failure or FGXF magic/version mismatch. |
| 58 | `SYS_FONTREVERT` | FGX-specific: revert to the built-in default font and clear CurrentFontName. No args; C=1. |
| 59 | `SYS_FONTNAME` | FGX-specific: copy the current font name (NUL-term, "" = default) into a caller-bank buffer. A = caller-bank buf offset. X = buf size (bytes). Returns: C=1 + A = bytes copied including NUL. |
| 60 | `SYS_DMESG` | FGX-specific: copy kernel log ring buffer into a caller-bank buffer. A = caller-bank buf offset. X = max bytes to copy. Returns: C=1 + A = bytes copied (in chronological order; oldest bytes first if the ring has wrapped). Pairs with /bin/dmesg. |
| 61 | `SYS_MEMINFO` | FGX-specific diagnostic: query Kmalloc/Kfree state. A.lo = subcmd; X = caller-bank buf offset; Y = buf size in bytes. Subcmds: 0 = type stats (8 × 16 B) 1 = arena stats (N × 16 B) 2 = chunk walk (per-chunk 8 B) 3 = retired (EINVAL; the pool is vm.coremap) 4 = guard audit (corrupt chunks) 5 = Memory Manager block table (8 B rows) 6 = Memory Manager totals (3 longs) Returns: C=1 + A = bytes written; C=0 + A = errno (EINVAL on bad subcmd). Pairs with vmstat -m, -c and -g. |
| 62 | `SYS_MALLOC` | userland-libc: allocate. A = size (16-bit, bytes). Returns C=1 + A.lo = bank, Y = offset; C=0 + A = ENOMEM if heap full or EINVAL on size=0. Block is tagged M_ANON. Lives in one of the kernel heap banks ($07-$09); userland uses LDAL/STAL to access. Offset returned in Y, NOT X, because dispatcher exit clobbers handler-return X (see memory note feedback_syscall_dispatcher_x_ clobber_at_exit). |
| 63 | `SYS_FREE` | userland-libc: release a block from SYS_MALLOC. A.lo = bank, X = offset. Returns C=1 ok; C=0 + A = EFAULT if the ptr doesn't name a live allocation. |
| 64 | `SYS_ALARM` | vi-port slice 3: alarm(seconds). A.lo = seconds; 0 cancels any pending alarm. Returns A = previous alarm's remaining seconds (0 if none). SIGALRM gets delivered at the next syscall return after the timer expires. |
| 65 | `SYS_IOCTL` | FGX-specific: device control on a fd. |
| 66 | `SYS_POLLKEY` | FGX-specific: non-blocking key poll. C=1 + A=key if one is queued, else C=0. A.lo = fd, X = cmd, Y = arg-ptr lo16; arg-ptr bank pushed before COP. Returns C=1 (A=0) ok; C=0 (A = errno: ENOTTY for unknown cmd, EBADF for unknown fd). Routes through the FCB's FST FOP table (FOP_Ioctl). Non-chardev FSTs return ENOTTY. |
| 67 | `SYS_GETFSSTAT` | FGX: copy struct statfs[] for all online mounts into a caller buffer (BSD getfsstat). A = buf offset (caller bank), X = bufsize bytes, Y = flags (ignored). Returns C=1 + A = mount count written. |
| 68 | `SYS_MM_ALLOC` | FGX: large Memory-Manager allocation via _NewHandle (MAY span banks; for the resident NTP module). A = size lo16, X = size hi16. Returns C=1 + A.lo = handle bank, Y = handle offset (deref the handle for the 24-bit base); C=0 + A = ENOMEM. Block attr $C008 = locked\|fixed\|noSpec, NO attrNoCross so it can be >64 KB multi-bank. |
| 69 | `SYS_MM_FREE` | FGX: release a SYS_MM_ALLOC block. A.lo = handle bank, X = handle offset (_DisposeHandle). Returns C=1. |
| 70 | `SYS_IFCONFIG` | FGX net: get/set an interface record. A = ifreq offset, X = op (IFC_*), caller DBR = ifreq bank. See ifconfig_sys.s / include/ifnet.s. |
| 71 | `SYS_SOCKET` | BSD socket(domain,type,proto): A=domain, X=type, Y=proto -> A=fd. See socket.s. |
| 72 | `SYS_BIND` | bind(fd, sockaddr_in*, len) |
| 73 | `SYS_SENDTO` | sendto(fd, argblk*) [argblk: see socket.s] |
| 74 | `SYS_RECVFROM` | recvfrom(fd, argblk*) (non-blocking) |
| 75 | `SYS_SETSOCKOPT` | setsockopt(fd, level, optname, val*, len) |
| 76 | `SYS_CONNECT` | connect(fd, sockaddr_in*, len) [TCP] |
| 77 | `SYS_SEND` | send(fd, argblk*) [buf,len,flags] |
| 78 | `SYS_RECV` | recv(fd, argblk*) (blocking; MSG_DONTWAIT) |
| 79 | `SYS_YIELD` | yield() — cooperative reschedule (no args) |
| 80 | `SYS_SETPGID` | setpgid(pid, pgid) — job control. A = pid (0 = caller), X = pgid (0 = use pid). C=1 + A=0 ok; C=0 + A = ESRCH (no such pid). |
| 81 | `SYS_GETPGRP` | getpgrp(pid) — THAT process's group, as 2.11BSD's does. A = pid (0 = caller). C=1 + A = pgrp; C=0 + A = ESRCH (no such pid). |
| 82 | `SYS_WAITPID` | waitpid(pid, *status, options). A = pid (-1 = any child, >0 = that pid), X = status-ptr offset (0 = none), Y = options. C=1 + A = pid (reaped/stopped) or 0 (WNOHANG, nothing waitable); C=0 + A = ECHILD. |
| 83 | `SYS_NANOSLEEP` | nanosleep(ticks) — block the caller for A = duration in 60 Hz ticks (16-bit). Idle-blocks via _sleep(WCHAN_TIMER); C=1 + A=0 when the deadline passes; C=0 + A = EINTR if a signal woke it first. A=0 returns immediately. |
| 84 | `SYS_LISTEN` | listen(fd, backlog) — TCP server: OPEN the bound socket in TCP mode + LISTEN. A=fd, X=backlog (ignored, W5100 single-socket). C=1 + A=0 ok; C=0 + A=errno. |
| 85 | `SYS_ACCEPT` | accept(fd) — block until a peer connects; A=listen fd. C=1 + A = new connection fd (the listener's hw socket; listenfd is detached); C=0 + A=errno (EINTR on ^C). |
| 86 | `SYS_SOUND_CLAIM` | sound_claim() — caller claims the DOC, so the kernel runs Sound_StopDoc when the caller TERMINATES (audio stops on kill, keeps playing when backgrounded). C=1 + A=0. |
| 87 | `SYS_PROCS` | procs(buf,max) — process enumeration for ps and w; fills buf with PROCINFO_SIZE records {pid,ppid,pgid,state,name[16], stksize,stkhwm,arena_used,arena_free, heaphwm,ttyname[8]} (include/kernel.s PI_*), returns count. C=1 + A=count. |
| 88 | `SYS_PIPE` | pipe(fd[2]): X=&fd[2] -> fd[0]=read fd[1]=write; C=1 ok, C=0+A=errno (ENFILE/EMFILE/ENOMEM) |
| 89 | `SYS_DUP2` | dup2(old,new): A=old X=new -> A=new (closes new if open); C=1 ok, C=0+A=errno (EBADF/EMFILE) |
| 90 | `SYS_SLOTSCAN` | FGX: copy the boot slot-scan table into a caller buffer. A = buf offset (caller bank), X = bufsize bytes. Returns C=1 + A = bytes written (50), or C=1 + A=0 if bufsize < 50. byte0 = detected W5100 slot (0=none); bytes 1..49 = 7 records of {flags, sig[6]} for slots 1..7. |
| 91 | `SYS_REALLOC` | userland-libc: resize a SYS_MALLOC block, preserving contents. A.lo = old bank, X = old offset, Y = new size (bytes). NULL old ptr (bank=0,off=0) -> malloc. Returns C=1 + A.lo = bank, Y = offset (offset in Y not X: dispatcher exit clobbers handler-return X); C=0 + A = errno (ENOMEM: old block left intact, per the C realloc contract). |
| 92 | `SYS_MKDIR` | mkdir(path,mode): A = path (caller bank), X = mode, masked by the umask as Reno does. Returns C=1 + A=0, or C=0 + A=errno (EEXIST/ENOSPC/ENOTDIR/ENOENT/ EIO). |
| 93 | `SYS_UTIME` | utimes(path,times): A = path offset, X = offset of two 32-bit epoch times (atime, mtime), both in the caller's data bank. Returns C=1 + A=0, or C=0 + A=errno (ENOENT/EIO). |
| 94 | `SYS_RMDIR` | rmdir(path): A = path (caller bank). Returns C=1 + A=0, or C=0 + A=errno (ENOTDIR/ENOTEMPTY/ENOENT/ EIO/EBUSY). |
| 95 | `SYS_RENAME` | rename(from,to): A = offset of an argument block, +0 from and +4 to, each a far pointer. C=1+A=0, or C=0 + A=errno (EXDEV across filesystems). |
| 96 | `SYS_MALLOC32` | userland-libc: 32-bit-size malloc (train-2 M-4). A = size lo16, X = size hi16. Returns like SYS_MALLOC: C=1 + A.lo=bank + Y=offset (offset 0 = dedicated MM block), or C=0 + A=errno. SYS_MALLOC (#62) zero-extends into the same core. |
| 97 | `SYS_FSYNC` | train-3 F4: fsync(fd) — force this file's data + metadata to disk NOW. A.lo = fd. C=0+A=EBADF/EIO. |
| 98 | `SYS_SYNC` | train-3 F4: sync() — commit every open file's dirty state + bitmap. Always C=1 (errors latch per-FCB). |
| 99 | `SYS_SELECT` | select(nfds,rd,wr,ex,timeout) via a libc-marshalled argblk (A.lo=off). C=1+A=ready count / C=0+A=errno. |
| 100 | `SYS_SHUTDOWN` | shutdown(fd, how): A=fd, X=how. TCP half-close — SHUT_WR/RDWR send FIN (CR_DISCON, socket stays FIN_WAIT so recv still drains); SHUT_RD = no-op. C=1 ok / C=0+A=EBADF/ENOTSOCK. |
| 101 | `SYS_SCREEN_CTL` | screen_ctl(A): 1=claim/suspend the console flush (userland owns SHR), 0=release+repaint. Auto-released on task death (process.s). |
| 102 | `SYS_SIGSETMASK` | sigsetmask(mask): A=lo16, X=hi16 of the 32-bit BSD signal mask (bit s-1 blocks signal s -- the sigmask() convention, NOT the kernel's pending-bit layout). Masked signals stay PENDING and deliver when unmasked. Returns A=0. The old mask is tracked by the libc shadow (single-threaded per task). tcsh's pfork blocks SIGCHLD around fork+palloc -- without a real mask the sequential snapshot-fork delivers SIGCHLD at the fork syscall's own exit, BEFORE the parent records the pid (2026-07-27). |
| 103 | `SYS_FTRUNCATE` | ftruncate(fd, length): A=fd, X=length bits 0..15, Y=bits 16..23 |
| 104 | `SYS_UMASK` | umask(mask): A = new mask -> A = the PREVIOUS mask. BSD's number for this is 60, which SYS_DMESG already holds, so it lands FGX-local -- the same situation this file records for setgid. Masked to 07777 as 2.11BSD and Reno both do (ufs_syscalls2.c:205, vfs_syscalls.c:1635). (ProDOS EOF is 24-bit). Sets the file's LENGTH: a shorter length hides the tail from read(2) and stat(2); a longer one extends the file sparsely, reading as zeros. The file offset is NOT moved (POSIX). BLOCKS ARE NOT RECLAIMED -- see apple/fgx#68. C=1 ok / C=0+A=EBADF/EISDIR/EINVAL. |
| 105 | `SYS_GETRLIMIT` | getrlimit(res, *rlp): A=res, Y=rlp offset, DBR=rlp bank -> A=0 / errno |
| 106 | `SYS_SETRLIMIT` | setrlimit(res, *rlp): same shape |
| 107 | `SYS_SIGPAUSE` | sigpause(mask): A=lo16, X=hi16. Installs the mask, sleeps until a signal is actionable, and always returns C=0 + A=EINTR. |
| 108 | `SYS_GETPEERNAME` | getpeername(fd, sockaddr_in*): X=fd, A=sockaddr offset (caller bank). Writes a full SIN_SIZE record -- the 3-arg BSD form's namelen is libc's business, not the kernel's, which keeps this to the two registers SYS_CONNECT already uses. C=0+A=ENOTCONN unless ESTABLISHED. |
| 109 | `SYS_GETSOCKNAME` | getsockname(fd, sockaddr_in*): same shape. An UNBOUND socket answers 0.0.0.0:0 with C=1, as BSD does -- "no name yet" is not an error. |
| 110 | `SYS_MODLOAD` | FGX-specific: stream a module into |
| 111 | `SYS_LSTAT` | lstat(path,buf): A=path X=stat_buf(own-bank) -> C=1 ok; C=0+A=errno. stat(2) that does not FOLLOW a final symlink -- the only difference, as 4.3BSD-Reno's own lstat is stat's six lines with NOFOLLOW. |
| 112 | `SYS_READLINK` | readlink(path,buf,sz): A=path X=buf(own-bank) Y=size |
| 113 | `SYS_SYMLINK` | symlink(target,linkname): A=target X=linkname |
| 114 | `SYS_STATFS` | statfs(path,buf): A=path X=buf(own-bank) (both own-bank) -> C=1 ok; C=0+A=errno. The TARGET is contents, not a path to resolve -- see root_symlink. -> C=1 + A=byte count; C=0 + A=errno (EINVAL if not a symlink) a bank from userland. A = subcmd (0 begin, 1 data, 2 end), X/Y per subcmd. ONE syscall with a subcommand rather than three: each far-bank handler costs an 8-byte core stub plus a 2-byte dispatch entry, and the core bank has 43 bytes free. SYS_MEMINFO (61) is the precedent. Plan: docs/history/plans/ 2026-09-01-userland-modload.md B1. |
| 115 | `SYS_FCHDIR` | fchdir(fd): A=fd. UFS 2.7 -- chmod(1)/chown(8) -R save the starting directory with open(".") and return to it with this. |
| 116 | `SYS_REBOOT` | reboot(howto): A=howto (RB_*, see sys/reboot.h). DOES NOT RETURN on success -- the machine halts or cold-starts. C=0+A=errno only for a refusal before that point. 2.11BSD puts it at 55 (init_sysent.c:165) and that number is squatted by SYS_BORDER, so this is FGX-local -- the same call SYS_VFORK made when SYS_POLLKEY held BSD's 66. |
| 117 | `SYS_SYSCTL` | sysctl(name,namelen,old,oldlenp, new,newlen): A = caller-bank offset of libc's argument block, because six arguments do not fit three registers -- select(2) at 99 is marshalled the same way. It serves kern.securelevel, kern.clockrate, kern.boottime, the machdep node and the vm node (sysctl(3)); every other name is ENOTSUP. The block is twelve words (far/root_sysctl.c): a value of up to 8 bytes travels in it, a larger one the kernel copies to oldp, words 10 and 11. 2.11BSD puts __sysctl at 202 (init_sysent.c), above everything this table numbers, so this is FGX-local. |
| 118 | `SYS_GETLOGIN` | getlogin(buf, len): A = caller-bank offset, X = size. Copies the u-area's login name out; C=1 + A = bytes placed (0 = none set). |
| 119 | `SYS_SETLOGIN` | setlogin(name): A = caller-bank offset of a NUL-terminated name. SUPER-USER ONLY, which is 2.11BSD's own rule for a kernel with no sessions (usr/sys/sys/kern_prot.c:186). |
| 120 | `SYS_SIGPROCMASK` | sigprocmask(how, set, oset): A = new mask lo16, X = hi16, Y = how. C=1 + A = OLD mask lo16, Y = hi16 (the __syscall_y return-hi convention, as lseek uses); C=0 + A = EINVAL for an unknown how. Same routine as SYS_SIGSETMASK, whose callers already pass how = 0 (= SIG_SETMASK). This 2.11BSD carries sigprocmask as syscall 32 and marks 109/110 "(old sigblock)" / "(old sigsetmask)" (usr/sys/sys/syscalls.c). |
| 121 | `SYS_SETITIMER` | setitimer(which, itv, oitv): A = it_value SECONDS, X = it_interval SECONDS, Y = which. C=1 + A = the OLD counter's remaining TICKS lo16, Y = hi16 (the __syscall_y return-hi convention); C=0 + A = EINVAL for any `which' but ITIMER_REAL, or ESRCH with no current task. SECONDS IN, TICKS OUT is not a muddle: upstream's ITIMER_REAL is whole seconds in and libc divides the remainder, which is the only value the kernel holds at tick resolution. 2.11BSD stores `it_value = aitv.it_value.tv_sec' and merely increments it when any tv_usec is set (usr/sys/sys/kern_time.c:215-223). |
| 122 | `SYS_READV` | readv(fd, iov, iovcnt): A = fd, X = the iovec array (caller's DBR bank), Y = iovcnt. C=1 + A = bytes read; C=0 + A = EBADF, or EINVAL for iovcnt > 16 or a total over 32767. 2.11BSD's is 120, spent here on sigprocmask. |
| 123 | `SYS_WRITEV` | writev(fd, iov, iovcnt): as readv, writing. One uio and one fo_write for the whole vector (2.11BSD sys_generic.c rwuio). |
| 124 | `SYS_GETTIMEOFDAY` | gettimeofday(blk): A = a 12-byte block (caller's DBR bank) that gets tv_sec, tv_usec, tz_minuteswest, tz_dsttime. C=1 + A = 0. The kernel clock, UTC (tty/kern_time.c); 2.11BSD's is 116, FGX's SYS_REBOOT. |
| 125 | `SYS_ADJTIME` | adjtime(blk): A = a 16-byte block (caller's DBR bank): delta's tv_sec and tv_usec in, olddelta's out. Super user only. C=1 + A = 0; C=0 + A = EPERM. Slews the kernel clock (FreeBSD 2.2.8's rule). FGX's number; 2.11BSD's is 140. |
| 126 | `SYS_SETTIMEOFDAY` | settimeofday(blk): A = a 14-byte block (caller's DBR bank): a flags word (bit 0 = tv given, bit 1 = tz given), tv_sec, tv_usec, tz_minuteswest, tz_dsttime. Super user only. C=1 + A = 0; C=0 + A = EPERM. Sets the kernel clock and writes the battery clock back (FreeBSD resettodr). 2.11BSD's number. |
| 127 | `SYS_FCNTL` | fcntl(fd, cmd, arg): A = fd, X = cmd, Y = arg. C=1 + A = the value; C=0 + A = errno (EBADF, EINVAL, EMFILE). F_DUPFD, F_GETFD/F_SETFD (close on exec), F_GETFL/F_SETFL; F_GETOWN/F_SETOWN are EINVAL, FGX sending no SIGIO or SIGURG. 4.3BSD-Reno kern_descrip.c; 2.11BSD's number is 92. |
| 128 | `SYS_FLOCK` | flock(fd, how): A = fd, X = LOCK_SH/LOCK_EX/LOCK_UN, with LOCK_NB. C=1 + A = 0; C=0 + A = errno (EBADF, EOPNOTSUPP on a socket or pipe, EWOULDBLOCK, EINTR). The lock is the vnode's; 4.3BSD-Reno kern_descrip.c and vfs_vnops.c. 2.11BSD's number is 131. |
| 129 | `SYS_FCHOWN` | fchown(fd, uid, gid): A = fd, X = uid, Y = gid; -1 leaves an id alone. C=1 + A = 0; C=0 + A = errno (EBADF, EINVAL on a socket or pipe, EROFS, EPERM). 4.3BSD-Reno vfs_syscalls.c. 2.11BSD's number is 123. |
| 130 | `SYS_FCHMOD` | fchmod(fd, mode): A = fd, X = mode. C=1 + A = 0; C=0 + A = errno (EBADF, EINVAL on a socket or pipe, EROFS, EPERM). 4.3BSD-Reno vfs_syscalls.c. 2.11BSD's number is 124. |
<!-- END GENERATED: syscall-table -->

**Note on `SYS_TICKS`:** it returns the high word in **X** (it predates the
X-clobber-on-exit rule); new syscalls should return a high word in Y instead.

### 4.4 argv / envp

**`SYS_EXECVE`** takes `A` = the path (an offset in the caller's data bank) and
`X`/`Y` = the offset and bank of a two-entry argument block `{ argv, envp }`,
each a far pointer to a NULL-terminated vector of far pointers to strings.
That is 2.11BSD's `struct execa` (`vendor/2.11BSD/usr/sys/sys/kern_exec.c`),
and the kernel walks the caller's vectors in place as `fuword` does upstream;
an over-long list fails with `E2BIG`. libc's `execve` builds the block on its
stack (`toolchain/lib/libc_c/exec.c`). `SYS_POSIX_SPAWN` / `SYS_POSIX_SPAWNX`
take caller-bank vectors of 16-bit pointers; see their table entries.

The kernel lays argv/envp out on the new process's bank-0 stack in BSD shape:
`argc` at `S+1`, then `argv[i]` as 16-bit bank-0 pointers at `S+3+2i`, a NULL,
then the envp pointers and a NULL (read by `_libc_start`, section 5.1).

### 4.5 file_action wire format

`SYS_POSIX_SPAWNX` takes a `file_actions` pointer to an array of 6-byte
entries in the caller's bank, terminated by `op = 0` (`include/loader.s`,
`FA_*`):

| Offset | Field | Meaning                                                  |
|--------|-------|----------------------------------------------------------|
| 0      | op    | 0 = END, 1 = OPEN, 2 = CLOSE, 3 = DUP2                   |
| 1      | fd    | target fd in child                                        |
| 2..3   | arg1  | OPEN: own-bank path ptr; DUP2: srcFd                     |
| 4..5   | arg2  | OPEN: O_* flags; DUP2/CLOSE: ignored                     |

Actions apply to the child's fd table only.

### 4.6 Open flags

From `include/fs.s`:

| Symbol       | Value   | Meaning                                  |
|--------------|---------|------------------------------------------|
| `O_RDONLY`   | `$0000` | read-only                                |
| `O_WRONLY`   | `$0001` | write-only                               |
| `O_RDWR`     | `$0002` | read+write                               |
| `O_NONBLOCK` | `$0004` | non-blocking (4.3BSD-Reno `FNDELAY` value) |
| `O_APPEND`   | `$0008` | seek to EOF before each write            |
| `O_CREAT`    | `$0200` | create if absent                         |
| `O_TRUNC`    | `$0400` | truncate to 0 on open                    |
| `O_EXCL`     | `$0800` | with `O_CREAT`, fail if it exists        |

### 4.7 Preemption, safepoints, and the tty foreground group

Syscall handlers are atomic (never preempted mid-handler). Preemption is a
**reschedule request** honoured only at a scheduling boundary -- a syscall's
exit, or a loop safepoint:

- **The resched mirror.** The kernel publishes a user-readable flag at
  `KFGX_YIELD_MIRROR = $00:030A` (`include/memmap.s`). The heartbeat sets it on
  quantum expiry (`QUANTUM_TICKS` VBLs, `include/kernel.s`) and on keyboard
  input; the dispatcher clears it. Nonzero means "yield at your next
  opportunity".
- **Loop safepoints (fcc).** At the top of every `while`/`do`/`for` (and a
  backward `goto`) fcc emits `LDAL KFGX_YIELD_MIRROR / BEQ *+5 /
  JSR _fcc_safepoint`; `_fcc_safepoint` (`toolchain/lib/fcc_runtime.s`) makes a
  `SYS_YIELD`, so a compute-bound loop still reaches a boundary and both
  quantum fairness and signal delivery (^C on a hung loop) happen there. It
  saves nothing: it is emitted only where A and N/Z are dead; X/Y survive the
  context switch.
- **Hand-assembly loops** that spin without syscalls should poll the mirror the
  same way, or they cannot be interrupted. `fcc_runtime.s` defines the
  `SYS_YIELD` and `KFGX_YIELD_MIRROR` EQUs; companion assembly linked with it
  must not redefine them.
- **Tty foreground group.** When a shell has claimed the tty (`TIOCSPGRP`):
  ^C/^Z are consumed by the kernel and delivered as `SIGINT`/`SIGTSTP` to the
  foreground group; a **background** `SYS_READ` gets `SIGTTIN` (default stop)
  and `EINTR`; a background `SYS_POLLKEY` returns "no key" and yields. With no
  foreground group set, keys go to whoever reads first.

---

## 5. Process startup

### 5.1 crt0

A dynamic program (`fgx_dyn`, the default) enters at `_crt0_dyn`
(`toolchain/lib/crt0_dyn.s`): it acquires `libc.so.1` from the shared-library
registry (failing with "ld.so: libc.so.1 not loaded" if it is not resident),
copies libc's core into the program's data bank, runs libc's binder over the
program's import tables, and continues as `_crt0_lib`. A static program
(`fgx_static`) enters at `_crt0_lib` (`toolchain/lib/crt0_lib.s`) directly.
`_crt0_lib`:

1. sets `MX = %00` and seeds the soft-frame pointer (unless the loader did) and
   the program's `_fcc_dbr` from DBR;
2. calls libc's `_libc_start` (`toolchain/lib/libc_start.s`), which copies the
   kernel's argv frame (section 4.4) into `args_argc` / `args_argv[]`, sets
   `__progname`, packs the environment into `args_env` and points `environ` at
   it, stashes the data bank at DP `$B8` for signal delivery, and records
   `_sig_tramp`'s offset;
3. calls `_crt0_inits` (each linked library's `_lib_init`), then `main`;
4. on return from `main`, flushes stdio and exits with `main`'s return value
   (`SYS_EXIT`).

### 5.2 argc / argv / environ

fcc binds `main`'s parameters in its prologue: `argc` from `args_argc`, `argv`
to `&args_argv[0]`, a real `char **` of 4-byte entries (`parse_stmt.c`). The
storage is in `toolchain/lib/args_data.s`.

The kernel stages at most `LSARGV_MAX` = 16 argv entries and 16 envp entries
per exec into the new stack (`src/kernel/far/loader.s`); a string that does not
fit makes the exec fail with `E2BIG`. libc's capacities match
(`tools/check_argv_caps.py` holds `ARGS_MAX` equal to `LSARGV_MAX`):

| Cell | Capacity |
|------|----------|
| `args_argv` | `ARGS_MAX` = 16 entries (`toolchain/lib/args.s`, mirrored in `libc_start.s`) |
| `args_env` | `ARGS_ENV_MAX` = 256 bytes of packed `NAME=value` strings; an entry that does not fit ends the copy |
| `args_envv` / `environ` | `ARGS_ENVV_MAX` = 32 entries |

---

## 6. The C library

### 6.1 Where it lives

| Part | Source |
|------|--------|
| C functions (stdio, string, stdlib, syscall wrappers, signals, sockets, ...) | `toolchain/lib/libc_c/*.c`, one translation unit through `libc_c/libc_c.c`. Ported files are registered in `docs/PROVENANCE.md`. |
| The parts 2.11BSD also writes in assembly | `toolchain/lib/libc.s`: `getpid`, `vfork`, `setjmp`, `longjmp` |
| Program startup | `toolchain/lib/libc_start.s` (`_libc_start`, `_libc_sigtramp`) |
| Data cells | `toolchain/lib/libc_data.s`, `args_data.s`, plus the data segment fcc emits for `libc_c` |
| Syscall-wrapper macros for hand assembly | `toolchain/lib/fcc_libc_shims.s`: `SYSCALL_PTRARG` (swap DBR to a pointer argument's bank for the syscall), `SYSCALL_ERR` / `SYSCALL_ERRSW` (store the errno and return the error value), and the DP cells `c_strcmp_a` / `c_strcmp_b` (`$F2-$F7`). It defines no functions. |
| Headers | `toolchain/include/` |

The other libraries follow the same pattern: `libcurses_c/`, `libtermlib_c/`,
`libfgx_c/`, `libutil_c/`, and `libdouble/` (the soft double) and `libllong/`
(`long long`) under `toolchain/lib/`.

### 6.2 Calling convention

libc's C functions are ordinary cc-target functions (section 3.6), called by
`FGX2_FARCALL` under their own names (`strlen`, `fopen`, `printf`). Variadic
functions such as `printf` take their arguments as C varargs on the stack.
Of the four routines in `libc.s`, `setjmp`/`longjmp` are the builtins of
section 3.6; `getpid` and `vfork` take no arguments and return in A, so a C
caller reaches them like any other function. A hand-assembly caller of a C libc function pushes
its arguments as section 3.6 describes.

### 6.3 Shared libraries

| Library | On disk | Built from |
|---------|---------|------------|
| libc | `/lib/libc.so.1.0` | `toolchain/lib/libc_c/` (`fcc --libso --sections`) |
| libcurses | `/lib/libcurses.so.1.0` | `toolchain/lib/libcurses_c/` |
| libtermlib | `/lib/libtermlib.so.1.0` | `toolchain/lib/libtermlib_c/` |
| libfgx | `/lib/libfgx.so.1.0` | `toolchain/lib/libfgx_c/` |
| libutil | `/lib/libutil.so.1.0` | `toolchain/lib/libutil_c/` |

(`toolchain/Makefile`; staged by `tools/ninja/manifest.json`.) A shared library
is an FGX3 file with header flag bit 1 and a trailer of exports, member blocks
and per-process fixups (`toolchain/src/ld/fgx_ld.py`).

At boot `/etc/rc` loads `ld.mod` (`src/modules/ld/ld.s`, the shared-library
registry, reached by `SYS_LDCTL`) and then runs `ldload(8)`
(`src/userland/ldload/ldload.c`), which makes libc resident and then each
library `/etc/ld.so.conf` lists; any other library loads when a program first
needs it. A dynamic program binds to the resident libraries at exec through
`crt0_dyn` (section 5.1); a static program (`"static": true` in
`tools/ninja/manifest.json`) carries the library functions it reaches,
collected by `fgx_gc.py` (`docs/fgx2-linker.md`).

### 6.4 Direct-page cells

libc and the runtime claim the top of the task's direct page; the authoritative
map is the header of `toolchain/lib/fcc_runtime.s`. Hand-written code must not
keep state in these across a libc call:

| DP        | Owner                                      |
|-----------|--------------------------------------------|
| `$78-$97` | `_fcc_img16..31`, the callee-saved band: preserve it |
| `$98-$B7` | `_fcc_fpr0..7`, far-pointer registers (`_fcc_fpr0` is every pointer return) |
| `$B8`     | `_LS_DATA_DP`, the task's data bank (`libc_start.s`) |
| `$B9-$BF` | `_fcc_stkfloor`, `_fcc_fb`, `_fcc_sfp`     |
| `$C0-$DF` | promoted-local register file               |
| `$E0-$E3` | `args.s` scratch                           |
| `$E4-$ED` | `LIBC_DP_SRC/DST/TMP/LP0` (`libc.s`), overlapping `_fcc_ptr` and `_fcc_long_hi` |
| `$EE-$FF` | runtime scratch, `c_strcmp_a/b` (`$F2-$F7`), `_fcc_fp`, `_fcc_ptr2` |

---

## 6A. Signal handlers -- delivery model and the reentrancy contract

**Delivery is synchronous, at syscall exit.** `_Sys_CheckSignal`
(`src/kernel/signal.s`) runs in the dispatcher's return path, so a handler only
ever runs at the boundary of a syscall the task made (including the
`SYS_YIELD` of a loop safepoint, section 4.7). The kernel enters the program's
`_sig_tramp` (`crt0_lib.s`, segment 0), which jumps to libc's
`_libc_sigtramp` (`libc_start.s`); that restores DBR to the task's data bank
from DP `$B8`, calls the C handler as a normal far call with the signal number,
and restores the interrupted syscall's A/Y/carry before resuming. Every signal
except `SIGKILL` and `SIGSTOP` can be caught (`src/kernel/signal.s`).

**THE LANDMINE -- libc and the runtime's DP scratch are NOT reentrant.** The
trampoline preserves the syscall return registers and DBR, and nothing else.
When a handler runs, the interrupted libc function may hold live state in the
DP cells of section 6.4 and in libc's data cells (stdio buffers, the `FILE`
table, static result buffers). A handler that touches them corrupts the
interrupted call's result.

**The contract for handler bodies** (the classic BSD `sig_atomic_t`
discipline):

- **DO**: set a plain `int`/`char` file-scope global flag and return. The
  runtime-verified shape is the multibank sweep's `c29_handler` fixture
  (`toolchain/tests/multibank/`):

  ```c
  int got_sigint = 0;
  void trapint(int sig) { got_sigint = 1; }   /* poll the flag in main */
  ```

- **DON'T**: call libc (printf, fopen, malloc, str*/mem*), do pointer /
  `long` / float arithmetic (these use the DP scratch and the FPR band), or
  call `exit()`. The failure is silent corruption of the interrupted call, not
  a crash at the handler.

`longjmp` out of a handler restores the signal mask (section 3.6), which is
what BSD's `onintr`-style handlers rely on; it is still subject to the
reentrancy rule above if the interrupted code was inside libc.

**Porting note.** BSD sources often `fprintf` and `longjmp` from their SIGINT
handlers (`ed`'s `onintr`, `more`, ...). Where the interrupted code can be
inside libc, convert the handler to a flag-set and move the response to the
main loop's next poll point -- see `userland-bsd-ports.md`.

---

## 7. Errno values (excerpt)

From `include/errno.s` (2.11BSD numbering, `vendor/2.11BSD/usr/sys/h/errno.h`;
C programs see the same values through `toolchain/include/errno.h`):

| Number | Name      | Meaning                                  |
|--------|-----------|------------------------------------------|
| 1      | `EPERM`   | not permitted                            |
| 2      | `ENOENT`  | no such file or directory                |
| 4      | `EINTR`   | interrupted system call                  |
| 5      | `EIO`     | I/O error                                |
| 8      | `ENOEXEC` | exec format error                        |
| 9      | `EBADF`   | bad file descriptor                      |
| 10     | `ECHILD`  | no child processes                       |
| 11     | `EAGAIN`  | resource temporarily unavailable (`EWOULDBLOCK`) |
| 12     | `ENOMEM`  | out of memory                            |
| 13     | `EACCES`  | permission denied                        |
| 14     | `EFAULT`  | bad address                              |
| 16     | `EBUSY`   | resource busy                            |
| 17     | `EEXIST`  | file exists                              |
| 20     | `ENOTDIR` | not a directory                          |
| 22     | `EINVAL`  | invalid argument                         |
| 23     | `ENFILE`  | file table overflow                      |
| 24     | `EMFILE`  | too many open files                      |
| 25     | `ENOTTY`  | inappropriate ioctl for device           |
| 29     | `ESPIPE`  | illegal seek                             |
| 30     | `EROFS`   | read-only file system                    |
| 32     | `EPIPE`   | broken pipe                              |
| 78     | `ENOSYS`  | function not implemented                 |

---

## 8. Required reading for compiler and runtime authors

- `docs/calling-conventions.md` -- kernel-side rules.
- `docs/memory-map.md` -- full bank table, bank-0 layout, stacks.
- `docs/coding-standards.md` -- what hand-written FGX assembly looks like.
- `include/loader.s` -- binary header layouts, syscall numbers, the user-bank
  pool.
- `include/fs.s`, `include/errno.s` -- open flags, errnos, file structures.
- `toolchain/lib/fcc_runtime.s` -- the runtime helpers fcc calls and the
  direct-page map.
- `toolchain/lib/{crt0_lib,crt0_dyn,libc_start,libc}.s` -- the hand-written
  startup and libc assembly a program links against.
- `docs/fgx2-linker.md` -- the link pipeline, the FGX2 macros, and
  `toolchain/src/ld/fgx_ld.py`.

---

## 9. ABI versioning

The current ABI is **v2** -- `FGX_ABI_CURRENT = 2` in `include/loader.s`
("32-bit ptr model, hw stack, kernel ABI v2"), stamped at byte 13 of every FGX3
binary. The loader refuses an FGX3 binary whose stamp differs, so a binary built
for another ABI is rejected rather than mis-run.

A breaking change to any of these bumps `FGX_ABI_CURRENT` (and with it the
stamp `fgx_ld.py` writes):

- syscall numbers or signatures;
- the crt0 entry contract or the argv frame layout;
- the FGX2/FGX3 header, segment-table or reloc-record layout;
- the cross-segment reference shapes (`FGX2_FARCALL`, `FGX2_LONG_PTR`, and the
  reloc each produces);
- the cc-target convention (section 3.6): pointer width, argument order,
  return-value locations, `jmp_buf` layout;
- the shared-library trailer or binding contract.

Non-breaking changes (new syscalls up to a raised `SYS_NUM_MAX`, new libc
functions, new errno values) stay within the current ABI.
