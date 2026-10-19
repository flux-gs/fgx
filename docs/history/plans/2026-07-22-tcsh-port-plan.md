# tcsh 6.00 Port Plan (FGX)

**Goal:** Port tcsh 6.00 (2.11BSD, Cornell/christos, 1991) to FGX as a direct
port — no changes to the vendored `examples/2.11BSD/usr/bin/tcsh` C sources.
Every gap the port exposes is filled in the FGX kernel, libc, or fcc
(toolchain-first). Replaces the buggy custom `jsh`.

**Source:** `examples/2.11BSD/usr/bin/tcsh` (48 `.c`, 20 `.h`, ~36K LOC).
Already configured for the PDP-11 (`-Dpdp11`) — 16-bit int, small memory,
memory-frugal algorithms — which matches fcc's `int==16` model exactly. This
is why the 2.11BSD tcsh is the port source (per the port-source policy).

**Prereqs already landed (the campaign built directly toward this):**
- fork/vfork/execve (kernel fork train) — tcsh forks in `sh.sem.c` + `sh.proc.c`.
- `waitpid` + the `_fcc_fb` fix (toolchain v1.19.0) — `sh.proc.c:170` reaps a
  **stack-local `union wait w`** via wait3; the fix makes that resolve.
- pty subsystem (`/dev/ptyp*`,`/dev/ttyp*`, `TIOCSPGRP/GPGRP`) — the
  controlling terminal job control needs.
- sbrk (fork train Stage S) — tcsh's own malloc (`alloc11.c`, the 2.11BSD
  16-bit variant) grows the heap via sbrk.
- termcap (`tgetent/tgetstr/tgoto/tputs`) — `ed.screen.c` drives the line editor.

## Build model

- Compile each TU `-Dpdp11 -I.`; link `-i` (separate I/D → FGX multibank).
- `LIBES=-ltermcap` → FGX termlib. curses NOT needed (tcsh uses termcap direct).
- **Build-only host helpers** (`mkprstr.c`, `jpnerror.c`) generate the packed
  error-strings source on the HOST — they hold nearly all real `<stdio.h>`
  usage and never run on FGX. Run them at build time like a codegen step.
- Runtime output is tcsh's own `xprintf` (`tc.printf.c`), not libc stdio — FGX
  only needs `sprintf` + `write` (both present).

## Gap analysis (tcsh needs × FGX provides)

### Already satisfied — no work
fork, vfork, execv/execve, `_exit`, waitpid (+ `_fcc_fb` fix), getpid/getppid,
setpgid, getpgrp, kill, ioctl, gtty/stty (sgtty), open/close/read/write/lseek/
dup/dup2/pipe, stat/lstat, opendir/readdir/closedir, getcwd, access, unlink/
rename/mkdir/rmdir, chdir, malloc/free/realloc/sbrk, sprintf/write, atoi/atol/
strtol/qsort/getenv, str*/mem*, gettimeofday/time/localtime, getpwnam/getpwuid,
getuid/geteuid, isatty, termcap, `TIOCSPGRP/GPGRP/GETP/SETP/SETN/GETC/SETC/
GWINSZ`. select present (net-scope; must confirm on tty fds).

### Small libc shims (Phase 1) — additive, toolchain-first
| need | fill |
|---|---|
| `wait3(*status,opts,*rusage)` | shim → `waitpid` + zero-fill `struct rusage` (config picks the waitpid path; rusage child-time degrades to 0) |
| `tcsetpgrp/tcgetpgrp(fd,pgrp)` | wrappers → `ioctl(fd, TIOCSPGRP/TIOCGPGRP, &pgrp)` (kernel ioctls exist) |
| `killpg(pgrp,sig)` | → `kill(-pgrp, sig)` |
| `setpgrp()` (BSD) | → `setpgid(0,0)` (or config to setpgid) |
| `getwd(buf)` | → `getcwd(buf, MAXPATHLEN)` |
| `getpwent/setpwent/endpwent` | synthetic single-entry iteration (getpwnam/uid already synthetic) |
| `gethostname(buf,len)` | copy a fixed "fgx" (or kernel hostname global) |
| `getgid/getegid` | return 0 (single-user, mirrors getuid) |
| `times(*tms)` | fill from `SYS_TICKS` (or zero-fill) |
| `getrusage` | zero-fill stub (time builtin degrades) |
| `setpriority/getpriority/nice` | stub → 0/ENOSYS (nice builtin degrades) |
| `setrlimit/getrlimit` + `sys/resource.h` + `struct rlimit`/`struct rusage` | header + stub → ENOSYS (limit builtin degrades) |
| `readlink/symlink` | readlink present; confirm symlink (path-resolution, non-critical) |

