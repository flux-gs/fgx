/* fd_set idiom: value-base long* array-element store / compound-assign / read
 * on (&var)->longarr[i] — FD_ZERO/FD_SET/FD_CLR/FD_ISSET expand to this.
 * Formerly rejected ("chained '->' to in-struct long array field" then
 * "value-base index-store through long*").  Exercises 32-bit range (bit 30)
 * and two elements.  -> 42. */
struct fds { long b[2]; };

int main(void)
{
    struct fds e;
    (&e)->b[0] = 0;                 /* store  (FD_ZERO)  */
    (&e)->b[1] = 0;
    (&e)->b[0] |= (1L << 3);        /* or=    (FD_SET)   */
    (&e)->b[0] |= (1L << 30);       /* high 32-bit bit   */
    (&e)->b[1] = (1L << 5);
    (&e)->b[1] &= ~(1L << 5);       /* and=   (FD_CLR)   */
    if (((&e)->b[0] & (1L << 3))  == 0) return 1;   /* read (FD_ISSET) */
    if (((&e)->b[0] & (1L << 30)) == 0) return 2;
    if ((&e)->b[0] != ((1L << 3) | (1L << 30)))     return 3;
    if ((&e)->b[1] != 0)                            return 4;
    return 42;
}
