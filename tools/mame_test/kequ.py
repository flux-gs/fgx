#!/usr/bin/env python3
"""kequ -- resolve a Merlin32 EQU, following aliases across the headers.

WHY THIS IS SHARED.  Four B3 checkers each grew their own copy of "read `NAME
EQU <value>` out of include/kernel.s, substituting symbols for one level of
indirection".  Every copy was correct until the bank-0 layout started being
DERIVED from kernel.nproc (tools/ninja/genconfig.py): the values moved to the
generated include/config.s and kernel.s kept only aliases, so every copy broke
in the same way, on the same day.  A reader that looks in one file for a
constant that can live in another is the defect -- fixing it four times is how
it comes back a fifth.

It searches config.s FIRST (that is where the derived layout lives) and then
kernel.s, and it follows alias chains and simple `A+{B*256}` arithmetic, which
is how the B3 lane constants are expressed.

A missing symbol RAISES.  These checkers exist to catch a kernel that moved
underneath a probe; resolving an unknown name to zero would turn that into a
serene pass, which is the precise failure this project keeps re-learning.
"""
import os
import re

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# config.s first: the derived bank-0 layout lives there, and kernel.s only
# aliases it.  Searching kernel.s first would find the alias and then have to
# chase it anyway.
_SOURCES = (os.path.join(_ROOT, "include", "config.s"),
            os.path.join(_ROOT, "include", "kernel.s"))


def equ(name, _depth=0):
    """Value of `name`, following aliases and simple arithmetic.  Raises if absent."""
    if _depth > 8:
        raise SystemExit(
            "kequ: %s resolves through more than 8 levels -- a cycle, or an "
            "expression this parser is not meant to evaluate." % name)
    tok = None
    for path in _SOURCES:
        try:
            text = open(path, errors="replace").read()
        except FileNotFoundError:
            continue
        m = re.search(r"^\s*%s\s+EQU\s+(.+?)\s*(?:;.*)?$" % re.escape(name),
                      text, re.MULTILINE)
        if m:
            tok = m.group(1).strip()
            break
    if tok is None:
        raise SystemExit(
            "kequ: %s is in neither include/config.s nor include/kernel.s -- it "
            "was renamed, or the config was not generated. Fix this parser "
            "rather than dropping the check that needed the value." % name)
    if tok.startswith("$"):
        return int(tok[1:], 16)
    if tok.isdigit():
        return int(tok)
    # Merlin32 braces are grouping, not arithmetic; strip them and let Python
    # evaluate what is left, after substituting every symbol it mentions.
    expr = re.sub(r"[{}]", "", tok)
    for sym in sorted(set(re.findall(r"[A-Z_][A-Z_0-9]*", expr)),
                      key=len, reverse=True):
        expr = expr.replace(sym, str(equ(sym, _depth + 1)))
    if expr.startswith("$"):
        return int(expr[1:], 16)
    return int(eval(expr, {"__builtins__": {}}))


def arena_bounds():
    """(lo, hi) of the bank-0 stack arena.  hi is exclusive."""
    lo = equ("CFG_STK_ARENA")
    return lo, lo + equ("CFG_STK_ARENA_PAGES") * 256


def _selftest():
    """A resolver that silently returned a wrong number would leave every check
    that uses it asserting about a machine that does not exist."""
    fails = 0
    lo, hi = arena_bounds()
    if not (0x0C00 < lo < hi <= 0xC000):
        print("  SELFTEST FAIL: arena bounds $%04X..$%04X are not in bank 0"
              % (lo, hi))
        fails += 1
    # An ALIAS must resolve to the same value as the constant it aliases --
    # this is the exact chain that broke the four copies of this reader.
    if equ("FGX_STK_ARENA") != equ("CFG_STK_ARENA"):
        print("  SELFTEST FAIL: the kernel.s alias and the config.s value "
              "disagree -- alias following is broken")
        fails += 1
    # And ARITHMETIC through an alias: the switch stack's top is
    # CFG_STK_SWITCH+FGX_STK_SWITCH_SIZE-1, so it exercises both.
    top, size = equ("FGX_STK_SWITCH_TOP"), equ("FGX_STK_SWITCH_SIZE")
    if top != equ("CFG_STK_SWITCH") + size - 1:
        print("  SELFTEST FAIL: FGX_STK_SWITCH_TOP $%04X is not the switch "
              "stack's base plus %d minus one" % (top, size))
        fails += 1
    try:
        equ("FGX_NO_SUCH_SYMBOL_AT_ALL")
        print("  SELFTEST FAIL: an unknown symbol resolved instead of raising")
        fails += 1
    except SystemExit:
        pass
    if fails:
        print("kequ self-test: %d FAILURE(S)" % fails)
        return 1
    print("kequ self-test: OK (arena $%04X..$%04X, switch stack top $%04X, "
          "aliases followed, unknown symbols raise)" % (lo, hi, top))
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(_selftest())
