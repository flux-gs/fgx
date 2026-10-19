#!/usr/bin/env python3
"""
kprobe.py — non-perturbing kernel probe for FGX under MAME.

WHY
---
Some FGX bugs are *layout/size-sensitive Heisenbugs*: adding any instrumentation
to the kernel or a userland binary shifts the code/data layout and the bug
changes or vanishes (e.g. the sed "read returns 0" bug — see
docs/RESUME-2026-06-23-sed-read-heisenbug.md).  You cannot debug those by
editing source, because editing source IS the perturbation.

kprobe runs the *unmodified* disk image and uses MAME's hardware debugger
(`-debug -debugger none -debugscript`) to set hardware **breakpoints** and
**watchpoints** at kernel addresses.  When one fires, a debugger action copies a
few captured expressions (PC, the written value, current values of named kernel
variables, …) into a **scratch RAM ring**.  The existing `fgxdebug` plugin then
dumps that ring at exit, and kprobe parses + prints the captured events.

Because the binary on disk is never changed, the Heisenbug manifests exactly as
in a normal run — kprobe only *observes*.

KERNEL RELOCATION
-----------------
The kernel assembles at ORG $02 but relocates to a runtime bank (e.g. $7D) chosen
by the loader.  kprobe never hard-codes that bank: the generated debugscript
reads the live kernel bank from the loader anchor at $00:032C (magic $4B at
$00:032D, same anchor the fgxdebug plugin uses) the first time the bank-0 syscall
JT gateway at $00:032E executes (which is post-boot, so the anchor is valid), and
resolves every kernel-bank-relative address against it.

USAGE
-----
    python3 tools/mame_test/kprobe.py probes/<name>.json
    python3 tools/mame_test/kprobe.py <name>          # -> probes/<name>.json
    python3 tools/mame_test/kprobe.py probes/<name>.json --window   # visible MAME

See tools/mame_test/KPROBE.md for the probe-config schema and worked examples.

EXTENDING
---------
Probe configs are JSON (see KPROBE.md).  A probe is a `command` to autoboot plus a
list of `watch` (watchpoints) and `brk` (breakpoints), each capturing a list of
`fields` (MAME debugger expressions, with FGX shorthands — see FIELD SHORTHANDS).
Add new symbols by name (resolved from the kernel listing) or by raw offset.
Nothing here is sed-specific.
"""

import argparse
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
PROBES_DIR = HERE / "probes"
BUILD_DIR = REPO / "build"
CFG_PATH = Path("/tmp/fgx_debug_config.json")   # hard-coded in the plugin

# Reuse run.py's paths + plugin-config builder + plugin sync, without running
# its main().  (run.py guards main() under `if __name__ == "__main__"`.)
_spec = importlib.util.spec_from_file_location("fgx_run", HERE / "run.py")
run = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(run)

# Loader anchor for the live kernel bank (see fgxdebug init.lua ~line 247).
KBANK_BYTE_ADDR = 0x00032C       # live kernel bank
KBANK_MAGIC_ADDR = 0x00032D      # == 0x4B when the anchor is valid
JT_GATEWAY_ADDR = 0x00032E       # bank-0 syscall JT gateway — hit on every syscall

# Scratch ring defaults (bank-0 RAM kprobe writes captured events into).
# Layout: dword[0] = event count; events follow at +8, each = nfields dwords.
DEFAULT_SCRATCH = 0x008000
RING_HEADER = 8                  # bytes before the first event slot

# Kernel listings to resolve symbols from (Merlin -V output).
LISTINGS = [
    BUILD_DIR / "fgx_S01_KernelMain_Output.txt",
    BUILD_DIR / "fgx_S02_BlockDriver_Output.txt",
]


# --------------------------------------------------------------------------- #
# Symbol resolution
# --------------------------------------------------------------------------- #
_sym_cache = {}


