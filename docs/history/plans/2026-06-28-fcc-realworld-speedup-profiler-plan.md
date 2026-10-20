# fcc real-world profiler (Phase 0) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a statistical PC-sampling profiler for fcc-compiled FGX tools that attributes a real tool's run-time cycles to 5 categories (user body / call glue / prologue-epilogue / libc / kernel-IO), and produce a `fas`+`sed` profile + report that recommends the next fcc optimization lever.

**Architecture:** A gated PC-sampler hook added to the existing `fgxdebug` MAME Lua plugin dumps a `runtime-bank:offset → count` histogram; a new pure-Python post-processor (`tools/profile/`) parses each tool's merlin32 seg0 listing, relocates runtime addresses to link-relative offsets, attributes each sample to the enclosing symbol + category, and renders a report. A driver builds old-fcc vs new-fcc tool binaries (with a silent-rebuild guard) and runs both under MAME with sampling.

**Tech Stack:** Python 3 (host post-processor, stdlib only — no deps), Lua (MAME plugin), bash (driver), MAME (Ample build) via `tools/mame_test/run.py`, merlin32 seg0 `-V` listings.

## Global Constraints

- Pure-Python post-processor, **stdlib only** (no pip deps) — runs on the same host as `bench/fbench.py`.
- The PC-sampler is **opt-in via a config key**; with the key absent the plugin behaves byte-for-byte as today (zero effect on golden/oracle/cycle_markers runs).
- Old-fcc tool builds MUST set `PROJECT_ROOT` *after* `source lib/build_common.sh`, assert `toolchain/fcc --version` matches the intended commit, and fail loudly if a "Building fcc…" line appears (the silent-rebuild trap hit during measurement, 2026-06-28).
- Symbol/category attribution keys off the seg0 listing's **source-file column** (user `sed.s`/`fas.s` vs `lib/`/`crt0.s`/`_fcc_*` libc) and the per-line **mnemonic** (call-glue/frame). Samples in banks that are not the tool's code banks → kernel-IO.
- Plan/report docs live under `docs/history/`; profiler code under `tools/profile/`. Do not bump the FGX pin or touch `toolchain/` in this plan.
- Commit trailer on every commit:

## File Structure

- `tools/profile/seg0map.py` — parse a seg0 `-V` listing → `SymbolTable`; address→`Sym(symbol, mnemonic, srcfile)`; `categorize()`.
- `tools/profile/profile_report.py` — relocate runtime addr → link offset; build the profile from a samples JSON; render the markdown report; CLI `main`.
- `tools/profile/tests/test_seg0map.py` — unit tests (parser, attribution, categorize).
- `tools/profile/tests/test_profile_report.py` — unit tests (relocate, build_profile, render).
- `tools/profile/tests/fixtures/mini_seg0.txt` — a hand-built minimal listing for tests.
- `tools/mame_test/plugins/fgxdebug/init.lua` — MODIFY: add the gated PC-sampler.
- `tools/profile/workloads/big.s` — fas workload (a large `.s` to assemble).
- `tools/profile/workloads/heavy.sed` + `tools/profile/workloads/big.txt` — sed workload (script + input).
- `tools/profile/run_profile.sh` — driver: build old/new tool, run both sampled under MAME, invoke the report.
- `docs/history/2026-06-28-fcc-realworld-profile-report.md` — the committed output report (Task 6).

---

### Task 1: seg0 listing parser → SymbolTable

**Files:**
- Create: `tools/profile/seg0map.py`
- Create: `tools/profile/tests/test_seg0map.py`
- Create: `tools/profile/tests/fixtures/mini_seg0.txt`

**Interfaces:**
- Produces: `Sym = namedtuple("Sym", "symbol mnemonic srcfile")`; `class SymbolTable` with `.from_listing(path) -> SymbolTable` and `.lookup(offset:int) -> Sym|None` (nearest code line at-or-before `offset` within the same enclosing label).

- [ ] **Step 1: Create the test fixture** `tools/profile/tests/fixtures/mini_seg0.txt` (real merlin32 `-V` line shapes; columns are pipe-delimited; the address is `BB/OOOO`, the trailing field carries the label/mnemonic, and the 3rd field is the source file):

