/* chainptr.c — regression for the fcc chained pointer-through-pointer deref-
 * store BANK bug (FGX2 multi-bank).
 *
 * `*T = *U = q` (T,U are char**) is `*U = q; *T = *U;`.  The inner store put
 * the correct far pointer (offset + DATA bank) into *U, but the OUTER store
 * dropped the BANK byte -> *T got bank $00 instead of the data bank.  This was
 * elvis curses.c pair()'s `*T = *U = ""` leaving KS = $00:6ECB; do_KS() then
 * deref'd the wrong bank, read nonzero kernel code, and streamed 20 code bytes
 * into kbuf -> the "vi draws garbage / no screen" bug.
 *
 * Under --data-segment the string "Z" lives in the DATA bank (seg1) while code
 * runs in seg0 (a different bank).  With the bug, `a` gets bank $00, so `a[0]`
 * reads bank $00 at "Z"'s offset (not 'Z').  Exit 42 iff BOTH a and b deref
 * back to the "Z" string correctly (right bank); a wrong bank derails the read.
 */

char *a = "xx";
char *b = "yy";
char **T;
char **U;

int main()
{
    T = &a;
    U = &b;

    *T = *U = "Z";

    if (a[0] == 'Z' && a[1] == 0 &&
        b[0] == 'Z' && b[1] == 0)
    {
        return 42;
    }
    return 1;
}
