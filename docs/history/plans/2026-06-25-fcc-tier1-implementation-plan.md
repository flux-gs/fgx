# fcc Tier 1 + Benchmarking — Implementation Plan (rev. 2 — post adversarial review)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a benchmarking harness that *actually executes fcc binaries*, then land Tier 1 codegen wins (peephole REP/SEP + INA folds; inline constant shift/pow2-mul/divmod) — each change measured against a committed baseline and gated by a real correctness oracle.

**Architecture:** Phase 0 builds `toolchain/bench/fbench.py` reusing `toolchain/tests/metrics.sh` size logic plus a **headerless bare-metal MAME cycle harness** (a port of `examples/65816-llvm-mos/scripts/runInMameCycles.sh`, corrected for fcc's link model). Phase 1 extends the textual peephole (`toolchain/src/cc/peephole.c`), TDD'd via the host harness `tests/peephole/test_peephole.c`. Phase 2 adds constant-aware lowering in `toolchain/src/cc/parse_expr.c`, enabled by a non-destructive `peek_tok()` in `toolchain/src/cc/lex_pp.c`. **Correctness is gated by `run_runtime.py` (exit-code/oracle), never by the cycle harness; size by goldens; cycles are advisory.**

**Tech Stack:** C (fcc), Python 3, bash, Merlin32, MAME apple2gs (headless) + MAME Lua.

**Spec:** `docs/history/plans/2026-06-25-fcc-tier1-and-benchmarking-design.md` (rev. 2). **Audit:** `docs/history/audits/2026-06-25-fcc-tier1-plan-review.md` (the 66-finding review this revision applies).

## What rev. 2 fixes (from the adversarial review)

This plan was rewritten after a multi-agent review found the v1 measurement/test wiring did not work. The blocking corrections, all applied below:

- **Two distinct harnesses, never conflated.** (1) *Cycle* harness = a **headerless** bench binary (`_wrap_bench.s`, `ORG $001000`, no FGX1 header) loaded raw into MAME at `$1000`, START/DONE markers **emitted in assembly** (fcc cannot store to an arbitrary far bank from C). (2) *Correctness* harness = `run_runtime.py`, which builds the normal **FGX1** golden, boots the real kernel, and compares the program's **exit code** to `oracle.json`. The v1 plan tried to PC=$1000 a header-prefixed `ORG $0B0000` binary and to verify correctness by reading `$025000` under `run_runtime.py` — both wrong.
- **A real miscompile fixed before it ships:** the constant div/mod fallback must keep the dividend in A (`LDX #k; STX _fcc_tmp_b`), not `STA _fcc_tmp_b; LDA #k` (which computes `k/x`).
- **Peephole width safety:** `PHP`/`PLP` are **not** M-neutral; the extended REP/SEP pass only applies to `#$20` toggles.
- **Coverage:** the ported corpus does not exercise T1.2; int/unsigned-int micro-benches are added so the constant-shift/mul wins are measurable.
- **Release gate:** peephole runs on *every* C userland binary, so a userland rebuild + `run_runtime.py` behavior gate is mandatory before release.

## Global Constraints

- **Branch:** `feat/fcc-tier1-benchmarking` (`main` tagged `pre-fcc-tier1-benchmarking`). Never commit to `main`.
- **Two-harness rule:** `run.sh` verifies **bytes** (goldens). `run_runtime.py` verifies **behavior** (exit code vs `oracle.json`). `fbench` cycle numbers are **advisory** and never gate. Never use the cycle harness to check correctness, and never use `run.sh`/`run_runtime.py` to measure speed.
- **Toolchain discipline:** ship via the toolchain release flow — goldens green (`bash toolchain/tests/run.sh`), `run_runtime.py` green, then `toolchain/release.sh`, then re-pin FGX. Land via merge→main + `release.sh`, never push a feature branch.
- **Codegen-change release gate (mandatory):** because `peephole_optimize` is unconditional (`main.c:415`) and the Phase-2 changes alter `emit_*`, any merge that changes codegen MUST, before release: (1) `run_runtime.py` full sweep green; (2) rebuild ALL C userland (`build_userbin_fgx2_c`) and run their headless behavior manifests green. Do not rely on the fast 3-manifest group.
- **Fix the toolchain, don't work around it** — lexer/parser gaps get fixed in fcc (e.g. `peek_tok()`, moving shared helpers to `globals.c`).
- **Clean-room:** adopt algorithms from `examples/65816-llvm-mos` (Apache-2.0); never paste its C++.
- **Test fixtures use the FGX1 wrappers** (`_wrap.s`/`_wrap_libc.s`) because the goldens/runtime harnesses are FGX1; the FGX2-default policy governs *shipped* binaries, not compiler test fixtures. The codegen under test is link-model-independent.
- **Stage specific files** per commit (no `git add -A`).
- **Commit trailer** (every commit):
  ```
  ```
- **fcc build:** `make -C toolchain` → `toolchain/fcc`. **Peephole unit test:** `make -C toolchain test-peephole`. **Lexer unit test:** `make -C toolchain test-lex`. **Goldens:** `bash toolchain/tests/run.sh`; regen `bash toolchain/tests/regen_goldens.sh`. **Runtime oracle:** `python3 toolchain/tests/run_runtime.py` (run from the FGX root; needs kernel+disk+MAME).
- **Plans/specs/audits live in `docs/history/`** (tracked); `docs/superpowers/` is gitignored.

---

## Phase 0 — Benchmark harness (T1.0)

Builds two things: a size/system snapshotter and a **working** cycle harness, then captures the pre-change baseline. **If the cycle harness cannot run on a given machine (no MAME), the baseline is valid as size-only** — cycles are advisory.

> **EXECUTED 2026-06-25 (subagent-driven).** Phase 0 landed (toolchain submodule
> `8c2a120..917ccdc`). MAME = the **Ample fork** (`mame64`, resolved via
> `lib/mame_env.sh`: `$MAME`/app-bundle/PATH + `$FGX_MAME_SUPPORT`); `cycles.py`
> uses `-rompath SUPPORT/roms -pluginspath SUPPORT/plugins`. Verified on Ample MAME
> **v0.287**: `emu.time()`, `install_write_tap`, `mem:write_u8` all work;
> `cpu:total_cycles()` does NOT (so the cycle metric stays `emu.time()×clock_hz`).
> **Live baseline cycles:** `t12_shift` = 259 cyc/call, `t12_mul` = 635 cyc/call
> (current libcall codegen — the pre-Tier-1 anchors).
>
> The headerless "Option A" env only runs the 2 simplest benches (shift, mul);
> the other 11 (incl. `t12_divmod`, references using div/mod, pointers, static
> data, recursion) BUILD clean but **hang bare-metal**. → **Option B built (see
> below).**
>
> **★ OPTION B LANDED 2026-06-26 — full-corpus cycle timing under the REAL kernel**
> (toolchain submodule `..0416465`, superproject pin `1000f8e`). Benches now carry
> C-callable markers (`fbench_start()`/`fbench_done()` → `corpus/fbench_markers.s`,
> `STAL` bank 2; same `.c` builds Option A + B). `corpus/_wrap_fbench.s` is the FGX1
> wrapper; `toolchain/bench/fbench_kernel.py` builds each bench FGX1, `cadius
> ADDFILE`s them onto a disk copy, and runs each through `tools/mame_test/run.py`.
> The `fgxdebug` plugin gained an opt-in `cycle_markers` write-tap feature
> (`install_write_tap` on $025000/$025002, capture `emu.time()`); `run.py` forwards
> a manifest `cycle_markers` field. **12/13 benches measure** (only `bubbleSort`
> reseed-variant times out — follow-up). Baseline:
> `baselines/toolchain-v0.13.0-pre-tier1.kernel.json`.
>
> **Option B metric = `us_per_call`** (emulated µs of the hot loop): the kernel runs
> fast mode (~2.2 MHz effective, IIgs memory slowdowns) and this MAME build has no
> CPU cycle counter, so absolute cycles are approximate and NOT comparable to the
> 1.023 MHz reference — the **baseline-vs-current delta** is authoritative.
> Anchors: `t12_shift` 116, `t12_mul` 246, `t12_divmod` 676 µs/call. Option A
> (clean 1.023 MHz cycles) remains for shift/mul-class benches.

### Task 0.1: Harness skeleton + headerless bench wrapper + README

**Files:**
- Create: `toolchain/bench/_wrap_bench.s` (the bare-metal cycle wrapper — no FGX1 header)
- Create: `toolchain/bench/README.md`
- Create: `toolchain/bench/baselines/.gitkeep`
- Modify: `.gitignore` (add `toolchain/bench/reports/`)

**Interfaces:**
- Produces: `_wrap_bench.s` — `ORG $001000`, first emitted byte is `crt0_bench` (entry at offset 0, so PC=$1000 is correct), which sets native mode + 16-bit + a high stack, writes the START marker, `JSR main`, writes the DONE marker, then spins. Markers are absolute-long stores ($025000/$025002) so they are DBR-independent. The cycle harness (Task 0.3) reads them. **The C corpus contains no marker code** (fcc can't store to bank 2 from an integer-constant pointer).

- [ ] **Step 1: Write the bare-metal bench wrapper**

```
;==============================================================================
; _wrap_bench.s — headerless bare-metal wrapper for fbench CYCLE benchmarks.
; NO FGX1 header: file offset 0 == first instruction, so the harness loads the
; raw image at $001000 and sets PC=$1000 with no header to skip. ORG $001000 so
; every 2-byte JSR / DBR-relative data ref resolves at the load address. Markers
; are written in ASM (absolute-long, DBR-independent) around JSR main, because
; fcc cannot emit a store to an arbitrary far bank from C.
;==============================================================================
                MX      %11             ; emulation start: A+index 8-bit
                ORG     $001000

crt0_bench      EQU     *
                CLC
                XCE                     ; native mode
                REP     #$30            ; 16-bit A + index (runtime)
                MX      %00             ; REQUIRED: tell Merlin32 both regs are
                                        ; 16-bit now, else LDX/LDA #imm assemble
                                        ; 1-byte and the 16-bit CPU mis-reads them
                LDX     #$0FFF          ; ample bank-0 stack (recursive benches)
                TXS
                LDA     #$A1A1          ; START marker
                STAL    $025000
                JSR     main            ; run the benchmark hot loop
                REP     #$30            ; re-assert 16-bit before the DONE marker
                LDA     #$A2A2          ; DONE marker
                STAL    $025002
done_spin       BRA     done_spin

                PUT     fcc_output.s
                PUT     ../../lib/fcc_runtime.s
                PUT     ../../lib/fcc_runtime_data.s
```
> Corpus benchmarks are written self-contained (define their own helpers); if any needs libc string fns, add `PUT ../../lib/libc*.s` here and note it. `main` is the fcc-compiled benchmark entry; its result is discarded (cycles, not correctness, are what this wrapper measures).

- [ ] **Step 2: Write the README (two-harness model + how-to)**

```markdown
# fbench — fcc benchmarking harness

Tracks four metrics across codegen changes: object/binary size, kernel size,
direct-page usage, execution cycles. ADVISORY — it does not gate the build.

## Two harnesses — do not confuse them
- CORRECTNESS is gated by `toolchain/tests/run_runtime.py` (exit code vs oracle.json)
  and `run.sh` (golden bytes). fbench never checks correctness.
- SPEED is measured here. Cycle benches are HEADERLESS bare-metal binaries
  (_wrap_bench.s, ORG $1000) loaded raw into MAME at $1000; markers are emitted
  in asm by the wrapper around `JSR main`. This is "Option A". The real-kernel
  FGX1 path (run_runtime.py) is "Option B", reserved for libc/kernel-dependent
  benches; not used for cycle timing.

## Run
    python3 toolchain/bench/fbench.py snapshot <tag>      # -> baselines/<tag>.json
    python3 toolchain/bench/fbench.py compare <base.json> # vs current tree (size+cyc+dp+system)
    python3 toolchain/bench/fbench.py report              # unified scoreboard

## Add a cycle benchmark
1. corpus/<name>.c: a self-contained `int main(void){ ... hot loop x ITERS ... }`.
   No markers in C — the wrapper emits them. Use ITERS>=2000 (see cycle resolution).
2. corpus/<name>.link.s: `TYP $06 / DSK <name> / ORG $001000 / ASM _wrap_bench.s`.
3. Optional reference cyc in corpus/refs.json (labeled indicative-only).
4. `python3 toolchain/bench/fbench.py report`; confirm it builds + runs.

## Update the baseline
After a codegen change lands and goldens + run_runtime are green:
    python3 toolchain/bench/fbench.py snapshot toolchain-<tag>
    git add toolchain/bench/baselines/toolchain-<tag>.json
```

- [ ] **Step 3: Baseline keeper + gitignore**

Run:
```bash
mkdir -p toolchain/bench/baselines toolchain/bench/reports
: > toolchain/bench/baselines/.gitkeep
printf '\n# fbench generated reports\ntoolchain/bench/reports/\n' >> .gitignore
```

- [ ] **Step 4: Commit**

```bash
git add toolchain/bench/_wrap_bench.s toolchain/bench/README.md \
        toolchain/bench/baselines/.gitkeep .gitignore
git commit  # trailer
```

---

### Task 0.2: `fbench.py` — size + system + snapshot/compare (all four deltas)

**Files:**
- Create: `toolchain/bench/fbench.py`, `toolchain/bench/test_fbench.py`
- Reference: `toolchain/tests/metrics.sh` (size logic), `build.sh:58` (`kernel_bytes`)

**Interfaces:**
- Produces: CLI `snapshot <tag>` / `compare <base.json>` / `report`; snapshot JSON:
  ```json
  {"tag":"...","toolchain_git":"<submodule sha>","fgx_git":"<superproj sha>",
   "size":{"goldens":{"total_bytes":N,"total_asm_lines":N,"per_fixture":{...}}},
   "system":{"kernel_bytes":N,"fcc_userland_bytes":N},
   "dp":{"fcc_bytes":0,"reservations":[...],"overlaps":[]},
   "cycles":{"<name>":{"cyc_per_call":F|null,"calypsi":F,"llvm_mos":F}}}
  ```
- `compare()` reports deltas for **size, cycles, dp, AND system** (not size-only).

- [ ] **Step 1: Failing test (size snapshot + makedirs + compare covers cycles)**

`toolchain/bench/test_fbench.py`:
```python
import json, subprocess, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
def run(*a): return subprocess.run([sys.executable, os.path.join(HERE,"fbench.py"),*a],
                                    capture_output=True, text=True)
def test_snapshot_size_and_provenance(tmp_path):
    out = tmp_path/"snap.json"
    r = run("snapshot","t","--out",str(out)); assert r.returncode==0, r.stderr
    d = json.loads(out.read_text())
    assert d["size"]["goldens"]["total_bytes"] > 0
    assert "kernel_bytes" in d["system"]
    assert "toolchain_git" in d        # provenance is the toolchain submodule, not fgx
def test_report_makedirs_on_fresh_tree(tmp_path):
    # report must not crash when reports/ is absent
    r = run("report"); assert r.returncode == 0, r.stderr
```

- [ ] **Step 2: Run, verify fail**

Run: `python3 -m pytest toolchain/bench/test_fbench.py -q`
Expected: FAIL (`fbench.py` missing).

- [ ] **Step 3: Implement `fbench.py`**

```python
#!/usr/bin/env python3
"""fbench — fcc benchmarking harness (size/system/dp now; cycles via cycles.py)."""
import argparse, json, os, subprocess, sys, glob, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TC   = os.path.join(ROOT, "toolchain")
# fcc-built userland binaries we attribute to codegen (explicit, deterministic).
FCC_USERLAND = ["sed", "ed", "grep", "tr", "od", "more", "man"]   # extend as ported

def _git_sha(path):
    try:
        return subprocess.check_output(["git", "-C", path, "rev-parse", "HEAD"],
                                       text=True).strip()
    except Exception:
        return "unknown"

def _git_dirty(path):
    try:
        return bool(subprocess.check_output(["git","-C",path,"status","--porcelain"],
                                            text=True).strip())
    except Exception:
        return False

def collect_size():
    per, tb, tl = {}, 0, 0
    for b in sorted(glob.glob(os.path.join(TC, "tests", "M*", "*.expected.bin"))):
        rel = os.path.relpath(b, ROOT); nb = os.path.getsize(b)
        s = b[:-len(".expected.bin")] + ".expected.s"; nl = 0
        if os.path.exists(s):
            with open(s, errors="replace") as f:
                nl = sum(1 for ln in f if ln.strip() and not ln.lstrip().startswith((";","*")))
        per[rel] = {"bytes": nb, "lines": nl}; tb += nb; tl += nl
    return {"goldens": {"total_bytes": tb, "total_asm_lines": tl, "per_fixture": per}}

def collect_system():
    kb = os.path.getsize(os.path.join(ROOT,"bin","fgx.bin")) if \
         os.path.exists(os.path.join(ROOT,"bin","fgx.bin")) else 0
    # fcc-built userland only: explicit list, not a wildcard over disk_src (which
    # is regenerated per build and contains hand-asm tools/fonts/manpages).
    ub = 0
    for tool in FCC_USERLAND:
        for cand in (os.path.join(ROOT,"bin",tool+".bin"), os.path.join(ROOT,"bin",tool)):
            if os.path.exists(cand): ub += os.path.getsize(cand); break
    return {"kernel_bytes": kb, "fcc_userland_bytes": ub}

def _snap(tag):
    import cycles_collect, dp_collect
    return {"tag": tag,
            "toolchain_git": _git_sha(TC) + ("-dirty" if _git_dirty(TC) else ""),
            "fgx_git": _git_sha(ROOT),
            "size": collect_size(), "system": collect_system(),
            "dp": dp_collect.collect_dp(), "cycles": cycles_collect.collect_cycles()}

def snapshot(tag, out):
    snap = _snap(tag)
    d = os.path.dirname(out)
    if d: os.makedirs(d, exist_ok=True)            # fresh-tree safe
    with open(out, "w") as f: json.dump(snap, f, indent=2)
    g = snap["size"]["goldens"]
    print(f"snapshot '{tag}': {len(g['per_fixture'])} fixtures, {g['total_bytes']} bytes, "
          f"{g['total_asm_lines']} asm lines, {len(snap['cycles'])} benches -> {out}")
    return snap

def _pct(d, b): return (d*100.0/b) if b else 0.0

def compare(base_path):
    with open(base_path) as f: base = json.load(f)
    cur = _snap("current")
    # SIZE
    bg, cg = base["size"]["goldens"], cur["size"]["goldens"]
    db = cg["total_bytes"]-bg["total_bytes"]; dl = cg["total_asm_lines"]-bg["total_asm_lines"]
    print(f"size bytes: {bg['total_bytes']} -> {cg['total_bytes']} ({db:+d}, {_pct(db,bg['total_bytes']):+.2f}%)")
    print(f"asm lines:  {bg['total_asm_lines']} -> {cg['total_asm_lines']} ({dl:+d}, {_pct(dl,bg['total_asm_lines']):+.2f}%)")
    # SYSTEM
    for k in ("kernel_bytes","fcc_userland_bytes"):
        ob,nb = base["system"].get(k,0), cur["system"].get(k,0)
        print(f"{k}: {ob} -> {nb} ({nb-ob:+d}, {_pct(nb-ob,ob):+.2f}%)")
    # DP
    print(f"dp fcc_bytes: {base['dp']['fcc_bytes']} -> {cur['dp']['fcc_bytes']}  "
          f"overlaps: {len(cur['dp']['overlaps'])}")
    # CYCLES (headline)
    print("cycles (cyc/call):")
    for n in sorted(set(base["cycles"]) | set(cur["cycles"])):
        ob = base["cycles"].get(n,{}).get("cyc_per_call")
        nb = cur["cycles"].get(n,{}).get("cyc_per_call")
        if ob is None or nb is None:
            print(f"  {n}: {ob} -> {nb} (incomplete)"); continue
        print(f"  {n}: {ob:.0f} -> {nb:.0f} ({nb-ob:+.0f}, {_pct(nb-ob,ob):+.2f}%)")

def main():
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("snapshot"); s.add_argument("tag"); s.add_argument("--out")
    c = sub.add_parser("compare"); c.add_argument("base")
    sub.add_parser("report")
    a = ap.parse_args()
    if a.cmd == "snapshot":
        snapshot(a.tag, a.out or os.path.join(os.path.dirname(__file__),"baselines",a.tag+".json"))
    elif a.cmd == "compare":
        compare(a.base)
    elif a.cmd == "report":
        snap = snapshot("report", os.path.join(os.path.dirname(__file__),"reports","latest.json"))
        import scoreboard; scoreboard.print_scoreboard(snap)

if __name__ == "__main__":
    main()
```
> `cycles_collect`, `dp_collect`, `scoreboard` are implemented in Tasks 0.3/0.5/0.6. To keep this task's test green before those exist, create 1-line stub modules `cycles_collect.py` (`def collect_cycles(): return {}`), `dp_collect.py` (`def collect_dp(): return {"fcc_bytes":0,"reservations":[],"overlaps":[]}`), and `scoreboard.py` (`def print_scoreboard(s): pass`) now; later tasks replace them.

- [ ] **Step 4: Run, verify pass**

Run: `python3 -m pytest toolchain/bench/test_fbench.py -q`
Expected: PASS (goldens must exist; if not, `bash toolchain/tests/regen_goldens.sh` first).

- [ ] **Step 5: Commit**

```bash
git add toolchain/bench/fbench.py toolchain/bench/test_fbench.py \
        toolchain/bench/cycles_collect.py toolchain/bench/dp_collect.py toolchain/bench/scoreboard.py
git commit  # trailer
```

---

### Task 0.3: Cycle harness — headerless load + instruction-precise marker taps

**Files:**
- Create: `toolchain/bench/cycles.py`
- Modify: `toolchain/bench/cycles_collect.py` (build corpus, run, record)
- Reference: `examples/65816-llvm-mos/scripts/runInMameCycles.sh`, `tools/mame/roms`

**Interfaces:**
- Produces: `cycles.run_binary(bin_path, clock_hz=1023000) -> float|None` = total cycles between START and DONE (per-call division happens in cycles_collect using each bench's ITERS). Uses **memory write-taps**, not frame polling, so the result is not quantized to ~17050-cyc frames.

- [ ] **Step 1: Failing test (parse)**

Append to `test_fbench.py`:
```python
import importlib.util
def _load(m,p):
    s=importlib.util.spec_from_file_location(m,os.path.join(HERE,p)); mod=importlib.util.module_from_spec(s); s.loader.exec_module(mod); return mod
def test_parse_total_cyc():
    cyc=_load("cycles","cycles.py")
    assert abs(cyc.parse_total_cyc("MAME-CYC total_cyc=2046.0")-2046.0) < 1e-6
```

- [ ] **Step 2: Run, verify fail** — `python3 -m pytest toolchain/bench/test_fbench.py -k total_cyc -q` → FAIL.

- [ ] **Step 3: Implement `cycles.py` (write-taps, S handled by wrapper)**

```python
#!/usr/bin/env python3
"""fbench cycle measurement — emu.time() captured at the exact marker WRITES
(install_write_tap), avoiding the ~60Hz frame-boundary quantization that makes
small Tier-1 deltas invisible."""
import os, re, subprocess, tempfile
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROMS = os.path.join(ROOT, "tools", "mame", "roms")

_LUA = r'''
local loaded, frame, t0, t1 = false, 0, nil, nil
local mem
emu.register_frame_done(function()
  frame = frame + 1
  if loaded then return end
  if frame < 30 then return end
  local cpu = manager.machine.devices[":maincpu"]
  mem = cpu.spaces["program"]
  local f=io.open("%(BIN)s","rb"); if not f then print("BIN-MISSING"); manager.machine:exit(); return end
  local d=f:read("*all"); f:close()
  for i=1,#d do local a=0x001000+i-1
    if not (a>=0x00C000 and a<0x00D000) then mem:write_u8(a, d:byte(i)) end end
  -- Instruction-precise taps on the marker addresses (bank 2).
  mem:install_write_tap(0x025000, 0x025001, "fbstart", function(off,data,mask)
    if not t0 then t0 = emu.time() end end)
  mem:install_write_tap(0x025002, 0x025003, "fbdone", function(off,data,mask)
    if t0 and not t1 then t1 = emu.time()
      print(string.format("MAME-CYC total_cyc=%%.1f", (t1-t0)*%(HZ)d))
      manager.machine:exit() end end)
  loaded = true
  cpu.state["PC"].value=0x1000; cpu.state["PB"].value=0; cpu.state["DB"].value=0
  cpu.state["D"].value=0; cpu.state["E"].value=0    -- S/native set by crt0_bench
  print("MAME-LOADED bytes="..#d)
end)
'''

def parse_total_cyc(text):
    m = re.search(r"total_cyc=([0-9.]+)", text)
    return float(m.group(1)) if m else None

def run_binary(bin_path, clock_hz=1023000, secs=30, timeout=90):
    lua = _LUA % {"BIN": bin_path, "HZ": clock_hz}
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as f:
        f.write(lua); lp=f.name
    env = dict(os.environ, SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
    try:
        cp = subprocess.run(["mame","apple2gs","-rompath",ROMS,"-plugins",
                             "-autoboot_script",lp,"-video","none","-sound","none",
                             "-nothrottle","-seconds_to_run",str(secs)],
                            capture_output=True, text=True, env=env, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None
    finally:
        os.unlink(lp)
    return parse_total_cyc(cp.stdout + cp.stderr)
```
> If `install_write_tap` is unavailable in the pinned MAME build, fall back to frame-poll **but** set ITERS≥2000 in every bench and have cycles_collect refuse-and-warn when total_cyc < 34100 (two frames) so quantization can never masquerade as signal. Note this in the README.

- [ ] **Step 4: Run, verify pass** — `python3 -m pytest toolchain/bench/test_fbench.py -k total_cyc -q` → PASS.

- [ ] **Step 5: Commit** — `git add toolchain/bench/cycles.py toolchain/bench/test_fbench.py` ; commit (trailer).

---

### Task 0.4: Corpus — port reference benches + add T1.2 micro-benches

**Files:**
- Create: `toolchain/bench/corpus/<name>.c` + `<name>.link.s`; `toolchain/bench/corpus/refs.json`
- Modify: `toolchain/bench/cycles_collect.py`

**Interfaces:**
- Consumes: `_wrap_bench.s` (0.1), `cycles.run_binary` (0.3).
- Produces: `collect_cycles() -> {name:{cyc_per_call,calypsi,llvm_mos}}`; **logs every skip with a reason** (no silent truncation); `cyc_per_call = total_cyc / ITERS[name]`.

- [ ] **Step 1: Port one reference bench, self-contained (`strLen`)**

`toolchain/bench/corpus/strLen.c`:
```c
/* ITERS=2000 */
static const char *s = "the quick brown fox jumps over the lazy dog";
static unsigned slen(const char *p){ unsigned n=0; while(*p++) n++; return n; }
int main(void){ unsigned acc=0; int i; for(i=0;i<2000;i++) acc+=slen(s); return (int)acc; }
```
`toolchain/bench/corpus/strLen.link.s`:
```
                TYP     $06
                DSK     strLen
                ORG     $001000
                ASM     _wrap_bench.s
```

- [ ] **Step 2: Port the rest of the integer reference benches (same recipe, self-contained)**

For `bsearch, sumOfSquares, strcpy, popcount, dotProduct, djb2Hash, memcmp, bubbleSort, fib`: copy the body from `examples/65816-llvm-mos/benchmarks/<name>.c` **verbatim** (keep inputs matching their `benchInputs()` so the indicative ref columns line up), make `main` run the hot loop ITERS=2000 and `return` a result, add `<name>.link.s`. Defer float/double benches (`dadd,ddiv,dmul,mandelbrot,particles`) — they will be logged as SKIP until fcc float coverage is confirmed. **If a bench cannot compile under fcc, STOP and scope it** (do not silently drop — log it).

- [ ] **Step 3: Add T1.2-exercising micro-benches (NEW — the reference corpus does not hit T1.2)**

The ported corpus exercises T1.1 (REP/SEP, INA via `i++`) but **not** T1.2 (constant shift/mul/divmod on *int/unsigned int*). Add these so the T1.2 wins are measurable:
```c
/* corpus/t12_shift.c   ITERS=2000 */
int main(void){ unsigned a=0; unsigned x; int i;
  for(i=0;i<2000;i++){ x=(unsigned)i; a += (x<<3) + (x>>3); } return (int)a; }
/* corpus/t12_mul.c     ITERS=2000 */
int main(void){ unsigned a=0; unsigned x; int i;
  for(i=0;i<2000;i++){ x=(unsigned)i; a += x*8; } return (int)a; }
/* corpus/t12_divmod.c  ITERS=2000 */
int main(void){ unsigned a=0; unsigned x; int i;
  for(i=0;i<2000;i++){ x=(unsigned)i; a += (x/8) + (x%8); } return (int)a; }
```
Add `.link.s` for each. (Use unsigned int — NOT long — because T1.2 inlines int only and div/mod unsigned only.)

- [ ] **Step 4: refs.json (indicative-only) from the README headline table**

`toolchain/bench/corpus/refs.json` (cite: `examples/65816-llvm-mos/README.md` Status table; columns "Ours"=llvm_mos, "Calypsi"=calypsi):
```json
{"_note":"reference harness numbers — INDICATIVE ONLY, not a controlled comparison (different ORG/ITERS/inputs/calling-convention; both frame-quantized). Authoritative metric is fcc baseline-vs-current delta.",
 "dotProduct":{"calypsi":5712,"llvm_mos":1534},"bsearch":{"calypsi":2387,"llvm_mos":682},
 "sumOfSquares":{"calypsi":16368,"llvm_mos":6820},"bubbleSort":{"calypsi":17050,"llvm_mos":11594},
 "strLen":{"calypsi":1023,"llvm_mos":767},"djb2Hash":{"calypsi":2643,"llvm_mos":2046},
 "popcount":{"calypsi":1534,"llvm_mos":1194},"strcpy":{"calypsi":1194,"llvm_mos":1108},
 "memcmp":{"calypsi":716,"llvm_mos":682},"fib":{"calypsi":10912,"llvm_mos":11594}}
```

- [ ] **Step 5: Implement `collect_cycles()` (build, run, per-ITERS divide, log skips)**

```python
import os, re, glob, json, subprocess, shutil
import cycles
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TC   = os.path.join(ROOT, "toolchain")
CDIR = os.path.join(os.path.dirname(__file__), "corpus")

def _iters(src):
    m = re.search(r"ITERS=(\d+)", open(src).read()); return int(m.group(1)) if m else 1

def collect_cycles():
    out, skipped = {}, []
    refs = json.load(open(os.path.join(CDIR,"refs.json"))) if os.path.exists(os.path.join(CDIR,"refs.json")) else {}
    if not shutil.which("merlin32") or not shutil.which("mame"):
        print("fbench: merlin32/mame absent — cycles UNMEASURED (size-only snapshot)")
        return out
    for c in sorted(glob.glob(os.path.join(CDIR,"*.c"))):
        name = os.path.splitext(os.path.basename(c))[0]
        link = os.path.join(CDIR, name+".link.s")
        if not os.path.exists(link): skipped.append((name,"no .link.s")); continue
        if subprocess.run([os.path.join(TC,"fcc"), name+".c","-o","fcc_output.s"], cwd=CDIR).returncode:
            skipped.append((name,"fcc fail")); continue
        if subprocess.run(["merlin32", name+".link.s"], cwd=CDIR, capture_output=True).returncode:
            skipped.append((name,"merlin32 fail")); continue
        total = cycles.run_binary(os.path.join(CDIR,name))
        if total is None: skipped.append((name,"no markers / timeout")); continue
        it = _iters(c)
        out[name] = {"cyc_per_call": total/it,
                     "calypsi": refs.get(name,{}).get("calypsi"),
                     "llvm_mos": refs.get(name,{}).get("llvm_mos")}
        print(f"  bench {name}: {total/it:.1f} cyc/call (total {total:.0f}, iters {it})")
    for n,why in skipped: print(f"  SKIP {n}: {why}")
    return out
```

- [ ] **Step 6: Smoke build + cleanup**

Run: `make -C toolchain && python3 toolchain/bench/fbench.py report`
Expected: per-bench `cyc/call` lines for benches that compile + run; explicit `SKIP` lines otherwise. **Verify one marker manually first**: temporarily print in the Lua and confirm `t0`/`t1` fire (markers observed). Fix any bench fcc can't compile or leave SKIP'd.

- [ ] **Step 7: Commit** (stage sources only, not built `corpus/<name>` binaries)

```bash
git add toolchain/bench/corpus/*.c toolchain/bench/corpus/*.link.s \
        toolchain/bench/corpus/refs.json toolchain/bench/cycles_collect.py
git commit  # trailer
```

---

### Task 0.5: DP-budget manifest + per-task-page collision model

**Files:**
- Create: `toolchain/bench/dp_budget.toml`
- Modify: `toolchain/bench/dp_collect.py`
- Reference: `docs/memory-map.md`, `docs/history/plans/2026-06-24-dp-pressure-relief-design.md`, `toolchain/lib/crt0.s` + `fcc_runtime_data.s` (the USER DP page, not kernel)

**Interfaces:**
- Produces: `collect_dp() -> {"fcc_bytes":N,"reservations":[...],"overlaps":[...]}`. Scope = the **per-task user direct-page page** that fcc-compiled code shares with its own crt0/libc runtime — NOT the kernel/GS-OS pages (FGX gives each task its own bank-0 DP page distinct from the kernel's, so a fcc-vs-kernel overlap is architecturally impossible and was a v1 misconception).

- [ ] **Step 1: Seed the manifest (user DP page only)**

```toml
# toolchain/bench/dp_budget.toml — the PER-TASK USER direct-page page that
# fcc-compiled code shares with its crt0/libc runtime. The FGX kernel and GS/OS
# live in SEPARATE bank-0 DP pages (see docs/memory-map.md); they are listed
# below as informational-only and never collide with user code.
# fcc uses ZERO user DP today (locals are stack-relative, scratch is absolute).
# Tier 2/3 will claim ranges here; fbench flags any overlap within THIS page.

[[reservation]]
owner = "fcc_future_imgregs"
range = [0xC0, 0xDF]   # 16 i16 imaginary regs = $C0..$DF inclusive ($DF = IMG7 hi byte)
note  = "RESERVED for the Tier-3 imaginary-register pool (matches reference backend); unused today"

[[reservation]]
owner = "fcc_future_scratch"
range = [0xE0, 0xEF]
note  = "Tier-2/3 lowering scratch (reference $E0-$EF); unused today"

# --- informational: SEPARATE pages, never overlap user code ---
[[informational]]
owner = "fgx_kernel_dp"
note  = "kernel DP page is distinct from the user task page — see docs/memory-map.md; fill exact range when sourced"
[[informational]]
owner = "gsos_firmware_dp"
note  = "GS/OS+firmware DP — separate page"
```

- [ ] **Step 2: Implement `dp_collect.py`**

```python
import os, re
def collect_dp():
    man = os.path.join(os.path.dirname(__file__), "dp_budget.toml")
    resv, owner = [], None
    if os.path.exists(man):
        for ln in open(man):
            mo = re.search(r'owner\s*=\s*"([^"]+)"', ln)
            mr = re.search(r'range\s*=\s*\[\s*(0x[0-9a-fA-F]+)\s*,\s*(0x[0-9a-fA-F]+)', ln)
            if mo: owner = mo.group(1)
            if mr and owner and owner.startswith("fcc_"):
                resv.append({"owner":owner,"lo":int(mr.group(1),16),"hi":int(mr.group(2),16)})
    # fcc DP usage = 0 today; Tier 2/3 computes this from the user binary's DP refs.
    # Overlap check is within the user page only (reservations above).
    overlaps=[]
    for i in range(len(resv)):
        for j in range(i+1,len(resv)):
            a,b=resv[i],resv[j]
            if a["lo"]<=b["hi"] and b["lo"]<=a["hi"]: overlaps.append([a["owner"],b["owner"]])
    return {"fcc_bytes":0,"reservations":resv,"overlaps":overlaps}
```

- [ ] **Step 3: Verify** — `python3 toolchain/bench/fbench.py snapshot dptest --out /tmp/dp.json && python3 -c "import json;print(json.load(open('/tmp/dp.json'))['dp'])"`
Expected: two `fcc_*` reservations ($C0-$DF, $E0-$EF), no overlaps, fcc_bytes=0.

- [ ] **Step 4: Commit** — `git add toolchain/bench/dp_budget.toml toolchain/bench/dp_collect.py` ; commit (trailer).

---

### Task 0.6: Unified scoreboard + commit the baseline

**Files:**
- Modify: `toolchain/bench/scoreboard.py`
- Create: `toolchain/bench/baselines/toolchain-v0.16.0-pre-tier1.json`

**Interfaces:**
- Produces the comparison anchor. Baseline name is **toolchain-version + intent stamped** (not `v0.16.0.json`, which would collide with the released tag and record a feature-branch SHA).

- [ ] **Step 1: Scoreboard printer**

```python
def print_scoreboard(snap):
    print(f"# fbench — {snap['tag']} (toolchain {snap['toolchain_git'][:12]})")
    g=snap["size"]["goldens"]; s=snap["system"]
    print(f"\n## Size\n- goldens: {g['total_bytes']} bytes, {g['total_asm_lines']} asm lines")
    print(f"- kernel: {s['kernel_bytes']}  fcc-userland: {s['fcc_userland_bytes']}")
    print(f"- DP(fcc): {snap['dp']['fcc_bytes']} bytes  overlaps: {len(snap['dp']['overlaps'])}")
    if snap["cycles"]:
        print("\n## Cycles (cyc/call) — fcc vs reference (INDICATIVE ONLY)")
        print("| bench | fcc | calypsi* | llvm-mos* |\n|---|--:|--:|--:|")
        for n,v in sorted(snap["cycles"].items()):
            print(f"| {n} | {v['cyc_per_call']:.0f} | {v.get('calypsi') or '-'} | {v.get('llvm_mos') or '-'} |")
        print("\n*reference-harness numbers; not a controlled comparison.")
    else:
        print("\n## Cycles: UNMEASURED (size-only snapshot — MAME/merlin32 absent or no markers)")
```

- [ ] **Step 2: Build fresh, capture baseline**

Run:
```bash
make -C toolchain && bash toolchain/tests/regen_goldens.sh && bash toolchain/tests/run.sh
python3 toolchain/bench/fbench.py snapshot toolchain-v0.16.0-pre-tier1
python3 toolchain/bench/fbench.py report
```
Expected: `run.sh` full pass; scoreboard prints. **A size-only baseline (cycles UNMEASURED) is acceptable** if MAME is unavailable — cycles are advisory.

- [ ] **Step 3: Commit baseline**

```bash
git add toolchain/bench/scoreboard.py toolchain/bench/baselines/toolchain-v0.16.0-pre-tier1.json
git commit  # trailer: "feat(bench): fbench harness + pre-tier1 baseline"
```

**Phase 0 gate:** `python3 toolchain/bench/fbench.py compare toolchain/bench/baselines/toolchain-v0.16.0-pre-tier1.json` runs against a clean tree and shows all-zero size/system/dp deltas (cycle deltas zero or "incomplete" if unmeasured).

---

## Phase 1 — Peephole extensions (T1.1)

TDD via `make -C toolchain test-peephole`. **Before landing Task 1.1, confirm the pattern actually fires on real fcc output** (the extended REP/SEP pass may rarely match — see Step 0).

> **EXECUTED 2026-06-26 (inline; toolchain submodule `4caab68`).** The Step-0
> empirical gate (applied to all three tasks against raw pre-peephole emit, 38
> char-heavy programs + all fixtures) decided the scope:
> - **Task 1.1 (extended REP/SEP coalescing): DROPPED** — 0 candidates (fcc only
>   toggles M-width around M-sensitive ops, never an M-neutral run).
> - **Task 1.3 (invert-cond-to-fall-through): DROPPED** — 0 candidates (fcc emits
>   long conditionals as `Bcc *+5; BRL target`, not `Bcc L; BRA L2; L:`).
> - **Task 1.2 (CLC;ADC→INC / SEC;SBC→DEC, carry dead): LANDED** — 183 real sites.
>   Two corrections vs the task text: emit **`INC`/`DEC`** (implied-A), NOT
>   `INA`/`DEA` (merlin32 rejects those — golden+merlin32 gate caught it); and
>   **exclude REP/SEP from `writes_carry`** (width toggles don't touch carry) so
>   the fold can't fire when carry is read across a toggle (+ regression test).
>   V-divergence (ADC sets V, INC doesn't) is documented safe — fcc never reads V;
>   adversarially reviewed SAFE.
> - **Task 1.4 (regen + measure): DONE** — goldens 282/282, runtime oracle
>   263/263 (0 regressions); −854 B (−0.38%) userland, −71 asm lines; µs/call
>   memcmp −4.1% / strLen −3.4% / strcpy −2.9% / djb2Hash −0.5%. Baseline
>   `bench/baselines/t1.1-peephole.json`. See design spec §6 table.

### Task 1.1: Extended REP/SEP coalescing (M-toggles only; PHP/PLP are barriers)

**Files:** Modify `toolchain/src/cc/peephole.c`; Test `toolchain/tests/peephole/test_peephole.c`.

**Interfaces:** Produces `is_m_neutral(const char*)`, `pat_repsep_extended(Line*,size_t)` — cancels an `REP #$20 … SEP #$20` (or reverse) pair separated only by M-neutral ops; **only when the candidate operand is `#$20`** (never `#$10`/`#$30`).

- [ ] **Step 0: Confirm the pattern exists in real output (else drop the pass)**

Run: `make -C toolchain && (cd toolchain/tests/M11 && ../../fcc cpa_strlen.c -o /tmp/x.s) && grep -n -A3 'REP\|SEP' /tmp/x.s | head -40`
Expected: identify at least one `REP #$20 … (only LDX/LDY/INX/…) … SEP #$20` window. **If none exists across several char-heavy fixtures, the pass cannot help — drop Task 1.1 rather than ship dead bug-surface, and note it in the spec.**

- [ ] **Step 1: Failing tests**

```c
check("repsep_extended_cancel",
      "                REP     #$20\n                LDX     #2\n                SEP     #$20\n                LDA     #0\n",
      "                LDX     #2\n                LDA     #0\n");
check("repsep_extended_kept_lda",
      "                REP     #$20\n                LDA     #2\n                SEP     #$20\n",
      "                REP     #$20\n                LDA     #2\n                SEP     #$20\n");
/* index-width toggle (#$10) must NOT be coalesced — LDX between is X-width-sensitive */
check("repsep_extended_x_toggle_kept",
      "                REP     #$10\n                LDX     #2\n                SEP     #$10\n",
      "                REP     #$10\n                LDX     #2\n                SEP     #$10\n");
/* PHP/PLP are NOT m-neutral: a bracketed PHP would capture the wrong width */
check("repsep_extended_php_barrier",
      "                REP     #$20\n                PHP\n                SEP     #$20\n",
      "                REP     #$20\n                PHP\n                SEP     #$20\n");
```

- [ ] **Step 2: Run, verify fail** — `make -C toolchain test-peephole` → the new cases FAIL.

- [ ] **Step 3: Implement**

```c
/* M-accumulator-width-NEUTRAL ops. EXCLUDES PHP/PLP (they save/restore the M
 * and X bits in P — cancelling toggles around them changes the captured/restored
 * width) and PHA/PLA (M-width-sensitive). Index ops are width-neutral wrt M. */
static int
is_m_neutral(const char *m)
{
    static const char *t[] = {
        "LDX","LDY","STX","STY","INX","DEX","INY","DEY","CPX","CPY",
        "PHX","PHY","PLX","PLY","CLC","SEC","NOP", NULL };
    int i;
    for (i = 0; t[i]; i++) if (strcmp(m, t[i]) == 0) return 1;
    return 0;
}

/* REP #$20 ... (only M-neutral, unlabeled, no call/branch) ... SEP #$20 (or the
 * reverse) -> both toggles dead; erase. ONLY for #$20 (M) toggles — never #$10
 * (X) or #$30, whose bracketed index ops ARE width-sensitive. Fixpoint re-scan.
 * Port of W65816SepRepCleanup.cpp:360-445. */
static void
pat_repsep_extended(Line *lines, size_t n)
{
    int again = 1;
    while (again) {
        size_t i; again = 0;
        for (i = 0; i < n; i++) {
            int a_rep, a_sep, want_rep; size_t j;
            if (lines[i].dead) continue;
            a_rep = strcmp(lines[i].mnem,"REP")==0; a_sep = strcmp(lines[i].mnem,"SEP")==0;
            if (!a_rep && !a_sep) continue;
            if (strcmp(lines[i].operand, "#$20") != 0) continue;   /* M-bit toggles only */
            want_rep = a_sep;
            for (j = i+1; j < n; j++) {
                if (lines[j].dead) continue;
                if (lines[j].raw[0]=='\0') continue;
                if (lines[j].mnem[0]=='\0') { if (lines[j].label[0]!='\0'){j=n;break;} continue; }
                if (lines[j].label[0]!='\0') { j=n; break; }
                if ((want_rep && strcmp(lines[j].mnem,"REP")==0) ||
                    (!want_rep && strcmp(lines[j].mnem,"SEP")==0)) {
                    if (strcmp(lines[j].operand, "#$20")==0) { lines[i].dead=1; lines[j].dead=1; again=1; }
                    break;
                }
                if (is_control(lines[j].mnem)) { j=n; break; }
                if (!is_m_neutral(lines[j].mnem)) { j=n; break; }
            }
            if (again) break;
        }
    }
}
```
Wire after `pat_repsep_adjacent`:
```c
    pat_repsep_adjacent(lines, n);
    pat_repsep_extended(lines, n);
```

- [ ] **Step 4: Run, verify pass** — `make -C toolchain test-peephole` → all pass (incl. existing `rep_nonadjacent_kept`).

- [ ] **Step 5: Commit** — stage `peephole.c` + `test_peephole.c`; commit (trailer).

---

### Task 1.2: `CLC;ADC #k`→`INA`×k / `SEC;SBC #k`→`DEA`×k (carry dead)

**Files:** Modify `toolchain/src/cc/peephole.c`, `toolchain/src/cc/peephole.h`; Test `test_peephole.c`.

**Interfaces:** Produces `pat_clcadc_to_ina(Line*,size_t)`; `int ph_test_carry_dead_after(const char*,int)`. Carry-only liveness (V is assumed dead — fcc emits no `BVC/BVS`).

- [ ] **Step 1: Hook decl in `peephole.h`** — `int ph_test_carry_dead_after(const char *asm_text, int idx);`

- [ ] **Step 2: Failing tests** (decimal immediates — confirm fcc emits decimal in Step 4 of nothing; the existing emit uses `ADC #%d`):
```c
check("clcadc_to_ina","                CLC\n                ADC     #1\n                STA     5,s\n                RTL\n",
                      "                INA\n                STA     5,s\n                RTL\n");
check("clcadc_to_ina2","                CLC\n                ADC     #2\n                RTL\n",
                       "                INA\n                INA\n                RTL\n");
check("secsbc_to_dea","                SEC\n                SBC     #1\n                RTL\n",
                      "                DEA\n                RTL\n");
check("clcadc_keep_carry_live","                CLC\n                ADC     #1\n                ADC     7,s\n                RTL\n",
                               "                CLC\n                ADC     #1\n                ADC     7,s\n                RTL\n");
check("clcadc_keep_large_imm","                CLC\n                ADC     #100\n                RTL\n",
                              "                CLC\n                ADC     #100\n                RTL\n");
/* labelled CLC is a branch target -> never fold */
check("clcadc_keep_labeled","L1                 CLC\n                ADC     #1\n                RTL\n",
                            "L1                 CLC\n                ADC     #1\n                RTL\n");
if (ph_test_carry_dead_after("                ADC     #1\n                BCC     L1\n",0)!=0)
  { g_fails++; g_tests++; printf("FAIL carry_live_bcc\n"); } else { g_tests++; printf("ok   carry_live_bcc\n"); }
```

- [ ] **Step 3: Run, verify fail** — `make -C toolchain test-peephole`.

- [ ] **Step 4: Implement** (note `#include <stdio.h>` for `snprintf`)
```c
/* Reads carry as input (carry-only; V assumed dead — fcc emits no BVC/BVS).
 * PHP reads C (pushes P); XCE swaps C<->E. Conservative. */
static int reads_carry(const char *m){
    return !strcmp(m,"ADC")||!strcmp(m,"SBC")||!strcmp(m,"ROL")||!strcmp(m,"ROR")||
           !strcmp(m,"BCC")||!strcmp(m,"BCS")||!strcmp(m,"PHP")||!strcmp(m,"XCE"); }
/* Normalizes carry (=> a stale carry is dead afterwards). */
static int writes_carry(const char *m){
    return !strcmp(m,"CLC")||!strcmp(m,"SEC")||!strcmp(m,"CMP")||!strcmp(m,"CPX")||
           !strcmp(m,"CPY")||!strcmp(m,"REP")||!strcmp(m,"SEP")||!strcmp(m,"PLP"); }
static int carry_dead_after(Line *lines, size_t n, size_t idx){
    size_t i;
    for (i=idx+1;i<n;i++){ Line *L=&lines[i];
        if (L->raw[0]=='\0') continue;
        if (L->mnem[0]=='\0'){ if (L->label[0]!='\0') return 0; continue; }
        if (reads_carry(L->mnem)) return 0;
        if (is_return(L->mnem))   return 1;
        if (writes_carry(L->mnem))return 1;
        if (is_control(L->mnem))  return 0; }
    return 0;
}
/* "#<decimal>" in 1..2, else -1 (fcc emits decimal `ADC #1`; hex `#$` guard is defensive). */
static int small_imm(const char *op){ int v=0; const char *p=op;
    if (*p!='#') return -1; p++;
    if (*p=='$'||*p=='%'||*p=='\'') return -1;
    if (*p<'0'||*p>'9') return -1;
    for(;*p>='0'&&*p<='9';p++) v=v*10+(*p-'0');
    if (*p!='\0') return -1;
    return (v>=1&&v<=2)?v:-1; }
/* CLC;ADC #k (k=1..2, carry dead) -> k×INA ; SEC;SBC #k -> k×DEA. Never fold a
 * labelled CLC/SEC (branch target). */
static void pat_clcadc_to_ina(Line *lines, size_t n){
    size_t i;
    for (i=0;i+1<n;i++){ long j; int k,is_add,is_sub;
        if (lines[i].dead) continue;
        if (lines[i].label[0]!='\0') continue;          /* branch target — skip */
        is_add=!strcmp(lines[i].mnem,"CLC"); is_sub=!strcmp(lines[i].mnem,"SEC");
        if (!is_add&&!is_sub) continue;
        j=next_insn_no_label(lines,n,i+1); if (j<0) continue;
        if (is_add && strcmp(lines[(size_t)j].mnem,"ADC")) continue;
        if (is_sub && strcmp(lines[(size_t)j].mnem,"SBC")) continue;
        k=small_imm(lines[(size_t)j].operand); if (k<0) continue;
        if (!carry_dead_after(lines,n,(size_t)j)) continue;
        { const char *mn=is_add?"INA":"DEA"; char buf[64]; char *d;
          snprintf(buf,sizeof buf,"                %s",mn);
          d=strdup(buf); if(!d) continue; free(lines[i].raw); lines[i].raw=d; parse_fields(&lines[i]);
          if (k==2){ d=strdup(buf); if(!d){lines[(size_t)j].dead=1;continue;}
                     free(lines[(size_t)j].raw); lines[(size_t)j].raw=d; parse_fields(&lines[(size_t)j]); }
          else lines[(size_t)j].dead=1; }
    }
}
```
Wire after the repsep passes: `pat_clcadc_to_ina(lines, n);`. Add the hook:
```c
int ph_test_carry_dead_after(const char *asm_text,int idx){
    size_t n; Line *lines=split_lines(asm_text,&n); int r;
    if(!lines||idx<0||(size_t)idx>=n){ free_lines(lines,n); return 0; }
    r=carry_dead_after(lines,n,(size_t)idx); free_lines(lines,n); return r; }
```

- [ ] **Step 5: Run, verify pass** — `make -C toolchain test-peephole`.
- [ ] **Step 6: Commit** — stage `peephole.c`, `peephole.h`, `test_peephole.c`; commit (trailer).

---

### Task 1.3: Invert conditional to fall-through + final pass order

**Files:** Modify `toolchain/src/cc/peephole.c`; Test `test_peephole.c`.

**Interfaces:** Produces `invert_branch`, `pat_invert_to_fallthrough`. **Final pass order (single block, no cross-pass fixpoint):**
```c
    pat_invert_to_fallthrough(lines, n);   /* may create a fresh BRA-to-next */
    pat_bra_to_next(lines, n);
    pat_staload_forward(lines, n);
    pat_repsep_adjacent(lines, n);
    pat_repsep_extended(lines, n);
    pat_clcadc_to_ina(lines, n);
```

- [ ] **Step 1: Failing tests**
```c
check("invert_to_fallthrough",
      "                BEQ     L2\n                BRA     L5\nL2                 ENT\n",
      "                BNE     L5\nL2                 ENT\n");
check("invert_kept_no_bra",
      "                BEQ     L2\n                NOP\nL2                 ENT\n",
      "                BEQ     L2\n                NOP\nL2                 ENT\n");
/* labelled conditional is itself a target — don't rewrite */
check("invert_kept_labeled",
      "L0                 BEQ     L2\n                BRA     L5\nL2                 ENT\n",
      "L0                 BEQ     L2\n                BRA     L5\nL2                 ENT\n");
```
- [ ] **Step 2: Run, verify fail** — `make -C toolchain test-peephole`.
- [ ] **Step 3: Implement**
```c
static const char *invert_branch(const char *m){
    if(!strcmp(m,"BEQ"))return "BNE"; if(!strcmp(m,"BNE"))return "BEQ";
    if(!strcmp(m,"BCC"))return "BCS"; if(!strcmp(m,"BCS"))return "BCC";
    if(!strcmp(m,"BMI"))return "BPL"; if(!strcmp(m,"BPL"))return "BMI";
    return NULL; }
static void pat_invert_to_fallthrough(Line *lines, size_t n){
    size_t i;
    for(i=0;i<n;i++){ const char *inv; long j,lab;
        if(lines[i].dead) continue;
        if(lines[i].label[0]!='\0') continue;            /* branch target — skip */
        inv=invert_branch(lines[i].mnem); if(!inv) continue;
        j=next_insn_no_label(lines,n,i+1); if(j<0) continue;
        if(strcmp(lines[(size_t)j].mnem,"BRA") && strcmp(lines[(size_t)j].mnem,"BRL")) continue;
        lab=next_labeled_line(lines,(size_t)j+1,n);
        if(lab<0||strcmp(lines[(size_t)lab].label,lines[i].operand)) continue;
        { char buf[80]; char *d;
          snprintf(buf,sizeof buf,"                %-8s%s",inv,lines[(size_t)j].operand);
          d=strdup(buf); if(!d) continue; free(lines[i].raw); lines[i].raw=d; parse_fields(&lines[i]);
          lines[(size_t)j].dead=1; }
    }
}
```
Set the final pass order (Interfaces block above) in `peephole_optimize`.
- [ ] **Step 4: Run, verify pass** — `make -C toolchain test-peephole`.
- [ ] **Step 5: Commit** — stage `peephole.c`, `test_peephole.c`; commit (trailer).

---

### Task 1.4: Phase-1 goldens regen + measure

**Files:** Modify `toolchain/tests/M*/**.expected.{s,bin}`; Create `toolchain/bench/baselines/t1.1-peephole.json`.

- [ ] **Step 1: Rebuild + run goldens (expect intended drift)** — `make -C toolchain && bash toolchain/tests/run.sh`.
- [ ] **Step 2: Inspect a diff** — `cd toolchain/tests/M11 && ../../fcc cpa_strlen.c -o cpa_strlen.s && diff cpa_strlen.s cpa_strlen.expected.s; cd -` → confirm only REP/SEP-pair removals and `CLC;ADC #1`→`INA`; no live carry/REP dropped.
- [ ] **Step 3: Regen + gate** — `bash toolchain/tests/regen_goldens.sh && bash toolchain/tests/run.sh` → full pass.
- [ ] **Step 4: Correctness oracle (mandatory — peephole touches all codegen)** — from FGX root: `python3 toolchain/tests/run_runtime.py` → all scored fixtures pass (no new regressions).
- [ ] **Step 5: Measure + record** — `python3 toolchain/bench/fbench.py compare toolchain/bench/baselines/toolchain-v0.16.0-pre-tier1.json` ; `python3 toolchain/bench/fbench.py snapshot t1.1-peephole`. Record size %/cyc % in the spec §6 predicted-vs-actual table.
- [ ] **Step 6: Commit** — stage `toolchain/tests/M*/`, the baseline; commit "perf(fcc): T1.1 peephole" (trailer).

---

## Phase 2 — Constant-aware lowering (T1.2)

> **EXECUTED 2026-06-26 (inline).** All tasks landed.
> - **2.1 peek_tok** (submodule `839267c`): scan_tok/next_tok split + non-destructive
>   peek_tok + helper relocation. Additive — goldens byte-identical, test-lex green.
>   (Step 6 rewind-site hardening was NOT needed: my peeks are consumed before any
>   manual rewind — g_cur is the INT_LIT, parsed before recursion — and goldens +
>   oracle confirm no interaction. pushback kept static/encapsulated.)
> - **2.2 inline shift** (submodule `1e7b2fc`): `x<<k`→ASL, unsigned `x>>k`→LSR.
>   shift_const→30. 0 existing drift.
> - **2.3+2.4 const mul + unsigned pow2 div/mod** (submodule `ce4b055`, unified
>   parse_mul_expr): pow2 `*`→ASL, unsigned pow2 `/`,`%`→LSR/AND; non-pow2 keeps the
>   libcall via the dividend-in-A fallback (`LDX #k; STX _fcc_tmp_b`). INC/DEC and
>   ASL/LSR mnemonics verified against merlin32. mul_const→48, divmod_const→28
>   (asymmetric divisor proves 37/3==12). 35 fixtures drifted.
> - **2.5 measure**: goldens 285/285, full oracle **266/266 (0 regressions)**,
>   fast-group 19/19 on rebuilt userland. Measured (vs t1.1-peephole baseline):
>   **t12_mul −76%/−80%, t12_divmod −90%, t12_shift −38%** cyc; userland size flat
>   (−18 B — T1.2 rarely fires in long/var/stride userland). Baselines
>   `t1.2-const-arith.json` (+ kernel us/call). **Tier 1 COMPLETE.** T1.3 deferred.

### Task 2.1: `peek_tok()` + relocate shared lexer helpers

**Files:** Modify `toolchain/src/cc/lex_pp.c`, `toolchain/src/cc/fcc.h`, `toolchain/src/cc/globals.c`, `toolchain/src/cc/main.c`, `toolchain/Makefile`; Create `toolchain/tests/lex/test_peek.c`.

**Interfaces:** Produces `Tok peek_tok(void)` (non-destructive 1-token lookahead beyond `g_cur`). Also moves `die`, `is_ident_start`, `is_ident_cont` from `main.c` to `globals.c` so the lexer unit test links without `main()`.

- [ ] **Step 1: Move shared helpers `main.c` → `globals.c`**

Cut `die` (main.c:19), `is_ident_start` (main.c:27), `is_ident_cont` (main.c:33) verbatim from `main.c` into `globals.c`; leave their prototypes in `fcc.h` (already declared at fcc.h:414/420/422). Rebuild to confirm fcc still links: `make -C toolchain`.

- [ ] **Step 2: Add `test-lex` target + failing test**

`toolchain/Makefile`:
```make
test-lex:
	$(CC) $(CFLAGS) -DFCC_LEX_TEST -o /tmp/fcc_test_lex \
	    tests/lex/test_peek.c src/cc/lex_pp.c src/cc/globals.c
	/tmp/fcc_test_lex
```
`toolchain/tests/lex/test_peek.c`:
```c
#include <stdio.h>
#include "../../src/cc/fcc.h"
int main(void){
    int fails=0;
    lex_init_buffer("1 << 2 + x;");          /* helper added in Step 3 */
    next_tok();
    if (g_cur.kind!=TOK_INT_LIT || g_cur.value!=1){ printf("FAIL cur1\n"); fails++; }
    if (peek_tok().kind!=TOK_LSHIFT){ printf("FAIL peek<<\n"); fails++; }
    if (peek_tok().kind!=TOK_LSHIFT){ printf("FAIL idempotent\n"); fails++; }
    next_tok(); if (g_cur.kind!=TOK_LSHIFT){ printf("FAIL consume peek\n"); fails++; }
    next_tok(); if (g_cur.kind!=TOK_INT_LIT||g_cur.value!=2){ printf("FAIL cur2\n"); fails++; }
    if (peek_tok().kind!=TOK_PLUS){ printf("FAIL peek+\n"); fails++; }
    printf(fails?"\n%d FAIL\n":"\nok\n",fails); return fails?1:0;
}
```

- [ ] **Step 3: Run, verify fail** — `make -C toolchain test-lex` → undefined `peek_tok`/`lex_init_buffer`.

- [ ] **Step 4: Implement refactor + peek + test helper**

In `lex_pp.c`: rename the existing `void next_tok(void){…}` body to `static void scan_tok(void)`. **Convert every internal recursive `next_tok()` call to `scan_tok()`** — there are ~12 (lex_pp.c:609,639,755,876,901,936,952,962,978,1465,1521,1527; verify with grep below). Add:
```c
static Tok g_pushback; static int g_have_pushback = 0;
void next_tok(void){
    if (g_have_pushback){ g_cur = g_pushback; g_have_pushback = 0; return; }
    scan_tok();
}
Tok peek_tok(void){
    if (!g_have_pushback){ Tok save=g_cur; scan_tok(); g_pushback=g_cur; g_cur=save; g_have_pushback=1; }
    return g_pushback;
}
#ifdef FCC_LEX_TEST
void lex_init_buffer(const char *src){ extern void pp_push_buffer(const char*,int);
    g_have_pushback=0; pp_push_buffer(src,(int)strlen(src)); }
#endif
```
> Use the real buffer-seat entry name (check lex_pp.c ~29-58 where `g_pp_stack[g_pp_top]` is loaded; if there's no exported pusher, add a tiny one guarded by FCC_LEX_TEST). In `fcc.h`: `Tok peek_tok(void);`.
> **Contract (add as a comment in fcc.h):** do not call `peek_tok()` while a live pointer into `g_cur`'s string/identifier buffer is held — a peek may pp_pop and invalidate it.

- [ ] **Step 5: Verify all recursion sites converted** — `grep -n 'next_tok(' toolchain/src/cc/lex_pp.c` should show ONLY the `next_tok` definition + (none internal). `make -C toolchain test-lex` → `ok`.

- [ ] **Step 6: Harden legacy rewind-peeks** — the parser already does manual save/restore "rewind peeks" (parse_expr.c:1431,1574,1813,2194,2416). At each, also save/restore `g_have_pushback`/`g_pushback` (≈2 lines each) so a pushed-back token survives a rewind.

- [ ] **Step 7: Full goldens + oracle still green (additive change)** — `make -C toolchain && bash toolchain/tests/run.sh && (cd ${ROOT} && python3 toolchain/tests/run_runtime.py)` (substitute repo root). Expected: full pass.

- [ ] **Step 8: Commit** — stage `lex_pp.c`, `fcc.h`, `globals.c`, `main.c`, `tests/lex/test_peek.c`, `Makefile`; commit "feat(fcc): non-destructive peek_tok() + relocate lexer helpers" (trailer).

---

### Task 2.2: Inline constant shift (`x<<k`, unsigned `x>>k`)

**Files:** Modify `toolchain/src/cc/emit.c`, `parse_expr.c`, `fcc.h`; Create golden `toolchain/tests/M30/shift_const.c` + `.link.s`; add `toolchain/tests/oracle.json` entry.

**Interfaces:** Produces `void emit_inline_shift(TokKind op,int is_unsigned,unsigned k)` — `ASL`×k (LSHIFT) or `LSR`×k (unsigned RSHIFT) on A; **preserves `g_expr_unsigned`** (sets it for the result). Signed `>>` is NOT inlined (forward-safety; fcc's `>>` is currently logical via `_fcc_shr16`).

- [ ] **Step 1: Golden fixture WITH main() (crt0 does `JSR main`; no main ⇒ merlin32 link fails)**

`toolchain/tests/M30/shift_const.c`:
```c
unsigned f(unsigned x){ return (x << 2) + (x >> 1); }
int g(int a){ return a << 3; }
int main(void){ return (int)f(5) + g(1); }   /* 22 + 8 = 30 */
```
`toolchain/tests/M30/shift_const.link.s` (runtime-bearing wrapper — fallback libcalls live in fcc_runtime.s, PUT by `_wrap.s`):
```
                TYP     $06
                DSK     shift_const
                ORG     $0B0000
                ASM     _wrap.s
```
Copy the runtime wrapper into M30: `mkdir -p toolchain/tests/M30 && cp toolchain/tests/M11/_wrap.s toolchain/tests/M30/`.

- [ ] **Step 2: Show the current libcall (pre-change)** — `make -C toolchain && (cd toolchain/tests/M30 && ../../fcc shift_const.c -o shift_const.s && grep -n '_fcc_shl16\|_fcc_shr16\|ASL\|LSR' shift_const.s)` → shows `JSR _fcc_shl16/_fcc_shr16`.

- [ ] **Step 3: Implement `emit_inline_shift` + the parser peek (preserve unsignedness)**

`emit.c`:
```c
/* Inline constant shift on A. LSHIFT -> ASL×k; UNSIGNED RSHIFT -> LSR×k.
 * Caller guarantees int (not long/float) LHS in A, 1<=k<=15, and RSHIFT=>unsigned.
 * Preserves signedness so a following comparison/op sees the right type. */
void emit_inline_shift(TokKind op, int is_unsigned, unsigned k){
    unsigned i; const char *mn = (op==TOK_LSHIFT) ? "ASL" : "LSR";
    for (i=0;i<k;i++) fprintf(g_out,"                %s\n",mn);
    g_expr_type = LT_INT; g_expr_unsigned = is_unsigned;
}
```
`fcc.h`: `void emit_inline_shift(TokKind op,int is_unsigned,unsigned k);`
`parse_expr.c` — replace `parse_shift_expr`:
```c
void parse_shift_expr(void){
    parse_add_expr();
    while (g_cur.kind==TOK_LSHIFT || g_cur.kind==TOK_RSHIFT){
        TokKind op=g_cur.kind; LocalType lhs_type=g_expr_type; int lhs_u=g_expr_unsigned;
        if (lhs_type!=LT_LONG && lhs_type!=LT_FLOAT){
            next_tok();                              /* consume << / >> */
            if (g_cur.kind==TOK_INT_LIT){
                unsigned k=g_cur.value & 0xFFFF; Tok after=peek_tok();
                int bare=!(after.kind==TOK_PLUS||after.kind==TOK_MINUS||
                           after.kind==TOK_STAR||after.kind==TOK_SLASH||after.kind==TOK_PERCENT);
                if (bare && k==0){ next_tok(); g_expr_type=LT_INT; continue; }   /* identity */
                if (bare && k>=1 && k<=15 && (op==TOK_LSHIFT || lhs_u)){
                    next_tok(); emit_inline_shift(op,lhs_u,k); continue;
                }
            }
            emit_push_a(); parse_add_expr();
            emit_scalar_binop(lhs_type,g_expr_type,lhs_u,g_expr_unsigned,
                              (op==TOK_LSHIFT)?emit_binop_shl:emit_binop_shr);
            continue;
        }
        next_tok(); emit_push_long(); parse_add_expr();
        emit_scalar_binop(lhs_type,g_expr_type,lhs_u,g_expr_unsigned,
                          (op==TOK_LSHIFT)?emit_binop_shl:emit_binop_shr);
    }
}
```

- [ ] **Step 4: Verify codegen** — `make -C toolchain && (cd toolchain/tests/M30 && ../../fcc shift_const.c -o shift_const.s && grep -n 'ASL\|LSR\|_fcc_sh' shift_const.s)` → `x<<2`=2×ASL, `x>>1`(unsigned)=LSR, `a<<3`=3×ASL; no shl/shr libcall for these.

- [ ] **Step 5: Register the runtime correctness oracle** — add `"shift_const": 30` to `toolchain/tests/oracle.json` (the known exit code; `30 & 0xFF = 30`, fits a byte).

- [ ] **Step 6: Regen + both gates** — `bash toolchain/tests/regen_goldens.sh && bash toolchain/tests/run.sh && (cd ${ROOT} && python3 toolchain/tests/run_runtime.py)` → full pass; `shift_const` returns 30.

- [ ] **Step 7: Commit** — stage `emit.c`, `parse_expr.c`, `fcc.h`, `tests/M30/`, `tests/oracle.json`; commit "perf(fcc): inline constant shift (ASL/LSR)" (trailer).

---

### Task 2.3: Constant pow2 multiply (`x*2^n`→`ASL`×n)

**Files:** Modify `emit.c`, `parse_expr.c`, `fcc.h`; Create `toolchain/tests/M30/mul_const.c` + `.link.s`; oracle entry.

**Interfaces:** Produces `int emit_inline_mul_const(unsigned k)` — emits inline for k∈{0,1,pow2≤2^15}, returns 1 if handled else 0 (caller keeps `_fcc_mul16`). **Non-pow2 (e.g. `*10`) is NOT inlined** — it stays a libcall. The fallback uses `LDX #k; STX _fcc_tmp_b` (mul is commutative; this is the same shape the div/mod fix requires).

- [ ] **Step 1: Golden + main**

`toolchain/tests/M30/mul_const.c`:
```c
unsigned f(unsigned x){ return x * 4; }     /* ASL ASL */
unsigned h(unsigned x){ return x * 10; }    /* non-pow2 -> _fcc_mul16 */
int main(void){ return (int)(f(7) + h(2)); }  /* 28 + 20 = 48 */
```
`mul_const.link.s` (same shape as `shift_const.link.s`, `ASM _wrap.s`).

- [ ] **Step 2: Implement**

`emit.c`:
```c
int emit_inline_mul_const(unsigned k){
    if (k==0){ fprintf(g_out,"                LDA     #0\n"); g_expr_type=LT_INT; return 1; }
    if (k==1){ g_expr_type=LT_INT; return 1; }
    if ((k&(k-1))==0 && k<=0x8000u){ unsigned n=0,t=k; while(t>1){t>>=1;n++;}
        while(n--) fprintf(g_out,"                ASL\n"); g_expr_type=LT_INT; return 1; }
    return 0;
}
```
`fcc.h`: `int emit_inline_mul_const(unsigned k);`
`parse_expr.c` `parse_mul_expr` — handle `*` with a bare literal (and the unified `LDX #k; STX` fallback):
```c
void parse_mul_expr(void){
    parse_unary();
    while (g_cur.kind==TOK_STAR||g_cur.kind==TOK_SLASH||g_cur.kind==TOK_PERCENT){
        TokKind op=g_cur.kind; LocalType lhs_type=g_expr_type; int lhs_u=g_expr_unsigned;
        if (op==TOK_STAR && lhs_type!=LT_LONG && lhs_type!=LT_FLOAT){
            next_tok();
            if (g_cur.kind==TOK_INT_LIT){
                unsigned k=g_cur.value & 0xFFFF; Tok after=peek_tok();
                int bare=!(after.kind==TOK_STAR||after.kind==TOK_SLASH||after.kind==TOK_PERCENT);
                if (bare){
                    next_tok();
                    if (!emit_inline_mul_const(k)){
                        fprintf(g_out,"                LDX     #%u\n",k);   /* divisor/multiplier */
                        fprintf(g_out,"                STX     _fcc_tmp_b\n");
                        fprintf(g_out,"                JSR     _fcc_mul16\n");
                        g_expr_type=LT_INT;
                    }
                    g_expr_unsigned=lhs_u;             /* preserve signedness */
                    continue;
                }
            }
            emit_push_a(); parse_unary();
            emit_scalar_binop(lhs_type,g_expr_type,lhs_u,g_expr_unsigned,emit_binop_mul);
            continue;
        }
        /* '/','%', or long/float '*': handled in Task 2.4 / original path */
        next_tok();
        if (lhs_type==LT_LONG||lhs_type==LT_FLOAT) emit_push_long(); else emit_push_a();
        parse_unary();
        { void (*e)(void)=(op==TOK_STAR)?emit_binop_mul:(op==TOK_SLASH)?emit_binop_div:emit_binop_mod;
          emit_scalar_binop(lhs_type,g_expr_type,lhs_u,g_expr_unsigned,e); }
    }
}
```

- [ ] **Step 3: Verify codegen** — `make -C toolchain && (cd toolchain/tests/M30 && ../../fcc mul_const.c -o mul_const.s && grep -n 'ASL\|_fcc_mul16\|LDA     #0' mul_const.s)` → `x*4`=2×ASL; `x*10`=`_fcc_mul16`.

- [ ] **Step 4: Oracle + gates** — add `"mul_const": 48` to `oracle.json`; `bash toolchain/tests/regen_goldens.sh && bash toolchain/tests/run.sh && (cd ${ROOT} && python3 toolchain/tests/run_runtime.py)` → pass.

- [ ] **Step 5: Commit** — stage `emit.c`, `parse_expr.c`, `fcc.h`, `tests/M30/`, `oracle.json`; commit "perf(fcc): inline pow2 multiply" (trailer).

---

### Task 2.4: Unsigned constant divide/modulo by pow2 (+ the operand-swap fix)

**Files:** Modify `emit.c`, `parse_expr.c`, `fcc.h`; Create `toolchain/tests/M30/divmod_const.c` + `.link.s`; oracle entry.

**Interfaces:** Produces `int emit_inline_divmod_pow2(TokKind op,unsigned k)` — unsigned `/2^n`→`LSR`×n, unsigned `%2^n`→`AND #(k-1)`, plus `x/1`=identity / `x%1`→`LDA #0`; returns 1 if emitted. **CRITICAL:** the non-inlinable fallback for `/`,`%` MUST keep the dividend in A: `LDX #k; STX _fcc_tmp_b; JSR _fcc_divu16|_fcc_modu16` (the v1 `STA _fcc_tmp_b; LDA #k` computed `k/x`).

- [ ] **Step 1: Implement**

`emit.c`:
```c
/* Unsigned x / 2^n -> LSR×n ; unsigned x %% 2^n -> AND #(k-1). Also x/1 identity,
 * x%1 -> 0. Signed is NOT inlined (rounding differs) — caller keeps the libcall. */
int emit_inline_divmod_pow2(TokKind op, unsigned k){
    if (k==1){ if (op==TOK_PERCENT){ fprintf(g_out,"                LDA     #0\n"); }
               g_expr_type=LT_INT; return 1; }                 /* x/1=x ; x%1=0 */
    if (k<2 || (k&(k-1))!=0 || k>0x8000u) return 0;
    if (op==TOK_PERCENT){ fprintf(g_out,"                AND     #%u\n",k-1); }
    else { unsigned n=0,t=k; while(t>1){t>>=1;n++;} while(n--) fprintf(g_out,"                LSR\n"); }
    g_expr_type=LT_INT; return 1;
}
```
`fcc.h`: `int emit_inline_divmod_pow2(TokKind op,unsigned k);`
`parse_expr.c` — extend the `parse_mul_expr` fast-path guard to also handle unsigned `/`,`%`, and use the **dividend-in-A** fallback:
```c
        int can_inline = (op==TOK_STAR) ||
                         ((op==TOK_SLASH||op==TOK_PERCENT) && lhs_u);   /* unsigned div/mod only */
        if (can_inline && lhs_type!=LT_LONG && lhs_type!=LT_FLOAT){
            next_tok();
            if (g_cur.kind==TOK_INT_LIT){
                unsigned k=g_cur.value & 0xFFFF; Tok after=peek_tok();
                int bare=!(after.kind==TOK_STAR||after.kind==TOK_SLASH||after.kind==TOK_PERCENT);
                if (bare){
                    next_tok();
                    int done = (op==TOK_STAR) ? emit_inline_mul_const(k)
                                              : emit_inline_divmod_pow2(op,k);
                    if (!done){
                        /* dividend stays in A; constant -> _fcc_tmp_b via X */
                        fprintf(g_out,"                LDX     #%u\n",k);
                        fprintf(g_out,"                STX     _fcc_tmp_b\n");
                        fprintf(g_out,"                JSR     %s\n",
                                op==TOK_STAR ? "_fcc_mul16" :
                                op==TOK_SLASH? "_fcc_divu16" : "_fcc_modu16");
                        g_expr_type=LT_INT;
                    }
                    g_expr_unsigned=lhs_u; continue;
                }
            }
            emit_push_a(); parse_unary();
            { void (*e)(void)=(op==TOK_STAR)?emit_binop_mul:(op==TOK_SLASH)?emit_binop_div:emit_binop_mod;
              emit_scalar_binop(lhs_type,g_expr_type,lhs_u,g_expr_unsigned,e); }
            continue;
        }
```
> Replaces the `op==TOK_STAR`-only block from Task 2.3 with this unified `can_inline` block. Confirm `_fcc_divu16`/`_fcc_modu16` are the unsigned names (emit_binop_div:1995, emit_binop_mod:2018).

- [ ] **Step 2: Golden with an ASYMMETRIC divisor (the pow2 sample never hits the buggy fallback)**

`toolchain/tests/M30/divmod_const.c`:
```c
unsigned p2(unsigned x){ return (x / 4) + (x % 8); }   /* LSR LSR ; AND #7 */
unsigned np(unsigned x){ return (x / 3) + (x % 5); }   /* non-pow2: x/3 + x%5 (NOT 3/x, 5/x) */
int main(void){ return (int)(p2(37) + np(37)); }       /* (9+5)+(12+2)=14+14=28 */
```
`divmod_const.link.s` (`ASM _wrap.s`).

- [ ] **Step 3: Verify codegen + oracle + gates** — `make -C toolchain && (cd toolchain/tests/M30 && ../../fcc divmod_const.c -o divmod_const.s && grep -n 'LSR\|AND     #7\|LDX     #3\|_fcc_divu16\|_fcc_modu16' divmod_const.s)` → `x/4`=2×LSR, `x%8`=AND #7, `x/3`/`x%5`=`LDX #3/#5; STX _fcc_tmp_b; JSR _fcc_divu16/_fcc_modu16` (dividend in A). Add `"divmod_const": 28` to `oracle.json`; `bash toolchain/tests/regen_goldens.sh && bash toolchain/tests/run.sh && (cd ${ROOT} && python3 toolchain/tests/run_runtime.py)` → pass (proves `37/3==12`, not `3/37==0`).

- [ ] **Step 4: Commit** — stage `emit.c`, `parse_expr.c`, `fcc.h`, `tests/M30/`, `oracle.json`; commit "perf(fcc): inline unsigned pow2 div/mod + fix div/mod operand order" (trailer).

---

### Task 2.5: Phase-2 measure + Tier-1 wrap + release gate

**Files:** Create `toolchain/bench/baselines/t1.2-const-arith.json`; update the spec §6 table.

- [ ] **Step 1: Measure** — `make -C toolchain && bash toolchain/tests/run.sh`; `python3 toolchain/bench/fbench.py compare toolchain/bench/baselines/t1.1-peephole.json`; `python3 toolchain/bench/fbench.py compare toolchain/bench/baselines/toolchain-v0.16.0-pre-tier1.json`; `python3 toolchain/bench/fbench.py snapshot t1.2-const-arith`; `python3 toolchain/bench/fbench.py report`. Expected: `t12_shift`/`t12_mul`/`t12_divmod` micro-benches show the T1.2 wins; ported corpus shows T1.1 effects; long/variable-mul benches ≈ flat.
- [ ] **Step 2: Record predicted-vs-actual** in spec §6 (note any miss + why).
- [ ] **Step 3: Codegen-change RELEASE GATE (mandatory)** — from FGX root: (a) `python3 toolchain/tests/run_runtime.py` full sweep green; (b) rebuild all C userland (`build_userbin_fgx2_c` or the project's userland build) and run their headless behavior manifests green (sed/ed/grep/tr/od/more/man/vi/yacc-parsers). Do NOT release if any userland behavior regresses.
- [ ] **Step 4: Commit + finish the branch** — stage the baseline + spec; commit "docs(fcc): record Tier-1 measured gains". Then invoke `superpowers:finishing-a-development-branch`: goldens+oracle+userland green → merge to `main` → `toolchain/release.sh` (toolchain first) → re-pin FGX. Reassess deferred T1.3 against the data.

---

## Self-Review (rev. 2)

**Spec coverage:** Phase 0 (0.1-0.6) = harness/size/cycles/dp/system/baseline; Phase 1 (1.1-1.4) = peephole; Phase 2 (2.1-2.5) = peek_tok + shift/mul/divmod; T1.3 deferred. ✓
**Review coverage (audit findings):** A1/A2/A3/A5 → Task 0.1 headerless `_wrap_bench.s` + 0.3 PC=$1000/S-via-crt0. A4/C-3 → asm markers (no C store). B1-B11/H5 → Task 0.2/2.x return-value fixtures + `_wrap.s` + `oracle.json`; correctness via run_runtime, not $025000. C1 → Task 2.4 `LDX #k; STX` dividend-in-A. C-5/E1/E2 → Task 1.1 `#$20`-only + PHP/PLP removed. D2/H1 → Task 2.1 helper relocation + drop symtab.c. H2 → Task 0.2 compare() covers cyc/dp/system. H3/N2 → Global Constraints + Task 2.5 release gate. H4/G3 → Task 0.3 write-taps. G1/G2/G9 → Task 0.4 T1.2 micro-benches + pow2-only (no `x*10` claim). M1/H2 → toolchain SHA + renamed baseline. M2/F1/H3 → Task 0.5 per-task page + `$C0-$DF`. M3/H6 → fcc-only system bytes. M4/H7/B8 → makedirs + run-from-root. L-1→0.1 Step 0 grep-first; L-2..L-8 → carry readers/label guards/strdup checks/pass order folded in; L-7 → all-12 scan_tok sites + rewind hardening + contract. ✓
**Placeholder scan:** none; two explicit implementer-verify notes (real `pp_push_buffer` name in 2.1; `_fcc_divu16/modu16` names in 2.4) with how to confirm. ✓
**Type consistency:** `emit_inline_shift(TokKind,int,unsigned)`, `emit_inline_mul_const(unsigned)->int`, `emit_inline_divmod_pow2(TokKind,unsigned)->int`, `peek_tok(void)->Tok`, `ph_test_carry_dead_after(const char*,int)->int` consistent across fcc.h/peephole.h decls, emit.c/lex_pp.c/peephole.c defs, and parse_expr.c/test call sites. All fast paths set `g_expr_unsigned`. ✓
**Biggest residual risk:** the cycle harness depends on `install_write_tap` + the headerless-load path working under the pinned MAME; Task 0.4 Step 6 requires a manual marker-observed smoke test before trusting any cycle number, and cycles remain advisory (correctness is gated solely by run.sh + run_runtime.py).
