/* A dynamic link against libfgx.so (shared libc SP5): ticks() is libfgx's,
 * printf libc's. */
#include <stdio.h>
extern long ticks();

main()
{
    printf("%ld\n", ticks());
    return 0;
}
