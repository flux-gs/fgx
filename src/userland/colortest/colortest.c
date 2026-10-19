/* colortest - SGR foreground/background colour grid for the FGX SHR console.
 *
 * FGX-original (not a BSD port).  Prints a 4x4 grid over the 640-mode four-
 * colour row palette (slot 0=blue, 1=grey, 2=red, 3=green); rows are the fg
 * slot, columns the bg slot, each cell labelled "<fg><bg>".  A visual check
 * that the per-cell SGR colour path works end to end:
 *   - the console SGR parser (console_vthandler.s) stores VT_SGR_FG / VT_SGR_BG,
 *   - _Vt_ApplySgr realizes them via Con_SetFg / Con_SetBg,
 *   - _Con_RenderCell paints the (bg<<2)|fg PreExpFont variant.
 * Cells on the diagonal (fg slot == bg slot) render invisible by design -- bg
 * is limited to the same four colours as fg.
 *
 * slot_code() maps a slot 0..3 to the ANSI colour code that _Vt_FgToSlot folds
 * into that slot, so the grid exercises all four row colours (incl. blue/slot 0,
 * which ANSI blue=4 now selects).  ESC is printf("%c",27) because each SGR
 * string interpolates variable colour codes (printf("%c[3%d;4%dm", ...)); a
 * bare "\033[..." string escape ALSO compiles fine (fcc lex_pp.c G16/G19;
 * pinned by toolchain tests/M37/strescapes.c) -- %c is just the natural fit
 * next to the %d codes here, not a workaround for a lexer gap.
 */
#include <stdio.h>

/* ANSI colour code that selects row-palette slot i (0..3) in 640 mode. */
int slot_code(int i)
{
    if (i == 0) return 4;               /* blue          -> slot 0 */
    if (i == 1) return 7;               /* white         -> slot 1 (grey) */
    if (i == 2) return 1;               /* red           -> slot 2 */
    return 2;                           /* green         -> slot 3 */
}

int main(void)
{
    int fg, bg;
    int e = 27;                         /* ESC */

    printf("FGX SGR fg/bg colour grid (slots: 0=blue 1=grey 2=red 3=green)\n");
    for (fg = 0; fg < 4; fg++) {
        for (bg = 0; bg < 4; bg++) {
            printf("%c[3%d;4%dm", e, slot_code(fg), slot_code(bg));
            printf(" %d%d ", fg, bg);   /* cell label = fg slot, bg slot */
        }
        printf("%c[0m\n", e);           /* reset attrs at row end */
    }
    printf("COLORDONE\n");
    return 0;
}
