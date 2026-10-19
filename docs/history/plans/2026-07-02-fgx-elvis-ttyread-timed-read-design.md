# FGX elvis `ttyread()` timed console read — scoped design

**Status:** DESIGN ONLY (not built). Scoped 2026-07-02 during the elvis machine-layer
work, after curses.c reached compile-clean (27/29 elvis TUs). The remaining editor
wall is unix.c's `ttyread()`. This doc scopes the FGX timed/non-blocking console
read it needs; it does not implement it.

## The wall

`unix.c:33` — `fd_set rd;` — is the first of a cluster (`fd_set` / `select()` /
`struct timeval`) that elvis's BSD `ttyread()` uses. It is *not* an fcc gap: those
are undefined machine-layer types/functions. unix.c provides **three** `ttyread()`
backends by `#ifdef` (BSD `select`, SysV/`UNIXV` plain blocking `read`, V7
`alarm`+`read`); the BSD/UNIXV/V7 choice is whole-port (we compile `-DBSD` — curses.c
takes the matching sgtty path, now clean). So we own the BSD `ttyread()` seam.

## The contract elvis needs (`unix.c` BSD `ttyread`)

```
int ttyread(char *buf, int len, int time)
```
- `time` is a timeout in **tenths of a second**. `time == 0` means **block forever**
  for the first byte.
- If input arrives within the timeout: read up to `len` available bytes, return the
  count (`>= 1`).
- On timeout with no input: return **0**.
- The `select() == -1` branch is SIGWINCH/resize handling: on a terminal-size change
  it fakes a `^L`. **FGX's console is fixed-size (no window resize), so this branch is
  inert** — we never synthesize the resize `^L`.

**Why the timeout matters (do NOT just block):** elvis calls `ttyread` with a short
`time` to disambiguate a lone **ESC** (return to command mode) from the start of an
arrow-/function-key **escape sequence** (`ESC [ A`, …), and for the `:set timeout`
mapped-key window. A pure blocking read would make a bare ESC hang until the next
keypress — unacceptable for a vi. This is exactly why "stub it as a blocking read"
was rejected during scoping.

At the point `ttyread` runs, curses has put the tty in CBREAK/RAW + noecho (via the
sgtty seam), so reads are single-keystroke, unbuffered — i.e. the kernel's char-at-a-
time key path, **not** the canonical line discipline.

## What FGX already has (the key finding — no new kernel primitive required)

| syscall | # | what | role here |
|---|---|---|---|
| `SYS_GETKEY` | 50 | `Con_GetKey` — **blocking** single raw key | the `time == 0` path |
| `SYS_POLLKEY` | 66 | `Con_PollKey` — **non-blocking** key poll (foreground-gated; yields for bg) | the poll |
| `SYS_TICKS` | 52 | 32-bit monotonic `_kSystemTicks` (VBL heartbeat, ~60 Hz on IIgs) | the timeout clock |
| `SYS_YIELD` | — | cooperative yield | keep the poll loop from busy-spinning |
| `SYS_ISATTY` | — | `isatty(fd)` (already has a `c_isatty` shim) | elvis's `isatty(0)` check |

The kernel's own CBREAK/RAW read path (`@rd_rcNoEcho`, syscall.s) already *drains
already-waiting keys non-blocking up to the requested count* — the exact "read up to
`len` available bytes" behavior, confirming the primitives compose.

**Consequence:** a faithful timed `ttyread` is achievable entirely in libc/userland
over the existing syscalls. No kernel change is needed.

## Options

### A — Full BSD `select()`/`fd_set`/`timeval` in libc
Provide `<sys/select.h>`-ish `fd_set` + `FD_ZERO/FD_SET/FD_ISSET` + `struct timeval` +
a libc `select()` that, for the fd-0 case elvis uses, runs the tick-poll loop below.
unix.c's BSD `ttyread` then compiles **unmodified**.
- **+** upstream-faithful; `select` reusable by other ports; zero edits to vendored source.
- **−** larger surface (a real `fd_set`/`select` we only ever exercise for fd 0);
  `select`'s general multi-fd/timeval semantics are more than elvis needs.

