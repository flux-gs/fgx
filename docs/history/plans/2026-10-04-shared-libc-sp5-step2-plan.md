# Shared libc SP5 step 2: the boot order, libfgx.so, libutil.so and the relink -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every manifest tool and fas runs as a dynamic program against libc.so (plus libfgx.so, libutil.so, libtermlib.so, libcurses.so where it needs them), except a small static set linked by fgx_static and `ac` (step 3), with `/etc/rc` loading the libraries before anything else.

**Architecture:** `/etc/rc` runs `modload ld` and `ldload` first and stops if libc is not resident.  libfgx and libutil are built as shared libraries the way libtermlib is (fcc `--libso`, fgx_libso).  fgx_dyn drops a library a program does not reference, so every tool can be offered libfgx.  fgx_static takes a library's sections and extra code segments.  `gen.py` links a manifest tool dynamically by default, statically with `"static": true`, and through the pile only with `"pile": true`.

**Tech Stack:** Python 3 host tools (`toolchain/src/ld/`), fcc K&R C (`toolchain/lib/*_c/`), Merlin32 65816 assembly, ninja via `tools/ninja/gen.py`, the toolchain Makefile, headless MAME tests (`tools/mame_test/run.py`).

**Status:** revised for an adversarial review (Fable, 2026-10-04): three Critical, nine Important and eight Minor findings, all adopted.

**Spec:** [`2026-10-04-shared-libc-sp5-design.md`](2026-10-04-shared-libc-sp5-design.md), sections 6, 6.1, 6.2, 6.3 and 8 item 2 (as of 1cb069d7c).  Step 1's plan, [`2026-10-04-shared-libc-sp5-step1-plan.md`](2026-10-04-shared-libc-sp5-step1-plan.md), built the dynamic mode this one uses.

## Global Constraints

- ASCII only in every file.
- 65816 assembly is written by the main agent, not delegated (standing rule).
- Commit bodies are the changelog: informational, no process, no follow-ups; end with the session's Co-Authored-By and Claude-Session trailers.
- No push, no MR (feat branch; `ALLOW_FEAT_PUSH=1` only when the maintainer asks).
- Headless MAME only: `tools/mame_test/run.py`; never a raw `mame64`.
- A test that cannot go red is not coverage: every new check states its control and the control is run once.
- New MAME tests are probes and do not join `GATE_TESTS` (`tools/gate.sh:633-639`); the gate's seconds ratchet has no headroom.
- Nothing in spec section 7 is retired here: the pile path, the overlay rules, `PILE_CARRIES_OWN`, `util.fgxa` and `crt0_far.s` stay until step 5, unused where this step stops using them.
- Toolchain-first: a gap in fcc, libc or the linkers is fixed there, never worked around in a tool.
- Read the BSD counterpart before changing a libc/libfgx function or rc behaviour and name it in the commit; a file taken from gitignored `examples/` is vendored under `vendor/` in the same commit.
- Source comments describe the current state only.
- Commit bodies: where a step shows `Body:` it lists what the body states; compose it from that list and the task's Files, in the informational voice of the changelog (what changed and why, BSD/SunOS sources named), with no process and no follow-ups.
- sh, tcsh and vi are step 3: untouched here.  `ac` stays on its pile (`"pile": true`) until step 3 measures it.

## Plan rulings (decisions the spec left to the plan, and deviations)

- **R1. libfgx passes `environ`, it does not get staging cells.**  Spec 6.2 says libfgx "owns its own staging cells".  Its spawn family copies the exec-time environment out of libc's `args_env` into its own `sys_envp` table.  2.11BSD's `execv` passes the process's current environment: `mov	_environ,-(sp)	/ pass default environment,` (`examples/2.11BSD/usr/lib/libc/pdp/sys/execv.s`).  `environ` is a libc.so data export (`toolchain/lib/libc_c/data.exports`).  So `spawnv` passes `environ`, and `sys_envp`, `__fgx_build_envp` and the `args_env` reach all go.  The unused `_libc_lstrBufA` declaration goes too.  The spec is amended in Task 1.  Cost if wrong: a child would see the parent's edited environment where it used to see the exec-time one, which is BSD's behaviour.
- **R2. `ldload` exits 2 when libc is not resident.**  Spec 6.1 writes `ldload || exit 1`.  But ldload exits 1 if ANY library fails (`ldload.c:129-130`, `ldload.8`): a bad `/etc/ld.so.conf` line would then stop the boot, which the spec does not intend.  ldload now exits 2 when libc is not resident and 1 when only a listed library failed, and rc stops on 2 with a `case`, which is a sh builtin.  The spec is amended in Task 1.  Cost if wrong: one exit code.
- **R3. A static link takes a library as program-mode sections.**  fgx_static links libc's library-mode compile, which is libc-specific (`_libc_blktab`, its cells and templates).  libfgx and libutil are compiled the way a program's own source is (`fcc --sigs build/libc.sigs --sections`), and fgx_static prunes them as it prunes libc (`--lib CODE,DATA`), so a static program carries only the functions it reaches.  The `util.fgxa` archive is then used only by pile links, and retires with them in step 5.  Spec 6.3 ("the util archive stays for the static links") is amended in Task 1.  Cost if wrong: a static program carries a library's statics in its own data, which is the definition of a static link.
- **R4. libutil's static users are init and login.**  Spec 6.3 says init, login and fsck.  The manifest gives `libs: util` to init, login and telnetd only (`tools/ninja/manifest.json`); fsck has none.  Amended in Task 1.
- **R5. A manifest tool is dynamic unless marked.**  `"static": true` links it with fgx_static, and `"pile": true` keeps today's pile link (ac only).  The `"dynamic"` and `"libc_overlay"` keys are removed from the manifest; the overlay rules stay in gen.py, unused, until step 5.  Every dynamic tool is offered libfgx, and fgx_dyn keeps it only if the tool references it (Task 4), as the pile link GCs libfgx out of a tool that does not use it today.
- **R6. A tool that will not link dynamically is triaged, not dropped.**  Task 7 links all of them with `ninja -k 0` and sorts each failure.  An fcc or libc gap is fixed in the toolchain.  A tool that over-fills its data segment is fit-checked by fgx_dyn's own message: it gets `"pile": true` and a ledger ruling naming the bytes, and the maintainer is told; it is not given a workaround.  A tool reaching a libc-private label from inline asm gets that label exported from libc.so, or the tool's asm replaced by the C call it stands for, whichever the BSD source of that tool supports.  A static tool whose segment 0 overflows (fgx_static's "segment 0 ... is over 64 KB": a static seg0 carries libc's hand-written code, `fgx_libso.BANK0`, which a pile seg0 does not) moves translation units from segment 0 to a `seg3_tus` group in the manifest, which is the only knob; fsck is the likely case.  fas is not a manifest tool, so `"pile": true` does not apply to it: if fgx_dyn refuses fas, Task 7 keeps the old `fasfgx.sh` and its rule, and the ledger says why.

