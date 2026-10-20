/* M19b: ONE SUBSCRIPT ON A MULTI-DIMENSIONAL MEMBER IS A ROW, and a row is an
 * array, so its value is a pointer to the row's first element -- in every
 * spelling that reaches the member.
 *
 * K&R 2nd ed A.8.6.2 (p.177): "x3d[i][j] is an array of 7 integers, and x3d[i]
 * is an array of 5 arrays of 7 integers", and x3d[i][j][k] "is equivalent to
 * *(x3d[i][j] + k) ... the addition involves multiplication by the size" of
 * what the row points at.  A.7.3.3 (p.164) makes the member route irrelevant:
 * the type of E1->MOS "is the type of the member", and "E1->MOS is the same as
 * (*E1).MOS".  So p->m[i] is &p->m[i][0], whichever arm parses it.
 *
 * The '->' arms indexed a rank-2 member as if it were rank 1 and LOADED the
 * element: p->m[i] was the char at byte i, where it should be the address
 * i*row bytes in.  syslogd's `strncpy(f->f_un.f_uname[i], ...)' copied every
 * user name to the same wrong place, and its user and wall lines never
 * matched a login.  Each bit below is one spelling; the reference for each is
 * the union's FLAT member at i*6, so a row is checked against the storage rule
 * rather than against another spelling of itself.
 */
struct filed {
    int  before;
    union {
        char f_uname[4][6];          /* row stride 6 */
        char f_fname[24];
    } f_un;
    int  after;
};

struct s3 {
    int  a;
    char u[3][5];                    /* directly in the struct: the one-hop arm */
    int  b;
};

struct s4 {
    int  c;
    int  w[3][4];                    /* an INT row: stride 8 bytes */
};

struct hop {
    struct s3 *next;
};

struct filed F;
struct filed FA[2];
struct filed *pf  = &F;
struct filed *pfa = FA;
struct s3    S3;
struct s3   *ps3 = &S3;
struct s4    S4;
struct s4   *ps4 = &S4;
struct hop   H;
struct hop  *ph  = &H;

static int
rowlen(r)
char *r;
{
    int n = 0;

    while (r[n])
        n++;
    return n;
}

int main(void)
{
    int i, k, acc;
    char *r;

    i = 2;
    k = 1;
    acc = 0;
    H.next = &S3;

    /* '->' then '.': syslogd's own spelling */
    r = pf->f_un.f_uname[i];
    if (r == &F.f_un.f_fname[i * 6])
        acc += 1;

    /* one '->' hop, and two.  u follows a 2-byte int, so row i is 2 + i*5
     * bytes into the struct. */
    if (ps3->u[i] == (char *)&S3 + 2 + i * 5 &&
        ph->next->u[i] == (char *)&S3 + 2 + i * 5)
        acc += 2;

    /* (*E1).MOS, which A.7.3.3 says E1->MOS IS */
    if ((*pf).f_un.f_uname[i] == &F.f_un.f_fname[i * 6])
        acc += 4;

    /* an array-of-struct element, and a pointer subscripted like one */
    if (FA[k].f_un.f_uname[i] == &FA[k].f_un.f_fname[i * 6])
        acc += 8;
    if (pfa[k].f_un.f_uname[i] == &FA[k].f_un.f_fname[i * 6])
        acc += 16;

    /* the row's first element, through the row */
    F.f_un.f_fname[i * 6] = 'q';
    if (*pf->f_un.f_uname[i] == 'q')
        acc += 32;

    /* an int member: the row stride is 4 elements of 2 bytes */
    if ((char *)ps4->w[i] == (char *)&S4 + 2 + i * 8)
        acc += 64;

    /* a row as an argument, and sizeof of a row (A.7.4.8: "when applied to an
     * array, the result is the total number of bytes in the array") */
    F.f_un.f_fname[6] = 'a';
    F.f_un.f_fname[7] = 'b';
    F.f_un.f_fname[8] = 'c';
    F.f_un.f_fname[9] = 0;
    if (rowlen(pf->f_un.f_uname[1]) == 3 && sizeof pf->f_un.f_uname[0] == 6)
        acc += 128;

    return acc;                      /* 255 */
}
