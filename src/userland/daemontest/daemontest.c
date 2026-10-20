/* daemontest -- daemon(3) returns its invoker (apple/fgx#494).  The shell's
 * next command runs at once; the daemon writes /tmp/dt.mark two seconds
 * later, after its parent has exited. */
#include <stdio.h>
#include <fcntl.h>

int daemon();
int sleep();
int open();
int close();

int
main()
{
    if (daemon(0, 1) < 0) { printf("DT FAIL daemon\n"); return 1; }
    sleep(2);
    close(open("/tmp/dt.mark", O_WRONLY | O_CREAT, 0644));
    return 0;
}
