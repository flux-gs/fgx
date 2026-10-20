#!/usr/bin/env python3
# Render an FGX SHR framebuffer dump (from tools/mame_test dump.json) to a PNG.
# Reconstructs the on-screen image from shr_full + shr_palette + shr_scb, so we
# can "screenshot" a headless MAME run without a display.
#
# Usage: shr2png.py <dump.json> <out.png>
import json, sys, zlib, struct

def png(w, h, rgb):  # rgb: bytes, w*h*3, top-to-bottom
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    raw = bytearray()
    for y in range(h):
        raw.append(0)                      # filter: none
        raw += rgb[y*w*3:(y+1)*w*3]
    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    out += chunk(b"IEND", b"")
    return out

def main():
    dump, outp = sys.argv[1], sys.argv[2]
    d = json.load(open(dump))
    m = d["memory"]
    pix = bytes.fromhex(m["shr_full"]["hex"])         # 32000 B, 160/line
    pal = bytes.fromhex(m["shr_palette"]["hex"])      # 512 B: 16 pal x 16 col x 2
    scb = bytes.fromhex(m["shr_scb"]["hex"])          # 200 B
    SCALE = 2
    W, H = 320, 200
    img = bytearray(W*SCALE * H*SCALE * 3)
    def putpx(x, y, r, g, b):
        for dy in range(SCALE):
            for dx in range(SCALE):
                o = ((y*SCALE+dy)*W*SCALE + (x*SCALE+dx))*3
                img[o]=r; img[o+1]=g; img[o+2]=b
    for y in range(H):
        s = scb[y] if y < len(scb) else 0
        palidx = s & 0x0F
        base = palidx*32
        for x in range(W):
            byte = pix[y*160 + (x>>1)]
            nib = (byte >> 4) if (x & 1) == 0 else (byte & 0x0F)
            e = base + nib*2
            lo = pal[e]; hi = pal[e+1]
            R = (hi & 0x0F)*17; G = ((lo >> 4) & 0x0F)*17; B = (lo & 0x0F)*17
            putpx(x, y, R, G, B)
    open(outp, "wb").write(png(W*SCALE, H*SCALE, bytes(img)))
    print("wrote %s (%dx%d)" % (outp, W*SCALE, H*SCALE))

main()
