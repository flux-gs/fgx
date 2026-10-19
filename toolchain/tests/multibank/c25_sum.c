/* c25_sum.c — extern callee pinned in a DIFFERENT code bank (construct 25).
 * Receives a struct BY VALUE (a stack copy made by the caller's MVN block move)
 * and sums its fields. */
struct c25_s { int a; int b; int c; };

int c25_sum(struct c25_s s) { return s.a + s.b + s.c; }
