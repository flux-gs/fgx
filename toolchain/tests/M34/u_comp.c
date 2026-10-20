/* u_comp.c — A-1 unsigned compound assign: emit_binop_for_compound used to
 * hard-force signed for every op= regardless of operand types; the LHS's
 * signedness is now captured at load time (usual-arithmetic: either
 * operand unsigned => unsigned).  Exit 42. */
unsigned int u;

int main()
{
	int n;

	n = 0;
	u = 0x9000;
	u /= 2;                        /* unsigned 0x4800; signed -28672/2 = 0xC800 */
	if (u == 0x4800) n += 1;
	u = 0x9000;
	u >>= 4;                       /* logical 0x0900; arithmetic 0xF900 */
	if (u == 0x0900) n += 2;
	u = 0xFFF0;
	u %= 7;                        /* 65520 % 7 == 0; signed -16 % 7 == -2 */
	if (u == 0) n += 4;
	return n == 7 ? 42 : n;
}
