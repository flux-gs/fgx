#!/usr/bin/env python3
"""Produce FGX FGXF v1 font files (.FNT, 808 B).

Sources:
  --from-s   path/to/font_xxx.s      label pulled via --label (Font_XXX_ASCII)
  --from-c   path/to/fontNxM.c       Baron Williams column-oriented .c; width
                                     from --col-width
  --from-raw path/to/raw760.bin      raw 760-byte glyph block

Header metadata (CLI):
  --name "Display Name"        16-byte field
  --author "Someone"           16-byte field
  --license "MIT"              8-byte field
  --cell-width N               1-byte field (informational)
  --cell-height N              1-byte field (informational, default 8)

Output:
  -o path/to/OUT.FNT
"""
import argparse
import pathlib
import re

MAGIC = b"FGXF"
VERSION = 1
HEADER_SIZE = 48
GLYPHS_SIZE = 760
FILE_SIZE = HEADER_SIZE + GLYPHS_SIZE  # 808

def pad(s, n):
    b = s.encode("latin-1")
    if len(b) > n:
        raise SystemExit(f"field value {s!r} too long (max {n} bytes)")
    return b + b"\x00" * (n - len(b))

def from_s(path, label):
    lines = pathlib.Path(path).read_text().splitlines()
    start = None
    end = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == label:
            start = i
            continue
        if start is not None:
            # End when a new label starts (another Font_*) or a banner comment.
            if re.match(r"^[A-Za-z_][A-Za-z0-9_]*\s*$", stripped) and stripped != label:
                end = i
                break
            if stripped.startswith(";====") or stripped.startswith(";----"):
                end = i
                break
    if start is None:
        raise SystemExit(f"label {label} not found in {path}")
    if end is None:
        end = len(lines)
    out = []
    for line in lines[start + 1:end]:
        s = line.strip()
        if not s.startswith("DFB"):
            continue
        for tok in s[3:].split(","):
            tok = tok.strip()
            if not tok:
                continue
            assert tok.startswith("$"), tok
            out.append(int(tok[1:], 16) & 0xFF)
    if len(out) != GLYPHS_SIZE:
        raise SystemExit(f"{label}: expected {GLYPHS_SIZE} bytes, got {len(out)}")
    return bytes(out)

def from_c(path, col_width):
    text = pathlib.Path(path).read_text()
    m = re.search(r"\{(.*?)\}\s*;", text, re.DOTALL)
    if not m:
        raise SystemExit(f"initializer not found in {path}")
    body = re.sub(r"//.*", "", m.group(1))
    body = re.sub(r"/\*.*?\*/", "", body, flags=re.DOTALL)
    nums = re.findall(r"0x[0-9A-Fa-f]+|-?\d+", body)
    vals = []
    for n in nums:
        if n.lower().startswith("0x"):
            vals.append(int(n, 16) & 0xFF)
        else:
            vals.append(int(n) & 0xFF)
    if len(vals) != 95 * col_width:
        raise SystemExit(f"expected {95*col_width} source bytes, got {len(vals)}")
    out = bytearray(95 * 8)
    for ch in range(95):
        cols = vals[ch*col_width:(ch+1)*col_width]
        for r in range(8):
            byte = 0
            for c, col in enumerate(cols):
                if (col >> r) & 1:
                    byte |= 1 << (7 - c)
            out[ch*8 + r] = byte
    return bytes(out)

def from_raw(path):
    data = pathlib.Path(path).read_bytes()
    if len(data) != GLYPHS_SIZE:
        raise SystemExit(f"{path}: expected {GLYPHS_SIZE} bytes, got {len(data)}")
    return data

def main():
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--from-s", metavar="PATH")
    src.add_argument("--from-c", metavar="PATH")
    src.add_argument("--from-raw", metavar="PATH")
    ap.add_argument("--label", help="label name for --from-s")
    ap.add_argument("--col-width", type=int, help="source column count for --from-c")
    ap.add_argument("--name", required=True)
    ap.add_argument("--author", required=True)
    ap.add_argument("--license", required=True)
    ap.add_argument("--cell-width", type=int, required=True)
    ap.add_argument("--cell-height", type=int, default=8)
    ap.add_argument("-o", "--output", required=True)
    args = ap.parse_args()

    if args.from_s:
        if not args.label:
            raise SystemExit("--label required with --from-s")
        glyphs = from_s(args.from_s, args.label)
    elif args.from_c:
        if not args.col_width:
            raise SystemExit("--col-width required with --from-c")
        glyphs = from_c(args.from_c, args.col_width)
    else:
        glyphs = from_raw(args.from_raw)

    header = (
        MAGIC
        + bytes([VERSION, args.cell_width, args.cell_height, 0])
        + pad(args.name, 16)
        + pad(args.author, 16)
        + pad(args.license, 8)
    )
    assert len(header) == HEADER_SIZE, len(header)

    out_path = pathlib.Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(header + glyphs)
    print(f"wrote {out_path} ({FILE_SIZE} bytes)")

if __name__ == "__main__":
    main()
