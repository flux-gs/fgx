#!/usr/bin/env python3
"""mknetnix.py - /netnix, the network stack's name list.

2.11BSD's route(8), netstat(1) and their kin find the network's tables with
nlist("/netnix", ...) (usr/sbin/route/route.c, flushroutes): on the PDP-11
/netnix is the supervisor-space network image, and its a.out symbol table names
`_rthost', `_rtnet' and the rest.  On FGX the stack is five modules and the
data is one bank, bsdnetd, loaded where the boot puts it.  So this writes only a
name list: a 2.11BSD a.out header (usr/sys/h/exec.h; magic 0407, no text or
data, relocation stripped) and its symbol table, one entry per label in
bsdnetd's data image, each value the label's OFFSET IN THAT BANK.  sysctl
kern.netdata says where the bank is.

  usage: mknetnix.py <bsdnetd listing> <out>
         mknetnix.py --self-test

The entry layout is 2.11BSD's struct nlist under _AOUT_INCLUDE_
(usr/include/nlist.h): n_strx (a 4-byte offset into the string table), n_type,
n_ovly, n_value (16 bits), little-endian as FGX reads it.  The string table
follows the symbols; offsets start at 4, past its own length word, so 0 can
mean no name.  C labels get upstream's leading underscore.
"""
import re
import struct
import sys

A_MAGIC1 = 0o407
N_DATA, N_EXT = 0x03, 0x20
ROW = re.compile(r"^\s*\d+ \|.*\| (Data|Code)\s*\|.*\| ([0-9A-F]{2})/([0-9A-F]{4}) :.*\| ([A-Za-z_][A-Za-z0-9_]*)\s")


def labels(path):
    out = {}
    with open(path, errors="replace") as f:
        for line in f:
            m = ROW.match(line)
            if m and m.group(1) == "Data" and not m.group(4).startswith("_fcc"):
                out.setdefault(m.group(4), int(m.group(3), 16))
    return out


def namelist(syms):
    strtab = bytearray(4)
    entries = bytearray()
    for name, value in sorted(syms.items()):
        strx = len(strtab)
        strtab += ("_" + name).encode() + b"\0"
        entries += struct.pack("<IBBH", strx, N_DATA | N_EXT, 0, value)
    struct.pack_into("<I", strtab, 0, len(strtab))
    hdr = struct.pack("<8H", A_MAGIC1, 0, 0, 0, len(entries), 0, 0, 1)
    return hdr + bytes(entries) + bytes(strtab)


def self_test():
    nl = namelist({"rthashsize": 0x081F, "rthost": 0x1F1C})
    magic, _, _, _, syms, _, _, flag = struct.unpack_from("<8H", nl, 0)
    assert magic == A_MAGIC1 and flag == 1 and syms == 16, "header"
    strx, typ, ovly, val = struct.unpack_from("<IBBH", nl, 16)
    base = 16 + syms
    name = nl[base + strx:nl.index(b"\0", base + strx)]
    assert name == b"_rthashsize" and val == 0x081F and typ == N_DATA | N_EXT, name
    return 0


def main(argv):
    if argv[1:] == ["--self-test"]:
        return self_test()
    syms = labels(argv[1])
    for need in ("rthost", "rtnet", "rthashsize"):
        if need not in syms:
            sys.exit(f"mknetnix: `{need}' is not in {argv[1]}")
    with open(argv[2], "wb") as f:
        f.write(namelist(syms))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
