# Shared libc SP4 step 4: first use, the race, the kill, reclaim, the errors -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove on the machine what step 3 built but only exercised for libc: a curses program bound on the machine loads termlib and curses on first use, two first users race to one load, a first user killed mid-load leaves the row for the next, an unused library is reclaimed under pool pressure and reloads at the same base, and the binder's error paths say what the spec says -- each with a control that must fail; then retire SP3's `dynsomis`/`dynsonodata` and record the measurements.

**Architecture:** No new loading mechanism: the binder's first-use path (`ld_need` from `ld_bind`) and ld.mod's arbitration, exit hook and reclaim exist since steps 1-3. This step adds the probes -- `curssodyn` (cursso linked dynamically, bound on the machine, as `dynsodyn` is dynso), `ldctl` modes that read a row (`row`), stop a loader mid-load (`waitload`) and drain the pool (`drain`), and a fit fixture `fitso` built twice a fixed margin under its link-time limit -- each multi-step probe a script under `/testdata`. Two things the probes need are fixed first: SIGKILL does not end a stopped process (apple/fgx#505), and `fgx_dyn` gains `--fit-report` so a fixture can be sized from the linker's own numbers. Any further defect a probe finds is fixed in its own commit (systematic-debugging), as #502-#504 were.

**Tech Stack:** Merlin32 65816 (`signal.s`), fcc K&R C (`ldctl`, `fitso`), 2.11BSD sh scripts (`disk_src/testdata/`), bash (`build_dynso.sh`), Python 3 (`fgx_dyn.py`, `tools/ninja/gen.py`), ninja, headless MAME via `tools/mame_test/run.py`.

**Spec:** `docs/history/plans/2026-09-30-shared-libc-sp4-design.md` (sections 1, 4, 5.2, 5.3, 5.5, 8, 9 items 2-6, 10 step 4, 11). Step 3's plan for the conventions: `docs/history/plans/2026-10-01-shared-libc-sp4-step3-plan.md`.

## Global Constraints

- Branch `feat/shared-libc`; no push, no MR. Each commit ends with the session's attribution trailers; bodies are the changelog (informational, no names or process). Announce every `ninja` rebuild and every MAME run to the maintainer before it starts (he boots the tree by hand).
- ASCII only; comments describe the current state only. Merlin32 has no operator precedence; explicit `MX` at every label reached in another width (check_mx).
- `$S` is the plan's workspace (`sdd-workspace` prints it); long output goes there and only its tail is read.
- **A typed command is at most 255 characters** (`TTYHOG`, `src/kernel/tty/tty.c:83, 1216-1220`: past it each character is dropped). A probe of more than one short line is a script in `disk_src/testdata/` (tracked as is, no staging entry; precedent `czrun`), run as `sh /testdata/<name>`. Needles then never appear in the typed command; `tools/check_vacuous_assertions.py` still runs.
- Scripts use `&`, `$!` and `wait` under 2.11BSD's sh (`vendor/2.11BSD/usr/bin/sh/macro.c:90` is `$!`), which has no job control: a background child stays in the terminal's process group, so curses's tty ioctls do not stop it with SIGTTOU. Two curses programs on one console may leave its modes changed afterwards; every needle in those probes comes from a file, not from the console's echo.
- Signals by number for `/bin/kill`: SIGKILL 9, SIGSTOP 17, SIGCONT 19 (`toolchain/include/signal.h:51, 59, 61`).
- fcc locals live on the bank-0 stack: anything a syscall reads is a static in the data bank (as `ldctl.c`'s `blk`).
- Every MAME verdict is a fresh run (`--fresh`; "(1 cached)" did not run).
- A kernel or libc behaviour with a BSD counterpart: read it in `vendor/` and name file and function in the commit.
- Before the last commit, run every manifest (RESUME-2026-10-02): `python3 -c "import os;print('\n'.join(sorted(f[:-5] for f in os.listdir('tools/mame_test/tests') if f.endswith('.json'))))" | xargs python3 tools/mame_test/run.py --fresh`. Expected failures: `manyproc`, `wuptime` (#498), which fail on main too.

## Rulings this plan makes against the spec (each lands in the spec in Task 7)

1. **The dynamic curses probe is a new binary, `curssodyn`**; SP3's host-bound `cursso` stays as a control, as `dynso` stays beside `dynsodyn` (spec 9 keeps "dynso's bound image as a control").
2. **"Not found" uses the staged termlib renamed aside at run time**, not a test-only `fgx_libso.LIBS` entry (spec 9.6): `ld_need` takes the same path (no `/lib/<name>.so.<major>.` file; text `ld_load.c:82-96, 225, 230`), the script renames it back within the run, and no library build or ninja edge is added for a test.
3. **The machine's fit check is reached by moving a base, not by a program the host would refuse**: since 0a1c9944b fgx_dyn refuses at link time any program whose data does not fit below the libraries' assembled bases, so the run-time check fires only when a needed core lands lower than it was linked against. `ldctl pad 100` holds 100 bytes of arena first (as `lddelta` does), so termlib lands 100 bytes lower; `fitover` is linked 50 bytes under the limit (refused), `fitunder` 150 (runs) -- the pair is the control.
4. **"The free-bank count unchanged" (spec 9.4) is observed as the row's bank list**: no interface reports the pool's free count. The list is read while the loader holds the row, and after the waiter's takeover the READY row's list must equal it: a bank lost would make the takeover grant another (`ld_need` grants only `core - have`, `ld_load.c:501, 655`), a bank granted twice would lengthen the list.
5. **The race and the kill are built by stopping the loader, not by timing**: `ldctl waitload <lib> <pid>` sends `<pid>` SIGSTOP itself the moment its LOOKUP sees the row LOADING with banks granted -- inside the 44 KB read -- so the second user always finds the row LOADING and must wait. The race then continues the loader (SIGCONT); the kill SIGKILLs it. Under arbitration off the second user loads too, deterministically. It also exercises spec 11's stated divergence (a waiter waits while the loader is stopped).
6. **The race is proven on two boots**: one runs two traced first users and counts the loads (curses `loaded)` exactly once); the other runs two full first users and checks both exit 0. A full run prints no load marker, and a traced run does not run curses.
7. **The digest parity of spec 9.7 extends to `curssodyn`**, which `lddigest` runs on a fresh boot, so the machine's digest is taken through a first-use load of termlib and curses at their assembled bases (no `ld.so.conf`: the arena stacks libc, termlib, curses in the order `fgx_libso` assembled them).
8. **apple/fgx#505 is fixed in this step**: the kill probe cannot pass while a SIGKILLed stopped process stays stopped, and a loader nobody can kill holds its row LOADING and every waiter asleep. Same family (the signal paths ld.mod's exit hook relies on), own commit.

## Review Focus

1. **A waiter whose loader is killed** -- a second user of curses asleep in ACQUIRE when the stopped loader is SIGKILLed takes the row over (with its banks) and runs. Test: `curssokill` (Task 4).
2. **The same program twice at once on a fresh boot** -- both run, one load. Test: `curssorace`, `curssoload` (Task 4).
3. **A program whose library was reclaimed** -- it reloads and runs, at the same core base, with libc's banks untouched. Test: `curssoreclaim` (Task 5).
4. **`ldd` on a program whose library is missing** -- lists it as `not found` and exits 0, running nothing. Test: `ldfit` (Task 6).
5. **A library loaded by a program that then fails its fit** -- stays resident and serves the next program (the fit check follows the core loop in `ld_bind.c`, after COMMIT). Test: `ldfit`'s trace of `fitunder` after `fitover` failed says termlib `resident)` (Task 6).

---

### Task 1: SIGKILL ends a stopped process (apple/fgx#505)

**Files:**
- Modify: `src/kernel/signal.s` (`_Kill_Apply`, about line 486), `src/userland/ldctl/ldctl.c` (mode `stopkill`)
- Create: `tools/mame_test/tests/ldctl_stopkill.json`

**Interfaces:**
- Consumes: `_Kill_Apply`'s SIGCONT arm (TASK_STOPPED -> TASK_READY, SEF_STOPREPORTED cleared), `@disp_stop`'s `JSR swtch` (resumes there and returns into signal dispatch).
- Produces: a SIGKILL posted to a TASK_STOPPED task makes it READY, so it acts on the pending SIGKILL. Task 4's kill probe relies on it.

- [ ] **Step 1: Read BSD**

Read `vendor/2.11BSD/usr/sys/sys/kern_sig.c` `psignal()`, lines 300-345. The deciding lines (317-325): `case SSTOP: ... if (sig == SIGKILL) goto run;`. Quote them in the commit.

- [ ] **Step 2: Write the failing regression**

In `ldctl.c`, after `killm`:

```c
/* A stopped child dies of SIGKILL: psignal() makes a stopped process
 * runnable for it (2.11BSD kern_sig.c).  A hang here shows no ok. */
static int
stopkill()
{
    int pid, st;

    pid = fork();
    if (pid == 0)
        for (;;)
            pause();
    sleep(1);
    kill(pid, SIGSTOP);
    sleep(1);
    kill(pid, SIGKILL);
    st = reap(pid);
    say("stopkill", (st & 0177) == SIGKILL, "a stopped child killed");
    return 0;
}
```

and in `main`: `else if (strcmp(argv[1], "stopkill") == 0) stopkill();`. `tools/mame_test/tests/ldctl_stopkill.json`, modelled on `ldctl_kill.json`: name `ldctl_stopkill`, description "A process stopped by SIGSTOP dies when sent SIGKILL (apple/fgx#505), as 2.11BSD's psignal() makes it runnable for it.", command `/testbin/ldctl stopkill`, needle `LDC stopkill ok`, `timeout_s` 120, lacks `LDC FAIL`, `PANIC`, `BRK`.

- [ ] **Step 3: Run it to verify it fails**

Announce the `ninja` and the run. Run: `ninja > $S/t1_red.log 2>&1; tools/mame_test/run.py ldctl_stopkill --fresh 2>&1 | tail -3`
Expected: FAIL by timeout (`reap` never returns: the child stays stopped), no `LDC stopkill ok`.

- [ ] **Step 4: The fix**

In `_Kill_Apply`, the SIGCONT test becomes SIGCONT or SIGKILL:

```
@ka_haveSig     ; SIGCONT and SIGKILL un-stop a stopped target (post time).
                CMP     #SIGCONT
                BEQ     @ka_unstop
                CMP     #SIGKILL
                BNE     @ka_post
@ka_unstop      LDA:    TCB_Status,X
```

(the lines after `LDA: TCB_Status,X` unchanged), and the routine's header comment: "SIGCONT and SIGKILL post-time: a TASK_STOPPED target is flipped back to READY (2.11BSD psignal(): a SIGKILL makes a stopped process run, so it acts on the kill)". The same width throughout (MX %00), so `@ka_unstop` needs no `MX`. signal.s is in the core (`PUT` from `main.s:3785`): the change is 5 bytes. Read the build's core-room report (`grep -i "core" $S/t1_build.log`); if the core has no 5 bytes, STOP -- the fix's home is then a ruling for the maintainer (spec 6: "the core if it fits, else the far or tty bank").

- [ ] **Step 5: Run it to verify it passes**

Run: `ninja > $S/t1_build.log 2>&1; tail -2 $S/t1_build.log; tools/mame_test/run.py ldctl_stopkill ldctl_kill ldctl_race ldctl_intr --fresh 2>&1 | tail -3`
Expected: `4 passed`. Then the job-control probes, which exercise the stop path: `tools/mame_test/run.py $(ls tools/mame_test/tests | grep -iE 'stop|tstp|ttin|ttou|jobs|bg|fg' | sed 's/.json//') --fresh 2>&1 | tail -3`; Expected: all pass. Run `tools/gate.sh`; Expected `GATE GREEN`.

- [ ] **Step 6: Commit**

```bash
git add src/kernel/signal.s src/userland/ldctl/ldctl.c tools/mame_test/tests/ldctl_stopkill.json
git commit -F - <<'EOF'
fix(kernel): SIGKILL ends a stopped process -- apple/fgx#505

_Kill_Apply made a stopped process runnable only for SIGCONT; a SIGKILL
was posted and left pending while the process waited in swtch for a
continue that might never come, holding whatever it held.  2.11BSD's
psignal() (usr/sys/sys/kern_sig.c):

	case SSTOP:
		...
		if (sig == SIGKILL)
			goto run;

A SIGKILL now makes a stopped process ready as SIGCONT does, and it
dies of the kill.  ldctl's `stopkill' stops a child, kills it, and
reaps it signalled.
EOF
```

---

### Task 2: curssodyn -- curses bound on the machine, first use, ldd, parity

**Files:**
- Modify: `tools/dynso-fgx2/build_dynso.sh` (case `curssodyn`), `tools/ninja/gen.py` (entry `curssodyn`; `curssodyn` in the `dyndigest` loop), `tools/ninja/manifest.json` (stage `/testbin/curssodyn`, `/testbin/curssodyn.digest`), `src/userland/cursso/cursso.c` (header comment only), `tools/mame_test/tests/lddigest.json`
- Create: `disk_src/testdata/curssodyn`, `tools/mame_test/tests/curssodyn.json`

**Interfaces:**
- Consumes: step 3's `fgx_dyn`, `crt0_dyn.s`, `ld_bind` (first use through `ld_need`), the trace line `\t-l<name>.<major> => <path> (core $XXXX, prebound|by name, resident|loaded)` and `N bytes of unused cores between them`, `fgx_bind --digest`.
- Produces: `/testbin/curssodyn` (exit 0 and `CURS ok` when every check passes) and `/testbin/curssodyn.digest`, used by Tasks 4-7.

- [ ] **Step 1: Write the failing probe**

`disk_src/testdata/curssodyn`:

```sh
# curssodyn on a fresh boot: the first trace loads curses, the program
# runs, a second trace finds it resident, ldd lists the libraries.
LD_TRACE_LOADED_OBJECTS=1 /testbin/curssodyn > /tmp/t1
echo CTR first=`grep -c "lcurses.1 => .*loaded)" /tmp/t1`
/testbin/curssodyn
LD_TRACE_LOADED_OBJECTS=1 /testbin/curssodyn > /tmp/t2
echo CTR second=`grep -c "lcurses.1 => .*resident)" /tmp/t2`
ldd /testbin/curssodyn
```

`tools/mame_test/tests/curssodyn.json`:

```json
{
 "name": "curssodyn",
 "description": "Shared libc SP4: cursso linked dynamically and bound on the machine: on a fresh boot the trace loads curses (first use), the program runs its checks, a second trace says resident, and ldd lists the three libraries with their core bases and the hole bytes.",
 "command": "sh /testdata/curssodyn",
 "timeout_s": 240,
 "expect": {
  "screen_contains": ["CTR first=1", "CURS ok", "CTR second=1", "-ltermlib.1 => /lib/libtermlib.so.1.0 (core $", "-lcurses.1 => /lib/libcurses.so.1.0 (core $", "bytes of unused cores between them"],
  "screen_lacks": ["CURS FAIL", "ld.so:", "PANIC", "BRK"]
 }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 tools/check_vacuous_assertions.py && tools/mame_test/run.py curssodyn --fresh 2>&1 | tail -3`
Expected: FAIL -- `/testbin/curssodyn` is not on the image (`CTR first=0`, `not found`).

- [ ] **Step 3: Build and stage curssodyn**

`build_dynso.sh`: `curssodyn) src=cursso/cursso.c; libs=libcurses ;;` in the case list; `curssodyn` in the "bound on the machine" copy case (`dynsodyn|dynsomisdyn|dyntrue|curssodyn`), the usage line and the header comment ("curssodyn (cursso, bound on the machine)"). `gen.py`: a `"curssodyn"` entry copied from `"cursso"` with `out="tools/dynso-fgx2/curssodyn.bin"`, `script="tools/dynso-fgx2/build_dynso.sh curssodyn"`; `"curssodyn"` in the `for _n in ("dynsodyn", "dynsomisdyn")` digest loop, and `toolchain/lib/libtermlib.so.1.0 toolchain/lib/libcurses.so.1.0` added to that rule's implicit inputs. `manifest.json`: beside `dynsomisdyn`'s, `tools/dynso-fgx2/curssodyn.bin` -> `disk_src/testbin/curssodyn` and `build/curssodyn.digest` -> `disk_src/testbin/curssodyn.digest`. `cursso.c`'s header: "bound on the host (cursso) or on the machine (curssodyn)".

Run: `python3 tools/ninja/gen.py >/dev/null && ninja > $S/t2_build.log 2>&1; tail -2 $S/t2_build.log; cat build/curssodyn.digest`
Expected: the build succeeds; the digest is one line `LDB sites xxxx n=N`, N > 0. If fgx_dyn refuses `curssodyn` for segment 0's room (spec 5.1), STOP: that is sub-project 5's case.

- [ ] **Step 4: Run it to verify it passes**

Run: `tools/mame_test/run.py curssodyn --fresh 2>&1 | tail -3`
Expected: `1 passed`. A failure is a step 3 defect libc-only probes could not reach (termlib's or curses's block tables through `_crt0_inits`, a non-libc core copy, a first-use `ld_need` from the binder): superpowers:systematic-debugging, a fix in its own commit with its regression check, then rerun.

- [ ] **Step 5: Parity -- extend lddigest**

Append to `lddigest.json`'s command `; LD_BIND_DIGEST=1 /testbin/curssodyn > /tmp/dg3; cmp /tmp/dg3 /testbin/curssodyn.digest && echo LDB \"same\"3` (count the typed command: it must stay at 255 characters or fewer; if not, move the whole command to `disk_src/testdata/lddigest` and run `sh /testdata/lddigest`), and `"LDB same3"` to `screen_contains`; its description gains "and curssodyn's, taken through a first-use load of termlib and curses".

Run: `python3 tools/check_vacuous_assertions.py && tools/mame_test/run.py lddigest --fresh 2>&1 | tail -3`
Expected: `1 passed`. A `differ` with no `core copy differs` is a digest mismatch: compare `/tmp/dg3` with the host's and find which library's normalisation differs (ruling 7 assumes the assembled bases).

- [ ] **Step 6: Control -- the first-use path must be what passed**

Temporarily make the binder treat every non-libc library as absent (in `ld_bind.c`, `rr = -1;` in place of the `ld_need` call), `ninja`, run `curssodyn`.
Expected: FAIL (`ld.so: libtermlib.so.1: not found`, `CTR first=0`). Restore, `ninja`, `git diff --stat toolchain` empty.

- [ ] **Step 7: Commit**

```bash
git add tools/dynso-fgx2/build_dynso.sh tools/ninja/gen.py tools/ninja/manifest.json \
        src/userland/cursso/cursso.c disk_src/testdata/curssodyn \
        tools/mame_test/tests/curssodyn.json tools/mame_test/tests/lddigest.json
git commit -F - <<'EOF'
test(shared-libc): a curses program bound on the machine

curssodyn is cursso linked dynamically and bound by libc's binder: on a
fresh boot its first run loads termlib and curses (first use), it runs
its checks against them, a second run finds them resident, and ldd
lists the three libraries.  Its binding digest equals fgx_bind's,
taken through the first-use load.
EOF
```

---

### Task 3: ldctl reads a row and stops a loader

**Files:**
- Modify: `src/userland/ldctl/ldctl.c` (modes `row`, `waitload`)

**Interfaces:**
- Consumes: `struct ldblk`, `LDS_LOOKUP`, `LD_FREE`=1, `LD_LOADING`=2, `LD_READY`=3 (`toolchain/include/sys/ldctl.h`).
- Produces: `ldctl row <lib>` prints `LDC row state=S users=U nbanks=N`, `LDC base XXXX` (4 hex digits), `LDC banks bb bb ...` (each bank, 2 hex digits), then `LDC row ok`; a missing row prints `LDC FAIL row <lib>`. `ldctl waitload <lib> [pid]` polls LOOKUP until the row is LOADING with at least one bank granted, then sends `pid` (if given) SIGSTOP and prints `LDC loading <lib>` and `LDC waitload ok`; after 20000 polls `LDC FAIL waitload <lib>`. Used by Tasks 4 and 5.

- [ ] **Step 1: The modes, checked against a known state first**

There is no RED for a new reporting mode on its own; its control is `ldctl row libc`, whose answer is known: libc is READY, pinned, four banks (spec 12, step 2). In `ldctl.c`, after `padm`:

```c
/* s's row: its state, users and banks, one line each, for a probe to
 * compare across runs. */
static int
rowm(s)
char *s;
{
    int i;

    if (look(s) < 0) {
        say("row", 0, s);
        return 1;
    }
    printf("LDC row state=%d users=%d nbanks=%d\n", blk.state, blk.users,
           blk.nbanks);
    printf("LDC base %04x\n", blk.core_base);
    printf("LDC banks");
    for (i = 0; i < blk.nbanks; i++)
        printf(" %02x", blk.banks[i]);
    printf("\n");
    return 0;
}

/* Poll until s's row is LOADING with banks granted -- a first user is
 * reading the library into them -- and stop that user, so a probe can
 * act while the load is in progress. */
static int
waitload(s, pid)
char *s;
int pid;
{
    unsigned n;

    for (n = 0; n < 20000; n++)
        if (look(s) >= 0 && blk.state == LD_LOADING && blk.nbanks > 0) {
            if (pid > 0)
                kill(pid, SIGSTOP);
            printf("LDC loading %s\n", s);
            return 0;
        }
    say("waitload", 0, s);
    return 1;
}
```

and in `main`, before the `look` arm:

```c
    else if (strcmp(argv[1], "row") == 0 && argc > 2)
        rowm(argv[2]);
    else if (strcmp(argv[1], "waitload") == 0 && argc > 2)
        waitload(argv[2], argc > 3 ? atoi(argv[3]) : 0);
```

Run: `ninja > $S/t3_build.log 2>&1; tail -2 $S/t3_build.log`, then (announced) a one-off run with a scratch manifest in `$S` or by hand: `tools/mame_test/run.py --fresh` on a temporary `tools/mame_test/tests/ldrow.json` with command `/testbin/ldctl row libc; /testbin/ldctl row libnone`, needles `LDC row state=3 users=0 nbanks=4` and `LDC FAIL row libnone`.
Expected: both needles. Delete the temporary manifest (it adds nothing Task 4-5's probes do not).

- [ ] **Step 2: Commit**

```bash
git add src/userland/ldctl/ldctl.c
git commit -F - <<'EOF'
test(ldctl): read a row, and stop a loader mid-load

`ldctl row <lib>' prints a row's state, users, core base and banks, one
line each, for a probe to compare across runs.  `ldctl waitload <lib>
<pid>' polls until the row is LOADING with banks granted and stops
<pid> there, so a probe can race or kill a first user inside its load.
EOF
```

---

### Task 4: the race and the kill

**Files:**
- Create: `disk_src/testdata/curssoload`, `disk_src/testdata/curssorace`, `disk_src/testdata/curssokill`, `tools/mame_test/tests/curssoload.json`, `tools/mame_test/tests/curssorace.json`, `tools/mame_test/tests/curssokill.json`

**Interfaces:**
- Consumes: `/testbin/curssodyn` (Task 2), `ldctl row` and `ldctl waitload` (Task 3), SIGKILL ending a stopped process (Task 1).
- Produces: nothing later tasks consume.

- [ ] **Step 1: Write the three probes**

`disk_src/testdata/curssoload` (rulings 5, 6):

```sh
# Two traced first users of curses: A is stopped inside its load, B
# starts and must wait, A continues.  curses is loaded once.
LD_TRACE_LOADED_OBJECTS=1 /testbin/curssodyn > /tmp/r1 &
A=$!
/testbin/ldctl waitload libcurses $A
LD_TRACE_LOADED_OBJECTS=1 /testbin/curssodyn > /tmp/r2 &
sleep 2
kill -19 $A
wait
cat /tmp/r1 /tmp/r2 > /tmp/r
echo RCE curses=`grep -c "lcurses.1 => .*loaded)" /tmp/r` traced=`grep -c "lcurses.1 =>" /tmp/r`
```

`disk_src/testdata/curssorace` (ruling 6, Review Focus 2):

```sh
# Two first users of curses run to the end: A is stopped inside its
# load, B waits on the row, A continues; both exit 0.
/testbin/curssodyn > /dev/null &
A=$!
/testbin/ldctl waitload libcurses $A
(/testbin/curssodyn > /dev/null; echo RCE b=$? > /tmp/sb) &
sleep 2
kill -19 $A
wait $A
echo RCE a=$? > /tmp/sa
wait
cat /tmp/sa /tmp/sb
```

`disk_src/testdata/curssokill` (rulings 4, 5, Review Focus 1):

```sh
# The first user of curses is stopped inside its load and SIGKILLed
# while a second waits: the row is aborted with its banks, the waiter
# takes it over and runs, and the row ends READY with the same banks.
/testbin/curssodyn > /dev/null &
A=$!
/testbin/ldctl waitload libcurses $A
/testbin/ldctl row libcurses
/testbin/ldctl row libcurses | grep banks > /tmp/k1
(/testbin/curssodyn > /dev/null; echo KIL b=$? > /tmp/sb) &
sleep 2
kill -9 $A
wait
cat /tmp/sb
/testbin/ldctl row libcurses
/testbin/ldctl row libcurses | grep banks > /tmp/k2
cmp /tmp/k1 /tmp/k2 && echo KIL same banks
```

Manifests, each `"command": "sh /testdata/<name>"`, `"timeout_s": 240`, lacks `["LDC FAIL", "ld.so:", "PANIC", "BRK"]`, and:
- `curssoload`: description "Shared libc SP4: two traced first users of curses on a fresh boot, the first stopped inside its load while the second starts: curses is loaded once, and both traces list it."; contains `["LDC loading libcurses", "RCE curses=1 traced=2"]`.
- `curssorace`: description "Shared libc SP4: two first users of curses on a fresh boot, the first stopped inside its load while the second waits on the row: both run and exit 0."; contains `["LDC loading libcurses", "RCE a=0", "RCE b=0"]`.
- `curssokill`: description "Shared libc SP4: the first user of curses, stopped inside its load, is SIGKILLed while a second waits: the row is aborted with its banks kept, the waiter takes it over and runs, and the row ends READY holding the same banks."; contains `["LDC loading libcurses", "LDC row state=2 users=0", "KIL b=0", "LDC row state=3 users=0", "KIL same banks"]`.

(`state=2 users=0` is the row LOADING, its owner not yet a user: COMMIT counts it, spec 4. The two seconds let B reach ACQUIRE's sleep; B finding the row LOADING is certain, because A is stopped holding it.)

- [ ] **Step 2: Run them**

Announce. Run: `python3 tools/check_vacuous_assertions.py && tools/mame_test/run.py curssoload curssorace curssokill --fresh 2>&1 | tail -3`
Expected: `3 passed`. `LDC FAIL waitload` means the poll never saw curses LOADING with banks (the load ran past it, or the poll starved the loader -- read the dump's timings). No `KIL b=` means the waiter hung: either the stopped loader did not die (Task 1) or the exit hook did not abort its row (spec 6.3).

- [ ] **Step 3: Controls -- each must go red, then restore**

  - Arbitration off (in `src/modules/ld/ld.s`, `svc_acquire` treats a row LOADING by another live process as absent and answers "load it", as step 1's control did): `curssoload` FAILs (`curses=2`: B loads too, deterministically, since A is stopped holding the row).
  - Exit hook off (`_Ld_Exit` returns at once): `curssokill` FAILs (the waiter sleeps on a row nobody will commit: no `KIL b=0`, timeout).
  - Task 1's fix reverted (`BEQ @ka_unstop` removed): `curssokill` FAILs (the stopped loader never dies).

Each: edit, `ninja`, run the one probe fresh, see it fail, restore, `ninja`. Then `git diff --stat src` is empty.

- [ ] **Step 4: Commit**

```bash
git add disk_src/testdata/curssoload disk_src/testdata/curssorace disk_src/testdata/curssokill \
        tools/mame_test/tests/curssoload.json tools/mame_test/tests/curssorace.json \
        tools/mame_test/tests/curssokill.json
git commit -F - <<'EOF'
test(shared-libc): two first users race, a loader killed mid-load

The first user of curses on a fresh boot is stopped inside its load and
a second starts.  Continued, the first finishes the load and the second
finds curses resident: one load between them, and both run.  SIGKILLed
instead, the first leaves the row aborted with its banks; the second
takes it over, runs, and leaves it READY holding the same banks.
EOF
```

---

### Task 5: reclaim

**Files:**
- Modify: `src/userland/ldctl/ldctl.c` (mode `drain`)
- Create: `disk_src/testdata/curssoreclaim`, `tools/mame_test/tests/curssoreclaim.json`

**Interfaces:**
- Consumes: `ldctl row` (Task 3), `/testbin/curssodyn` (Task 2).
- Produces: `ldctl drain <lib>`: commits throwaway rows `drain<n>` of 8 banks (core size 1) until `<lib>`'s row holds no banks, at most 12 (libc, termlib, curses and twelve drains are fifteen of the sixteen rows a boot); `LDC drain ok`, or `LDC FAIL drain <lib>`.

- [ ] **Step 1: Write the failing probe**

`disk_src/testdata/curssoreclaim` (spec 9.5, Review Focus 3):

```sh
# After curssodyn exits, drain the pool: curses's unused row is
# reclaimed, libc's pinned row is not; curses reloads at the same base.
/testbin/curssodyn > /dev/null
/testbin/ldctl row libcurses | grep base > /tmp/b1
/testbin/ldctl row libc | grep banks > /tmp/c1
/testbin/ldctl drain libcurses
/testbin/ldctl row libcurses
/testbin/ldctl row libc | grep banks > /tmp/c2
cmp /tmp/c1 /tmp/c2 && echo RCL libc kept
LD_TRACE_LOADED_OBJECTS=1 /testbin/curssodyn | grep lcurses
/testbin/curssodyn
/testbin/ldctl row libcurses | grep base > /tmp/b2
cmp /tmp/b1 /tmp/b2 && echo RCL same base
```

`curssoreclaim.json`: command `sh /testdata/curssoreclaim`, `timeout_s` 300, description "Shared libc SP4: after curssodyn exits, the pool is drained through ld.mod's grants: curses's unused row is reclaimed (no banks, its slot kept) and libc's pinned row is not; curssodyn then reloads curses at the same base and runs.", contains `["LDC drain ok", "LDC row state=1 users=0 nbanks=0", "RCL libc kept", "prebound, loaded)", "CURS ok", "RCL same base"]` (`prebound, loaded)` can only be curses's line: the trace is filtered through `grep lcurses`), lacks `["LDC FAIL", "CURS FAIL", "ld.so:", "PANIC", "BRK"]`.

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 tools/check_vacuous_assertions.py && tools/mame_test/run.py curssoreclaim --fresh 2>&1 | tail -3`
Expected: FAIL -- `ldctl drain` is not a mode (no `LDC drain ok`).

- [ ] **Step 3: Add `drain`**

In `ldctl.c`, before `reclaimm`:

```c
/* Grant banks through throwaway rows until s's row holds none: the pool
 * runs dry, and Bank_Alloc's reclaim frees an unused row's banks. */
static int
drainm(s)
char *s;
{
    int pid, n;
    char dn[16];

    for (n = 0; n < 12; n++) {
        if (look(s) < 0) {
            say("drain", 0, s);
            return 1;
        }
        if (blk.nbanks == 0)
            return 0;
        sprintf(dn, "drain%d", n);
        pid = fork();
        if (pid == 0) {
            name(dn, 1);
            ldctl(LDS_ACQUIRE);
            blk.nbanks = 8;
            blk.core_size = 1;
            ldctl(LDS_GRANT);
            ldctl(LDS_COMMIT);
            _exit(0);
        }
        reap(pid);
    }
    look(s);
    say("drain", blk.nbanks == 0, s);
    return 0;
}
```

In `main`: `else if (strcmp(argv[1], "drain") == 0 && argc > 2) drainm(argv[2]);`. (`reclaimm` keeps its own loop: it stops on two rows.)

- [ ] **Step 4: Run it to verify it passes**

Announce. Run: `ninja > $S/t5_build.log 2>&1; tools/mame_test/run.py curssoreclaim ldctl_reclaim --fresh 2>&1 | tail -3`
Expected: `2 passed`. How reclaim picks (read before changing anything): `ld.s:892-956` scans rows by index, but `depended` (`ld.s:958-995`) skips any row a READY row's `deps` names -- so termlib (row 1) is kept while curses is READY, and curses goes first; once curses is FREE, termlib is reclaimable too and usually follows. A reload at a different base is a defect in the arena slot's keeping (spec 4).

- [ ] **Step 5: Control -- the exit hook off**

`_Ld_Exit` returns at once: curses keeps `users=1` after curssodyn exits, so it is never reclaimed. `ninja`, run `curssoreclaim` fresh: Expected FAIL (`LDC FAIL drain libcurses`). Restore, `ninja`.

- [ ] **Step 6: Commit**

```bash
git add src/userland/ldctl/ldctl.c disk_src/testdata/curssoreclaim \
        tools/mame_test/tests/curssoreclaim.json
git commit -F - <<'EOF'
test(shared-libc): an unused library reclaimed and reloaded

After curssodyn exits, the pool is drained through throwaway rows until
curses's row gives up its banks; libc's pinned row keeps its own.
curssodyn then loads curses again, at the same core base, and runs.
ldctl gains `drain'.
EOF
```

---

### Task 6: the error probes -- a library not found, data that no longer fits

**Files:**
- Modify: `toolchain/src/ld/fgx_dyn.py` (`--fit-report`), `tools/dynso-fgx2/build_dynso.sh` (cases `fitover`, `fitunder`), `tools/ninja/gen.py` (two entries), `tools/ninja/manifest.json` (two staging entries)
- Create: `src/userland/fitso/fitso.c`, `disk_src/testdata/ldfit`, `tools/mame_test/tests/ldfit.json`

**Interfaces:**
- Consumes: `ldctl pad <bytes>` (step 2), the binder's `ld.so: <prog>: no room for its data (ends $XXXX, LIM $YYYY)` and `ld.so: libtermlib.so.1: not found` (`ld_load.c:82-96, 225, 230`).
- Produces: `fgx_dyn.py --fit-report` prints `fit end $XXXX lim $YYYY` (the data's end, `len(seg1)`, and LIM, the lowest needed core less the blocks' bytes) on stdout before the fit check, whether the program fits or not. `/testbin/fitover` and `/testbin/fitunder`, one source, data ending 50 and 150 bytes below the link-time LIM; each prints `FIT ok` and exits 0 when it runs.

- [ ] **Step 1: Write the failing probe**

`disk_src/testdata/ldfit` (rulings 2, 3, Review Focus 4, 5):

```sh
# termlib renamed aside: a program needing it is refused, ldd lists it.
mv /lib/libtermlib.so.1.0 /lib/hold
/testbin/fitunder
echo FIT nf=$?
ldd /testbin/fitunder
mv /lib/hold /lib/libtermlib.so.1.0
# 100 bytes of arena held, then termlib loads 100 bytes lower than
# linked: fitover (50 under its limit) is refused, fitunder (150) runs.
/testbin/ldctl pad 100
/testbin/fitover
echo FIT over=$?
LD_TRACE_LOADED_OBJECTS=1 /testbin/fitunder > /tmp/f1
echo FIT tres=`grep -c "ltermlib.1 => .*resident)" /tmp/f1`
/testbin/fitunder
echo FIT under=$?
```

`ldfit.json`: command `sh /testdata/ldfit`, `timeout_s` 240, description "Shared libc SP4: the binder's errors.  With termlib renamed aside, a program needing it fails `not found' and ldd lists it so; restored, 100 bytes of arena held first push termlib 100 bytes lower than linked, so fitover (50 bytes under its link-time limit) fails `no room for its data' and fitunder (150) runs, finding termlib resident from the refused run.", contains `["ld.so: libtermlib.so.1: not found", "FIT nf=1", "-ltermlib.1 => not found", "fitover: no room for its data (ends $", "FIT over=1", "FIT tres=1", "FIT ok", "FIT under=0"]`, lacks `["FIT FAIL", "PANIC", "BRK"]`.

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 tools/check_vacuous_assertions.py && tools/mame_test/run.py ldfit --fresh 2>&1 | tail -3`
Expected: FAIL -- `/testbin/fitunder` is not on the image.

- [ ] **Step 3: `fgx_dyn --fit-report`**

`build()` gains a last parameter `fit_report=False`; just before `err = fit_error(...)`:

```python
    if fit_report:
        print("fit end $%04X lim $%04X" % (end, lim))
```

`main()`: `ap.add_argument("--fit-report", action="store_true", help="print the data's end and LIM")`, passed as `fit_report=a.fit_report`. Usage text at the top of the file gains the option.

Run: `python3 toolchain/src/ld/fgx_dyn.py --self-test` and, in `tools/dynso-fgx2`, the `dyntrue` link by hand with `--fit-report` added (the two lines of `build_dynso.sh`'s compile and link, into `$S/fr`).
Expected: `fgx_dyn: self-test OK`; one line `fit end $XXXX lim $YYYY` with end < lim, and the image byte-identical to `tools/dynso-fgx2/dyntrue.dyn` (`cmp`).

- [ ] **Step 4: The fixture**

`src/userland/fitso/fitso.c`:

```c
/*
 * fitso -- a dynamic program needing termlib whose data ends a fixed
 * margin below the LIM fgx_dyn computes from the libraries' assembled
 * core bases (build_dynso.sh sizes PAD1 and PAD2 from fgx_dyn
 * --fit-report).  Run where termlib's core landed lower than that, the
 * binder must refuse it.  `FIT ok' when it runs and termlib answers.
 *
 * FGX-Provenance: none
 *
 * Spec: docs/history/plans/2026-09-30-shared-libc-sp4-design.md, 9.6.
 */
#include <stdio.h>

extern int tgetent();

static char pad1[PAD1];
static char pad2[PAD2];
static char tbuf[1024];

int
main()
{
    pad1[PAD1 - 1] = 1;
    pad2[PAD2 - 1] = 1;
    printf(tgetent(tbuf, "vt100") == 1 && pad1[PAD1 - 1] == 1 &&
           pad2[PAD2 - 1] == 1 ? "FIT ok\n" : "FIT FAIL\n");
    return 0;
}
```

(Two arrays: the total is near 60 KB and fcc's `int` is 16 bits; each half stays under 32768.) `build_dynso.sh`: `fitover|fitunder) src=fitso/fitso.c; libs=libtermlib ;;`, and before the shared compile:

```bash
if [ "$name" = fitover ] || [ "$name" = fitunder ]; then
    margin=150
    [ "$name" = fitover ] && margin=50
    # A link at one byte each reports the data's end and LIM; the arrays
    # then take up all but `margin' bytes of the gap.
    "$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" -DPAD1=1 -DPAD2=1 \
        --data-segment "$name.data.s" -o "$name.s" "$REPO/src/userland/$src"
    rep=$(python3 "$LD/fgx_dyn.py" --name "$name" --dir "$name.ld" --code "$name.s" \
        --data "$name.data.s" --lib "$libs" --out "$name.dyn" --fit-report)
    end=$(echo "$rep" | sed -n 's/^fit end \$\([0-9A-F]*\) lim .*/\1/p')
    lim=$(echo "$rep" | sed -n 's/^fit end .* lim \$\([0-9A-F]*\)$/\1/p')
    gap=$((0x$lim - 0x$end - margin))
    def="-DPAD1=$((1 + gap / 2)) -DPAD2=$((1 + gap - gap / 2))"
fi
```

then the existing compile and link with `${def:-}`, `--fit-report` on the link for these two, and after it the check that the margin is exact:

```bash
if [ "$name" = fitover ] || [ "$name" = fitunder ]; then
    rep=$(python3 "$LD/fgx_dyn.py" --name "$name" --dir "$name.ld" --code "$name.s" \
        --data "$name.data.s" --lib "$libs" --out "$name.dyn" --fit-report)
    end=$(echo "$rep" | sed -n 's/^fit end \$\([0-9A-F]*\) lim .*/\1/p')
    [ $((0x$lim - 0x$end)) -eq $margin ] || {
        echo "build_dynso.sh: $name ends at \$$end, not $margin under \$$lim" >&2; exit 2; }
fi
```

(fold it into the one link if simpler: the point is that the image's own report proves the margin). `fitover|fitunder` join the "bound on the machine" copy case; both in the usage line and header comment. `gen.py`: entries `fitover` and `fitunder` modelled on `dyntrue`'s (`gate="src/userland/fitso"`, `globs=["src/userland/fitso/*"]`, `extra` gains nothing new: fgx_dyn.py is there). `manifest.json`: `tools/dynso-fgx2/fitover.bin` -> `disk_src/testbin/fitover`, the same for `fitunder`.

Run: `python3 tools/ninja/gen.py >/dev/null && ninja > $S/t6_build.log 2>&1; tail -2 $S/t6_build.log`
Expected: both build, each margin exact. If fgx_dyn refuses one with the second message (the binder's scratch below libc's core) rather than accepting it, the fixture's binding limit is the scratch rule, not the cores: STOP and record it -- the run-time check this probe aims at would not be the one reached.

- [ ] **Step 5: Run it to verify it passes**

Announce. Run: `tools/mame_test/run.py ldfit --fresh 2>&1 | tail -3`
Expected: `1 passed`. `FIT over=0` means termlib did not land lower: compare `LDC pad`'s value with libc's base (`lddelta` proves the shift for curses through ld.so.conf; here termlib through the binder; the earlier `not found` attempts never GRANT, so termlib's row has no slot when `pad` takes its own).

- [ ] **Step 6: Control -- the run-time fit check off**

In `ld_bind.c`, make the `brk > lowest - need` test `0 &&`: `ninja`, run `ldfit`: Expected FAIL (`FIT over=0`, no `no room`). Restore, `ninja`.

- [ ] **Step 7: Commit**

```bash
git add toolchain/src/ld/fgx_dyn.py src/userland/fitso/fitso.c tools/dynso-fgx2/build_dynso.sh \
        tools/ninja/gen.py tools/ninja/manifest.json disk_src/testdata/ldfit \
        tools/mame_test/tests/ldfit.json
git commit -F - <<'EOF'
test(shared-libc): a library not found, and data that no longer fits

With termlib renamed aside, a program that needs it fails `ld.so:
libtermlib.so.1: not found' and ldd lists it as not found.  With 100
bytes of arena held before termlib loads, its core lands 100 bytes
lower than the program was linked against: fitso linked 50 bytes under
its limit is refused `no room for its data', and linked 150 under it
runs, finding termlib resident from the refused run.  fgx_dyn gains
--fit-report, the data's end and LIM, which sizes the fixture.
EOF
```

---

### Task 7: retire dynsomis and dynsonodata; measurements, spec and roadmap

**Files:**
- Delete: `tools/mame_test/tests/dynsomis.json`, `tools/mame_test/tests/dynsonodata.json`
- Modify: `tools/dynso-fgx2/build_dynso.sh`, `tools/ninja/gen.py`, `tools/ninja/manifest.json`, `tools/mame_test/tests/dynsomisdyn.json` (description), `src/userland/man/pages/cat1/ldd.0` (BUGS), `docs/history/plans/2026-09-30-shared-libc-sp4-design.md` (9, 12), `docs/ROADMAP.md`
- Create: `tools/mame_test/tests/cursexec.json`

- [ ] **Step 1: Retire the two host-bound probes**

`build_dynso.sh`: drop `dynsomis` and `dynsonodata` from the case list, usage line and header comment; the moved libc moves to `dynsomisdyn`'s case:

```bash
  dynsomisdyn)
    rm -rf mis
    mkdir -p mis
    python3 "$LD/fgx_libso.py" --core-pad 2 --out mis/libc.so.1.0 --dir mis/ld
    src=dynso/dynso.c; libs=libc; def=-DDSO_SHARED; so="--so libc=mis/libc.so.1.0" ;;
```

and delete the bind-time `dynsomis`/`dynsonodata` lines (the `mis` build, `--so`, `--no-data-sites`, and the trace grep's `*)` arm, which only they reached; `dynso|cursso|dyntruebound` keep the prebound grep). `gen.py`: delete the `"dynsomis"` and `"dynsonodata"` entries; `"dynsomisdyn"` drops `tools/dynso-fgx2/dynsomis.bin` from `hard` and gains `toolchain/src/ld/fgx_libso.py` in `extra`. `manifest.json`: delete the two staging entries. `git rm` the two test files. `dynsomisdyn.json`'s description: "(dynsomis's)" becomes "(fgx_libso --core-pad 2)". `fgx_bind.py --no-data-sites` stays (fgx_bind is the host reference).

Run: `python3 tools/ninja/gen.py >/dev/null && ninja > $S/t7_build.log 2>&1; tail -2 $S/t7_build.log; ls disk_src/testbin/dynsomis disk_src/testbin/dynsonodata 2>&1; make -s -C toolchain test-archives > $S/t7_host.log 2>&1; tail -3 $S/t7_host.log`
Expected: the build succeeds; neither file staged (if the stager does not prune, remove them and note it); host tests pass. Announce, then `tools/mame_test/run.py dynsomisdyn lddigest dynso cursso --fresh 2>&1 | tail -3`; Expected `4 passed`.

```bash
git add -A tools/dynso-fgx2/build_dynso.sh tools/ninja/gen.py tools/ninja/manifest.json \
        tools/mame_test/tests/dynsomis.json tools/mame_test/tests/dynsonodata.json \
        tools/mame_test/tests/dynsomisdyn.json
git commit -F - <<'EOF'
test(shared-libc): retire the host-bound by-name probes

dynsomis and dynsonodata bound dynso by name on the host; the machine's
binder now does that on every boot (dynsomisdyn, lddigest), so they and
their 26 s of build go.  dynsomisdyn builds its moved libc itself.
dynso's host-bound image stays as the control.
EOF
```

- [ ] **Step 2: The measurements**

`cursexec.json`: name `cursexec`; command `/testbin/exectime /testbin/curssodyn 1; /testbin/exectime /testbin/curssodyn 20; /testbin/exectime /testbin/cursso 20; ldd /testbin/curssodyn` (under 255 characters); `timeout_s` 300; description "Shared libc SP4: curssodyn's first exec on a fresh boot (termlib and curses loaded on first use), its mean over 20 with both resident, and cursso's (bound on the host: it reads every library's banks per exec); the first-use cost is the first less the resident mean."; contains `["EXT /testbin/curssodyn ", "EXT /testbin/cursso "]`, lacks `["failed", "ld.so:", "PANIC", "BRK"]`.

Announce. Run: `tools/mame_test/run.py cursexec exectime --fresh 2>&1 | tail -3; grep -h "EXT \|unused cores" /tmp/fgx_test_cursexec/dump.txt /tmp/fgx_test_exectime/dump.txt`
Expected: `2 passed`. Record: curssodyn's first exec and resident mean (first-use cost = their difference), cursso's mean, the hole bytes, and exectime's three means. The gate: dynamic `true` still within 10% of `/bin/true`; if not, STOP for the maintainer. The stack surcharge (6 -> 11 pages) and ldload's boot time (libc 3.3 s) are step 2-3's numbers, unchanged by this step: cite them.

- [ ] **Step 3: ldd(1)'s BUGS**

Spec 11 says two divergences are stated in BUGS; `ldd.0` has neither. Append to its BUGS:

```
     A program whose library another process is loading waits
     for that load, for as long as the loading process is
     stopped; an interrupt ends the wait.

     Any user can make an installed library resident, until the
     bank pool needs its banks back.
```

- [ ] **Step 4: Amend the spec to the build; ROADMAP**

- Spec 9: items 2-6 as built (the probe names; rulings 1-7); the retirement done; the 255-character command limit and `/testdata` scripts as the shape of these probes.
- Spec 12: "Step 4 landed": the probes, `ldctl`'s modes, `fitso` and `--fit-report`, the measurements of step 2, the controls and what each failed, apple/fgx#505 (found by the plan's review, fixed per 2.11BSD `psignal()`), anything else found, and that the full manifest run passed but `manyproc` and `wuptime`.
- ROADMAP's shared libc paragraph: step 4 landed; sub-project 4 is complete; next, sub-project 5 (the cut-over) -- its spec first.

- [ ] **Step 5: The full manifest run**

Announce (it takes hours). Run the Global Constraints' every-manifest command, output to `$S/t7_all.log`.
Expected: every manifest passes but `manyproc` and `wuptime`. Any other failure: run it on main to see whether this branch caused it; a branch regression is fixed before the commit (systematic-debugging, its own commit).

- [ ] **Step 6: Commit**

```bash
git add tools/mame_test/tests/cursexec.json src/userland/man/pages/cat1/ldd.0 \
        docs/history/plans/2026-09-30-shared-libc-sp4-design.md docs/ROADMAP.md
git commit -F - <<'EOF'
docs(shared-libc): SP4 step 4 as built

First use, the race, the kill, reclaim and the binder's errors proven
in MAME, with their controls; curses's first-use cost and its resident
exec measured (cursexec).  ldd(1)'s BUGS state the wait on another
process's load and that any user can make a library resident.
ROADMAP: sub-project 4 is complete; the cut-over is next.
EOF
```

---

Revised after an adversarial review of this plan (Fable, 2026-10-02): every finding adopted -- the 255-character typed-command limit (probes as `/testdata` scripts), SIGKILL not ending a stopped process (apple/fgx#505, Task 1), a vacuous `resident)` needle, the race made deterministic by stopping the loader, `--fit-report` in place of parsing a refusal, the stop sent by `ldctl` itself, reclaim's order through `depended`, the core-base needle, and the measurement's wording.
