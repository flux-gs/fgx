#!/usr/bin/env python3
"""check_net_retired.py - the transports the kernel stack replaced stay gone.

Every socket is a 2.11BSD struct socket in the network modules since net-mux S4,
reached from its FCB.  What came before -- net.mod's socket-descriptor table and
its twelve-entry cap, the W5100's TCP, UDP and IPRAW cores, the loopback rings and
the AF_UNIX rings -- was deleted with it.  Since S5 an interface is configured
only through the stack's ioctls, as 2.11BSD's ifconfig and route do it, so
SYS_IFCONFIG, net.mod's interface table and the card's second name, `u2s1', are
gone too.  A second road to a socket hides defects
in the gap between the two, so a definition of any of their names coming back is
a build failure.

DEFINITIONS ONLY: an assembler label or EQU at column 0, a C #define, or a C
function definition at column 0.  A comment that names one in history is not a
road.  `u2s1' is a name, not a definition, so it is checked as a word anywhere
in the shipped files (disk_src/etc and the man pages too).

Usage: check_net_retired.py            the tree
       check_net_retired.py --self-test
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = ["src", "include", "toolchain/include", "toolchain/lib/libc_c",
        "toolchain/lib/libfgx_c"]
WORD_DIRS = DIRS + ["disk_src/etc"]
NAMES = [r"SOCKD_MAX", r"SOCKTBL_BLK_SIZE", r"XPORT_TCP", r"XPORT_UNIX",
         r"XPORT_ICMP", r"_W5_SockAlloc", r"_W5_SockFree", r"_sockTablePtr",
         r"_Loop_\w+", r"_Unp_\w+", r"_Net_Xport_\w+", r"FCB_SockIdx",
         r"SYS_IFCONFIG", r"_Ifnet_\w+", r"_Ifc_\w+", r"_Sys_Ifconfig\w*",
         r"IF_(REC_SIZE|Name|Slot|Mac|Flags|Ip|Netmask|Broadcast|Gateway)",
         r"IFC_(GETN|GET|SET|SETDHCP)", r"ifctl"]
ASM = re.compile(r"^(" + "|".join(NAMES) + r")\b")
CDEF = re.compile(r"^\s*#\s*define\s+(" + "|".join(NAMES) + r")\b")
CFN = re.compile(r"^(?:\w+\s+)*\**(" + "|".join(NAMES) + r")\s*\(")
WORD = re.compile(r"\bu2s1\b")


def scan(path, text):
    out = []
    for n, line in enumerate(text.split("\n"), 1):
        if path.endswith(".s"):
            m = ASM.match(line)
        else:
            m = CDEF.match(line) or CFN.match(line)
        if m:
            out.append(f"{path}:{n}: {m.group(1)}")
    return out


def scan_word(path, text):
    return [f"{path}:{n}: u2s1" for n, line in enumerate(text.split("\n"), 1)
            if WORD.search(line)]


def self_test():
    assert scan("x.s", "SOCKD_MAX       EQU     12") == ["x.s:1: SOCKD_MAX"]
    assert scan("x.s", "_Loop_CloseTry  MX      %00") == ["x.s:1: _Loop_CloseTry"]
    assert scan("x.s", "; _Loop_CloseTry was here") == []
    assert scan("x.s", "                JSR     _Loop_CloseTry") == []
    assert scan("x.h", "#define SOCKD_MAX 12") == ["x.h:1: SOCKD_MAX"]
    assert scan("x.c", "/* SOCKD_MAX */") == []
    assert scan("x.c", "int ifctl(int op, char *r)") == ["x.c:1: ifctl"]
    assert scan("x.c", "    ifctl(IFC_GET, r);") == []
    assert scan("x.s", "_Ifnet_FindByName MX %00") == ["x.s:1: _Ifnet_FindByName"]
    assert scan_word("rc", "ifconfig u2s1 inet") == ["rc:1: u2s1"]
    assert scan_word("rc", "ifconfig wz0 inet") == []
    print("check_net_retired self-test: OK")


def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return
    bad = []
    for d in DIRS:
        for dirpath, _, files in os.walk(os.path.join(ROOT, d)):
            for f in files:
                if f.endswith((".s", ".c", ".h")):
                    p = os.path.join(dirpath, f)
                    bad += scan(os.path.relpath(p, ROOT),
                                open(p, errors="replace").read())
    for d in WORD_DIRS + ["src/userland/man/pages"]:
        for dirpath, _, files in os.walk(os.path.join(ROOT, d)):
            for f in files:
                p = os.path.join(dirpath, f)
                bad += scan_word(os.path.relpath(p, ROOT),
                                 open(p, errors="replace").read())
    if bad:
        print("check_net_retired: a retired transport's name is defined again:")
        for b in bad:
            print("  " + b)
        sys.exit(1)
    print("check_net_retired: OK")


if __name__ == "__main__":
    main()
