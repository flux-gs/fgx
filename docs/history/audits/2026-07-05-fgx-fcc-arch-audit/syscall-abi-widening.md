# Follow-up: syscall-ABI widening enumeration (_Sys_CallerBank)

> Part of the 2026-07-05 FGX/fcc architecture audit. Question: keep the
> single-implicit-bank syscall ABI (`_Sys_CallerBank` = caller's DBR at the
> JSL) + bank-honoring shims, or widen pointer args to full 24-bit far
> pointers? Enumerate what widening touches.

## _Sys_CallerBank consumers

Definition/capture: `src/kernel/syscall.s:378` / `:131-140`. Per-task
save/restore across blocked syscalls exists (`src/kernel/sched.s:208-272`,
`SE_CallerBank`). A **parallel second mechanism** already exists for deferred
writes: `TCB_DataBank` (`src/kernel/process.s:112,1089`) persists the caller's
data bank so waitpid status can be written after the caller's syscall context
is gone — evidence the single-bank capture already needed structural
workarounds.

**39 consumption sites across 7 files → 31 distinct syscalls.** Highlights:

- READ/WRITE (buf), OPEN/UNLINK/CHDIR/STAT/LISTDIR/EXECVE/SPAWN/SPAWNX/FONTLOAD
  paths via shared helper `_Sys_CopyPathToBuf` (syscall.s:1675-1682).
- Buffer-filling: STAT dst (2nd ptr!), GETCWD, LISTDIR dst (2nd ptr!), UPTIME,
  TICKS, KSTAT, DIAG, FONTNAME, DMESG, MEMINFO, PROCS, PIPE fd[2], SLOTSCAN,
  GETFSSTAT, BPF read-tap.
- Net argblk family: IFCONFIG, BIND, CONNECT, SENDTO (argblk AND the buf it
  points to — nested, same bank forced), RECVFROM (argblk + buf + *from — 3
  objects, one bank), SEND, RECV.
- EXECVE/SPAWN argv+envp: nested 16-bit ptr arrays, bank implied
  (loader.s:1137,1165); SPAWNX file_actions embed own-bank path ptrs
  (process.s:646).
- IOCTL: ABI doc says "bank pushed before COP" — never implemented; falls back
  to CallerBank (syscall.s:1325-1329).

**2+ pointer syscalls (inexpressible today): 9** — STAT, LISTDIR, EXECVE,
POSIX_SPAWN, POSIX_SPAWNX (each ≥2 direct ptrs), plus the argblk family
(SENDTO/RECVFROM/SEND/RECV) that *exists because* the ABI couldn't express
multiple pointers. Plus 3 nested-pointer wire formats (argv/envp arrays,
file_actions) whose 16-bit entries inherit the single bank.

## Shim audit (fcc_libc_shims.s) — caller-buffer-bank rule sweep

Verdicts: **a** = uses pushed far-ptr bank; **b** = assumes DBR (BUG);
**c** = DBR-swap around syscall (correct).

Correct (12+): c_fread/c_fwrite (with the stash-DP-before-swap hazard at
552-557), c_read/c_write, c_open/c_creat/c_unlink, c_stat (a+c — the one the
ledger verified), c_gtty/c_stty, c_getfsstat/c_ifctl/c_slotscan, c_ticks,
c_fopen/c_freopen/c_fputs/c_perror, c_getenv, c_atol, c_tget*, str*/mem*,
c_malloc/c_free/c_realloc (the far-ptr syscall precedent — bank in A.lo).

**Latent bugs (verdict b, 9):**

| Shim | Line | Defect |
|---|---|---|
| c_pipe | 1520 | bank at 5,S ignored; comment admits "fd MUST be… data bank"; soft-stack local `int fd[2]` breaks |
| c_bind / c_connect | 1334/1444 | "addr bank ignored" |
| c_sendto | 1374 | buf bank at 15,S dropped |
| c_recvfrom | 1423 | buf AND from banks dropped; kernel *writes* both |
| c_send / c_recv | 1461/1482 | buf bank dropped ("SINGLE-BANK shims" header admission) |
| c_system | 1288 | cmd bank ignored (documented) |
| c_atoi | 848 | offset→DBR-relative; c_atol was fixed (860), atoi wasn't |

Missing entirely: c_getcwd, c_listdir, c_gets, c_fstat, c_wait(pid).

Score: 12 swap correctly, 1 mixed, **9 latent wrong-bank bugs**. The
caller-buffer-bank rule was verified for c_stat only; the socket family +
pipe + atoi fail it today.

## Blast radius

- **Kernel:** 31 handlers, heavily funneled (9 path syscalls share one helper;
  nearly every site is the identical `LDA _Sys_CallerBank / STA _libcTmp2+2`
  pair). 39 mechanical edits + dispatcher capture + sched.s widening +
  TCB_DataBank unification. Small, boring, greppable.
- **Register room: NO for uniform 3×24-bit** (72 > 48 bits). Per-syscall spare
  bytes cover almost everything (STAT: Y unused; OPEN: Y unused; READ/WRITE:
  A.hi free; etc.). Precedent: MALLOC/FREE/REALLOC bank-in-A.lo
  (syscall.s:4233-4300). Only LISTDIR (all 3 regs used) and EXECVE/SPAWN/SPAWNX
  (3 ptrs + nested arrays) genuinely need an arg-block or pushed-args
  convention — and the dispatcher already reads the user stack
  (`_Sys_UserSP`), so pushed-bank-words-before-JSL is cheap (it was the
  documented-but-unimplemented ioctl design).
- **Userland cost is where full-widen dies:** 268 hand-asm `JSL SYS_TRAMP`
  sites across 121 files + 21 in libc.s need bank-byte discipline on a
  flag-day. Shim side: 12 swap shims simplify; 9 broken shims become trivially
  correct (they already have the bank on their stack — today they discard it).
- **Compat:** no clean sentinel — bank $00 is a real user bank; $FF (ROM)
  could work; or ABI-v2 flag day (the repo rebuilds world every release).

## Recommendation: hybrid

**Widen only the 9–11 multi-pointer/deferred-write calls** (STAT + planned
FSTAT, LISTDIR, EXECVE, POSIX_SPAWN/SPAWNX via far-ptr arg-blocks; add bank
bytes to the socket argblk; WAIT/WAITPID status far ptr in TCB, subsuming
TCB_DataBank). **Keep CallerBank for the 22 single-pointer calls** — one
pointer ⇒ one bank ⇒ the shim DBR-swap is semantically exact and proven.
**Kill the shim bug class separately** with one shared `SYSCALL_PTRARG` macro
(bank from n,S → PLB → call → restore) replacing ~12 hand-rolled copies, and
write the 9 missing/broken shims through it.

Rationale: only 9 of 31 consumers are genuinely inexpressible; the hybrid is
additive (spare bytes / added argblk fields — old wire formats keep working
per-syscall, no sentinel needed); and the actual recurring bug generator is
the hand-rolled PHB/PLB discipline, fixed at zero ABI cost by the macro.