def resolve_sym(name):
    """Resolve a kernel symbol to (bank, offset).

    Greps the Merlin -V listings for the symbol's address column, e.g.
        ... | 02/F3AE : 00 00 00 00 | _fsFileState   DS  $0040 ...
        ... | 00/032E : ...          | _JT_...
    Returns (bank, offset).  bank 0x02 means kernel-bank-relative (relocates);
    bank 0x00 means a fixed bank-0 address.  Raises if not found.
    """
    if name in _sym_cache:
        return _sym_cache[name]
    # Listing rows look like:
    #   ... | 02/F3AE : 00 00 00 00 | _fsFileState   DS  $0040   ; comment
    #   ... | 02/2000               | Some_Label     ENT
    # The address is "BB/AAAA" (optionally ": bytes"); the SOURCE column follows
    # the final "|".  We resolve only when the source column's FIRST token is the
    # symbol — so comments ("; Fs_ReadN scratch") and operand uses don't match.
    # Note: EQU ("Equivalence") rows carry no address column and won't resolve —
    # give those an explicit "off" in the probe (see KPROBE.md).
    pat = re.compile(r"([0-9A-F]{2})/([0-9A-F]{4})(?:\s*:[^|]*)?\|\s*(\S+)")
    for lst in LISTINGS:
        if not lst.exists():
            continue
        for line in lst.read_text(errors="replace").splitlines():
            m = pat.search(line)
            if m and m.group(3) == name:
                bank, off = int(m.group(1), 16), int(m.group(2), 16)
                _sym_cache[name] = (bank, off)
                return bank, off
    raise SystemExit(f"kprobe: symbol {name!r} not found in kernel listings "
                     f"(it may be an EQU/ENT with no address column — give an "
                     f"explicit \"off\" instead; see KPROBE.md).")


def addr_of(spec):
    """A watch/brk entry's address.  Either {"sym": NAME} or {"off": HEX[, bank]}.

    Returns (bank, offset).  For kernel-bank (bank 0x02) the live runtime bank is
    substituted in the debugscript via the `kb()` expression helper below.
    """
    if "sym" in spec:
        return resolve_sym(spec["sym"])
    if "off" in spec:
        off = int(str(spec["off"]), 16) if isinstance(spec["off"], str) else spec["off"]
        return spec.get("bank", 0x02), off & 0xFFFF
    raise SystemExit(f"kprobe: watch/brk entry needs \"sym\" or \"off\": {spec}")


# --------------------------------------------------------------------------- #
# Debugger-expression field shorthands
# --------------------------------------------------------------------------- #
# Captured `fields` are MAME debugger expressions.  We expand a few FGX
# shorthands first so probe configs stay readable and bank-agnostic:
#   {PC}        -> full 24-bit program counter (pb<<16 | pc)
#   {VAL}       -> wpdata  (the value written; watchpoints only)
#   {A}{X}{Y}{S}{D}  -> the 65816 registers
#   {kb:X}      -> dword read of kernel-bank symbol-or-offset X at the live bank
#                  i.e. d@((kbank<<16) | off)  where off = off_of(X) or 0xX
#   {kbw:X}     -> word (16-bit) read ; {kbb:X} -> byte read
#                  X is a symbol name (resolved from the listing) OR a hex offset
#                  like 0xF3B0 (for EQU fields that don't resolve).
# `kbank` is the live kernel bank, resolved in phase 1 and baked in here, so the
# generated debugscript has concrete addresses and ZERO nested action quoting.
def expand_field(expr, kbank):
    out = expr
    out = out.replace("{PC}", "(pb*65536+pc)")
    out = out.replace("{VAL}", "wpdata")
    for r in ("a", "x", "y", "s", "d"):
        out = out.replace("{%s}" % r.upper(), r)

    def kb(m):
        width, x = m.group(1), m.group(2)
        off = int(x, 16) if x.lower().startswith("0x") else resolve_sym(x)[1]
        addr = "0x%06X" % ((kbank << 16) | off)
        return {"kb": "d@", "kbw": "w@", "kbb": "b@"}[width] + addr

    out = re.sub(r"\{(kb|kbw|kbb):(0x[0-9A-Fa-f]+|[A-Za-z_][A-Za-z0-9_]*)\}", kb, out)
    return out


