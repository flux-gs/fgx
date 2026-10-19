/* ---- buffered syscall wrappers (C4 batch 4) ------------------------------
 * The __syscall_db class: the kernel reads/writes user buffers through
 * DBR, so each wrapper hands the pointer's bank to the builtin — the
 * whole hand PHB/swap/PLB discipline is one line of C now.
 * FGX convention notes preserved from the shims: read/write return 0
 * (not -1) on error; lseek packs (whence<<8)|fd into A and returns the
 * 32-bit position as a long (hi byte in Y). */

int read(int fd, char *buf, int n)
{
    unsigned long lp = (unsigned long)buf;
    int r = (int)__syscall_db(3, (unsigned)(lp >> 16), fd, (unsigned)lp, n);
    /* POSIX: -1 on error (errno set) vs 0 on EOF.  The kernel returns C=1 with
     * a 0 byte count for EOF and C=0 for a real error, so a non-blocking read
     * with no data (EAGAIN) is distinguishable from EOF (telnet needs this). */
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

int write(int fd, char *buf, int n)
{
    unsigned long lp = (unsigned long)buf;
    int r = (int)__syscall_db(4, (unsigned)(lp >> 16), fd, (unsigned)lp, n);
    if (__syscall_c() == 0) { errno = r; return -1; }   /* POSIX: -1 on error */
    return r;
}

/* open(2) -- SYS_OPEN(5).  A=path, X=flags, Y=mode.
 *
 * THE THIRD ARGUMENT IS READ ONLY WHEN O_CREAT IS SET, which is what makes a
 * two-argument call safe.  2.11BSD's open(2) is the same bargain: its stub
 * hands the kernel three words whether or not the caller supplied three, and
 * the kernel consults the mode only on the create path (4.3BSD-Reno
 * kern/vfs_syscalls.c:559, `cmode = ((uap->crtmode &~ u.u_cmask) & 07777)
 * &~ S_ISVTX', reached from vn_open's FCREAT arm and nowhere else).  So an
 * `open(path, O_RDONLY)' leaves the mode unread, and an
 * `open(path, O_CREAT|..., 0644)' has it honoured.
 *
 * AND FGX IS SAFER HERE THAN ITS ANCESTOR, measured rather than assumed: a
 * short call on 2.11BSD hands the kernel whatever word was on the stack,
 * while fcc pads a short call with an explicit zero and warns at the site
 * (`'open' called with 2 args, expects 3 -- K&R-padding the rest with 0').
 * A two-argument O_CREAT is still a caller bug; it creates mode 0 rather than
 * something arbitrary, and the compiler names the line.
 *
 * IT WAS TWO-ARGUMENT UNTIL NOW AND THAT IS WHY EVERY CREATED FILE HAD MODE 0.
 * The mode was dropped here, `root_open' passed a hardcoded 0 as vn_open's
 * cmode, and vn_mknode wrote that into the inode.  Three ports were trimmed to
 * fit the two-argument shape -- passwd(1), tip(1) and mktemp(3) all pass a
 * mode upstream -- and they are restored with it. */
int open(char *path, int flags, int mode)
{
    unsigned long lp = (unsigned long)path;
    int r = (int)__syscall_db(5, (unsigned)(lp >> 16), (unsigned)lp, flags,
                              mode);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

int creat(char *path, int mode)
{
    /* O_WRONLY|O_CREAT|O_TRUNC, and NOT an unlink first.
     *
     * THE UNLINK DESTROYED DEVICE NODES.  This used to unlink the path and
     * then open O_CREAT|O_WRONLY, on the reasoning "FGX SYS_OPEN does not
     * honor O_TRUNC" -- true of the legacy ProDOS resolver, and false since
     * apple/fgx#318 routed open(2) on a mounted root through vn_open, which
     * honours FTRUNC itself.
     *
     * It was HARMLESS ONLY BECAUSE THE UNLINK FAILED.  On a UFS root unlink
     * answered EIO until the root hook landed, and the result is discarded
     * here by design -- so the open then found the file still there and
     * truncation quietly did not happen.  The moment unlink started working,
     * `>' began DELETING what it redirected to: the Bourne shell's `>' is
     * creat(), so `echo x > /dev/console' removed the character node and made
     * a plain file called `console' in its place.  The write went to that
     * file, nothing reached the console, and `ls -l /dev/console' reported
     * `-r--------' size 0 -- the replacement, not a stat defect.
     *
     * A latent bug that a working unlink turns into data loss is exactly the
     * shape worth naming: the fix that exposed it was correct.
     *
     * THE MODE IS THE CALLER'S NOW.  creat(2) is open(path,
     * O_WRONLY|O_CREAT|O_TRUNC, mode) by definition and this is that,
     * including the mode it always accepted and used to discard. */
    unsigned long lp = (unsigned long)path;
    int r;
    r = (int)__syscall_db(5, (unsigned)(lp >> 16), (unsigned)lp, 0x0601, mode);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

int unlink(char *path)
{
    unsigned long lp = (unsigned long)path;
    int r = (int)__syscall_db(10, (unsigned)(lp >> 16), (unsigned)lp, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* mkdir(2): SYS_MKDIR=92.  mode is advisory (ProDOS has no mode bits); passed
 * for source compatibility but ignored by the kernel.  Path far pointer via
 * _db, bank-correct like unlink/chdir. */
int mkdir(char *path, int mode)
{
    unsigned long lp = (unsigned long)path;
    int r = (int)__syscall_db(92, (unsigned)(lp >> 16), (unsigned)lp, mode, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* rmdir(2) — remove an empty directory (SYS_RMDIR=94).  Mirrors mkdir: the
 * path is a far pointer, passed bank-then-offset via __syscall_db.  Kernel
 * enforces is-dir (ENOTDIR) and empty (ENOTEMPTY). */
int rmdir(char *path)
{
    unsigned long lp = (unsigned long)path;
    int r = (int)__syscall_db(94, (unsigned)(lp >> 16), (unsigned)lp, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* rename(2) — rename FROM to TO (SYS_RENAME=95).  Both paths live in the same
 * caller bank, so one bank byte covers both; A=FROM offset, X=TO offset.  The
 * kernel does an in-place rename only when FROM and TO share a parent
 * directory; a DIFFERENT parent returns EXDEV and mv(1) falls back to
 * copy+unlink.  An existing TO in the same directory is REPLACED, as POSIX
 * requires -- but not atomically: ProDOS has no way to swap two directory
 * entries, so the kernel unlinks TO and then renames, and a crash in between
 * loses TO. */

/* The two-path syscalls pass a block of FAR pointers (apple/fgx#438).
 *
 * They used to pass `from's bank and then `to' as a bare 16-bit offset, so the
 * kernel read BOTH paths out of `from's bank -- the convention carries one
 * bank byte for a whole call, and that was true enough while every string a
 * program had was in its own data bank.  apple/fgx#301 pointed argv at the
 * kernel's bank-0 frame, and `rename(argv[1], argv[2])' started reading its
 * second path from the first one's bank.  Each path names its own bank now.
 *
 * The block is a libc static rather than a local because the kernel reads it
 * through `_Sys_CallerBank' (DBR) at the offset in A, which is SYS_SELECT's
 * convention and the one apple/fgx#303 widened execve to. */
static char *_path2_argblk[2];

int rename(char *from, char *to)
{
    unsigned long lp;
    int r;

    _path2_argblk[0] = from;
    _path2_argblk[1] = to;
    lp = (unsigned long)_path2_argblk;
    r = (int)__syscall_db(95, (unsigned)(lp >> 16), (unsigned)lp, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* symlink(2) -- SYS_SYMLINK(113).  `target' is the link's CONTENTS and is not
 * resolved; `linkname' is the name created.  Both go through the far-pointer
 * block above, so each names its own bank. */
int symlink(char *target, char *linkname)
{
    unsigned long lp;
    int r;

    _path2_argblk[0] = target;
    _path2_argblk[1] = linkname;
    lp = (unsigned long)_path2_argblk;
    r = (int)__syscall_db(113, (unsigned)(lp >> 16), (unsigned)lp, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* link(2) -- SYS_LINK(9).  A SECOND NAME FOR ONE INODE, and it exists now.
 *
 * 2.11BSD's own syscall number, from its dispatch table (usr/sys/sys/
 * init_sysent.c:119); FGX's table had kept the slot as a stub.
 *
 * THIS USED TO SET ENOSYS AND SAY SO IN FULL.  ln(1) is `int (*linkf)() =
 * sflag ? symlink : link', so a verbatim port named link(2) whether the system
 * had one or not, and the honest stub was what let ln land whole in the first
 * place.  ufs_link had been in the vnodeops table since 1.12c-b the entire
 * time -- what was missing was every layer above it.
 *
 * BOTH PATHS GO THROUGH THE FAR-POINTER BLOCK above, so each names its own
 * bank -- `ln argv[1] argv[2]' has both in the kernel's frame while a literal
 * would be in the data bank.
 *
 * THE TARGET IS RESOLVED WITH FOLLOW, so `ln symlink-to-f g' makes a second
 * name for f and not for the symlink.  That is 4.3BSD-Reno's order
 * (kern/vfs_syscalls.c:719) and it is the difference between link(2) and
 * symlink(2) that is easiest to get backwards. */
int link(char *from, char *to)
{
    unsigned long lp;
    int r;

    _path2_argblk[0] = from;
    _path2_argblk[1] = to;
    lp = (unsigned long)_path2_argblk;
    r = (int)__syscall_db(9, (unsigned)(lp >> 16), (unsigned)lp, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* chmod(2) -- SYS_CHMOD(15).  A=path, X=mode.
 *
 * 2.11BSD's own syscall number, from its dispatch table (usr/sys/sys/
 * init_sysent.c:125); FGX's table had kept the slot as a stub.
 *
 * THE PATH IS RESOLVED THROUGH THE FINAL SYMLINK, which is 4.3BSD-Reno's
 * chmod (kern/vfs_syscalls.c:1136, `LOOKUP | FOLLOW | LOCKLEAF') and is not
 * what chown does one function down.  A symlink has no mode of its own worth
 * changing.
 *
 * IT SUCCEEDS FOR ANY CALLER, and that is worth saying rather than
 * discovering: nothing in this kernel evaluates a credential yet, so
 * ufs_setattr runs Reno's cr_uid == 0 path for everyone.  chmod(2)'s BUGS
 * section carries it. */
int chmod(char *path, int mode)
{
    unsigned long lp = (unsigned long)path;
    int r = (int)__syscall_db(15, (unsigned)(lp >> 16), (unsigned)lp,
                              mode & 07777, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* chown(2) -- SYS_CHOWN(16).  A=path, X=uid, Y=gid.
 *
 * THREE ARGUMENTS, which is 2.11BSD's own note in the table it is numbered
 * from: "16 = chown; now 3 args".
 *
 * -1 IN EITHER FIELD LEAVES IT ALONE -- `chown f -1 20' changes the group and
 * not the owner -- and it is the SAME -1 the kernel's vattr uses for "not
 * set", so the two meanings coincide rather than needing a translation.
 *
 * IT DOES NOT FOLLOW THE FINAL SYMLINK.  Reno's chown resolves NOFOLLOW
 * (kern/vfs_syscalls.c:1204) where its chmod FOLLOWs, because a symlink does
 * have an owner.  POSIX later split that into chown/lchown; this is the
 * 4.3BSD behaviour, and chown(2)'s BUGS section says so. */
int chown(char *path, int uid, int gid)
{
    unsigned long lp = (unsigned long)path;
    int r = (int)__syscall_db(16, (unsigned)(lp >> 16), (unsigned)lp,
                              uid, gid);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* mount(2) -- SYS_MOUNT(21).  A = the offset of a four-word argument block:
 * [0] type [1] dir [2] flags [3] data.
 *
 * 4.3BSD-Reno's ARGUMENTS on 2.11BSD's number: `mount(type, dir, flags, data)'
 * (kern/vfs_syscalls.c), because the kernel has a type switch and 2.11BSD's
 * `smount(fspec, freg, flags)' has no way to name a type.  Four arguments do
 * not fit three registers, so they travel by reference, as sysctl's do.
 * _Sys_Mount's header carries the rest.
 *
 * `data' IS THE DEVICE PATH for MOUNT_UFS -- see ufs_mount's header for why it
 * is not Reno's `struct ufs_args'.
 *
 * THE BLOCK AND BOTH STRINGS SHARE ONE BANK, as link's and rename's paths do,
 * and the block is static so that bank is this program's data bank.
 *
 * THE MOUNT POINT MUST BE ABSOLUTE: the kernel starts the walk at the system
 * root.  mount(8) resolves what it is given before calling. */
/* {type, flags, dir, data} -- the two paths are FAR pointers (apple/fgx#438).
 * It was four bare ints, so the kernel read `dir' and `data' at 16-bit offsets
 * in the block's own bank; the block is this libc static in the data bank and
 * mount(8) passes its directory from argv, which apple/fgx#301 moved to the
 * kernel's bank-0 frame.  `mount /dev/sd1 /mnt' answered ENOENT for a device
 * that was there.  Offsets 0/2/4/8 are what _Sys_Mount reads. */
static struct _mount_blk {
    int   type;
    int   flags;
    char *dir;
    char *data;
} _mount_argblk;

int mount(int type, char *dir, int flags, char *data)
{
    unsigned long lp = (unsigned long)&_mount_argblk;
    int r;

    _mount_argblk.type  = type;
    _mount_argblk.flags = flags;
    _mount_argblk.dir   = dir;
    _mount_argblk.data  = data;
    r = (int)__syscall_db(21, (unsigned)(lp >> 16), (unsigned)lp, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* umount(2) -- SYS_UMOUNT(22).  A=spec.
 *
 * THE DEVICE, NOT THE DIRECTORY, which is 2.11BSD's interface (`umount' ->
 * `unmount1(uap->fspec)') and not Reno's.  umount(8) normalises whatever it
 * was given into `f_mntfromname' with getmntinfo(3) before calling, so this is
 * the shape the tool actually uses. */
int umount(char *spec)
{
    unsigned long lp = (unsigned long)spec;
    int r = (int)__syscall_db(22, (unsigned)(lp >> 16), (unsigned)lp, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* fchdir(2) -- NOT A SYSCALL HERE, and this says so properly rather than not
 * existing.  link()'s bargain above, for the same reason: 2.11BSD's chmod(1)
 * uses it to return to where its -R walk started (`fchdir(fcurdir)'), so a
 * verbatim port carries a reference to it whether the system has one or not.
 *
 * IT WAS A STUB, AND THE STUB SAID WHAT WOULD UNBLOCK IT: "chdir(2) here
 * resolves a PATH through namei, and fchdir starts from a DESCRIPTOR -- so it
 * needs the file table's vnode handed to vfs.mod's cwd table, which is a KFAR
 * slot and a seam entry of its own.  The far bank has 86 bytes free, which is
 * the whole reason this is a stub today."
 *
 * That figure was three campaigns old and the far bank now has over 9,000
 * free, so the reason had expired without anything saying so -- which is the
 * argument for a stub naming its blocker rather than only its absence.  UFS
 * 2.7 pays it: SYS_FCHDIR=115, far slot 68, and vfs_fchdir beside vfs_chdir
 * in the module that owns the cwd table. */
int fchdir(int fd)
{
    int r;

    r = (int)__syscall(115, fd, 0, 0);
    if (__syscall_c() == 0) { errno = r; return (-1); }
    return (0);
}

/* ftruncate(2): SYS_FTRUNCATE=103.  Sets the file's LENGTH: a shorter length
 * hides the tail from read(2) and stat(2), a longer one extends the file with
 * zeros, and the file offset is not moved.  ProDOS EOF is 24-bit, so a length
 * above 16 MB is rejected rather than silently wrapped.
 *
 * The blocks a shrink orphans are NOT returned to the volume until the file is
 * unlinked -- apple/fgx#68.  Length semantics are exact; free space is not. */
int ftruncate(int fd, long length)
{
    int r;

    if (length < 0 || length > 0xFFFFFFL) { errno = EINVAL; return -1; }
    r = (int)__syscall(103, fd & 0xFF, (unsigned)(length & 0xFFFFL),
                       (unsigned)((length >> 16) & 0xFFL));
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* truncate(2) by PATH.  No syscall of its own: open + ftruncate + close is the
 * same work the kernel would do, and doing it here keeps one length-setting
 * path in the kernel rather than two.  O_WRONLY because truncating is a write;
 * errno comes from whichever step failed. */
int truncate(char *path, long length)
{
    int fd, r, e;

    fd = open(path, O_WRONLY, 0);    /* no O_CREAT: no mode to give */
    if (fd < 0) return -1;
    r = ftruncate(fd, length);
    e = errno;
    close(fd);
    if (r < 0) errno = e;
    return r;
}

/* chdir(2): SYS_CHDIR=12.  Real libc entry (Stage B1) so the per-tool
 * chdir_ hand-asm stubs (jsh_stubs.s &c) can retire.  Passes the path's
 * full far pointer via _db, so it is bank-correct even when the path lives
 * outside DBR (the old asm stub assumed the DBR bank). */
int chdir(char *path)
{
    unsigned long lp = (unsigned long)path;
    int r = (int)__syscall_db(12, (unsigned)(lp >> 16), (unsigned)lp, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

long lseek(int fd, long off, int whence)
{
    unsigned r = __syscall(19, ((whence & 0xFF) << 8) | (fd & 0xFF),
                           (unsigned)off, (unsigned)(off >> 16));
    if (__syscall_c() == 0) { errno = (int)r; return -1L; }
    return (long)(((unsigned long)__syscall_y() << 16) | (unsigned long)r);
}

/* getwd(3) lives in lib/libc_c/getwd.c -- it is 2.11BSD's own, a tree walk
 * over opendir/readdir, and no longer a syscall.  SYS_GETCWD(42) is retired
 * with the per-task cwd string it read (apple/fgx#344).
 */

