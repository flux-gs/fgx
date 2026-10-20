/* Exhibit *p++ on a local char* (pointing into own-bank global storage).
 *
 * test(p) does *p++ — should return 42 ('*').  The pointer p is a local
 * param; emit_load_local properly puts the bank into _fcc_ptr+2.  But
 * the postinc-deref path at fcc.c:~5201 loads from _fcc_tmp_b -> TAX ->
 * LDAL $000000,X — dropping the bank to 0.
 *
 * In own-bank land bank-0:<offset of "*Q"> is whatever bank-0 has there
 * (usually garbage / kernel data / 0).  Should return 42 once fixed.
 */
char *g_msg = "*Q";   /* '*' = 42 */

int test(char *p)
{
    return *p++;
}

int main()
{
    return test(g_msg);
}
