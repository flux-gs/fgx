/* M18: the telnet call() varargs IDIOM over a K&R function-pointer parameter
 * (2.11BSD usr/ucb/telnet.c:2205).  call() walks &args as a char** array
 * ((char *)0-terminated) and forwards (argc, &args) through the fn-ptr param.
 * Exercises what the plain fn-ptr fixture misses: the &param walk (offset-flip
 * dependent), the (char *)0 terminator (a 4-byte pointer, not a 2-byte int 0
 * — the walk strides 4), and a variadic call site (the caller precedes the
 * definition, as in telnet, so only the `int call();` unspecified-args decl is
 * in scope and the 4-arg call is not arg-count checked).  A future ABI/offset
 * change that breaks &param addressing changes the return value. */
int call();
int use();

int main()
{
	return call(use, (char *)"a", (char *)"b", (char *)0);
}

int use(argc, argv)
	int argc;
	char **argv;
{
	/* argv points at call's args slot — the walked vararg array. */
	return argc * 10 + (argv[0][0] - 'a') + (argv[1][0] - 'a');
}

int call(routine, args)
	int (*routine)();
	char *args;
{
	register char **argp;
	register int argc;
	for (argc = 0, argp = &args; *argp++ != 0; argc++)
		;
	return (*routine)(argc, &args);
}
