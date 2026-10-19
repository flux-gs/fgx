/* Group 2 '->'member operator ops (tr(1) next()/nextc()):
 *   *t->p        deref of a '->'member pointer            (2a)
 *   t->last++    postfix '++' on an int member (yields OLD) (2b-int)
 *   *t->p++      postfix '++' on a ptr member, then deref   (2a + 2b-ptr)
 *   *--t->p = v  prefix '--' on a ptr member, then deref-store (2c)
 * parse_unary's '*'-fast-path skips a '->'member operand (general path +
 * emit_deref_general); parse_primary's '->' block handles postfix ++/-- via
 * emit_member_incdec; parse_unary's prefix block handles --member.  This
 * fixture is single-bank (the golden harness passes no --data-segment);
 * the multi-bank path is validated behaviorally by the tr(1) port.
 *
 * Trace: buf[0]=10 buf[1]=20, last=5, p=&buf[0].
 *   a=*p=10; b=last++ (5, last->6); c=*p++ (10, p->&buf[1]);
 *   d=*p=20; *--p=0 (p->&buf[0], buf[0]=0).
 *   return 10+5+10+20 + buf[0](0) + last(6) = 51. */
char buf[8];
struct s { int last, max; char *p; } S;
int f(t)
struct s *t;
{
	int a, b, c, d;
	a = *t->p;
	b = t->last++;
	c = *t->p++;
	d = *t->p;
	*--t->p = 0;
	return a + b + c + d + buf[0] + t->last;
}
int main(){
	buf[0] = 10; buf[1] = 20;
	S.last = 5; S.max = 0; S.p = buf;
	return f(&S);
}
