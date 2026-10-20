#include <sys/stat.h>
extern char *strcpy(char *dst, char *src);
char pathbuf[32];
int main()
{
    struct stat statb;            /* LOCAL soft-stack buf, exactly like elvis tmp.c */
    char *p; int i, r;
    strcpy(pathbuf, "/etc/hostname");
    p = (char *)&statb;
    for (i = 0; i < 30; i++) p[i] = 0xEE;   /* poison */
    r = stat(pathbuf, &statb);
    if (r != 0) return 2;
    if ((statb.st_mode & 0xF000) == 0x8000) return 42;   /* S_IFREG = PASS */
    return (int)((statb.st_mode >> 8) & 0xFF);           /* 238=0xEE poison if unwritten */
}
