/* CU-3: comma-expression statements — the curses.h tty-mode and getyx
 * macro shapes.  Covers: bare `a = b, c = d;` at statement level; the
 * parenthesized three-operand form with a field |= FIRST operand and a
 * call LAST operand (the cbreak macro, verbatim); the &= ~mask sibling
 * (nocbreak); and getyx-style member reads into locals.  xstty() records
 * the flags value AT CALL TIME, so the checks also pin the left-to-right
 * operand order.  Exits 42 iff every operand ran exactly once, in order
 * (10 + 12 + 10 + 10). */
struct sgttyb { int sg_flags; };
struct win { int _cury; int _curx; };

#define TRUE   1
#define FALSE  0
#define CBREAK 02
#define cbreak()   (_tty.sg_flags |= CBREAK, _rawmode = TRUE, xstty(_tty_ch, &_tty))
#define nocbreak() (_tty.sg_flags &= ~CBREAK, _rawmode = FALSE, xstty(_tty_ch, &_tty))
#define getyx(win,y,x) y = win->_cury, x = win->_curx

struct sgttyb _tty;
struct win gwin;
int _rawmode;
int _tty_ch;
int nxstty;
int seen_flags;

int xstty();

int
main()
{
    struct win *w;
    int a, b, y, x;
    int r = 0;

    _tty_ch = 3;
    _tty.sg_flags = 010;

    /* bare comma-expression statement (getyx's shape, plain vars) */
    a = 0; b = 0;
    a = 5, b = 7;
    if (a == 5 && b == 7)
        r += 10;

    /* cbreak: field |= first operand, plain = middle, call last */
    cbreak();
    if (_tty.sg_flags == 012 && _rawmode == TRUE && nxstty == 1 &&
        seen_flags == 012)
        r += 12;

    /* nocbreak: the &= ~mask sibling */
    nocbreak();
    if (_tty.sg_flags == 010 && _rawmode == FALSE && nxstty == 2 &&
        seen_flags == 010)
        r += 10;

    /* getyx: member reads into locals through a struct pointer */
    gwin._cury = 4;
    gwin._curx = 6;
    w = &gwin;
    y = 0; x = 0;
    getyx(w, y, x);
    if (y == 4 && x == 6)
        r += 10;

    return r;
}

int
xstty(ch, tp)
int ch;
struct sgttyb *tp;
{
    nxstty++;
    seen_flags = tp->sg_flags;      /* flags AT CALL TIME (ordering pin) */
    return ch;
}
