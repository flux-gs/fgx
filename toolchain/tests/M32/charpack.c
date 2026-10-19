/* charpack.c — B-8: scalar char struct members are BYTE-PACKED (PDP-11 /
 * 2.11BSD layout: chars 1 byte, word members even-aligned, struct total
 * rounded to even).  RED before the 2026-07-06 parse_struct_def flip
 * (scalar chars got 2-byte slots: sizeof(struct{char;char;}) was 4),
 * GREEN after.  Also pins the fn-ptr-field alignment gap: the two fn-ptr
 * declarator paths appended at raw cur, which only stayed even because
 * chars used to occupy 2-byte slots.
 *
 * Exit 42 = pass; 1..13 identify the failing property.
 */
struct cc  { char a; char b; };                   /* 2 */
struct c3  { char a; char b; char c; };           /* 3 -> even round 4 */
struct ci  { char a; int i; };                    /* i re-aligns @2 -> 4 */
struct big { char a; char b; long l; char c; };   /* a@0 b@1 l@2 c@6 -> 8 */
struct fp  { char a; int (*f)(); };               /* f even-aligned @2 -> 6 */

struct cc  garr[3];
struct cc  gcc = { 11, 22 };     /* brace-init bytes land at packed offsets */
struct big gb;                   /* long-field brace-init is a separate M22
                                    gap (init supports int, char, char ptr,
                                    fn ptr only) — filled at runtime below */

int fret() { return 7; }

int take(s)
struct cc s;
{
	return s.a * 10 + s.b;
}

int main()
{
	struct cc l;
	struct fp f;
	int r;

	if (sizeof(struct cc)  != 2) return 1;
	if (sizeof(struct c3)  != 4) return 2;
	if (sizeof(struct ci)  != 4) return 3;
	if (sizeof(struct big) != 8) return 4;
	if (sizeof(struct fp)  != 6) return 5;
	/* adjacency: byte stores must not clobber the neighbour */
	l.a = 0x11; l.b = 0x22;
	if (l.a != 0x11 || l.b != 0x22) return 6;
	l.b = 0x33;
	if (l.a != 0x11) return 7;
	/* brace-init lands by the packed offsets */
	if (gcc.a != 11 || gcc.b != 22) return 8;
	/* long field at a packed offset (l@2 after two packed chars) */
	gb.a = 1; gb.b = 2; gb.l = 70000; gb.c = 3;
	if (gb.a != 1 || gb.b != 2 || gb.c != 3) return 8;
	if (gb.l != 70000) return 9;
	/* array-of-struct stride = packed size */
	garr[0].a = 1; garr[0].b = 2;
	garr[1].a = 3; garr[1].b = 4;
	garr[2].a = 5;
	if (garr[0].b != 2 || garr[1].a != 3 || garr[2].a != 5) return 10;
	/* char before a fn-ptr field: ptr must sit even-aligned at +2 */
	if ((char *)&f.f - (char *)&f != 2) return 11;
	f.a = 9;
	f.f = fret;
	if (f.a != 9) return 12;
	r = f.f();
	if (r != 7) return 12;
	/* by-value struct arg with packed chars (2-byte copy) */
	if (take(l) != 0x11 * 10 + 0x33) return 13;
	return 42;
}
