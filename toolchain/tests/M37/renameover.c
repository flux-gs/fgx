/* renameover: rename(2) REPLACES an existing target in the same directory.
 * FGX-only (MAME oracle): real files under /tmp on the boot disk.
 *
 * POSIX rename(2) replaces the target atomically, and that is what makes the
 * standard safe-save idiom work: write a temp file beside the original, rename
 * it over the original, which is how novi(1) saves.
 *
 * Checks, in order: the replace succeeds; the target now holds the SOURCE's
 * bytes (not the ones it had); the source name is gone; and a rename ACROSS
 * directories inside one filesystem succeeds too.  EXDEV is a check on the two
 * ends' MOUNTS -- `fvp->v_mount != tdvp->v_mount', 4.3BSD-Reno
 * kern/vfs_syscalls.c:1450 -- and this volume is the only one mounted, so no
 * rename on it can reach that answer.
 *
 * 12 + 12 + 8 + 10 = 42. */
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>

static int
put(char *path, char *s, int n)
{
	int fd = creat(path, 0644);

	if (fd < 0) return -1;
	if (write(fd, s, n) != n) { close(fd); return -1; }
	close(fd);
	return 0;
}

int
main()
{
	char buf[8];
	int fd, n, r = 0;

	if (put("/tmp/rovsrc", "NEW", 3) < 0) return 1;
	if (put("/tmp/rovdst", "oldold", 6) < 0) return 2;

	if (rename("/tmp/rovsrc", "/tmp/rovdst") == 0) r += 12;

	fd = open("/tmp/rovdst", O_RDONLY);
	if (fd >= 0) {
		n = read(fd, buf, 6);
		close(fd);
		/* 3 bytes, "NEW" -- if the old file survived we would read 6
		 * bytes of "oldold" instead. */
		if (n == 3 && buf[0] == 'N' && buf[1] == 'E' && buf[2] == 'W')
			r += 12;
	}

	fd = open("/tmp/rovsrc", O_RDONLY);          /* source must be gone */
	if (fd < 0) r += 8;
	else close(fd);

	/* Across directories, one filesystem: a plain rename.  mv(1) has no
	 * copy+unlink fallback to take here, and this arm is what says the
	 * replace above is not scoped to a single directory. */
	if (put("/tmp/rovsrc", "X", 1) == 0) {
		if (rename("/tmp/rovsrc", "/rovdst2") == 0) r += 10;
		unlink("/rovdst2");
		unlink("/tmp/rovsrc");
	}

	unlink("/tmp/rovdst");
	return r;                                    /* 42 */
}
