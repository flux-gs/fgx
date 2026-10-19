# fpsim: the soft double as a system service (apple/fgx#447)

Decided by the maintainer on 2026-09-24. This replaces the plan to link the soft double
into each program. Parent plan: `2026-09-23-fcc-64bit-double-plan.md`,
increments 6 and the flip.

## 1. Why it cannot live in each program

fcc's compile of the llvm-mos soft double (`lib/libdouble/softdouble.c`) is
20,923 bytes. A tool's libc pile is one 64 KB bank that must stay reloc-free.
Linking the soft double into the pile was tried on a scratch tool. It worked on
FGX, but it overflows the pile bank of most tools that use double:

| Tool | Pile today | With the runtimes |
|---|---:|---:|
| df | 47,772 | ~70 KB |
| frotz | 47,100 | ~69 KB |
| ensoniqplay | 43,352 | ~65 KB |
| fractal | 42,445 | ~64.5 KB |
| od | 42,325 | ~64.4 KB |
| tcsh | 64,500 | full already, and `sh.func.c` uses `atof` |

Putting it in each tool's code banks instead costs every program ~21 KB, and
tcsh has almost no bank headroom.

## 2. What 2.11BSD does

Read from `vendor/2.11BSD` and `examples/2.11BSD`:

- **libc is static, linked per object.** Large programs use text overlays
  (`ld -Z`), with libc in the resident base. tcsh's Makefile links
  `$(BASE) -Z $(OV1) ... -Z $(OV7) -Y -ltermcap -lc`, and `kern_exec.c:101-103`
  loads the overlay formats. FGX's pile and code banks have the same shape.
- **Floating point is never in the program.** `double` compiles to FP11
  instructions. On a machine without an FPU they trap, and `trap.c:128` sends
  `T_INSTRAP` to `fptrap()` in `usr/sys/pdp/mch_fpsim.s`, "Kernel floating
  point simulator". It is one copy, in the kernel, outside every address space.
- **With no simulator, the program gets SIGILL:** `trap.c` sets
  `i = SIGILL; u.u_code = ILL_RESAD_FAULT; /* it's simplest to lie */`. The
  simulator itself reports FP errors as SIGFPE (`mch_fpsim.s:273`).
  `conf/GENERIC` notes FPSIM "doesn't work at present".

## 3. The design

### 3.1 The vector

A 4-byte `JML` cell at bank-0 `$0324`, renamed from `COP_TRAMP` to
`FPSIM_TRAMP`.

- `COP_TRAMP` is declared "installed at boot", but nothing writes or reads it.
  The BRK/COP trap plan (2026-09-20) puts its handler at `$FF00` and does not
  use the cell.
- A call is `JSL FPSIM_TRAMP`. It has an absolute bank-0 target, so it needs
  no relocation and the pile can make it, exactly like `JSL SYS_TRAMP`.

### 3.2 The call protocol

Each operand is 64 bits in four words:

| Word | Carrier | Operand B | Where it lives |
|---|---|---|---|
| w0 | A | `_fcc_long_b_lo` | A / direct page `$EE` |
| w1 | `_fcc_long_hi` | `_fcc_long_b_hi` | direct page `$EC` / `$F0` |
| w2 | `_fcc_q2` | `_fcc_qb2` | the program's data bank |
| w3 | `_fcc_q3` | `_fcc_qb3` | the program's data bank |

The module runs on the caller's direct page and stack, so w0 and w1 cross the
call as they are. w2 and w3 live in the caller's data bank, and their addresses
differ in every binary, so the module cannot read them.

**User side**: `lib/libdouble/d_stub.s`, the `double` archive's only member.
Each `_fcc_d*` entry:
- pushes `_fcc_qb3`, `_fcc_qb2`, `_fcc_q3`, `_fcc_q2`;
- loads the operation number into X;
- calls `JSL FPSIM_TRAMP`;
- stores the returned X and Y into `_fcc_q2` and `_fcc_q3`;
- drops 8 bytes and returns with A.

Members are selected into the tool's pile by the archive walk (`PILE_LIBS`),
together with any llong members, at a few hundred bytes per tool.

**Module side**: `fpsim_entry`:
- `PHB/PHK/PLB`;
- copies the four stacked words into the module's own `_fcc_q2` ... `_fcc_qb3`;
- dispatches on X to the `d_glue.s` entry, which is unchanged;
- then `LDX _fcc_q2; LDY _fcc_q3; PLB; RTL`, with w0 in A and w1 in
  `_fcc_long_hi`.

