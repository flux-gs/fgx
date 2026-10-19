/* ---- dirent (H1: sys/dir.h over SYS_LISTDIR) ------------------------------
 * SYS_LISTDIR is one-shot (whole directory as NUL-separated names into a
 * caller buffer, no resume) and resolves the path AND the buffer through
 * ONE caller bank.  Both therefore live in a single malloc'd block and the
 * call runs under __syscall_db with the block's HEAP bank: the path is
 * staged at the head of the names region and OVERLAID by the kernel's
 * output — safe because the kernel copies the path to its own buffer
 * (_Sys_CopyPathToBuf) before the directory is read.  Layout:
 *   the DIR header, then [sizeof(DIR) .. +__DIRBUF_MAX) the path, then names
 *
 * sizeof(DIR) AND NOT A LITERAL.  It was a hardcoded 4 in two places, and
 * adding dd_fd for dirfd(3) moved the names to 6 while readdir went on reading
 * from 4 -- so the first two bytes of dd_size were handed back as a directory
 * entry and `ls -l /dev' reported a phantom `/dev/T not found'.
 * Snapshot ceiling __DIRBUF_MAX bytes of names; larger directories
 * truncate silently (the kernel call's own shape).  DIRs are independent
 * malloc'd handles — concurrent opendirs are fine. */

static struct direct __lc_dirent;       /* readdir's return cell */

DIR *opendir(char *path)
{
    DIR *d;
    char *blk;
    unsigned long lp;
    int n;

    d = (DIR *)malloc(sizeof(DIR) + 2048);   /* hdr + __DIRBUF_MAX */
    if (d == 0)
        return (DIR *)0;                /* errno from malloc */
    blk = (char *)d + sizeof(DIR);
    strcpy(blk, path);
    lp = (unsigned long)blk;
    n = (int)__syscall_db(49, (unsigned)(lp >> 16),
                          (unsigned)lp,          /* A = path (staged) */
                          (unsigned)lp,          /* X = names buffer  */
                          2048);                 /* Y = buffer max    */
    if (__syscall_c() == 0) {
        errno = n;
        free((char *)d);
        return (DIR *)0;
    }
    /* The descriptor dirfd(3) hands out.  Opened AFTER the listing so a
     * failure here costs nothing that already worked. */
    d->dd_fd   = open(path, 0, 0);   /* O_RDONLY: no mode to give */
    d->dd_loc  = 0;
    d->dd_size = n;
    return d;
}

struct direct *readdir(DIR *dirp)
{
    char *names;
    int i, loc;
    unsigned ino;

    if (dirp == (DIR *)0)
        return (struct direct *)0;
    loc = dirp->dd_loc;
    if (loc + 2 > dirp->dd_size)        /* no room for a record's inode */
        return (struct direct *)0;
    names = (char *)dirp + sizeof(DIR);
    /* A RECORD IS `ino:2' THEN `name\0', little-endian.  THE LENGTH IS THE
     * BOUND -- dd_size is what the kernel said it wrote, and there is no
     * terminator record; the inode makes a record something you must have two
     * bytes of before you can trust the name, so a marker would have had to be
     * two bytes as well and the length already says it.
     *
     * The zero-inode test is a GUARD, not the terminator: the kernel skips any
     * entry whose d_ino is 0 (2.11BSD dir.h -- a free entry has d_ino set to 0)
     * so it never writes one, and this stops a truncated or foreign buffer
     * being read as a name. */
    ino = (unsigned)(unsigned char)names[loc]
        | ((unsigned)(unsigned char)names[loc + 1] << 8);
    if (ino == 0)
        return (struct direct *)0;
    loc += 2;
    i = 0;
    while (i < MAXNAMLEN && names[loc + i] != 0) {
        __lc_dirent.d_name[i] = names[loc + i];
        i++;
    }
    __lc_dirent.d_name[i] = 0;
    __lc_dirent.d_namlen  = i;
    __lc_dirent.d_ino     = (unsigned short)ino; /* the filesystem's, not a 1 */
    while (names[loc + i] != 0)                  /* overlong: skip rest */
        i++;
    dirp->dd_loc = loc + i + 1;                  /* past the NUL */
    return &__lc_dirent;
}

int closedir(DIR *dirp)
{
    if (dirp == (DIR *)0) { errno = 9; return -1; }          /* EBADF */
    if (dirp->dd_fd >= 0)
        close(dirp->dd_fd);
    free((char *)dirp);
    return 0;
}

/* dirfd(3) -- the descriptor behind a DIR.  -1 when the open failed; a caller
 * that fstats it gets EBADF, which is the honest answer. */
int dirfd(dirp)
DIR *dirp;
{
    return (dirp == (DIR *)0 ? -1 : dirp->dd_fd);
}

/* readlink(2) over SYS_READLINK=112.  IT RETURNED EINVAL UNCONDITIONALLY
 * until 2026-09-05, with the note "FGX/ProDOS has no symlinks" -- true of
 * ProDOS and not of the 2.11BSD root, where ufs_symlink and ufs_readlink have
 * been live vnodeops since UFS 1.13a.  The syscall was what was missing.
 *
 * EINVAL SURVIVES as the answer for a name that is not a symlink, which is
 * what a port's S_IFLNK-guarded call expects -- it is the kernel's answer now
 * rather than this function's assumption. */
int readlink(char *path, char *buf, int bufsiz)
{
    int r;
    int i;

    strcpy(_libc_lstrBufB, path);
    /* BOTH THE PATH AND THE ANSWER MUST BE IN ONE BANK, and that is the whole
     * of what was wrong with this call.  The kernel reads the path from, and
     * writes the target back into, the CALLER'S DBR (syscall.s:145,
     * `_Sys_CallerBank') -- one bank for both.  This used plain __syscall and
     * so handed the kernel whatever DBR happened to be, and readlink came back
     * with the right COUNT and NOTHING WRITTEN: the caller's buffer still held
     * its own paint, $A5.  apple/fgx#326 spent a day looking inside the VFS
     * for that, and the VFS was never involved.
     *
     * So the answer lands in a libc static beside the staged path -- same
     * bank, by construction -- and is copied out here, where `buf' can be
     * anywhere the caller likes.  __syscall_db names that bank explicitly
     * rather than trusting DBR, which is what every other buffer-passing call
     * in this libc already does. */
    /* 128 IS THE LITERAL AND sizeof IS NOT USABLE HERE: _libc_lstrBufA is an
     * `extern char []' -- an INCOMPLETE type -- so sizeof on it is not the
     * array's size.  Writing it that way clamped bufsiz to 1 and readlink
     * returned exactly one character, `-> /'.  The 128 is
     * toolchain/lib/libc_data.s:32, where the buffer is declared. */
    if (bufsiz > 128)
        bufsiz = 128;
    r = (int)__syscall_db(112,
                          (unsigned)((unsigned long)_libc_lstrBufB >> 16),
                          (unsigned)(unsigned long)_libc_lstrBufB,
                          (unsigned)(unsigned long)_libc_lstrBufA,
                          (unsigned)bufsiz);
    if (__syscall_c() == 0) { errno = r; return -1; }
    for (i = 0; i < r; i++)
        buf[i] = _libc_lstrBufA[i];
    return r;
}


