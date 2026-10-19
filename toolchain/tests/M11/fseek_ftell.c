/* M24: c_fseek + c_ftell shims via long-arg passing.
 * Opens a PURPOSE-BUILT 42-byte file /testdata/ftell (NOT a malleable
 * user-facing file like /etc/motd, whose size drifts), seeks to end, and
 * reads the size back via ftell.  The file is exactly 42 bytes by
 * construction, so its size IS the pass code.
 *
 * THE NAME IS LOWERCASE BECAUSE THE VOLUME IS.  This said /testdata/FTELL and
 * worked for as long as the root was ProDOS, which folds case; a 2.11BSD root
 * does not, so fopen answered NULL and the fixture returned its `!fp' arm --
 * exit 1 where 42 was expected.  The file on disk has always been
 * disk_src/testdata/ftell.  Same class as novidraw opening the man page by the
 * name the volume actually has. */
#include <stdio.h>

int main()
{
    FILE *fp;
    long  sz;

    fp = fopen("/testdata/ftell", "r");
    if (!fp) return 1;
    fseek(fp, 0L, SEEK_END);
    sz = ftell(fp);
    fclose(fp);

    return (int)sz;       /* /testdata/ftell is exactly 42 bytes */
}
