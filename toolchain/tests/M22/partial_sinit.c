/* Partial struct-array element initializer: an inner brace group with FEWER
 * values than the struct has fields, remainder zero-filled — ex.c's command
 * table terminator `{(char *)0}` (and the classic `{0}` sentinel row).  -> 42. */
struct cmd { char *name; int code; int flags; };

struct cmd tbl[] = {
	{ "map",  10, 3 },
	{ "quit", 20, 5 },
	{ (char *)0 }           /* partial: code + flags zero-filled */
};

int main(void)
{
	if (tbl[0].name[0] != 'm') return 1;
	if (tbl[0].code    != 10)  return 2;
	if (tbl[1].flags   != 5)   return 3;
	if (tbl[2].name    != (char *)0) return 4;   /* zero-filled */
	if (tbl[2].code    != 0)   return 5;
	if (tbl[2].flags   != 0)   return 6;
	return 42;
}
