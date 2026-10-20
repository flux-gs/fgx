/* T5-C C4 batch 8: the spawn family in C.
 *
 * spawnv copies the path into the data-bank scratch (the kernel still reads
 * the path as an offset in the caller's data bank, apple/fgx#304), passes
 * argv and the current environ as full pointers in execve's argument
 * convention, and the /bin/true child is reaped through waitpid; spawnve
 * passes an explicit NULL envp.  argv_tab is char *[]: each entry carries
 * its own bank, and the kernel reads the table up to its NULL.
 *
 * FGX-only (MAME oracle).  10+10+6+8+8 = 42. */
char nm[] = "/bin/true";
char *argv_tab[2];

int main(void)
{
    int pid, st, r = 0;

    argv_tab[0] = nm;
    argv_tab[1] = 0;
    pid = spawnv(nm, argv_tab);
    if (pid > 0)                          r += 10;
    if (waitpid(pid, &st, 0) == pid)      r += 10;  /* reap the zombie */
    if (st == 0)                          r += 6;   /* true exits 0 */
    if (spawnv("/bin/NOPEBIN", argv_tab) == -1) r += 8;
    pid = spawnve(nm, argv_tab, (char **)0);
    if (pid > 0 && waitpid(pid, &st, 0) == pid) r += 8;
    return r;
}