```
 1381 |  5                                sed.s      6 | Global      | 00 |         |    0 | 0B/0112               | main                          ENT
 1382 |  5                                sed.s      7 | Code        | 00 |         |    3 | 0B/0112 : 5B          |                               TCS
 1383 |  5                                sed.s      8 | Code        | 00 |         |    3 | 0B/0113 : 20 40 02    |                               JSR          _sed_match
 1730 |  5                                sed.s    372 | Empty       | 00 |         |    0 | 0B/0358               | _sed_match
 1731 |  5                                sed.s    373 | Code        | 00 |         |    3 | 0B/0358 : A9 00       |                               LDA          #0
 1732 |  5               ../../src/userland/lib/crt0.s 40 | Code   | 00 |         |    3 | 0B/0400 : 60          |                               RTS
```

- [ ] **Step 2: Write the failing test** `tools/profile/tests/test_seg0map.py`:

```python
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from seg0map import SymbolTable, Sym

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "mini_seg0.txt")

def test_parses_labels_mnemonics_srcfile():
    st = SymbolTable.from_listing(FIX)
    assert st.lookup(0x0112) == Sym("main", "TCS", "sed.s")          # label line's first code
    assert st.lookup(0x0113) == Sym("main", "JSR", "sed.s")          # still inside main
    assert st.lookup(0x0358) == Sym("_sed_match", "LDA", "sed.s")    # new label
    assert st.lookup(0x0400).srcfile.endswith("crt0.s")              # libc/runtime srcfile
    assert st.lookup(0x0400).mnemonic == "RTS"

def test_lookup_between_addrs_uses_enclosing():
    st = SymbolTable.from_listing(FIX)
    assert st.lookup(0x0359).symbol == "_sed_match"   # no code line at 0x359 -> nearest prior
```

- [ ] **Step 3: Run it, expect failure**

Run: `cd tools/profile && python3 -m pytest tests/test_seg0map.py -q` (or `python3 tests/test_seg0map.py` with a tiny `if __name__` runner)
Expected: FAIL (`ModuleNotFoundError: seg0map` / `No module`).

- [ ] **Step 4: Implement `tools/profile/seg0map.py`**

```python
"""Parse a merlin32 -V seg0 listing into an address->symbol/mnemonic/srcfile map."""
import re
from collections import namedtuple

Sym = namedtuple("Sym", "symbol mnemonic srcfile")

_ADDR = re.compile(r"([0-9A-Fa-f]{2})/([0-9A-Fa-f]{4})")
_MNEM = re.compile(r"\b([A-Z]{3})\b")          # 65816 mnemonics are 3 upper letters
_LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)")

class SymbolTable:
    def __init__(self):
        self._by_off = {}   # offset -> Sym  (code lines only)
        self._offsets = []  # sorted offsets

    @classmethod
    def from_listing(cls, path):
        st = cls()
        cur_sym = "?"
        with open(path, errors="replace") as f:
            for line in f:
                cols = line.split("|")
                if len(cols) < 3:
                    continue
                srcfile = cols[1].split()[-1] if cols[1].split() else ""
                m = _ADDR.search(line)
                if not m:
                    continue
                off = int(m.group(2), 16)
                # trailing field = label/code body (after the last '|')
                body = cols[-1].rstrip("\n")
                # a label is a non-blank token at column 0 of the body
                lab = _LABEL.match(body.strip()) if body[:1] not in (" ", "\t", "") else None
                if body and not body[0].isspace():
                    lm = _LABEL.match(body.strip())
                    if lm and lm.group(1) not in ("ENT", "EQU", "MAC", "DFB", "DA", "HEX"):
                        cur_sym = lm.group(1)
                # mnemonic = first 3-upper token AFTER any leading label
                mm = _MNEM.search(body)
                mnem = mm.group(1) if mm else ""
                # only record lines that actually emit/anchor code (have a mnemonic
                # or are a label anchor); skip pure comments/equates with no addr change
                st._by_off[off] = Sym(cur_sym, mnem, srcfile)
        st._offsets = sorted(st._by_off)
        return st

    def lookup(self, offset):
        import bisect
        i = bisect.bisect_right(self._offsets, offset) - 1
        if i < 0:
            return None
        return self._by_off[self._offsets[i]]
```

