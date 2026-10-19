/* pdmount - a ProDOS volume mounts, is counted, holds and releases its root.
 *
 * FGX-Provenance: none
 *
 * The node layer, driven through mount(2) directly so each errno is the
 * kernel's.  /dev/sd1 is a ProDOS volume cadius built (disk/pdscratch.po,
 * tools/mkpdscratch.py), and /mnt an empty directory on the root.
 *
 * `pdmount -s file ...' is the other half: it reads each file through
 * read(2) in 700-byte pieces, so every transfer starts at a different offset
 * in a block, and prints its size, 2.11BSD sum(1)'s checksum, its st_mtime and
 * its permission bits -- or the errno, for a name the lookup refused, an open
 * the permissions refused, or a read that failed.  `pdmount -U file ...' does
 * the same as uid 1 and gid 1, printing PDUSUM, so the access byte's mapping is
 * asked of a caller the super-user rule does not wave through.
 *
 * `pdmount -p file offset length seed' writes `length' bytes of a pattern
 * at `offset' in 700-byte pieces and prints PDWR with the bytes written and
 * the errno, if any; -A appends them instead, and -P writes as uid 1.  Byte
 * `pos' of a run is ((pos * 31 + seed * 17) ^ (pos >> 7)) & 255, pos counted
 * from the start of the file, which tools/mame_test/pdwrite_check.py
 * replays.  `pdmount -c name ...' (-K as uid 1) creates, `-d name ...' makes
 * directories, and `-n prefix count' creates until it fails; `-r name ...'
 * (-J as uid 1) unlinks and `-D name ...' removes directories; each prints the
 * errno.  `-O name' opens a file, unlinks it, then writes 5000 bytes of the
 * pattern (seed 30) through the descriptor and reads them back: PDOU prints
 * how far it got, the errno reopening the name got, and the bytes that
 * differed.  `-M from to' renames and prints PDMV; `-T name length' opens a
 * file for writing and ftruncate(2)s it, printing PDTR.  The manifest's sums
 * come from the
 * bytes cadius was handed (tools/mkpdscratch.py --sums), not from cadius.
 *
 * `pdmount -w dir' (-W also reads) walks a whole tree for a volume nothing
 * here built, by chdir as du(1) does: every entry's d_ino must equal its
 * st_ino, every "." and ".." must equal the directory's and its parent's, a
 * climb back through ".." must land where it left, and no inode number may
 * repeat.  One PDWALK line totals it, after the first five disagreements; with
 * -W a PDWTIME line totals the low 16 bits of every entry's st_mtime.
 *
 * WHAT EACH MARKER DISCRIMINATES:
 *
 *   PDRW      a WRITABLE mount(2) succeeds and unmounts: the kernel writes
 *             ProDOS, and only mount_prodos(8) keeps a mount read-only
 *             without `-o write'.
 *   PDBUSYDEV the root's own device is refused with EBUSY: a device that
 *             already carries a mount, of any type, is not read.
 *   PDMOUNT   a read-only mount succeeds.
 *   PDSTAT    statfs(2) reports type 10 and the volume's block counts, which
 *             the manifest compares against an independent count of the
 *             image's bitmap -- so the numbers are the volume's, not the
 *             filesystem's own idea of it.
 *   PDINO     the root's inode number is its key block, 2, and is
 *             the same before and after the crossings below: every walk into
 *             the mount reached a node with the root's identity.
 *   PDIDENT   TWO WALKS TO ONE LOCATION REACH ONE NODE, which the inode number
 *             above cannot show -- it is read from the volume, so a hash that
 *             built a new node per walk would print 2 too.  mount(2) refuses
 *             to cover a directory whose use count is not 1, and asks that
 *             BEFORE it looks the type up: with the root held as the working
 *             directory, a walk to /mnt that reaches the SAME node sees a
 *             count of 2 and answers EBUSY; one that built a second node sees
 *             1 and goes on to MOUNT_NONE's ENODEV.  The same call from / is
 *             the positive control, and must answer ENODEV.
 *   PDHOLD    a working directory inside the mount keeps it busy: the root
 *             node's reference is real.  Taken after forty crossings in and
 *             out, more than the vnode pool holds, so a crossing that leaked
 *             a reference or a node would have run the pool dry first.
 *   PDREL     leaving it releases that reference, and unmount succeeds.
 *   PDCYCLE   twenty mount/cross/unmount cycles, more than the mount pool's
 *             fourteen slots: a slot, a device reference or a hashed node
 *             that an unmount failed to give back runs out here.
 */
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/dir.h>

