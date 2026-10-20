#!/bin/bash
# Regenerate all shipped FGX .FNT files under disk_src/lib/fonts/ from their
# sources.  Re-run after changing glyph data or metadata.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p "disk_src/lib/fonts"

python3 tools/gen_fnt.py \
    --from-s src/drivers/console/fonts/font_bold.s \
    --label Font_Bold_ASCII \
    --name "Bold default" \
    --author "generated" \
    --license "MIT" \
    --cell-width 6 \
    -o disk_src/lib/fonts/bold.fnt


# default35.fnt is NOT generated any more.  It was the 320-mode (3x5) font,
# and the 320 mode was removed on 2026-09-01; gen_fnt_3x5.py stays because it
# is the source of truth for those glyph shapes if the mode ever returns.

# DEFAULT.FNT - the 640-mode default font.  This is a committed binary asset:
# it was generated once from the retired Font_Default_ASCII
# inline blob via `gen_fnt.py --from-s ... --label Font_Default_ASCII` and has
# no remaining .s/.c source, so it is NOT regenerated here.
