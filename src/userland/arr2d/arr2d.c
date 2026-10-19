/* arr2d.c — regression for the fcc data-segment N-D array partial-decay bank.
 *
 * This is the elvis `init_digraphs()` shape (main.c: `static char digtable[][4]`
 * walked by `for (i=0; *digtable[i]; i++)`).  `t[i]` on a 2-D `char[][4]` is a
 * PARTIAL decay: it yields a `char[4]` row that decays to `char *`.  fcc builds
 * that row far-pointer in emit_array_index_read_global's partial-decay branch.
 *
 * Under --data-segment the array `t` lives in the DATA bank (seg1) while the
 * code runs in seg0 (a DIFFERENT bank at runtime).  The row pointer's bank must
 * therefore be the runtime DATA bank (PHB/DBR), NOT the code bank (PHK).  The
 * pre-fix codegen emitted a bare PHK, so `*t[i]` read the CODE bank at the
 * array's offset -> code bytes (nonzero) instead of the `""` terminator -> the
 * loop ran off the end (elvis dumped that as the startup garble).
 *
 * Correct walk: t[0]="AB", t[1]="CD", t[2]="" -> loop stops at i==2, and the
 * row contents read back as 'A'/'D'.  Exit 42 iff all three hold; a wrong-bank
 * read derails i and/or the contents, so the exit code won't be 42.
 */

char t[][4] = { "AB", "CD", "" };

int main()
{
	int i;

	for (i = 0; *t[i]; i++)
	{
	}

	if (i == 2 && t[0][0] == 'A' && t[1][1] == 'D')
	{
		return 42;
	}
	return i & 0xFF;
}
