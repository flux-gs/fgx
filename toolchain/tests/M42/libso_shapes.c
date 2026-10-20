/* M42: --libso block-static shapes, each through the lvalue walker. */
struct pt { int x; int y; };
static int n;                 /* scalar */
static int arr[4];            /* array element, zero-initialised (A.8.7) */
static struct pt p;           /* struct field */
static long big = 70000L;     /* long */
static char buf[8];           /* char array, sizeof */
static char sbuf[4];
static char *pt;              /* a pointer static, stored through (strftime) */
int sink();
int fls() { static int calls; return ++calls; }   /* function-local static */
int main()
{
    int i = 2;
    n = 3; n += 4; n++;                        /* store, op=, ++ */
    arr[i] = n; arr[i + 1] = arr[i] + 1;       /* index store/load, mixed */
    arr[i] += sink(arr[0]);                    /* op= with a call on the rhs */
    p.x = 5; p.y = p.x * 2;                    /* field store/load */
    big += 1;
    buf[sizeof(buf) - 1] = 'z';                /* sizeof is the array's */
    fls(); fls();
    pt = sbuf; *pt++ = 'a'; *pt = 'b';        /* through a block pointer */
    return (n == 8 && arr[2] == 8 && arr[3] == 9 && p.y == 10 &&
            big == 70001L && buf[7] == 'z' && sizeof(buf) == 8 &&
            fls() == 3 && arr[0] == 0 &&
            sbuf[0] == 'a' && sbuf[1] == 'b' && pt == sbuf + 1) ? 42 : 1;
}
int sink(v) int v; { return v; }
