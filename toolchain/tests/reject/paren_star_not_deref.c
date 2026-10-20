/* expect: expected ';' */
/* THE GUARD ON THE `(*E).m` -> `E->m` REWRITE (apple/fgx#95).
 *
 * K&R A.7.3.3 makes `(*E).m` and `E->m` the same expression, and fcc now
 * normalises the first into the second.  The rewrite is done on the token
 * stream, where `( * ...` is only a dereference if what follows the `*` is a
 * single postfix-expression.
 *
 * Here it is not: the `*` binds to `a` alone, and the parens group a
 * CONDITIONAL.  Cancelling the `*` against the `.` would silently produce
 * `a ? b : c -> f` -- a program that still parses and computes something else,
 * which is the only failure mode of a stream rewrite worth fearing.  This must
 * be REJECTED, not quietly reinterpreted.
 *
 * The message is the pre-existing one for a `.` the parser cannot place; the
 * assertion here is that the rewrite declined to fire, not that the diagnostic
 * is good. */
struct s { int f; };
struct s *b;
struct s *c;
int a;

int f() { return (*a ? b : c).f; }
