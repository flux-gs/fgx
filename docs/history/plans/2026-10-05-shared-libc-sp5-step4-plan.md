# Shared libc SP5 step 4: the toolchain's fixtures off crt0_far.s -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nothing in `toolchain/tests/` or `toolchain/bench/` links or PUTs `crt0_far.s` (two references remain by design: `test_libso.py:174`, which checks its absence, and none other once Task 4 rewrites the C comments):
- the fcc fixtures (`run.sh`), the runtime oracle (`run_runtime.py`) and the bench (`fbench_kernel.py`) link through one helper that calls fgx_static;
- the multibank sweep links through the same helper;
- the 42 M-dirs' `_seg0.link.s`, `_seg1.link.s` and `_fgx.json`, the bench corpus's three, and the sweep's `dataseg.link.s` are deleted;
- carried from step 3: the 16 hand-listed fgx_static/fgx_dyn edges in gen.py's SHELLS use `STATIC_INPUTS`/`DYN_INPUTS`, and `tools/stack_reach.py` reads the `.ld` directories.

**Architecture:** A new `toolchain/tests/fixture_link.py` builds one fgx_static command: crt0_lib, the fixture's code and data, libfgx's program-mode compile (`build/static_libs/libfgx.s`), libc's library-mode compile, plus whatever an M-dir's optional `_link.json` adds. `run.sh` calls it from bash; `run_runtime.py`, `fbench_kernel.py` and the sweep's `gen_sweep_link.py` import it. The sweep's bankmap groups become `--code-seg`s. `crt0_far.s` itself stays until step 5, because the pile path (`tools/fgx2/seg0.link.s.in`, gen.py's `LIBC_SEED_ROOTS` and `shell_deps` floor) still names it.

**Tech Stack:** Python 3 host tools, bash (`toolchain/tests/run.sh`, `multibank/build_sweep.sh`), ninja (`tools/ninja/gen.py`), headless MAME through `tools/mame_test/run.py` (the sweep and the oracle).

**Status:** revised for an adversarial review (Fable, 2026-10-06): no Critical, seven Important and thirteen Minor findings, all adopted (M11, `check_libc_link_sites.py`'s pattern-only mention of the templates, by a docstring fix).

**Spec:** [`2026-10-04-shared-libc-sp5-design.md`](2026-10-04-shared-libc-sp5-design.md), section 7 (Toolchain bullet: `crt0_far.s` and what PUTs or names it) and section 8 item 4. Step 3's RESUME (`docs/history/resume/RESUME-2026-10-05b-shared-libc-sp5-step3-landed.md`, gitignored) carries the gen.py and stack_reach items.

## Starting state (measured 2026-10-05, HEAD 15ca1c43b)

- 710 fixtures in 42 M-dirs. 36 M-dirs share one `_seg0.link.s`; M37-M42 differ from it in comments and termlib: M38 and M39 PUT `libtermlib_helpers.s` and `libtermlib.s` (seg0) and their data (seg1), M37 termlib's data only. Ten `_fgx.json` add `"stack_frames": ["fcc_output.s"]`.
- **Spike: 709 of 710 fixture goldens link under fgx_static** with `--lib build/static_libs/libfgx.s,build/static_libs/libfgx.data.s` and nothing else (scratchpad run, every `.expected.s` + `.expected.data.s`). The one failure is `M38/tcops`, the only fixture that calls termlib (`tgetent` unresolved).
- `M38/tcops` links when `libtermlib.c` is compiled program-mode (`fcc --sections --sigs build/libc.sigs -Itoolchain/lib/libtermlib_c`) and passed as a `--lib`, **with** `libtermlib_helpers.s`/`libtermlib_helpers_data.s` as program code and data. Without the helpers it fails: `JSR _tc_setent` unresolved in `libs.s` (libtermlib.c's inline asm near-calls them, so they must sit in segment 0 with it).
- **The multibank sweep links under fgx_static** with bankmap group 0 as `--code` and groups 1-4 as `--code-seg`, ballast as a 12,288-byte `DS` file: seg0 10,618, data 2,280, seg2-5 19,541/21,389/19,385/22,049, one libc bank 21,973 bytes; 7 segments.
- Fixture binaries: 712 `.expected.bin` total 11,134,545 bytes (mean 15,638) today; the 709 fgx_static links total 7,732,048 (mean 10,906, largest 90,812).
- **The goldens do not move.** `.expected.s` and `.expected.data.s` are fcc's output; the link is downstream of them, and the `.expected.bin` is a gitignored build product (`run.sh` header). Spec section 7's "goldens regenerated" therefore means: a `REGEN=1` run over the new link leaves `git status` clean. What does change is every fixture binary, and the only things that execute those are the oracle (`run_runtime.py`) and the sweep -- which is why both run in Task 6.
- `run_runtime.py:build_fcc_bin` compiles a fixture without its M-dir's `_fcc.flags`, which `run.sh` passes (`run.sh:195-199`). M42's six fixtures (`--libso-inplace`) are compiled differently in the oracle's differential mode than in the golden run. A defect found along the way; Task 3 fixes it in its own commit.

## Global Constraints

- ASCII only in every file.
- 65816 assembly is written by the main agent, not delegated. No task here is expected to need any; an implementer who finds it does stops with NEEDS_CONTEXT.
- Commit bodies are the changelog: informational, no process, no follow-ups; trailers as the session gives them.
- No push, no MR.
- Headless MAME only: `tools/mame_test/run.py` (which the sweep and the oracle drive). Never a raw `mame64`, never `--debug`. Say for every MAME verdict whether it ran fresh.
- A test that cannot go red is not coverage: every new check states its control, and the control is run once.
- New MAME tests are probes and do not join `GATE_TESTS`. This plan adds none.
- Toolchain-first: a gap in fcc, libc or the linkers is fixed there, not in a fixture's recipe.
- Nothing is retired beyond what these links alone used. `crt0_far.s`, `args.s`, the piles, `seg3.py`, `fgx_gc.run()` and the `shell_deps` floor stay for step 5.
- Source comments describe the current state only.
- No change here has a BSD or K&R counterpart (test and build plumbing only); commits say so rather than cite.

## Plan rulings

- **R1. One fixture link, in one file.** Today the same link is written three times: `run.sh:link_fixture`, `run_runtime.py:_link_fixture_fgx2` (which `fbench_kernel.py` imports) and `multibank/gen_sweep_link.py`. The comments in `run_runtime.py:386-400` record that two of these copies drifted once and hid a soft-frame mutation. `toolchain/tests/fixture_link.py` replaces all three. It shells out to `fgx_static.py` rather than importing it, so fgx_static's `die()` (a `SystemExit`) stays a failed link and not a dead oracle. Cost if wrong: one file to split later.
- **R2. Libraries come from ninja's `build/static_libs/`, not from run.sh.** Static tools link `build/static_libs/libfgx.s` (gen.py:2523-2531); the fixtures use the same file, so they test what the static set ships. `run.sh` and `fixture_link.py` refuse with "run ninja first" when it is absent. Consequence: `make -C toolchain test` on a tree never built by ninja stops at that message. The gate runs `ninja all` before the fixture stage (`tools/gate.sh:520`), so the gate is unaffected. Cost if wrong: run.sh compiles its own libfgx, a dozen lines.
- **R3. termlib, for tcops only, by an M-dir recipe.** gen.py gains `build/static_libs/libtermlib.s`, compiled as libfgx's is. `toolchain/tests/M38/_link.json` names it as a `lib` and the helpers as `code`/`data`. The recipe's three keys are `code`, `data` and `lib`; any other key is refused. M39's termlib PUTs had no user (spike: all M39 fixtures link without it) and go with its templates. The bench corpus's termlib PUTs likewise: no bench calls termlib. Rejected: a `--lib CODE,DATA,HCODE,HDATA` form in fgx_static. No static program links termlib, and one fixture does not justify a linker option. Cost if wrong: a later static termlib user adds the option and M38's recipe shrinks to one `lib` line.
- **R4. The sweep keeps its placement.** bankmap group 0 is segment 0; group *i* (i >= 1) is fgx_static's segment *i*+1 (segment 1 is the data). The caller/callee lint is unchanged: it compares groups. Ballast becomes one `DS 12288` file per ballast entry. fgx_static's `stack_frames` already includes every code file and every libc bank (`fgx_static.py:197, 318, 332, 343`), which supersedes the hand-added `libc.sel.s` entry and its long comment in `gen_sweep_link.py:128-157`. bankmap.json's note text about seg0 carrying "the shared libc/libfgx pile" is corrected; the placement itself does not change.
- **R5. anti_coincidence reads fgx_static's layout and fails on zero tags.** Data is `ld/seg1` and `ld/seg1_layout.s`; code banks are `ld/seg0`, `ld/seg2`... and `ld/bank*`. Today zero tags prints "nothing to check" and passes. Once the layout path moves, a wrong path or a renamed label would turn the scan into a silent pass, so zero tags becomes a failure.
- **R6. The SHELLS edges.** gen.py checks, when it generates the graph, that each SHELLS entry depends on the whole input list of every linker its build scripts run -- every `.sh` in its command plus its `links`, since tcsh's link is the second script (gen.py:1577): `STATIC_INPUTS` when a script names `fgx_static.py`, `DYN_INPUTS` when it names `fgx_dyn.py`. The 16 hand-listed entries (libcso, ldload, bytecatso, libcsofull; dynso, dynsodyn, dynsomisdyn, dyntrue, dynmulti, dynrebind, dyntabseg, fitover, fitunder, dyntruebound, cursso, curssodyn) take the list in `hard=`, because `extra` is existence-filtered (`shell_deps`, gen.py:1902-1909) and both lists name build products. The dynamic entries keep `disk_src/etc/ld.so.conf` and `build/libc.sigs`, which DYN_INPUTS lacks.
- **R7. stack_reach reads every link file a build wrote.** `sources()` globs `seg*.link.s` in the build dir and `seg*.link.s` and `bank*.link.s` in each `*.ld/` under it. It resolves each PUT against the link file's own directory, because fgx_static writes paths relative to the `.ld` dir (`fgx_libso.write_link`). It skips `seg1_layout.s`, `imports_layout.s`, `macros.s` and `dataseg_layout.s`. `PROGRAMS` is unchanged (sh and tar static, tcsh/grep/ls dynamic).

## Review Focus

1. **A fixture whose M-dir recipe is silently ignored.** If `_link.json` were not read, tcops would fail, but only as one FAIL among 710. Pinned by Task 1's negative control: tcops linked from a scratch M-dir without the recipe must fail with `tgetent` in the log.
2. **The oracle building a different program than the golden run.** It now shares the link (R1). The compile differed by `_fcc.flags`; Task 3 pins that with a byte comparison of the two builds of `M42/libso_calls`.
3. **A sweep that links but proves nothing.** If the data segment or the code banks moved, the anti-coincidence scan could read the wrong files. Pinned by R5's zero-tag failure, Task 4's control run of the scan against a deliberately wrong layout path, and the sweep's own runtime preflight (exit 99) in Task 6.
4. **A gate that skips the stages this plan changes.** The fixture stage and the sweep/oracle stage are keyed on a hash of `toolchain/` `.c/.h/.py/.s/.json` files (`tools/gate.sh:450-463`). This plan moves it anyway (`fixture_link.py`, `_link.json`, the deleted templates), but `run.sh` (a `.sh`) is not in it, so a later run.sh-only change would not re-run the fixtures. Task 6 deletes both stamps before the gate regardless -- harmless, and it removes the question -- and reads the gate log for the fixture count and the oracle line.
6. **A linker change the oracle's scoping cannot see.** Every fixture binary now depends on `toolchain/src/ld/` and `fixture_link.py`. Task 3 adds them to `BROAD_INPUT_PREFIXES`, so such a change selects the forced-plus-sample set rather than one edited fixture.
5. **A static link whose libc state is set up by crt0_lib and not crt0_far.** Every fixture now enters through `_crt0_lib`/`_libc_start`. The ones that touch what crt0 seeds are `M1/sigdbr` (signal trampoline, DBR), the M35 soft-frame fixtures (`_fcc_sfp`), `M38/sigsown` and the environ/argv fixtures. Pinned by the oracle's `--all` run in Task 6: every fixture's exit code against `oracle.json`, not a sample.

---

### Task 1: `fixture_link.py`, and a program-mode libtermlib

**Files:**
- Create: `toolchain/tests/fixture_link.py`
- Create: `toolchain/tests/test_fixture_link.py`
- Create: `toolchain/tests/M38/_link.json`
- Modify: `toolchain/src/ld/fgx_static.py` (the fgx_ld call, :351-352)
- Modify: `tools/ninja/gen.py` (the static_libs block, gen.py:2520-2532; `all`, :3180)
- Modify: `tools/gate.sh` (after the build's `ninja all`, gate.sh:390-394)
- Modify: `toolchain/.gitignore`, `toolchain/bench/.gitignore`

**Interfaces:**
- Produces:
  - `fixture_link.command(mdir, scratch, code, data, out, name="fixture", code_segs=()) -> list[str]`: the fgx_static argv. `code`, `data` and each group in `code_segs` are lists of paths, relative to `mdir` or absolute.
  - `fixture_link.link(mdir, scratch, code, data, out, name="fixture", code_segs=()) -> (bool, str)`: runs it. Returns ok (exit 0 and `out` exists) and the combined stdout/stderr.
  - CLI: `fixture_link.py --mdir D --scratch S --code a.s[,b.s] --data a.data.s[,..] --out F [--name N]`, exit 0 on success, 1 on a failed link, 2 on a missing library.
  - `build/static_libs/libtermlib.s` and `build/static_libs/libtermlib.data.s` (ninja).

- [ ] **Step 1: Write the failing test**

`toolchain/tests/test_fixture_link.py`:

```python
#!/usr/bin/env python3
"""test_fixture_link.py - the fixture link (fixture_link.py) builds a static
image entered at _crt0_lib with no crt0_far.s in it, reads an M-dir's
_link.json, and refuses a recipe key it does not know.  Needs ninja's
build/static_libs/ and the toolchain's lib/libc_so.s.

Run: python3 toolchain/tests/test_fixture_link.py
"""
import json
import os
import shutil
import struct
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(REPO, "tools"))
import fixture_link  # noqa: E402
import libc_so_check  # noqa: E402

fails = []


def check(cond, what, detail=""):
    print(("  ok   " if cond else "  FAIL ") + what + ("  " + detail if detail else ""))
    if not cond:
        fails.append(what)


def stage(tmp, mdir, name):
    """Copy a fixture's goldens into tmp as <name>.s / <name>.data.s."""
    src = os.path.join(HERE, mdir, name)
    shutil.copy(src + ".expected.s", os.path.join(tmp, name + ".s"))
    shutil.copy(src + ".expected.data.s", os.path.join(tmp, name + ".data.s"))


def plain(tmp):
    stage(tmp, "M0", "return_42")
    out = os.path.join(tmp, "r42.bin")
    ok, log = fixture_link.link(tmp, os.path.join(tmp, "ld"), ["return_42.s"],
                                ["return_42.data.s"], out)
    check(ok, "M0/return_42 links", log[-300:])
    if not ok:
        return
    data = open(out, "rb").read()
    check(data[:4] == b"FGX3", "the image is FGX3", repr(data[:4]))
    seg0 = 16 + 8 * data[6]
    entry = struct.unpack_from("<H", data, 8)[0]
    check(data[seg0 + entry:seg0 + entry + 2] == b"\xC2\x30",
          "the entry is _crt0_lib's REP #$30", hex(entry))
    lst = os.path.join(tmp, "ld", "seg0_Output.txt")
    check(not libc_so_check.label_addrs(lst, {"_crt0_start"}),
          "crt0_far.s is not in the link (no _crt0_start)")


def recipe(tmp):
    # M38's recipe, read from M38 itself: tcops links.
    m38 = os.path.join(HERE, "M38")
    stage(tmp, "M38", "tcops")
    ok, log = fixture_link.link(m38, os.path.join(tmp, "ld38"),
                                [os.path.join(tmp, "tcops.s")],
                                [os.path.join(tmp, "tcops.data.s")],
                                os.path.join(tmp, "tcops.bin"))
    check(ok, "M38/tcops links with M38/_link.json", log[-300:])
    # Control: the same fixture from a directory with no recipe must fail,
    # and on the termlib symbol, or the recipe is not what made it link.
    bare = os.path.join(tmp, "bare")
    os.mkdir(bare)
    ok, log = fixture_link.link(bare, os.path.join(tmp, "ldbare"),
                                [os.path.join(tmp, "tcops.s")],
                                [os.path.join(tmp, "tcops.data.s")],
                                os.path.join(tmp, "tcops_bare.bin"))
    check(not ok and "tgetent" in log[-300:] and "Traceback" not in log,
          "without a recipe tcops fails on tgetent, as fgx_static's own "
          "message", log[-300:])


def bad_key(tmp):
    d = os.path.join(tmp, "badkey")
    os.mkdir(d)
    with open(os.path.join(d, "_link.json"), "w") as f:
        json.dump({"code": [], "libs": []}, f)
    try:
        fixture_link.command(d, d, ["a.s"], ["a.data.s"], os.path.join(d, "a.bin"))
    except SystemExit as e:
        check("libs" in str(e), "an unknown recipe key is refused", str(e))
        return
    check(False, "an unknown recipe key is refused", "no SystemExit")


tmp = tempfile.mkdtemp(prefix="fixture_link.")
try:
    for t in (plain, recipe, bad_key):
        t(tmp)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("test_fixture_link: %s" % ("FAIL (%d)" % len(fails) if fails else "OK"))
sys.exit(1 if fails else 0)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 toolchain/tests/test_fixture_link.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'fixture_link'`.

- [ ] **Step 3: Add the libtermlib compile to gen.py**

In `tools/ninja/gen.py`, after the `libutil` `lines.append(...)` in the static_libs block (gen.py:2528-2532), add:

```python
    lines.append(
        "build build/static_libs/libtermlib.s | build/static_libs/libtermlib.data.s: fcc_c "
        "toolchain/lib/libtermlib_c/libtermlib.c | $fcc build/libc.sigs\n"
        "  data = build/static_libs/libtermlib.data.s\n"
        "  flags = --sections -Itoolchain/lib/libtermlib_c\n  softscc =")
```

and extend the block's comment to say that libtermlib is compiled for the fcc fixtures' termlib recipe (`toolchain/tests/M38/_link.json`), no static program linking it. libfgx's compile reaches `all` through the static tools that link it; libtermlib's has no consumer in the graph, so `all` would never build it. Add it to `all`'s phony list (gen.py:3180):

```python
    lines.append("build all: phony kernel modules userland shells disk "
                 "build/.libc_checked build/static_libs/libtermlib.s\n")
```

Announce: "Rebuilding the main checkout's build graph (gen.py + ninja); feat/shared-libc, HEAD unchanged."

Run: `python3 tools/ninja/gen.py && ninja build/static_libs/libtermlib.s && ninja -n all | head -3`
Expected: the compile succeeds (the `fcc_c` rule's `$scheck` stack check included), and `ninja -n all` reports no work once `ninja all` has run.

- [ ] **Step 4: Write `fixture_link.py`**

```python
#!/usr/bin/env python3
"""fixture_link.py - link one fcc fixture as fgx_static links a static
program: crt0_lib, the fixture's code and data, libfgx's program-mode
compile (build/static_libs, as the static set links it) and libc's
library-mode compile.  run.sh, run_runtime.py, the bench and the multibank
sweep all link through here.

An M-dir's optional _link.json adds files, paths relative to the repository
root:
    {"code": ["a.s"], "data": ["a_data.s"], "lib": [["l.s", "l.data.s"]]}
`code' and `data' join the program's own (never pruned); each `lib' pair is
pruned as libfgx is.

Run: fixture_link.py --mdir D --scratch S --code a.s[,b.s] --data a.data.s[,..]
                     --out F [--name N]
     exit 0 linked, 1 the link failed, 2 a library is not built
"""
import argparse
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
STATIC = os.path.join(REPO, "toolchain", "src", "ld", "fgx_static.py")
LIBFGX = ("build/static_libs/libfgx.s", "build/static_libs/libfgx.data.s")
KEYS = ("code", "data", "lib")


def recipe(mdir):
    p = os.path.join(mdir, "_link.json")
    if not os.path.exists(p):
        return {k: [] for k in KEYS}
    r = json.load(open(p))
    bad = sorted(set(r) - set(KEYS))
    if bad:
        sys.exit("fixture_link: %s: unknown keys %s" % (p, ", ".join(bad)))
    return {k: r.get(k, []) for k in KEYS}


def command(mdir, scratch, code, data, out, name="fixture", code_segs=()):
    r = recipe(mdir)
    here = lambda p: os.path.join(os.path.abspath(mdir), p)
    repo = lambda p: os.path.join(REPO, p)
    libs = [LIBFGX] + [tuple(l) for l in r["lib"]]
    missing = [p for l in libs for p in l if not os.path.exists(repo(p))]
    if missing:
        print("fixture_link: %s not built: run ninja first" % ", ".join(missing),
              file=sys.stderr)
        sys.exit(2)
    cmd = [sys.executable, STATIC, "--name", name, "--dir", os.path.abspath(scratch),
           "--code", ",".join([here(p) for p in code] + [repo(p) for p in r["code"]]),
           "--data", ",".join([here(p) for p in data] + [repo(p) for p in r["data"]]),
           "--out", os.path.abspath(out)]
    for c, d in libs:
        cmd += ["--lib", repo(c) + "," + repo(d)]
    for g in code_segs:
        cmd += ["--code-seg", ",".join(here(p) for p in g)]
    return cmd


def link(mdir, scratch, code, data, out, name="fixture", code_segs=()):
    r = subprocess.run(command(mdir, scratch, code, data, out, name, code_segs),
                       capture_output=True, text=True)
    return r.returncode == 0 and os.path.exists(out), r.stdout + r.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mdir", required=True)
    ap.add_argument("--scratch", required=True)
    ap.add_argument("--code", required=True)
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--name", default="fixture")
    a = ap.parse_args()
    ok, log = link(a.mdir, a.scratch, a.code.split(","), a.data.split(","),
                   a.out, a.name)
    sys.stdout.write(log)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
```

`toolchain/tests/M38/_link.json`:

```json
{
  "code": ["toolchain/lib/libtermlib_helpers.s"],
  "data": ["toolchain/lib/libtermlib_helpers_data.s"],
  "lib": [["build/static_libs/libtermlib.s", "build/static_libs/libtermlib.data.s"]]
}
```

- [ ] **Step 5: Run the test -- the recipe passes, the control's message does not**

Run: `python3 toolchain/tests/test_fixture_link.py`
Expected: every line `ok` except "without a recipe tcops fails on tgetent, as fgx_static's own message": fgx_static runs fgx_ld with `check=True` (`fgx_static.py:351-352`), so an unresolved symbol ends in a 23-line `CalledProcessError` traceback after fgx_ld's one-line message (measured by the review). run.sh shows a failure's last 12 lines (`run.sh:238`), so the symbol never reaches the reader.

- [ ] **Step 6: fgx_static reports fgx_ld's refusal as its own**

In `toolchain/src/ld/fgx_static.py`, replace the fgx_ld call (:351-352) with:

```python
    r = subprocess.run([sys.executable, os.path.join(HERE, "fgx_ld.py"), mpath,
                        "-o", out], capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    if r.returncode:
        die(r.stderr.strip() or r.stdout.strip() or "fgx_ld failed")
```

Run: `python3 toolchain/src/ld/fgx_static.py --self-test && python3 toolchain/tests/test_fixture_link.py`
Expected: `fgx_static: self-test OK`; every line `ok`, last line `test_fixture_link: OK`, exit 0. The control line is `ok`, which means the control did fail, on `tgetent`, without a traceback.

- [ ] **Step 7: Ignore the link scratch**

`toolchain/.gitignore`, in the "Transient test intermediates" block (:21-24), add `.ld/`, `.link.err` and `fixture_fgx`. `toolchain/bench/.gitignore`: add `corpus/.ld/` and `corpus/fixture_fgx`. An interrupted run then leaves a clean `git status`, as the existing `fcc_output.s` entry is for.

- [ ] **Step 8: Wire it into the gate after the build**

`fixture_link` needs ninja's `build/static_libs/`, so the test runs after the gate's build, not in the checker block (which runs before it, gate.sh:149-226; on a fresh tree it would go red there instead of at the build). In `tools/gate.sh`, after the `ninja all` at gate.sh:390-394:

```bash
# Every fcc fixture, the oracle, the bench and the multibank sweep link through
# fixture_link.py; its test carries its own negative control (tcops without
# M38's recipe must fail on tgetent).
python3 toolchain/tests/test_fixture_link.py >/dev/null 2>&1 \
    || fail_out "fixture link check failed: test_fixture_link.py"
```

Run: `bash -n tools/gate.sh`
Expected: no output.

- [ ] **Step 9: Commit**

Two commits: the linker fix on its own, then the rest.

```bash
git add toolchain/src/ld/fgx_static.py
git commit -m "fix(fgx_static): report fgx_ld's refusal as fgx_static's own message" \
  -m "fgx_static ran fgx_ld with check=True, so an unresolved symbol ended the link in a CalledProcessError traceback with fgx_ld's one-line diagnosis above it, out of sight of a caller that shows the tail.  fgx_static now dies with fgx_ld's message.  Tooling only, no BSD counterpart."
git add toolchain/tests/fixture_link.py toolchain/tests/test_fixture_link.py \
        toolchain/tests/M38/_link.json tools/ninja/gen.py tools/gate.sh \
        toolchain/.gitignore toolchain/bench/.gitignore
git commit -m "test(fixtures): fixture_link.py, the one fixture link, through fgx_static" \
  -m "A fixture links as a static program does: crt0_lib, its code and data, libfgx's program-mode compile and libc's library-mode compile.  An M-dir's _link.json adds code, data and pruned libraries; M38's adds libtermlib, now compiled program-mode by ninja, and the termcap helpers its inline asm near-calls.  Test-only plumbing, no BSD counterpart."
```

---

### Task 2: run.sh links through `fixture_link.py`

**Files:**
- Modify: `toolchain/tests/run.sh` (header :1-41, `cleanup` :66-79, `link_fixture` :84-145, the precondition block :53-61, the T5-C comment :325-331)

The 42 M-dirs' templates are NOT deleted here: `run_runtime.py:402-404` reads `_seg0.link.s` unguarded and `fbench_kernel.py:29,69` imports the old link, and both run in the gate's runtime stage. Task 3 deletes them once nothing reads them.

**Interfaces:**
- Consumes: `fixture_link.py` CLI (Task 1).
- Produces: `run.sh` unchanged in usage (`[REGEN=1] [PARALLEL=N] run.sh [name ...]`), with `<name>.expected.bin` now an fgx_static image. Per-fixture scratch lives in `<M-dir>/.ld/`.

- [ ] **Step 1: Record the baseline and confirm the current run is green**

Run: `cd toolchain/tests && ./run.sh > /tmp/fgx_step4_before.log 2>&1; tail -3 /tmp/fgx_step4_before.log`
Expected: `710 passed, 0 failed` and the stack_check lines pass.

- [ ] **Step 2: Replace the link**

In `run.sh`, add next to the existing variables (after `SEG3=` at :49, which goes):

```bash
LINK="$HERE/fixture_link.py"
```

and delete the `GEN=`, `LD=` and `SEG3=` lines. After the merlin32 check (:58-61) add:

```bash
for l in libfgx libtermlib; do
    if [ ! -f "$HERE/../../build/static_libs/$l.s" ]; then
        echo "build/static_libs/$l.s not built. Run: ninja" >&2
        exit 2
    fi
done
```

Replace the whole body of `link_fixture()` (:84-145) with:

```bash
# Link the staged fcc_output.s / fcc_output.data.s in $dir into
# $dir/fixture_fgx through fixture_link.py (fgx_static).  Returns non-zero and
# leaves the linker's output in .link.err on failure.
link_fixture() {
    local dir="$1"
    (
        cd "$dir" || exit 1
        if ! python3 "$LINK" --mdir . --scratch .ld --code fcc_output.s \
                --data fcc_output.data.s --out fixture_fgx >.link.err 2>&1; then
            echo "STAGE link: fixture_link.py failed" >>.link.err
            exit 1
        fi
    )
}
```

Replace `cleanup()`'s `rm` (:69-79) with:

```bash
    rm -f "$dir/$name.s" "$dir/$name.data.s" \
          "$dir/fcc_output.s" "$dir/fcc_output.data.s" "$dir/fixture_fgx" \
          "$dir/.diff.out" "$dir/.link.err"
    rm -rf "$dir/.ld"
```

Rewrite the header's step 3 (:7-15) to:

```
#   3. link the fixture binary: fixture_link.py, which runs fgx_static over
#      fcc_output.s / fcc_output.data.s (crt0_lib, libfgx's program-mode
#      compile, libc's library-mode compile, plus the M-dir's _link.json)
#   4. cp fixture_fgx -> <name>.expected.bin         (BUILD PRODUCT, gitignored)
```

and in the paragraph after it replace "merlin32+fgx_ld applied to the .expected.s plus the runtime/libc pile" with "fgx_static applied to the .expected.s and the committed libraries". Delete the comment block about libc-breakup task 5 (it lived inside the old `link_fixture`).

- [ ] **Step 3: The comments that go false**

`run.sh:325-331` ("T5-C: the C libc pile ships in EVERY binary") is no longer true: a fixture links libc's library-mode compile. Reword it to say why the checks stay -- `libc_c.s` and `libfgx.s` are still the piles step 5 retires, and their emission is still stack-checked here -- without the claim. Replace any em-dash in a line you rewrite with `--` (ASCII only; run.sh has eight).

- [ ] **Step 4: Run the full suite**

Run: `cd toolchain/tests && ./run.sh > /tmp/fgx_step4_after.log 2>&1; tail -3 /tmp/fgx_step4_after.log`
Expected: `710 passed, 0 failed`, stack_check passes.

- [ ] **Step 5: The goldens do not move**

Run: `cd toolchain/tests && REGEN=1 ./run.sh > /tmp/fgx_step4_regen.log 2>&1; tail -2 /tmp/fgx_step4_regen.log; git status --short -- . | grep -v '^D ' | head`
Expected: `710 passed, 0 failed`; `git status` lists only `run.sh`.

- [ ] **Step 6: Control -- the link stage runs**

Run: `mv M38/_link.json /tmp/ && ./run.sh tcops; mv /tmp/_link.json M38/` (from `toolchain/tests`)
Expected: `FAIL tcops (STAGE link: fixture_link.py failed)` with fgx_ld's `unresolved symbol 'tgetent'` line in the printed tail (Task 1 Step 6 is what puts it there), then `0 passed, 1 failed`. Then `./run.sh tcops` passes again.

- [ ] **Step 7: No scratch left behind**

Run: `find toolchain/tests -name .ld -o -name fixture_fgx -o -name .link.err | wc -l`
Expected: `0` (a count, not a `head`).

- [ ] **Step 8: Commit**

```bash
git add toolchain/tests/run.sh
git commit -m "test(fixtures): run.sh links each fixture with fgx_static" \
  -m "Each fixture is linked by fixture_link.py, entered at _crt0_lib, against libc's library-mode compile and libfgx's program-mode compile, instead of crt0_far.s and the libc pile.  The goldens are fcc's output and do not change: a REGEN run over the new link rewrites none of the 710.  run.sh now needs ninja's build/static_libs/libfgx.s and libtermlib.s.  Test-only plumbing, no BSD counterpart."
```

---

### Task 3: the oracle and the bench link through `fixture_link.py`; the oracle passes `_fcc.flags`

**Files:**
- Modify: `toolchain/tests/run_runtime.py` (:369-438 the link block, :441-485 `build_fcc_bin`, the header lines :20-21 and :36-37 that describe the pile link)
- Modify: `toolchain/bench/fbench_kernel.py` (:25-29 the import, :50-73 `build_fgx1`)
- Delete: `toolchain/bench/corpus/_seg0.link.s`, `_seg1.link.s`, `_fgx.json`
- Test: `toolchain/tests/test_fixture_link.py` (one more case)

**Interfaces:**
- Consumes: `fixture_link.link` (Task 1).
- Produces: `run_runtime.link_fixture(link_dir, extra_code=()) -> Path | None`, replacing `_link_fixture_fgx2`. `link_dir` holds `fcc_output.s`/`fcc_output.data.s`; the scratch is `link_dir/.ld`.

- [ ] **Step 1: Write the failing test (the `_fcc.flags` defect)**

Add to `toolchain/tests/test_fixture_link.py`, before the driver loop, and add `oracle_flags` to the tuple `(plain, recipe, bad_key)`:

```python
def oracle_flags(tmp):
    """run_runtime's differential build compiles a fixture as run.sh does,
    _fcc.flags included: M42/libso_calls built both ways is one image."""
    import pathlib
    import run_runtime
    golden = os.path.join(tmp, "golden")
    os.mkdir(golden)
    stage(golden, "M42", "libso_calls")
    gbin = os.path.join(golden, "g.bin")
    ok, log = fixture_link.link(os.path.join(HERE, "M42"), os.path.join(golden, "ld"),
                                [os.path.join(golden, "libso_calls.s")],
                                [os.path.join(golden, "libso_calls.data.s")], gbin)
    check(ok, "M42/libso_calls links from its golden", log[-200:])
    fx = {"name": "libso_calls", "c": pathlib.Path(HERE, "M42", "libso_calls.c"),
          "s": pathlib.Path(HERE, "M42", "libso_calls.expected.s")}
    obin = run_runtime.build_fcc_bin(fx, pathlib.Path(tmp),
                                     pathlib.Path(REPO, "toolchain", "fcc"))
    check(obin is not None and ok and open(str(obin), "rb").read() == open(gbin, "rb").read(),
          "the oracle's build of M42/libso_calls is the golden's image")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 toolchain/tests/test_fixture_link.py`
Expected: FAIL on "the oracle's build of M42/libso_calls is the golden's image": `build_fcc_bin` still links the pile way (the M-dir templates are still present), so its image differs from fgx_static's -- and it also compiles without `--libso-inplace`. Both are this task's to fix.

- [ ] **Step 3: Replace the oracle's link**

In `run_runtime.py`, replace :369-438 (the comment block, `GEN_LAYOUT`, `FGX_LD`, `SEG3`, `_LINK_INTERMEDIATES`, `_PUT_LIB_RE`, `_libc_roots`, `_link_fixture_fgx2`) with:

```python
# The fixture link: run.sh's, the bench's and the sweep's, in one place
# (fixture_link.py, fgx_static).
import fixture_link  # noqa: E402

_LINK_INTERMEDIATES = ["fcc_output.s", "fcc_output.data.s", "fixture_fgx"]


def link_fixture(link_dir, extra_code=()):
    """Link the staged fcc_output.s/.data.s in link_dir -> fixture_fgx.
    Returns the Path or None."""
    out = link_dir / "fixture_fgx"
    ok, _log = fixture_link.link(str(link_dir), str(link_dir / ".ld"),
                                 ["fcc_output.s"] + list(extra_code),
                                 ["fcc_output.data.s"], str(out))
    return out if ok else None
```

If `import fixture_link` fails when `run_runtime` is imported from another directory, add `sys.path.insert(0, str(Path(__file__).resolve().parent))` before it; `run_multibank.py` and `fbench_kernel.py` import `run_runtime` from elsewhere.

In `build_fcc_bin`: replace `_link_fixture_fgx2(link_dir)` with `link_fixture(link_dir)`; in its `finally`, after the unlink loop, add `shutil.rmtree(link_dir / ".ld", ignore_errors=True)`. Remove any other remaining use of the deleted names (`grep -n "_link_fixture_fgx2\|_libc_roots\|SEG3\|GEN_LAYOUT\|FGX_LD" toolchain/tests/run_runtime.py` prints nothing).

Every fixture binary now also depends on the linkers and the helper, which the change-scoping's broad-input list does not name: a linker change plus one fixture edit would run that one fixture and none of the 709 binaries the linker changed. Set (run_runtime.py:213-215):

```python
# Sources that change EVERY fixture binary without changing a single golden:
# the libraries every fixture links and the link itself.  Golden-diff
# scoping is blind to these by construction, so they get their own trigger.
BROAD_INPUT_PREFIXES = ("toolchain/lib/", "toolchain/src/ld/",
                        "toolchain/tests/fixture_link.py")
```

Comments that go false with this task, each rewritten to the current state (re-measure the sizes from the `.expected.bin` files after Task 2 and use those figures; this plan's spike measured 709 images totalling 7,732,048 bytes, mean 10,906, largest 90,812):
- the header's fixture-link lines (:20-21, "two-segment FGX2 links (merlin32 x2 + gen_seg1_layout + fgx_ld.py)"): "fgx_static links (fixture_link.py)";
- the header's volume paragraph (:27-45: "32 MB ProDOS volume ceiling", "Only linking against a shared pile would change that") and the `MAX_FIXTURES_PER_DISK` comment (:202-209: "a 63,650-byte seg0 libc pile", "the median fixture is 63,639 bytes"). The volume no longer binds: the whole suite is a few MB on a 32 MiB UFS disk (`build_big_disk`'s docstring, :557-566, already says the ProDOS ceiling is gone). Ruling: the cap stays at 240, and its comment states the reason that remains -- a change-scoped run boots only what the change touched (the maintainer, 2026-08-01), and `--all` is the full run;
- the NOTE strings that blame the volume (:293, :327, :341) and the chunked-mode NOTE (:1060-1068): say "exceeds the change-scoped cap of 240" instead of "does not fit a 32 MB volume".

Replace any em-dash in a line you rewrite with `--` (ASCII only; run_runtime.py has twelve).

- [ ] **Step 4: Run the test -- the link half passes, the flags half still fails**

Run: `python3 toolchain/tests/test_fixture_link.py`
Expected: if the images still differ, the failure is now only the missing `--libso-inplace`. Confirm, from the repo root (fcc runs in the M-dir because the file name is baked into its output):
```bash
(cd toolchain/tests/M42 && ../../fcc --data-segment /tmp/a.data.s --libso-inplace libso_calls.c -o /tmp/a.s) \
  && diff -q /tmp/a.s toolchain/tests/M42/libso_calls.expected.s && echo with-flag-identical
(cd toolchain/tests/M42 && ../../fcc --data-segment /tmp/b.data.s libso_calls.c -o /tmp/b.s) \
  && ! diff -q /tmp/b.s toolchain/tests/M42/libso_calls.expected.s >/dev/null && echo without-flag-differs
```
Expected: `with-flag-identical` and `without-flag-differs`.

- [ ] **Step 5: Commit the link move**

```bash
git add toolchain/tests/run_runtime.py
git commit -m "test(oracle): the runtime oracle links through fixture_link.py" \
  -m "run_runtime.py's copy of the fixture link (seg3 selection, two merlin32 passes, fgx_ld over the M-dir templates) is replaced by fixture_link.py, so the oracle stages the same fgx_static image run.sh builds.  Test-only plumbing, no BSD counterpart."
```

- [ ] **Step 6: Pass `_fcc.flags` in the differential build**

In `build_fcc_bin`, after the `sigsarg` lines:

```python
    # And the M-dir's _fcc.flags (M42: --libso-inplace), as run.sh passes them.
    flags_file = link_dir / "_fcc.flags"
    dirflags = flags_file.read_text().split() if flags_file.exists() else []
```

and add `+ dirflags` after `sigsarg` in the fcc argv.

Run: `python3 toolchain/tests/test_fixture_link.py`
Expected: every line `ok`, `test_fixture_link: OK`.

- [ ] **Step 7: Commit the defect fix**

```bash
git add toolchain/tests/run_runtime.py toolchain/tests/test_fixture_link.py
git commit -m "fix(oracle): the differential build passes the M-dir's _fcc.flags" \
  -m "run_runtime.py's build_fcc_bin compiled a fixture without its M-dir's _fcc.flags, which run.sh passes, so M42's six --libso-inplace fixtures ran as a different program in the oracle's differential mode than the one their goldens pin.  test_fixture_link.py compares the two builds of M42/libso_calls byte for byte.  Test-only plumbing, no BSD counterpart."
```

- [ ] **Step 8: Move the bench**

In `toolchain/bench/fbench_kernel.py`: the import (:29) becomes `from run_runtime import link_fixture  # noqa: E402`; the comment above it (:25-28) says the bench links as the fixtures do, through `fixture_link.py`; in `build_fgx1`, `_link_fixture_fgx2(pathlib.Path(CDIR))` becomes `link_fixture(pathlib.Path(CDIR), ["fbench_markers.s"])`. Rewrite its docstring's recipe sentence ("seg3 archive select -> seg1 -> seg1_layout -> seg0 -> fgx_ld") as "fgx_static, through fixture_link.py". After the link, `shutil.rmtree(os.path.join(CDIR, ".ld"), ignore_errors=True)`.

```bash
git rm -q toolchain/bench/corpus/_seg0.link.s toolchain/bench/corpus/_seg1.link.s \
          toolchain/bench/corpus/_fgx.json
```

Run (host only, no MAME):
```bash
cd toolchain/bench && python3 -c '
import glob, os, fbench_kernel as F
bad = [c for c in sorted(glob.glob(os.path.join(F.CDIR, "*.c"))) if F.build_fgx1(c)[0] is None]
print("failed:", bad)'
```
Expected: `failed: []`. If a bench's `build_fgx1` returns `fcc-fail` the cause predates this task; record it, and confirm with `git stash`-free evidence (run the same line at the task's BASE in a scratch worktree) before calling it pre-existing.

Run: `cd toolchain/bench/corpus && git status --short --ignored . | grep -v '^!!' ; ls -a | grep -E '^\.ld$|^fixture_fgx$'`
Expected: only the three deletions; no `.ld` or `fixture_fgx` left.

- [ ] **Step 9: Commit**

```bash
git add toolchain/bench/fbench_kernel.py
git commit -m "test(bench): the kernel bench links through fixture_link.py" \
  -m "fbench_kernel.py links each corpus bench as a fixture is, with fbench_markers.s as extra code; the corpus's _seg0.link.s, _seg1.link.s and _fgx.json are deleted, and with them a termlib pile no bench called.  Test-only plumbing, no BSD counterpart."
```

- [ ] **Step 10: Delete the M-dir templates, now that nothing reads them**

```bash
grep -rln "_seg0.link.s\|_seg1.link.s\|_fgx.json" toolchain/tests/*.py toolchain/tests/*.sh toolchain/bench/*.py tools/*.py tools/gate.sh | sort
```
Expected: no file that reads them. `tools/check_libc_link_sites.py` names `M*/_seg0.link.s` in its docstring and a pattern-only self-test (:14, :127); it passes without the files, and its docstring is corrected to say the fixtures link through fixture_link.py. Anything else that reads them is fixed first.

```bash
git rm -q toolchain/tests/M*/_seg0.link.s toolchain/tests/M*/_seg1.link.s toolchain/tests/M*/_fgx.json
git ls-files 'toolchain/tests/M*/_seg*' 'toolchain/tests/M*/_fgx.json' | wc -l
```
Expected: `0`.

Run: `cd toolchain/tests && ./run.sh > /tmp/fgx_step4_tmpl.log 2>&1; tail -1 /tmp/fgx_step4_tmpl.log; cd ../.. && python3 tools/check_libc_link_sites.py --self-test && python3 toolchain/tests/test_fixture_link.py | tail -1`
Expected: `710 passed, 0 failed` (the last line before the stack checks; read it with `grep passed`), `check_libc_link_sites` OK, `test_fixture_link: OK`.

```bash
git add tools/check_libc_link_sites.py
git commit -m "test(fixtures): delete the M-dir link templates" \
  -m "The 42 M-dirs' _seg0.link.s, _seg1.link.s and _fgx.json described the crt0_far.s pile link; run.sh, the runtime oracle and the bench now link through fixture_link.py and read none of them.  Test-only plumbing, no BSD counterpart."
```

---

### Task 4: the multibank sweep links through `fixture_link.py`

**Files:**
- Modify: `toolchain/tests/multibank/gen_sweep_link.py` (whole file)
- Modify: `toolchain/tests/multibank/build_sweep.sh` (steps 1b-5, the `rm` line)
- Modify: `toolchain/tests/multibank/anti_coincidence.py`
- Modify: `toolchain/tests/multibank/bankmap.json` (the two `notes` strings only)
- Modify: `toolchain/tests/multibank/README.md` (the "What it is" paragraph's link description)
- Modify: `toolchain/tests/multibank/.gitignore`
- Modify: `toolchain/tests/multibank/driver.c`, `c29_signal.c`, `toolchain/tests/M1/sigdbr.c` (comments only)
- Delete: `toolchain/tests/multibank/dataseg.link.s`

**Interfaces:**
- Consumes: `fixture_link.link(..., code_segs=...)` (Task 1).
- Produces: `toolchain/tests/multibank/multibank.bin` (path unchanged, so `run_multibank.py` is untouched); the link's scratch in `toolchain/tests/multibank/ld/`.

- [ ] **Step 1: Build the current sweep and record its scan line**

Run: `toolchain/tests/multibank/build_sweep.sh > /tmp/fgx_mb_before.log 2>&1; tail -3 /tmp/fgx_mb_before.log`
Expected: `anti_coincidence: N tag(s) unique across 5 code bank(s) OK` and `BUILD OK`. Note N.

- [ ] **Step 2: Rewrite `gen_sweep_link.py`**

```python
#!/usr/bin/env python3
"""Link the far-pointer sweep with explicit placement from bankmap.json.

bankmap.json's first code segment is the program's segment 0; each further
one is an fgx_static --code-seg, so group i (i >= 1) is segment i+1 (segment
1 is the data).  A ballast entry is a 12,288-byte DS block: inert bytes that
keep the code banks realistically full.  Also LINTS that every declared
[caller, callee] pair sits in DIFFERENT groups (a same-segment callee makes a
"cross-bank" call intra-bank -> false green).

fgx_static measures the stack over every code file and every libc bank it
links, so libc's deepest frame (getwd, 384 bytes) is counted.

Run from toolchain/tests/multibank/ AFTER build_sweep.sh compiles the TUs.
Writes multibank.bin, with the link's files in ld/.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import fixture_link  # noqa: E402

BALLAST_DS = 12288


def lint(bm):
    seg_of = {}
    for i, seg in enumerate(bm["code_segments"]):
        for tu in seg:
            seg_of[tu] = i
    for i, seg in enumerate(bm["code_segments"]):
        # fgx_ld refuses an FGX3 code segment with no FGX2_MODE stamp, which
        # only fcc output carries: a group of ballast alone cannot link.
        if all(t.startswith("ballast/") for t in seg):
            sys.exit("LINT FAIL: group %d holds only ballast; it needs a TU." % i)
    for caller, callee in bm.get("callees", []):
        if caller not in seg_of:
            sys.exit("LINT FAIL: caller TU '%s' not placed in any segment." % caller)
        if callee not in seg_of:
            sys.exit("LINT FAIL: callee TU '%s' not placed in any segment." % callee)
        if seg_of[caller] == seg_of[callee]:
            sys.exit("LINT FAIL: %s and its callee %s share group %d -> the call "
                     "would be intra-bank (false green)." % (caller, callee, seg_of[caller]))


def ballast(tu):
    name = "ballast_%s.s" % tu.split("/", 1)[1]
    with open(os.path.join(HERE, name), "w") as f:
        f.write("                DS     %d\n" % BALLAST_DS)
    return name


def link(bm):
    groups, data = [], []
    for seg in bm["code_segments"]:
        g = []
        for t in seg:
            if t.startswith("ballast/"):
                g.append(ballast(t))
            else:
                g.append(t + ".code.s")
                data.append(t + ".data.s")
        groups.append(g)
    ok, log = fixture_link.link(HERE, os.path.join(HERE, "ld"), groups[0], data,
                                os.path.join(HERE, "multibank.bin"),
                                name="multibank", code_segs=groups[1:])
    sys.stdout.write(log)
    if not ok:
        sys.exit("LINK FAIL (see above)")


if __name__ == "__main__":
    bm = json.load(open(os.path.join(HERE, "bankmap.json")))
    lint(bm)
    link(bm)
```

- [ ] **Step 3: Rewrite `build_sweep.sh`'s link half**

Keep the header comment's first two lines and steps "1. compile" and "6. anti-coincidence scan". Change the pipeline comment to `compile TUs --data-segment -> gen_sweep_link.py (placement lint + fgx_static) -> anti-coincidence scan`. Delete the `GEN=` and `LD=` lines, steps 1b, 2, 3, 4 and 5, and replace them with:

```bash
echo "== 2. lint + link (fgx_static, placement from bankmap.json) =="
python3 gen_sweep_link.py || { echo "link FAIL"; exit 1; }
echo "LINKED multibank.bin = $(wc -c < multibank.bin) B"
```

Renumber the scan to `== 3.`. Replace the `rm -f` line with:

```bash
rm -rf ld
rm -f *.code.s *.data.s ballast_*.s multibank.bin
```

Then `git rm -q toolchain/tests/multibank/dataseg.link.s`.

`toolchain/tests/multibank/.gitignore`: add `ld/` and `ballast_*.s` (the link leaves both by design: the scan reads `ld/`), and remove the entries nothing writes any more (`libc.sel.*`, `*.lst`, `multibank.json`, `seg[0-9].link.s`, `seg[0-9]`, `dataseg`, `dataseg_layout.s`). Keep `*.code.s`, `*.data.s`, `multibank.bin`.

Replace any em-dash in a line you rewrite with `--` in every file this task edits (ASCII only).

- [ ] **Step 4: Point the scan at fgx_static's layout, and fail on zero tags**

In `anti_coincidence.py`:
- the docstring says it reads `ld/seg1_layout.s` and `ld/seg1` (fgx_static's data segment) and every code bank (`ld/seg0`, `ld/seg2`..., `ld/bank*`);
- `layout = os.path.join(HERE, "ld", "seg1_layout.s")`;
- zero tags is an error: `sys.exit("anti_coincidence: no _cNN_g tags in %s -- the scan would check nothing" % layout)`;
- the code banks:
  ```python
  ld = os.path.join(HERE, "ld")
  segs = sorted(os.path.relpath(p, HERE) for p in
                glob.glob(os.path.join(ld, "seg[0-9]")) + glob.glob(os.path.join(ld, "seg[0-9][0-9]"))
                + glob.glob(os.path.join(ld, "bank[0-9]")))
  segs = [s for s in segs if s != os.path.join("ld", "seg1")]
  ```
- the tag is read with `read_bytes(os.path.join("ld", "seg1"), off, TAG_LEN)`, and the warning text says `seg1`, not `dataseg`.

Check `gen_seg1_layout.py`'s EQU values against `LABEL_RE` (`_cNN_g EQU $hex`) by reading one line of `ld/seg1_layout.s` after Step 5's build; if the form differs, fix the regex to the file's form.

- [ ] **Step 5: Build and scan**

Run: `toolchain/tests/multibank/build_sweep.sh > /tmp/fgx_mb_after.log 2>&1; tail -4 /tmp/fgx_mb_after.log`
Expected: a `static multibank:` summary line naming seg0, data, seg2-seg5 and the libc banks; `anti_coincidence: N tag(s) unique across 6 code bank(s) OK` (seg0, seg2-5, one libc bank; more if libc takes two), with the same N as Step 1; `BUILD OK`.

- [ ] **Step 6: Control -- the scan can fail**

Run (from `toolchain/tests/multibank`): `mv ld/seg1_layout.s /tmp/l.s && : > ld/seg1_layout.s && python3 anti_coincidence.py; echo rc=$?; mv /tmp/l.s ld/seg1_layout.s`
Expected: `no _cNN_g tags ... the scan would check nothing`, `rc=1`.

Then plant a coincidence: copy one non-zero tag's four bytes from `ld/seg1` into `ld/seg2` at the same offset.

```bash
cp ld/seg2 /tmp/seg2.orig
python3 - <<'EOF'
import re
tags = re.findall(r'^(_?c\d+_g)\s+EQU\s+\$([0-9A-Fa-f]+)', open("ld/seg1_layout.s").read(), re.M)
data = open("ld/seg1", "rb").read()
seg2 = bytearray(open("ld/seg2", "rb").read())
for name, off in tags:
    off = int(off, 16)
    tag = data[off:off + 4]
    if len(tag) == 4 and tag != b"\0\0\0\0" and off + 4 <= len(seg2):
        seg2[off:off + 4] = tag
        open("ld/seg2", "wb").write(seg2)
        print("planted", name, hex(off))
        break
else:
    raise SystemExit("no non-zero tag fits seg2 -- pick another bank")
EOF
python3 anti_coincidence.py; echo rc=$?
cp /tmp/seg2.orig ld/seg2 && python3 anti_coincidence.py
```
Expected: `planted _cNN_g 0x...`, then `FALSE-GREEN RISK ... in ld/seg2` and `rc=1`, then the restored run's `... OK`.

- [ ] **Step 7: Notes and README**

`bankmap.json` notes: in the first string replace "seg0 is filled by the shared libc/libfgx pile itself (LIBC+SHIMS+LIBC_C+LIBFGX+ARGS, emitted once in seg0), so it carries NO ballast -- once the tcsh/Bourne libc train grew the pile, a 12KB ballast + the ~52KB pile no longer fit one 64KB bank" with "seg0 carries crt0_lib, the fcc runtime and libc's hand-written code, and no ballast; libc's functions are in libc banks of their own". Replace the second string with "seg0 holds the driver and mbio; groups 1-4 are fgx_static segments 2-5 (segment 1 is the data)." Do not change `code_segments` or `callees`.

`README.md` "What it is": replace "built with the real machinery (`crt0_far` + `FGX2_FARCALL` + `FGX2_LONG_PTR`, `fcc --far-calls --data-segment` -> merlin32 -> `fgx_ld.py`)" with "linked by fgx_static as any static program is (`crt0_lib`, `FGX2_FARCALL`, `FGX2_LONG_PTR`; `toolchain/tests/fixture_link.py`)". Update the README line that lists `crt0_far.s` among the sweep's trigger files (:68) to `crt0_lib.s`.

Run: `grep -n "crt0_far\|dataseg" toolchain/tests/multibank/*.py toolchain/tests/multibank/*.sh toolchain/tests/multibank/README.md toolchain/tests/multibank/bankmap.json`
Expected: nothing, except `README.md:78` ("merged-dataseg globals"), which is rewritten to "data-segment globals" in this step.

- [ ] **Step 8: Source comments in the C**

`driver.c:1` and `c29_signal.c:3` name `crt0_far`. Change to `crt0_lib` (`driver.c`: "crt0_lib far-calls main and SYS_EXITs with A.lo"; `c29_signal.c`: "registers libc's signal trampoline"). `driver.c:7-9` and `run_multibank.py`'s docstring say green is exit 42; the driver exits 43 (`driver.c:142`) and `run_multibank.py:97` checks 43 -- correct both texts to 43. `toolchain/tests/M1/sigdbr.c:2` names `crt0_far` in a comment: say `_libc_start` publishes the trampoline (`libc_start.s:171-178`). fcc does not copy comments into its output, so `sigdbr.expected.s` does not move; confirm with `cd toolchain/tests && ./run.sh sigdbr`.

Run: `cd toolchain/tests/multibank && ./build_sweep.sh >/dev/null 2>&1; echo rc=$?`
Expected: `rc=0`.

- [ ] **Step 9: Commit**

```bash
git add toolchain/tests/multibank toolchain/tests/M1/sigdbr.c
git commit -m "test(multibank): the far-pointer sweep links with fgx_static" \
  -m "gen_sweep_link.py lints the placement and links through fixture_link.py: bankmap.json's first group is segment 0 and each further group a --code-seg, so the sweep keeps five code banks plus data, now with libc's functions in a bank of their own.  dataseg.link.s and the per-segment wrappers are gone.  The anti-coincidence scan reads fgx_static's data segment and every code and libc bank, and fails rather than passing when it finds no tags.  Test-only plumbing, no BSD counterpart."
```

---

### Task 5: the SHELLS edges carry their linker's inputs

**Files:**
- Modify: `tools/ninja/gen.py` (the 16 SHELLS entries named in R6, gen.py:1590-1830; a check after `SHELLS`)

**Interfaces:**
- Consumes: `STATIC_INPUTS`, `DYN_INPUTS`, `shell_deps(spec)` (gen.py).
- Produces: a generation-time refusal: `SystemExit` naming each SHELLS entry whose dependencies miss part of its linker's inputs.

- [ ] **Step 1: Write the failing check**

After `shell_deps` is defined (gen.py:1851 onwards) and before the SHELLS edges are emitted, add:

```python
def check_shell_linker_inputs():
    """A SHELLS entry whose build script runs fgx_static or fgx_dyn depends on
    that linker's whole input list, or an edit to one of its modules leaves
    the binary stale on the disk."""
    bad = []
    for name, spec in sorted(SHELLS.items()):
        # Every shell script the entry runs: tcsh's link is the SECOND script
        # of its command (build_tcsh.sh && bash build_tcsh_link.sh).
        paths = {t for t in spec["script"].split() if t.endswith(".sh")}
        paths |= set(spec["links"])
        script = "".join(open(os.path.join(ROOT, t)).read() for t in sorted(paths))
        deps = set(shell_deps(spec))
        for tool, inputs in (("fgx_static.py", STATIC_INPUTS), ("fgx_dyn.py", DYN_INPUTS)):
            if tool in script:
                missing = sorted(set(inputs) - deps)
                if missing:
                    bad.append("%s (%s): %s" % (name, tool, ", ".join(missing)))
    if bad:
        raise SystemExit("SHELLS entries missing their linker's inputs:\n  "
                         + "\n  ".join(bad))
```

Call it where the SHELLS edges are emitted (find the loop over `SHELLS` that calls `shell_deps`; call `check_shell_linker_inputs()` once before it). `shell_deps` returns a sorted list (gen.py:1910), hence the `set()`.

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 tools/ninja/gen.py`
Expected: `SystemExit` listing the 16 entries of R6 and no others (bsh, elvis and tcsh already carry their lists). The four static entries miss `toolchain/src/ld/fgx_pack.py`, `toolchain/lib/libllong/*.s` and `toolchain/lib/libdouble/d_stub.s`; the twelve dynamic ones additionally `fgx_libso.py`, `libc_so_helpers.s` and `libutil.so.1.0`. `fgx_gc.py` must NOT appear: `shell_deps` adds it unconditionally (gen.py:1897), and `fgx_ld.py`/`gen_seg1_layout.py` come from `TOOLCHAIN_DEPS` -- if any of those three is listed, the check is comparing the wrong thing. If an entry outside R6's list appears, or one of the 16 does not, stop and read its scripts: R6's list came from a text match, and the check is the authority.

- [ ] **Step 3: Give the 16 entries their lists**

For libcso, ldload, bytecatso and libcsofull: delete the hand-written `extra` list and its comment, and set
`extra=[]` (or drop the key if `shell_deps` tolerates its absence: check `spec["extra"]` at gen.py:1902; it does not, so keep `extra=[]`) and `hard=STATIC_INPUTS`.

For the 12 dynamic entries (dynso ... curssodyn): delete the hand-written `extra` and set `extra=[]`, `hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"]`. dynsomisdyn's script also names `fgx_libso.py`, which DYN_INPUTS contains.

If a script names both linkers (check `grep -l "fgx_static.py" tools/dynso-fgx2/build_dynso.sh tools/libcso-fgx2/build_libcso.sh tools/ldload-fgx2/build_ldload.sh`), give the entry both lists.

Fix the comment above STATIC_INPUTS (gen.py:1521-1522), which says "ldload's SHELLS entry lists the same": it now says the static SHELLS entries depend on this list and `check_shell_linker_inputs` holds them to it. Add the same sentence, with DYN_INPUTS, above DYN_INPUTS.

- [ ] **Step 4: Run it to verify it passes, and that the edges now fire**

Announce: "Regenerating build.ninja and rebuilding on feat/shared-libc; HEAD unchanged."

Run: `python3 tools/ninja/gen.py && ninja all > /tmp/fgx_step4_ninja.log 2>&1; tail -2 /tmp/fgx_step4_ninja.log; touch toolchain/src/ld/fgx_pack.py && ninja -n all | grep -cE 'libcso|ldload|bytecatso|dynso|dyntrue|dynmulti|dynrebind|dyntabseg|fit(over|under)|cursso'`
Expected: gen.py silent; `ninja all` completes; the count is at least 16 (each of the 16 binaries now rebuilds when fgx_pack.py changes).

Control that the check reads tcsh's link script (tcsh's `fgx_dyn.py` is only in `build_tcsh_link.sh`, the second script of its command): in tcsh's spec (gen.py:1583-1585), temporarily change `+ DYN_INPUTS` to `+ DYN_INPUTS[1:]` and run `python3 tools/ninja/gen.py`. Expected: `SystemExit` naming `tcsh (fgx_dyn.py): toolchain/src/ld/fgx_dyn.py`. Restore the line and run gen.py again: silent. Before this task the same `touch` + `ninja -n` matched none of them; to confirm, run it at the task's BASE in a scratch worktree, or state that it was not run.

Then `ninja all` once more so the tree is clean: `ninja all >/dev/null && ninja -n all | head -1` prints `ninja: no work to do.`

- [ ] **Step 5: Commit**

```bash
git add tools/ninja/gen.py
git commit -m "build(ninja): static and dynamic SHELLS entries depend on their linker's inputs" \
  -m "Sixteen SHELLS entries linked by fgx_static or fgx_dyn listed their linker's files by hand and missed some: fgx_pack.py, libllong and d_stub.s for all sixteen, and fgx_libso.py, libc_so_helpers.s and libutil.so for the dynamic twelve, so an edit to any of them left those binaries stale.  They take STATIC_INPUTS or DYN_INPUTS now, and gen.py refuses to write the graph when an entry whose build script runs a linker misses any of that linker's inputs."
```

---

### Task 6: stack_reach reads the `.ld` directories; the gate, the sweep and the oracle

**Files:**
- Modify: `tools/stack_reach.py` (`sources()`, :83-117; `self_test()`)
- Modify: `docs/history/plans/2026-10-04-shared-libc-sp5-design.md` (section 7's Toolchain bullet, section 8 item 4)
- Modify: `docs/ROADMAP.md` (the SP5 paragraph at :2735)

**Interfaces:**
- Consumes: the `.ld` directories fgx_static/fgx_dyn write (`tools/<name>-fgx2/static.ld/`, `dyn.ld/`).
- Produces: nothing later tasks use.

- [ ] **Step 1: Write the failing self-test case**

Read `self_test()` in `tools/stack_reach.py`, then add a case in its style that builds, in a temp dir standing in for `tools/<name>-fgx2/`:
- `static.ld/seg0.link.s` with `PUT  ../prog.s` and `PUT  seg1_layout.s` and `PUT  bank0.s`;
- `static.ld/bank0.link.s` with `PUT  bank0.s`;
- `prog.s`, `static.ld/bank0.s` and `static.ld/seg1_layout.s` (any content);

and asserts `sources()` (called with the temp dir; give `sources` an optional `bdir` parameter defaulting to today's `tools/<program>-fgx2`) returns exactly `prog.s` and `static.ld/bank0.s` as real paths, once each.

Run: `python3 tools/stack_reach.py --self-test`
Expected: FAIL on the new case (today `sources()` globs only `bdir/seg*.link.s`, finds none, and falls back to `bdir/*.s`, which returns `prog.s` alone).

- [ ] **Step 2: Read every link file**

```python
def sources(program, bdir=None):
    """Every .s the binary actually LINKS, from the link files its build
    wrote: <bdir>/seg*.link.s, and seg*.link.s and bank*.link.s in each
    <bdir>/*.ld/ (fgx_static's and fgx_dyn's).  A PUT resolves against its
    own link file's directory.  (The docstring's paragraph on why a glob of
    the build dir is not enough stays as it is.)
    """
    bdir = bdir or os.path.join(ROOT, "tools", "%s-fgx2" % program)
    links = glob.glob(os.path.join(bdir, "seg*.link.s"))
    for ld in glob.glob(os.path.join(bdir, "*.ld")):
        links += glob.glob(os.path.join(ld, "seg*.link.s"))
        links += glob.glob(os.path.join(ld, "bank*.link.s"))
    out, seen = [], set()
    for link in sorted(links):
        here = os.path.dirname(link)
        for put in PUT_RE.findall(open(link, errors="replace").read()):
            if not put.endswith(".s") or put.endswith(".data.s"):
                continue
            path = os.path.realpath(os.path.join(here, put))
            if path in seen or not os.path.exists(path):
                continue
            if os.path.basename(path) in SKIP:
                continue
            seen.add(path)
            out.append(path)
    if not out:                      # no link recipe (fixture dirs): old glob
        out = [f for f in glob.glob(os.path.join(bdir, "*.s"))
               if not f.endswith(".link.s") and not f.endswith(".data.s")]
    return out
```

with, above it:

```python
# Layout and macro scaffolding carries no frames; skipped so `functions`
# stays a count of real code.
SKIP = {"macros.s", "dataseg_layout.s", "seg1_layout.s", "imports_layout.s"}
```

Keep the docstring's existing explanation of why the link recipe is read (the libc-pile mint count); it is still the reason.

Run: `python3 tools/stack_reach.py --self-test`
Expected: passes.

- [ ] **Step 3: The real table**

Run: `python3 tools/stack_reach.py`
Expected: a row for each of sh, tcsh, tar, grep and ls, none of them "no built assembly". sh and tar read `static.ld` (their libc banks included); tcsh, grep and ls read `dyn.ld`, whose link files PUT the program's TUs and runtimes -- libc for them is libc.so, outside the binary. `dyn.ld/shift/` holds a second link set (fgx_dyn's relocation pass) that the `*.ld/seg*.link.s` glob does not reach, deliberately: its files duplicate the first set's. Record the table in the commit body.

- [ ] **Step 4: Commit**

```bash
git add tools/stack_reach.py
git commit -m "fix(stack_reach): read the link files fgx_static and fgx_dyn write" \
  -m "stack_reach found a binary's sources through <build dir>/seg*.link.s, which no static or dynamic link writes, and fell back to the build dir's own .s files: for a static program the libc banks it links were left out of the &local and window counts.  It now reads seg*.link.s and bank*.link.s in each .ld directory as well, resolving PUTs against the link file's own directory.  <table>"
```

- [ ] **Step 5: The spec and ROADMAP**

Spec section 7, Toolchain bullet: "nine `_seg1.link.s`" is wrong -- there were 42, one per M-dir; correct it. After the crt0_far sentence add "Step 4 moved them (the fixture link is `toolchain/tests/fixture_link.py`); the goldens are fcc's output and did not move -- a REGEN run over the new link rewrote none." Section 8 item 4 gets "(done: plan `2026-10-05-shared-libc-sp5-step4-plan.md`)".

ROADMAP :2735: step 4 done, next is step 5. One sentence each; keep the paragraph's existing shape.

```bash
git add docs/history/plans/2026-10-04-shared-libc-sp5-design.md docs/ROADMAP.md
git commit -m "docs(sp5): step 4 done -- the fixtures link with fgx_static"
```

- [ ] **Step 6: The gate, with the fixture and runtime stages forced**

The fixture stage and the sweep/oracle stage are keyed on a source hash (Review Focus 4). This plan's changes move it, but delete both stamps so both stages run without depending on that:

```bash
rm -f .gate/fcc-fixtures.stamp .gate/fcc-runtime.stamp
```

Announce: "Running the gate on the main checkout (feat/shared-libc); it rebuilds the tree and boots MAME headlessly."

Run: `tools/gate.sh > /tmp/fgx_step4_gate.log 2>&1; tail -30 /tmp/fgx_step4_gate.log`
Expected, all read from the log:
- `fixtures` stage: `710 passed, 0 failed`;
- `test_fixture_link.py` and `test_shells.py` silent in the checker block;
- `multibank sweep`: `==> PASS` (exit 43, the driver's green, `driver.c:142`);
- `runtime fixture oracle`: an `oracle-validated pass` line. If change-scoping selected a subset, the gate prints its NOTE; then also run Step 7.
- the final verdict green, with the MAME test count as at HEAD 15ca1c43b (45/45).

If the gate stops at a red stage, read which stage (it stops at the first red one) before acting.

- [ ] **Step 7: The whole oracle**

Review Focus 5 needs every fixture executed, not the scoped sample. Run: `python3 toolchain/tests/run_runtime.py --all > /tmp/fgx_step4_oracle.log 2>&1; grep -E 'oracle-validated pass|NOTE|wrong-exit|crash|no-marker' /tmp/fgx_step4_oracle.log | head -20`

`--all` bypasses the 240-fixture selection cap (`run_runtime.py:999-1003`); the limit it can still meet is the 32 MB volume. The 709 images measured 7.7 MB in this plan's spike, so it should fit. If the disk build overflows anyway, split the run with `--names` into lists of at most 240, one per run, until every fixture in `oracle.json` has a verdict.
Expected: every fixture passes against `oracle.json`. A failure is investigated (systematic-debugging) before anything else: the likeliest cause is a crt0_lib/crt0_far difference in what is seeded at entry (`_fcc_sfp`, `_fcc_dbr`, the signal trampoline, `environ`), and the fix belongs in `crt0_lib.s`/`libc_start.s` (65816: the main agent's), never in the fixture.

- [ ] **Step 8: Put the tree back**

The oracle stages under `disk_src/tests/`. Run: `rm -rf disk_src/tests && ninja all >/dev/null && ninja -n all | head -1 && git status --short | head`
Expected: `ninja: no work to do.`; `git status` shows only the untracked `docs/history/wip-2026-09-28-cache/` that predates the plan.
