/* A multi-dimensional array initialized with its inner braces elided.  K&R
 * A.8.7: "If, however, the initializer for a subaggregate does not begin with
 * a left brace, then only enough elements from the list are taken into
 * account for the members of the subaggregate; any remaining members are left
 * to initialize the next member of the aggregate of which the subaggregate is
 * a part."  y is K&R's own example; ml is 4.3BSD-Reno ctime.c's mon_lengths.
 * A static local is a static object like any other: sl() holds its 2-D
 * arrays, asctime's wday_name among them -- rows filled exactly by 3-char
 * strings, which keep no NUL (A.8.7, "not counting the terminating null").
 * A failing check returns its number; all passing returns 42. */
float y[4][3] = {
	1, 3, 5, 2, 4, 6, 3, 5, 7
};
int ml[2][12] = {
	31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
	31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
};
int mix[3][2] = { {1, 2}, 3, 4, {5} };      /* braced, elided, braced */
int unsized[][3] = { 1, 2, 3, 4 };             /* size from the list: 2 rows */
int cube[2][2][2] = { {1, 2, 3}, 4 };       /* elision one level down */
long wide[2][2] = { 1, 70000L, -1 };
int trail[2][2] = { 1, 2, 3, };             /* the trailing comma is the list's */

/* The rows as upstream's asctime reads them, with "%.3s". */
static int
sl()
{
    static char wday[7][3] = {
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
    };
    static int dm[2][3] = { 1, 2, 3, 4 };
    static int sz[][2] = { {1, 2}, 3 };

    if (wday[0][0] != 'S' || wday[0][2] != 'n' || wday[1][0] != 'M')
        return 13;
    if (wday[6][0] != 'S' || wday[6][1] != 'a' || wday[6][2] != 't')
        return 14;
    if (dm[1][0] != 4 || dm[1][1] != 0 || dm[1][2] != 0) return 15;
    if (sizeof sz != 4 * sizeof (int) || sz[1][0] != 3 || sz[1][1] != 0)
        return 16;
    return 0;
}

int
main()
{
    int r;

    if (y[0][0] != 1.0 || y[0][2] != 5.0 || y[1][0] != 2.0) return 1;
    if (y[2][2] != 7.0 || y[3][0] != 0.0 || y[3][2] != 0.0) return 2;
    if (ml[0][1] != 28 || ml[1][1] != 29 || ml[1][11] != 31) return 3;
    if (mix[0][1] != 2 || mix[1][0] != 3 || mix[1][1] != 4) return 4;
    if (mix[2][0] != 5 || mix[2][1] != 0) return 5;
    if (sizeof unsized != 6 * sizeof (int)) return 6;
    if (unsized[1][0] != 4 || unsized[1][1] != 0 || unsized[1][2] != 0) return 7;
    if (cube[0][0][0] != 1 || cube[0][0][1] != 2) return 8;
    if (cube[0][1][0] != 3 || cube[0][1][1] != 0) return 9;
    if (cube[1][0][0] != 4 || cube[1][1][1] != 0) return 10;
    if (wide[0][1] != 70000L || wide[1][0] != -1L || wide[1][1] != 0) return 11;
    if (trail[1][0] != 3 || trail[1][1] != 0) return 12;
    if ((r = sl()) != 0) return r;
    return 42;
}
