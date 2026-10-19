/* A-1: unsigned 16-bit comparison.  40000 > 20000 is 1 unsigned; under the
 * old signed compare 40000 reads as -25536 so 40000 > 20000 was wrong (0).
 * Picks _fcc_gtu16.  Returns 1. */
unsigned va;
unsigned vb;
int main()
{
    va = 40000;
    vb = 20000;
    return va > vb;
}
