/* M42: --libso block-static shapes, second set: each is reached through its
 * member's block on the machine and must compute what the label form did. */
struct s { int a[3]; };
static int (*fp)();           /* call through a function-pointer static */
static int arr[4];
static long ll[2];            /* long element ++ */
static struct s v;            /* & of a member's element */
static int m[2][3];           /* two-dimensional */
static double d;              /* soft double */
static long long q;
static int *ptrs[2];          /* pointer array */
static unsigned char c;       /* unsigned char op= */
static int n;
int x = 11;
int g() { return 7; }
int main()
{
    int *p1, *p2;
    fp = g;
    arr[1] = 3; p1 = &arr[1];
    ll[1] = 70000L; ll[1]++;
    v.a[1] = 5; p2 = &v.a[1];
    m[1][2] = 4;
    d = 1.5; d = d * 2.0;
    q = 5; q = q * 3;
    ptrs[1] = &x;
    c = 4; c |= 3;
    n = 0;
    return (fp() == 7 && *p1 == 3 && ll[1] == 70001L && *p2 == 5 &&
            m[1][2] == 4 && (int)d == 3 && (int)q == 15 && *ptrs[1] == 11 &&
            c == 7 && (n ? 0 : 1)) ? 42 : 1;
}
