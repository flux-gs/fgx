/* c17_targets.c — extern callees in a DIFFERENT code bank (construct 17): the
 * function passed as an argument and the applier that calls it.  A fn-ptr TYPEDEF
 * param lets both the definition here and the prototype extern in c17_fnarg.c use
 * the SAME (prototype) ABI — a bare K&R extern would push args R-to-L against the
 * prototype callee and swap them.  Prototype fn-ptr param = the tputs idiom. */
typedef int (*c17_fn)(int);

int c17_dbl(int v) { return v + v; }

int c17_apply(c17_fn fp, int v) { return fp(v); }   /* calls the passed fn-ptr cross-bank */
