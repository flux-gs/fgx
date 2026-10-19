/* M22/P3-2: POINTER-RETURNING fn-ptr — `char *(*fp)()` was an artificial
 * reject ("expected declarator name"): the declarator paths never allowed
 * return-type stars before `(*name)`.  FnSig.return_type always was a full
 * tword, so the fix is star consumption in parse_fn_ptr_declarator +
 * type_for_decl on the starred base; call results then type as char*
 * (4-byte pointer store, deref works) with no emitter change.  Runtime
 * cross-bank version = multibank construct c39. */
char buf[4];

char *
pick(i)
{
	buf[2] = 42;
	return buf + i;
}

char *(*fp)();

int
main()
{
	char *r;
	fp = pick;
	r = (*fp)(1);
	if (r != buf + 1) return 1;
	return r[1];                 /* buf[2] == 42 */
}
