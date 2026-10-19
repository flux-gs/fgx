# Concurrent fork -- implementation plan

> For agentic workers: REQUIRED SUB-SKILL: superpowers:executing-plans, INLINE.
> The kernel tasks are 65816 assembly, which stays with the main agent
> (standing rule): no subagent writes Merlin32.  Steps use `- [ ]` boxes.

**Goal:** after `fork(2)`, parent and child both run whether or not the child
execs; daemon(3) regains 2.11BSD's fork and /etc/rc loses its `&`s
(apple/fgx#494).

**Architecture:** a snapshot fork's members form an image group at one set of
addresses.  One member is resident; the others are parked in homes -- a Uimg
home for the stack range and direct page, a bank home (spare banks) for the
group's mutable bank set -- and `Uimg_Ensure` swaps them.  The parent is
released at the child's first interruptible sleep or quantum yield.

**Tech stack:** Merlin32 65816 assembly (kernel), fcc K&R C (probes, libc),
the MAME harness (`tools/mame_test`), Python (check scripts).

**Spec:** `docs/history/plans/2026-09-26-concurrent-fork-design.md`.

## Global constraints

- ASCII only in every file.
- Comments describe the current state only; history goes in commit bodies.
- Cite the 2.11BSD / Reno / FreeBSD source by file and function (or line) for
  every behaviour with a BSD counterpart; quote K&R for any fcc change.
- Announce every rebuild and every change of branch.
- Do not edit build inputs while `tools/gate.sh` or a suite run is running.
- Never `git checkout` a generated tracked file (kernel_exports.s etc.).
- Build: `make -C toolchain && python3 tools/ninja/gen.py && ninja`.
  Single tests: `python3 tools/mame_test/run.py --fresh <name>...`.
  Gate: `tools/gate.sh`.  Full suite: `python3 tools/mame_test/run.py`.
- Every new test must go red on the kernel before the change it proves; each
  mutation named below is run and its result recorded in the commit body.
- The gate's seconds budget is not raised: new cases go in the MAME suite.
- Commit bodies are informational changelog: no names, no process, no
  follow-ups; trailers as the session requires.

## Names used across tasks

| Name | Kind | Where | Meaning |
|---|---|---|---|
| `SEF_FORKREL` | `%10000000` | `include/kernel.s` | snapshot child has been released |
| `_imgOwner` | `DS TASK_MAX_SLOTS` | `src/kernel/task.s` | per pid-1: owner pid of its image group, 0 = none |
| `_kImgCopies` | `DS 2` | `src/kernel/task.s` | count of image copies (one per park, restore or snapshot of a member) |
| `Img_Release` | routine | `src/kernel/process.s` | X = TCB of the running snapshot child; releases it if homes can be had |
| `_Img_BankMove` | routine | `src/kernel/process.s` | A = pid, `_ks_dir` 0 park / 1 restore: that member's bank set <-> its bank home |
| `Img_HandOff` | routine | `src/kernel/process.s` | X = TCB of an exiting or exec'ing owner: give the image to an heir |
| `Img_DataHome` | routine | `src/kernel/process.s` | A = pid: C=1 A = the bank holding that member's data-bank bytes |
| `forkpair` | probe | `src/userland/forkpair/forkpair.c` | modes `order`, `bytes`, `orphan`, `three`, `hwm` |
| `daemontest` | probe | `src/userland/daemontest/daemontest.c` | calls daemon(3), sleeps, writes a marker |

`SE_SnapPtr` changes meaning in Task 5: from "the parent's snapshot, held by
the child" to "this task's own bank home descriptor".

---

### Task 1: survey and the heap-break check (documentation only)

**Files:** Modify `docs/history/plans/2026-09-26-concurrent-fork-design.md`
(section 5 table, section 3 bound).

- [ ] **Step 1: foreign-write survey.**  For each path, record in a table
  (path, file:line, writes into whose memory, in whose context, verdict):
  - interrupt handlers: `grep -n "ENT\|RTI" src/kernel/*.s src/modules/*/*.s`
    for the IRQ chain; follow serial RX, W5100 RX (`_Sock_PollIntr`),
    keyboard ring, ADB; any `STA [..]` whose bank byte comes from a task's
    `SE_CallerBank`/`TCB_DataBank` outside that task's own syscall;
  - SmartPort reads: does any read land in a user buffer directly, or only in
    `BLK_STAGE` then `MVN` in the caller's context (`b3-stack-swap-scope.md`
    table)?
  - far-bank and module code that saves a caller bank+offset and writes it
    after a `_sleep`/`kc_sleep` (search `SE_CallerBank`, `_Sys_CallerBank`,
    `KFAR_` call sites that sleep);
  - kernel readers of another task's data bank (`PI_HeapHwm` in
    `src/kernel/syscall.s:5290-5311`, any other `TCB_DataBank` dereference:
    `grep -n "TCB_DataBank" src/kernel/*.s src/kernel/far/*.s`).
  Each row's verdict: SAFE (owner's context), LOCK (needs `SEF_STKLOCK` for a
  window -- name the window), or REDIRECT (reads through `Img_DataHome`).
