/* An assignment expression has the type of its left operand (K&R A.7.17),
 * so storing 0xF000 into an unsigned object and widening the assignment's
 * value to long zero-extends -- through a pointer, an array element and a
 * struct member alike.  Returns 42. */
unsigned ua[2];
struct t { unsigned u; } st;
unsigned uv;
unsigned *up = &uv;

int
main()
{
	long v;
	int r;

	r = 0;
	v = (*up = 0xF000);	if (v == 61440L) r += 14;
	v = (ua[1] = 0xF000);	if (v == 61440L) r += 14;
	v = (st.u = 0xF000);	if (v == 61440L) r += 14;
	return r;
}
