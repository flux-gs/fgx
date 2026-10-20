/* M18: K&R function-pointer PARAMETER — the shape 2.11BSD telnet's central
 * call() dispatcher uses (usr/ucb/telnet.c:2205,
 *   call(routine, args) int (*routine)(); char *args; { ... }).
 * fcc's K&R param-DECLARATION parser previously rejected `int (*routine)();`
 * with "expected parameter name in K&R declaration"; the ANSI form and struct
 * fn-ptr fields already worked.  Fixed by routing the K&R param-decl path
 * through parse_fn_ptr_declarator. */
int sum2(a, b) int a; int b; { return a + b; }

int call2(routine, x, y)
	int (*routine)();
	int x;
	int y;
{
	return (*routine)(x, y);
}

int main()
{
	return call2(sum2, 40, 2);
}
