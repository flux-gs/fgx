/* sgtty - exercise the FGX sgtty(2) raw-tty support (vi-port slice 4.3).
 *
 * FGX-original (not a BSD port).  Two modes:
 *   sgtty           Round-trip the tty modes through gtty/stty, asserting the
 *                   cooked defaults, vi's visual-mode transform (clear ECHO +
 *                   CRMOD, set CBREAK), the kernel's read-back, and the restore.
 *                   Terminating + non-blocking, so it gates headlessly.
 *   sgtty r         Enter CBREAK + noecho (vi visual mode), read 3 keys one at
 *                   a time, echo them back in ^-notation, then restore cooked.
 *                   Proves @rd_console returns char-at-a-time without echo --
 *                   needs live keystrokes (run interactively or with the
 *                   trailing-key test).
 */
#include "../lib/sgtty.h"

int printf(const char *fmt, ...);
int read(int fd, char *buf, int n);

struct sgttyb t;

int main(int argc, char **argv)
{
    short saved;
    int i;
    char c;

    if (gtty(0, &t) != 0) {
        printf("GTTYFAIL\n");
        return 1;
    }
    saved = t.sg_flags;

    if (argc > 1 && argv[1][0] == 'r') {
        /* Raw-read mode: vi visual transform, read 3 keys char-at-a-time. */
        t.sg_flags = (t.sg_flags & ~(ECHO | CRMOD)) | CBREAK;
        stty(0, &t);
        printf("RAW=");
        for (i = 0; i < 3; i++) {
            if (read(0, &c, 1) != 1)
                break;
            if ((c & 0xff) < 0x20)
                printf("^%c", (c & 0x1f) + '@');   /* control -> ^X */
            else
                printf("%c", c & 0xff);
        }
        printf("\n");
        t.sg_flags = saved;                        /* restore cooked */
        stty(0, &t);
        printf("RAWDONE\n");
        return 0;
    }

    /* Round-trip mode (default; headless-gated). */
    printf("flags0=%x erase=%x kill=%x\n",
           t.sg_flags & 0xffff, t.sg_erase & 0xff, t.sg_kill & 0xff);
    if ((t.sg_flags & ECHO) == 0) {
        printf("NOTCOOKED\n");
        return 1;
    }
    /* vi ostart(): tty.sg_flags = (normf & ~(ECHO|CRMOD)) | CBREAK. */
    t.sg_flags = (t.sg_flags & ~(ECHO | CRMOD)) | CBREAK;
    if (stty(0, &t) != 0) {
        printf("STTYFAIL\n");
        return 1;
    }
    gtty(0, &t);                                   /* read the kernel's stored state */
    printf("flagsR=%x\n", t.sg_flags & 0xffff);
    if (t.sg_flags & ECHO) {
        printf("ECHOSTUCK\n");
        return 1;
    }
    if ((t.sg_flags & CBREAK) == 0) {
        printf("NOCBREAK\n");
        return 1;
    }
    /* Restore and confirm cooked is back. */
    t.sg_flags = saved;
    stty(0, &t);
    gtty(0, &t);
    if ((t.sg_flags & ECHO) == 0) {
        printf("RESTOREFAIL\n");
        return 1;
    }
    printf("SGTTYOK\n");
    return 0;
}
