/* FGX libc — sys/stat.h.  stat(2)/fstat(2) + struct stat.
 *
 * struct stat IS 2.11BSD's, field for field (vendor/2.11BSD/usr/sys/h/stat.h
 * :14-31) -- spares and all, because their POSITIONS are what put st_mtime and
 * st_blocks where upstream has them, and a port that reads either expects them
 * there.  It was a 32-byte subset until 2026-09-05; the ls port named the cost
 * when vendor's ls.c read st_flags.  It also mirrors the kernel's include/fs.s
 * layout (the STX_ fields Fs_Stat fills) and check_stat_layout.py holds the
 * two together.  Mode bits
 * are FGX's 16-bit packing (S_IFREG=0x8000, S_IFDIR=0x4000), NOT the classic
 * Unix octal; values come straight from fs.s.  ProDOS has no real uid/gid/ino
 * (kernel writes 0 / synthesized values).  Prototypes are K&R (unspecified
 * args) to match the port's call sites.
 */
#ifndef _SYS_STAT_H
#define _SYS_STAT_H

/* st_rdev IS PRESENT AND IS NODEV UNTIL stat(2) GOES THROUGH THE VFS.
 * 2.11BSD's struct carries it between st_gid and st_size (usr/sys/h/stat.h)
 * and this one now does too, so a port that names the field compiles.  What it
 * CANNOT yet be is a real device number: SYS_STAT walks ProDOS (Fs_Stat) and
 * never reaches a vnode, so nothing on that path knows one -- the VFS layer
 * does (struct vattr's va_rdev, filled by ufs_getattr since UFS 1.13a), and
 * stat(2) starts asking it at the root swap.
 *
 * `short' RATHER THAN dev_t, matching st_dev two lines up: this header
 * deliberately includes nothing and spells every field in a built-in type, so
 * naming dev_t here would drag <sys/types.h> into every translation unit that
 * stats a file.  Same width either way.
 *
 * NODEV RATHER THAN ZERO, and the difference is not cosmetic.  A ProDOS file
 * has no device number, and zero is a plausible one: 2.11BSD's fsck decides
 * whether it is checking the ROOT filesystem with
 *
 *     if (rootdev == statb.st_rdev) hotroot++;
 *
 * where rootdev came from stat("/").  With both fields zero that test is TRUE
 * for every volume, and a false hotroot makes fsck refuse its scratch file and
 * demand a reboot after any repair.  NODEV says "not a special file", which is
 * the truthful answer for everything this path can see, and the comparison
 * then fails as it should. */
struct stat {
    short           st_dev;
    unsigned short  st_ino;
    unsigned short  st_mode;
    short           st_nlink;
    short           st_uid;
    short           st_gid;
    short           st_rdev;            /* device a special file names; NODEV */
    long            st_size;
    long            st_atime;
    int             st_spare1;
    long            st_mtime;
    int             st_spare2;
    long            st_ctime;
    int             st_spare3;
    long            st_blksize;
    long            st_blocks;
    unsigned short  st_flags;           /* uappnd, uchg, schg...  FGX sets none */
    unsigned short  st_spare4[3];
};

/* File type bits (fs.s packing) and the type-field mask.  The type lives in the
 * top nibble; FGX only ever synthesizes REG/DIR (and CHR for a tty stat), but
 * the full set is defined so ports can compare (S_IFMT-masked) mode values --
 * classic-Unix nibble values, scaled to the 16-bit packing. */
#define S_IFMT          0xF000          /* type-field mask (top nibble) */
#define S_IFREG         0x8000          /* regular file */
#define S_IFDIR         0x4000          /* directory */
#define S_IFCHR         0x2000          /* character device (tty) */
#define S_IFBLK         0x6000          /* block device */
#define S_IFIFO         0x1000          /* named pipe (FIFO) */
#define S_IFLNK         0xA000          /* symbolic link */
#define S_IFSOCK        0xC000          /* socket */

/* Type-test macros (POSIX): (mode & S_IFMT) == S_IFxxx. */
#define S_ISREG(m)      (((m) & S_IFMT) == S_IFREG)
#define S_ISDIR(m)      (((m) & S_IFMT) == S_IFDIR)
#define S_ISCHR(m)      (((m) & S_IFMT) == S_IFCHR)
#define S_ISBLK(m)      (((m) & S_IFMT) == S_IFBLK)
#define S_ISFIFO(m)     (((m) & S_IFMT) == S_IFIFO)
#define S_ISLNK(m)      (((m) & S_IFMT) == S_IFLNK)
#define S_ISSOCK(m)     (((m) & S_IFMT) == S_IFSOCK)

/* Permission bits (fs.s: owner read/write). */
/* THE FULL PERMISSION SET, and it was two bits until 2026-09-05.  Only
 * S_IRUSR and S_IWUSR existed, because the kernel's stat image had only a
 * ProDOS access byte to build a mode from and a single write-enable bit in it
 * carried all the information there was.  The kernel reports a real 12-bit
 * mode now (the STX_ cutover), so the names it needs exist.
 *
 * CLASSIC OCTAL VALUES, unlike the S_IF* type bits above: 2.11BSD's ls shifts
 * one triple to reach the next (`S_IREAD>>3', usr/bin/ls/ls.c:617), which only
 * works if the nine bits are the classic contiguous ones. */
#define S_ISUID         04000           /* set user id on execution */
#define S_ISGID         02000           /* set group id on execution */
#define S_ISVTX         01000           /* save swapped text after use */
#define S_IRWXU         00700
#define S_IRUSR         00400
#define S_IWUSR         00200
#define S_IXUSR         00100
#define S_IRWXG         00070
#define S_IRGRP         00040
#define S_IWGRP         00020
#define S_IXGRP         00010
#define S_IRWXO         00007
#define S_IROTH         00004
#define S_IWOTH         00002
#define S_IXOTH         00001
#define S_IREAD         00400           /* historical alias of S_IRUSR */
#define S_IWRITE        00200           /* historical alias of S_IWUSR */
#define S_IEXEC         00100           /* historical alias of S_IXUSR */

/* st_flags, verbatim from 2.11BSD's h/stat.h:82-91.  NOTHING IN FGX SETS ONE
 * -- there is no chflags(2) -- so every file reads 0 and `ls -lo' prints a
 * column of `-'.  The names exist because a port that reads the field expects
 * to be able to name its bits, and because the FIELD is in the struct: it is
 * 2.11BSD's struct entire, so a name for each bit costs nothing and its
 * absence would be the next thing a port trips on. */
#define UF_SETTABLE     0x00ff          /* mask of owner changeable flags */
#define UF_NODUMP       0x0001          /* do not dump file */
#define UF_IMMUTABLE    0x0002          /* file may not be changed */
#define UF_APPEND       0x0004          /* writes to file may only append */
#define SF_SETTABLE     0xff00          /* mask of superuser changeable flags */
#define SF_ARCHIVED     0x0100          /* file is archived */
#define SF_IMMUTABLE    0x0200          /* file may not be changed */
#define SF_APPEND       0x0400          /* writes to file may only append */

/* chmod(2): set the nine permission bits plus setuid/setgid/sticky.  The IFMT
 * bits are not settable and are masked off; see chmod(2). */
int chmod(char *path, int mode);

int stat(char *path, struct stat *st);
int fstat(int fd, struct stat *st);
int lstat(char *path, struct stat *st);  /* SYS_LSTAT: a symlink's own inode */

#endif /* _SYS_STAT_H */
