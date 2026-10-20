/* mountupd - mount(2)'s MNT_UPDATE arm: read-only to read-write in place.
 *
 * FGX-Provenance: none
 *
 * `mount -u' is what stands between a root fsck'd read-only at boot and a
 * machine anyone can write to, so this probes the transition itself rather
 * than the tool: mount(8)'s own update path is 2.11BSD's and unchanged, and
 * what is new is the kernel arm underneath it.
 *
 * THE THINGS IT DISCRIMINATES, and each would pass without the others:
 *
 *   MUTYPE    a type with no vfssw[] row is ENODEV, both the null row
 *             (MOUNT_NONE) and one past the table's end, and neither refusal
 *             leaves /mnt covered or held: the mount straight after it has to
 *             succeed.  That UFS mount is the positive control -- it is the
 *             row the table DOES have.
 *   MUCREAT   a read-only mount REFUSES a create.  Without this the rest is
 *             vacuous -- a mount that was writable all along would "become"
 *             writable and every later arm would pass.
 *   MUUPD     the update returns 0.
 *   MUWROTE   a create SUCCEEDS afterwards.
 *   MUPERSIST the file is still there, with its bytes, AFTER an unmount and a
 *             fresh mount.  This is the assertion and MUWROTE is not: reading
 *             back through the mount that created it answers from the in-core
 *             inode, so a write that never reached the platter reads correctly
 *             and corrupts nothing.  Unmounting drops the inode; mounting
 *             again is the only way to ask the disk.
 *   MURO      read-write to read-only is REFUSED.  Both trees refuse it and
 *             say why -- 2.11BSD's ufs_mount.c is blunt about it, "besides
 *             which most programs get very upset at having access yanked out
 *             from under them" -- so a port that allowed it would be inventing
 *             an interface, not completing one.
 *
 * /dev/sd1 is the scratch spindle the suite attaches as an extra hard disk,
 * and /mnt an empty directory on the boot volume.  ufsmount covers the plain
 * mount and unmount on the same pair.
 */
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/mount.h>

static int wrfile(path)
char *path;
{
	int fd;

	fd = creat(path, 0644);
	if (fd < 0)
		return (-1);
	if (write(fd, "updated", 7) != 7) {
		(void)close(fd);
		return (-1);
	}
	return (close(fd));
}

static int rdfile(path)
char *path;
{
	int  fd;
	char buf[8];

	fd = open(path, O_RDONLY);
	if (fd < 0)
		return (-1);
	buf[0] = '\0';
	if (read(fd, buf, 7) != 7) {
		(void)close(fd);
		return (-1);
	}
	(void)close(fd);
	buf[7] = '\0';
	return (strcmp(buf, "updated") == 0 ? 0 : -1);
}

int
main()
{
	printf("MUSTART\n");

	errno = 0;
	if (mount(MOUNT_NONE, "/mnt", MNT_RDONLY, "/dev/sd1") == 0 ||
	    errno != ENODEV) {
		printf("MUNOTYPE none errno=%d\n", errno);
		return (12);
	}
	errno = 0;
	if (mount(MOUNT_MAXTYPE + 1, "/mnt", MNT_RDONLY, "/dev/sd1") == 0 ||
	    errno != ENODEV) {
		printf("MUNOTYPE max errno=%d\n", errno);
		return (13);
	}
	printf("MUTYPE\n");

	if (mount(MOUNT_UFS, "/mnt", MNT_RDONLY, "/dev/sd1") < 0) {
		printf("MUNOMOUNT errno=%d\n", errno);
		return (1);
	}

	errno = 0;
	if (wrfile("/mnt/updprobe") == 0) {
		printf("MUNOTRO\n");    /* writable while mounted read-only:
					 * every arm below would be vacuous */
		return (2);
	}
	if (errno != EROFS) {
		printf("MUROERR errno=%d\n", errno);
		return (3);
	}
	printf("MUCREAT\n");

	if (mount(MOUNT_UFS, "/mnt", MNT_UPDATE, "/dev/sd1") < 0) {
		printf("MUNOUPD errno=%d\n", errno);
		return (4);
	}
	printf("MUUPD\n");

	if (wrfile("/mnt/updprobe") < 0) {
		printf("MUNOWRITE errno=%d\n", errno);
		return (5);
	}
	printf("MUWROTE\n");

	errno = 0;
	if (mount(MOUNT_UFS, "/mnt", MNT_UPDATE | MNT_RDONLY, "/dev/sd1") == 0) {
		printf("MUNORO\n");     /* read-write to read-only ALLOWED */
		return (6);
	}
	if (errno != ENOTSUP) {
		printf("MUROERRNO=%d\n", errno);
		return (7);
	}
	printf("MURO\n");

	/* THE ROUND TRIP IS THE ASSERTION, not the write above.  Reading the
	 * file back through the mount that created it proves nothing: the
	 * inode is in core either way, so a write that never reached the
	 * platter -- which is exactly what iupdat's sb_ronly guard causes when
	 * the update does not clear it -- reads back correctly and corrupts
	 * nothing.  Unmounting drops the in-core inode; mounting again is the
	 * only way to ask the disk. */
	if (umount("/dev/sd1") < 0) {
		printf("MUNOUMNT errno=%d\n", errno);
		return (8);
	}
	if (mount(MOUNT_UFS, "/mnt", 0, "/dev/sd1") < 0) {
		printf("MUNOREMOUNT errno=%d\n", errno);
		return (9);
	}
	if (rdfile("/mnt/updprobe") < 0) {
		printf("MUNOPERSIST errno=%d\n", errno);
		return (10);
	}
	printf("MUPERSIST\n");

	if (umount("/dev/sd1") < 0) {
		printf("MUNOUMNT2 errno=%d\n", errno);
		return (11);
	}
	printf("MUDONE\n");
	return (0);
}