Headers to add (additive): `sys/resource.h` (rlimit+rusage), `unistd.h`
(thin, if tcsh includes it under pdp11), `sys/file.h` (FIOCLEX flags) — verify
which the pdp11 path actually includes at first-compile.

### Kernel fills (Phase 1–2)
| need | fill |
|---|---|
| `fstat(fd,*st)` | `SYS_FSTAT` is a stub (ENOSYS); implement it (tcsh uses it 2×) — small |
| close-on-exec (`FIOCLEX/FIONCLEX` or `fcntl(F_SETFD)`) | fd-flag support so exec/pipe fd hygiene is correct — medium |
| missing sgtty ioctls (`TIOCGLTC/SLTC` ltchars, `TIOCLGET/LSET` local modes, `TIOCGETD/SETD` line disc) | fill in the pty/tty ioctl handler, or return ENOTTY where tcsh tolerates — medium |

### The crux — signal delivery + masking (Phase 2, its own sub-campaign)
tcsh is fundamentally signal-driven: **127 `signal()` calls**, SIGCHLD-based
job reaping, SIGINT interactivity, SIGTSTP/SIGTTIN/SIGTTOU job control,
sigblock/sigsetmask race-free critical sections. FGX today: `SYS_SIGNAL`
installs but **delivery is partial/stubbed**; `sigblock/sigsetmask` are
**no-ops**; no `sigvec/sigaction`. This is the largest work item and gates
interactive/job-control correctness.

Scope (kernel):
1. **Real delivery** — post pending signals to a task and run its handler on
   return-to-user (SIGINT from ^C already does EINTR; extend to handler
   dispatch for SIGCHLD/SIGTSTP/SIGTTIN/SIGTTOU/SIGCONT/SIGHUP/SIGTERM/etc.).
2. **Masking** — real `sigblock/sigsetmask/sigpause` so SIGCHLD handling is
   race-free (the classic block-around-fork/reap window).
3. **Handler ABI** — sig number arg, restartable-vs-EINTR syscall semantics,
   handler stack (ties to the fork-train frame-stash discipline).
4. libc: `sigvec` → real; `sigsetmask/sigblock` → real; keep the tc.sig.c
   config macros pointing at the BSD flavor.

This mirrors a prior kernel campaign in size; plan it as a Fable-reviewed
sub-roadmap before implementing. Signals are a platform gap, so it is kernel
work under the toolchain-first rule (not a tcsh source change).

## Phased roadmap

- **P0 — Build harness + first compile.** Stand up `src/userland/tcsh/` (or a
  vendored-copy build), host-run mkprstr/jpnerror, compile every TU `-Dpdp11`,
  collect the *real* missing-symbol set (empirical, refines this survey). No
  link yet. Deliverable: all 48 TUs compile; a concrete link-error gap list.
- **P1 — Link (shims + stubs).** Add the Phase-1 libc shims + headers +
  `fstat`; degrade rlimit/priority/rusage. Deliverable: tcsh LINKS and starts
  to a prompt non-interactively (`tcsh -c 'echo hi'`), reaping via waitpid.
- **P2 — Signal subsystem.** Kernel signal delivery + masking sub-campaign.
  Deliverable: SIGINT (^C) at the prompt, SIGCHLD job reaping, sigblock races
  closed. Probe: run a pipeline, ^C it, verify clean reap.
- **P3 — Job control on the pty.** fg/bg, `^Z` (SIGTSTP), tty pgrp handoff
  (tcsetpgrp), SIGTTIN/TTOU. Deliverable: `sleep 100 &`, `fg`, `^Z`, `bg`,
  `jobs` all correct on a ptyp/ttyp pair. Closed-loop probe like the fork/pty
  ones.
- **P4 — Interactive polish + tests.** Line editor (`ed.*`) key bindings,
  completion (`tw.*`), history, prompt; MAME closed-loop tests; man page;
  make tcsh the default shell (retire jsh path). Deliverable: green suite +
  interactive smoke tests.

## Risks / open questions
- **Signal delivery is the tall pole** — everything interactive/job-control
  depends on it; P2 may itself need a plan doc + review.
- `select` on tty fds (sh.init.c uses it 5×) — confirm it works for the
  console/pty or tcsh degrades to blocking reads.