extern int ftruncate();

static int crossings(n)
int n;
{
	int i;

	for (i = 0; i < n; i++) {
		if (chdir("/mnt") < 0)
			return (-1);
		if (chdir("/") < 0)
			return (-1);
	}
	return (0);
}

static void sums(argc, argv, tag)
int argc;
char **argv;
char *tag;
{
	static char buf[700];
	struct stat st;
	long size;
	unsigned sum;
	int fd, n, i;

	for (; argc > 0; argc--, argv++) {
		if (stat(*argv, &st) < 0 || (fd = open(*argv, O_RDONLY)) < 0) {
			printf("%s %s errno=%d\n", tag, *argv, errno);
			continue;
		}
		size = 0L;
		sum = 0;
		while ((n = read(fd, buf, sizeof buf)) > 0) {
			size += n;
			for (i = 0; i < n; i++) {
				sum = (sum & 1) ? (sum >> 1) + 0x8000 : sum >> 1;
				sum += (unsigned char)buf[i];
			}
		}
		if (n < 0)
			printf("%s %s read errno=%d t=%ld m=%o\n", tag, *argv, errno,
			    (long)st.st_mtime, st.st_mode & 07777);
		else
			printf("%s %s %ld %u t=%ld m=%o\n", tag, *argv, size, sum,
			    (long)st.st_mtime, st.st_mode & 07777);
		close(fd);
	}
}

static void pwrite_run(argc, argv)
int argc;
char **argv;
{
	static char buf[700];
	long off, len, pos, done;
	int fd, n, i, seed, mode;

	if (argc != 6) {
		printf("PDWR usage\n");
		return;
	}
	if (argv[1][1] == 'P' && (setgid(1) < 0 || setuid(1) < 0)) {
		printf("PDWR setuid errno=%d\n", errno);
		return;
	}
	off  = atol(argv[3]);
	len  = atol(argv[4]);
	seed = atoi(argv[5]);
	mode = O_WRONLY;
	if (argv[1][1] == 'A')
		mode |= O_APPEND;
	errno = 0;
	done = 0L;
	if ((fd = open(argv[2], mode)) < 0) {
		printf("PDWR %s open errno=%d\n", argv[2], errno);
		return;
	}
	if (argv[1][1] == 'A')
		off = lseek(fd, 0L, 2);
	else if (lseek(fd, off, 0) != off) {
		printf("PDWR %s seek errno=%d\n", argv[2], errno);
		close(fd);
		return;
	}
	while (done < len) {
		n = (len - done > (long)sizeof buf) ? (int)sizeof buf :
		    (int)(len - done);
		for (i = 0; i < n; i++) {
			pos = off + done + (long)i;
			buf[i] = (char)(((pos * 31L + (long)seed * 17L) ^
			    (pos >> 7)) & 255L);
		}
		/* A SHORT WRITE IS NOT THE END: write(2) returns the bytes it
		 * moved, and the call after it reports why it could move no
		 * more. */
		if ((i = write(fd, buf, n)) <= 0)
			break;
		done += i;
	}
	if (done == len)
		errno = 0;
	printf("PDWR %s %ld errno=%d\n", argv[2], done, errno);
	close(fd);
}

/* unlinked -- `-O name': a file unlinked while open keeps working. */
static void unlinked(name)
char *name;
{
	static char wb[700], rb[700];
	long pos;
	int fd, gone, bad, i, k;

	errno = 0;
	if ((fd = open(name, O_RDWR)) < 0 || unlink(name) < 0) {
		printf("PDOU %s errno=%d\n", name, errno);
		return;
	}
	gone = 0;
	if ((i = open(name, O_RDONLY)) < 0)
		gone = errno;
	else
		close(i);
	for (pos = 0L; pos < 5000L; pos += k) {
		k = (5000L - pos > 700L) ? 700 : (int)(5000L - pos);
		for (i = 0; i < k; i++)
			wb[i] = (char)((((pos + i) * 31L + 30L * 17L) ^
			    ((pos + i) >> 7)) & 255L);
		if (write(fd, wb, k) != k)
			break;
	}
	bad = 0;
	if (lseek(fd, 0L, 0) == 0L)
		for (pos = 0L; pos < 5000L; pos += k) {
			k = (5000L - pos > 700L) ? 700 : (int)(5000L - pos);
			if (read(fd, rb, k) != k)
				break;
			for (i = 0; i < k; i++)
				if (rb[i] != (char)((((pos + i) * 31L + 30L * 17L) ^
				    ((pos + i) >> 7)) & 255L))
					bad++;
		}
	printf("PDOU %s %ld gone=%d bad=%d\n", name, pos, gone, bad);
	close(fd);
}

