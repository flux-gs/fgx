/* apple/fgx#284: a declaration list may MIX a function-pointer declarator with
 * ordinary ones.  `int (*fp)();' alone always worked; in a comma list it
 * failed in either order, at block scope and at file scope -- and at file
 * scope even an all-fn-ptr list failed, because that path took one declarator
 * and returned.
 *
 * K&R A.8 gives the list as `init-declarator-list: init-declarator |
 * init-declarator-list , init-declarator', with `init-declarator: declarator |
 * declarator = initializer'.  Each element is a full declarator in its own
 * right and only the declaration-specifiers are shared, so nothing requires
 * the elements to share a shape.
 *
 * THE ORDINARY DECLARATORS AROUND THE FN-PTR ARE THE ASSERTION.  A list that
 * mis-parses can still leave the fn-ptr itself working while the neighbours
 * take the wrong storage, so every arm here uses the plain variables declared
 * beside the pointer, and one fn-ptr carries an initializer mid-list.
 * Exits 42 iff all three land (14 + 14 + 14). */

int gplain, (*gfp)();           /* file scope, plain first  */
int (*gfp2)(), gplain2;         /* file scope, fn-ptr first */
int (*gfa)(), (*gfb)();         /* file scope, two fn-ptrs  */

seven()  { return 7; }
eleven() { return 11; }

int
main()
{
    int i, n, (*fp)(), nif;     /* the 2.11BSD fsck inode.c:59 shape */
    int a, (*fq)() = seven, b;  /* an initializer on a mid-list fn-ptr */
    int r = 0;

    i = 1; n = 2; nif = 3;
    fp = eleven;
    if ((*fp)() == 11 && i == 1 && n == 2 && nif == 3)
        r += 14;

    a = 4; b = 5;
    if ((*fq)() == 7 && a == 4 && b == 5)
        r += 14;

    gplain = 6; gplain2 = 8;
    gfp = seven; gfp2 = eleven; gfa = seven; gfb = eleven;
    if ((*gfp)() == 7 && (*gfp2)() == 11 &&
        (*gfa)() == 7 && (*gfb)() == 11 &&
        gplain == 6 && gplain2 == 8)
        r += 14;

    return r;
}
