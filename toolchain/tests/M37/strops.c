/* T5-C C4 batch 3: the str* family in C over __asm.
 *
 * One pass over all nine conversions with the edges that matter:
 * cross-bank (bank-0 stack vs data-bank globals vs literals), strncmp
 * early-stop vs sign, strncpy zero-padding, strchr/strrchr found /
 * not-found / c==0-finds-the-terminator, and the pointer-return
 * conventions (d back from the copies, s+idx from the searches).
 * clang cross-checked: 5*7 + 4 + 2 + 1 = 42. */
#include <string.h>

char g1[24];
char g2[24];

int main(void)
{
    char lb[12];
    int r = 0;

    strcpy(g1, "hello");                    /* literal -> data-bank global */
    strcpy(lb, "hel");                      /* literal -> bank-0 stack */
    strcat(lb, "lo");                       /* stack dst: walk + append */
    if (strcmp(g1, lb) == 0)      r += 5;   /* cross-bank compare */
    if (strlen(g1) == 5)          r += 5;
    if (strncmp(g1, "help", 3) == 0) r += 5;
    if (strncmp(g1, "help", 4) < 0)  r += 5; /* 'l' < 'p' */
    strncpy(g2, g1, 8);                     /* copies 6, pads 2 zeros */
    if (g2[5] == 0 && g2[7] == 0) r += 5;
    if (memcmp(g1, g2, 6) == 0)   r += 5;
    if (strchr(g1, 'l') == g1 + 2) r += 5;
    if (strrchr(g1, 'l') == g1 + 3) r += 4;
    if (strchr(g1, 'z') == NULL)  r += 2;
    if (strrchr(g1, 0) == g1 + 5) r += 1;   /* c==0 -> terminator ptr */
    return r;
}