- [ ] **Step 2: heap-break check.**  Confirm nothing in a data bank lives in
  `[*HEAP_BRK, $FFFA)`: read `toolchain/lib/libc_c/malloc.c` (sbrk and the
  allocator), `toolchain/lib/crt0*.s` / loader data placement
  (`src/kernel/far/loader.s`, where the data segment and `end` are laid), the
  soft-frame and argv staging (`b3-stack-swap-scope.md` "argv frame staged
  into the home bank"), and tcsh/elvis/bsh private allocators (sh's own
  malloc in `src/userland/sh`).  Record the answer, with citations, in
  section 3.  If anything does live there, stop and report before Task 3.
- [ ] **Step 3: commit** `docs: concurrent fork -- the foreign-write survey`.
  No gate (a doc change reaches no build input).

### Task 2: the probes, red, and the copy counter

**Files:**
- Create: `src/userland/forkpair/forkpair.c`, `src/userland/daemontest/daemontest.c`
- Create: `tools/mame_test/tests/forkpair_{order,bytes,orphan,three,hwm}.json`,
  `tools/mame_test/tests/forkcost.json`, `tools/mame_test/tests/forkcost_check.py`,
  `tools/mame_test/tests/daemontest.json`
- Modify: `tools/ninja/manifest.json` (tools `forkpair`, `daemontest`; staging to
  `disk_src/testbin/`), `src/kernel/task.s` (`_kImgCopies`),
  `src/kernel/process.s` (increment it)

**Interfaces:** Produces `_kImgCopies` (kernel data word, symbol in the kernel
listing), incremented once per `_Fork_Snapshot` and once per `_Fork_Restore`.

- [ ] **Step 1: forkpair.c**

