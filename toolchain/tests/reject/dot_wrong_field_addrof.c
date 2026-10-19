/* expect: no such field */
/* `&T.md.pre` -- taking the address is the shape that would hand the wrong
 * offset to something that writes it later, far from here. */
struct leaf { int pre; int i; };
struct mid  { struct leaf *lp; struct leaf ld; };
struct top  { struct mid *mp; struct mid md; };
struct top T;

int *f() { return &T.md.pre; }