## Review Focus

1. **libc.so unloadable at boot** -- rc must stop with the root still read-only and the console shell up, not run fsck-less and remount read-write.  Pinned by the `rcnolibc` probe in Task 2.
2. **A dynamic program that does not use libfgx** must not load libfgx.so on its first exec (a bank for nothing, and a failure if libfgx.so is missing).  Pinned by `test_unreferenced_library_dropped` in Task 4 and the `ldd` check in Task 7.
3. **A static program that uses libfgx or libutil, with libc.so unloadable** -- init (spawnve, dmesg) and the console sh must still run.  Pinned by `rcnolibc` in Task 6, re-run once init is on fgx_static.
4. **fsck, whose code needs two banks, as a static program** -- it runs on every boot and a wrong cross-segment call corrupts the root check.  Pinned by the gate's every-boot `fsck -p` and `ufsboot` in Task 6.
5. **A spawned child's environment** after R1 -- `time` (spawnvp) must still find its command through `PATH`, and a child must still see its parent's environment.  Pinned by the `spawnenv` probe in Task 3.

---

### Task 1: Amend the spec for the plan's rulings

**Files:**
- Modify: `docs/history/plans/2026-10-04-shared-libc-sp5-design.md` (sections 6, 6.1, 6.2, 6.3)

**Interfaces:**
- Consumes: nothing.
- Produces: the spec text later tasks cite.

- [ ] **Step 1: Edit section 6.1's `ldload` bullet.**  Replace `` `/sbin/ldload || exit 1` `` with:

```
`/sbin/ldload`, and rc stops (`case $? in 2) exit 1;; esac`, a sh
builtin) when ldload exits 2, which it does when libc is not resident; it
exits 1 when only a library `/etc/ld.so.conf` lists failed, which does not
stop the boot
```

and in section 2's row "What runs before the libraries are resident", "stops if they cannot be" stays.

- [ ] **Step 2: Edit section 6.2's "libfgx stops reaching into libc's private data" bullet** to say: libfgx's spawn family passes `environ`, a libc.so data export, as 2.11BSD's `execv` does (`mov	_environ,-(sp)	/ pass default environment,`, `pdp/sys/execv.s`), so `sys_envp`, `__fgx_build_envp` and the `args_env` reach go, and so does the unused `_libc_lstrBufA` declaration.  Remove "libfgx owns its own staging cells in `libfgx_data.s` instead."

- [ ] **Step 3: Edit section 6.3.**  Users: init and login link it statically, telnetd imports it (fsck does not use it).  Replace "The `util` archive (`toolchain/lib/util.fgxa`) stays for the static links." with: a static link compiles libutil's and libfgx's sources as a program's own (with `--sections`) and fgx_static keeps the functions the program reaches; `util.fgxa` serves only pile links and retires with them (section 7).  Add `util.fgxa` and its Makefile target to section 7's Build bullet.

- [ ] **Step 4: Check ASCII and commit.**

Run: `LC_ALL=C grep -n '[^[:print:][:space:]]' docs/history/plans/2026-10-04-shared-libc-sp5-design.md`
Expected: no output.

```bash
git add docs/history/plans/2026-10-04-shared-libc-sp5-design.md
git commit -m "docs(shared-libc): SP5 spec follows the step 2 plan's rulings" -m "ldload exits 2 when libc is not resident and rc stops only then, since a
listed library's failure should not stop the boot.  libfgx's spawn family
passes environ, as 2.11BSD's execv does (pdp/sys/execv.s, \"pass default
environment\").  A static link takes libfgx and libutil as program-mode
sections; util.fgxa serves only pile links.  libutil's static users are
init and login."
```

(Trailers on every commit in this plan, as Global Constraints say.)

---

### Task 2: The boot order (spec 6.1)

**Files:**
- Modify: `src/userland/ldload/ldload.c:39-68,100-131` (exit status)
- Modify: `disk_src/usr/man/cat8/ldload.8:35` (exit status)
- Modify: `disk_src/etc/rc.in:1-144` (ldload first; the comment block at `:126-134`, its code at `:135-137`)
- Modify: `disk_src/etc/modload.conf` (`ld` first)
- Modify: `tools/check_modload_lists.py:44-82,105-135` (several modload lines, in order)
- Create: `tools/mame_test/fixtures/libc.so.garbage`
- Create: `tools/mame_test/tests/rcnolibc.json`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `ldload` exit status 0 (all loaded), 1 (a listed library failed), 2 (libc not resident).  `rc_list(text)` returns `(words, nlines)` with the words of every modload line, in order.

- [ ] **Step 1: Write the checker's failing self-test.**  In `self_test()`, change the case `("two modload invocations", twice, conf, False)` to expect agreement, and add a case where two lines disagree in order:

```python
    twice = "/sbin/modload serial\n/sbin/modload bpf pty\n"
    twiceswap = "/sbin/modload bpf pty\n/sbin/modload serial\n"
    ...
        ("two modload invocations, in order", twice, conf, True),
        ("two modload invocations, out of order", twiceswap, conf, False),
```

and update the docstring's count ("Ten synthetic pairs; the six that must DISAGREE are the point.").

- [ ] **Step 2: Run it.**

Run: `python3 tools/check_modload_lists.py --self-test`
Expected: `  WRONG two modload invocations, in order -> disagree`, then `check_modload_lists: SELF-TEST FAILED (1)`.

- [ ] **Step 3: Make `rc_list` read every modload line.**  Replace the `len(hits) != 1` early return and the single-hit parse with a loop over `hits`, each line cut at its first redirection and its `$NAME` words resolved as today, the words concatenated in file order; return `(words, len(hits))` and `(None, 0)` when there is no line.  In `compare`, the "expected exactly one" complaint becomes "has no `modload' line".  Update the module docstring's "rc.in's explicit `/sbin/modload' line is the only thing that loads anything" to say rc's modload lines, read in order, are one list.

- [ ] **Step 4: Run the self-test again.**

Run: `python3 tools/check_modload_lists.py --self-test`
Expected: `check_modload_lists: self-test clean (11 cases)`.

- [ ] **Step 5: ldload's exit status.**  In `ldload.c`, make `load()` return `int` (0 on success, -1 on failure; it already counts `fails`), record `libcok = load("libc", 1) == 0;` in `main`, and end:

```c
    printf("ldload: %d loaded, %d resident\n", nloaded, nresident);
    if (!libcok)
        return 2;
    return fails != 0;
