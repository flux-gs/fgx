/* A struct's pointer fields initialized by an address plus or minus a
 * constant.  K&R A.7.19: "Initializers must evaluate either to a constant or
 * to the address of a previously declared external or static object plus or
 * minus a constant."  2.11BSD sort's `struct field proto = { nofold+128, ...'
 * is the case.  The displacement is pointer arithmetic, so it scales by the
 * pointee: ip's +2 is four bytes into iarr, and the value after each field
 * (n) must still land in its own member.  Returns 42. */
char tab[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
int iarr[4] = { 10, 20, 30, 40 };

struct field {
    char *cp;
    int *ip;
    char *dp;
    int n;
} f = { tab+3, iarr+2, tab+6-1, 9 };

int main()
{
    return f.cp[0] + *f.ip + f.dp[0] + f.n - 7 + (f.ip[-2] == 10 ? 0 : 50);
}
