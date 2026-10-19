/* M11: stat() with a bank-0 HW-stack LOCAL path (P3-4 I2).
 * fcc locals live on the bank-0 hardware stack, so `path[]' here is in bank 0 —
 * a DIFFERENT bank than the libc data segment.  c_stat stages the path into
 * DBR-bank scratch so the native image stays in the libc data bank regardless
 * of where the path lives.
 * ⚠ SMOKE TEST ONLY — this exit code CANNOT catch the I2 bug (RED-proven: the
 * buggy shim wrote AND read the native image at the same wrong-bank $00
 * location, so st_mode round-trips correctly and the buggy build also returns
 * 42).  The bug's observable is the bank-0 SCRIBBLE at $00:_libc_lstrBufA; the
 * fail-closed gate is the capture_writes tap in the shared I2+I3 corruption
 * oracle (tools/mame_test), not this fixture.
 *
 * THE SCRATCH IS A struct stat AND NOT A HAND-ROLLED int[].  The structure is
 * 52 bytes (sys/stat.h) and stat(2) fills every one of them, so a short local
 * here overwrites the bank-0 hardware stack past its end -- which HANGS rather
 * than failing, and a hung fixture carries its whole oracle chunk of forty
 * down with it unscored.  Naming the type is what keeps the size from drifting
 * away from the kernel's again.  apple/fgx#383.
 *
 * /bin/sh is a regular file, so S_IFREG must be set in st_mode.  Returns 42
 * iff stat works; 1 = stat failed (path not found), 2 = st_mode wrong. */
#include <string.h>
#include <sys/stat.h>

int main()
{
    char path[16];
    struct stat st;

    strcpy(path, "/bin/sh");  /* bank-0 HW-stack local -> the I2 path */
    if (stat(path, &st) != 0) return 1;
    if ((st.st_mode & S_IFREG) == 0) return 2;
    return 42;
}
