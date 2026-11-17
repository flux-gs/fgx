/* `&' of any lvalue (K&R A.7.4.2: "The operand must be an lvalue referring
 * neither to a bit-field nor to an object declared as register"), in the
 * shapes 2.11BSD's socket and IP code spells: IA_SIN's
 * `&(((struct in_ifaddr *)ia)->ia_addr)', sblock's `&(sb)->sb_flags' with sb
 * itself `&so->so_snd', and sorwakeup's `&(so)->so_rcv' with so itself
 * `inp->inp_socket', with and without a wrapping pair of parentheses.
 * Each address is written through and must land in the right member.
 * `&rp->m' through a register pointer names the pointee, which is allowed.
 * Returns 42. */
struct sa { int f; };
struct ia { int x; struct sa addr; int arr[3]; };
struct sb { int sb_cc; int sb_flags; };
struct so { int t; struct sb so_snd, so_rcv; };
struct inp { int q; struct so *inp_socket; };

struct ia gia;
struct so gso;
struct inp ginp;

int main()
{
	char *cp;
	struct sa *a;
	int *x;
	struct sb *r;
	struct ia arr[2], *p;
	register struct ia *rp;

	cp = (char *)&gia;
	ginp.inp_socket = &gso;
	p = &gia;

	a = &(((struct ia *)cp)->addr);
	a->f = 10;
	x = &(&gso.so_snd)->sb_flags;
	*x = 8;
	r = &(ginp.inp_socket)->so_rcv;
	r->sb_cc = 5;
	r = &((ginp.inp_socket)->so_rcv);
	r->sb_flags = 4;
	x = &p->arr[2];
	*x = 6;
	a = &arr[1].addr;
	a->f = 7;
	p = &*p;
	p->x = 2;
	rp = &gia;			/* through a register POINTER is allowed */
	x = &rp->arr[0];
	*x = 0;
	x = &((rp)->arr)[1];
	*x = 0;

	if (gia.addr.f != 10 || gso.so_snd.sb_flags != 8 || gso.so_rcv.sb_cc != 5)
		return (1);
	if (gso.so_rcv.sb_flags != 4 || gia.arr[2] != 6 || arr[1].addr.f != 7)
		return (2);
	if (gso.so_snd.sb_cc != 0 || gso.t != 0 || gia.x != 2)
		return (3);
	return (gia.addr.f + gso.so_snd.sb_flags + gso.so_rcv.sb_cc +
	    gso.so_rcv.sb_flags + gia.arr[2] + arr[1].addr.f + gia.x);
}
