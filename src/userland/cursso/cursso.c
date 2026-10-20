/*
 * cursso -- a curses program linked dynamically against libcurses.so,
 * libtermlib.so and libc.so, bound on the host (cursso, shared libc SP3,
 * section 5) or on the machine (curssodyn, SP4): the screen through
 * initscr/addstr/refresh/endwin, curses's core data read by the program
 * (LINES, COLS, stdscr), and termlib's (UP, which curses's setterm fills
 * and the program reads through its own import).  `CURS <check> ok' per
 * check, then `CURS ok'.
 */
#include <curses.h>
#include <string.h>

extern char *UP, *CM, *tgoto();
extern int tgetent();

static int fails;

static void
say(what, ok)
char *what;
int ok;
{
    printf(ok ? "CURS %s ok\n" : "CURS FAIL %s\n", what);
    if (!ok)
        fails++;
}

int
main()
{
    char buf[32];
    int lines, cols;

    initscr();
    move(1, 2);
    addstr("CURSSO");
    refresh();
    lines = LINES;
    cols = COLS;
    endwin();
    say("size", lines > 0 && cols > 0 && lines == LINES && cols == COLS);
    say("stdscr", stdscr != (WINDOW *)0 && stdscr->_maxy == LINES &&
        stdscr->_maxx == COLS);
    say("up", UP != (char *)0 && strcmp(UP, "\033[A") == 0);
    say("tgoto", strcmp(tgoto(CM, 5, 10), "\033[11;6H") == 0);
    say("tgetent", tgetent(buf, "vt100") == 1);
    printf(fails ? "CURS FAIL %d\n" : "CURS ok\n", fails);
    return fails != 0;
}
