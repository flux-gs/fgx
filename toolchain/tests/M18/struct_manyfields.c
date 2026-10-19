/* struct_manyfields: a structure with more than 32 members.
 *
 * fcc capped structures at 32 members, which is a conformance gap rather than
 * a design choice: K&R imposes no limit, and C89 2.2.4.1 sets the translation
 * limit at 127 members in one struct or union.  The cap is now 127.
 *
 * The gap was found porting 4.3BSD-Reno's VFS, whose `struct vnodeops` holds
 * exactly 32 function pointers -- it met the old cap with nothing to spare, so
 * the very next member anywhere would have failed.
 *
 * Counting members is the easy half; the half that actually breaks is OFFSET
 * arithmetic once the field table grows, so this fixture does not merely
 * declare 40 members, it writes distinct values through members spread across
 * the whole structure and reads them back.  If two members alias, or an offset
 * past the old cap is computed wrongly, the sum changes.  Mixed widths are
 * deliberate: char/short/long in sequence means every member after the first
 * sits at an offset that depends on correct accumulation, so drift anywhere
 * propagates to everything after it.  -> 42.
 */

struct many {
    char  c0;  short s0;  long l0;   char  c1;  short s1;  long l1;
    char  c2;  short s2;  long l2;   char  c3;  short s3;  long l3;
    char  c4;  short s4;  long l4;   char  c5;  short s5;  long l5;
    char  c6;  short s6;  long l6;   char  c7;  short s7;  long l7;
    char  c8;  short s8;  long l8;   char  c9;  short s9;  long l9;
    char  c10; short s10; long l10;  char  c11; short s11; long l11;
    short tail0; short tail1; short tail2; short tail3;
};

struct many M;

int
main()
{
    /* Zero it so a stale byte cannot be mistaken for a correct read. */
    char *p = (char *)&M;
    int   i;
    long  acc;

    for (i = 0; i < (int)sizeof(struct many); i++)
        p[i] = 0;

    /* First member, and members immediately either side of the OLD 32 cap
     * (member 32 is c10, at declaration index 32), and the very last. */
    M.c0    = 3;      /* member  0 */
    M.l5    = 7L;     /* member 17 */
    M.s10   = 5;      /* member 31 -- last one the old cap allowed */
    M.c11   = 9;      /* member 33 -- first one it did not */
    M.l11   = 11L;    /* member 35 */
    M.tail3 = 13;     /* member 39 -- the last */

    acc  = (long)M.c0 + M.l5 + (long)M.s10;
    acc += (long)M.c11 + M.l11 + (long)M.tail3;
    /* 3 + 7 + 5 + 9 + 11 + 13 == 48 */

    /* Nothing else may have been disturbed: every other member must still be
     * zero.  An aliasing offset shows up here even if the sum above survives. */
    if (M.c1 || M.s0 || M.l0 || M.c10 || M.s11 || M.tail0 || M.tail2)
        return 0;                       /* aliased -- fail loudly */

    return (int)acc - 6;                /* 48 - 6 == 42 */
}
