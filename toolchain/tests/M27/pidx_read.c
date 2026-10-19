/* B1c-2b: hot int* p indexed by a loop counter (base-independent index) promotes
 * to LDA [_fcc_img{k}],Y.  psum(data,4) sums data[2..3] = 11+12 = 23. */
static int data[4];
static int psum(int *p, int n)
{
    int s = 0, i;
    for (i = 2; i < n; i++) s = s + p[i];   /* p[i]: promoted index deref */
    return s;
}
int main(void)
{
    data[0] = 9; data[1] = 10; data[2] = 11; data[3] = 12;
    return psum(data, 4);                    /* 11 + 12 == 23 */
}
