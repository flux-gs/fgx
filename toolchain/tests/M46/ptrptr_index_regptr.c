/* A pointer local subscripted by an element read through ANOTHER pointer,
 * `fdp[ap[1]]', with the two in different banks: the table in the data bank,
 * the index array a stack local in bank 0.  K&R A.7.3.1: "E1[E2] is identical
 * (by definition) to *((E1)+(E2))", so the element is fdp's, in fdp's bank.
 * fcc pushed fdp's offset, evaluated ap[1] through _fcc_ptr -- which left ap's
 * bank in _fcc_ptr+2 -- and read the element at fdp's offset in AP'S bank.
 * The far kernel's unp_fileop found no descriptor that way.  Returns 42. */
struct s { int a[12]; };
struct s pool[4];
struct s *tab[8];
struct s *pool_p;
struct s **ofile;

struct s **
base(pid)
int pid;
{
	if (ofile == (struct s **)0)
		return ((struct s **)0);
	return (&ofile[pid * 2]);
}

int
f(pid, ap)
int pid;
register int *ap;
{
	register struct s *fp;
	struct s **fdp;
	int *out;
	int i, n;

	fp = (ap[1] > 0 && ap[1] <= 4) ? &pool_p[ap[1] - 1] : (struct s *)0;
	switch (ap[0]) {
	case 0:
		fdp = base(pid);
		if (fdp == (struct s **)0 || ap[1] < 0 || ap[1] >= 4 ||
		    fdp[ap[1]] == (struct s *)0)
			return (0);
		for (i = 0; i < 4; i++)
			if (fdp[ap[1]] == &pool_p[i])
				return (i + 1);
		return (0);
	}
	return (fp != (struct s *)0);
}

int
main()
{
	int idx[2];

	pool_p = pool;
	ofile = tab;
	tab[2 + 1] = &pool[2];
	idx[0] = 0;
	idx[1] = 1;
	return (f(1, idx) == 3 ? 42 : 1);
}
