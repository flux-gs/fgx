/* A pointer or arithmetic object's initializer may sit in braces.  K&R A8.7:
 * "The initializer for a pointer or an object of arithmetic type is a single
 * expression, perhaps in braces."  SunOS eject.c's
 * `char *default_dev = { "/dev/rfd0c" };' is the shape fcc rejected, at file
 * scope, in a block and as a static local alike.  A trailing comma is A8.7's
 * list nicety.  Each value is read back at run time.  Exits 42 iff all six
 * hold. */
char *gp = { "eject" };
long gl = { 70000L, };
int gi = { -3 };

int
f(n)
int n;
{
    int x = { n + 1 };
    static int k = { 5 };
    char *s = { "z", };

    return x + k + (*s == 'z');
}

int
main()
{
    int ok;

    ok = 0;
    if (gp[0] == 'e' && gp[4] == 't' && gp[5] == 0)
        ok += 7;
    if (gl == 70000L)
        ok += 7;
    if (gi == -3)
        ok += 7;
    if (f(1) == 2 + 5 + 1)
        ok += 21;
    return ok;
}
