/* arraymemberdecay.c -- a struct member that is an ARRAY decays to a pointer,
 * whatever its element type.
 *
 * K&R A.7.1, p.161: "the value of the expression is a pointer to the first
 * object in the array, and the type of the expression is altered to ``pointer
 * to T''".  There is no exemption for what T is.
 *
 * fcc's bare-member decay named two types, LT_CHAR_ARRAY and LT_INT_ARRAY, so
 * a member array of anything FOUR BYTES wide -- long, unsigned long, float, a
 * pointer -- fell past it into the scalar load and the expression became
 * element [0]'s VALUE.  Not a width error: a different object.
 *
 * apple/fgx#409, found through apple/fgx#408.  fsck(8)'s pass1 does
 *
 *      bcmp((char *)dp->di_addr, (char *)zino.di_addr, NADDR * sizeof(daddr_t))
 *
 * and daddr_t is long, so `zino.di_addr' passed the CONTENTS of di_addr[0] --
 * zero, zino being the zero inode -- and bcmp compared 52 bytes at address 0,
 * the direct page.  Whether those bytes are zero depends on which disk driver
 * is live, so fsck called an intact filesystem clean on one controller and
 * badly damaged on another, and /etc/rc's `fsck -p' repaired what was never
 * broken.
 *
 * THE ASSERTION IS A ROUND TRIP THROUGH THE DECAYED POINTER, not a comparison
 * against `&m.arr[0]'.  Both would catch this, but the round trip also proves
 * the pointer is USABLE -- a decay that produced the right number by accident
 * still has to address the array -- and it does not need `&m.arr[0]', which
 * fcc cannot yet parse when a nested struct precedes the array member.
 *
 * The 1- and 2-byte cases are the CONTROL: they always worked, so a change
 * that fixed the wide types by breaking them shows up as 48/49 rather than as
 * a silent swap.
 *
 * Exit 42 = pass; every other code identifies the element type that failed.
 */
struct ic1 { unsigned short a, b, c, d; long e; };

struct dn { struct ic1 ic; long   addr[13]; };   /* the dinode shape */
struct ln { int a;         long   arr[13]; };
struct un { int a;         unsigned long arr[4]; };
struct fn { int a;         float  arr[4];  };
struct pn { int a;         char  *arr[4];  };
struct in { int a;         int    arr[8];  };
struct cn { int a;         char   arr[8];  };

struct dn vd;
struct ln vl;
struct un vu;
struct fn vf;
struct pn vp;
struct in vi;
struct cn vc;

/* The fsck shape: the array reaches a function as an argument, and the callee
 * reads through it. */
static long
firstlong(p)
	long *p;
{
	return (*p);
}

int main()
{
	long          *lp;
	unsigned long *up;
	float         *fp;
	char         **pp;
	int           *ip;
	char          *cp;

	/* 1. THE WIDE ELEMENT TYPES, which is where it was broken.  Write
	 *    through the member, read through the decayed pointer. */
	vd.addr[0] = 0x1234L;
	lp = vd.addr;
	if (*lp != 0x1234L)
		return (43);            /* long, after a nested struct */

	vl.arr[0] = 0x5678L;
	lp = vl.arr;
	if (*lp != 0x5678L)
		return (44);            /* long */

	vu.arr[0] = 0x9ABCL;
	up = vu.arr;
	if (*up != 0x9ABCL)
		return (45);            /* unsigned long */

	vf.arr[0] = 2.5;
	fp = vf.arr;
	if (*fp != 2.5)
		return (46);            /* float */

	vp.arr[0] = "x";
	pp = vp.arr;
	if (*pp != vp.arr[0])
		return (47);            /* pointer */

	/* 2. THE CONTROL: the widths that always decayed. */
	vi.arr[0] = 4242;
	ip = vi.arr;
	if (*ip != 4242)
		return (48);            /* int */

	vc.arr[0] = 'Z';
	cp = vc.arr;
	if (*cp != 'Z')
		return (49);            /* char */

	/* 3. AND THE OTHER DIRECTION: a store THROUGH the decayed pointer must
	 *    land in the array.  Equality of two reads could be satisfied by
	 *    both being wrong; this cannot. */
	lp = vl.arr;
	*lp = 0x4321L;
	if (vl.arr[0] != 0x4321L)
		return (50);

	/* 4. THROUGH AN ARGUMENT, which is how fsck reaches it.  A value that
	 *    never left the frame could be repaired by the caller's own cast;
	 *    this asks the same question of the call boundary. */
	vd.addr[0] = 0x0F0FL;
	if (firstlong(vd.addr) != 0x0F0FL)
		return (51);
	vl.arr[0] = 0x00FFL;
	if (firstlong(vl.arr) != 0x00FFL)
		return (52);

	/* 5. A NON-ZERO ELEMENT [0] IS THE WHOLE CONFUSION: a broken decay
	 *    yields that value where the address belongs, so with it set to
	 *    something that is not a valid address the round trip still holds
	 *    only if the decay is real. */
	vl.arr[1] = 0x7777L;
	vl.arr[0] = 0x0001L;
	lp = vl.arr;
	if (lp[1] != 0x7777L)
		return (53);

	return (42);
}
