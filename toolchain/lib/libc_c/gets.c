/* gets(s) — read a line from stdin (fd 0) into s, dropping the '\n'.  No size
 * limit (caller-sized buffer); unsafe by spec but 2.11BSD telnet's command mode
 * uses it.  Returns s, or NULL at EOF with nothing read. */
char *gets(char *s)
{
    int i = 0, ch;

    for (;;) {
        ch = getchar();                          /* NOT read(0, ...): a raw
                                                  * read beside a buffered one
                                                  * skips what the buffer holds */
        if (ch < 0) { if (i == 0) return (char *)0; break; }
        if (ch == 10) break;                     /* '\n' ends the line */
        s[i] = ch;
        i++;
    }
    s[i] = 0;
    return s;
}