- [ ] **Step 5: Run the test, expect pass**

Run: `cd tools/profile && python3 -m pytest tests/test_seg0map.py -q`
Expected: PASS (2 passed). If `pytest` is unavailable, add `if __name__ == "__main__":` runners and run `python3 tests/test_seg0map.py`.

- [ ] **Step 6: Commit**

```bash
git add tools/profile/seg0map.py tools/profile/tests/test_seg0map.py tools/profile/tests/fixtures/mini_seg0.txt
git commit  # message: "feat(profile): seg0 -V listing parser -> address/symbol/mnemonic/srcfile map" + trailer
```

---

### Task 2: attribution categories

**Files:**
- Modify: `tools/profile/seg0map.py` (add `categorize`)
- Modify: `tools/profile/tests/test_seg0map.py` (add tests)

**Interfaces:**
- Consumes: `Sym` from Task 1.
- Produces: `CATEGORIES = ("user_body","call_glue","prologue_epilogue","libc","kernel_io","unknown")`; `categorize(sym: Sym|None, in_tool_bank: bool) -> str`.

- [ ] **Step 1: Write the failing test** (append to `test_seg0map.py`):

```python
from seg0map import categorize

def test_categorize():
    user_jsr = Sym("main", "JSR", "sed.s")
    user_lda = Sym("main", "LDA", "sed.s")
    user_tcs = Sym("main", "TCS", "sed.s")
    libc_lda = Sym("_fcc_memcpy", "LDA", "../../src/userland/lib/string.s")
    assert categorize(user_jsr, True) == "call_glue"
    assert categorize(user_tcs, True) == "prologue_epilogue"
    assert categorize(user_lda, True) == "user_body"
    assert categorize(libc_lda, True) == "libc"
    assert categorize(user_lda, False) == "kernel_io"     # sample outside tool banks
    assert categorize(None, True) == "unknown"
```

- [ ] **Step 2: Run it, expect failure** (`ImportError: categorize`).

- [ ] **Step 3: Implement `categorize` in `seg0map.py`:**

```python
CATEGORIES = ("user_body","call_glue","prologue_epilogue","libc","kernel_io","unknown")

_CALL_GLUE = {"JSR","JSL","RTS","RTL","RTI"}
_FRAME = {"TSC","TCS"}   # frame establish/teardown markers (unique to prologue/epilogue)

def _is_libc(sym):
    s = (sym.srcfile or "")
    return ("/lib/" in s) or s.endswith("crt0.s") or sym.symbol.startswith("_fcc_")

def categorize(sym, in_tool_bank):
    if not in_tool_bank:
        return "kernel_io"          # syscall / kernel / loader bank
    if sym is None:
        return "unknown"
    if sym.mnemonic in _CALL_GLUE:
        return "call_glue"
    if sym.mnemonic in _FRAME:
        return "prologue_epilogue"
    if _is_libc(sym):
        return "libc"
    return "user_body"
```

- [ ] **Step 4: Run the tests, expect pass** (`cd tools/profile && python3 -m pytest tests/test_seg0map.py -q`).

- [ ] **Step 5: Commit**

```bash
git add tools/profile/seg0map.py tools/profile/tests/test_seg0map.py
git commit  # "feat(profile): 5-category attribution (user/glue/frame/libc/kernel-IO)" + trailer
```

---

### Task 3: relocation + profile builder + report renderer

**Files:**
- Create: `tools/profile/profile_report.py`
- Create: `tools/profile/tests/test_profile_report.py`

**Interfaces:**
- Consumes: `SymbolTable`, `categorize`, `CATEGORIES` from Tasks 1–2.
- Produces: `detect_tool_banks(samples:dict) -> set[int]` (banks holding ≥ THRESH of samples); `build_profile(samples:dict, st:SymbolTable, tool_banks:set) -> dict` returning `{"by_category": {cat: count}, "by_symbol": [(symbol, count), …], "total": N}`; `render_report(profiles:dict, meta:dict) -> str`. Sample keys are `"BB:OOOO"` strings (hex bank:offset); values are int counts.

- [ ] **Step 1: Write the failing test** `tools/profile/tests/test_profile_report.py`:

