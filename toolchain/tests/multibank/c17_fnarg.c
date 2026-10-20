/* c17_fnarg.c — construct 17: pass a fn-ptr as an argument to a callee in another
 * bank, which calls it (also in another bank).  The passed fn-ptr's bank must
 * survive the arg push and the indirect call must far-dispatch.  Prototype externs
 * (named params, via the fn-ptr typedef) match c17_targets' ABI so args aren't
 * swapped. */
typedef int (*c17_fn)(int);
extern int c17_dbl(int v);
extern int c17_apply(c17_fn fp, int v);

int c17_check(void) { return c17_apply(c17_dbl, 0x0B) == 0x16; }
