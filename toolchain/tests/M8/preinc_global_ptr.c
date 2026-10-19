/* preinc_global_ptr: prefix ++/-- of a GLOBAL pointer as a statement (tcsh/sh
 * macro.c `++staktop;`, staktop a BYTPTR == char*).  K&R A.7.4.1: the operand
 * of prefix ++/-- is any modifiable lvalue; a global pointer qualifies and is
 * incremented by sizeof(*p) (A.7.7).  The statement path rejected a global
 * pointer though S_PREINC_STMT's walk already bumps one (the for-step twin).
 * -> 42. */
char  str[6];
char *cursor;

int
main()
{
    int r;

    str[0] = 0; str[1] = 14; str[2] = 28;
    cursor = str;            /* &str[0] */

    ++cursor;                /* &str[1] */
    r = *cursor;             /* 14 */
    ++cursor;                /* &str[2] */
    r += *cursor;            /* +28 = 42 */
    --cursor; --cursor;      /* back to &str[0] */
    r += *cursor;            /* +0 = 42 (verifies -- landed) */

    return r;                /* 42 */
}
