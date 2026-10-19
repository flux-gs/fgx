/* dynmulti's second code segment: libc code (strcpy, strlen) and data
 * (errno) reached from a segment other than 0. */
#include <string.h>
#include <errno.h>

int
seg2_fn(b)
char *b;
{
    strcpy(b, "seg2!");
    return errno == 0 ? (int)strlen(b) : -1;
}
