/* Long-global ++/-- at statement and for-step positions.
 * Both forms failed previously with
 * "global ++/-- at stmt: only int/char supported (M21)".
 *
 * Result: 42.
 */
long g_n;

int main()
{
    int i;
    g_n = 40;
    g_n++;                       /* stmt ++ on long global: 41 */
    g_n--;                       /* stmt -- on long global: 40 */
    g_n++;                       /* 41 */
    for (i = 0; i < 1; i = i + 1) {
        g_n++;                   /* for-body ++ (also stmt path): 42 */
    }
    return g_n;                  /* long->int return narrows; low word = 42 */
}