```c
/* forkpair -- concurrent fork (apple/fgx#494).  One mode per run:
 *   order   the parent runs while its child sleeps:   FP ORDER ok
 *   bytes   each side keeps its own global, heap byte and stack local
 *           across alternating sleeps:                  FP BYTES ok
 *   orphan  the parent exits at once; the sleeping child is reparented to
 *           init, then execs echo:                      FP ORPHAN ok
 *   three   parent, child and grandchild each keep their own bytes:
 *                                                        FP THREE ok
 *   hwm     ps's heap high-water mark for a parked member is its own:
 *                                                        FP HWM ok
 * Every mode prints FP ... FAIL on a wrong answer. */
#include <stdio.h>
#include <string.h>
#include <fgx.h>

int fork();
int wait(int *status);
int getppid();
int getpid();
char *sbrk(int incr);
void _exit(int code);
int execl();
int sleep();
int open();
int close();
int unlink();
int access();

int g;
static struct procinfo plist[16];       /* data bank: procs writes via DBR */

/* Set all three tiers to v, sleep s seconds, then check them. */
static int
tiers(char *h, int v, int s)
{
    int loc;

    g = v;
    h[0] = v;
    loc = v;
    if (s)
        sleep(s);
    return g == v && h[0] == v && loc == v;
}

static int
hwm_of(int pid)
{
    int n, i;

    n = procs((char *)plist, 16);
    for (i = 0; i < n; i++)
        if (plist[i].pid == pid)
            return plist[i].heaphwm;
    return -1;
}

int
main(int argc, char **argv)
{
    char *h, *m;
    int pid, st, ok, kid;

    m = argc > 1 ? argv[1] : "";
    h = sbrk(64);
    if (h == (char *)-1) { printf("FP FAIL sbrk\n"); return 1; }

    if (strcmp(m, "order") == 0) {
        unlink("/tmp/fp.order");
        pid = fork();
        if (pid == 0) {
            sleep(2);
            _exit(access("/tmp/fp.order", 0) == 0 ? 0 : 1);
        }
        close(open("/tmp/fp.order", 0x0201, 0644));  /* O_WRONLY|O_CREAT */
        wait(&st);
        printf("FP ORDER %s\n", st == 0 ? "ok" : "FAIL");
        return 0;
    }
    if (strcmp(m, "bytes") == 0) {
        pid = fork();
        if (pid == 0) {
            ok = tiers(h, 22, 1) && tiers(h, 23, 1) && tiers(h, 24, 0);
            _exit(ok ? 0 : 3);
        }
        ok = tiers(h, 11, 1) && tiers(h, 12, 1) && tiers(h, 13, 0);
        wait(&st);
        printf("FP BYTES %s\n", ok && st == 0 ? "ok" : "FAIL");
        return 0;
    }
    if (strcmp(m, "orphan") == 0) {
        pid = fork();
        if (pid == 0) {
            sleep(2);
            if (getppid() != 1)
                execl("/bin/echo", "echo", "FP ORPHAN FAIL", (char *)0);
            else
                execl("/bin/echo", "echo", "FP ORPHAN ok", (char *)0);
            _exit(127);
        }
        _exit(0);
    }
    if (strcmp(m, "three") == 0) {
        pid = fork();
        if (pid == 0) {
            kid = fork();
            if (kid == 0) {
                ok = tiers(h, 33, 1) && tiers(h, 34, 1) && tiers(h, 35, 0);
                _exit(ok ? 0 : 5);
            }
            ok = tiers(h, 22, 1) && tiers(h, 23, 1) && tiers(h, 24, 0);
            wait(&st);
            _exit(ok && st == 0 ? 0 : 4);
        }
        ok = tiers(h, 11, 1) && tiers(h, 12, 1) && tiers(h, 13, 0);
        wait(&st);
        printf("FP THREE %s\n", ok && st == 0 ? "ok" : "FAIL");
        return 0;
    }
    if (strcmp(m, "hwm") == 0) {
        pid = fork();
        if (pid == 0) {
            sleep(2);                   /* parked while the parent measures */
            _exit(0);
        }
        sbrk(8192)[8191] = 1;           /* the parent's break rises */
        ok = hwm_of(pid) > 0 && hwm_of(pid) != hwm_of(getpid());
        wait(&st);
        printf("FP HWM %s\n", ok ? "ok" : "FAIL");
        return 0;
    }
    printf("usage: forkpair order|bytes|orphan|three|hwm\n");
    return 2;
}
```

  Check `O_WRONLY|O_CREAT` against `toolchain/include/fcntl.h` and use the
  header's names if they differ from `0x0201`.

- [ ] **Step 2: daemontest.c**

```c
/* daemontest -- daemon(3) returns its invoker (apple/fgx#494).  The shell's
 * next command runs at once; the daemon writes /tmp/dt.mark two seconds
 * later, after its parent has exited. */
#include <stdio.h>

int daemon();
int sleep();
int open();
int close();

int
main()
{
    if (daemon(0, 1) < 0) { printf("DT FAIL daemon\n"); return 1; }
    sleep(2);
    close(open("/tmp/dt.mark", 0x0201, 0644));
    return 0;
}
```

