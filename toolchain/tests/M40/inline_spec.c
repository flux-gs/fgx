/* C99's `inline' function specifier, which fcc accepts and ignores: it asks
 * only that calls be fast, and changes no meaning.  Not K&R; not verified
 * against C99's text.  Both placements, after `static' and alone.  Returns
 * 42 when both functions are called. */
static inline int
twice(int x)
{
    return 2 * x;
}

inline int
thrice(int x)
{
    return 3 * x;
}

int
main()
{
    return twice(9) + thrice(8);
}
