/* ptrarr_null_store: storing a NULL into a POINTER-ARRAY element must write
 * the bank byte too.
 *
 * A pointer element is 4 bytes on FGX (offset word + bank byte).  The store
 * took its bank from the RHS CARRIER (_fcc_ptr+2), which only gets bridged
 * when the RHS is genuinely a pointer -- so an INTEGER RHS stored a STALE
 * bank.  `v[n] = 0` then read back with offset 0 but a garbage bank, so
 * `v[n] != 0` was TRUE and every NULL-terminated pointer walk ran off the end.
 * Silent, and invisible on single-bank FGX1 where readers PHK-recovered their
 * own bank.  That terminator is the shape of every BSD argv/envp table.
 *
 * Found because the fcc runtime oracle had been dark: its chunked driver
 * sourced scripts with `source`, a csh/jsh builtin, and /bin/sh became the
 * 2.11BSD Bourne shell (which uses `.`), so every fixture reported
 * "no-marker" -- including return_0.  The goldens could not see this because
 * the bad code is byte-stable; only running it on device catches it.  -> 42
 */
char *g_static = 0;          /* static initialiser */
char *g_run;                 /* runtime store      */
char *vec[3];                /* array element      */
char *vec_init[3] = {0, 0, 0};
char s0[2];
int main(void)
{
    s0[0] = 'A'; s0[1] = 0;
    if (g_static != 0) return 1;      /* static-init scalar   */
    g_run = 0;
    if (g_run != 0) return 2;         /* runtime-store scalar */
    if (vec_init[2] != 0) return 3;   /* static-init element  */
    vec[0] = s0; vec[1] = s0;
    vec[2] = 0;
    if (vec[2] != 0) return 4;        /* runtime-store element */
    vec[2] = (char *)0;
    if (vec[2] != 0) return 5;        /* cast form             */
    return 42;
}