- [ ] **Step 3: the test JSONs.**  Pattern (forkpair_order.json; the others
  change the mode and needle; `orphan` asserts `FP ORPHAN ok` and lacks
  `FP ORPHAN FAIL`):

```json
{
 "name": "forkpair_order",
 "description": "Concurrent fork (apple/fgx#494): the parent runs while its child sleeps.  The child sleeps 2 s and then looks for a file the parent creates after fork; the parent then waits.  On a deferred-parent fork the parent cannot run until the child exits, so the file is absent and FP ORDER FAIL.",
 "command": "/testbin/forkpair order",
 "timeout_s": 60,
 "expect": {
  "screen_contains": ["FP ORDER ok"],
  "screen_lacks": ["FAIL", "PANIC", "BRK"]
 }
}
```

  daemontest.json, `command`:
  `sh -c '/testbin/daemontest; A=DT; B=BACK; echo $A$B; sleep 4; test -f /tmp/dt.mark && echo DT=$A$B'`
  expecting `DTBACK` and `DT=DTBACK`, lacking `FAIL`.  (Today `DTBACK` prints
  and so does the mark, so this case is red only after Task 8 restores the
  fork -- it proves Task 8, not Task 5; note that in its description.)

- [ ] **Step 4: forkcost.** Add `_kImgCopies DS 2` beside the `_ui*` state in
  `src/kernel/task.s` (zeroed in `Uimg_Init`), and `INC _kImgCopies` at the
  top of `_Fork_Snapshot` and `_Fork_Restore` (`src/kernel/process.s`).
  forkcost.json runs `/bin/true` at the prompt with `poison` setting
  `_kImgCopies` to `0000` at the frame after boot (the harness's
  `paste_frame`; read `tools/mame_test/run.py` for the poison frame
  semantics, and remember frames are absolute), `memory_regions`
  `{ "name": "kimg", "symbol": "_kImgCopies", "len": 2 }`, and
  forkcost_check.py asserting the little-endian word equals 2.

- [ ] **Step 5: register and build.**  Add `forkpair` and `daemontest` to
  `tools/ninja/manifest.json` (tools list and `disk_src/testbin/` staging,
  as tztest is).  Rebuild (announce).
- [ ] **Step 6: run red.**  `python3 tools/mame_test/run.py --fresh
  forkpair_order forkpair_bytes forkpair_orphan forkpair_three forkpair_hwm
  forkcost`.  Expected: order FAIL, orphan FAIL, three/bytes/hwm FAIL or
  timeout (the parent never runs early), forkcost PASS (2 today).  Record the
  output.
- [ ] **Step 7: commit** `test: forkpair and daemontest, concurrent fork probes;
  a kernel image-copy counter`.  No gate needed for red tests alone, but the
  counter is kernel code: run `tools/gate.sh` first.

**Done (as built):** `bytes` and `three` also require a marker file the
parent writes after its own sleeps, read by the last sleeper -- without it
both passed on the deferred-parent kernel, since the child simply ran to
completion first.  `orphan` runs as `forkpair orphan; sleep 4` so the
orphan's echo lands while the console is up.  daemontest asserts `EARLYDT`
(the mark is absent when the shell moves on), which makes it red today.
forkcost's poke uses bank `$7C`, the core kernel bank (FGX_DATA is `$7D`).
Red on the kernel before Task 3: all five forkpair modes print their FAIL
line; daemontest lacks EARLYDT; forkcost reads 2 (PASS).

### Task 3: bound the data bank's copy by the heap break

**Files:** Modify `src/kernel/process.s` (`_Fork_Snapshot` pair 0,
`_Fork_CopyBank` / `_Fork_CopyRange`, `_Fork_Restore`).

