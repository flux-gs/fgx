/* comma_stmt_prefix: a comma-operator statement led by a prefix ++/-- --
 * `--wp, ++i;` (tcsh sh.dol.c).  The prefix ++/-- statement arm consumed the
 * operator before any comma-scan, so the trailing `, ...` died 'expected ;';
 * now the whole statement routes through build_comma when a top-level comma
 * precedes the ';'.  -> 42. */
int
main()
{
    char  buf[8];
    char *wp;
    int   i;
    wp = buf + 4;
    i = 40;
    --wp, ++i;          /* wp -> buf+3, i = 41 */
    --wp, ++i;          /* wp -> buf+2, i = 42 */
    return i + (int)(wp - buf) - 2;   /* 42 + 2 - 2 == 42 */
}
