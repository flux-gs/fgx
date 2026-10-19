/* M23: #include <stdio.h> / <string.h>  — system header lookup via the
 * argv[0]-derived include dir.  Verifies the FILE * typedef + stdout
 * global + strlen / fputs decls all resolve through angle-includes. */
#include <stdio.h>
#include <string.h>

int main()
{
    fputs("sysinc ok\n", stdout);
    return strlen("hello") + strlen("world") + 32;   /* 5+5+32 = 42 */
}
