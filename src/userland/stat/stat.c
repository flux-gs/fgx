/* stat(1) -- display file status.  FGX-native C (no vendored BSD source:
 * stat(1) postdates the vendored trees).  Prints the stat(2) size, blocks,
 * file type, inode number and modification time, and the mode as ls(1)
 * prints it, from strmode(3): type, rwx for owner, group and other, and the
 * setuid, setgid and sticky bits.
 *
 *   File: /etc/motd
 *   Size: 1602        Blocks: 4        regular file
 *   Mode: -rw-r--r--  Inode: 291
 * Modify: Tue Jun 30 17:30:00 2026
 *
 * "Inode" is st_ino, the UFS inode number (same as ls -i).
 */
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static struct stat sb;

int statone();

int main(argc, argv)
	int	argc;
	char	**argv;
{
	int i, rc;

	if (argc < 2) {
		fputs("usage: stat file ...\n", stderr);
		exit(1);
	}
	rc = 0;
	for (i = 1; i < argc; i++) {
		if (statone(argv[i]) != 0)
			rc = 1;
		if (i + 1 < argc)
			putchar('\n');
	}
	exit(rc);
}

int statone(path)
	char	*path;
{
	char	mode[12];		/* strmode(3) writes 11 and a NUL */
	char	*type;

	if (stat(path, &sb) != 0) {
		fprintf(stderr, "stat: %s: ", path);
		perror("");
		return 1;
	}

	if ((sb.st_mode & S_IFMT) == S_IFDIR)
		type = "directory";
	else if ((sb.st_mode & S_IFMT) == S_IFREG)
		type = "regular file";
	else
		type = "other";

	strmode(sb.st_mode, mode);
	mode[10] = 0;			/* strmode's trailing ACL column */

	printf("  File: %s\n", path);
	printf("  Size: %-10ld  Blocks: %-6ld  %s\n",
	       sb.st_size, sb.st_blocks, type);
	printf("  Mode: %s  Inode: %u\n", mode, sb.st_ino);
	printf("Modify: %s", ctime(&sb.st_mtime));
	return 0;
}
