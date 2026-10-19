/* comp_base_pun_read: K&R global-member pun (A.7.3, 1st ed) through a COMPUTED
 * non-struct-pointer base.  2.11BSD /bin/sh service.c:
 *   IF c=expand((argp=endstak(argp))->argval,0)
 * argp is a STRING (char*); endstak returns a STKPTR (char*); the paren-
 * assignment yields a char* byte address, and `->argval` resolves the member
 * in the global namespace (argval is an argnod field) and reads it (the array
 * field decays to its address).  Host cc (ANSI) rejects the pun; the value is
 * checked against the ANSI-equivalent layout (the same bytes via argnod*).
 * -> 42. */
struct argnod { struct argnod *argnxt; char argval[4]; };
struct argnod  storage;
char          *setup();
char          *setup() { storage.argval[0] = 42; return (char *)&storage; }

int
main()
{
    char *argp;
    char *v;

    argp = 0;
    v = (argp = setup())->argval;   /* computed (paren-assign) char* pun read */
    return v[0];                    /* argval[0] == 42 */
}
