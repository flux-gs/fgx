/* fcc2 P1.4 loop-scoped (region) promotion regression.  Each function makes a
 * real CALL (helper) so the WHOLE-function promotion gate bails, but has a
 * CALL-FREE hot for-loop whose int accumulator/index region-promote to a DP-IMG
 * slot: seed n,S->slot at loop entry, write slot->n,S at loop exit, slot
 * persists across iterations.  Covers the three exit paths the write-back must
 * be correct for, and a read of the var AFTER the loop (the write-back's reason
 * to exist).  Values vs a clang host reference; total masked to 8 bits.
 *   sum_loop(5):  s=1, +0+1+2+3+4            = 11   (fall-through exit)
 *   with_break(10): s=1, +0+1+2, break@i==3  = 4    (break exit)
 *   with_cont(5): s=1, +0+1+(skip 2)+3+4     = 9    (continue: back-edge, no WB)
 *   with_goto(5): s=1, +0+1+2, goto@i==2     = 4    (goto OUT -> region DISQUALIFIED)
 *   main: helper(0)=1 + 11 + 4 + 9 + 4       = 29
 * with_goto guards the goto write-back-bypass miscompile: a goto leaving the loop
 * skips IR_LOOP_END, so the region must NOT promote when a user label/goto ("_uL_")
 * is present -- it falls back to n,S and the value stays correct.
 */
static int helper(int x) { return x + 1; }   /* a real call -> whole-fn gate fails */

static int sum_loop(int n)
{
    int s = 0, i;
    s = helper(s);                  /* call -> region promotion path */
    for (i = 0; i < n; i++)         /* call-free loop: s,i region-promote */
        s = s + i;
    return s;                       /* reads s AFTER the loop -> write-back must run */
}

static int with_break(int n)
{
    int s = 0, i;
    s = helper(s);
    for (i = 0; i < n; i++) {
        if (i == 3) break;          /* break -> lab_end where the write-back sits */
        s = s + i;
    }
    return s;
}

static int with_cont(int n)
{
    int s = 0, i;
    s = helper(s);
    for (i = 0; i < n; i++) {
        if (i == 2) continue;       /* continue -> back-edge, slot persists, no WB */
        s = s + i;
    }
    return s;
}

static int with_goto(int n)
{
    int s = 0, i;
    s = helper(s);
    for (i = 0; i < n; i++) {
        s = s + i;
        if (i == 2) goto done;      /* goto OUT of the loop -> region disqualified */
    }
done:
    return s;                       /* must read the correct s (n,S, not a stale slot) */
}

int main(void)
{
    int t = helper(0);              /* 1 */
    t = t + sum_loop(5);            /* +11 = 12 */
    t = t + with_break(10);         /* +4  = 16 */
    t = t + with_cont(5);           /* +9  = 25 */
    t = t + with_goto(5);           /* +4  = 29 */
    return t & 0xFF;                /* 29 */
}
