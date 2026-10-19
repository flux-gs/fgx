/* FGX-Origin: original -- FGX code; there is no BSD counterpart.  It names
 * 2.11BSD only for the tty behaviour it works with.
 *
 * ansicat(1) -- show ANSI art: files copied byte for byte to a terminal.
 *
 * An ANSI art file is code page 437 text and ECMA-48 control sequences
 * written for a PC's ANSI.SYS: bytes from $80 up are glyphs, and a SAUCE
 * metadata record may follow the art after a ^Z, the DOS end-of-file byte.
 * So ansicat
 *   - sets LLITOUT on its standard output, because the tty strips the eighth
 *     bit of every output byte without it (2.11BSD ttyoutput), and puts the
 *     local mode word back on exit and on an interrupt;
 *   - starts with ESC[0m ESC[2J ESC[H, since ANSI.SYS homes the cursor on
 *     ESC[2J and ECMA-48's ED does not;
 *   - copies each file up to its first ^Z, so a SAUCE record is not shown;
 *   - with -b baud, paces the bytes at baud/10 a second, as they arrived over
 *     a modem, which is the timing an ANSI animation was drawn for.
 * The Second Sight card's console, ttyv3, shows the sixteen colours and the
 * code page; the IIgs screen shows them in its four colours and ASCII.
 */
#include <stdio.h>
#include <stdlib.h>
#include <sgtty.h>
#include <signal.h>

int nanosleep(int ticks);               /* libc: SYS_NANOSLEEP, 60 a second */

static int lsaved;                      /* the local mode word found */
static int lgot;                        /* 1 once lsaved holds it */
static int per;                         /* -b: bytes a second, 0 = unpaced */
static int credit;                      /* sixtieths of a byte in hand */

static void restore(void)
{
    fputs("\033[0m", stdout);
    fflush(stdout);
    if (lgot)
        ioctl(1, TIOCLSET, (char *)&lsaved);
}

static void onintr(void)
{
    restore();
    exit(1);
}

/* One byte, after the pacing lets it through: every tick adds `per'
 * sixtieths of a byte, and a byte costs sixty. */
static void put(int c)
{
    if (per) {
        while (credit < 60) {
            fflush(stdout);
            nanosleep(1);
            credit += per;
        }
        credit -= 60;
    }
    putchar(c);
}

static void copy(FILE *f)
{
    int c;

    while ((c = getc(f)) != EOF && c != 032)
        put(c);
}

int main(int argc, char **argv)
{
    int c, i, rc, lit;
    long baud;
    FILE *f;

    while ((c = getopt(argc, argv, "b:")) != EOF) {
        if (c != 'b') {
            fputs("usage: ansicat [-b baud] [file ...]\n", stderr);
            return 2;
        }
        baud = atol(optarg);
        if (baud < 10 || baud > 115200) {
            fputs("ansicat: baud must be 10 to 115200\n", stderr);
            return 2;
        }
        per = (int)(baud / 10);
    }
    if (ioctl(1, TIOCLGET, (char *)&lsaved) == 0) {
        lgot = 1;
        lit = LLITOUT;
        ioctl(1, TIOCLBIS, (char *)&lit);
    }
    signal(SIGINT, onintr);
    fputs("\033[0m\033[2J\033[H", stdout);
    rc = 0;
    if (optind >= argc)
        copy(stdin);
    for (i = optind; i < argc; i++) {
        if ((f = fopen(argv[i], "r")) == NULL) {
            fflush(stdout);
            fprintf(stderr, "ansicat: cannot open %s\n", argv[i]);
            rc = 1;
            continue;
        }
        copy(f);
        fclose(f);
    }
    restore();
    return rc;
}
