/* apple/fgx#454: `e ? p : i' and `e ? i : p' with an integer arm that is NOT
 * the constant 0 have the POINTER type, as 2.11BSD's ccom gives them
 * (usr/lib/ccom/c01.c:290-305, with the warning "illegal combination of
 * pointer and integer, op :").  2.11BSD's sh expands $0..$9 through exactly
 * this shape -- macro.c:87 `v=((c==0) ? cmdadr : (c<=dolc) ? dolv[c] :
 * (dolg=0))' -- and fcc typed it int: the pointer arms kept only their offset,
 * the store gave them the data bank, and a pointer into any other bank read
 * the wrong memory.  Every script saw $0..$9 empty.
 *
 * The pointer arm here points at a LOCAL array, which is never in the data
 * bank, so an int-typed result reads the wrong bank.  The integer arm is a
 * RUNTIME zero, which must still be the null pointer.
 * Exit 42, or the number of the first check that failed. */
static int iv(int x) { return x; }

static char *cmd;
static char *vec[3];

int main(void)
{
    char loc[4];
    char *p;
    int c, d = 5;

    loc[0] = 'x'; loc[1] = 0;
    cmd = loc; vec[1] = loc;

    c = iv(1);
    p = (c == 1) ? loc : (d = 0);           /* pointer arm taken */
    if (p[0] != 'x') return 1;
    if (d != 5) return 2;

    c = iv(2);
    p = (c == 1) ? loc : (d = 0);           /* integer arm taken */
    if (p) return 3;
    if (d != 0) return 4;

    d = 5;
    p = (c == 2) ? (d = 0) : loc;           /* integer arm first */
    if (p) return 5;
    p = (c != 2) ? (d = 0) : loc;
    if (p[0] != 'x') return 6;

    /* sh's own nesting: $0, then $1, then past the end */
    c = iv(0);
    p = ((c == 0) ? cmd : (c <= 1) ? vec[c] : (d = 0));
    if (p[0] != 'x') return 7;
    c = iv(1);
    p = ((c == 0) ? cmd : (c <= 1) ? vec[c] : (d = 0));
    if (p[0] != 'x') return 8;
    c = iv(2);
    p = ((c == 0) ? cmd : (c <= 1) ? vec[c] : (d = 0));
    if (p) return 9;
    return 42;
}
