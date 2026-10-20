/* A multi-dimensional long or float array initialized from nested braces.
 * K&R A.8.7: the initializer list initializes the members in order, however
 * the braces nest, so each item is stored at its element's full width, and a
 * short row is zero-filled.  A failing check returns its number; all passing
 * returns 42. */
long m[2][2] = { {1, 70000}, {-1} };
float fm[2][2] = { {1.5, -2.0}, {3} };

int
main()
{
    if (m[0][0] != 1 || m[0][1] != 70000L) return 1;
    if (m[1][0] != -1L || m[1][1] != 0) return 2;
    if (fm[0][0] != 1.5 || fm[0][1] != -2.0) return 3;
    if (fm[1][0] != 3.0 || fm[1][1] != 0.0) return 4;
    return 42;
}
