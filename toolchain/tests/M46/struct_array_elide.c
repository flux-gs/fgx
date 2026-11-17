/* A struct-array initializer whose elements are braced except the last,
 * which is not: 2.11BSD route(8)'s name list ends `{ "_rthashsize" }, "", };'.
 * K&R A.8.7: "If the initializer for a subaggregate does not begin with a left
 * brace, then only enough elements from the list are taken into account for
 * the members of the subaggregate".  The last element takes "" for its first
 * member and its others are 0.  fcc decided braced-or-flat once for the whole
 * list and refused the bare element ("expected '{' for struct-array
 * element").  Also an elided element in the middle, followed by a braced one.
 * Returns 42. */
struct nl { char *name; int type; int value; };
struct nl a[] = {
	{ "one", 1, 10 },
	{ "two" },
	"",
};
struct nl b[] = {
	{ "x", 1, 2 },
	"y", 3, 4,
	{ "z", 5, 6 },
};

int main()
{
	int bad = 0;

	if (sizeof a / sizeof a[0] != 3) bad |= 1;
	if (a[0].value != 10 || a[1].type != 0 || a[1].name[1] != 'w') bad |= 2;
	if (a[2].name == 0 || a[2].name[0] != 0 || a[2].type != 0) bad |= 4;
	if (sizeof b / sizeof b[0] != 3) bad |= 8;
	if (b[1].name[0] != 'y' || b[1].type != 3 || b[1].value != 4) bad |= 16;
	if (b[2].name[0] != 'z' || b[2].value != 6) bad |= 32;
	return bad ? bad : 42;
}