/* creates -- `-c name ...' creates each name, O_EXCL, and prints PDCR with the
 * errno; -K does it as uid 1 and gid 1; `-d name ...' makes each a directory
 * and prints PDMK.  `-n prefix count' creates prefix0, prefix1, ... until
 * `count' or the first failure, and prints PDCN with how many it made. */
static void creates(argc, argv)
int argc;
char **argv;
{
	static char nm[32];
	int fd, i, n, op;

	op = argv[1][1];
	if (op == 'M' || op == 'T') {
		errno = 0;
		if (argc != 4)
			fd = -1;
		else if (op == 'M')
			fd = rename(argv[2], argv[3]);
		else if ((fd = open(argv[2], O_WRONLY)) >= 0) {
			i = ftruncate(fd, atol(argv[3]));
			close(fd);
			fd = i;
		}
		printf("%s %s %s errno=%d\n", op == 'M' ? "PDMV" : "PDTR", argv[2],
		    argc == 4 ? argv[3] : "usage", fd < 0 ? errno : 0);
		return;
	}
	if (op == 'O') {
		unlinked(argv[2]);
		return;
	}
	if ((op == 'K' || op == 'J') && (setgid(1) < 0 || setuid(1) < 0)) {
		printf("PDCR setuid errno=%d\n", errno);
		return;
	}
	if (op == 'n') {
		n = (argc == 4) ? atoi(argv[3]) : 0;
		errno = 0;
		for (i = 0; i < n; i++) {
			sprintf(nm, "%s%d", argv[2], i);
			if ((fd = open(nm, O_WRONLY | O_CREAT | O_EXCL, 0644)) < 0)
				break;
			close(fd);
		}
		printf("PDCN %s %d errno=%d\n", argc == 4 ? argv[2] : "usage", i,
		    i < n ? errno : 0);
		return;
	}
	for (argc -= 2, argv += 2; argc > 0; argc--, argv++) {
		errno = 0;
		if (op == 'd')
			fd = mkdir(*argv, 0755);
		else if (op == 'r' || op == 'J')
			fd = unlink(*argv);
		else if (op == 'D')
			fd = rmdir(*argv);
		else if ((fd = open(*argv, O_WRONLY | O_CREAT | O_EXCL, 0644)) >= 0)
			fd = close(fd);
		printf("%s %s errno=%d\n", op == 'd' ? "PDMK" :
		    (op == 'r' || op == 'J') ? "PDRM" : op == 'D' ? "PDRD" : "PDCR",
		    *argv, fd < 0 ? errno : 0);
	}
}

static char path[256];		/* for messages only; the walk uses chdir */
static unsigned char seen[8192];
static long wdirs, wfiles, wbytes, wsum, wbad, wdup, wnotsup, wshort, wtime;
static int wread;

static void bad(name, what, a, b)
char *name, *what;
long a, b;
{
	if (++wbad <= 5)
		printf("PDWBAD %s/%s %s %ld %ld\n", path, name, what, a, b);
}

static void mark(name, ino)
char *name;
unsigned ino;
{
	if (seen[ino >> 3] & (1 << (ino & 7))) {
		if (++wdup <= 5)
			printf("PDWDUP %s/%s %u\n", path, name, ino);
	}
	seen[ino >> 3] |= 1 << (ino & 7);
}

static void readsum(name, size)
char *name;
long size;
{
	static char buf[700];
	long got;
	unsigned sum;
	int fd, n, i;

	if ((fd = open(name, O_RDONLY)) < 0) {
		bad(name, "open", (long)errno, 0L);
		return;
	}
	got = 0L;
	sum = 0;
	while ((n = read(fd, buf, sizeof buf)) > 0) {
		got += n;
		for (i = 0; i < n; i++) {
			sum = (sum & 1) ? (sum >> 1) + 0x8000 : sum >> 1;
			sum += (unsigned char)buf[i];
		}
	}
	close(fd);
	if (n < 0 && errno == ENOTSUP && got == 0L)
		wnotsup++;
	else if (n < 0)
		bad(name, "read", (long)errno, got);
	else if (got != size) {
		wshort++;
		bad(name, "size", size, got);
	} else
		wsum += sum;
}

