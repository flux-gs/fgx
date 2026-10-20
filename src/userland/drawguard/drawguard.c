/* Repro of elvis redraw.c:1082-1085 — CHAINED long assignment (FGX2 multi-bank).
 *   if (redrawafter == INFINITY) { redrawafter = 0; preredraw = postredraw = INFINITY; }
 * After this, postredraw & preredraw MUST be INFINITY (2000000001). If the
 * chained long assignment miscompiles them to 0, the redraw draw-loop guard
 * `l < postredraw` (1 < 0) is FALSE -> redraw draws nothing -> vi hangs blank.
 * Exit 42 iff both are INFINITY (correct).
 */
#define INFINITY 2000000001L

long redrawafter = 0;
long preredraw   = 9;
long postredraw  = 9;

int main()
{
    redrawafter = INFINITY;       /* set by redraw(MARK_UNSET) */
    preredraw = 0L;               /* MARK_UNSET reset */
    postredraw = 0L;

    if (redrawafter == INFINITY)  /* long == compare */
    {
        redrawafter = 0L;
        preredraw = postredraw = INFINITY;   /* the chained long assignment */
    }

    if (postredraw == INFINITY && preredraw == INFINITY)
        return 42;                /* correct */
    /* diagnose: return low byte of postredraw so we see what it became */
    return (int)(postredraw & 0xFF) | 0x80;
}
