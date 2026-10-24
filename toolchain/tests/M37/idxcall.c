/* M37: an index that calls a function (K&R A.7.3.1: "E1[E2] is identical
 * (by definition) to *((E1)+(E2))").  The base pointer's bank waits while
 * the index is evaluated, and a callee that reaches memory through another
 * bank must not change which bank the element is read from.  4.3BSD-Reno
 * doprnt.c's `digs[__lc_pf_qdiv(_quad, base)]' is the shape.  Each array
 * is static, in the data bank; via()'s `*q++' reads its own frame, on the
 * bank-0 stack, through _fcc_ptr.  Returns 42. */
static char digs[] = "0123456789";
static int  nums[4] = { 10, 11, 12, 13 };
static long lnum[3] = { 70000L, 70001L, 70002L };
static char *strs[3] = { "a", "b", "c" };
char *gp = digs;

int via(int k) { char b[2]; char *q; b[0] = (char)k; q = b; return *q++; }

int main()
{
    char *p = digs;
    int *ip = nums;
    long *lp = lnum;
    char **sp = strs;
    int r = 0;

    if (p[via(7)] == '7') r += 10;
    if (ip[via(2)] == 12) r += 10;
    if (lp[via(1)] == 70001L) r += 10;
    if (*sp[via(2)] == 'c') r += 5;
    p[via(3)] = 'x';
    if (digs[3] == 'x') r += 4;
    gp[via(4)] = 'y';
    if (digs[4] == 'y') r += 3;
    return r;
}
