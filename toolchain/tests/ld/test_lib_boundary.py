#!/usr/bin/env python3
"""
test_lib_boundary.py - libc holds exactly what 2.11BSD's libc holds.

2.11BSD puts login(3), logout(3) and logwtmp(3) in libutil.a
(usr.lib/libutil/Makefile: login.o logout.o logwtmp.o dkcksum.o), and the
resolver -- gethostbyname, gethostbyaddr, getservbyname -- in libc
(usr/lib/libc/net, usr/lib/libc/net/named).  This checks what programs link
against that line, in both directions: libc.so's export table and libutil's
static library.

Run: python3 tests/ld/test_lib_boundary.py   (from the toolchain root)
     or `make test-libs`
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "src", "ld"))
import fgx_imports                                               # noqa: E402
import fgx_libso                                                 # noqa: E402

LIBUTIL = ["login", "logout", "logwtmp"]
RESOLVER = ["gethostbyname", "gethostbyaddr", "getservbyname"]

fails = []


def check(cond, what):
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        fails.append(what)


def libc_exports():
    """The export table in libc.so's trailer: what a dynamically linked
    program resolves against."""
    path = fgx_libso.so_path("libc")
    if not os.path.exists(path):
        print("test_lib_boundary: %s not built: run make libc_so first" % path,
              file=sys.stderr)
        sys.exit(2)
    with open(path, "rb") as f:
        return {e[0] for e in fgx_imports.file_trailer(f.read())["exports"]}


def libutil_exports():
    """build/static_libs/libutil.s's FGX2_EXPORT lines (gen.py's static_libs
    edge)."""
    path = os.path.join(os.path.dirname(ROOT), "build", "static_libs", "libutil.s")
    if not os.path.exists(path):
        print("test_lib_boundary: %s not built: run ninja first" % path,
              file=sys.stderr)
        sys.exit(2)
    names = set()
    with open(path, errors="replace") as f:
        for ln in f:
            t = ln.split()
            if t[:1] == ["FGX2_EXPORT"] and len(t) > 1:
                names.add(t[1])
    return names


libc = libc_exports()
util = libutil_exports()

for name in LIBUTIL:
    check(name not in libc, "libc does not export %s (2.11BSD libutil.a)" % name)
    check(name in util, "libutil exports %s" % name)
for name in RESOLVER:
    check(name in libc, "libc exports %s (2.11BSD libc/net)" % name)
check(not any("resolv" in n for n in fgx_libso.LIBS),
      "no separate resolver library")

print("FAIL: %d" % len(fails) if fails else "library boundary holds")
sys.exit(1 if fails else 0)