```python
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from seg0map import SymbolTable
from profile_report import detect_tool_banks, build_profile, render_report

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "mini_seg0.txt")

def test_detect_tool_banks_picks_dominant():
    samples = {"0B:0112": 50, "0B:0358": 40, "00:1234": 2}  # bank 0B dominates
    assert detect_tool_banks(samples) == {0x0B}

def test_build_profile_categorizes():
    st = SymbolTable.from_listing(FIX)
    samples = {"0B:0113": 10, "0B:0358": 30, "00:9999": 5}  # JSR / LDA / kernel
    prof = build_profile(samples, st, {0x0B})
    assert prof["total"] == 45
    assert prof["by_category"]["call_glue"] == 10      # 0B:0113 = JSR
    assert prof["by_category"]["user_body"] == 30      # 0B:0358 = LDA in _sed_match
    assert prof["by_category"]["kernel_io"] == 5       # bank 00 not a tool bank

def test_render_report_has_sections():
    prof = {"sed": ({"by_category": {"user_body": 30, "call_glue": 10}, "by_symbol": [("_sed_match", 30)], "total": 40}, {"wall_s": 12.3})}
    out = render_report(prof, {"date": "2026-06-28"})
    assert "user_body" in out and "_sed_match" in out and "12.3" in out
```

- [ ] **Step 2: Run it, expect failure** (`ModuleNotFoundError: profile_report`).

- [ ] **Step 3: Implement `tools/profile/profile_report.py`:**

```python
"""Relocate runtime bank:offset samples -> symbol/category; render a profile report."""
import json, sys, argparse
from collections import Counter
from seg0map import SymbolTable, categorize, CATEGORIES

_BANK_THRESH = 0.10   # a bank holding >=10% of samples is treated as a tool code bank

def _parse_key(k):
    bank, off = k.split(":")
    return int(bank, 16), int(off, 16)

def detect_tool_banks(samples):
    by_bank = Counter()
    total = 0
    for k, n in samples.items():
        b, _ = _parse_key(k); by_bank[b] += n; total += n
    if total == 0:
        return set()
    return {b for b, n in by_bank.items() if n / total >= _BANK_THRESH}

def build_profile(samples, st, tool_banks):
    cats = Counter(); syms = Counter(); total = 0
    for k, n in samples.items():
        b, off = _parse_key(k); total += n
        in_tool = b in tool_banks
        sym = st.lookup(off) if in_tool else None
        cats[categorize(sym, in_tool)] += n
        syms[(sym.symbol if sym else f"bank{b:02X}")] += n
    return {"by_category": {c: cats.get(c, 0) for c in CATEGORIES},
            "by_symbol": syms.most_common(25), "total": total}

def render_report(profiles, meta):
    L = [f"# fcc real-world profile — {meta.get('date','')}", ""]
    for tool, (prof, tmeta) in profiles.items():
        t = prof["total"] or 1
        L += [f"## {tool}  (wall {tmeta.get('wall_s','?')} s, {prof['total']} samples)", "",
              "| category | % |", "|---|---|"]
        for c in CATEGORIES:
            L.append(f"| {c} | {prof['by_category'][c]*100.0/t:.1f}% |")
        L += ["", "| symbol | % |", "|---|---|"]
        for s, n in prof["by_symbol"]:
            L.append(f"| {s} | {n*100.0/t:.1f}% |")
        L.append("")
    return "\n".join(L)

def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples", required=True, help="pc_samples.json from the plugin")
    ap.add_argument("--listing", required=True, help="build/userbin_<tool>_seg0_Output.txt")
    ap.add_argument("--tool", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args(argv)
    sj = json.load(open(a.samples))
    samples = sj["samples"]; meta = {"wall_s": sj.get("wall_s")}
    st = SymbolTable.from_listing(a.listing)
    banks = detect_tool_banks(samples)
    prof = build_profile(samples, st, banks)
    open(a.out, "w").write(render_report({a.tool: (prof, meta)}, {"date": "2026-06-28"}))
    print(f"tool_banks={sorted(hex(b) for b in banks)} total={prof['total']}")
    for c in CATEGORIES:
        print(f"  {c:18} {prof['by_category'][c]*100.0/(prof['total'] or 1):5.1f}%")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests, expect pass** (`cd tools/profile && python3 -m pytest tests/ -q` → 3+ passed).

- [ ] **Step 5: Commit**

```bash
git add tools/profile/profile_report.py tools/profile/tests/test_profile_report.py
git commit  # "feat(profile): relocation + profile builder + report renderer" + trailer
```

---

### Task 4: PC-sampler hook in the fgxdebug MAME plugin

**Files:**
- Modify: `tools/mame_test/plugins/fgxdebug/init.lua` (add a gated per-frame PC sampler)
- Reference (read first): the existing `cycle_markers` block and the reset/stop notifiers + the `emu.time()` / `io.open` output path in the same file.

**Interfaces:**
- Consumes: a config key the run.py config writer will add in Task 5: `"pc_sample": {"out": "<path>"}` (presence = enable).
- Produces: at the dump point, a JSON file `{"samples": {"BB:OOOO": count, …}, "total": N, "wall_s": <emu.time delta>}` matching what `profile_report.main` reads (Task 3).

- [ ] **Step 1: Read the plugin to find the hooks.** `cd tools/mame_test/plugins/fgxdebug && grep -n "machine_reset_notifier\|cpu\.state\|emu.time\|io.open\|frame\|add_notifier\|dump" init.lua` — confirm where `cpu` is attached (`manager.machine.devices[":maincpu"]`) and where output is written.

- [ ] **Step 2: Add the sampler state + per-frame callback.** Near the existing config parse, read the new key; on machine reset (where `cpu`/`mem` are bound), register a frame notifier that reads the program-bank + PC from `cpu.state` and increments a Lua table. Use the bank-aware program counter; in MAME's 65816 core the relevant state entries are the program-bank register and PC (confirm exact key names via `for k,_ in pairs(cpu.state) do emu.print_info(k) end` on first run — the listing in §Step-1 of run.py output names them). Concretely:

```lua
-- near other config fields:
local pc_sample_out = cfg and cfg.pc_sample and cfg.pc_sample.out or nil
local pc_hist, pc_total, pc_t0 = {}, 0, nil

