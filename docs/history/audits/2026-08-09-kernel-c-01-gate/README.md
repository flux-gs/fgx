# The 0.1 gate -- what fcc makes of real filesystem code

The UFS campaign's phase 0.1 gate. It exists to be able to overturn the
decision to write the filesystem in C, so it measures real BSD sources rather
than a sketch, and it reports the number that came out rather than the number
that was hoped for.

Subjects, both compiled with the kernel-C seam's flags (`-fno-safepoints`):

| file | source |
|---|---|
| `bmap.c` | **2.11BSD's `ufs_bmap.c`**, body verbatim. The PDP-11 `mapin`/`mapout` overlay calls are dropped (FGX buffers are directly addressable) and nothing else is touched. 2.11BSD rather than Reno because `bmap` is coupled to the on-disk format, and the format is 2.11BSD's. |
| `vnops.c` | The **Reno vnode layer's shape**: a 32-entry `vnodeops` vector dispatched as `(*vp->v_op->vn_xxx)()`, plus `vget`/`vput` with the reference count and free-list handling. |
| `fsgate.h` | Just enough kernel to compile. Sizes are 2.11BSD's -- 16-bit `ino_t`, 32-bit `daddr_t`, 4 direct + 3 indirect. |

Measured by PUTting the compiled output into the far bank and reading the
per-file byte totals out of the build listing -- the same listing the ceiling
check reads, so the numbers are the real emitted image and not an estimate.

## Results

### Stack: PASSES, and comfortably

This was the binding question, because kernel C runs on a **256-byte per-pid
kernel stack** (`FGX_STK_KTASKS + (pid<<8)`, canary at the page bottom).

```
vop_bmap   frame  0 B  + saved frame base 2 + JSL return 3  =   5 B
bmap       frame 28 B  + saved frame base 2 + JSL return 3  =  33 B
                                         chain total  =  38 B of 256
```

Every vnode-layer frame is **zero bytes** -- `vop_bmap`, `vop_read`, `vget` and
`vput` all spill nothing. `bmap`, the largest single routine in the block-map
path, is 28.

The earlier worry was misplaced but for the right reason. What kills the stack
is not depth, it is a single function with a local AGGREGATE: the two deepest
frames in the shipped C userland are 262 B and 264 B, each larger than the
whole page. Neither subject here declares one, and that is not luck -- BSD puts
those buffers in the u-area, which is exactly the discipline that keeps this
number at 38.

**Rule this gate establishes: no local arrays or structs in kernel C.** It is
2.11BSD's own rule, and it is worth a build-time check rather than a comment.

### Size: DOES NOT FIT IN ONE BANK

```
bmap.c      2480 B      one function, ~130 lines of C
vnops.c     1311 B      four functions (2 dispatchers, vget, vput)
fcc_rt.s    3564 B      fcc's runtime -- paid ONCE, already resident
```

The far bank has 45,075 bytes free with the runtime already in it. A full
UFS plus VFS is on the order of 40-60 functions of this kind; at the measured
rate that is somewhere between 40 KB and 150 KB. **One bank does not hold it.**

This does not overturn C, but it does settle an open question in the campaign
plan: filesystem types cannot be "kernel proper". They have to be **preloaded
FGXM banks** -- which is what the plan already says for the filesystem types,
and now has to say for the VFS core too, or the two have to be split across
banks deliberately rather than by accident.

### What drives the size -- MEASURED, correcting a wrong first answer

The first version of this report blamed the 32-bit `daddr_t` helper calls and
called inlining `_fcc_long_from_int` the biggest lever. **Both claims were
wrong**, and bucketing the emitted bytes says so:

| | bytes | share |
|---|---:|---:|
| plain ALU, loads and stores | 1040 | 41.9% |
| **DP register-file traffic** (`_fcc_fpr*`, `_fcc_ptr`, `_fcc_long_hi` ...) | **634** | **25.6%** |
| **frame-slot access** (`n,S`) | **362** | **14.6%** |
| all subroutine calls | 188 | 7.6% |
| &nbsp;&nbsp;...of which the long helpers | 105 | 4.2% |
| data and other | 156 | 6.3% |
| branches | 76 | 3.1% |
| MX mode switches | 24 | 1.0% |

The long helpers are **4.2%**, not "most of it". And inlining them makes the
binding constraint WORSE, because a call is the compact encoding here:

```
_fcc_long_from_int call sites in bmap : 21
  as a JSR                            :  3 B each =  63 B
  cheapest correct inline sequence    : 11 B each = 231 B
    (LDX #0 / CMP #$8000 / BCC +1 / DEX / STX _fcc_long_hi)
  NET                                 : +168 B on a 2480 B function (+6.8%)
```

The helper itself is 14 bytes and is paid once. Inlining trades 168 bytes of
image for about 12 cycles per conversion -- the wrong direction when the gate's
own finding is that size, not speed, is what does not fit.

**The real lever is 40% of the function: DP register-file traffic plus frame
slot access.** fcc materialises intermediates through the direct page and the
stack frame rather than keeping them in registers across a statement. That is
register allocation, not helper calls, and it is a much larger and more
interesting piece of work than the one this report first recommended.

## Not yet measured: cycles

The gate's third measurement needs a running benchmark and is not done. It is
the one remaining input, and it is the least likely to change the decision:
the FS layer is dominated by SmartPort block latency, not by arithmetic.

## Verdict

C is viable for the filesystem. The stack fits with room to spare, subject to
a no-local-aggregates rule that BSD already follows. The size does not fit one
bank and the campaign's bank plan has to account for that up front rather than
discovering it at 40 KB.

Do NOT inline the long helpers -- measured, it costs 168 bytes to save 12
cycles a call, against a size constraint and not a speed one. If code size is
to be attacked at all, the target is the 40% of the function spent shuttling
intermediates through the direct page and the stack frame.

## Reproducing these numbers

`gate.link.s` + `gateseg.s` assemble the subjects standalone, so a
measurement does not require touching the kernel build:

```
cd docs/history/audits/2026-08-09-kernel-c-01-gate
../../../../toolchain/fcc -fno-safepoints -I . -o bmap.s bmap.c
../../../../toolchain/fcc -fno-safepoints -I . -o vnops.s vnops.c
merlin32 -V gate.link.s          # NOTE: -V is a flag, it takes no directory
```

Then bucket `_Output.txt` by source file -- the filename is the
second-to-last token of the file column, and the byte count is the `Size`
column. Cross-checked against the far-bank build: both report `bmap.s` at
**2480 B** exactly, so the standalone figure is the same number by a cheaper
route.

Two traps met while building this, both of which produce a listing full of
`00/FFFF` and no image:

- `merlin32 -V . gate.link.s` treats `.` as the master source file. `-V` takes
  no argument.
- The subjects need `fcc_dp.s`, `fcc_rt.s`, `fcc_ktrap.s` and the toolchain's
  `fcc_runtime_data.s` in the link, or the first `PEI _fcc_fb` fails to decode.
