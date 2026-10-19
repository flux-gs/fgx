/* labs(3), 4.3BSD-Reno stdlib/labs.c: `return(j < 0 ? -j : j);'.  LONG_MIN has
 * no positive counterpart in two's complement, so labs(LONG_MIN) hands back
 * LONG_MIN -- undefined, and what every other libc does with it. */
long labs(long j)
{
    return j < 0 ? -j : j;
}
