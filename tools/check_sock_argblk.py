#!/usr/bin/env python3
"""check_sock_argblk.py - libc packs the socket arg block and the kernel unpacks
it; the two must agree on where every field sits.

WHY THIS EXISTS.  `_sock_argblk' (toolchain/lib/libc_c/socket.c) is a flat scalar
block that libc fills and the kernel reads through the caller's DBR.  There is
no shared declaration: libc writes `_sock_argblk[i]' in C and net.mod reads
`LDY #off' in Merlin32 assembly, so the layout lives twice and nothing made the
two copies agree.

That is not hypothetical.  apple/fgx#440: `sendto' and `recvfrom' took a `flags'
argument, named it in the signature, and packed no word for it -- so MSG_OOB
and MSG_DONTWAIT were discarded in libc, before the kernel could honour or
refuse them.  The kernel side agreed, in the sense that it read no such word.
Both halves were self-consistent and both were wrong, which is precisely the
failure a single-sided review does not catch.

A DISAGREEMENT HERE IS SILENT.  The kernel reads whatever bytes are at the
offset it believes in -- for `sendto' that is the destination port two words
down, for `recvfrom' the source-sockaddr pointer -- and answers from garbage.
It cannot be reached from a fixture either: every flags-0 datagram call goes on
to touch the W5100, and the loopprobe fixtures boot a machine with no card.  So
the agreement is CHECKED rather than tested.

WHAT IS COMPARED: for each of the four calls that carry a MSG_* flags word, the
C subscript libc assigns `flags' to, doubled, against the byte offset the
matching kernel handler loads into `_sockSendFlags' / `_sockRecvFlags'.  The
block's own `DS' size must cover every byte any of them uses.

AND THE BUFFER'S BANK (apple/fgx#480).  Each of the four packs `(int)(lp >> 16)'
-- the buffer's bank -- at SOCKARG_BANK (include/socket.s), and each handler
must build its uio through _So_ArgUio exactly once, which must read that
offset into the iovec.  A wrapper that stops packing it, or a stager that stops
reading it, sends a stack buffer's bytes to the data bank with nothing to say
so: the count comes back right and the buffer does not.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# BOTH socket members.  The wrappers are split across two files because the
# libc pile dead-strips at FILE granularity (socket_srv.c's header says why),
# and a checker that reads only one of them reports the other's calls as
# "packs no flags word" -- a false PASS-shaped result for a real pairing.
CSRC = [os.path.join(ROOT, "toolchain/lib/libc_c/socket.c"),
        os.path.join(ROOT, "toolchain/lib/libc_c/socket_srv.c")]
ASM  = os.path.join(ROOT, "src/modules/net/net.s")
DATA = os.path.join(ROOT, "toolchain/lib/libc_c/socket.c")
SOCK = os.path.join(ROOT, "include/socket.s")

# libc call -> kernel handler.  Only the calls that carry MSG_* flags.
PAIRS = {
    "send":     "net_op_send",
    "recv":     "net_op_recv",
    "sendto":   "net_op_sendto",
    "recvfrom": "net_op_recvfrom",
}

C_FUNC  = re.compile(r"^int\s+(\w+)\s*\(")
C_SLOT  = re.compile(r"_sock_argblk\[(\d+)\]\s*=\s*(.+?);")
A_FUNC  = re.compile(r"^(net_op_\w+)\b")
# LDY #N ... LDA [_libcTmp2],Y ... STA _sockSendFlags   (comments/blank between)
A_READ  = re.compile(
    r"^\s+LDY\s+#(\d+)\s*(?:;.*)?$\n"
    r"(?:\s*(?:;.*)?\n)*"
    r"\s+LDA\s+\[_libcTmp2\],Y\s*(?:;.*)?$\n"
    r"(?:\s*(?:;.*)?\n)*"
    r"\s+STA\s+_sock(?:Send|Recv)Flags\b",
    re.M)
DS_SIZE = re.compile(r"^int\s+_sock_argblk\s*\[\s*(\d+)\s*\]\s*;", re.M)
BANK_EQU = re.compile(r"^SOCKARG_BANK\s+EQU\s+(\d+)", re.M)
C_BANK_RHS = re.compile(r"^\(int\)\s*\(\s*lp\s*>>\s*16\s*\)$")
# every handler builds its uio through the one stager
A_BANK = re.compile(r"^\s+JSR\s+_So_ArgUio\b", re.M)
# ...which reads the bank word: LDY #SOCKARG_BANK / LDA [_libcTmp2],Y
# its body runs to the next GLOBAL label: `@' labels are inside it
STAGER = re.compile(r"^(_So_ArgUio)\b(.*?)^(?=[_A-Za-z])", re.M | re.S)
STAGER_BANK = re.compile(
    r"^\s+LDY\s+#SOCKARG_BANK\b.*$\n"
    r"(?:\s*(?:;.*)?\n)*"
    r"\s+LDA\s+\[_libcTmp2\],Y\b",
    re.M)


def c_flag_slots(text):
    """{function: subscript assigned `flags'}, {function: max subscript} and
    {function: subscript assigned the buffer's bank}."""
    flags, widest, bank, cur = {}, {}, {}, None
    for line in text.splitlines():
        m = C_FUNC.match(line)
        if m:
            cur = m.group(1)
        if cur is None:
            continue
        for idx, rhs in C_SLOT.findall(line):
            idx = int(idx)
            widest[cur] = max(widest.get(cur, -1), idx)
            if rhs.strip() == "flags":
                flags[cur] = idx
            if C_BANK_RHS.match(rhs.strip()):
                bank[cur] = idx
    return flags, widest, bank


def asm_flag_offsets(text):
    """{handler: byte offset loaded into a _sock*Flags cell}."""
    bodies, cur, buf = {}, None, []
    for line in text.splitlines(True):
        m = A_FUNC.match(line)
        if m:
            if cur:
                bodies[cur] = "".join(buf)
            cur, buf = m.group(1), []
        if cur:
            buf.append(line)
    if cur:
        bodies[cur] = "".join(buf)
    out, banks = {}, {}
    for name, body in bodies.items():
        banks[name] = len(A_BANK.findall(body))
        hits = A_READ.findall(body)
        if len(hits) > 1:
            raise SystemExit(
                "check_sock_argblk: %s stages a flags word %d times; "
                "one handler, one offset" % (name, len(hits)))
        if hits:
            out[name] = int(hits[0])
    return out, banks


def check(csrc, asm, data, sock):
    flags, widest, bank = c_flag_slots(csrc)
    offs, banks = asm_flag_offsets(asm)
    errs, checked = [], 0
    m = BANK_EQU.search(sock)
    bank_off = int(m.group(1)) if m else None
    if bank_off is None:
        errs.append("no `SOCKARG_BANK EQU n' in include/socket.s")

    for cname, aname in sorted(PAIRS.items()):
        if cname not in flags:
            errs.append("libc %s() packs no flags word -- the argument is "
                        "accepted and discarded (apple/fgx#440)" % cname)
            continue
        if aname not in offs:
            errs.append("%s stages no flags word, but libc %s() packs one at "
                        "byte %d" % (aname, cname, flags[cname] * 2))
            continue
        want, got = flags[cname] * 2, offs[aname]
        if want != got:
            errs.append("%s reads flags at +%d; libc %s() writes it at +%d "
                        "(_sock_argblk[%d])"
                        % (aname, got, cname, want, flags[cname]))
        if cname not in bank:
            errs.append("libc %s() packs no buffer bank -- a stack buffer "
                        "is read and written in the data bank "
                        "(apple/fgx#480)" % cname)
        elif bank_off is not None and bank[cname] * 2 != bank_off:
            errs.append("libc %s() packs the buffer bank at +%d "
                        "(_sock_argblk[%d]); SOCKARG_BANK is +%d"
                        % (cname, bank[cname] * 2, bank[cname], bank_off))
        if banks.get(aname, 0) != 1:
            errs.append("%s builds its uio through _So_ArgUio %d times; it "
                        "must once" % (aname, banks.get(aname, 0)))
        checked += 1

    m = STAGER.search(asm + "\nEND\n")
    if not m:
        errs.append("no _So_ArgUio in net.s: nothing stages the buffer bank")
    elif not STAGER_BANK.search(m.group(2)):
        errs.append("_So_ArgUio does not read SOCKARG_BANK into the uio -- a "
                    "stack buffer is moved in the data bank (apple/fgx#480)")

    m = DS_SIZE.search(data)
    if not m:
        errs.append("no `int _sock_argblk[n];' in socket.c")
    else:
        size = 2 * int(m.group(1))
        need = (max(widest.values()) + 1) * 2 if widest else 0
        if size < need:
            errs.append("_sock_argblk is %d bytes; libc writes %d bytes"
                        % (size, need))
    return errs, checked


def self_test():
    good_c = (
        "int send(int s, char *buf, int len, int flags)\n"
        "{\n    _sock_argblk[0] = 1;\n    _sock_argblk[1] = len;\n"
        "    _sock_argblk[2] = flags;\n"
        "    _sock_argblk[3] = (int)(lp >> 16);\n}\n")
    stage = "                JSR     _So_ArgUio\n"
    stager = ("_So_ArgUio      MX      %00\n"
              "@local          NOP\n"
              "                LDY     #SOCKARG_BANK\n"
              "                LDA     [_libcTmp2],Y\n"
              "                RTS\n")
    good_a = (
        "net_op_send     MX      %00\n" + stage +
        "                LDY     #4\n"
        "                LDA     [_libcTmp2],Y\n"
        "                STA     _sockSendFlags\n" + stager)
    data = "int _sock_argblk[6];\n"
    sock = "SOCKARG_BANK    EQU     6           ; bank\n"
    saved = dict(PAIRS)
    try:
        PAIRS.clear()
        PAIRS["send"] = "net_op_send"

        errs, n = check(good_c, good_a, data, sock)
        assert not errs and n == 1, ("agreeing pair must pass", errs)

        # the offsets disagree
        bad_a = good_a.replace("#4", "#6")
        errs, _ = check(good_c, bad_a, data, sock)
        assert any("reads flags at +6" in e for e in errs), errs

        # libc drops the argument entirely -- apple/fgx#440's own shape
        bad_c = good_c.replace("    _sock_argblk[2] = flags;\n", "")
        errs, _ = check(bad_c, good_a, data, sock)
        assert any("packs no flags word" in e for e in errs), errs

        # the kernel never stages it
        bad_a2 = ("net_op_send     MX      %00\n" + stage +
                  "                RTL\n" + stager)
        errs, _ = check(good_c, bad_a2, data, sock)
        assert any("stages no flags word" in e for e in errs), errs

        # the block is too short for what libc writes
        errs, _ = check(good_c, good_a, "int _sock_argblk[2];\n", sock)
        assert any("_sock_argblk is 4 bytes" in e for e in errs), errs

        # a comment between the three instructions must not hide the read
        spaced = (
            "net_op_send     MX      %00\n"
            "                LDY     #4                  ; flags\n"
            "                ; a note in the middle\n"
            "                LDA     [_libcTmp2],Y\n"
            "                STA     _sockSendFlags\n" + stage + stager)
        errs, n = check(good_c, spaced, data, sock)
        assert not errs and n == 1, ("comments must not hide it", errs)

        # libc stops packing the buffer's bank -- apple/fgx#480's own shape
        bad_c = good_c.replace("    _sock_argblk[3] = (int)(lp >> 16);\n", "")
        errs, _ = check(bad_c, good_a, data, sock)
        assert any("packs no buffer bank" in e for e in errs), errs

        # libc packs it one word off
        bad_c = good_c.replace("_sock_argblk[3] = (int)(lp >> 16)",
                               "_sock_argblk[4] = (int)(lp >> 16)")
        errs, _ = check(bad_c, good_a, data, sock)
        assert any("packs the buffer bank at +8" in e for e in errs), errs

        # a handler stops building its uio through the stager
        errs, _ = check(good_c, good_a.replace(stage, ""), data, sock)
        assert any("through _So_ArgUio 0 times" in e for e in errs), errs

        # the stager stops reading the bank
        errs, _ = check(good_c, good_a.replace("#SOCKARG_BANK", "#2"),
                        data, sock)
        assert any("does not read SOCKARG_BANK" in e for e in errs), errs
    finally:
        PAIRS.clear()
        PAIRS.update(saved)
    print("check_sock_argblk: self-test OK")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    csrc = "\n".join(open(f).read() for f in CSRC)
    errs, n = check(csrc, open(ASM).read(), open(DATA).read(),
                    open(SOCK).read())
    if errs:
        for e in errs:
            print("check_sock_argblk: " + e, file=sys.stderr)
        return 1
    print("check_sock_argblk: clean (%d calls; libc and net.mod agree on every "
          "MSG_* flags offset and buffer bank)" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