**Interfaces:** Produces a pair form with an END: pair stride grows from 4 to
6 (`orig(1) spare(1) start(2) end(2)`), `FSD_PAIR_STRIDE EQU 6`, and
`_Fork_CopyBank` copies `[start, end]` then, for a data-bank pair,
`[$FFFA, $FFFF]`.

- [ ] **Step 1:** Change `FSD_PAIR_STRIDE` to 6 and every `ASL ASL` pair-index
  computation to multiply by 6 (search `pair stride 4` in process.s).  Store
  `end`: pair 0 = `(dataBank:HEAP_BRK) - 1` read at snapshot/park time, all
  other pairs = `$FFFF`.  Keep the `$FFFA-$FFFF` tail copy for pair 0 only.
  Update the pair-0 comment: the bound is the break, which covers the heap;
  the data-segment bound it rejects stays rejected.
- [ ] **Step 2: tests.**  `python3 tools/mame_test/run.py --fresh fkiso fknest
  softfork vfexec vfexit bigforkx forkcost` all PASS; add a mutation run with
  `end` forced to `$0FFF` for pair 0: fkiso must FAIL (the heap byte is above
  it).  Record both.
- [ ] **Step 3:** Measure: boot frames to the first prompt, before (Task 2's
  build) and after, from `bootstk` or the boot test's dump frame; record.
- [ ] **Step 4:** gate; commit `perf(kernel): a fork copies the data bank only
  up to its break`.

