/* A store through an element of an array of struct pointers: `a[i]->f = v'.
 * K&R A.7.3.1 and A.7.3.3 make a[i]->f a postfix expression, and it is a
 * modifiable lvalue of the member's type (A.7.17), so =, op= and ++ all apply.
 * fcc read the shape and refused to store to it ("expected '='").  From a
 * local array, a global array, a long member, and a variable index.
 * Returns 42. */
struct m { int a; int len; long big; };
struct m *gms[3];

int main()
{
	struct m x, y, z, *ms[2];
	int k, bad = 0;

	ms[0] = &x; ms[1] = &y;
	gms[2] = &z;
	x.len = y.len = z.len = 0;
	k = 1;
	ms[k]->len = 5;
	ms[0]->len = 9;
	ms[k]->len += 3;
	ms[k]->len++;
	gms[2]->len = 7;
	gms[k + 1]->big = 70000L;
	if (y.len != 9) bad |= 1;
	if (x.len != 9) bad |= 2;
	if (z.len != 7) bad |= 4;
	if (z.big != 70000L) bad |= 8;
	if (ms[k]->len != 9 || gms[2]->len != 7) bad |= 16;
	return bad ? bad : 42;
}
