#!/usr/bin/env python3
"""net_stack_depth.py -- how deep the network code's stack goes, statically.

A task's kernel C runs on its slot's kernel.kstk bytes, and fcc puts frames on
that stack.  This walks fcc's output: a function costs its FRAMESIZE, two bytes of
saved frame pointer, a three-byte return address, and what it had pushed when it
made the call.  A call through a pointer is invisible to the walk, so INDIRECT
names the targets, and a function that makes one with no entry there is reported.

A report with no build edge: a number it prints settles a design point once.

Usage: net_stack_depth.py <object dir> [root ...]
       net_stack_depth.py --self-test
"""
import glob
import os
import re
import sys

# Who a function may reach through a pointer, read from in_proto.c's inetsw and
# the callers.  if_output is lo0's or the W5100 driver's.
PR_INPUT = ["tcp_input", "udp_input", "icmp_input", "rip_input", "rip_input"]
USRREQ = ["tcp_usrreq", "udp_usrreq", "raw_usrreq"]
OUTPUT = ["looutput", "w5output"]
INDIRECT = {
    "ipintr": PR_INPUT,
    "ip_output": OUTPUT,
    "arpresolve": OUTPUT,
    "arpwhohas": OUTPUT,
    "in_arpinput": OUTPUT,
    "raw_usrreq": ["rip_output"],
    "net_softclock": ["pfslowtimo", "pffasttimo", "if_slowtimo", "arptimer"],
    "sosend": USRREQ,
    "soreceive": USRREQ,
    "soclose": USRREQ,
    "sobind": USRREQ,
    "soconnect": USRREQ,
    "soaccept": USRREQ,
    "solisten": USRREQ,
    "sodisconnect": USRREQ,
    "soshutdown": USRREQ,
    "sorflush": [],
    "raw_input": [],
    "rawintr": USRREQ,
    "pfctlinput": [],
    "pffasttimo": [],
    "pfslowtimo": [],
    "domaininit": [],
    "rtrequest": [],
    "ifioctl": [],
    "in_pcbnotify": [],
    "icmp_input": [],
    "in_control": [],
    "if_slowtimo": [],
    "if_down": [],
    "ip_ctloutput": [],
    "m_expand": [],
    "tcp_input": [],
    "netintr": [],
    "sofree": USRREQ,
    "soabort": USRREQ,
    "sogetopt": [],
    "sosetopt": [],
    "sorwakeup": [],
    "sonewconn": USRREQ,
    "in_ifinit": ["w5ioctl"],  # if_ioctl
    # afswitch's af_hash and af_netmatch: small leaves
    "ifa_ifwithnet": [],
    "rtalloc": [],
    "rtredirect": [],
}
# Hand-written leaves: bytes below the caller.  in_cksum's frame is CK_L + saved D
# + return.  The last four are written in S3 and are guesses until it measures
# them: the copies to and from a process, the file lookup and setjmp.
LEAF = {"in_cksum": 15, "splimp": 4, "splnet": 4, "splhigh": 4,
        "splx": 3, "kc_sleep": 40, "kc_sleepi": 40, "kc_wakeup": 40, "kc_panic": 8,
        "kc_printstr": 16, "kc_ticks": 12, "kc_time": 12, "setsoftnet": 8,
        "copyin": 30, "netcopyout": 30, "getf": 20, "setjmp": 12}
# in_control is PRU_CONTROL, an ioctl: every usrreq reaches it in the walk, and no
# packet does.
NOT_FROM_THE_DRAIN = {"in_control"}
# The drain, and the socket calls a process makes, which run on its kernel slot.
ROOTS = ["netintr", "sendto", "recvfrom", "connect", "bind", "setsockopt",
         "getsockname", "shutdown", "soclose", "ifioctl", "sbselqueue"]
PUSH = {"PHA": 2, "PHX": 2, "PHY": 2, "PEI": 2, "PHP": 1, "PHB": 1, "PHD": 2,
        "PLA": -2, "PLX": -2, "PLY": -2, "PLP": -1, "PLB": -1, "PLD": -2}