**Done (as built):** only the data bank's pair has a bound, so the stride
stays 4 and the bound lives in the descriptor's former pad word,
`FSD_DATAEND` (offset 42).  `_Fork_CopyBank` copies `[_fs_start, _fs_end]`
and, when `_fs_end` is below `$FFFF`, the heap cells `[HEAP_BASE, $FFFF]`.
The precondition -- nothing live above any break -- was proved by restoring
2.11BSD's sbrk zero-fill (apple/fgx#361), which found three more sh writers
past the break (getstak, addblok, the lexer's count).  Mutation `end = $0FFF`:
softexec, softfork and stakovr go red; fkiso stays green (its heap byte is
not above $0FFF).  Timing, 20 x `/bin/true` from sh: prompt-exit at frame
4728 before, 4584 after (-144 frames, ~7 per fork), both repeatable.

### Task 4: snapshot children join the image cache (stack and direct page)

**Files:** Modify `include/kernel.s` (`SEF_FORKREL`), `src/kernel/task.s`
(`_imgOwner`, `_Uimg_Held`, `_Uimg_Walk`, `Uimg_Init`), `src/kernel/process.s`
(`_vf_common` mode 1, `_Fork_Snapshot` tail, exec and exit hand-back).

**Interfaces:** Produces `_imgOwner[pid-1]`; after this task a snapshot child
is an ordinary Uimg claimant, resident at fork; the parent is parked at fork
through `Uimg_HomeAlloc` + `_Uimg_Park`.  Banks are still restored eagerly by
`_Fork_Restore`.  Behaviour is unchanged (the parent still waits).

- [ ] **Step 1:** `SEF_FORKREL EQU %10000000` in `include/kernel.s` with a
  comment naming what sets and clears it (Tasks 5 and 6).
- [ ] **Step 2:** `_Uimg_Held` and `_Uimg_Walk` test `SEF_VFORKCHILD` only
  (`task.s:2982` and `task.s:3105`), with the comment saying a snapshot child
  is an ordinary claimant of its range.
- [ ] **Step 3:** In `_vf_common`, mode 1 only: replace `Task_BorrowSet` on the
  parent (`process.s`, step 9) with: `Uimg_HomeAlloc` for the parent's range
  (fail -> the existing `@vf_rollback`, errno ENOMEM, before the child is made
  READY), `_Uimg_Park` of the parent, `_uiResident[child] = 1`,
  `_imgOwner[parent] = _imgOwner[child] = parent pid`, `INC _kImgCopies`.
  Mode 0 keeps `Task_BorrowSet`.
- [ ] **Step 4:** `_Fork_Snapshot` stops snapshotting the stack extent and DP
  (the tail after the bank pairs, `process.s` around the `FSD_STKBASE` /
  `FSD_DPPAGE` stores) and `_Fork_Restore` stops restoring them.  The parent's
  stack and DP now return through `Uimg_Ensure` when it is next picked.
- [ ] **Step 5:** exec and exit hand-back (`process.s` @evf_* and @psx_*): for
  a snapshot child, `_uiResident[child] = 0` and `_imgOwner[child] = 0` before
  the wake; `Task_BorrowClr` only for a vfork child.  When the group's last
  non-owner leaves, `_imgOwner[owner] = 0`.
- [ ] **Step 6:** rebuild (announce); `python3 tools/mame_test/run.py --fresh
  fkiso fknest softfork vfexec vfexit bigforkx manyproc forkcost` PASS; then
  gate and the full suite (wuptime #498 is the known failure).
- [ ] **Step 7:** commit `refactor(kernel): a snapshot fork child is an ordinary
  claimant of its parent's range`.

**Done (as built):** `_imgOwner` and `SEF_FORKREL` are left to Task 5,
their first user.  The parent's home is allocated BEFORE the snapshot, so a
pool out of units fails the fork through the ordinary rollback.  The child is
PINNED by `SEF_SNAPCHILD` (Uimg_Evictable and the UI_RANK walk) rather than
having its residency cleared: at exec, Task_AllocStack sets the new range's
residency, and an unpinned child sleeping on exec's disk reads would be
parked with no home (a halt).  The exit hand-back clears the dead child's
residency.  inittermbusy exposed an init defect -- SIGTERM delivered inside
the ttys merge -- fixed in init.c to 2.11BSD's `mvec` before this commit.

### Task 5: release, and the bank set swaps

**Files:** Modify `src/kernel/sched.s` (`_sleep`), `src/kernel/syscall.s` (the
quantum yield, `syscall.s:433-448`), `src/kernel/process.s` (`Img_Release`,
`_Img_BankMove`, `_vf_common` wait predicate, `_Fork_Snapshot` descriptor
ownership, hand-back), `src/kernel/task.s` (`_Uimg_Park`, `_Uimg_Restore`).

**Interfaces:**
- `Img_Release` -- In: X = running TCB, MX %00, IRQs off.  If the task has
  `SEF_SNAPCHILD` and not `SEF_FORKREL`: allocate its Uimg home
  (`Uimg_HomeAlloc`, its range) and a bank home descriptor with one spare
  per pair of the group's set; on success set `SEF_FORKREL` and
  `_wakeup(WCHAN_VFORK)`; on failure change nothing.  Preserves X/Y.
- `_Img_BankMove` -- In: A = pid of a group member, `_ks_dir` 0 = live banks
  -> that pid's spares, 1 = spares -> live; its descriptor is its own
  `SE_SnapPtr`.  Increments `_kImgCopies`.  No-op if the pid has no
  descriptor.  Extents are that member's own, recomputed per call: pair 0
  `[0, HEAP_BRK)` plus `$FFFA-$FFFF` (Task 3), the soft-bank pair from
  `_fcc_sfp` in the member's direct page (live in bank 0 at both call sites:
  a park copies the page without clearing it, a restore has just put it
  back), big-block pairs whole.
- `SE_SnapPtr` = this task's own bank home.  At fork the snapshot descriptor
  goes on the PARENT's `SE_SnapPtr` (reused if it has one from an earlier
  fork, its spares refreshed).

- [ ] **Step 1:** `_sleep` (`sched.s`, `@slp_go`): before `JSR _Slp_Block`,
  `LDX _curTCB`-equivalent (read how `_sleep` names the running TCB) and
  `JSR Img_Release`.  `_sleepUn` is NOT changed; say why in a comment (exec's
  disk reads sleep there, and a release there costs the shell's hot path two
  image copies).