```

Read 2.11BSD's nearest counterpart first: there is none (ldload is FGX's; SunOS's `ldconfig` builds a cache and does not load), so the commit body says: "ldload has no BSD counterpart: SunOS 4.1.3's ldconfig builds rtld's cache and loads nothing (etc/files/rc.local)."  In `ldload.8`, replace "It exits 1 if any library failed." with "It exits 2 if libc could not be made resident, 1 if any other library failed, and 0 otherwise."

- [ ] **Step 6: Reorder rc.**  In `disk_src/etc/rc.in`, before the `# CHECK THE ROOT` block, add:

```sh
# THE SHARED LIBRARIES COME FIRST, so they are resident before anything that
# needs them runs.  SunOS 4.1.3's rc.boot makes its libraries reachable the
# same way, mounting /usr read-only before fsck checks it (etc/files/rc.boot,
# `intr mount -n -r /usr').  Both commands only read, and the root is still
# read-only here.  ld.mod comes first, alone, because ldload fills its
# registry; the rest of the modules load below, after the root is writable.
#
# IF libc CANNOT BE MADE RESIDENT, rc STOPS (ldload exits 2), before fsck and
# before `mount -u -w /' could make an unchecked root writable.  init starts
# the console's /bin/sh regardless of rc's status.  A library /etc/ld.so.conf
# lists failing (ldload exits 1) does not stop the boot.
/sbin/modload ld >/dev/console 2>&1
/sbin/ldload >/dev/console 2>&1
case $? in
2)
	exit 1
	;;
esac
```

Delete the old `ldload` block (`rc.in:139-144`), take `ld` out of the main modload line (`/sbin/modload serial bpf net ramdisk pty sscon cda klog fpsim $UFSPROBE ...`), and reword the comment block at `:126-134`: "ONE PROCESS, NOT SIX" becomes "ONE PROCESS FOR THESE" (ld.mod loaded above is the one other), and "THE LIST IS /etc/modload.conf's, IN ITS ORDER" says rc's two modload lines together are that list.  In `disk_src/etc/modload.conf`, move `ld` to the first entry.

- [ ] **Step 7: Run the checker for real.**

Run: `python3 tools/check_modload_lists.py`
Expected: `check_modload_lists: clean (10 modules, same order in both: ...)` (ld first), exit 0.

- [ ] **Step 8: Write the probe.**  `tools/mame_test/fixtures/libc.so.garbage` holds one line, `not a shared library`.  `tools/mame_test/tests/rcnolibc.json`:

```json
{
 "name": "rcnolibc",
 "description": "SHARED LIBC SP5 STEP 2 (spec 6.1): A libc.so THAT WILL NOT LOAD STOPS /etc/rc WITH THE ROOT READ-ONLY.  The image's /lib/libc.so.1.0 is replaced by a text file, so ldload cannot make libc resident and exits 2, and rc exits before its fsck block, its remount and every dynamic program.  init then starts the console's static /bin/sh.  The typed `mount' (static) prints the root's flags: `read-only' is the proof the remount did not run, and the autoboot line rc prints before fsck must be absent.  Control: run with rc.in's `case' block deleted -- rc carries on, the remount runs, and `read-only' is gone.",
 "command": "/sbin/mount",
 "timeout_s": 300,
 "stage_files": [
  {"host": "tools/mame_test/fixtures/libc.so.garbage", "prodos_dir": "/FGX/lib", "name": "libc.so.1.0"}
 ],
 "expect": {
  "screen_contains": ["read-only"],
  "screen_lacks": ["Running disk integrity checks", "PANIC", "BRK"]
 }
}
```

- [ ] **Step 9: Rebuild and run the probe and its control.**  Announce the rebuild of the main checkout (feat/shared-libc).

Run: `ninja && python3 tools/mame_test/run.py rcnolibc`
Expected: PASS.  Then delete the `case` block from `disk_src/etc/rc.in`, `ninja && python3 tools/mame_test/run.py rcnolibc`: Expected FAIL (no `read-only`).  Restore the block, `ninja`.

- [ ] **Step 10: Run the boot-order probes and the gate.**

Run: `python3 tools/mame_test/run.py ldload ldorder ldfit dyntools ufsboot && tools/gate.sh`
Expected: all PASS; gate green.

- [ ] **Step 11: Commit.**

```bash
git add src/userland/ldload/ldload.c disk_src/usr/man/cat8/ldload.8 disk_src/etc/rc.in disk_src/etc/modload.conf tools/check_modload_lists.py tools/mame_test/fixtures/libc.so.garbage tools/mame_test/tests/rcnolibc.json
git commit -m "feat(rc): the shared libraries load before anything else" -m "Body: SunOS 4.1.3 rc.boot's 'intr mount -n -r /usr' before fsck; ldload exits 2 when libc is not resident (ldload has no BSD counterpart); rc stops on 2 with the root read-only; ld leaves the main modload line; check_modload_lists reads every modload line in order"
```

---

### Task 3: libfgx passes `environ` (R1)

**Files:**
- Create: `vendor/2.11BSD/usr/lib/libc/pdp/sys/execv.s` (copied from `examples/2.11BSD/usr/lib/libc/pdp/sys/execv.s`)
- Modify: `toolchain/lib/libfgx_c/libfgx.c:7-9,35-41,195-330`
- Create: `src/userland/spawnenv/spawnenv.c`, `tools/mame_test/tests/spawnenv.json`
- Modify: `tools/ninja/manifest.json` (spawnenv as a tool entry `{"name": "spawnenv"}` and a staging row `bin/spawnenv.bin -> disk_src/testbin/spawnenv`, as cloexec is: `manifest.json:617` and `:1518-1519`)

**Interfaces:**
- Consumes: nothing.
- Produces: libfgx with no reference to `args_env`, `sys_envp` or `_libc_lstrBufA`, which Task 5's `libfgx.so` link requires (a library above libc reaches only libc's exported data).

- [ ] **Step 1: Write the probe.**  `spawnenv.c` sets `FGXENV=ok` with `setenv` (or edits `environ` if libc has no `setenv`; check `toolchain/include/stdlib.h` first), spawns `/bin/sh -c 'echo child FGXENV=$FGXENV'` with `spawnv`, waits, then `spawnvp("echo", ...)` with `argv = {"echo", "vp found", 0}` and waits.  It prints `SPAWNENV done` last.  `spawnenv.json` expects `["child FGXENV=ok", "vp found", "SPAWNENV done"]` and lacks `["PANIC", "BRK"]`; its description names the control (spawnv passing the exec-time block, the old behaviour: `child FGXENV=` with nothing after it).  Command: `/testbin/spawnenv`.

- [ ] **Step 2: Build and run it.**

Run: `ninja && python3 tools/mame_test/run.py spawnenv`
Expected: FAIL: `child FGXENV=` is empty (today's `__fgx_build_envp` walks the exec-time `args_env`).

- [ ] **Step 3: Change libfgx.**  Vendor `execv.s` (copy the file unchanged).  In `libfgx.c`:
  - delete `extern char _libc_lstrBufA[];`, `extern char args_env[];`, `char *sys_envp[17];` and `__fgx_build_envp`;
  - add `extern char **environ;`;
  - `spawnv`'s `blk[1] = __fgx_build_envp();` becomes `blk[1] = environ;` with the comment "the current environment, as 2.11BSD's execv passes it (pdp/sys/execv.s, `mov _environ,-(sp)')";
  - correct the header at `:7-9`: libfgx calls into libc (strcpy, getenv); libc makes no calls into libfgx.

