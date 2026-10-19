/* H1 tip: strncat(3) in the pile — n-limited append with NUL termination,
 * n larger than src (copies all), n smaller (truncates), append to empty,
 * return-value identity, dst prefix untouched.  Host clang cross-checks
 * against its own strncat.  7+7+7+7+7+7 = 42. */
#include <string.h>

char buf[32];

int main(void)
{
    int r = 0;
    char *ret;

    /* n > strlen(src): whole src appended + NUL */
    strcpy(buf, "abc");
    ret = strncat(buf, "def", 10);
    if (strcmp(buf, "abcdef") == 0) r += 7;
    if (ret == buf) r += 7;

    /* n < strlen(src): exactly n bytes + NUL */
    strcpy(buf, "abc");
    strncat(buf, "defgh", 2);
    if (strcmp(buf, "abcde") == 0) r += 7;
    if (buf[5] == 0) r += 7;

    /* append to empty dst */
    buf[0] = 0;
    strncat(buf, "xyz", 8);
    if (strcmp(buf, "xyz") == 0) r += 7;

    /* n == 0: dst unchanged */
    strcpy(buf, "keep");
    strncat(buf, "junk", 0);
    if (strcmp(buf, "keep") == 0) r += 7;

    return r;
}
