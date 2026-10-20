/* static_charptr_str: a static-local `char *` scalar initialised to a string
 * literal (incl. comma-separated declarators).  The mangled global emits like
 * a file-scope `char *p = "literal"`, so fcc records the pooled string label
 * -- previously the static-local scalar init accepted only int/char literals.
 * tcsh: sh.dir `static char *emsg = "..."`, ed.screen `static char *fmts =
 * "%s\n", *fmtd = "%d\n"`.  -> 42. */
int
slen(cp)
    char *cp;
{
    int n = 0;
    while (cp[n]) n++;
    return n;
}

int
main()
{
    static char *fmts = "%s\n", *fmtd = "%d\n";   /* len 3, 3 */
    static char *emsg = "abcdefghij";             /* len 10 */
    return slen(fmts) + slen(fmtd) + slen(emsg) + 26;  /* 3+3+10+26 == 42 */
}
