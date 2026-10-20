#!/usr/bin/env python3
"""enumerate_sites.py — list every PHK/PHB bank-emission site in fcc's codegen so
flip_sweep.py can flip each one (PHK<->PHB), rebuild fcc, and see which sweep
constructs go red.

A "site" is an `ir_emitf("... PHK\n")` or `ir_emitf("... PHB\n")` line in emit.c /
parse_expr.c / parse_stmt.c: the point where fcc pushes a bank byte for a far
pointer / far call.  We record the file, 1-based line, the exact original line
text (anchor — flip_sweep hard-fails if it drifts), and the flipped line (PHK<->PHB
swapped).  Lines carrying BOTH mnemonics, or neither cleanly, are skipped.

Writes flip/sites.json.  Run from anywhere; paths are resolved from HERE.
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TC   = os.path.abspath(os.path.join(HERE, "..", "..", ".."))   # toolchain/
FILES = ["src/cc/emit.c", "src/cc/parse_expr.c", "src/cc/parse_stmt.c"]

# An ir_emitf line that emits a standalone PHK or PHB mnemonic.
EMIT_RE = re.compile(r'ir_emitf\("[^"]*\b(PHK|PHB)\\n"')

# Train-2 phase 0b: the STORED-POINTER bank source (_fcc_ptr+2) — the "lost
# _fcc_ptr+2 -> seg0 not seg1" mole class, and the channel a malloc/realloc
# return's bank transits.  Per-kind mutations (not PHK/PHB swaps):
#   LDA _fcc_ptr+2  ->  LDA #$00   (bank read DROPPED — rebuilt as bank 0)
#   STA/STX _fcc_ptr+2 -> STZ ...  (bank write ZEROED before any later read)
PTRBANK_RE = re.compile(
    r'ir_emitf\("(\s*)(LDA|STA|STX)(\s+)_fcc_ptr\+2(\\n)"')


def main():
    sites = []
    for rel in FILES:
        path = os.path.join(TC, rel)
        with open(path) as f:
            lines_cache = f.readlines()
        if True:
            for lineno, line in enumerate(lines_cache, 1):
                m = EMIT_RE.search(line)
                if m:
                    has_phk = "PHK\\n" in line
                    has_phb = "PHB\\n" in line
                    if has_phk == has_phb:        # both or neither cleanly -> skip
                        continue
                    if has_phk:
                        flipped = line.replace("PHK\\n", "PHB\\n", 1)
                        kind = "PHK"
                    else:
                        flipped = line.replace("PHB\\n", "PHK\\n", 1)
                        kind = "PHB"
                    sites.append({
                        "file": rel, "line": lineno, "kind": kind,
                        "orig": line.rstrip("\n"), "flipped": flipped.rstrip("\n"),
                    })
                    continue
                pm = PTRBANK_RE.search(line)
                if pm:
                    op = pm.group(2)
                    # NO-OP guard: a bank STORE whose value was just loaded as
                    # #0 (emit_addr_param_lower's `LDA #0 / STA _fcc_ptr+2` —
                    # &param composes bank 0 on purpose) — STZ writes the same
                    # zero, so the mutation can never red anything.  Skip.
                    if op != "LDA":
                        recent = lines_cache[max(0, lineno - 4):lineno - 1]
                        if any(('LDA' in r and ('#0\\n' in r or '#$00' in r))
                               for r in recent):
                            continue
                    if op == "LDA":
                        mutated = line.replace("LDA%s_fcc_ptr+2" % pm.group(3),
                                               "LDA%s#$00" % pm.group(3), 1)
                        kind = "PTRBANK_LD"
                    else:                          # STA / STX -> STZ
                        mutated = line.replace("%s%s_fcc_ptr+2" % (op, pm.group(3)),
                                               "STZ%s_fcc_ptr+2" % pm.group(3), 1)
                        kind = "PTRBANK_ST"
                    sites.append({
                        "file": rel, "line": lineno, "kind": kind,
                        "orig": line.rstrip("\n"), "flipped": mutated.rstrip("\n"),
                    })
    out = os.path.join(HERE, "sites.json")
    with open(out, "w") as f:
        json.dump(sites, f, indent=2)
    by_file = {}
    for s in sites:
        by_file[s["file"]] = by_file.get(s["file"], 0) + 1
    print("wrote %d sites to %s" % (len(sites), out))
    for k, v in by_file.items():
        print("  %-24s %d" % (k, v))
    return 0


if __name__ == "__main__":
    sys.exit(main())