/* walk -- the working directory, whose inode is ino and whose parent's is
 * pino.  Names are relative, so no path the walk builds is longer than one
 * ProDOS name. */
static void walk(ino, pino)
unsigned ino, pino;
{
	struct direct *dp;
	struct stat st;
	DIR *d;
	int len;

	if ((d = opendir(".")) == (DIR *)0) {
		bad(".", "opendir", (long)errno, 0L);
		return;
	}
	while ((dp = readdir(d)) != (struct direct *)0) {
		if (strcmp(dp->d_name, ".") == 0) {
			if (dp->d_ino != ino)
				bad(".", "d_ino", (long)dp->d_ino, (long)ino);
			continue;
		}
		if (strcmp(dp->d_name, "..") == 0) {
			if (dp->d_ino != pino)
				bad("..", "d_ino", (long)dp->d_ino, (long)pino);
			continue;
		}
		if (stat(dp->d_name, &st) < 0) {
			bad(dp->d_name, "stat", (long)errno, 0L);
			continue;
		}
		if ((unsigned)st.st_ino != dp->d_ino)
			bad(dp->d_name, "st_ino", (long)dp->d_ino, (long)st.st_ino);
		mark(dp->d_name, (unsigned)st.st_ino);
		wtime += (long)((unsigned)st.st_mtime);
		if ((st.st_mode & S_IFMT) != S_IFDIR) {
			wfiles++;
			wbytes += st.st_size;
			if (wread)
				readsum(dp->d_name, st.st_size);
			continue;
		}
		wdirs++;
		if (chdir(dp->d_name) < 0) {
			bad(dp->d_name, "chdir", (long)errno, 0L);
			continue;
		}
		len = strlen(path);
		if (len + 1 + strlen(dp->d_name) < sizeof path) {
			path[len] = '/';
			strcpy(path + len + 1, dp->d_name);
		}
		walk((unsigned)st.st_ino, ino);
		path[len] = '\0';
		if (chdir("..") < 0 || stat(".", &st) < 0 ||
		    (unsigned)st.st_ino != ino) {
			bad(dp->d_name, "..", (long)errno, (long)st.st_ino);
			break;
		}
	}
	closedir(d);
}

static int walkall(dir)
char *dir;
{
	struct stat st, pst;

	if (strlen(dir) >= sizeof path || chdir(dir) < 0 ||
	    stat(".", &st) < 0 || stat("..", &pst) < 0) {
		printf("PDWALK %s errno=%d\n", dir, errno);
		return (1);
	}
	strcpy(path, dir);
	mark(".", (unsigned)st.st_ino);
	walk((unsigned)st.st_ino, (unsigned)pst.st_ino);
	printf("PDWALK d=%ld f=%ld b=%ld dup=%ld bad=%ld ns=%ld sh=%ld s=%ld\n",
	    wdirs, wfiles, wbytes, wdup, wbad, wnotsup, wshort, wsum);
	if (wread)
		printf("PDWTIME t=%ld\n", wtime);
	return (0);
}