def kaddr(spec, kbank):
    """Concrete 24-bit address for a watch/brk entry, given the live kernel bank."""
    bank, off = addr_of(spec)
    return ((kbank if bank == 0x02 else bank) << 16) | off


# --------------------------------------------------------------------------- #
# Debugscript generation
# --------------------------------------------------------------------------- #
def gen_debugscript(probe, kbank, scratch, max_events):
    """Generate the MAME debugscript text for this probe.

    The live kernel bank is already known (phase 1), so every wp/bp address is
    concrete and each has exactly ONE action level — no nested action quoting
    (MAME can't parse `"... wpset ...,"...""`).

    The scratch ring is CIRCULAR: slot = (count mod max_events).  Boot-time file
    I/O can write a watched kernel var many times before the command under test
    runs; a circular ring keeps the LAST `max_events` writes (the ones around the
    failure), while dword[0] records the total count.

      temp0 = total event count (monotonic)
      temp2 = scratch slot index = temp0 - (temp0/max)*max   (MAME `/` is integer)
    """
    nfields_max = max((len(w.get("fields", [])) for w in
                       probe.get("watch", []) + probe.get("brk", [])), default=1)
    stride = nfields_max * 4

    def capture_action(fields):
        parts = ["temp2=temp0-(temp0/%d)*%d" % (max_events, max_events)]
        slot = "(0x%X+%d+temp2*%d)" % (scratch, RING_HEADER, stride)
        for i, f in enumerate(fields):
            parts.append("d@(%s+%d)=%s" % (slot, i * 4, expand_field(f, kbank)))
        parts.append("temp0=temp0+1")
        parts.append("d@0x%X=temp0" % scratch)
        parts.append("go")
        return " ; ".join(parts)

    lines = [
        "; kprobe generated debugscript — DO NOT EDIT (regenerated each run)",
        "; kernel_bank=$%02X  temp0=count  temp2=ring slot" % kbank,
        "temp0=0",
        "d@0x%X=0" % scratch,
    ]
    for w in probe.get("watch", []):
        a = kaddr(w, kbank)
        lines.append('wpset 0x%06X,%d,%s,1,"%s"'
                     % (a, w.get("len", 1), w.get("type", "w"),
                        capture_action(w.get("fields", ["{PC}"]))))
    for b in probe.get("brk", []):
        a = kaddr(b, kbank)
        lines.append('bpset 0x%06X,1,"%s"' % (a, capture_action(b.get("fields", ["{PC}"]))))
    lines.append("go")
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------- #
# Run
# --------------------------------------------------------------------------- #
def _mame_args(disk, command, *, debugscript=None, window=False):
    SUP = run.AMPLE_SUP
    args = [
        run.MAME, "apple2gs", "-skip_gameinfo", "-ramsize", "8M",
        "-window", "-nounevenstretch",
        "-homepath", str(SUP), "-rompath", str(SUP / "roms"),
        "-artpath", str(SUP / "artwork"), "-nvram_directory", str(SUP / "nvram"),
        "-state_directory", str(run.STATE_DIR),
        "-pluginspath", str(run.AMPLE_PLUGINS), "-plugin", "fgxdebug",
        "-sl7", "retronet", "-hard1", str(disk), "-natural",
        "-autoboot_delay", "12", "-autoboot_command", command + "\\n",
    ]
    if debugscript:
        args += ["-debug", "-debugger", "none", "-debugscript", str(debugscript)]
    if window:
        args += ["-resolution", "1408x924", "-video", "bgfx", "-bgfx_path", str(SUP / "bgfx")]
    else:
        args += ["-video", "none", "-sound", "none"]
    return args


