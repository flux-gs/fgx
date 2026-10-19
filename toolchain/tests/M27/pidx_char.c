/* B1c-2b: char* s indexed -> LDA [_fcc_img{k}],Y + AND #$00FF.
 * 'A'(65) + 'B'(66) = 131; 131 - 65 = 66. */
static char buf[4];
static int csum(char *s, int n)
{
    int t = 0, i;
    for (i = 0; i < n; i++) t = t + s[i];
    return t - 65;
}
int main(void)
{
    buf[0] = 'A'; buf[1] = 'B'; buf[2] = 0; buf[3] = 0;
    return csum(buf, 2);                      /* 131 - 65 == 66 */
}