- close-on-exec correctness for pipes across exec (fd leak → hangs).
- 16-bit int × tcsh pointer/size assumptions on the banked 65816 — the
  pdp11 path already assumes 16-bit int, but watch `alloc11.c` heap arithmetic
  and any `int`-holds-pointer idioms (the fcc multibank far-ptr class).
- ProDOS filename constraints (no underscores, case-insensitive) for tcsh's
  dotfiles (`.tcshrc`, `.history`) and `/etc/csh.cshrc` paths.

## P0 empirical gap map (2026-07-22)

P0 first-compile re-run against the integrated toolchain **`feat/fcc-tcsh`**
(= `feat/fcc-bsd-large` FCC_GROW dynamic tables + BSD headers, merged with
`feat/fcc-declarator` Inc 1-4 return-type fix, plus two new fixes landed this
session: `g_typedefs` FCC_GROW and `NULL` in `<sys/types.h>`). Result: **10 of
46 TUs compile**; the empirical fcc gap set (first error per TU) is:

| count | gap | locus | class |
|---|---|---|---|
| **18** | `expected ';' after fn-ptr global decl` | `parse_stmt.c:5527`, tripped by `ed.h:74 extern PFCmd CcFuncTbl[];` (an **array of an fn-ptr typedef**) | **Increment 5** — the fn-ptr-typedef-resolved global branch only handles a scalar name, not `[dims]`. `CcFuncTbl` is the ONLY such global (defined `PFCmd CcFuncTbl[] = { e_unassigned, ... }` in ed.defns.c — func-name init, already handled by `parse_fnptr_global_array`; only the `extern []` decl form is new). |
| 5 | `expected type (int/char/void/struct/typedef-name)` | sh.h/ed.h chain (tw.*, sh.exec) | likely CCRETVAL/typedef visibility in these TUs' include order; re-triage after the fn-ptr fix |
| 4 | `expected ';'` | various | per-TU parser gaps (surface after the shared fn-ptr fix unblocks the TU) |
| 2 | `expected ')'` | sh.err.c:353, sh.misc.c:433 | parser gaps |
| 1 | `expected '[' (&p[i] on ptr-to-ptr needs 2nd subscript)` | sh.glob.c:230 | known fcc ptr-arith single-bank gap `[[feedback_fcc_ptr_arith_single_bank_gap]]` |
| 1 | `sizeof in constant expr requires a type name` | tc.who.c:1 | fcc sizeof-in-constexpr gap |
| 1 | `expected '(' after sizeof in constant expression` | sh.init.c:170 | fcc sizeof-in-constexpr gap |
| 1 | `static-local initializer must be a constant` | sh.dir.c:75 | fcc static-local-init gap |
| 1 | `no such field` | sh.time.c:416 | struct-field / union gap |
| 1 | `void-returning function cannot be used in expression` | sh.sem.c:379 | fcc void-fn-in-expr gap |
| 1 | `expected '='` | sh.parse.c:178 | parser gap |

Notes: `typedef void sigret_t` IS rejected by fcc ('typedef of void requires *',
an artificial reject) but is NOT on the pdp11 path (`SIGVOID` unset →
`sigret_t=int`) — skip until needed. fcc misattributes include-body errors to
the includer's line (e.g. `sh.c:74` is a comment; the real locus is `ed.h:74`).
~23 TUs die early in `sh.h`/`ed.h`, hiding their later errors — fix the shared
fn-ptr construct FIRST, then re-run to reveal the true tail.

## Immediate next step
Execute **Increment 5** of the fcc declarator refactor (charter:
`2026-07-22-fcc-declarator-refactor.md`) — it is now a proven tcsh dependency,
not just cleanup. Route the fn-ptr contexts through the unified
`parse_declarator` (grouping `(*fp)()` + function `(params)` + array-of-fn-ptr
with in-band FnSig interning), retiring `parse_fn_ptr_declarator`/
`g_fnptr_decl_arr`/the cast's private parser. This clears the 18-TU
`CcFuncTbl` family (`extern PFCmd CcFuncTbl[]` + the scalar/array/comma fn-ptr
global/local/typedef/param shapes). Gate 477/477 byte-identical at each
sub-step. Then re-run P0 and knock down the revealed tail (the sizeof-constexpr,
static-local-init, ptr-arith, void-fn-in-expr, no-such-field gaps) one fix +
fixture at a time, until all 46 TUs compile → then P1 (link).
