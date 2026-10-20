/* expect: sizeof: no such field */
/* sizeof has its own dot/arrow walker, and it accepts BOTH operators in one
 * loop -- so it is the one place where the fix had to remember which operator
 * it had just consumed rather than treating the whole chain alike. */
struct leaf { int pre; int i; };
struct mid  { struct leaf *lp; struct leaf ld; };
struct top  { struct mid *mp; struct mid md; };
struct top T;

int f() { return sizeof(T.md.pre); }