- [ ] **Step 4: Rebuild and run.**

Run: `ninja && python3 tools/mame_test/run.py spawnenv cloexec`
Expected: PASS both.

- [ ] **Step 5: Commit.**

```bash
git add vendor/2.11BSD/usr/lib/libc/pdp/sys/execv.s toolchain/lib/libfgx_c/libfgx.c src/userland/spawnenv tools/mame_test/tests/spawnenv.json tools/ninja/manifest.json
git commit -m "fix(libfgx): the spawn family passes the current environment" -m "Body: quote execv.s; the exec-time copy and its 17-entry table go; the probe"
```

---

### Task 4: fgx_dyn drops a library the program does not reference

**Files:**
- Modify: `toolchain/src/ld/fgx_dyn.py:396-401` (`build`)
- Test: `toolchain/tests/dyn/test_dyn.py` (its own `check()` harness, run as a script, not pytest)

**Interfaces:**
- Consumes: `fgx_dyn.Libs(names, override)`, `program_names(code_rows, data_rows) -> (code_exports, data, refs)`.
- Produces: `build(...)` links against `libc`, the requested libraries the program references (by a name it uses and does not define), and every library below those; the IMPS table names exactly those.  Its returned dict gains `"libs": [names]`.

- [ ] **Step 1: Write the failing test.**  In `test_dyn.py`, beside `hello()`, using the file's `link()`, `imps()` and `check()`, and call it from the list at the bottom:

```python
def dropped():
    # hello.c calls printf only: libcurses (and with it libtermlib) is
    # offered and must not reach the table, or the binder would load both.
    rc, text, data, _d = link(os.path.join(HERE, "hello.c"), "libc,libcurses",
                              name="dropped")
    check(rc == 0, "hello links with an unused library offered", text[-600:])
    if rc:
        return
    t = imps(data)
    check([l["name"] for l in t["libs"]] == ["libc"],
          "an unreferenced library and its below leave the table",
          str([l["name"] for l in t["libs"]]))
    # curs.c uses curses: libcurses stays and brings libtermlib below it.
    rc, text, data, _d = link(os.path.join(HERE, "curs.c"), "libc,libcurses",
                              name="kept")
    check(rc == 0 and [l["name"] for l in imps(data)["libs"]]
          == ["libc", "libtermlib", "libcurses"],
          "a referenced library stays, with the library below it", text[-300:])
```

- [ ] **Step 2: Run it.**

Run: `cd toolchain && python3 tests/dyn/test_dyn.py`
Expected: `FAIL: 1` (the table names libtermlib and libcurses for hello).

- [ ] **Step 3: Implement.**  In `build`, after `code_exports, _data, refs = program_names(...)`:

```python
    used = {libs.owner(n) for n in refs - code_exports} - {None}
    keep = [n for n in lib_names if n == "libc" or n in used]
    if keep != list(lib_names):
        libs = Libs(keep, override)        # adds each kept library's below
```

and add `"libs": libs.names` to the returned dict (a convenience for callers; nothing consumes it yet).  A library below a kept one comes back through `Libs`'s `below` walk.

- [ ] **Step 4: Run the tests and the suite.**

Run: `cd toolchain && python3 tests/dyn/test_dyn.py && cd .. && make -C toolchain test-archives`
Expected: `dyn checks passed`; `0 FAIL`.

- [ ] **Step 5: Commit.**

```bash
git add toolchain/src/ld/fgx_dyn.py toolchain/tests/dyn/test_dyn.py
git commit -m "feat(ld): a dynamic link keeps only the libraries the program uses"
```

---

### Task 5: libfgx.so and libutil.so (spec 6.2, 6.3)

