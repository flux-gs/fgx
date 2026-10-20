#!/usr/bin/env python3
"""Rasterize a TTF/OTF into an FGX FGXF v1 font (.FNT, 808 B).

Strategy:
  1. Render at LARGE pixel size (--render-size, default 64).
  2. Measure the monospace advance and ascender/descender extents.
  3. For each printable ASCII char (0x20..0x7E), crop the monospace cell,
     downsample to 6x8 (or 6x7 plus descender row) with LANCZOS, threshold.
  4. Pack into bits 7..2 of each row.

For pixel-art display fonts (e.g. Monofonto, Press Start, etc.), the LANCZOS
downsample preserves stroke topology far better than directly rendering at 8px.

Usage:
  tools/gen_fnt_ttf.py SOURCE.ttf -o OUT.FNT \\
      --name "Monofonto" --author "Typodermic" --license "Free"
      [--render-size N]   # source rendering size (default 64)
      [--cap-rows N]      # rows for cap-height region (default 7, descender=1)
      [--threshold N]     # 0..255 (default 128)
      [--x-shift N]       # +/- source pixels at render scale, post-crop
      [--y-shift N]       # +/- source pixels at render scale, post-crop
      [--preview PATH.png]
"""
import argparse
import pathlib
import sys
from PIL import Image, ImageDraw, ImageFont

MAGIC = b"FGXF"
VERSION = 1
HEADER_SIZE = 48
GLYPHS_SIZE = 760
FILE_SIZE = HEADER_SIZE + GLYPHS_SIZE
CELL_W = 6   # glyph pixels (in bits 7..2)
CELL_H = 8   # rows
PAD_BITS = 0b00000011  # low 2 bits always zero

PRINTABLE = [chr(c) for c in range(0x20, 0x7F)]  # 95 chars
assert len(PRINTABLE) == 95


def pad(s, n):
    b = s.encode("latin-1")
    if len(b) > n:
        raise SystemExit(f"field {s!r} too long (max {n})")
    return b + b"\x00" * (n - len(b))


def measure_advance(font):
    """Monospace advance in source pixels. Use 'M' bbox width as proxy."""
    bbox = font.getbbox("M")
    return bbox[2] - bbox[0]


def render_strip(font, render_size):
    """Render the full printable ASCII range and return (img, advance, ascent_top).

    ascent_top is the y-coordinate (in source pixels) of the cap-line in the
    rendered strip. The strip uses left/ascender anchor: top of ascender is y=0.
    Cap height region: [0 .. ascent], descender region: [ascent .. ascent+desc].
    """
    advance = measure_advance(font)
    n = len(PRINTABLE)
    ascent, descent = font.getmetrics()
    height = ascent + descent + 4  # bit of slack
    img = Image.new("L", (advance * n + render_size, height), 0)
    draw = ImageDraw.Draw(img)
    for i, ch in enumerate(PRINTABLE):
        draw.text((i * advance, 0), ch, fill=255, font=font, anchor="la")
    return img, advance, ascent


def downsample_cell(src, target_w, target_h, threshold):
    """LANCZOS-resize src (L mode) to target_w x target_h and threshold to 1bpp."""
    resized = src.resize((target_w, target_h), Image.LANCZOS)
    rows = []
    px = resized.load()
    for y in range(target_h):
        byte = 0
        for x in range(target_w):
            if px[x, y] >= threshold:
                byte |= 1 << (7 - x)
        rows.append(byte & 0xFC)
    return rows


def render_all(font_path, render_size, cap_rows, threshold, x_shift, y_shift):
    """Build 760-byte glyph block by downsampling each monospace cell.

    Each cell uses the FULL monospace advance horizontally (preserves spacing)
    and the (ascent + descent) range vertically. cap_rows controls how many
    of the 8 dest rows are devoted to the ascent region; descender chars use
    the remaining (8-cap_rows) rows.
    """
    font = ImageFont.truetype(str(font_path), render_size)
    strip, advance, ascent = render_strip(font, render_size)
    _, descent = font.getmetrics()
    glyphs = bytearray(GLYPHS_SIZE)
    desc_rows = CELL_H - cap_rows
    for i, ch in enumerate(PRINTABLE):
        x0 = i * advance + x_shift
        # Cap region
        cap_src = strip.crop((x0, 0 + y_shift, x0 + advance, ascent + y_shift))
        cap_rows_bytes = downsample_cell(cap_src, CELL_W, cap_rows, threshold)
        for r in range(cap_rows):
            glyphs[i * CELL_H + r] = cap_rows_bytes[r]
        if desc_rows > 0:
            dsc_src = strip.crop(
                (x0, ascent + y_shift, x0 + advance, ascent + descent + y_shift))
            dsc_rows_bytes = downsample_cell(
                dsc_src, CELL_W, desc_rows, threshold)
            for r in range(desc_rows):
                glyphs[i * CELL_H + cap_rows + r] = dsc_rows_bytes[r]
    return bytes(glyphs)


def write_preview(font_path, render_size, cap_rows, threshold,
                  x_shift, y_shift, out_path):
    """Render the 95-glyph block at 8× and save a PNG."""
    glyphs = render_all(
        font_path, render_size, cap_rows, threshold, x_shift, y_shift)
    scale = 8
    cols = 16
    rows = (len(PRINTABLE) + cols - 1) // cols
    gap = 2
    cell_w_px = (CELL_W + gap) * scale
    cell_h_px = (CELL_H + gap) * scale
    img = Image.new("RGB", (cols * cell_w_px, rows * cell_h_px), (20, 20, 30))
    px = img.load()
    for gi in range(len(PRINTABLE)):
        gx = gi % cols
        gy = gi // cols
        for r in range(CELL_H):
            byte = glyphs[gi * CELL_H + r]
            for c in range(CELL_W):
                on = (byte >> (7 - c)) & 1
                color = (220, 230, 255) if on else (40, 40, 55)
                bx = gx * cell_w_px + c * scale
                by = gy * cell_h_px + r * scale
                for dy in range(scale):
                    for dx in range(scale):
                        px[bx + dx, by + dy] = color
    img.save(out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", help="TTF/OTF input")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--author", required=True)
    ap.add_argument("--license", required=True)
    ap.add_argument("--render-size", type=int, default=64)
    ap.add_argument("--cap-rows", type=int, default=6,
                    help="rows for cap region (descender gets 8-cap_rows)")
    ap.add_argument("--threshold", type=int, default=112)
    ap.add_argument("--x-shift", type=int, default=0)
    ap.add_argument("--y-shift", type=int, default=0)
    ap.add_argument("--preview", help="write preview PNG")
    ap.add_argument("--cell-width", type=int, default=CELL_W)
    args = ap.parse_args()

    src = pathlib.Path(args.source).expanduser()
    if not src.exists():
        raise SystemExit(f"no such file: {src}")

    glyphs = render_all(src, args.render_size, args.cap_rows,
                        args.threshold, args.x_shift, args.y_shift)
    assert len(glyphs) == GLYPHS_SIZE

    header = (
        MAGIC
        + bytes([VERSION, args.cell_width, CELL_H, 0])
        + pad(args.name, 16)
        + pad(args.author, 16)
        + pad(args.license, 8)
    )
    assert len(header) == HEADER_SIZE

    out_path = pathlib.Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(header + glyphs)
    print(f"wrote {out_path} ({FILE_SIZE} bytes)")

    if args.preview:
        write_preview(src, args.render_size, args.cap_rows,
                      args.threshold, args.x_shift, args.y_shift,
                      args.preview)
        print(f"wrote preview {args.preview}")


if __name__ == "__main__":
    main()