-- inside the machine_reset_notifier, after `cpu = ...; mem = ...`:
if pc_sample_out then
    pc_t0 = emu.time and emu.time() or nil
    emu.add_frame_notifier(function()       -- ~60 Hz
        local pb = cpu.state["PB"] and cpu.state["PB"].value or 0
        local pc = cpu.state["CURPC"] and cpu.state["CURPC"].value or
                   (cpu.state["PC"] and cpu.state["PC"].value or 0)
        local key = string.format("%02X:%04X", pb & 0xFF, pc & 0xFFFF)
        pc_hist[key] = (pc_hist[key] or 0) + 1
        pc_total = pc_total + 1
    end)
end
```
(If `emu.add_frame_notifier` is unavailable in this MAME build, fall back to the same per-frame hook the plugin already uses for its dump-frame countdown — reuse that loop to sample.)

- [ ] **Step 3: Write the sampler output at the dump point.** Where the plugin writes its existing JSON dump, also (when `pc_sample_out` set) write:

```lua
if pc_sample_out then
    local f = io.open(pc_sample_out, "w")
    if f then
        local parts = {}
        for k, v in pairs(pc_hist) do parts[#parts+1] = string.format('"%s":%d', k, v) end
        local wall = (pc_t0 and emu.time) and (emu.time() - pc_t0) or 0
        f:write(string.format('{"samples":{%s},"total":%d,"wall_s":%.3f}',
                              table.concat(parts, ","), pc_total, wall))
        f:close()
        emu.print_info("fgxdebug: wrote pc samples -> " .. pc_sample_out)
    end
end
```

- [ ] **Step 4: Smoke-test the sampler** with an existing test plus the new key. Temporarily add `"pc_sample":{"out":"/tmp/pc.json"}` to a copy of `tools/mame_test/tests/sed_file.json`, run `python3 tools/mame_test/run.py <that test>` (after Task 5 wires config; until then, hand-write `/tmp/fgx_debug_config.json` with the key and boot once). Expected: `/tmp/pc.json` exists, parses as JSON, `total` > 100 for a multi-second run, and keys look like `"0B:034B"` / the tool's runtime bank.

- [ ] **Step 5: Verify no regression to existing runs.** Run one ordinary (no `pc_sample` key) test: `python3 tools/mame_test/run.py sed_file` → still passes, and no `/tmp/pc.json` written. This proves the gate.

- [ ] **Step 6: Commit**

```bash
git add tools/mame_test/plugins/fgxdebug/init.lua
git commit  # "feat(profile): gated PC-sampler hook in fgxdebug MAME plugin" + trailer
```

---

### Task 5: profiling driver (build old/new tool + run both sampled + report)

**Files:**
- Create: `tools/profile/run_profile.sh`
- Create: `tools/profile/workloads/heavy.sed`, `tools/profile/workloads/big.txt`, `tools/profile/workloads/big.s`
- Modify: `tools/mame_test/run.py` (only if needed) to pass a `pc_sample` key from the test manifest into the plugin config (the config writer is `build_plugin_config`, ~line 150).

**Interfaces:**
- Consumes: `profile_report.main` (Task 3), the PC-sampler (Task 4), `build_userbin_fgx2_c` (`lib/build_common.sh`), the scratchpad fcc binaries (`fcc-5692a76` = old, `fcc-head` = new) or rebuilds them.
- Produces: `pc_samples.<tool>.<fcc>.json` per run; a printed before/after wall-clock; invokes `profile_report.py` to emit per-tool reports.

- [ ] **Step 1: Create the workloads.** `heavy.sed` = several substitution + address-range rules; `big.txt` = a generated multi-KB input the rules hit repeatedly (size it so the sed run is ≥10 s GS time — start ~50–100 KB, tune in Step 5). `big.s` = a large valid assembler input for `fas` (concatenate/replicate an existing `toolchain/src/as/tests/**/*.s` to ~hundreds of lines so assembly takes ≥10 s GS time). Verify each is valid on the host reference first: `sed -f tools/profile/workloads/heavy.sed tools/profile/workloads/big.txt | head` produces sane output.

- [ ] **Step 2: Write `run_profile.sh` with the silent-rebuild guard.** For each (tool ∈ {sed, fas}, fcc ∈ {old, new}): copy the chosen fcc to `toolchain/fcc`, **assert** `./toolchain/fcc --version` contains the intended commit, build the tool via `build_userbin_fgx2_c` in a subshell that sets `PROJECT_ROOT` *after* `source lib/build_common.sh`, and abort if the build log contains "Building fcc" (the silent-rebuild trap). Stage the tool binary + workload onto the runtime disk; write a run.py test manifest carrying `command` (`time sed -f /…/heavy.sed /…/big.txt > /dev/null`, or the fas equivalent) and `pc_sample.out`; run it; copy out the samples JSON. Restore `toolchain/fcc` to the HEAD build at the end.

```bash
#!/bin/bash
set -u
ROOT=~/projects/Retro/Apple/fgx
SP="$(dirname "$0")/out"; mkdir -p "$SP"
assert_fcc() { ./toolchain/fcc --version 2>&1 | grep -q "$1" || { echo "FCC MISMATCH: want $1"; exit 3; }; }
build_tool() { # $1=fccbin $2=want-version-substr $3=tool
  cp "$1" "$ROOT/toolchain/fcc"; ( cd "$ROOT"; assert_fcc "$2" )
  ( cd "$ROOT"; source lib/build_common.sh >/dev/null 2>&1; PROJECT_ROOT="$ROOT"
    log=$(build_userbin_fgx2_c "$3" 2>&1); echo "$log" | grep -q "Building fcc" && { echo "SILENT REBUILD"; exit 4; } || true )
}
# ... per (tool,fcc): build_tool; stage on disk; write manifest with pc_sample.out; run.py; collect samples ...
# ... then: profile_report.py --samples … --listing build/userbin_<tool>_seg0_Output.txt --tool <tool> --out …
```
(Fill the staging + run.py invocation by mirroring how `tools/mame_test/tests/sed_file.json` is run; the listing path is `build/userbin_<tool>_seg0_Output.txt`, produced by the build.)

- [ ] **Step 3: Wire `pc_sample` through run.py if needed.** In `build_plugin_config` (`tools/mame_test/run.py`), pass `manifest.get("pc_sample")` into the plugin config dict so the manifest's `pc_sample` reaches `/tmp/fgx_debug_config.json`. Add nothing else.

- [ ] **Step 4: Run the driver for new-fcc only first** (fast iteration): `bash tools/profile/run_profile.sh sed new`. Expected: a samples JSON with `total` in the thousands and a printed category breakdown; `tool_banks` is a single bank (sed's runtime code bank).

- [ ] **Step 5: Tune workload length + validate relocation.** Confirm the run is ≥10 s GS (`total` ≥ ~600 at 60 Hz); if short, enlarge `big.txt`/`big.s`. Validate relocation (spec §8.1): the top symbols are real sed/fas functions (not `bank??`/`unknown`), and startup samples land near `main`. If most samples are `unknown`/`kernel_io`, the bank detection or offset relocation is wrong — fix before proceeding.

- [ ] **Step 6: Commit**

```bash
git add tools/profile/run_profile.sh tools/profile/workloads/
git commit  # "feat(profile): driver + fas/sed workloads (old/new fcc, silent-rebuild guard)" + trailer
```

---

### Task 6: full run + report + recommended lever

**Files:**
- Create: `docs/history/2026-06-28-fcc-realworld-profile-report.md`

**Interfaces:**
- Consumes: the driver (Task 5) and `profile_report.render_report` (Task 3).

- [ ] **Step 1: Run all four** combinations: `for t in sed fas; do for v in old new; do bash tools/profile/run_profile.sh $t $v; done; done`. Collect the 4 samples JSONs + the 2 (new-fcc) per-tool category profiles + the 4 wall-clock `time` outputs (old vs new, per tool).

- [ ] **Step 2: Cross-check accuracy (spec §8.2).** Pick the #1 hot user function from the sed profile; wrap it with the existing `cycle_markers` (write-tap at its entry + exit), re-run, and confirm its marker-measured time share is within statistical error of its sampled share. If they diverge >~2×, the sampler cadence is too coarse — densify per spec §4.1 and re-run.

- [ ] **Step 3: Confirm determinism (spec §8.3).** Run the sed new-fcc profile twice; the top-10 symbols and category roll-up must agree within noise. If not, raise the support threshold / lengthen the workload.

- [ ] **Step 4: Write the report** `docs/history/2026-06-28-fcc-realworld-profile-report.md`: for fas and sed — the category roll-up table, the top-15 hot symbols, the **old-fcc vs new-fcc whole-tool wall-clock** (the real before/after the user asked for), and a **Recommended lever** section that reads the dominant category off the spec §6 decision table with a one-paragraph rationale and the expected blast radius.

- [ ] **Step 5: Commit**

```bash
git add docs/history/2026-06-28-fcc-realworld-profile-report.md
git commit  # "docs(profile): fas+sed real-world cycle profile + recommended lever" + trailer
```

---

## Self-Review

**Spec coverage:** §3 mechanism (PC sampling) → Task 4; §4.1 plugin hook → Task 4; §4.2 post-processor (parse/relocate/map/categorize) → Tasks 1–3; §4.3 workloads + old/new before/after → Tasks 5–6; §4.4 report → Task 6; §5 categories → Task 2; §6 decision table → Task 6 Step 4; §7 risks (bank relocation → Task 5 Step 5 validation; sample density → Task 6 Step 2; silent-rebuild guard → Task 5 Step 2; libc/kernel tagging → Task 2 `categorize`); §8 validation → Task 6 Steps 2–3; §9 deliverables → all tasks. No gaps.

**Placeholder scan:** Task 5's `run_profile.sh` staging/run.py invocation is described as "mirror sed_file.json" rather than full code — this is the one integration step that depends on local run.py specifics the implementer must read; everything testable (Tasks 1–3) has complete code. Flagged, acceptable: it is bounded ("mirror the existing test"), not a logic placeholder.

**Type consistency:** sample-key format `"BB:OOOO"` is consistent across Task 3 (`_parse_key`), Task 4 (plugin emits `"%02X:%04X"`), and the tests. `Sym(symbol, mnemonic, srcfile)` field order is consistent Tasks 1–3. `CATEGORIES` tuple is the single source for category names in Tasks 2–3. The samples JSON shape (`{"samples":…, "total":…, "wall_s":…}`) matches between Task 4 (writer) and Task 3 (`main` reader).