def parse(lines):
    """-> ({fn: frame}, {fn: [(callee, pushed)]})"""
    frames, calls = {}, {}
    cur, delta = None, 0
    pending = None
    for line in lines:
        m = re.match(r"^([A-Za-z_]\w*)\s+ENT\b", line)
        if m:
            cur, delta = m.group(1), 0
            calls[cur] = []
            continue
        m = re.match(r"^([A-Za-z_]\w*)_FRAMESIZE\s+EQU\s+(\d+)", line)
        if m:
            frames[m.group(1)] = int(m.group(2))
            continue
        if cur is None:
            continue
        code = line.split(";")[0].split()
        if not code or line[0] not in " \t":
            continue
        op = code[0]
        if op == "PEA" and len(code) > 1 and code[1].endswith("-1") and \
                not re.match(r"_\w+_L\d+-1", code[1]):
            pending = code[1][:-2]
            continue
        if op == "RTL":
            if pending:
                calls[cur].append((pending, delta))
                pending = None
            continue
        if op in PUSH:
            delta += PUSH[op]
        if op == "TCS":
            delta = 0
    return frames, calls


def find_indirect(lines):
    """A call through a pointer: `PHK / PEA <label>-1 / ... / DEC / PHA / RTL'."""
    out = set()
    cur, armed = None, 0
    for line in lines:
        m = re.match(r"^([A-Za-z_]\w*)\s+ENT\b", line)
        if m:
            cur, armed = m.group(1), 0
            continue
        code = line.split(";")[0].split()
        if not code or line[0] not in " \t":
            continue
        if code[0] == "DEC":
            armed = 3
        elif armed:
            armed -= 1
            if code[0] == "RTL" and cur:
                out.add(cur)
                armed = 0
    return out


def depth(fn, frames, calls, indirect, memo, path, notes):
    if fn in path:
        notes.add("recursion: " + " -> ".join(path[path.index(fn):] + [fn]))
        return 0, [fn]
    if fn in memo:
        return memo[fn]
    if fn in LEAF:
        return LEAF[fn], [fn]
    if fn in NOT_FROM_THE_DRAIN:
        return 0, []
    if fn not in calls:
        notes.add("no body seen: " + fn)
        return 5, [fn]
    own = frames.get(fn, 0) + 5
    best, chain = 0, []
    edges = list(calls[fn])
    if fn in indirect:
        if fn not in INDIRECT:
            notes.add("indirect call with no INDIRECT entry: " + fn)
        for t in INDIRECT.get(fn, []):
            edges.append((t, 8))
    for callee, pushed in edges:
        d, c = depth(callee, frames, calls, indirect, memo, path + [fn], notes)
        if d + pushed > best:
            best, chain = d + pushed, c
    memo[fn] = (own + best, [fn] + chain)
    return memo[fn]


def report(lines, roots):
    frames, calls = parse(lines)
    indirect = find_indirect(lines)
    out, notes = {}, set()
    for r in roots:
        out[r] = depth(r, frames, calls, indirect, {}, [], notes)
    return out, notes


def self_test():
    src = """
a_FRAMESIZE EQU 10
b_FRAMESIZE EQU 20
c_FRAMESIZE EQU 4
d_FRAMESIZE EQU 2
a   ENT
                PHA
                PHK
                PEA     _t_L0-1
                PHK
                PEA     b-1
                RTL             ; PILECALL
_t_L0
                PLA
                RTL
b   ENT
                PHK
                PEA     _t_L1-1
                PHK
                PEA     c-1
                RTL             ; PILECALL
_t_L1
                RTL
c   ENT
                RTL
d   ENT
                PHK
                PEA     _t_L2-1
                PHK
                PEA     d-1
                RTL             ; PILECALL
_t_L2
                RTL
e   ENT
                PHK
                PEA     _t_L3-1
                LDA     _x
                DEC
                PHA
                RTL
_t_L3
                RTL
""".split("\n")
    out, notes = report(src, ["a", "d", "e"])
    # a: 10+5, +2 pushed, b: 20+5, c: 4+5 = 51
    assert out["a"][0] == 51, out["a"]
    assert out["a"][1] == ["a", "b", "c"], out["a"]
    assert any("recursion: d -> d" in n for n in notes), notes
    assert any("no INDIRECT entry: e" in n for n in notes), notes
    print("net_stack_depth self-test: OK")


def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return
    lines = []
    for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.s"))):
        if not f.endswith(".data.s"):
            lines += open(f, errors="replace").read().split("\n")
    roots = sys.argv[2:] or ROOTS
    out, notes = report(lines, roots)
    for r in roots:
        d, chain = out[r]
        print(f"{r}: {d} bytes\n  " + " -> ".join(chain))
    for n in sorted(notes):
        print("note: " + n)


if __name__ == "__main__":
    main()
