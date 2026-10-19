/* A-1: unsigned 16-bit division.  40000 / 1000 == 40 unsigned; signed
 * division of -25536/1000 gives the wrong answer.  Picks _fcc_divu16.
 * Returns 40. */
unsigned va;
int main()
{
    va = 40000;
    return va / 1000;
}
