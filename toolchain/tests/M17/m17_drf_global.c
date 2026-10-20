/* M17 acceptance fixture: deref-through-global + deref-through-local
 * via the long-pointer ABI.  Bank byte must be preserved across the
 * call to read_through() and through the global pointer load.
 *
 * Returns 42 if everything works:
 *   sum_local  = 7 + 7   = 14
 *   sum_global = 42 + 42 = 84
 *   return 84 - 14 - 28  = 42
 */

int g_n = 42;
int *g_p;

int read_through(int *p)
{
    return *p;
}

int main()
{
    int local;
    int *lp;
    int sum_local;
    int sum_global;
    local = 7;
    lp = &local;
    sum_local  = read_through(lp) + read_through(&local);
    g_p = &g_n;
    sum_global = read_through(g_p) + read_through(&g_n);
    return sum_global - sum_local - 28;
}
