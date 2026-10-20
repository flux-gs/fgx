import json, subprocess, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
def run(*a): return subprocess.run([sys.executable, os.path.join(HERE,"fbench.py"),*a],
                                    capture_output=True, text=True)
def test_snapshot_size_and_provenance(tmp_path):
    out = tmp_path/"snap.json"
    r = run("snapshot","t","--no-cycles","--out",str(out)); assert r.returncode==0, r.stderr
    d = json.loads(out.read_text())
    assert d["size"]["goldens"]["total_bytes"] > 0
    assert "kernel_bytes" in d["system"]
    assert "toolchain_git" in d        # provenance is the toolchain submodule, not fgx
    assert "fgx_git" in d
def test_report_makedirs_on_fresh_tree(tmp_path):
    # report must not crash when reports/ is absent
    r = run("report"); assert r.returncode == 0, r.stderr

import importlib.util
def _load(m,p):
    s=importlib.util.spec_from_file_location(m,os.path.join(HERE,p)); mod=importlib.util.module_from_spec(s); s.loader.exec_module(mod); return mod
def test_parse_total_cyc():
    cyc=_load("cycles","cycles.py")
    assert abs(cyc.parse_total_cyc("MAME-CYC total_cyc=2046.0")-2046.0) < 1e-6
    assert cyc.parse_total_cyc("no match here") is None
