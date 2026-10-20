/* fcc2 P1.4 B1b regression: a hot pointer PARAM walk (*p + p++) is promoted to a
 * contiguous DP-IMG pair and 4-byte-seeded at entry; the plain deref `*p`
 * collapses to a single `LDA [_fcc_img{k}]`.  If the seed loads the wrong stack
 * words, or the img deref reads the wrong DP address/bank, the result is not 42.
 *
 * p is a char* param, dereffed + incremented every loop iteration (loop-hot) and
 * char-pointee -> promotable.  psum walks data[0..3] = 9+10+11+12 = 42. */
static char data[4];

static int psum(char *p, int n)
{
    int s = 0;
    while (n > 0) {
        s = s + *p;     /* direct deref -> LDA [_fcc_img{k}] */
        p++;            /* offset-incr on the promoted pair  */
        n--;
    }
    return s;
}

int main(void)
{
    data[0] = 9; data[1] = 10; data[2] = 11; data[3] = 12;
    return psum(data, 4);   /* 9 + 10 + 11 + 12 == 42 */
}
