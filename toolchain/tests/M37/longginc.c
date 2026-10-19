/* long-global ++/-- : 32-bit load-modify-store on a LT_LONG global.  Was:
 * die "global ++/-- expr: int/char/pointer only" (postfix) and "prefix
 * ++/-- on long global not supported yet".  A value-used postinc must
 * return the OLD long; discarded/prefix return the new.  compress:
 * free_ent++, in_count++, out_count++.  Exit 42. */
long fe = 40;
long ct = 0;

int main(void)
{
	long old;
	old = fe++;               /* value-used postinc: old=40, fe=41 */
	ct++;                     /* discarded postinc:  ct=1 */
	++fe;                     /* prefix:             fe=42 */
	--fe;                     /* discarded postdec:  fe=41 */
	if (old != 40) return 1;
	if (fe  != 41) return 2;
	if (ct  != 1)  return 3;
	return (int)(old - 40 + fe + ct);   /* 0 + 41 + 1 = 42 */
}
