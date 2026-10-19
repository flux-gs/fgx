/* Labeled statement as an if/else ARM: per the C grammar `lab: stmt` is
 * ONE statement, so `else lab: if (nd) ...` must bind the whole labeled
 * statement to the else.  fcc's old bare-label node attached only the
 * label and spilled the statement after the if/else — both branches ran
 * it (curses cr_put.c plod: the moved-over screen char AND the ND
 * cursor-right both printed, drifting +1 column per cursor motion).
 * Shape below is plod's, reduced. */
int r1, r2, rboth;

int
probe(w, flg, same, nd)
int w, flg, same, nd;
{
	r1 = r2 = 0;
	if (w != 0)
		if (flg)
			r1 = 99;
		else {
			if (same)
				r1 = 1;      /* "print screen char" */
			else
				goto nondes;
		}
	else
nondes:
	     if (nd)
		r2 = 1;              /* "emit ND" */
	else
		r2 = 2;
	return r1 * 10 + r2;
}

int
main()
{
	/* w=1, flg=0, same=1, nd=1: then-arm prints char, must NOT reach
	 * nondes.  Expect r1=1 r2=0 -> 10. The curses bug returns 11. */
	if (probe(1, 0, 1, 1) != 10)
		return 1;
	/* goto path: w=1,flg=0,same=0 -> nondes -> r2=1 -> 01 */
	if (probe(1, 0, 0, 1) != 1)
		return 2;
	/* w=0 -> else arm directly */
	if (probe(0, 0, 0, 1) != 1)
		return 3;
	/* flg set: r1=99, skip everything -> 990 */
	if (probe(1, 1, 0, 1) != 990)
		return 4;
	return 42;
}
