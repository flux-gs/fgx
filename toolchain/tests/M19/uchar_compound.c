/* E1 op= E2 WITH AN UNSIGNED CHAR ON EITHER SIDE: a signed int operation.
 *
 * K&R A.7.17 (p.169): "E1 op= E2 is equivalent to E1 = E1 op (E2)", and A.6.1
 * (p.159) promotes an unsigned char to int, since an int holds every value.
 * So these divide signed: an unsigned divide gives 0 in each case.
 */
unsigned char GC;
int GI;
unsigned char *PC;

int main()
{
    int acc;
    int x;
    unsigned char c;

    acc = 0;
    x = -400;
    c = 200;
    x /= c;                                  /* -2 */
    if (x == -2) acc += 1;
    c = 200;
    c /= -2;                                 /* -100 stored: 156 */
    if (c == 156) acc += 2;
    GC = 200;
    GC /= -2;                                /* a global */
    if (GC == 156) acc += 4;
    GI = -400;
    GI /= GC;                                /* -400 / 156 = -2 */
    if (GI == -2) acc += 8;
    GC = 200;
    PC = &GC;
    *PC /= -2;                               /* through a pointer */
    if (GC == 156) acc += 16;
    x = -600;
    x %= c;                                  /* c is 156 here: -600 % 156 */
    if (x == -600 % 156) acc += 32;
    c = 10;
    c -= 20;                                 /* -10 stored: 246 */
    if (c == 246) acc += 64;
    x = -1;
    x += c;                                  /* 245 */
    if (x == 245) acc += 128;

    return acc;                              /* 255 */
}
