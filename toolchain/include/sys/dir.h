/* FGX libc -- sys/dir.h.  4.2BSD-shape directory access (H1 ls port) over
 * SYS_LISTDIR(49).
 *
 * The kernel call is one-shot: it fills a caller buffer with the whole
 * directory as back-to-back NUL-terminated names (no seek/resume, silent
 * truncation when the buffer fills).  A DIR is a malloc'd block holding
 * {dd_loc, dd_size} plus the snapshot; opendir stages the path inside the
 * block and runs the call under the block's heap bank (__syscall_db), so
 * concurrent DIRs are independent.  Consequences, by design:
 *
 *   - Directory snapshot capped at __DIRBUF_MAX bytes of names (~2048/avg
 *     7-byte name about 250 entries); larger directories are silently
 *     truncated to what fits -- same ceiling shape as the kernel call.
 *   - readdir returns a pointer to a single static struct direct cell
 *     (classic BSD contract: the next readdir overwrites it).
 *
 * d_ino IS THE FILESYSTEM'S.  SYS_LISTDIR's records are `ino:2' then the
 * NUL-terminated name, and the call's return value is the bound -- there is no
 * terminator record.  It reported a synthesized 1 for every entry until
 * apple/fgx#358, which made getwd(3)'s upward walk -- it matches a level by
 * inode -- unable to name any level at all.  The classic
 * `if (dp->d_ino == 0) continue;` skip still works: a zero d_ino means the same
 * thing here as on disk (2.11BSD dir.h -- a free entry has d_ino set to 0).
 */
#ifndef _SYS_DIR_H
#define _SYS_DIR_H

/* MAXNAMLEN IS THE FILESYSTEM'S, AND THE FILESYSTEM IS UFS.  This said 15
 * with the comment "ProDOS name cap" from the H1 port until 2026-09-05, while
 * BOTH kernel headers -- src/kernel/vfs/dir.h:60 and fsparam.h:343 -- said 63,
 * which is upstream's own value (vendor/2.11BSD/usr/sys/h/dir.h:13).  Nothing
 * disagreed across a wire, SYS_LISTDIR returning bare NUL-terminated names
 * rather than struct directs; readdir simply stopped copying at 15, so
 * `dhclient.conf.sample' came back as `dhclient.conf.s' and ls(1) then stat'd
 * a name that is not there (apple/fgx#317).  The cell is one static struct in
 * libc, so the whole cost is 48 bytes of the data bank. */
#define MAXNAMLEN   63
#define __DIRBUF_MAX 2048           /* snapshot ceiling (names + NULs) */

struct direct {
    unsigned short d_ino;           /* the entry's inode; 0 = not live */
    short          d_namlen;
    char           d_name[MAXNAMLEN + 1];
};

#define DIRSIZ(dp)  (sizeof (struct direct))

typedef struct {
    int dd_fd;                      /* the directory, open O_RDONLY */
    int dd_loc;                     /* cursor into the snapshot */
    int dd_size;                    /* bytes the kernel wrote */
} DIR;

/* dd_fd EXISTS FOR dirfd(3), which 2.11BSD's ls(1) uses to fstat what it just
 * opened.  FGX's opendir is a SNAPSHOT -- SYS_LISTDIR copies the whole
 * directory into the handle -- so it does not otherwise need a descriptor, and
 * for a long time did not have one.  It keeps one now because a port is
 * entitled to ask; a read-only open of a directory is permitted here exactly
 * as it is upstream (vn_open refuses VDIR only for write).
 *
 * -1 IF THE OPEN FAILED, and opendir still succeeds in that case: the listing
 * came from the syscall, not from the descriptor, so a name that can be listed
 * but not opened (the synthesized device namespace, retired) still
 * enumerates. */
DIR *opendir(char *path);
int  dirfd(DIR *dirp);
struct direct *readdir(DIR *dirp);
int closedir(DIR *dirp);
void rewinddir(DIR *dirp);

#endif
