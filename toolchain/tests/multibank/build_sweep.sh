#!/bin/bash
# Build the far-pointer construct-sweep multibank.bin, then run the
# anti-coincidence scan (a per-build false-green guard).
#
# Pipeline: compile TUs --data-segment -> gen_sweep_link.py (placement lint +
# fgx_static) -> anti-coincidence scan.
set -u
cd "$(dirname "$0")"
FCC="${FCC_OVERRIDE:-../../fcc}"    # FCC_OVERRIDE=<path>: Phase-2 differential
                                    # mode -- build the sweep with a CANDIDATE
                                    # fcc; the 34-construct oracle validates it

# TU list = every TU named anywhere in bankmap.json (bankmap order).  BALLAST
# entries (ballast/*) are no longer compiled: gen_sweep_link.py emits an inert
# DS filler for them (P3-2.6 one-mode fcc would FGX2_EXPORT their symbols and
# merge their data into the shared data segment -> cross-tool clashes).
TUS=$(python3 -c 'import json;print(" ".join(t for s in json.load(open("bankmap.json"))["code_segments"] for t in s))')
FIX_TUS=$(printf '%s\n' $TUS | grep -v '^ballast/' | tr '\n' ' ')

rm -rf ld
rm -f *.code.s *.data.s ballast_*.s multibank.bin

echo "== 1. compile =="
# -I../../include: toolchain headers.
for t in $FIX_TUS; do
  "$FCC" --data-segment "$t.data.s" -I../../include -I../../.. "$t.c" -o "$t.code.s" \
    || { echo "fcc FAIL $t"; exit 1; }
done

echo "== 2. lint + link (fgx_static, placement from bankmap.json) =="
python3 gen_sweep_link.py || { echo "link FAIL"; exit 1; }
echo "LINKED multibank.bin = $(wc -c < multibank.bin) B"

echo "== 3. anti-coincidence scan =="
python3 anti_coincidence.py || { echo "ANTI-COINCIDENCE FAIL (tag repeats in another bank -> false-green risk)"; exit 1; }
echo "BUILD OK"
