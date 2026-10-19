/* tentative_array_def: a file-scope sizeless array with no initializer is a
 * TENTATIVE definition (K&R A.10.2, p.187 -- the UNIX common extension the
 * 2.11BSD shells rely on).  A complete definition (here later in the same TU;
 * in the shell, in msg.c) provides the storage; the tentative one "becomes
 * merely a declaration".  fcc binds the tentative form as extern and
 * globals_declare (G45) reconciles the definition into the one symbol.
 * '*' is ASCII 42.  -> 42. */
char label[];                /* tentative definition (bound extern) */
char label[] = "*ready";     /* the definition provides storage + init */
int
main()
{
    return label[0];         /* '*' == 42 */
}
