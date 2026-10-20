/* G53 cycle 2: a PARAM read in a >255-byte frame.  The param `base` sits at
 * base_off+FRAMESIZE,S; with FRAMESIZE>255 that stack-rel displacement is
 * illegal (8-bit max).  Pre-fix merlin rejects it.  Returns 42. */
int bigframe_p(int base)
{
    char buf[300];
    int i;
    for (i = 0; i < 300; i++)
        buf[i] = (char)(i & 0x7F);
    return base + buf[50] - 12;   /* 4 + 50 - 12 = 42 */
}

int main()
{
    return bigframe_p(4);
}
