/* dyntabseg -- a dynamic program whose only code segment has no room for
 * the binder's tables, so they go in an added segment (shared libc SP5
 * spec 4.1).  pad.s fills the segment; build_dynso.sh sizes it. */
#include <stdio.h>

int
main()
{
    printf("TAB ok\n");
    return 0;
}
