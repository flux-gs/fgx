/* Struct-pointer global initialised to a literal (NULL) must get a 4-byte
 * cell.  The old emit arm whitelisted only char-, int- and void-pointers, so a struct
 * pointer fell into the generic 2-byte DA arm; a 4-byte load then read the
 * NEXT global's bytes as the high word (curses: `WINDOW *curscr = NULL;`
 * came up non-NULL on target and initscr delwin'd garbage).  The nonzero
 * sentinel data placed right after the pointers makes the truncation a
 * RUNTIME failure, not just a layout diff. */
struct S {
    int a;
    int b;
};

struct S *gp = 0;
struct S *gq = 0;
char sentinel[4] = { 1, 2, 3, 4 };   /* nonzero bytes adjacent to gq */

int *ip = 0;      /* pre-fix behaviour was already 4-byte; must stay */
char **cpp = 0;   /* ptr-to-ptr: also outside the old whitelist */

int
main()
{
	if (gp != 0)
		return 1;
	if (gq != 0)
		return 2;
	if (ip != 0)
		return 3;
	if (cpp != 0)
		return 4;
	if (sentinel[0] != 1 || sentinel[3] != 4)
		return 5;
	return 42;
}
