/* fcc2 P1.4 B1b regression (review-found): a promoted pointer PARAM (and scalar
 * param) in a frame > 255 bytes must seed via the DO/256 far path.  A raw
 * `LDA off+FRAMESIZE,S` overflows the 65816's 8-bit n,S displacement -> merlin32
 * rejects it / fas silently truncates -> the img pair is seeded from the wrong
 * stack slots -> wild far-pointer deref.  pad[300] forces FRAMESIZE > 255; p is a
 * loop-walked char* param (promoted + seeded) and n a loop-hot int param (also
 * promoted + seeded), so BOTH the pointer and scalar param seeds hit the far
 * path.  If the seed regresses to a bare LDA n,S this fails to build or != 42. */
static char data[4];

static int bigframe(char *p, int n)
{
    char pad[300];
    int s = 0, i;
    pad[0] = 0;
    for (i = 0; i < n; i++) {
        s = s + *p;     /* deref of promoted pointer param */
        p++;            /* offset-incr on the promoted pair */
    }
    return s + pad[0];
}

int main(void)
{
    data[0] = 9; data[1] = 10; data[2] = 11; data[3] = 12;
    return bigframe(data, 4);   /* 9 + 10 + 11 + 12 + 0 == 42 */
}
