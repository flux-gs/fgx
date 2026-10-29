/* M37: a member reached through the address of a global at a constant
 * offset is read and written at that address (K&R A.7.3.3: "E1->MOS is the
 * same as (*E1).MOS"; A.7.3.1: "E1[E2] is identical (by definition) to
 * *((E1)+(E2))").  The <stdio.h> macros are this shape: getc(stdin) is
 * --(&_iob[0])->_cnt.  Each case below either folds to an absolute address
 * or makes the register real first: as an argument, across a branch, with
 * a variable index, as a long.  Returns 42. */
struct io { int cnt; char *ptr; char *base; int bs; short fl; char fd; };
struct io tab[3];
long lg[2];
char buf[8] = "abcdefg";

#define gc(p)   (--(p)->cnt >= 0 ? (int)(*(unsigned char *)(p)->ptr++) : -1)

int take(struct io *p, int v) { return p->fd + v; }
long addr(struct io *p) { return (long)p; }
/* bcopy's overlap test: two pointers compared as unsigned long, one passed
 * from a variable and one as a constant address -- the whole bank word of
 * each must agree. */
int below(struct io *a, struct io *b) { return (unsigned long)a < (unsigned long)b; }

int main()
{
    int i, r = 0, c;
    struct io *vp;

    tab[1].cnt = 3; tab[1].ptr = buf; tab[1].fd = 7;
    c = gc(&tab[1]);  if (c != 'a') return 1;
    c = gc(&tab[1]);  if (c != 'b') return 2;
    if (tab[1].cnt != 1 || tab[1].ptr != buf + 2) return 3;
    if ((&tab[1])->cnt-- != 1 || tab[1].cnt != 0) return 4;
    if (gc(&tab[1]) != -1) return 5;
    tab[2].fd = 'x';
    if (++(&tab[2])->fd != 'y') return 6;
    (&tab[2])->fd = (char)0xFF;
    if (++tab[2].fd != 0) return 7;            /* byte wrap, neighbor intact */
    tab[2].fl = 0x1234;
    if (tab[2].fl != 0x1234) return 8;
    if (take(&tab[1], 3) != 10) return 9;      /* as an argument */
    r = take(&tab[1], tab[1].cnt < 0 ? 2 : 1); /* live across a branch */
    if (r != 9) return 10;
    i = 2;
    if ((&tab[i])->fd != 0) return 11;         /* variable index */
    if ((&tab[i < 0 ? 0 : 1])->fd != 7) return 16;   /* branch in the index */
    if (addr(&tab[0]) == addr(&tab[1])) return 12;
    if ((long)&tab[2] - (long)&tab[1] != sizeof(struct io)) return 13;
    lg[1] = 0x12345678L;
    if ((&lg[1])[0] != 0x12345678L) return 14;
    vp = &tab[2];
    if (!below(&tab[1], vp) || below(vp, &tab[1])) return 17;
    *(&tab[0].fd) = 5;
    if (tab[0].fd != 5) return 15;
    return 42;
}
