#!/usr/bin/env python3
"""The kernel's page map (src/kernel/bank.s), modelled.

2.11BSD's resource map (usr/sys/sys/subr_rmap.c, h/map.h): a dense array of
{m_size, m_addr} pieces in address order, first fit, coalescing on return,
size 0 ends it, address 0 is not legal.  A unit is a 256-byte page and an
address is bank << 8 | page.  FGX's rule BSD does not have: no allocation
crosses a bank, so a request is placed at the first address of a piece from
which it fits inside one bank, and the piece splits when that is not its
start.  A request under a bank first looks for room that does not start a
wholly free bank, so whole banks stay whole for data.
"""
import sys

BANK = 256


class Coremap:
    def __init__(self, first, nbanks, nmap=64):
        self.nmap = nmap
        self.m = [[nbanks * BANK, first << 8]]

    def pieces(self):
        return [tuple(p) for p in self.m]

    def free_total(self):
        return sum(s for s, _ in self.m)

    def alloc(self, size):
        assert 0 < size <= BANK
        for strict in (True, False):
            for i, (sz, a) in enumerate(self.m):
                p = a if (a & 0xFF) + size <= BANK else (a | 0xFF) + 1
                if p + size > a + sz:
                    continue
                if strict and size < BANK and p & 0xFF == 0 and a + sz - p >= BANK:
                    continue
                if p != a:
                    if len(self.m) >= self.nmap:
                        continue
                    self.m.insert(i, [p - a, a])
                    i += 1
                    self.m[i] = [sz - (p - a), p]
                    sz = sz - (p - a)
                if sz == size:
                    del self.m[i]
                else:
                    self.m[i] = [sz - size, p + size]
                return p
        return 0

    def free(self, size, addr):
        assert size and addr
        i = 0
        while i < len(self.m) and self.m[i][1] <= addr:
            i += 1
        if i and self.m[i - 1][1] + self.m[i - 1][0] == addr:
            self.m[i - 1][0] += size
            if i < len(self.m) and addr + size == self.m[i][1]:
                self.m[i - 1][0] += self.m[i][0]
                del self.m[i]
            return 0
        if i < len(self.m) and addr + size == self.m[i][1]:
            self.m[i] = [self.m[i][0] + size, addr]
            return 0
        if len(self.m) >= self.nmap:
            return size                 # mfree: "overflow, lost %u clicks"
        self.m.insert(i, [size, addr])
        return 0

    def claim(self, size, addr):
        for i, (sz, a) in enumerate(self.m):
            if a <= addr and addr + size <= a + sz:
                left, right = addr - a, a + sz - (addr + size)
                rows = ([[left, a]] if left else []) + ([[right, addr + size]] if right else [])
                if len(self.m) - 1 + len(rows) > self.nmap:
                    return False
                self.m[i:i + 1] = rows
                return True
        return False


def check(pieces, first, nbanks):
    lo, hi = first << 8, (first + nbanks) << 8
    prev_end = None
    for sz, a in pieces:
        assert sz > 0 and a > 0, (sz, a)
        assert lo <= a and a + sz <= hi, "outside the pool: %#x+%#x" % (a, sz)
        if prev_end is not None:
            assert a > prev_end, "unsorted, overlapping or uncoalesced at %#x" % a
        prev_end = a + sz


def self_test():
    m = Coremap(0x41, 4)                          # banks $41-$44
    assert m.alloc(256) == 0x4100                 # whole bank: lowest
    assert m.alloc(16) == 0x4200                  # no partly used bank yet
    assert m.alloc(256) == 0x4300                 # $42 is partly used: next whole bank
    assert m.alloc(32) == 0x4210                  # packs into the partial bank
    assert m.alloc(250) == 0x4400                 # 250 does not fit $42's 208 left
    m.free(16, 0x4200)
    m.free(32, 0x4210)                            # coalesces with $4230..$42FF
    check(m.pieces(), 0x41, 4)
    assert m.pieces() == [(256, 0x4200), (6, 0x44FA)], m.pieces()
    # A request that would cross a bank is placed at the next bank.
    m2 = Coremap(0x41, 2)
    assert m2.alloc(200) == 0x4100
    assert m2.alloc(100) == 0x4200                # 56 left in $41: does not fit
    assert m2.alloc(56) == 0x41C8
    # claim splits; overflow loses and reports.
    m3 = Coremap(0x41, 3, nmap=2)
    assert m3.claim(256, 0x4200)
    assert m3.pieces() == [(256, 0x4100), (256, 0x4300)]
    assert m3.alloc(1) == 0x4100                  # both banks whole: strict fails, then first fit
    assert m3.free(1, 0x4100) == 0
    assert m3.free(256, 0x4200) == 0              # coalesces all three
    assert m3.pieces() == [(768, 0x4100)]
    print("coremap_model: ok")


if __name__ == "__main__":
    self_test()
