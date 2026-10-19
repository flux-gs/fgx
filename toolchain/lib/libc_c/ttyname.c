/* ttyname(fd): ask the kernel which line this fd is bound to (FIODGNAME), and
 * prefix "/dev/".  BSD's implementation -- fstat, then readdir("/dev")
 * matching st_rdev -- is not available: the device namespace is a synthetic
 * short-circuit in Path_Resolve, not an enumerable directory, and stat has no
 * st_rdev.
 *
 * THE PREFIX IS "/dev/", and the round trip is worth recording.  It moved to
 * the transitional namespace under apple/fgx#223 because three consumers
 * compared against that spelling -- ttysprobe's TP18, ttytest's console
 * case, and fractal's controlling-terminal check -- and all three were failing.
 * Those three now compare against "/dev/", because that is where the device
 * NODES are: /dev/console is a real IFCHR inode made by mknod, and ttyname()
 * reporting a name that is not the file's is the thing #223 was about.
 *
 * Both spellings still RESOLVE, so this changes the name reported rather than
 * the set of names that work -- which is exactly what #223 said of the move in
 * the other direction.  The kernel's contract is unchanged and still stated
 * beside `_ttyNames' at src/kernel/signal.s: names carry no prefix and libc
 * adds one.
 *
 * THE BUFFER IS SIZED FROM THE PREFIX, which is the part a one-character edit
 * gets wrong in either direction: FIODGNAME writes up to FIODGNAME_MAX
 * including its NUL, so the array must be PFXLEN + FIODGNAME_MAX and the two
 * constants must move together.  Going the other way, #223 found the longest
 * name running one byte past the end.
 *
 * No isatty() probe: FIODGNAME returns ENOTTY for a non-tty fd, so the ioctl IS
 * the check, and doing both would cost a second syscall to learn the same thing.
 *
 * The returned pointer is a static buffer valid until the next call -- the BSD
 * contract, so callers that strcpy out of it are unchanged. */
#define _TTYNAME_PFX    "/dev/"
#define _TTYNAME_PFXLEN 5           /* strlen(_TTYNAME_PFX) -- see the buffer */

static char _tty_name[_TTYNAME_PFXLEN + FIODGNAME_MAX];  /* prefix + name + NUL */

char *ttyname(fd)
    int fd;
{
    strcpy(_tty_name, _TTYNAME_PFX);
    if (ioctl(fd, FIODGNAME, &_tty_name[_TTYNAME_PFXLEN]) < 0)
        return (char *)0;
    return _tty_name;
}

/* rewinddir(3): a FGX DIR is a kernel-made SNAPSHOT plus a cursor, so rewinding
 * is just resetting the cursor -- no re-read, and no lseek on the underlying fd
 * (there is not one).  Note this does NOT re-scan the directory: entries created
 * since opendir() stay invisible until the next opendir, which is the documented
 * snapshot semantics, not an oversight. */
void rewinddir(dirp)
    DIR *dirp;
{
    if (dirp != (DIR *)0)
        dirp->dd_loc = 0;
}