**Files:**
- Modify: `toolchain/Makefile:63-88` (two `--libso` compiles, two `.so` links, `libso_all`)
- Create: `toolchain/lib/libfgx_c/data.exports`, `toolchain/lib/libutil_c/data.exports`
- Modify: `toolchain/src/ld/fgx_libso.py:426-447` (`LIBS`)
- Modify: `tools/ninja/gen.py:1189-1194` (`libso` rule description), `:1466-1478` (`DYN_INPUTS`), the `libso` edge's `_so_out`/`_so_in` (`:1906-1918`)
- Modify: `toolchain/Makefile:228,239` (`test-archives`' prerequisites and its `for l in libc libtermlib libcurses` `libc_so_check.py` loop)
- Modify: `tools/ninja/manifest.json` (stage both to `disk_src/lib/`)
- Create: `toolchain/tests/dyn/fgxlib.c`, `toolchain/tests/dyn/utillib.c`
- Test: `toolchain/tests/dyn/test_dyn.py`

**Interfaces:**
- Consumes: Task 3's libfgx (no libc-private data); Task 4's dropping.
- Produces: `toolchain/lib/libfgx.so.1.0` and `toolchain/lib/libutil.so.1.0`, `fgx_libso.LIBS["libfgx"]`, `LIBS["libutil"]` (each `below=["libc"]`), staged at `/lib/libfgx.so.1.0` and `/lib/libutil.so.1.0`.

- [ ] **Step 1: Write the failing test.**  Two fixtures, `toolchain/tests/dyn/fgxlib.c`:

```c
#include <stdio.h>
extern long ticks();

main()
{
    printf("%ld\n", ticks());
    return 0;
}
```

and `toolchain/tests/dyn/utillib.c`:

```c
main()
{
    logwtmp("ttyp0", "", "");
    return 0;
}
```

and in `test_dyn.py` (called from the list at the bottom):

```python
def fgxutil():
    for src, lib, name in (("fgxlib.c", "libfgx", "ticks"),
                           ("utillib.c", "libutil", "logwtmp")):
        rc, text, data, _d = link(os.path.join(HERE, src),
                                  "libc,libfgx,libutil", name=lib)
        check(rc == 0, "%s links against %s.so" % (src, lib), text[-600:])
        if rc:
            continue
        t = imps(data)
        check([l["name"] for l in t["libs"]] == ["libc", lib],
              "%s's table needs libc and %s only" % (src, lib),
              str([l["name"] for l in t["libs"]]))
        check(any(i["name"] == name and i["call"] for i in t["imports"]),
              "%s is imported with a call site" % name)
```

- [ ] **Step 2: Run it.**

Run: `cd toolchain && python3 tests/dyn/test_dyn.py`
Expected: FAIL (`KeyError: 'libfgx'` from `fgx_libso.LIBS`, or `FAIL: 2`).

- [ ] **Step 3: The compiles and links.**  In `toolchain/Makefile`, after the libcurses rules, following libtermlib's lines exactly:

```make
lib/libfgx_so.s: $(wildcard lib/libfgx_c/*.c) $(wildcard include/*.h) fcc
	./fcc --libso --libso-name libfgx --sections --emit-blocks lib/libfgx_so.blocks.json -Ilib/libfgx_c lib/libfgx_c/libfgx.c -o lib/libfgx_so.s --data-segment lib/libfgx_so_data.s
lib/libfgx_so_data.s lib/libfgx_so.blocks.json: lib/libfgx_so.s
lib/libutil_so.s: $(wildcard lib/libutil_c/*.c) $(wildcard include/*.h) fcc
	./fcc --libso --libso-name libutil --sections --emit-blocks lib/libutil_so.blocks.json -Ilib/libutil_c lib/libutil_c/libutil.c -o lib/libutil_so.s --data-segment lib/libutil_so_data.s
lib/libutil_so_data.s lib/libutil_so.blocks.json: lib/libutil_so.s
lib/libfgx.so.1.0: lib/libfgx_so.s lib/libfgx_so_data.s lib/libfgx_so.blocks.json lib/libfgx_c/data.exports lib/libc.so.1.0 $(LIBSO_LD)
	python3 src/ld/fgx_libso.py --lib libfgx --out lib/libfgx.so.1.0 --dir lib/libfgx_so.d
lib/libutil.so.1.0: lib/libutil_so.s lib/libutil_so_data.s lib/libutil_so.blocks.json lib/libutil_c/data.exports lib/libc.so.1.0 $(LIBSO_LD)
	python3 src/ld/fgx_libso.py --lib libutil --out lib/libutil.so.1.0 --dir lib/libutil_so.d
libso_all: libc_so lib/libtermlib.so.1.0 lib/libcurses.so.1.0 lib/libfgx.so.1.0 lib/libutil.so.1.0
```

Each `data.exports` names the library's extern data objects and its block table, as libtermlib's does: libfgx's public headers (`include/fgx.h`) declare no extern objects once `sys_envp` is gone, so its file is the header comment and `_libfgx_blktab`; libutil's is the header comment and `_libutil_blktab`.  In `fgx_libso.LIBS`, after `libcurses`:

```python
    "libfgx": dict(code="libfgx_so.s", data="libfgx_so_data.s",
                   blocks="libfgx_so.blocks.json", core_list=None,
                   exports="libfgx_c/data.exports", prefix="_libfgx_",
                   bank0=[], data_files=[os.path.join(LIB, "fcc_runtime_data.s")],
                   below=["libc"], version=[1, 0], dir="libfgx_so.d",
                   equs=[("LIBC_DP_LP0", "$EB"), ("LIBC_DP_DST", "$E6")]),
    "libutil": dict(code="libutil_so.s", data="libutil_so_data.s",
                    blocks="libutil_so.blocks.json", core_list=None,
                    exports="libutil_c/data.exports", prefix="_libutil_",
                    bank0=[], data_files=[os.path.join(LIB, "fcc_runtime_data.s")],
                    below=["libc"], version=[1, 0], dir="libutil_so.d",
                    equs=[("LIBC_DP_LP0", "$EB"), ("LIBC_DP_DST", "$E6")]),
```

The `equs` are libcurses's; if Merlin reports an undefined label from libc.s, add it from `libc.s`'s EQU, and if one is unused, leave it (libcurses carries the same pair).  libfgx's `ticks` stages through `__asm_p0`, which `fcc_runtime_data.s` defines: the data file gives each library its own copy, as it does libtermlib.

- [ ] **Step 4: Wire the build.**  `gen.py`: the `libso` rule's description becomes `libtermlib.so + libcurses.so + libfgx.so + libutil.so <- toolchain/lib`; append the two `.so.1.0` files to `DYN_INPUTS`; add both libraries' `_so.s`, `_so_data.s`, `_so.blocks.json` and `.so.1.0` to the `libso` edge's `_so_out` (`gen.py:1906-1918`, `for b in ("libtermlib", "libcurses")` becomes the four), and `lib/libfgx_c/*.c`, `lib/libutil_c/*.c` and both `data.exports` to its `_so_in`, so ninja produces them on a fresh tree.  In `toolchain/Makefile`, `test-archives` gains both `.so.1.0` prerequisites and its `libc_so_check.py` loop the two names.  The lddigest rule and `fgx_lddigest.py` stay at libc, libtermlib and libcurses: no probe digests the new libraries.  `manifest.json`: two stage entries, `toolchain/lib/libfgx.so.1.0 -> disk_src/lib/libfgx.so.1.0` and `toolchain/lib/libutil.so.1.0 -> disk_src/lib/libutil.so.1.0`.

- [ ] **Step 5: Build and run the tests.**  Announce the rebuild.

Run: `make -C toolchain libso_all && (cd toolchain && python3 tests/dyn/test_dyn.py) && make -C toolchain test-archives && ninja`
Expected: both libraries link; tests PASS; `0 FAIL`; ninja clean.

- [ ] **Step 6: Commit.**

```bash
git add toolchain/Makefile toolchain/lib/libfgx_c/data.exports toolchain/lib/libutil_c/data.exports toolchain/src/ld/fgx_libso.py tools/ninja/gen.py tools/ninja/manifest.json toolchain/tests/dyn/test_dyn.py toolchain/tests/dyn/fgxlib.c toolchain/tests/dyn/utillib.c
git commit -m "feat(lib): libfgx.so and libutil.so, above libc" -m "Body: built as libtermlib.so is; libutil is 4.3BSD-Reno/2.11BSD libutil (login, logout, logwtmp); each depends on libc only; staged in /lib"
```

---

### Task 6: fgx_static takes libraries and code segments, and the static set moves to it

**Files:**
- Modify: `toolchain/src/ld/fgx_static.py` (`--lib CODE,DATA`, `--code-seg`, self-test)
- Modify: `tools/ninja/gen.py` (`parse_tools`: `static`, `pile`; a `staticlink` rule; the static branch in the tool loop; one program-mode compile each of libfgx.c and libutil.c)
- Modify: `tools/ninja/manifest.json` (`"static": true` on init, getty, login, fsck, mount, ifconfig, modload, test, echo, hostname, mv, tar, ln)

**Interfaces:**
- Consumes: Task 5's libraries (for the dynamic tools that follow in Task 7, not here).
- Produces: `fgx_static.build(name, d, code, data, out, bank_cap=None, squeeze=False, libs=(), extra=())`: `libs` is `[(code_path, data_path)]`, pruned like libc; `extra` is `[[code paths]]`, one code segment each (segments 2, 3, ...), before the libc banks.  CLI: `--lib CODE,DATA` (repeatable), `--code-seg a.s[,b.s]` (repeatable).  gen.py: `rec["static"]`, `rec["pile"]`; `build/static_libs/{libfgx,libutil}.{s,data.s}`.

- [ ] **Step 1: Write the failing self-test.**  In `fgx_static.self_test()`, after the existing `collect` case:

```python
    files["f.s"] = ["                FGX_SECT ticks", "ticks   ENT", "        RTL",
                    "                FGX_ENDS",
                    "                FGX_SECT procs", "procs   ENT", "        RTL",
                    "                FGX_ENDS"]
    files["p.s"] = files["p.s"] + ["        FGX2_FARCALL ticks"]
    units, live = collect(files, ["p.s", "l.s", "l_data.s", "f.s"],
                          {"l.s", "l_data.s", "f.s"})
    names = sorted(units[p][i][1] for p, i in live)
    assert "ticks" in names and "procs" not in names, names
```

Factor the argument parser out of `main()` into `parser()` and add:

```python
    opts = set(parser()._option_string_actions)
    assert {"--lib", "--code-seg"} <= opts, sorted(opts)
```

The `ticks`/`procs` case is green before (`collect` already prunes every file in its prune set) and documents the use; the RED is the parser assertion.  The pruning of a real library is proved by Step 7's link summaries.

- [ ] **Step 2: Run it.**

Run: `python3 toolchain/src/ld/fgx_static.py --self-test`
Expected: FAIL on the parser assertion.

- [ ] **Step 3: Implement `--lib`.**  In `build`, the libraries' files join `order` after the program's data and before libc's, and their paths join the prune set: `collect(files, order, {lib_code, lib_data} | {p for pair in libs for p in pair})`.  Their live code sections go into segment 0 with the program's code (written to `d/libs.s` from `units[...]` for the live keys, in file order), and their live data sections into segment 1 (`d/libs.data.s`).  `OUTPUT` (`fgx_static.py:40-42`, which `clear_outputs` uses to refuse a directory holding files it did not write) gains `libs`, `libs\.data` and `seg\d+(?:_rt)?`.

- [ ] **Step 4: Implement `--code-seg`.**  As fgx_dyn's `link_once` does (`fgx_dyn.py:252-268`), each extra segment `segN` (N from 2) assembles its files plus `fgx_libso.RUNTIME`.  A static link calls its helpers near, so each code bank carries the whole fcc runtime, as the tool build's seg3 carries its own `fcc_runtime.s`.  Its write_link inputs are `[MACROS, "seg1_layout.s"] + files + [RUNTIME]`, and it is appended to `segs` before the libc banks.  Its files join `frames` and `order` (so `collect` sees their references into libc).  A binary with no LIBC segment has at most EIGHT segments (`fgx_ld.py:913-914`, "a 9-segment binary must end with the LIBC segment"), and `pack_min` is called with up to 6 libc banks (`fgx_static.py:210-211`), so pass `6 - len(extra)` there and `die` if `2 + len(extra) + len(banks) > 8` or a segment is over 64 KB.

- [ ] **Step 5: Run the self-test.**

Run: `python3 toolchain/src/ld/fgx_static.py --self-test`
Expected: `fgx_static: self-test OK`.

- [ ] **Step 6: gen.py's static branch.**  `parse_tools` reads `static=t.get("static", False)` and `pile=t.get("pile", False)`.  A rule:

```
rule staticlink
  command = python3 toolchain/src/ld/fgx_static.py --name $name --dir $dir --code $code $codesegs $libs --data $data --out $out > $out.log 2>&1 || (cat $out.log; false)
  description = fgx_static $name
```

Two compiles, emitted once:

```
build build/static_libs/libfgx.s | build/static_libs/libfgx.data.s: fcc_c toolchain/lib/libfgx_c/libfgx.c | $fcc build/libc.sigs
  data = build/static_libs/libfgx.data.s
  flags = --sections
  softscc =
build build/static_libs/libutil.s | build/static_libs/libutil.data.s: fcc_c toolchain/lib/libutil_c/libutil.c | $fcc build/libc.sigs
  data = build/static_libs/libutil.data.s
  flags = --sections -Itoolchain/lib/libutil_c
  softscc =
```

In the tool loop, before the dynamic branch, a `rec["static"]` branch that compiles the tool's TUs as the dynamic branch does, but with the pile path's `softscc` value and its `src/softscc/{name}.txt` dependency (`gen.py:2561-2575`), not the dynamic branch's empty `softscc =`; then:

```python
            slibs = " ".join("--lib build/static_libs/%s.s,build/static_libs/%s.data.s" % (l, l)
                             for l in ["libfgx"] + [{"util": "libutil"}[x] for x in libs])
            lines.append(
                f"build bin/{name}.bin: staticlink {' '.join(alls)} {' '.join(data)} "
                f"build/static_libs/libfgx.s build/static_libs/libfgx.data.s "
                + ("build/static_libs/libutil.s build/static_libs/libutil.data.s " if "util" in libs else "")
                + "| " + " ".join(STATIC_INPUTS) + "\n"
                f"  name = {name}\n  dir = {b}/static.ld\n  code = {','.join(code0)}\n"
                f"  codesegs ={codesegs}\n  libs = {slibs}\n  data = {','.join(data)}")
            built.append(name)
            continue
```

`built.append` is what stages `bin/{name}.bin` (`produced`, `gen.py:2781-2795`), and `continue` keeps the tool out of the pile path, which would otherwise emit a second rule for the same output.  The section header line is `# ---- {name} (static)`, so Task 7's count is one grep per kind.

with `STATIC_INPUTS` beside `DYN_INPUTS`: `fgx_static.py`, `fgx_libso.py`, `fgx_ld.py`, `fgx_gc.py`, `crt0_lib.s`, `crt0_lib_data.s`, `libc_start.s`, `libc_start_data.s`, `libc_c/core.list`, `libc.s`, `fcc_libc_shims.s`, `ld_bind_asm.s`, `fcc_runtime.s`, `fcc_runtime_data.s`, `macros.s`, `libc_data.s`, `gen_seg1_layout.py`, `libc_so.s`, `libc_so_data.s`, `libc_so.blocks.json`, `build/libc.sigs` (ldload's SHELLS entry lists the same), plus `fgx_libso.BANK0`'s `libllong` members and `libdouble/d_stub.s` (`fgx_libso.py:253-256`), which a static link assembles into segment 0; add those two to `DYN_INPUTS` as well.  A `libs` entry other than `util` on a static tool is a `SystemExit`, as the dynamic branch's is.  fgx_static prunes libfgx out of a tool that does not reach it.

- [ ] **Step 7: Mark the static set.**  `"static": true` on the 13 tools in Files.  Rebuild (announce it) and read the links:

Run: `ninja 2>&1 | tail -30; for t in init getty login fsck mount ifconfig modload test echo hostname mv tar ln; do tail -1 bin/$t.bin.log; done`
Expected: 13 `static <name>: seg0 ... libc banks [...]` lines.  Any link failure is triaged by R6 and ruled in the ledger.

- [ ] **Step 8: Re-run the probes that boot through them, and the gate.**

Run: `python3 tools/mame_test/run.py rcnolibc ufsboot ptyremote inetdboot && tools/gate.sh`
Expected: all PASS (rcnolibc now proves Review Focus 3: init on fgx_static with libc.so unloadable); gate green, including every boot's `fsck -p` (Review Focus 4).

- [ ] **Step 9: Commit.**

```bash
git add toolchain/src/ld/fgx_static.py tools/ninja/gen.py tools/ninja/manifest.json
git commit -m "feat(build): the static set links with fgx_static" -m "Body: the set (spec 6.1, SunOS 4.1.3's -Bstatic list as far as FGX ships it); libfgx and libutil linked as program-mode sections, pruned; extra code segments each with the fcc runtime; fsck's two code banks"
```

---

### Task 7: Every other manifest tool, and fas, links dynamically

**Files:**
- Modify: `tools/ninja/gen.py` (default dynamic; `lib_map` gains `util`; libfgx offered to every dynamic tool)
- Modify: `tools/ninja/manifest.json` (remove every `"dynamic"` and `"libc_overlay"` key; `"pile": true` on ac)
- Modify: `tools/ninja/fasfgx.sh`, and gen.py's fas edge (`:2729-2745`)
- Modify: `tools/mame_test/tests/dyntools.json` (adds an `ldd` line, Review Focus 2)
- Modify: `disk_src/etc/rc.in` (the boot-order comment now names the static set)
- Delete: `tools/fas/seg0.link.s`, `seg1.link.s`, `seg2.link.s`, `fas_fgx.json` (tracked, hand-written pile link files)
- Delete (untracked): every pile-era output in `tools/<t>-fgx2/` of a tool that left the pile

**Interfaces:**
- Consumes: Task 4's dropping, Task 5's libraries, Task 6's static branch.
- Produces: every manifest tool not `static` or `pile` is a dynamic program; `tools/fas/fas_fgx` is a dynamic program.

- [ ] **Step 1: Write the failing check.**  In `dyntools.json`, add `/bin/cat` to its existing `/bin/ldd` invocation (ldd is staged at `/bin/ldd`, `manifest.json:914-915`), add `"/bin/cat:"` to `screen_contains` (ldd prints `%s:` per argument when given several, `ldd.c:61-62`) and `"-lfgx.1"` to `screen_lacks`.  The file already has `"-lc.1 => /lib/libc.so.1.0"` and lacks `"statically linked"`; the RED comes from that existing needle (`/bin/cat: statically linked`, `ldd.c:56-57`).  The `-lfgx.1` needle holds only because none of the programs on that ldd line (wc, ls, ul, worm, ntpd, cat) calls libfgx (worm's mention, `worm.c:12-13`, is a comment); the test's description says so.

Run: `python3 tools/mame_test/run.py dyntools`
Expected: FAIL (cat is still a pile program: ldd reports it is not dynamic).

- [ ] **Step 2: Default dynamic.**  In the tool loop, the dynamic branch's condition becomes `if not rec["pile"]:` (the static branch, Task 6, comes first), and:

```python
            lib_map = {"termlib": "libtermlib", "curses": "libcurses", "util": "libutil"}
            ...
            dlibs = ",".join(["libc", "libfgx"] + [lib_map[l] for l in libs])
```

The dynamic branch's `fcc_c` edges take the pile path's `softscc` value and `src/softscc/{name}.txt` dependency (`gen.py:2561-2575`) in place of its empty `softscc =`.  softexec, softfork and softjmp need it: softfork and softexec are gate tests, and `check_soft_exile.py` reads their `.s`.

`parse_tools` drops `dynamic`.  In `manifest.json`, remove the five `"dynamic": true` and five `"libc_overlay"` keys, and add `"pile": true` to ac.

- [ ] **Step 3: fas.**  `fasfgx.sh` compiles `fas.c` with `--sigs build/libc.sigs` and links with `fgx_dyn.py --name fas --dir dyn.ld --code fas_fgx.s --data fas_fgx.data.s --lib libc,libfgx --out fas_fgx`; the seg3.py, merlin32 and `fgx_ld --pile-dir` lines go, and so do the tracked `tools/fas/seg{0,1,2}.link.s` and `fas_fgx.json` (`fasfgx.sh:5-6`; `check_libc_link_sites.py` scans tracked `.link.s`).  gen.py's fas edge depends on `DYN_INPUTS` instead of the pile inputs.  If fgx_dyn refuses fas, R6's fas arm applies.

- [ ] **Step 3b: Remove the pile-era outputs.**  For every tool now static or dynamic (step 1's five included), delete from `tools/<t>-fgx2/` everything but `dyn.ld/` or `static.ld/` and the current link's compiled `.s`/`.data.s`: `<t>_fgx.json`, `seg*.link.s`, `seg*_Output.txt`, `seg1_layout.s`, `dataseg_layout.s`, `libc.sel*.s`, `*.gc.s`.  `helper_census.py` (run by `make test-archives` and the gate) globs `tools/*-fgx2/*.s` and every `tools/*-fgx2/*.json`; `check_data_budget.py` reads `dataseg_layout.s`; `check_soft_exile.py` reads `*.s`.  Then run `python3 tools/helper_census.py --check`.  If it is red, run `--write`; the regenerated `toolchain/lib/libc_so_helpers.s` is committed, and the commit says the census changed because the pile links left.

- [ ] **Step 3c: The rc comment.**  In `disk_src/etc/rc.in`'s boot-order comment (Task 2), add after its first sentence: "Every program below except the static set -- sh, init, getty, login, fsck, mount, ifconfig, modload, ldload, test, echo, hostname, mv, tar and ln -- is dynamic, and a dynamic program started before libc.so is resident prints `ld.so: libc.so.1 not loaded' and exits 1."  Then add to the IF-libc paragraph: "rc's own conditions run on `[', which is static, and the console shell is the recovery shell: test, echo, mount, fsck, mv, tar and ln are static."  (sh is static from step 3; until then it is a pile program, which also needs no libc.so, so the sentence is true now.)

- [ ] **Step 4: Link everything and triage.**  Announce the rebuild.

Run: `ninja -k 0 2>&1 | tee build/step2_link.log | grep -E '^FAILED|fgx_dyn:|fgx_static:' | sort | uniq -c | sort -rn | head -50`
Expected: no FAILED.  Otherwise each failure goes through R6.  An fcc/libc/linker gap is fixed in the toolchain with its regression test, and its own commit.  A data-segment overflow gets `"pile": true`, a ledger ruling with fgx_dyn's numbers, and a line in the final report.  Re-run until the log has no FAILED.  Print the count of dynamic, static and pile tools: `grep -c '^# ---- .* (dynamic)' build.ninja`, `grep -c '^# ---- .* (static)' build.ninja`, and the manifest's `pile` count, and check they sum to the manifest's tool count (192, plus spawnenv from Task 3).

- [ ] **Step 5: Run the check, step 1's probes, the boot probes and exectime.**

Run: `python3 tools/mame_test/run.py dyntools rcnolibc spawnenv dynrepeat dynskip dynmulti dynrebind boundshare cursexec dynsodyn dynsomisdyn curssodyn dynso cursso ldfit lddigest ldd exectime lddelta ldload ldorder dbgbank ufsboot ptyremote inetdboot telnet_loopback`
Expected: all PASS except as noted next.  `exectime` asserts no numbers: read them from `/tmp/fgx_test_exectime/dump.txt` ("screen text:") and compare with today's measured baseline (/bin/true 80 ms, dyntrue 91 ms, dyntruebound 277 ms), each within 10% (spec section 1); record before and after in the commit.  `manyproc` is not run; it is expected red until step 5.

- [ ] **Step 6: The gate and the host suite.**

Run: `make -C toolchain test-archives && tools/gate.sh`
Expected: `0 FAIL`; gate green.  If `gate_budget.py` fails on seconds, report the measured numbers; do not remove a gate test without the maintainer.

- [ ] **Step 7: Commit.**

```bash
git add tools/ninja/gen.py tools/ninja/manifest.json tools/ninja/fasfgx.sh tools/mame_test/tests/dyntools.json disk_src/etc/rc.in
git rm tools/fas/seg0.link.s tools/fas/seg1.link.s tools/fas/seg2.link.s tools/fas/fas_fgx.json
# plus toolchain/lib/libc_so_helpers.s if Step 3b regenerated it
git commit -m "feat(build): every manifest tool and fas link dynamically" -m "Body: counts (dynamic / static / pile); libfgx offered to all and kept where used; util via libutil.so; the overlay users need no overlay; any tool left on its pile, with its bytes"
```

---

### Task 8: ROADMAP

**Files:**
- Modify: `docs/ROADMAP.md` (the shared libc SP5 paragraph, around `:2683-2702`)

- [ ] **Step 1: Update the paragraph.**  Step 2 landed: the boot order, libfgx.so and libutil.so, the static set on fgx_static, and N dynamic tools (the number from Task 7), with ac and any ruled tool on its pile.  Next: step 3 (sh, tcsh, vi; ac measured).

- [ ] **Step 2: Commit.**

```bash
git add docs/ROADMAP.md
git commit -m "docs(roadmap): shared libc SP5 step 2 landed"
```

## Self-review

- Spec coverage: 6.1, the boot order, is Task 2.  The 6.1 static set is Task 6, and test and echo are in it.  6.2 is Tasks 3 and 5, 6.3 is Task 5, and the 6.3 static users are Task 6.  8 item 2's relink and fas are Task 7.  fgx_static taking the libraries is Task 6.  Spec 6.1's "reboot stays dynamic" needs no task, since reboot is not marked static.  The fpsim window needs none either: it is a statement of fact, and Task 2's gate covers it.
- Rulings R1-R4 change spec text and are written into it in Task 1.  R5 and R6 are plan mechanics.
- Interfaces: `ldload` exit codes (Task 2) are used by rc.in in Task 2 only.  Task 4's dropping is what Task 5's `fgxutil` test relies on (both libraries offered, one kept).  `LIBS["libfgx"|"libutil"]` (Task 5) is used by Task 7's `dlibs`.  fgx_static's `libs`/`extra` (Task 6) is used by Task 6's gen.py branch.