int
main(argc, argv)
int argc;
char **argv;
{
	struct statfs sf;
	struct stat st;
	long ino;
	int i;

	if (argc > 1 && strcmp(argv[1], "-s") == 0) {
		sums(argc - 2, argv + 2, "PDSUM");
		return (0);
	}
	if (argc > 1 && (strcmp(argv[1], "-p") == 0 ||
	    strcmp(argv[1], "-A") == 0 || strcmp(argv[1], "-P") == 0)) {
		pwrite_run(argc, argv);
		return (0);
	}
	if (argc > 2 && (strcmp(argv[1], "-c") == 0 ||
	    strcmp(argv[1], "-K") == 0 || strcmp(argv[1], "-d") == 0 ||
	    strcmp(argv[1], "-n") == 0 || strcmp(argv[1], "-r") == 0 ||
	    strcmp(argv[1], "-J") == 0 || strcmp(argv[1], "-D") == 0 ||
	    strcmp(argv[1], "-O") == 0 || strcmp(argv[1], "-M") == 0 ||
	    strcmp(argv[1], "-T") == 0)) {
		creates(argc, argv);
		return (0);
	}
	if (argc > 1 && strcmp(argv[1], "-U") == 0) {
		if (setgid(1) < 0 || setuid(1) < 0) {
			printf("PDUSUM setuid errno=%d\n", errno);
			return (14);
		}
		sums(argc - 2, argv + 2, "PDUSUM");
		return (0);
	}
	if (argc == 3 && (strcmp(argv[1], "-w") == 0 ||
	    strcmp(argv[1], "-W") == 0)) {
		wread = argv[1][1] == 'W';
		return (walkall(argv[2]));
	}

	printf("PDSTART\n");

	if (mount(MOUNT_PRODOS, "/mnt", 0, "/dev/sd1") < 0 ||
	    umount("/dev/sd1") < 0) {
		printf("PDNORW errno=%d\n", errno);
		return (1);
	}
	printf("PDRW\n");

	errno = 0;
	if (mount(MOUNT_PRODOS, "/mnt", MNT_RDONLY, "/dev/sd0") == 0 ||
	    errno != EBUSY) {
		printf("PDNOBUSYDEV errno=%d\n", errno);
		return (2);
	}
	printf("PDBUSYDEV\n");

	if (mount(MOUNT_PRODOS, "/mnt", MNT_RDONLY, "/dev/sd1") < 0) {
		printf("PDNOMOUNT errno=%d\n", errno);
		return (3);
	}
	printf("PDMOUNT\n");

	if (statfs("/mnt", &sf) < 0) {
		printf("PDNOSTAT errno=%d\n", errno);
		return (4);
	}
	printf("PDSTAT type=%d blocks=%ld free=%ld from=%s\n",
	    sf.f_type, sf.f_blocks, sf.f_bfree, sf.f_mntfromname);

	if (stat("/mnt", &st) < 0 || (st.st_mode & S_IFMT) != S_IFDIR) {
		printf("PDNOINO errno=%d mode=%o\n", errno, st.st_mode);
		return (12);
	}
	ino = (long)st.st_ino;
	if (crossings(40) < 0) {
		printf("PDNOCROSS errno=%d\n", errno);
		return (5);
	}
	if (stat("/mnt", &st) < 0 || (long)st.st_ino != ino) {
		printf("PDNOINO after=%ld before=%ld errno=%d\n",
		    (long)st.st_ino, ino, errno);
		return (13);
	}
	printf("PDINO %ld\n", ino);

	errno = 0;
	if (mount(MOUNT_NONE, "/mnt", MNT_RDONLY, "/dev/sd1") == 0 ||
	    errno != ENODEV) {
		printf("PDNOIDENT control errno=%d\n", errno);
		return (14);
	}
	if (chdir("/mnt") < 0) {
		printf("PDNOCD errno=%d\n", errno);
		return (6);
	}
	errno = 0;
	if (mount(MOUNT_NONE, "/mnt", MNT_RDONLY, "/dev/sd1") == 0 ||
	    errno != EBUSY) {
		printf("PDNOIDENT held errno=%d\n", errno);
		return (15);
	}
	printf("PDIDENT\n");
	errno = 0;
	if (umount("/dev/sd1") == 0 || errno != EBUSY) {
		printf("PDNOHOLD errno=%d\n", errno);
		return (7);
	}
	printf("PDHOLD\n");

	if (chdir("/") < 0 || umount("/dev/sd1") < 0) {
		printf("PDNOREL errno=%d\n", errno);
		return (8);
	}
	printf("PDREL\n");

	for (i = 0; i < 20; i++) {
		if (mount(MOUNT_PRODOS, "/mnt", MNT_RDONLY, "/dev/sd1") < 0) {
			printf("PDNOCYCLE mount %d errno=%d\n", i, errno);
			return (9);
		}
		if (crossings(2) < 0) {
			printf("PDNOCYCLE cross %d errno=%d\n", i, errno);
			return (10);
		}
		if (umount("/dev/sd1") < 0) {
			printf("PDNOCYCLE umount %d errno=%d\n", i, errno);
			return (11);
		}
	}
	printf("PDCYCLE\n");
	printf("PDDONE\n");
	return (0);
}
