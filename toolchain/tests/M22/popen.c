/* M22: popen()/pclose(), 2.11BSD's (gen/popen.c).  A read end carries the
 * command's output, a write end feeds its input, and pclose returns the
 * shell's wait status.  Returns 42. */
#include <stdio.h>

int main()
{
    FILE *p;
    char buf[16];

    p = popen("echo hi", "r");
    if (p == 0)                          return 1;
    if (fgets(buf, sizeof buf, p) == 0)  return 2;
    if (buf[0] != 'h' || buf[1] != 'i' || buf[2] != '\n') return 3;
    if (fgets(buf, sizeof buf, p) != 0)  return 4;   /* EOF after one line */
    if (pclose(p) != 0)                  return 5;

    p = popen("cat >/dev/null", "w");
    if (p == 0)                          return 6;
    fputs("discarded\n", p);
    if (pclose(p) != 0)                  return 7;

    p = popen("exit 3", "r");
    if (p == 0)                          return 8;
    if (pclose(p) != (3 << 8))           return 9;   /* WEXITSTATUS 3 */
    if (pclose(stdin) != -1)             return 10;  /* not popen'd */
    return 42;
}