### B — FGX-native `ttyread` seam (recommended)
Replace the BSD `ttyread` body with an FGX one (the machine-layer TU is explicitly a
port seam — cf. curses.c/tio.c). Implement directly over the primitives:
```
int ttyread(char *buf, int len, int time) {
    if (time == 0)                       /* block for the first key */
        buf[0] = getkey();               /* SYS_GETKEY */
    else {
        long deadline = ticks() + time * TICKS_PER_TENTH;  /* SYS_TICKS; ~6 at 60Hz */
        int k;
        for (;;) {
            k = pollkey();               /* SYS_POLLKEY: >=0 key, <0 none */
            if (k >= 0) { buf[0] = k; break; }
            if (ticks() >= deadline) return 0;             /* timeout */
            yield();                     /* SYS_YIELD: no busy-spin */
        }
    }
    /* got buf[0]; drain any further already-waiting keys up to len */
    return 1 + drain(buf + 1, len - 1);  /* SYS_POLLKEY loop, non-blocking */
}
```
- **+** smallest surface; no `fd_set` machinery; matches the "replace the machine-layer
  TU" pattern; no kernel change; the yield mirrors the existing `ping wait_ticks` idiom.
- **−** edits/replaces the vendored `ttyread` (a port seam, so acceptable) or adds an
  FGX `unix.c`; `TICKS_PER_TENTH` must be pinned to the real heartbeat rate.

### C — New kernel `SYS_READ_TIMED(fd, buf, len, timeout)`
A kernel timed read.
- **−** unnecessary: `SYS_POLLKEY` + `SYS_TICKS` already give this in userland; adds
  kernel surface + a syscall-table slot for no gain. Rejected unless profiling later
  shows the userland poll loop is too costly.

## Recommendation

**Option B** — an FGX-native `ttyread` over `SYS_POLLKEY` + `SYS_TICKS` + `SYS_GETKEY`
+ `SYS_YIELD`. No kernel change, minimal surface, faithful timeout (so bare-ESC vs
escape-sequence disambiguation works). Add a thin `select()` (Option A) later only if
another port needs general `select`.

## Open items before implementing (not blockers to the decision)
1. **Pin `TICKS_PER_TENTH`** — confirm `_kSystemTicks` is the 60 Hz VBL heartbeat
   (→ 6 ticks per tenth); adjust if the HB rate differs. One-line constant.
2. **libc wrappers** — thin `ticks()` (SYS_TICKS), `pollkey()` (SYS_POLLKEY),
   `getkey()` (SYS_GETKEY), `yield()` (SYS_YIELD) if not already exposed to C; these
   belong in libc, not a per-tool stub.
3. **`pollkey()` return convention** — confirm `Con_PollKey` returns "no key" as a
   sentinel distinguishable from a valid `\0` key (elvis can send NUL). If it returns
   0 for both, add an "available" flag path.
4. **Foreground gating** — `SYS_POLLKEY` yields + returns no-key for a *background*
   caller. elvis is foreground, so fine; note it so a future `elvis &` doesn't spin.
5. **Regression fixture** — a cold-boot MAME test: `ttyread` with a small `time`
   returns 0 on no input (timeout path) and the queued key(s) when present. Model on
   `tchtest`/`ttytest`.

## Scope boundary

This unblocks unix.c (the last editor-path wall) → **28/29** once implemented. The
remaining runtime seam (fork/wait→spawn for `:!`, real `errno` global, the signal
model, `getwd`→`getcwd`) and the multi-bank elvis **link** + MAME bring-up are
separate, later phases. prsvunix.c (the elvprsv helper, not the editor) already has no
fcc/libc blocker — its `popen`/`pclose` are stubbed (toolchain `4adc6b1`) and it
compiles clean in-context; a full elvprsv build additionally needs the un-vendored
`prsv.c` main.
```
