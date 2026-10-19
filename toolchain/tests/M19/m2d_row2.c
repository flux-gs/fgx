/* M19b: THE ELEMENT BESIDE THE ROW -- two subscripts on a rank-2 member in the
 * spellings m2d_row's row checks send through new code, and sizeof in both of
 * the operator's spellings.
 *
 * K&R A.8.6.2 (p.177): x3d[i][j][k] "is equivalent to *(x3d[i][j] + k)", so
 * m[i][j] is *(m[i] + j), and each element is checked against the union's FLAT
 * member at i*6 + j or against byte arithmetic from the struct's address --
 * never against another spelling of the same access.  A.7.4.8: sizeof "when
 * applied to an array, the result is the total number of bytes in the array",
 * and the operand "is either an expression, which is not evaluated, or a
 * parenthesized type name" -- so `sizeof(p->m[0])' and `sizeof p->m[0]' are
 * the same question.  The parenthesized one was refused, "expected ')'".
 */
struct filed {
    int  before;
    union {
        char f_uname[4][6];
        char f_fname[24];
    } f_un;
    int  after;
};

struct s3 {
    int  a;
    char u[3][5];
    int  b;
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
struct hop   H;
struct hop  *ph  = &H;

int main(void)
{
    int i, j, k, acc;
    char *r;

    i = 2;
    j = 3;
    k = 1;
    acc = 0;
    H.next = &S3;

    /* an array-of-struct element's member, then a pointer subscripted */
    FA[k].f_un.f_fname[i * 6 + j] = 'e';
    if (FA[k].f_un.f_uname[i][j] == 'e')
        acc += 1;
    if (pfa[k].f_un.f_uname[i][j] == 'e')
        acc += 2;

    /* sizeof, parenthesized and bare, of a row and of an element */
    if (sizeof(pf->f_un.f_uname[0]) == 6 && sizeof pf->f_un.f_uname[0] == 6)
        acc += 4;
    if (sizeof(pf->f_un.f_uname[1][2]) == 1 && sizeof pf->f_un.f_uname[1][2] == 1)
        acc += 8;

    /* one '->' hop and two, both subscripts: row 2 column 3 is 2 + 2*5 + 3 */
    *((char *)&S3 + 2 + i * 5 + j) = 'h';
    if (ps3->u[i][j] == 'h')
        acc += 16;
    if (ph->next->u[i][j] == 'h')
        acc += 32;

    /* A.8.6.2's identity, *(m[i] + j), through the row pointer */
    F.f_un.f_fname[i * 6 + j] = 'z';
    if (*(pf->f_un.f_uname[i] + j) == 'z')
        acc += 64;

    /* the row is a char *: it steps by one char */
    r = pf->f_un.f_uname[i];
    r++;
    if (r == &F.f_un.f_fname[i * 6 + 1])
        acc += 128;

    return acc;                      /* 255 */
}