- [ ] **Step 2:** the syscall-boundary yield: the same call before
  `JSR _Sys_Yield`.
- [ ] **Step 3:** `_vf_common`'s wait loop: after the flagged test, `BIT
  #SEF_FORKREL` / `BNE @vf_done`.
- [ ] **Step 4:** `_Uimg_Park` and `_Uimg_Restore`: after `_Uimg_Move`, if
  `_imgOwner[pid-1] != 0`, `JSR _Img_BankMove` in the same direction.  One
  place parks and restores a member: bytes, banks, residency.
- [ ] **Step 5:** hand-back: `_Fork_Restore` is no longer called from the
  child.  A snapshot child that execs or exits frees its own homes (Uimg and
  bank descriptor with spares), clears `SEF_SNAPCHILD` and `SEF_FORKREL` (the
  `AND #$FFE7` masks become `AND #$FF67`), and leaves the group; the parent's
  bytes return when it is picked.  When one member remains, the group
  dissolves: after that member is next restored (or at once if it is
  resident), its Uimg home and bank descriptor are freed and its `_imgOwner`
  cleared.
- [ ] **Step 5b:** apply every LOCK row from Task 1's survey: set
  `SEF_STKLOCK` for the named window, cleared on every exit from it, with a
  comment citing the survey row.
- [ ] **Step 6:** rebuild; `forkpair_order forkpair_bytes forkpair_three
  forkcost fkiso fknest softfork vfexec vfexit bigforkx manyproc` PASS.
  Mutations, each run and recorded: (a) call `Img_Release` from `_sleepUn`
  too -> forkcost FAIL (4 or more); (b) skip `_Img_BankMove` in
  `_Uimg_Restore` -> forkpair_bytes FAIL.
- [ ] **Step 7:** gate, full suite; commit `feat(kernel): a fork's parent runs
  while its child sleeps`.

**Done (as built):** see design section 3.1 -- N-1 bank homes with an
exchange at each swap (`Img_Swap`, `_Img_Xchg`, `_Img_Leave`), no
`_Img_DupHome`, and `Img_Release` from `_sleep` only.  `_Fork_Restore` is
gone.  Mutation (b), no `Img_Swap`: forkpair_bytes FAILS.  Mutation (a),
release from `_sleepUn`, and releasing at the quantum yield both leave
forkcost at 2: exec on the hot path never sleeps and finishes inside a
quantum, so forkcost cannot see where the release is.  Found and fixed
alongside: `Uimg_HomeAlloc` recorded a re-homed pid's home under the wrong
pid (bc6795cad).

### Task 6: the owner's exit and exec hand the image on

**Files:** Modify `src/kernel/process.s` (`Img_HandOff`, `_Sys_Exit` path
before `_Task_FreeBanks`, exec before the plain-exec reclaim).

**Interfaces:** `Img_HandOff` -- In: X = TCB of the owner.  If any other task
has `_imgOwner == owner pid`: choose the heir (the resident member, else the
lowest pid); move `TCB_BankList`, `TCB_StackBase`/`TCB_StackSize`,
`SE_SoftBank`, the big-block rows (re-key owner pid to heir pid in the
`_BlkRow` table: read `_BlkRow_FreeByOwner` for the row layout), and set
`_imgOwner[m] = heir` for every remaining member; clear the owner's copies so
its own frees find nothing.  Panics (`_Kern_Halt` with a message) if the group
has two owners or none.

- [ ] **Step 1:** implement `Img_HandOff`; call it at exit before
  `_Task_FreeBanks` and at a successful exec before the outgoing image is
  reclaimed.
- [ ] **Step 2:** rebuild; `forkpair_orphan` PASS (FP ORPHAN ok), the gate's
  bank-pairing check green.  Mutation: skip `Img_HandOff` at exit ->
  forkpair_orphan FAIL or the pairing check reports (record which).
