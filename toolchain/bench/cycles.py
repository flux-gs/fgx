#!/usr/bin/env python3
"""fbench cycle measurement — emu.time() captured at the exact marker WRITES
(install_write_tap), avoiding the ~60Hz frame-boundary quantization that makes
small Tier-1 deltas invisible.

MAME is resolved the FGX way (see lib/mame_env.sh): the $MAME env var, else the
Ample fork app bundle, else mame64/mame on PATH; support dir (roms + plugins)
from $FGX_MAME_SUPPORT, else the Ample support dir. Verified against the Ample
MAME v0.287 build: emu.time(), install_write_tap, and mem:write_u8 all work;
cpu:total_cycles() does NOT exist on this build, so cycles are emu.time()*clock_hz
(absolute value assumes IIgs slow mode 1.023 MHz — the authoritative number is the
baseline-vs-current DELTA on the same machine)."""
import os, re, subprocess, tempfile

_AMPLE_MAME = "/Applications/Ample.app/Contents/MacOS/mame64"
_AMPLE_SUPPORT = os.path.expanduser("~/Library/Application Support/Ample")

def _which(name):
    for d in os.environ.get("PATH", "").split(os.pathsep):
        p = os.path.join(d, name)
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return None

def resolve_mame():
    """Return (mame_bin, roms_dir, plugins_dir) or (None, None, None)."""
    mame = os.environ.get("MAME")
    if not mame or not os.access(mame, os.X_OK):
        mame = _AMPLE_MAME if os.access(_AMPLE_MAME, os.X_OK) else (_which("mame64") or _which("mame"))
    if not mame or not os.access(mame, os.X_OK):
        return (None, None, None)
    support = os.environ.get("FGX_MAME_SUPPORT", _AMPLE_SUPPORT)
    return (mame, os.path.join(support, "roms"), os.path.join(support, "plugins"))

def mame_available():
    return resolve_mame()[0] is not None

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
  cpu.state["D"].value=0; cpu.state["E"].value=0    -- native mode set here; S set by crt0_bench
  print("MAME-LOADED bytes="..#d)
end)
'''

def parse_total_cyc(text):
    m = re.search(r"total_cyc=([0-9.]+)", text)
    return float(m.group(1)) if m else None

def run_binary(bin_path, clock_hz=1023000, secs=30, timeout=90):
    mame, roms, plugins = resolve_mame()
    if not mame:
        return None
    lua = _LUA % {"BIN": bin_path, "HZ": clock_hz}
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as f:
        f.write(lua); lp = f.name
    env = dict(os.environ, SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
    try:
        cp = subprocess.run([mame, "apple2gs", "-rompath", roms,
                             "-pluginspath", plugins, "-autoboot_script", lp,
                             "-video", "none", "-sound", "none", "-nothrottle",
                             "-seconds_to_run", str(secs)],
                            capture_output=True, text=True, env=env, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None
    finally:
        os.unlink(lp)
    return parse_total_cyc(cp.stdout + cp.stderr)
