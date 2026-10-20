/* ---- ttyslot(3): this terminal's line number in /etc/ttys -----------------
 * 4.3BSD-Reno gen/ttyslot.c (2.11BSD lib/libc/gen/ttyslot.c).  The index of
 * the caller's /etc/utmp record; login(3), logout(3) and logwtmp(3), which
 * write that file, are libutil's (lib/libutil_c), as in 2.11BSD.
 */

int ttyslot()
{
    struct ttyent *ttyp;
    int slot, cnt;
    char *name, *p;

    setttyent();
    for (cnt = 0; cnt < 3; cnt++)
        if ((name = ttyname(cnt)) != (char *)0) {
            if ((p = strrchr(name, '/')) != (char *)0)
                p++;
            else
                p = name;
            for (slot = 1; (ttyp = getttyent()) != (struct ttyent *)0; slot++)
                if (strcmp(ttyp->ty_name, p) == 0) {
                    endttyent();
                    return slot;
                }
            break;                      /* a terminal, but not a listed line */
        }
    endttyent();
    return 0;
}
