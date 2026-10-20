/* A global float array takes a brace initializer: K&R A.8.7, "the
 * initializer for an array is a list of initializers for its members", in
 * order, and "if there are fewer initializers in the list than members of
 * the aggregate, the remaining members are initialized with 0".  fcc refused
 * the list ("brace-initializer requires int[N], long[N], ...").
 *
 * The items are the ones a float global takes: float literals, integer
 * literals converted to float, and a leading minus.  The unsized array is
 * sized by its list, and its sizeof proves it.  Exits 42 iff every element
 * reads back exactly -- each value here is exact in single precision. */
float full[3] = { 1.0, 2.5, 3 };
float part[4] = { -0.5 };
float unsz[] = { 7, -8.25 };

int
main()
{
    int ok;

    ok = 0;
    if (full[0] == 1.0 && full[1] == 2.5 && full[2] == 3.0)
        ok += 10;
    if (part[0] == -0.5 && part[1] == 0.0 && part[2] == 0.0 && part[3] == 0.0)
        ok += 10;
    if (unsz[0] == 7.0 && unsz[1] == -8.25)
        ok += 11;
    if (sizeof(unsz) == 2 * sizeof(float))
        ok += 11;
    return ok;
}
