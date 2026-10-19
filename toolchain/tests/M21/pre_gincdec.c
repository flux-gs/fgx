/* Prefix ++g; / --g; on a GLOBAL scalar at statement position.
 * Previously failed with "'g' undeclared": the standalone-statement prefix
 * handler (parse_stmt.c) did locals_lookup only, never globals_lookup -- while
 * the for-step handler already had the int/char/long global branch.  Fixed by
 * mirroring that branch.  (Postfix g++/g-- already worked: long_global_inc.c.)
 *
 * Result: 42.
 */
int  gi;
char gc;
long gl;

int main()
{
    gi = 40;
    ++gi;                /* prefix ++ on int global:  41 */
    ++gi;                /* 42 */
    gc = 65;
    --gc;                /* prefix -- on char global: 64 */
    gl = 100;
    ++gl;                /* prefix ++ on long global: 101 */
    --gl;                /* 100 */
    --gl;                /* 99 */
    if (gc != 64) return 1;
    if (gl != 99) return 2;
    return gi;           /* 42 */
}
