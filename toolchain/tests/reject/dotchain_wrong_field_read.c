/* expect: no such field */
/* The READ twin of dotchain_wrong_field: the store and the load arms of the
 * dot chain are separate code in fcc (parse_stmt.c vs parse_expr.c), so fixing
 * one and not the other is a live outcome, and only one of the two would have
 * been noticed.  */
struct leaf { int pre; int i; };
struct mid  { struct leaf *lp; struct leaf ld; };
struct top  { struct mid *mp; struct mid md; };
struct top T;

int f() { return T.md.pre; }
