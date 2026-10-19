/* dynmulti's third code segment: stdio (fputs, stdout) and errno reached
 * from a segment other than 0. */
#include <stdio.h>
#include <errno.h>

int
seg3_fn()
{
    return fputs("", stdout) == EOF ? -1 : errno;
}
