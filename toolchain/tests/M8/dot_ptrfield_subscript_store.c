/* dot_ptrfield_subscript_store: `structvar.ptrfield[i] = rhs` -- store through
 * a SUBSCRIPTED POINTER member (tcsh ed.xmap `CurCmd.code[0] = F_SEND_EOF`,
 * where code is Char*).  The dot-led M14-LHS path only handled ARRAY fields;
 * a pointer field + [i] now routes through S_CHAIN_STORE's ->p[i] arm with a
 * struct-VAR address base.  -> 42. */
struct cmd { int ch; char *code; };

int
main()
{
    struct cmd CurCmd;
    char       buf[4];

    buf[0] = 0; buf[1] = 0;
    CurCmd.code = buf;
    CurCmd.code[0] = 40;           /* buf[0] = 40 */
    CurCmd.code[1] = 2;            /* buf[1] = 2  */

    return buf[0] + buf[1];        /* 40 + 2 == 42 */
}
