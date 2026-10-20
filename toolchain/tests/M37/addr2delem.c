/* addr2delem.c -- `&arr[i][j]` on a multi-dimensional array, and the row
 * stride a multi-dim declaration builds.  apple/fgx#192.
 *
 * TWO FAULTS FROM ONE CAUSE, and the quiet one is the worse one.  The
 * address-of-element arm had no concept of dimensions: it took ONE subscript
 * and scaled it by the ELEMENT size.  So
 *
 *   &i2[1][2]   left the second '[' unread and the caller said "expected ')'";
 *   &i2[1]      COMPILED, and computed &i2[0][1].
 *
 * A row's stride is dims[1] * elem, not elem, so the second form was short by
 * a whole row and nothing said so.  A reject costs an afternoon; a wild
 * pointer costs whatever it corrupts.
 *
 * AND THE ELEMENT SIZE ITSELF WAS WRONG FOR 4-BYTE ELEMENTS.  Both multi-dim
 * declaration sites wrote `es = (t == LT_CHAR_ARRAY) ? 1 : 2` inline, so
 * `long l[3][4]` got a row stride of 8 instead of 16 -- and that one was never
 * about `&` at all: the plain READ `l2[1][2]` was already returning the wrong
 * element before this arm was touched.  The 1-D ladders had the 4-byte arms;
 * only the multi-dim sites lacked them.  `arr_row_elem_size` is now the one
 * place that answers it.
 *
 * K&R A.7.3.1 is recursive by construction -- "A postfix expression followed
 * by an expression in square brackets is a postfix expression", and E1[E2] is
 * *((E1)+(E2)) -- so i2[1][2] is the subscript production applied to its own
 * result, and A.8.6.2 gives the row its size.  A.7.4.2 then takes the address
 * of whatever that denotes.  Nothing in any of them makes a second subscript,
 * or a 4-byte element, a special case.
 *
 * WHY EVERY CASE READS A VALUE, AND WHY THE ARRAY IS SEEDED PER ELEMENT.  Both
 * faults produce a well-formed pointer to the wrong place; neither is visible
 * at compile time and neither is visible in an array of zeroes.  The seeding
 * pattern encodes the INDEX in the value (`0x100 + i*0x10 + j`), so a result
 * names the element it actually reached.
 *
 * THE PARTIAL-SUBSCRIPT CASES ARE THE POINT OF THE FILE, not an extra: `&a[i]`
 * on a 2-D array is the form that was silently wrong, and it is the one a fix
 * aimed only at the "expected ')'" symptom would leave broken while turning
 * the gate green.
 */

static int  i2[3][4];
static char c2[3][4];
static long l2[3][4];
static int  i3[2][3][4];

int main()
{
    int  *p;
    char *pc;
    long *pl;
    int   i, j, m, k;

    for (i = 0; i < 3; i++)
        for (j = 0; j < 4; j++) {
            i2[i][j] = 0x100 + i * 0x10 + j;
            c2[i][j] = (char)(0x10 + i * 4 + j);
            l2[i][j] = 0x77770000L + i * 0x10 + j;
        }
    for (i = 0; i < 2; i++)
        for (j = 0; j < 3; j++)
            for (m = 0; m < 4; m++)
                i3[i][j][m] = 0x200 + i * 0x40 + j * 0x08 + m;

    /* --- 50: the PARTIAL subscript -- the silently wrong one.  A stride of
     * `elem' rather than `dims[1] * elem' gives &i2[0][1], whose value is
     * 0x101 and not 0x110. ---------------------------------------------- */
    p = &i2[1];
    if (*p != 0x110) return (50);
    if (p[1] != 0x111) return (51);     /* ...and it is a whole row */
    if (p[4] != 0x120) return (52);     /* the next row begins where it should */

    /* --- 53: the FULL subscript -- what used to be rejected ------------ */
    p = &i2[1][2];
    if (*p != 0x112) return (53);
    if (p[1] != 0x113) return (54);

    /* --- 55: variable subscripts, which is what a loop writes ---------- */
    k = 2;
    p = &i2[k][1];
    if (*p != 0x121) return (55);

    /* --- 56: both indices zero, where every wrong stride multiplies to
     * zero and the case would pass whatever the strides are ------------- */
    p = &i2[0][0];
    if (*p != 0x100) return (56);

    /* --- 57: a 1-byte element, where the row stride is dims[1]*1 ------- */
    pc = &c2[2][3];
    if (*pc != (char)0x1B) return (57);

    /* --- 58: a 4-BYTE element.  This is the arr_row_elem_size half, and
     * the READ beside it is the half that was wrong before any of this
     * touched `&' -- so both are asserted. ----------------------------- */
    if (l2[1][2] != 0x77770012L) return (58);
    pl = &l2[1][2];
    if (*pl != 0x77770012L) return (59);
    if (pl[1] != 0x77770013L) return (60);
    pl = &l2[2];
    if (*pl != 0x77770020L) return (61);   /* partial, 4-byte rows */

    /* --- 62: three dimensions, so the per-level stride divide is
     * exercised more than once ----------------------------------------- */
    p = &i3[1][2][3];
    if (*p != 0x253) return (62);
    p = &i3[1][2];
    if (*p != 0x250) return (63);
    p = &i3[1];
    if (*p != 0x240) return (64);          /* one subscript of three */

    /* --- 65: the ADDRESS and the READ must agree, which is the invariant
     * the shared offset walk exists to keep.  Two paths that were each
     * self-consistent but disagreed with each other is exactly how the
     * 4-byte row stride survived. -------------------------------------- */
    p = &i2[2][1];
    if (*p != i2[2][1]) return (65);
    pl = &l2[2][1];
    if (*pl != l2[2][1]) return (66);

    return (42);
}
