/* Init-list scalars are constant EXPRESSIONS (elvis opts.c `{80, 32, ~0}`),
 * and pointer / fn-ptr struct-array fields accept a cast-of-0 null:
 * `(char *)0` sentinel rows and elvis's `NO_FUNC = (MARK (*)())0`.  Previously
 * fcc took only bare int/char literals and bare 0 in these positions.  -> 42. */
typedef int MARK;

char cols[3]  = {80, 32, ~0};           /* ~0 -> -1, low byte 0xff        */
int  flags[2] = {1 << 4, 3 * 7};        /* 16, 21                         */

struct key { MARK (*func)(); char *name; int arg; };
struct key keys[] = {
	{ (MARK (*)())0, (char *)0, ~0 },   /* NO_FUNC / NULL / -1            */
	{ 0,             "x",       5  },
};

int main(void)
{
	if ((cols[2] & 0xff) != 255) return 1;
	if (flags[0] != 16)          return 2;
	if (flags[1] != 21)          return 3;
	if (keys[1].name[0] != 'x')  return 4;
	if (keys[1].arg != 5)        return 5;
	if (keys[0].name)            return 6;   /* (char *)0   -> NULL */
	if (keys[0].func)            return 7;   /* (MARK(*)())0 -> NULL */
	return 42;
}
