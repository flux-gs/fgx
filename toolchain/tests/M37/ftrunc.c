/* ftrunc: ftruncate(2)/truncate(2).  FGX-only (MAME oracle): real files under
 * /tmp on the boot disk.
 *
 * FGX had no way to SHORTEN a file.  A program that rewrites one in place --
 * an editor's scratch buffer, a log that is reset, a cut/paste buffer -- could
 * only recreate it, losing the fd and the offset.  novi(1) hit it twice.
 *
 * Checks: a shrink is visible to read(2) AND to a fresh open (so the directory
 * entry was committed, not just the FCB); the file offset is NOT moved, which
 * is the half of POSIX that is easy to get wrong and invisible in casual use;
 * a grow extends with zeros; truncate(2) by path agrees with ftruncate(2) by
 * fd; and a descriptor open the WRONG WAY answers EINVAL.
 *
 * Block reclamation is deliberately NOT asserted -- a shrink leaves the
 * orphaned blocks attached to the file until unlink (apple/fgx#68), and a test
 * claiming otherwise would be asserting a behaviour FGX does not have.
 *
 * 8 + 8 + 6 + 6 + 8 + 6 = 42. */
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>

extern int errno;

static long
sizeof_path(char *path)
{
	struct stat st;

	if (stat(path, &st) < 0) return -1L;
	return (long)st.st_size;
}

int
main()
{
	struct stat st;
	char buf[32];
	int fd, n, r = 0;
	long pos;

	/* O_RDWR AND NOT creat(), WHICH IS THE POINT OF THIS LINE.  creat(2) is
	 * open(path, O_WRONLY|O_CREAT|O_TRUNC, mode) BY DEFINITION -- libc's
	 * creat says so and 4.3BSD-Reno's is the same -- so the descriptor it
	 * returns is WRITE-ONLY and the read-back arm below must fail EBADF on
	 * any faithful system.  It did not on a ProDOS root, where the FCB was
	 * readable regardless, so this fixture scored 42 there and 36 the first
	 * time the runtime oracle ran against a 2.11BSD one (apple/fgx#342).
	 * The subject here is ftruncate, not creat's mode, so the fixture asks
	 * for the descriptor it actually needs. */
	fd = open("/tmp/ftrc", O_RDWR | O_CREAT | O_TRUNC, 0644);
	if (fd < 0) return 1;
	if (write(fd, "abcdefghij", 10) != 10) return 2;

	/* Shrink to 4.  The offset stays at 10 -- POSIX is explicit that
	 * ftruncate does not seek -- so lseek(0,1) must still report 10. */
	if (ftruncate(fd, 4L) == 0) r += 8;
	pos = lseek(fd, 0L, 1);
	if (pos == 10L) r += 8;

	if (lseek(fd, 0L, 0) == 0L) {
		n = read(fd, buf, 32);
		if (n == 4 && buf[0] == 'a' && buf[3] == 'd') r += 6;
	}
	close(fd);

	/* A fresh open sees it too: the length reached the DIRECTORY ENTRY,
	 * not just the in-core FCB.  Without the commit this reads 10. */
	if (sizeof_path("/tmp/ftrc") == 4L) r += 6;

	/* Grow to 9: the gap reads as zeros. */
	fd = open("/tmp/ftrc", O_RDWR);
	if (fd >= 0) {
		if (ftruncate(fd, 9L) == 0 &&
		    lseek(fd, 0L, 0) == 0L &&
		    read(fd, buf, 32) == 9 &&
		    buf[3] == 'd' && buf[4] == 0 && buf[8] == 0)
			r += 8;
		close(fd);
	}

	/* truncate(2) by path, and a READ-ONLY descriptor is refused.
	 *
	 * EINVAL AND NOT EBADF, which is upstream's split: 4.3BSD-Reno's
	 * ftruncate answers EBADF through getvnode for a descriptor that is not
	 * open at all, and `if ((fp->f_flag & FWRITE) == 0) RETURN (EINVAL)' for
	 * one that is open without write (kern/vfs_syscalls.c:1359-1362).  Two
	 * faults, two errnos.
	 *
	 * A NON-REGULAR fd IS NOT THE CHECK, and asking for one here scored this
	 * fixture 36.  A device file on a mounted filesystem wears spec_inodeops,
	 * whose setattr slot is ufs_setattr (ufs/ufs_vnops.c:133); ufs_setattr
	 * refuses only VDIR and otherwise calls itrunc, which returns 0 for any
	 * i_size <= length (ufs/ufs_inode.c:394).  A device inode is zero-length,
	 * so ftruncate on /dev/console SUCCEEDS on upstream and here. */
	if (truncate("/tmp/ftrc", 2L) == 0 && sizeof_path("/tmp/ftrc") == 2L) {
		fd = open("/tmp/ftrc", O_RDONLY);
		if (fd >= 0) {
			errno = 0;
			if (ftruncate(fd, 0L) < 0 && errno == EINVAL) r += 6;
			close(fd);
		}
	}

	unlink("/tmp/ftrc");
	return r;                                /* 42 */
}
