/* expect: no such field */
/* The compound-assignment spelling.  `T.md.pre += 1` reaches a different arm
 * again from both the plain store and the incdec walker. */
struct leaf { int pre; int i; };
struct mid  { struct leaf *lp; struct leaf ld; };
struct top  { struct mid *mp; struct mid md; };
struct top T;

int f() { T.md.pre += 1; return 0; }