### 3.3 Why one shared copy is safe

This is the same argument the parent plan made for SANE:

- A task switches only at a syscall or an fcc loop safepoint
  (`docs/scheduler.md`, "Model A").
- Signals are delivered only on syscall return.
- The runtime is built `-fno-safepoints` and makes no syscall except its
  stack-overflow exit.

So a call runs to completion, and the module's data (scratch, llong cells,
carrier copies) is never shared by two calls at once. IRQ handlers do not use
it.

### 3.4 The module, `fpsim`

A `src/modules/fpsim` module, appended to the shared module bank after klog
(about 40 KB free there). It needs no kernel addresses, so its build id is
`$0000`. It is laid out like the retired hellokc C module and ufsprobe:
- the header and `mod_init`;
- `fpsim_entry`;
- `d_glue.s` and `softdouble.s`, which already compile `--pile -fno-safepoints`
  and pile-call the llong routines;
- the llong members;
- `fcc_rt.s` for the near `_fcc_long_*` helpers;
- a user-context stack-overflow trap (`SYS_EXIT` 134 through `SYS_TRAMP`, as
  `fcc_runtime.s` does), not the kernel's `fcc_ktrap.s`;
- the data files.

`mod_init` writes `$5C` and the entry's address and bank (`PHK`) into
`FPSIM_TRAMP`, as `_Sys_InstallVectors` does for `SYS_TRAMP`. `/etc/rc.in` and
`modload.conf` load it, and `gen_modplace.py` appends it.

### 3.5 When the module is absent

At boot the kernel points `FPSIM_TRAMP` at a far-bank stub, which has 1,567
bytes free (the core bank has 5). The stub is called in the user's own context,
so it does what a program would do:
- `kill(getpid(), SIGILL)` through `SYS_TRAMP`;
- delivered on that syscall's return, with SIGILL's default action,
  termination.

That is 2.11BSD's behaviour with no FPU and no FPSIM. A program that catches
SIGILL and returns gets an undefined result, as on BSD.

## 4. Increments

Each is gated.

- **F1. The vector and its default.**
  - `FPSIM_TRAMP` in `memmap.s`, with the `kernel.s` mirror and `ERR`. The
    user side's one caller, `d_stub.s`, defines the EQU itself.
  - The far-bank SIGILL stub, installed at boot.
  - A program calling the vector with no module must die of SIGILL.
- **F2. The module.**
  - `src/modules/fpsim`, the build edges, the rc and modload.conf lists, and
    modplace.
  - `mod_init` installs the vector.
- **F3. The user side.**
  - `d_stub.s` replaces `d_glue.s` and `softdouble.s` in the `double` archive.
  - M41's wrappers PUT the stub.
  - The pile placement of `llong`/`double` from this session's work.
  - Check: every long double fixture passes on FGX through the module, and a
    scratch tool that uses long double links through the LIBC gate and runs.
- **Done, 2026-09-24.**
  - F1: a program calling the vector with no module was killed by SIGILL;
    bsh reported "Illegal instruction", status 132. A scratch check: the
    module loads at every boot, so no permanent test reaches this path.
  - F2: the module is 25,141 bytes at `$6100` in the shared bank, with
    14,965 bytes left there.
  - F3: the long double fixtures pass on FGX through the module.
    - Swapping two of its dispatch entries fails `ldouble_arith` at check 4.
    - A scratch tool that uses long double linked through the LIBC gate and
      ran correctly. Its pile was 40,306 bytes, against 61,457 with the soft
      double inside it.
- Then **increment 6** (2.11BSD `ecvt`/`fcvt`/`atof`, printf's `%e/%f/%g`
  behind the `__lc_fltused` switch), then **the flip**.

## 5. Open points

- Performance: every operation adds a `JSL`/`JML`, a DBR switch and 8 bytes of
  copying, a few dozen cycles against roughly 1,000 for a multiply.
- The module is single-copy, so its scratch must not be touched by an IRQ
  handler. None calls it.
- Kerberos and NTP (#447's consumers) run after `/etc/rc`, so the module is
  loaded. `init`, `sh /etc/rc`, `getty`, `login` and `fsck` use no double.
