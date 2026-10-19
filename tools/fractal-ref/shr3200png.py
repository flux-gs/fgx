#!/usr/bin/env python3
# Reconstruct the per-scanline "3200-color" image from a headless dump:
#   shr_full    - 32000 B pixels (200 rows x 160 B, 4bpp, 320 mode)
#   gfx_paltab  - 8192 B  (256 per-line palettes x 32 B) staged by fractal --3200
# The live display uses the VGC scanline interrupt to load hw palette 0 from
# GFX_PALTAB[$C02E] per scanline; the fractal stages screen row y at slot
# palslot(y) = 127 + y*96/199 (the measured visible-$C02E calibration). We apply
# the SAME mapping here so this previews the coloring the beam produces (it does
# NOT validate live timing/calibration -- that needs the real machine).
import json, sys

def palslot(y):
    return 127 + (y * 96) // 199

def main():
    dump, out = sys.argv[1], sys.argv[2]
    d = json.load(open(dump))
    m = d.get("memory", d)
    px  = bytes.fromhex(m["shr_full"]["hex"])       # 32000
    pal = bytes.fromhex(m["gfx_paltab"]["hex"])     # 8192
    W, H = 640, 200                                  # 320-mode pixels display 2x wide
    img = bytearray(W * H * 3)
    for y in range(H):
        base = palslot(y) * 32                       # this row's 16-color palette
        row = y * 160
        for xb in range(160):
            b = px[row + xb]
            for half in (0, 1):
                idx = (b >> 4) if half == 0 else (b & 0x0F)
                e = base + idx * 2
                lo = pal[e]; hi = pal[e + 1]         # GGGGBBBB, 0000RRRR
                r = (hi & 0x0F) * 17
                g = ((lo >> 4) & 0x0F) * 17
                bl = (lo & 0x0F) * 17
                lx = (xb * 2 + half) * 2             # 2x horizontal
                for x in (lx, lx + 1):
                    o = (y * W + x) * 3
                    img[o] = r; img[o + 1] = g; img[o + 2] = bl
    # minimal PPM->PNG via stdlib zlib
    import zlib, struct
    def png(w, h, rgb):
        def chunk(t, data):
            c = t + data
            return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
        raw = bytearray()
        for y in range(h):
            raw.append(0)
            raw += rgb[y*w*3:(y+1)*w*3]
        return (b"\x89PNG\r\n\x1a\n"
                + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))
    # upscale 2x vertically for a 320x400 view (matches shr2png aspect)
    up = bytearray(W * H * 2 * 3)
    for y in range(H):
        srow = img[y*W*3:(y+1)*W*3]
        up[(2*y)*W*3:(2*y+1)*W*3] = srow
        up[(2*y+1)*W*3:(2*y+2)*W*3] = srow
    open(out, "wb").write(png(W, H*2, up))
    print("wrote", out, f"({W}x{H*2})")

if __name__ == "__main__":
    main()
