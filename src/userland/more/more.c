/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD more(1)
 *   Ported from more(1), 2.11BSD (by Eric Shienbrood, UC Berkeley; mods by
 *   Geoff Peck and John Foderaro, UCB).  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * more - page through text.  Port of 2.11BSD more(1) as a screen-CLEARING
 * pager (each page is drawn from the top of a cleared screen, like the old
 * hand-asm more.s) that also works in a pipe.
 *
 * Usage:   more [file]          (no file -> paginate stdin / a pipe)
 *          producer | more
 *
 * At the --More-- prompt:  SPACE = next page, b / ^B = back one page
 *                          (files only), q/Q = quit, any other key = ignored.
 *
 * Design (why a clearing pager, not in-place scroll):
 *   The FGX console treats CR ($0D) as a full newline (cursor to column 0 of
 *   the NEXT row), so the classic more(1) trick of erasing the "--More--"
 *   prompt with a bare CR does not work — a CR advances the line and leaves
 *   the prompt behind (stacking a second --More--).  So, like more.s, this
 *   port clears the screen (ESC[2J ESC[H) before each page: the clear wipes
 *   the previous page AND its prompt, and unrecognised keys are simply
 *   ignored (the prompt is never redrawn, so there is nothing to erase).
 *
 * Input / back-scroll:
 *   - A file arg is opened with fopen(); reads go through fgetc(), which is
 *     unbuffered (one SYS_READ per byte), so ftell() is byte-exact and `b`
 *     back-scroll works by recording each page's start offset and fseek()ing
 *     back to it (mirrors more.s's page_starts[] without needing a raw-fd
 *     lseek shim).
 *   - With no file arg, data is read forward from stdin (fd 0) via read() —
 *     a pipe is not seekable, so `b` is disabled there (silently ignored).
 *   The pager CONTROL key comes from fd 2, which is 2.11BSD more's readch()
 *   verbatim (`read (2, &ch, 1)').  That is the whole reason the idiom exists:
 *   in `cmd | more' fd 0 is the pipe carrying the data, and fd 2 is still the
 *   terminal.
 *
 * Port-side notes (FGX / fcc):
 *  - It used to call waitkey() (SYS_GETKEY=50), which takes no fd and dequeues
 *    the kernel keyboard ring, so over a pty it read the PHYSICAL CONSOLE: the
 *    client's SPACE did nothing while the console's paged the remote session
 *    (apple/fgx#151, measured by the ptykey fixture).  fd 2 was always the
 *    answer -- upstream reaches for it precisely because redirection moves
 *    fd 0 and leaves fd 2 alone.
 *  - Single-keystroke paging therefore needs the tty in CBREAK with ECHO off,
 *    which waitkey never required because it bypassed the line discipline
 *    entirely.  set_tty/reset_tty below are upstream's, and reset_tty runs on
 *    the way out AND from a SIGINT handler -- leaving a terminal in cbreak
 *    with no echo is a shell nobody can type at.
 *  - Line counting triggers on CR ($0D, FGX's terminator) and on a lone LF
 *    ($0A not following a CR, so CRLF counts once); columns wrap-count at 80.
 *  - Screen geometry + clear/standout strings now come from the libc termcap
 *    table via the C-callable bridge (tgetent + tgetstr cl/so/se + tgetnum
 *    li/co), the same path clear(1)/ul(1) use, instead of baked constants.
 *    Console is 25 rows (tgetnum("li")); page size = li-1 leaves the bottom row
 *    for the --More-- prompt; the wrap width is tgetnum("co")=80.  Each cap
 *    falls back to its historical constant if absent (dumb-terminal safe).
 *  - Exits at EOF (no --More--(END) wait); the shell prompt returns at once.
 *  - Not yet implemented vs 2.11BSD (tracked, not silently dropped): `/pattern`
 *    search (needs a regex engine — see docs/ROADMAP.md), multi-file paging
 *    (only argv[1] today), `=` line-number, `h` help.  Back-scroll matches
 *    2.11BSD's "forward-only on a pipe, fseek on a file" behavior; history is
 *    bounded at MAXPG pages here (2.11BSD rewinds from the start = unbounded).
 *  - NOT supported: bare interactive `more` with no file and no pipe — fd 0 is
 *    then the console and reading data would steal the prompt's keys (real BSD
 *    more wants a file on a tty too).
 *  - Buffers are file-scope globals (fcc stack-local arrays are unsafe).
 */
#include <stdio.h>
#include <stdlib.h>
#include <sgtty.h>
#include <signal.h>

/* fcc libc: read/write are not in <stdio.h>; fopen/fgetc/fseek/ftell/
   fclose/fprintf + FILE + SEEK_SET come from <stdio.h>. */
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);

/* Screen geometry + clear/standout come from the libc termcap table via the
   C-callable bridge -- the same path clear(1)/ul(1) use -- rather than baked
   constants.  fcc needs a prototype even for these bound calls. */
char *getenv(char *name);
int   tgetent(char *bp, char *name);
char *tgetstr(char *id, char **area);
int   tgetnum(char *id);
int   putch(int c);             /* fwd: tputs's outc, defined below */

#define DEF_LINES   25          /* fallback total rows if `li` is absent */
#define DEF_COLS    80          /* fallback columns if `co` is absent     */
#define MAXPG       256         /* back-scroll history depth (pages) */

FILE *fp;                       /* the file (NULL => reading stdin/pipe) */
int   seekable;                 /* 1 if back-scroll is possible (file input) */
int   ateof;                    /* set when a page hit end-of-input */
int   curpage;                  /* current page index */
long  pgoff[MAXPG];             /* file offset where each page starts */
char  ob[1];                    /* output byte */
char  rb[1];                    /* stdin read byte */
char  kb[1];                    /* fd 2 control-key byte */

/* Upstream's savetty/otty pair.  savetty is what the terminal was; otty is
   that plus CBREAK and minus ECHO.  no_tty is set when fd 2 is not a terminal
   at all, in which case nothing is changed and nothing has to be restored. */
struct sgttyb savetty;
struct sgttyb otty;
int   no_tty;

/* Termcap-derived geometry/strings (filled by initterm()).  Buffers are
   file-scope per this file's rule (fcc stack-local arrays are unsafe); the
   baked tgetent/tgetstr ignore them anyway. */
int   page_lines;               /* live page size = tgetnum("li") - 1 (prompt) */
int   line_width;               /* live wrap width = tgetnum("co")             */
char *cap_cl;                   /* clear-screen string ("cl")                  */
char *cap_so;                   /* standout on  ("so") -- --More-- prompt      */
char *cap_se;                   /* standout off ("se")                         */
char  tcbuf[32];                /* tgetent entry buffer (baked-ignored)        */
char  capbuf[64];               /* tgetstr area buffer  (baked-ignored)        */

/* write one byte to stdout (fd 1).  Returns c so it can serve as tputs's
   int (*outc)(int) callback (the termcap emit path). */
int putch(int c)
{
    ob[0] = c;
    write(1, ob, 1);
    return c;
}

/* clear the screen and home the cursor via the termcap `cl` string (tc_cl =
   ESC[H ESC[2J -- homes then erases, leaving the cursor top-left, the same end
   state as the old hand-emitted ESC[2J ESC[H).  Falls back to a direct emit if
   `cl` is somehow absent so the pager still works on a dumb terminal. */
void clearhome(void)
{
    if (cap_cl)
        tputs(cap_cl, 1, putch);
    else {
        putch(27); putch('['); putch('2'); putch('J');
        putch(27); putch('['); putch('H');
    }
}

/* next input byte (0..255), or -1 at end-of-input. */
int readbyte(void)
{
    int c;

    if (seekable) {
        c = fgetc(fp);
        if (c < 0)
            return -1;
        return c & 0xff;
    }
    if (read(0, rb, 1) <= 0)
        return -1;
    return rb[0] & 0xff;
}

/* Draw the current page: clear, (seek to its start if seekable), emit up to
   PAGE_LINES lines.  Sets ateof if input ended; records the next page's start
   offset for forward/back navigation. */
void showpage(void)
{
    int c, lines, col, prevcr;

    clearhome();
    if (seekable)
        fseek(fp, pgoff[curpage], SEEK_SET);
    lines = 0;
    col = 0;
    prevcr = 0;
    ateof = 0;
    while (lines < page_lines) {
        c = readbyte();
        if (c < 0) {
            ateof = 1;
            break;
        }
        putch(c);
        if (c == 0x1b) {
            /* CSI escape (ESC[...<final>): our man pages carry bold/underline
               as SGR runs (man_preformat.py); the console's VT parser paints
               and consumes them, so they occupy zero visible columns.  Emit
               the whole sequence but don't count its bytes toward col, else a
               decorated line false-wraps and cuts the page short (the 2/3-page
               bug).  Only CSI is emitted here; that's all man output uses. */
            c = readbyte();
            if (c < 0) { ateof = 1; break; }
            putch(c);
            if (c == '[') {
                do {
                    c = readbyte();
                    if (c < 0) { ateof = 1; break; }
                    putch(c);
                } while (!(c >= 0x40 && c <= 0x7e));
            }
            prevcr = 0;
            continue;
        }
        if (c == '\r') {
            col = 0;
            lines++;
        } else if (c == '\n') {
            col = 0;
            if (!prevcr)            /* collapse CRLF into one line */
                lines++;
        } else if (c == '\b') {
            /* Raw overstrike (c\bc, _\bc from piped nroff/ul) moves the cursor
               left, not right -- count visible columns, not raw bytes. */
            if (col > 0)
                col--;
        } else {
            col++;
            if (col >= line_width) {
                col = 0;
                lines++;
            }
        }
        prevcr = (c == '\r');
    }
    if (seekable && !ateof && curpage + 1 < MAXPG)
        pgoff[curpage + 1] = ftell(fp);
}

/* Load screen geometry + clear/standout strings from the termcap table.  Each
   cap falls back to the historical constant if absent, so more keeps working
   on a bare/dumb terminal.  tgetnum returns -1 on a miss; on FGX `li` is now 25
   (the SHR console's true row count) and `co` is 80. */
void initterm(void)
{
    char *tt;
    char *bp;
    int   n;

    tt = getenv("TERM");
    if (tt == NULL)
        tt = "fgx";             /* single console */
    tgetent(tcbuf, tt);         /* baked -> 1; buffer ignored */

    bp = capbuf;
    cap_cl = tgetstr("cl", &bp);
    cap_so = tgetstr("so", &bp);
    cap_se = tgetstr("se", &bp);

    n = tgetnum("li");          /* total screen rows */
    if (n <= 0)
        n = DEF_LINES;
    page_lines = n - 1;         /* reserve the bottom row for --More-- */
    if (page_lines < 1)
        page_lines = 1;

    n = tgetnum("co");
    if (n <= 0)
        n = DEF_COLS;
    line_width = n;

    /* Upstream samples fd 2 here and keeps two copies: savetty to restore and
       otty to impose.  gtty failing means fd 2 is not a terminal, and then
       there is nothing to set and nothing to put back -- readch() will simply
       hit EOF and more exits, which is what upstream's no_tty path amounts to
       for a pager with no way to prompt. */
    no_tty = (gtty(2, &savetty) < 0);
    if (!no_tty) {
        otty = savetty;
        otty.sg_flags |= CBREAK;
        otty.sg_flags &= ~ECHO;
    }
}

/* 2.11BSD more's set_tty()/reset_tty(), which is the pair that makes a single
   keystroke reach the pager instead of a whole edited line.  Both act on fd 2
   -- the same descriptor readch() reads -- so the mode and the read can never
   disagree about which terminal they mean. */
void set_tty(void)
{
    if (no_tty)
        return;
    stty(2, &otty);
}

void reset_tty(void)
{
    if (no_tty)
        return;
    stty(2, &savetty);
}

/* Upstream's end_it(), reached from the SIGINT handler.  A pager that exits
   through ^C without this leaves the terminal in cbreak with echo off, which
   looks exactly like a hung shell. */
void end_it(int sig)
{
    reset_tty();
    putch('\n');
    exit(0);
}

/* 2.11BSD more's readch(), verbatim in shape.  fd 2 is the terminal even when
   fd 0 is a pipe, which is the entire point.  A short read means the terminal
   has gone: exit rather than spin on it. */
int readch(void)
{
    if (read(2, kb, 1) <= 0) {
        reset_tty();
        exit(0);
    }
    return kb[0] & 0x7f;
}

int main(int argc, char **argv)
{
    int k, quit;

    initterm();
    signal(SIGINT, end_it);
    set_tty();

    fp = NULL;
    seekable = 0;
    ateof = 0;
    curpage = 0;
    pgoff[0] = 0L;

    if (argc >= 2) {
        fp = fopen(argv[1], "r");
        if (!fp) {
            reset_tty();
            fprintf(stderr, "more: cannot open %s\n", argv[1]);
            return 1;
        }
        seekable = 1;
    }

    quit = 0;
    while (!quit) {
        showpage();
        if (ateof)
            break;                  /* last page shown; done */
        /* --More-- in standout (so/se), like 2.11BSD more; the SGR codes are
           consumed by the console VT parser, so the literal text still shows.
           Interactive path -- live-verify on hardware (headless tests are sub-page,
           so they exit before reaching the prompt). */
        if (cap_so)
            tputs(cap_so, 1, putch);
        write(1, "--More--", 8);
        if (cap_se)
            tputs(cap_se, 1, putch);
        for (;;) {
            k = readch();
            if (k == 'q' || k == 'Q') {
                quit = 1;
                break;
            }
            if (k == ' ') {
                curpage++;          /* next page */
                break;
            }
            if (k == 'b' || k == 'B' || k == 2) {
                if (!seekable) {
                    putch(7);       /* pipe: not seekable -> bell (as 2.11BSD more) */
                } else {
                    if (curpage > 0)
                        curpage--;  /* back one page; clamp at the first page */
                    break;          /* re-render (page 0 again when at the top) */
                }
            }
            /* any other key: ignore, wait for another */
        }
    }

    if (seekable)
        fclose(fp);
    reset_tty();
    return 0;
}

/* tputs now comes from libtermlib (BSD-foundations P1) — the local copy
 * this comment anchored is retired; the tool selects libs="termlib".
 * UP and BC below are tentative definitions: libtermlib defines them, as
 * 2.11BSD's tgoto.c does, and K&R A.10.2's common extension merges the
 * two (this tool never calls tgoto, so they stay null). */
char *UP;
char *BC;
/* RTL-ABI: termlib compiles tputs/tgoto behind EMPTY-PAREN forward
 * decls (the fcc variadic flip, matching elvis's K&R externs) — every
 * client must declare them the same way or the args land reversed. */
void tputs();
