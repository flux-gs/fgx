/* fcc regression: EXTERN re-declaration AFTER a global's definition must
 * be a no-op (legal C).  Shape: a header's `extern int x;` re-included
 * after the defining TU in a merged pile — libcurses' curses.ext after
 * curses.c, where it silently DROPPED LINES/COLS/_tty_ch from the data
 * seg (storage demoted back to extern + initializer wiped).  Also covers
 * the multi-declarator + initializer form that exposed it. */
int a = 40, b, c;
extern int a, b, c;      /* extern after definition — keep storage + init */
char *p = "x";
extern char *p;
int main(void)
{
    b = 1;
    c = (p != 0);        /* p's storage + init survive too */
    return a + b + c;    /* 42 */
}
