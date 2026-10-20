/* Static-local array initializers (elvis fnames/labels/buf): the function-scope
 * `static` is backed by a name-mangled file-scope global, so it can carry an
 * initializer just like a global — char[] = "string", char*[] = { "a", ... }
 * (string-pool pointers), and int/char[] = { const-expr, ... }.  -> 42. */
int main(void)
{
	static char *names[3] = {"aa", "bb", "cc"};
	static char  buf[]    = "xyz";
	static int   nums[4]  = {10, 20, 30, ~0};

	if (names[0][0] != 'a') return 1;
	if (names[1][1] != 'b') return 2;   /* second char of "bb" */
	if (names[2][0] != 'c') return 3;
	if (buf[0] != 'x')      return 4;
	if (buf[2] != 'z')      return 5;
	if (buf[3] != 0)        return 6;   /* NUL terminator, size-from-init */
	if (nums[0] != 10)      return 7;
	if (nums[3] != -1)      return 8;   /* ~0 const-expr */
	return 42;
}
