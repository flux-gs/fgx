/* T5-C C4 batch 11: stat(2) native->POSIX translate in C + strerror
 * wrapper.  st is a bank-0 HW-stack LOCAL — exercises the caller-buf-bank
 * contract (the historic vi "not a regular file" hang).  strerror's deref
 * is bank-sensitive (message lives in the DATA bank; ENOENT -> 'N').
 *
 * FGX-only (MAME oracle).  8+8+8+6+6+6 = 42. */
#include <sys/stat.h>
extern char *strerror();

int main(void)
{
    struct stat st;
    int r = 0;

    if (stat("/bin/true", &st) == 0)         r += 8;
    if ((st.st_mode & S_IFMT) == S_IFREG)    r += 8;
    if (st.st_size > 0)                      r += 8;
    if (st.st_nlink == 1)                    r += 6;
    if (stat("/nosuchfile", &st) == -1)      r += 6;
    if (*strerror(2) == 'N')                 r += 6;
    return r;
}
