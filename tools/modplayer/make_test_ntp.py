#!/usr/bin/env python3
"""Generate a tiny synthetic NinjaTracker+ .ntp with known field values,
for closed-loop testing of the FGX `ntpinfo` parser. Layout: PHASE_A_NOTES §1."""
import os


def u24le(n):
    return bytes([n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff])


def build():
    b = bytearray()
    b += b'nfc!'            # magic
    b += bytes([2])         # version
    b += bytes([2])         # no_of_tracks      T=2
    b += bytes([2])         # no_of_instruments I=2
    b += bytes([2])         # max_pat_cnt       P=2
    b += bytes([2])         # pattern_order_len O=2
    b += bytes([4])         # song-name length
    b += b'TEST'            # song name
    # track table: 3 bytes x T (channel, stream_page, osc_byte = %x00yyyyy)
    b += bytes([0, 0, 0])   # trk0: channel 0 (left),  1 osc, base osc 0
    b += bytes([1, 0, 1])   # trk1: channel 1 (right), 1 osc, base osc 1
    # instrument records x I.
    # inst 1: normal, uploaded to DOC RAM (doc_ptr=1 nonzero).
    b += bytes([0]) + u24le(4) + u24le(0) + u24le(0)   # type single, len4, rp/rl 0
    b += bytes([0x40, 0, 1, 0, 3]) + b'IN1'            # vol64 ft0 doc_ptr1 siz0 nl3
    # inst 2: streamed/unplaced (doc_ptr=0) -> NOT in DOC RAM; must be SKIPPED, not
    # played as garbage (DOC page 0).  type bit3 ($08) marks streamed.
    b += bytes([0x08]) + u24le(4) + u24le(0) + u24le(0)
    b += bytes([0x40, 0, 0, 0, 3]) + b'IN2'            # doc_ptr0 (streamed)
    # pattern order: walk 2 distinct patterns (pat1 is at a non-zero offset).
    b += bytes([0, 1])      # order = [0, 1]
    # pattern data: P*64*T*4 = 2*64*2*4 = 1024 bytes (512 per pattern).
    # row r track t at offset r*8 + t*4.
    #   pat0: r0t0 n25 i1 ; r0t1 n27 i1 ; r1t0 n29 i0(persist i1)   -> 3 triggers
    #   pat1: r0t0 n30 i2(doc_ptr0 -> SKIP) ; r0t1 n31 i1           -> 1 trigger
    # correct total = 4 (the inst-2 note is skipped).  If doc_ptr-0 isn't skipped
    # the inst-2 note triggers garbage -> 5.
    p0 = bytearray(512)
    p0[0] = 25; p0[1] = 1     # r0 t0 note25 inst1
    p0[4] = 27; p0[5] = 1     # r0 t1 note27 inst1
    p0[8] = 29; p0[9] = 0     # r1 t0 note29 inst0 (persistence -> inst1)
    p1 = bytearray(512)
    p1[0] = 30; p1[1] = 2     # r0 t0 note30 inst2 (doc_ptr0 -> skipped)
    p1[4] = 31; p1[5] = 1     # r0 t1 note31 inst1
    b += bytes(p0) + bytes(p1)
    # instrument sample data: inst1 4 bytes, inst2 4 bytes (concatenated in order).
    b += bytes([0x10, 0x20, 0x30, 0x40])    # inst1 sample
    b += bytes([0x50, 0x60, 0x70, 0x80])    # inst2 sample (read+discarded; doc_ptr0)
    return bytes(b)


def main():
    out = os.path.join(os.path.dirname(__file__), '..', '..',
                       're', 'shellplay', 'ntp', 'test_tiny.ntp')
    out = os.path.abspath(out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    data = build()
    with open(out, 'wb') as f:
        f.write(data)
    print(f'wrote {out} ({len(data)} bytes)')


if __name__ == '__main__':
    main()
