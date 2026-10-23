FILE *popen(char *cmd, char *mode)
{
    /* STUB on FGX (no pipe-to-a-program yet): NULL so BSD callers
     * degrade gracefully -- same contract as the hand stub. */
    return (FILE *)0;
}

int pclose(FILE *fp)
{
    return -1;
}

