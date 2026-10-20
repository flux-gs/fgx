/* H1: sys/dir.h dirent surface over SYS_LISTDIR (malloc'd per-DIR
 * snapshot, heap-bank __syscall_db).  FGX-only (MAME oracle): reads the
 * boot disk's /bin.  Checks: entries enumerate with sane namlen, "true"
 * and "sh" both appear, CONCURRENT DIRs are independent, and close/reopen
 * works.  The kernel appends a ZERO-LENGTH terminator entry (counted in
 * its returned total); readdir must consume it as end-of-list — namlen 0
 * must never surface (the `sane` check pins it).  8+8+8+9+9 = 42. */
#include <sys/dir.h>
extern int errno;

int nameis(char *a, char *b)
{
    int i = 0;
    while (a[i] && a[i] == b[i]) i++;
    return a[i] == b[i];
}

int main(void)
{
    DIR *d, *d2;
    struct direct *dp;
    int n = 0, seen_true = 0, seen_sh = 0, sane = 1, r = 0;

    d = opendir("/bin");
    if (d == 0) return 1;
    d2 = opendir("/etc");                     /* concurrent DIR: independent */
    if (d2 != 0) {
        dp = readdir(d2);                     /* reading d2 must not move d */
        if (dp != 0 && d->dd_loc == 0) r += 9;
        closedir(d2);
    }
    while ((dp = readdir(d)) != 0) {
        n++;
        if (dp->d_namlen < 1 || dp->d_namlen > 15) sane = 0;
        if (dp->d_ino == 0) sane = 0;
        if (nameis(dp->d_name, "true")) seen_true = 1;
        if (nameis(dp->d_name, "sh"))   seen_sh = 1;
    }
    if (n > 10) r += 8;
    if (sane)   r += 8;
    if (seen_true && seen_sh) r += 8;
    if (closedir(d) == 0) {
        d = opendir("/bin");                  /* reopen after close */
        if (d != 0) {
            dp = readdir(d);
            if (dp != 0 && dp->d_namlen > 0) r += 9;
            closedir(d);
        }
    }
    return r;
}
