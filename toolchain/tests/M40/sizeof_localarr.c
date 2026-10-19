/* sizeof a local array.  K&R A.7.4.8: "when applied to an array, the result
 * is the total number of bytes in the array".  A local array of long, float,
 * long long or pointers answered one element's size, so the element-count
 * idiom `sizeof a / sizeof a[0]' gave 1; a char array answered its frame
 * slots, so `char c[5]' gave 6.  Globals were right, and are checked beside
 * them.  And a subscript of a multi-dimensional array is a row (A.8.6.2),
 * local or global, where sizeof answered one element; two subscripts did not
 * parse.  A failing check returns its number; all passing returns 42. */
struct q { int a; char b; };
char gc[5];
long gl[4];
int gm[4][5];

int
main()
{
    char c[5];
    int i[3];
    long l[4];
    float f[3];
    long long ll[2];
    char *p[3];
    struct q sq[3];
    long m[2][3];

    if (sizeof c != 5 || sizeof(c) != 5 || sizeof c != sizeof gc) return 1;
    if (sizeof i != 6) return 2;
    if (sizeof l != 16 || sizeof l / sizeof l[0] != 4 || sizeof l != sizeof gl)
        return 3;
    if (sizeof f != 12 || sizeof f / sizeof f[0] != 3) return 4;
    if (sizeof ll != 16) return 5;
    if (sizeof p != 12 || sizeof p / sizeof p[0] != 3) return 6;
    if (sizeof sq != 3 * sizeof(struct q)) return 7;
    if (sizeof m != 24 || sizeof(m) / sizeof(m[0]) != 2) return 8;
    if (sizeof m[1] != 12 || sizeof(m[0][2]) != 4) return 9;
    if (sizeof gm[3] != 10 || sizeof gm / sizeof gm[0] != 4 ||
        sizeof gm[0][0] != 2) return 10;
    if (sizeof p[0][1] != 1) return 11;
    return 42;
}