def _launch(args, *, cwd, timeout_s, window=False, label=""):
    env = os.environ.copy()
    if not window:
        env["SDL_VIDEODRIVER"] = "dummy"
    so = open(cwd / "mame_stdout.log", "w")
    se = open(cwd / "mame_stderr.log", "w")
    proc = subprocess.Popen(args, stdout=so, stderr=se, env=env)
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if proc.poll() is not None:
            break
        time.sleep(0.5)
    else:
        if label:
            print(f"  timeout ({timeout_s}s){label} — SIGKILL")
        proc.kill()
    proc.wait()
    so.close(); se.close()


def get_kernel_bank(disk, scratch_dir):
    """Phase 1: resolve the live kernel bank (cached by disk mtime).

    The kernel relocates to a runtime bank chosen by the loader; we boot once
    with the fgxdebug plugin (which reports `kernel_bank`) and cache it so
    repeated probes on the same disk skip the extra boot.  Knowing the bank up
    front lets the phase-2 debugscript use concrete addresses (no nested-action
    quoting).
    """
    mtime = int(disk.stat().st_mtime)
    cache = Path("/tmp/fgx_kprobe_kbank.json")
    if cache.exists():
        try:
            c = json.loads(cache.read_text())
            if c.get("mtime") == mtime and c.get("disk") == str(disk):
                return c["bank"]
        except Exception:
            pass
    print("kprobe: phase 1 — resolving live kernel bank (one boot, cached)…")
    manifest = {"name": "kbank", "command": "echo k", "timeout_s": 4}
    cfg = run.build_plugin_config(manifest, mode="test", paste_frame=run.BOOT_FRAMES_FRESH)
    dump_path = scratch_dir / "kbank.json"
    cfg["output_path"] = str(dump_path)
    CFG_PATH.write_text(json.dumps(cfg, indent=2))
    _launch(_mame_args(disk, "echo k"), cwd=scratch_dir,
            timeout_s=run.BOOT_FRAMES_FRESH // 60 + 12, label=" (phase 1)")
    if not dump_path.exists():
        sys.exit("kprobe: phase 1 produced no dump — boot failed (see mame_stderr.log)")
    bank = json.loads(dump_path.read_text()).get("kernel_bank", 0x02)
    cache.write_text(json.dumps({"disk": str(disk), "mtime": mtime, "bank": bank}))
    print(f"  live kernel bank = ${bank:02X}")
    return bank


def run_probe(probe, *, window=False):
    name = probe.get("name", "kprobe")
    scratch = (int(str(probe["scratch"]), 16) if isinstance(probe.get("scratch"), str)
               else probe.get("scratch", DEFAULT_SCRATCH))
    max_events = probe.get("max_events", 64)
    nfields_max = max((len(w.get("fields", [])) for w in
                       probe.get("watch", []) + probe.get("brk", [])), default=1)
    ring_len = RING_HEADER + max_events * nfields_max * 4

    scratch_dir = Path(f"/tmp/fgx_kprobe_{name}")
    if scratch_dir.exists():
        shutil.rmtree(scratch_dir)
    scratch_dir.mkdir(parents=True)

    run.sync_plugin()
    src_disk = REPO / probe["disk_image"] if "disk_image" in probe else run.DISK_BASE
    if not src_disk.exists():
        sys.exit(f"kprobe: disk image {src_disk} missing — run ./build.sh disk")
    test_disk = scratch_dir / "fgx.po"
    shutil.copy(src_disk, test_disk)

    # Phase 1: live kernel bank.
    kbank = get_kernel_bank(test_disk, scratch_dir)

    # Phase 2: plugin config (autoboot the command + dump the scratch ring).
    paste_frame = run.BOOT_FRAMES_FRESH
    manifest = {
        "name": name, "command": probe["command"],
        "timeout_s": probe.get("timeout_s", 30),
        "memory_regions": ([{"name": "kprobe_ring", "addr_hex": "%06X" % scratch,
                             "len": ring_len}] + probe.get("memory_regions", [])),
    }
    cfg = run.build_plugin_config(manifest, mode="test", paste_frame=paste_frame)
    dump_path = scratch_dir / "dump.json"
    cfg["output_path"] = str(dump_path)
    CFG_PATH.write_text(json.dumps(cfg, indent=2))

    script_path = scratch_dir / "probe.cmds"
    script_path.write_text(gen_debugscript(probe, kbank, scratch, max_events))

    print(f"kprobe: phase 2 — {name}: {probe['command']!r}")
    print(f"  ring @ ${scratch:06X}, {max_events} slots x {nfields_max} fields (circular)")
    print(f"  debugscript: {script_path}")
    _launch(_mame_args(test_disk, probe["command"], debugscript=script_path, window=window),
            cwd=scratch_dir, window=window,
            timeout_s=paste_frame // 60 + probe.get("timeout_s", 30) + 12, label="")
    return parse_and_report(probe, dump_path, scratch, max_events, nfields_max)


def parse_and_report(probe, dump_path, scratch, max_events, nfields):
    if not dump_path.exists():
        print("kprobe: NO dump.json — MAME may have failed; see mame_stderr.log")
        return 1
    d = json.loads(dump_path.read_text())
    mem = d.get("memory", {})
    ring = None
    for k, v in mem.items():
        if "kprobe_ring" in k:
            ring = v["hex"]
            break
    if ring is None:
        print("kprobe: ring region not in dump (plugin/region mismatch)")
        return 1
    b = bytes.fromhex(ring)

    def dword(o):
        return b[o] | b[o + 1] << 8 | b[o + 2] << 16 | b[o + 3] << 24

    count = dword(0)
    full = count > max_events
    print(f"\nkprobe: kernel_bank=${d.get('kernel_bank', 0):02X}  "
          f"total events={count}"
          + (f"  (circular ring full — showing LAST {max_events})" if full else ""))
    # Field labels: events aren't tagged with which probe fired; if there's a
    # single watch/brk we use its labels, else show raw field columns.
    labels = None
    srcs = probe.get("watch", []) + probe.get("brk", [])
    if len(srcs) == 1:
        labels = srcs[0].get("labels") or srcs[0].get("fields")
    stride = nfields * 4
    kept = min(count, max_events)
    start = (count % max_events) if full else 0      # oldest kept slot
    for j in range(kept):
        slot = (start + j) % max_events
        gidx = (count - kept + j)                    # global event index
        base = RING_HEADER + slot * stride
        vals = [dword(base + f * 4) for f in range(nfields)]
        if labels and len(labels) == len(vals):
            row = "  ".join(f"{lab}=${v:X}" for lab, v in zip(labels, vals))
        else:
            row = "  ".join(f"f{f}=${v:X}" for f, v in enumerate(vals))
        print(f"  #{gidx:<4d} {row}")
    if count == 0:
        print("  (no events — probe never fired; check symbol/offset & that the "
              "command exercises it)")
    return 0


# --------------------------------------------------------------------------- #
def load_probe(arg):
    p = Path(arg)
    if not p.exists():
        p = PROBES_DIR / (arg if arg.endswith(".json") else arg + ".json")
    if not p.exists():
        sys.exit(f"kprobe: probe config not found: {arg}")
    return json.loads(p.read_text())


def main():
    ap = argparse.ArgumentParser(description="Non-perturbing FGX kernel probe (MAME HW debugger).")
    ap.add_argument("probe", help="probe config (path or name under probes/)")
    ap.add_argument("--window", action="store_true", help="show the MAME window")
    a = ap.parse_args()
    return run_probe(load_probe(a.probe), window=a.window)


if __name__ == "__main__":
    sys.exit(main())
