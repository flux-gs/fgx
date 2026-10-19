#!/usr/bin/env python3
"""textchurn_check -- shared-text references balance, and no bank has two owners.

(a) Each text's count (TX_COUNT) equals the number of processes whose
    _kTextOf entry names it.
(c) A live task whose TCB_CodeBank holds a text's segment runs a text with
    a segment in that bank: a fork child runs its parent's code, and a
    reference it never took would let the text go while it runs.  Texts
    share banks (code is placed by size), so the bank names a set of texts.
(b) No page has two owners: a live task's TCB_BankList and SE_SoftBank own
    whole banks; a text's segment owns [TX_PAGE, TX_PAGE + TX_NPG) of its
    bank, or the whole bank when TX_NPG is 0.  A task that borrows (a fork
    child) lists nothing, so sharing never shows up here.
Regions: tcbs (task table), texttab (_kTextTab + _kTextOf), setab (the SE
table).  Exit 0 pass, 1 fail, 2 inconclusive.
"""
import binascii
import json
import pathlib
import sys

NTEXT, TXSZ, NPROC = 16, 36, 32
TX_COUNT = 32                       # src/kernel/tty/text.s
TCB, SE = 64, 32


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    m = d.get("memory", {})
    need = ("tcbs", "texttab", "setab")
    if any(not m.get(n, {}).get("hex") for n in need):
        print("textchurn: a region is missing from the dump")
        return 2
    t, x, se = (binascii.unhexlify(m[n]["hex"]) for n in need)
    textof = x[NTEXT * TXSZ:NTEXT * TXSZ + NPROC]
    bad = 0
    owners = {}                     # bank -> [(first page, end page, owner)]

    def own(bank, who, page=0, npg=0):
        nonlocal bad
        if bank == 0:
            return
        lo, hi = (page, page + npg) if npg else (0, 256)
        for a, b, other in owners.get(bank, []):
            if lo < b and a < hi:
                print(f"textchurn: FAIL -- bank ${bank:02X} pages [{lo},{hi}) held by "
                      f"{other} [{a},{b}) and {who}")
                bad += 1
        owners.setdefault(bank, []).append((lo, hi, who))

    textsin = {}                    # bank -> texts with a segment there
    for i in range(NTEXT):
        e = x[i * TXSZ:(i + 1) * TXSZ]
        if e[2] | e[3] << 8:
            for b in e[8:16]:
                if b:
                    textsin.setdefault(b, set()).add(i + 1)
    live = 0
    for s in range(NPROC):
        o = s * TCB
        if t[o + 2] in (0, 4):          # unused, or a zombie (already freed)
            continue
        live += 1
        for b in t[o + 54:o + 62]:
            own(b, f"pid {s + 1}")
        own(se[s * SE + 0x1F], f"pid {s + 1} soft-frame")
        cb = t[o + 20]
        if cb in textsin and textof[s] not in textsin[cb]:
            print(f"textchurn: FAIL -- pid {s + 1} runs code in bank ${cb:02X}, which holds "
                  f"texts {sorted(textsin[cb])}, but is recorded as running {textof[s] or 'none'}")
            bad += 1
    for i in range(NTEXT):
        e = x[i * TXSZ:(i + 1) * TXSZ]
        if (e[2] | e[3] << 8) == 0:
            continue
        users = sum(1 for p in textof if p == i + 1)
        if e[TX_COUNT] != users:
            print(f"textchurn: FAIL -- text {i + 1} counts {e[TX_COUNT]}, {users} process(es) run it")
            bad += 1
        for k in range(8):
            own(e[8 + k], f"text {i + 1}", e[16 + k], e[24 + k])
    print(f"textchurn: {live} live tasks, {len(owners)} banks with owners")
    if bad:
        return 1
    print("textchurn: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
