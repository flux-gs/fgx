/* A char* struct field in a static struct-array initialized with a global
 * array NAME — the array decays to its address (&arr[0]).  elvis opts.c's
 * `opts[]` `value` field = o_autoindent.  Single-bank bakes the global's
 * address (DA gname / DFB ^gname / pad); multi-bank data-reloc is deferred.
 * Verify the field aliases the global, NULL sentinels stay NULL, and a string
 * field still works.  -> 42. */
char gbuf[4];

struct { char *name; char type; char *value; } opts[] = {
	{ "ai",       1, gbuf },   /* value = &gbuf[0] (array decays) */
	{ "sentinel", 0, 0    },   /* value = NULL                   */
};

int main(void)
{
	gbuf[0] = 42;

	if (opts[0].value != gbuf)  return 1;   /* field aliases the global */
	if (opts[1].value != 0)     return 2;   /* NULL sentinel intact     */
	if (opts[0].name[0] != 'a') return 3;   /* string field still works */

	return opts[0].value[0];                /* *gbuf = 42 */
}
