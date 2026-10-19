/* CU-1: single-subscript POINTER stores through a pointer-to-pointer
 * member — `p->y[a] = <ptr rhs>;` is a 4-byte far-pointer element store
 * (the subscript scales by sizeof(char*) = 4, and the WHOLE far pointer
 * including the bank byte must land — a 16-bit store would leave the
 * bank byte stale).  rhs shapes: member-subscript read (deleteln.c row
 * rotate), plain local (insertln.c), CU-1 &-double-subscript
 * (id_subwins.c), and a char*-returning call (newwin.c minus malloc);
 * every store is read back through the normal rvalue path and
 * dereferenced.  q's row table starts zero-filled (bank 0), so a
 * 2-byte store could not fake the round trip.  Exits 42 iff all four
 * land intact (10 + 10 + 10 + 12). */
struct w { char **y; };

char ra[4];
char rb[4];
char rc[4];
char *rows[3];
char *rows2[3];
struct w gw;
struct w gw2;

char *pick();

int
main()
{
    struct w *p;
    struct w *q;
    char *t;
    int i;
    int r = 0;

    rows[0] = ra;
    rows[1] = rb;
    rows[2] = rc;
    gw.y = rows;
    p = &gw;
    gw2.y = rows2;                /* rows2: zero-filled far NULLs */
    q = &gw2;

    ra[0] = 'a'; ra[1] = 'x';
    rb[0] = 'b';
    rc[0] = 'c';

    /* member-read rhs: rotate the rows the deleteln.c way, then put
     * the saved first row back at the bottom (plain local rhs). */
    t = p->y[0];                  /* t = ra */
    i = 0;
    p->y[i] = p->y[i + 1];        /* y[0] = rb */
    p->y[1] = p->y[2];            /* y[1] = rc */
    p->y[2] = t;                  /* y[2] = ra */
    if (p->y[0][0] == 'b' && p->y[1][0] == 'c' && p->y[2][0] == 'a')
        r += 10;

    /* member-read rhs into ANOTHER struct's zeroed table, then a
     * deref round trip — offset AND bank byte must have survived. */
    q->y[1] = p->y[2];            /* q row 1 = ra */
    if (q->y[1][1] == 'x')
        r += 10;

    /* CU-1 &-double-subscript rhs (the id_subwins.c shape). */
    q->y[0] = &p->y[2][1];        /* = &ra[1] */
    if (q->y[0][0] == 'x')
        r += 10;

    /* call rhs (the newwin.c shape), then write through and read the
     * global row back directly. */
    q->y[2] = pick();             /* = rc */
    q->y[2][3] = 'Z';
    if (rc[3] == 'Z' && q->y[2][0] == 'c')
        r += 12;

    return r;
}

char *
pick()
{
    return rc;
}
