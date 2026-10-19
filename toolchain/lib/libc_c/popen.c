char *popen(char *cmd, char *mode)
{
    /* STUB on FGX (no pipe-to-a-program yet): NULL so BSD callers
     * degrade gracefully -- same contract as the hand stub. */
    return (char *)0;
}

int pclose(char *fp)
{
    return -1;
}

