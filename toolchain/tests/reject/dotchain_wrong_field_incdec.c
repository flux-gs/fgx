/* expect: no such field */
/* apple/fgx#85, the '++'/'--' arm.  `T.md.pre++` does NOT go through the same
 * lookup as `T.md.pre = 5`: a chain with two or more hops routes to the uniform
 * lvalue walker, which resolves the member itself and carries its own K&R pun
 * arm.  Fixing the store and read paths left this one silently punning, and
 * only probing every '.' spelling found it -- which is the argument for the
 * whole tests/reject/ directory rather than one case per issue. */
struct leaf { int pre; int i; };
struct mid  { struct leaf *lp; struct leaf ld; };
struct top  { struct mid *mp; struct mid md; };
struct top T;

int f() { T.md.pre++; return 0; }
