/* FGX-Origin: original -- FGX code.  Nothing here derives from the Regents'
 * work.
 */
/* fsynctest - does fsync(2) reach the filesystem?
 *
 * apple/fgx#355: it did not.  `Fs_Fsync' dispatched FOP_Flush into the ProDOS
 * FST, which answers EIO on a 2.11BSD volume, so every fsync of a regular file
 * failed -- and nothing on the image called fsync(2), so nothing said so.
 *
 * IT HOLDS THE DESCRIPTOR OPEN AND SLEEPS, and that is the whole design.  An
 * arm that only checks fsync's return value passes on a kernel that returns 0
 * and forces nothing -- MEASURED: mutating the seam call away left the first
 * cut of this test green.  What separates the two is the INODE ON THE PLATTER,
 * and the only thing that writes it apart from fsync is the last vrele, which
 * close(2) and exit(2) both trigger.  So this never closes: it writes,
 * fsyncs, says so, and sleeps.  Run backgrounded, the machine is stopped with
 * the file still open, and the manifest reads /root/fsy's SIZE out of the disk
 * image afterwards -- 64 if fsync forced the inode, 0 if it did not.
 *
 * The DATA is on disk either way, ufs_write bwriting every buffer before it
 * returns; the size in the inode is what is at stake.
 */
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>

char buf[64];

int main(argc, argv)
	int	argc;
	char	**argv;
{
	int fd, i, r;

	fd = open("/root/fsy", O_RDWR | O_CREAT | O_TRUNC, 0644);
	if (fd < 0) {
		printf("fsynctest: open: errno %d\n", errno);
		return 1;
	}
	for (i = 0; i < (int)sizeof(buf); i++)
		buf[i] = 'F';
	if (write(fd, buf, sizeof(buf)) != (int)sizeof(buf)) {
		printf("fsynctest: write: errno %d\n", errno);
		close(fd);
		return 1;
	}
	errno = 0;
	r = fsync(fd);
	printf("fsynctest: fsync=%d errno=%d\n", r, r < 0 ? errno : 0);

	/* An unopened descriptor must still be refused, so a "returns 0 for
	 * everything" kernel does not pass on the arm above alone. */
	errno = 0;
	r = fsync(99);
	printf("fsynctest: badfd=%d errno=%d\n", r, r < 0 ? errno : 0);

	/* AND NOW HOLD IT OPEN.  See the header: closing would write the inode
	 * back through vrele and the disk-size arm would pass either way.  The
	 * machine is stopped under us; the sleep only has to outlast the run. */
	printf("fsynctest: holding\n");
	sleep(120);
	return 0;
}
