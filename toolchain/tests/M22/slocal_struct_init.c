/* Static-local scalar struct initializer: `static struct tv t = { 5, 7 }`
 * inside a function is backed by a hidden file-scope global and routed through
 * the shared M22 brace-init walker (parse_struct_brace_init).  A partial
 * `{ 9 }` zero-fills the trailing field.  Formerly rejected with
 * "static struct-local initializer not supported yet".  -> 42. */
struct tv { long s; long u; };

int getpart(void)
{
	static struct tv p = { 9 };        /* p.s = 9, p.u zero-filled */
	return (int)(p.s + p.u);
}

int main(void)
{
	static struct tv t = { 5, 7 };
	if ((int)t.s != 5)  return 1;
	if ((int)t.u != 7)  return 2;
	if (getpart() != 9) return 3;
	return 42;
}