- [ ] **Step 3:** gate, full suite; commit `feat(kernel): an image outlives the
  fork parent that owned it`.

**Done (as built):** no `_imgOwner` array: the owner of a group is its
member that is not a snapshot child, and the heir becomes the owner by
losing `SEF_SNAPCHILD`/`SEF_FORKREL`.  `Img_HandOff` runs at exit before
`_Task_FreeBanks` and at a plain exec's commit (from the saved `_ev_old*`
image, before the reclaim), followed by `_Img_Leave`.  A vfork child is in no
group and is skipped by both -- handled as an owner it handed its (empty)
bank list to its suspended parent, and the parent's banks leaked (manyproc
`too big`).  Mutation, no hand-off at exit: forkpair_orphan halts with `uimg:
no home for pid N`.

### Task 7: ps reads a parked member's heap mark from its home

**Files:** Modify `src/kernel/process.s` (`Img_DataHome`),
`src/kernel/syscall.s:5290-5311` (`PI_HeapHwm`).

- [ ] **Step 1:** `Img_DataHome`: A = pid; resident or not in a group -> its
  `TCB_DataBank`; parked -> pair 0's spare in its bank home.
- [ ] **Step 2:** the `PI_HeapHwm` fill reads `HEAP_HWM` from the bank
  `Img_DataHome` returns.
- [ ] **Step 3:** rebuild; `forkpair_hwm` PASS.  Mutation: read `TCB_DataBank`
  again -> FAIL.  Gate; commit `fix(kernel): ps reports a parked fork member's
  own heap mark`.

### Task 8: daemon(3) forks; /etc/rc starts daemons without `&`

**Files:** Modify `toolchain/lib/libc_c/daemon.c`, `disk_src/etc/rc.in`,
`src/userland/man/pages/cat8/{syslogd,adjkerntz}.0`, `docs/PROVENANCE.md`;
check `src/userland/man/pages/cat1/{sh,tcsh}.0` for a stated subshell limit.

- [ ] **Step 1:** daemon.c: upstream's `switch (fork()) { case -1: return
  (-1); case 0: break; default: _exit(0); }`
  (`vendor/2.11BSD/usr/lib/libc/gen/daemon.c:48-54`) before the TIOCNOTTY
  walk; the header loses "THE FORK IS NOT DONE" and keeps the TIOCNOTTY delta.
- [ ] **Step 2:** rc.in: drop `&` from `/sbin/adjkerntz -i`, `/sbin/syslogd`,
  `/sbin/update`, `/sbin/inetd`; delete the BACKGROUNDED comments; keep the
  bounded syslog.pid wait with its reason.
- [ ] **Step 3:** man pages: syslogd(8) and adjkerntz(8) lose the `&` BUGS
  paragraph (adjkerntz.0 re-rendered from its roff with the two remaining
  BUGS items, `mandoc -T ascii`, `tools/check_man_overstrike.py`).
  PROVENANCE rows for daemon.c, syslogd.0 and adjkerntz.0 updated.
- [ ] **Step 4:** rebuild; `daemontest` PASS; the boot tests and
  `python3 tools/mame_test/run.py --fresh daemontest slogprobe` PASS; boot
  frames to the first prompt measured and compared with Task 2's.
- [ ] **Step 5:** gate, full suite; commit `feat(libc): daemon(3) forks, and
  /etc/rc starts daemons as BSD does` (closes #494).

### Task 9: documentation and the MR

- [ ] ROADMAP: a one-paragraph entry for concurrent fork (what it does, the
  cost, the design path); the design's status "implemented" with any
  departures listed in this plan under "As built".
- [ ] the project notes: what landed, the survey table, the measured copy counts and
  boot frames.
- [ ] Gate on the head, full suite; ask before pushing
  `feat/494-concurrent-fork` (`ALLOW_FEAT_PUSH=1`, `FGX_NO_GATE=1` when the
  head is gated) and opening the MR (no Claude line or URL in its
  description).
