/* apple/fgx#283: a CHAR ARRAY member of a struct, brace-initialised or from a
 * string literal.  Both were refused by the M22 field-type gate, which lists
 * the scalar and pointer field kinds it accepts, while an `int' array member
 * in the same position worked -- struct_init_leaves expanded every array
 * member EXCEPT a char one.
 *
 * K&R A.8.7 grants each spelling separately: "An aggregate is a structure or
 * array.  If an aggregate contains members of aggregate type, the
 * initialization rules apply recursively", and "As a special case, a character
 * array may be initialized by a string literal; successive characters of the
 * string initialize successive members of the array. ... if its size is fixed,
 * the number of characters in the string, not counting the terminating null
 * character, must not exceed the size of the array" -- so a string that
 * exactly fills the member is legal and loses only its NUL.
 *
 * THE MEMBER AFTER THE ARRAY IS THE REAL ASSERTION.  Expanding char arrays was
 * previously avoided because one string fills a WHOLE member, and a string
 * landing in only the first leaf would shift every later value up by one --
 * silently, since the result still compiles.  So every arm below checks the
 * trailing `b', and the short and exact-fit forms check the padding too.
 * Exits 42 iff all three land (14 + 14 + 14). */
struct t { int a; char n[4]; int b; };

struct t braced  = { 0x1111, {'A', 'B', 'C', 'D'}, 0x2222 };
struct t shortb  = { 0x3333, {'X'},                0x4444 };
struct t fromstr = { 0x5555, "hi",                 0x6666 };
struct t exact   = { 0x7777, "abcd",               0x1234 };

int
main()
{
    int r = 0;

    if (braced.a == 0x1111 && braced.b == 0x2222 &&
        braced.n[0] == 'A' && braced.n[1] == 'B' &&
        braced.n[2] == 'C' && braced.n[3] == 'D')
        r += 14;

    /* A SHORT group zero-fills within the member, it does not spill. */
    if (shortb.a == 0x3333 && shortb.b == 0x4444 &&
        shortb.n[0] == 'X' && shortb.n[1] == 0 &&
        shortb.n[2] == 0   && shortb.n[3] == 0)
        r += 14;

    if (fromstr.a == 0x5555 && fromstr.b == 0x6666 &&
        fromstr.n[0] == 'h' && fromstr.n[1] == 'i' &&
        fromstr.n[2] == 0   && fromstr.n[3] == 0 &&
        /* the exact-fit string keeps all four characters and drops its NUL */
        exact.a == 0x7777 && exact.b == 0x1234 &&
        exact.n[0] == 'a' && exact.n[3] == 'd')
        r += 14;

    return r;
}
