/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 1980 Regents of the University of California.
 *
 * FGX-Provenance: 2.11BSD tar(1)
 *   Ported from tar.c 5.7 (Berkeley) 4/26/86 (usr/bin/tar.c).
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * FGX adaptations (file-only tar; the old V7 512-byte-header format):
 *   - Tape/rmt removed: no /dev/rmt, no MTIO ioctls, no remote-tape protocol,
 *     no multi-volume/EOT prompting.  The archive is a file (`f name`) or
 *     stdin/stdout (`-`).  c/x/t are purely SEQUENTIAL, so tar never seeks —
 *     backtape()/lseek() (only used by the dropped append path) are gone.
 *   - Append/update dropped ('r' standalone, 'u'): no tfile/mktemp/sort/bsrch.
 *     'c' still works (it sets rflag directly).
 *   - mtime restored via utimes(2) (=> SYS_UTIME); dir mtimes via dodirtimes.
 *   - Octal header fields parsed with strtol(base 8) instead of sscanf, and
 *     emitted with printf %o/%lo (both added to libc for this port).
 *   - getbuf() simplified to the default blocking factor (no st_blksize).
 */
#include <stdio.h>
#include <sys/stat.h>
#include <sys/dir.h>
#include <sys/time.h>
#include <time.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

#define TBLOCK	512
#define NBLOCK	20
#define NAMSIZ	100
#define MAXPATHLEN 128

#define	writetape(b)	writetbuf(b, 1)
#define	min(a,b)  ((a) < (b) ? (a) : (b))
#define	max(a,b)  ((a) > (b) ? (a) : (b))

union hblock {
	char dummy[TBLOCK];
	struct header {
		char name[NAMSIZ];
		char mode[8];
		char uid[8];
		char gid[8];
		char size[12];
		char mtime[12];
		char chksum[8];
		char linkflag;
		char linkname[NAMSIZ];
	} dbuf;
};

struct linkbuf {
	ino_t	inum;
	dev_t	devnum;
	int	count;
	char	pathname[NAMSIZ];
	struct	linkbuf *nextp;
};

union	hblock dblock;
union	hblock *tbuf;
struct	linkbuf *ihead;
struct	stat stbuf;

int	rflag;
int	xflag;
int	vflag;
int	tflag;
int	cflag;
int	mflag;
int	fflag;
int	iflag;
int	oflag;
int	pflag;
int	wflag;
int	hflag;
int	Bflag;
int	Fflag;

int	mt;
int	term;
int	chksum;
int	recno;
int	first;
int	prtlinkerr;
int	freemem = 1;
int	nblock = 0;

int	onintr();
int	onquit();
int	onhup();

FILE	*vfile;
char	*usefile;

/* forward declarations (K&R implicit-int would lose far-pointer banks) */
int	openmt();
int	dorep();
int	endtape();
int	getdir();
int	passtape();
int	putfile();
int	doxtract();
int	dotable();
int	putempty();
int	longt();
int	pmode();
int	selectbits();
int	checkdir();
int	tomodes();
int	checksum();
int	checkw();
int	response();
int	checkf();
int	done();
int	wantit();
int	prefix();
int	readtape();
int	readtbuf();
int	writetbuf();
int	flushtape();
int	mterr();
int	bread();
int	getbuf();
int	dodirtimes();
int	setimes();
char	*getmem();
int	usage();
long	time();
int	dup();
int	chdir();
int	close();
/* char*-returning: must be declared so fcc keeps the far-pointer BANK
 * (an implicit int return would drop it) — no header prototypes exist. */
char	*getcwd();                      /* tar's OWN one-arg wrapper, below */
char	*getwd();
char	*rindex();

int
main(argc, argv)
	int argc;
	char *argv[];
{
	char *cp;

	vfile = stdout;
	if (argc < 2)
		usage();

	usefile = 0;
	argv[argc] = 0;
	argv++;
	for (cp = *argv++; *cp; cp++)
		switch (*cp) {

		case 'f':
			if (*argv == 0) {
				fprintf(stderr,
			"tar: tapefile must be specified with 'f' option\n");
				usage();
			}
			usefile = *argv++;
			fflag++;
			break;

		case 'c':
			cflag++;
			rflag++;
			break;

		case 'o':
			oflag++;
			break;

		case 'p':
			pflag++;
			break;

		case 'v':
			vflag++;
			break;

		case 'w':
			wflag++;
			break;

		case 'x':
			xflag++;
			break;

		case 't':
			tflag++;
			break;

		case 'm':
			mflag++;
			break;

		case '-':
			break;

		case 'b':
			if (*argv == 0) {
				fprintf(stderr,
			"tar: blocksize must be specified with 'b' option\n");
				usage();
			}
			nblock = atoi(*argv);
			if (nblock <= 0) {
				fprintf(stderr,
				    "tar: invalid blocksize \"%s\"\n", *argv);
				done(1);
			}
			argv++;
			break;

		case 'l':
			prtlinkerr++;
			break;

		case 'h':
			hflag++;
			break;

		case 'i':
			iflag++;
			break;

		case 'B':
			Bflag++;
			break;

		case 'F':
			Fflag++;
			break;

		default:
			fprintf(stderr, "tar: %c: unknown option\n", *cp);
			usage();
		}

	if (!rflag && !xflag && !tflag)
		usage();
	if (usefile == 0) {
		fprintf(stderr, "tar: an archive file ('f name') is required\n");
		usage();
	}
	if (rflag) {
		if (signal(SIGINT, SIG_IGN) != SIG_IGN)
			(void) signal(SIGINT, onintr);
		if (signal(SIGHUP, SIG_IGN) != SIG_IGN)
			(void) signal(SIGHUP, onhup);
		if (signal(SIGQUIT, SIG_IGN) != SIG_IGN)
			(void) signal(SIGQUIT, onquit);
		mt = openmt(usefile, 1);
		dorep(argv);
		done(0);
	}
	mt = openmt(usefile, 0);
	if (xflag)
		doxtract(argv);
	else
		dotable(argv);
	done(0);
	return 0;
}

int
usage()
{
	fprintf(stderr,
"tar: usage: tar -{cxt}[vfblmhopwBiF] f archive [blocksize] file1 file2 ...\n");
	done(1);
	return 1;
}

int
openmt(tape, writing)
	char *tape;
	int writing;
{
	if (strcmp(tape, "-") == 0) {
		/* Read from standard input or write to standard output. */
		if (writing) {
			if (cflag == 0) {
				fprintf(stderr,
			 "tar: can only create standard output archives\n");
				done(1);
			}
			vfile = stderr;
			mt = dup(1);
		} else {
			mt = dup(0);
			Bflag++;
		}
	} else {
		if (writing) {
			/* creat() = O_WRONLY|O_CREAT|O_TRUNC, which is all a
			 * create needs (we only write -- the append path that
			 * wanted O_RDWR is dropped).  The mode reaches the
			 * inode now: open(2) took two arguments when this was
			 * written and creat(2) discarded the third. */
			if (cflag)
				mt = creat(tape, 0666);
			else
				mt = open(tape, O_RDWR);
		} else
			mt = open(tape, O_RDONLY);
		if (mt < 0) {
			fprintf(stderr, "tar: ");
			perror(tape);
			done(1);
		}
	}
	return (mt);
}

int
dorep(argv)
	char *argv[];
{
	register char *cp, *cp2;
	char wdir[MAXPATHLEN], tempdir[MAXPATHLEN], *parent;

	(void) getcwd(wdir);
	while (*argv && !term) {
		cp2 = *argv;
		if (!strcmp(cp2, "-C") && argv[1]) {
			argv++;
			if (chdir(*argv) < 0) {
				fprintf(stderr,
				    "tar: can't change directories to ");
				perror(*argv);
			} else
				(void) getcwd(wdir);
			argv++;
			continue;
		}

		if (*argv[0] == '/')
			parent = "";
		else
			parent = wdir;

		for (cp = *argv; *cp; cp++)
			if (*cp == '/')
				cp2 = cp;
		if (cp2 != *argv) {
			*cp2 = '\0';
			if (chdir(*argv) < 0) {
				fprintf(stderr,
				    "tar: can't change directories to ");
				perror(*argv);
				continue;
			}
			parent = getcwd(tempdir);
			*cp2 = '/';
			cp2++;
		}
		putfile(*argv++, cp2, parent);
		if (chdir(wdir) < 0) {
			fprintf(stderr, "tar: cannot change back?: ");
			perror(wdir);
		}
	}
	putempty();
	putempty();
	flushtape();
	if (prtlinkerr == 0)
		return 0;
	for (; ihead != NULL; ihead = ihead->nextp) {
		if (ihead->count == 0)
			continue;
		fprintf(stderr, "tar: missing links to %s\n", ihead->pathname);
	}
	return 0;
}

int
endtape()
{
	return (dblock.dbuf.name[0] == '\0');
}

int
getdir()
{
	register struct stat *sp;
	int i;

top:
	readtape((char *)&dblock);
	if (dblock.dbuf.name[0] == '\0')
		return 0;
	sp = &stbuf;
	sp->st_mode = (int)strtol(dblock.dbuf.mode, (char **)0, 8);
	sp->st_uid  = (int)strtol(dblock.dbuf.uid,  (char **)0, 8);
	sp->st_gid  = (int)strtol(dblock.dbuf.gid,  (char **)0, 8);
	sp->st_size = strtol(dblock.dbuf.size,  (char **)0, 8);
	sp->st_mtime = strtol(dblock.dbuf.mtime, (char **)0, 8);
	chksum = (int)strtol(dblock.dbuf.chksum, (char **)0, 8);
	if (chksum != (i = checksum())) {
		fprintf(stderr, "tar: directory checksum error (%d != %d)\n",
		    chksum, i);
		if (iflag)
			goto top;
		done(2);
	}
	return 0;
}

int
passtape()
{
	long blocks;
	char *bufp;

	if (dblock.dbuf.linkflag == '1')
		return 0;
	blocks = stbuf.st_size;
	blocks += TBLOCK - 1;
	blocks /= TBLOCK;

	while (blocks-- > 0)
		(void) readtbuf(&bufp, TBLOCK);
	return 0;
}

int
putfile(longname, shortname, parent)
	char *longname;
	char *shortname;
	char *parent;
{
	int infile = 0;
	long blocks;
	/*
	 * FGX: putfile RECURSES (S_IFDIR arm below), and every local is live
	 * across that call, so each byte here is paid once per directory level
	 * of the bank-0 hardware stack -- and the linker's stack-pages hint
	 * reserves CYCLE_TURNS levels of it up front (stack_measure.py).
	 * 2.11BSD sized `buf` TBLOCK because it serves two disjoint roles: the
	 * path-prefix scratch on the RECURSIVE arm, and the malloc-failure read
	 * buffer on the S_IFREG arm, which never recurses.  Split them: the
	 * scratch is bounded by the NAMSIZ check below plus one appended
	 * directory entry, and the fallback block moves to static storage
	 * (data-segment bytes are plentiful; bank-0 stack pages are not).
	 * putfile's frame: 706 -> 311 B, tar's hint 30 -> 16 pages.
	 */
	char buf[NAMSIZ + MAXNAMLEN + 2];
	static char fallbuf[TBLOCK];
	char *bigbuf;
	register char *cp;
	struct direct *dp;
	DIR *dirp;
	register int i;
	char newparent[NAMSIZ + 64];
	int maxread;
	int hint;			/* amount to write to get "in sync" */

	if (!hflag)
		i = lstat(shortname, &stbuf);
	else
		i = stat(shortname, &stbuf);
	if (i < 0) {
		fprintf(stderr, "tar: ");
		perror(longname);
		return 0;
	}
	if (checkw('r', longname) == 0)
		return 0;
	if (Fflag && checkf(shortname, stbuf.st_mode, Fflag) == 0)
		return 0;

	switch (stbuf.st_mode & S_IFMT) {
	case S_IFDIR:
		/*
		 * FGX: check BEFORE the copy -- `buf` is now sized to the limit
		 * this test enforces rather than to TBLOCK's old slack, and
		 * longname comes from argv at the top level.  The test also
		 * moved OUT of `!oflag`: a prefix at/over NAMSIZ fits in neither
		 * format's header, so -o only ever descended such a tree to
		 * reject every file inside it one by one (S_IFREG arm below).
		 * Equivalent to the old `(cp - buf) >= NAMSIZ`, which ran with
		 * cp on the terminator, i.e. cp - buf == strlen(longname) + 1.
		 */
		if (strlen(longname) + 1 >= NAMSIZ) {
			fprintf(stderr, "tar: %s: file name too long\n",
			    longname);
			return 0;
		}
		for (i = 0, cp = buf; (*cp++ = longname[i++]) != 0;)
			;
		*--cp = '/';
		*++cp = 0;
		if (!oflag) {
			stbuf.st_size = 0;
			tomodes(&stbuf);
			strcpy(dblock.dbuf.name, buf);
			sprintf(dblock.dbuf.chksum, "%6o", checksum());
			(void) writetape((char *)&dblock);
		}
		sprintf(newparent, "%s/%s", parent, shortname);
		if (chdir(shortname) < 0) {
			perror(shortname);
			return 0;
		}
		if ((dirp = opendir(".")) == NULL) {
			fprintf(stderr, "tar: %s: directory read error\n",
			    longname);
			if (chdir(parent) < 0) {
				fprintf(stderr, "tar: cannot change back?: ");
				perror(parent);
			}
			return 0;
		}
		/*
		 * FGX opendir() snapshots the whole directory up front (no held
		 * fd during iteration), so — unlike 2.11BSD — we keep dirp open
		 * across the recursive putfile and just continue readdir.  No
		 * telldir/seekdir/close-reopen dance.
		 */
		while ((dp = readdir(dirp)) != NULL && !term) {
			if (dp->d_ino == 0)
				continue;
			if (!strcmp(".", dp->d_name) ||
			    !strcmp("..", dp->d_name))
				continue;
			strcpy(cp, dp->d_name);
			putfile(buf, cp, newparent);
		}
		closedir(dirp);
		if (chdir(parent) < 0) {
			fprintf(stderr, "tar: cannot change back?: ");
			perror(parent);
		}
		break;

	case S_IFLNK:
		tomodes(&stbuf);
		if (strlen(longname) >= NAMSIZ) {
			fprintf(stderr, "tar: %s: file name too long\n",
			    longname);
			return 0;
		}
		strcpy(dblock.dbuf.name, longname);
		if (stbuf.st_size + 1 >= NAMSIZ) {
			fprintf(stderr, "tar: %s: symbolic link too long\n",
			    longname);
			return 0;
		}
		i = readlink(shortname, dblock.dbuf.linkname, NAMSIZ - 1);
		if (i < 0) {
			fprintf(stderr, "tar: can't read symbolic link ");
			perror(longname);
			return 0;
		}
		dblock.dbuf.linkname[i] = '\0';
		dblock.dbuf.linkflag = '2';
		if (vflag)
			fprintf(vfile, "a %s symbolic link to %s\n",
			    longname, dblock.dbuf.linkname);
		sprintf(dblock.dbuf.size, "%11lo", 0L);
		sprintf(dblock.dbuf.chksum, "%6o", checksum());
		(void) writetape((char *)&dblock);
		break;

	case S_IFREG:
		if ((infile = open(shortname, 0)) < 0) {
			fprintf(stderr, "tar: ");
			perror(longname);
			return 0;
		}
		tomodes(&stbuf);
		if (strlen(longname) >= NAMSIZ) {
			fprintf(stderr, "tar: %s: file name too long\n",
			    longname);
			close(infile);
			return 0;
		}
		strcpy(dblock.dbuf.name, longname);
		if (stbuf.st_nlink > 1) {
			struct linkbuf *lp;
			int found = 0;

			for (lp = ihead; lp != NULL; lp = lp->nextp)
				if (lp->inum == stbuf.st_ino &&
				    lp->devnum == stbuf.st_dev) {
					found++;
					break;
				}
			if (found) {
				strcpy(dblock.dbuf.linkname, lp->pathname);
				dblock.dbuf.linkflag = '1';
				sprintf(dblock.dbuf.chksum, "%6o", checksum());
				(void) writetape( (char *) &dblock);
				if (vflag)
					fprintf(vfile, "a %s link to %s\n",
					    longname, lp->pathname);
				lp->count--;
				close(infile);
				return 0;
			}
			lp = (struct linkbuf *) getmem(sizeof(*lp));
			if (lp != NULL) {
				lp->nextp = ihead;
				ihead = lp;
				lp->inum = stbuf.st_ino;
				lp->devnum = stbuf.st_dev;
				lp->count = stbuf.st_nlink - 1;
				strcpy(lp->pathname, longname);
			}
		}
		blocks = (stbuf.st_size + (TBLOCK - 1)) / TBLOCK;
		if (vflag)
			fprintf(vfile, "a %s %ld blocks\n", longname, blocks);
		sprintf(dblock.dbuf.chksum, "%6o", checksum());
		hint = writetape((char *)&dblock);
		maxread = nblock * TBLOCK;
		if ((bigbuf = malloc((unsigned)maxread)) == 0) {
			maxread = TBLOCK;
			bigbuf = fallbuf;
		}

		while ((i = read(infile, bigbuf, min((hint * TBLOCK), maxread))) > 0
		    && blocks > 0) {
			register int nblks;

			nblks = ((i - 1) / TBLOCK) + 1;
			if (nblks > blocks)
				nblks = blocks;
			hint = writetbuf(bigbuf, nblks);
			blocks -= nblks;
		}
		close(infile);
		if (bigbuf != fallbuf)
			free(bigbuf);
		if (i < 0) {
			fprintf(stderr, "tar: Read error on ");
			perror(longname);
		} else if (blocks != 0 || i != 0)
			fprintf(stderr, "tar: %s: file changed size\n",
			    longname);
		while (--blocks >= 0)
			putempty();
		break;

	default:
		fprintf(stderr, "tar: %s is not a file. Not dumped\n",
		    longname);
		break;
	}
	return 0;
}

int
doxtract(argv)
	char *argv[];
{
	long blocks, bytes;
	int ofile, i;

	for (;;) {
		if ((i = wantit(argv)) == 0)
			continue;
		if (i == -1)
			break;			/* end of tape */
		if (checkw('x', dblock.dbuf.name) == 0) {
			passtape();
			continue;
		}
		if (Fflag) {
			char *s;

			if ((s = rindex(dblock.dbuf.name, '/')) == 0)
				s = dblock.dbuf.name;
			else
				s++;
			if (checkf(s, stbuf.st_mode, Fflag) == 0) {
				passtape();
				continue;
			}
		}
		if (checkdir(dblock.dbuf.name)) {	/* have a directory */
			if (mflag == 0)
				dodirtimes(&dblock);
			continue;
		}
		if (dblock.dbuf.linkflag == '2') {	/* symlink */
			/*
			 * only unlink non directories or empty
			 * directories
			 */
			if (rmdir(dblock.dbuf.name) < 0) {
				if (errno == ENOTDIR)
					unlink(dblock.dbuf.name);
			}
			if (symlink(dblock.dbuf.linkname, dblock.dbuf.name)<0) {
				fprintf(stderr, "tar: %s: symbolic link failed: ",
				    dblock.dbuf.name);
				perror("");
				continue;
			}
			if (vflag)
				fprintf(vfile, "x %s symbolic link to %s\n",
				    dblock.dbuf.name, dblock.dbuf.linkname);
			continue;
		}
		if (dblock.dbuf.linkflag == '1') {	/* regular link */
			/*
			 * only unlink non directories or empty
			 * directories
			 */
			if (rmdir(dblock.dbuf.name) < 0) {
				if (errno == ENOTDIR)
					unlink(dblock.dbuf.name);
			}
			if (link(dblock.dbuf.linkname, dblock.dbuf.name) < 0) {
				fprintf(stderr, "tar: can't link %s to %s: ",
				    dblock.dbuf.name, dblock.dbuf.linkname);
				perror("");
				continue;
			}
			if (vflag)
				fprintf(vfile, "%s linked to %s\n",
				    dblock.dbuf.name, dblock.dbuf.linkname);
			continue;
		}
		if ((ofile = creat(dblock.dbuf.name, stbuf.st_mode & 0xfff)) < 0) {
			fprintf(stderr, "tar: can't create %s: ",
			    dblock.dbuf.name);
			perror("");
			passtape();
			continue;
		}
		chown(dblock.dbuf.name, stbuf.st_uid, stbuf.st_gid);
		blocks = ((bytes = stbuf.st_size) + TBLOCK - 1) / TBLOCK;
		if (vflag)
			fprintf(vfile, "x %s, %ld bytes, %ld tape blocks\n",
			    dblock.dbuf.name, bytes, blocks);
		for (; blocks > 0;) {
			register int nread;
			char *bufp;
			register int nwant;

			nwant = NBLOCK * TBLOCK;
			if (nwant > (blocks * TBLOCK))
				nwant = (blocks * TBLOCK);
			nread = readtbuf(&bufp, nwant);
			if (write(ofile, bufp, (int)min(nread, bytes)) < 0) {
				fprintf(stderr,
				    "tar: %s: HELP - extract write error",
				    dblock.dbuf.name);
				perror("");
				done(2);
			}
			bytes -= nread;
			blocks -= (((nread - 1) / TBLOCK) + 1);
		}
		close(ofile);
		if (mflag == 0)
			setimes(dblock.dbuf.name, stbuf.st_mtime);
		if (pflag)
			chmod(dblock.dbuf.name, stbuf.st_mode & 07777);
	}
	if (mflag == 0) {
		dblock.dbuf.name[0] = '\0';	/* process the whole stack */
		dodirtimes(&dblock);
	}
	return 0;
}

int
dotable(argv)
	char *argv[];
{
	register int i;

	for (;;) {
		if ((i = wantit(argv)) == 0)
			continue;
		if (i == -1)
			break;			/* end of tape */
		if (vflag)
			longt(&stbuf);
		printf("%s", dblock.dbuf.name);
		if (dblock.dbuf.linkflag == '1')
			printf(" linked to %s", dblock.dbuf.linkname);
		if (dblock.dbuf.linkflag == '2')
			printf(" symbolic link to %s", dblock.dbuf.linkname);
		printf("\n");
		passtape();
	}
	return 0;
}

int
putempty()
{
	char buf[TBLOCK];

	bzero(buf, sizeof(buf));
	(void) writetape(buf);
	return 0;
}

int
longt(st)
	register struct stat *st;
{
	register char *cp;

	pmode(st);
	printf("%3d/%1d", st->st_uid, st->st_gid);
	printf("%7ld", st->st_size);
	cp = ctime(&st->st_mtime);
	printf(" %-12.12s %-4.4s ", cp + 4, cp + 20);
	return 0;
}

#define	SUID	04000
#define	SGID	02000
#define	ROWN	0400
#define	WOWN	0200
#define	XOWN	0100
#define	RGRP	040
#define	WGRP	020
#define	XGRP	010
#define	ROTH	04
#define	WOTH	02
#define	XOTH	01
#define	STXT	01000
int	m1[] = { 1, ROWN, 'r', '-' };
int	m2[] = { 1, WOWN, 'w', '-' };
int	m3[] = { 2, SUID, 's', XOWN, 'x', '-' };
int	m4[] = { 1, RGRP, 'r', '-' };
int	m5[] = { 1, WGRP, 'w', '-' };
int	m6[] = { 2, SGID, 's', XGRP, 'x', '-' };
int	m7[] = { 1, ROTH, 'r', '-' };
int	m8[] = { 1, WOTH, 'w', '-' };
int	m9[] = { 2, STXT, 't', XOTH, 'x', '-' };

int	*m[] = { m1, m2, m3, m4, m5, m6, m7, m8, m9 };

int
pmode(st)
	register struct stat *st;
{
	register int **mp;

	for (mp = &m[0]; mp < &m[9];)
		selectbits(*mp++, st);
	return 0;
}

int
selectbits(pairp, st)
	int *pairp;
	struct stat *st;
{
	register int n, *ap;

	ap = pairp;
	n = *ap++;
	while (--n >= 0 && (st->st_mode & *ap++) == 0)
		ap++;
	putchar(*ap);
	return 0;
}

/*
 * Make all directories needed by `name'.  If `name' is itself a directory on
 * the tar tape (trailing '/'), return 1; else 0.
 */
int
checkdir(name)
	register char *name;
{
	register char *cp;

	if ((cp = rindex(name, '/')) == 0)
		return (0);
	*cp = '\0';
	if (access(name, 0) == 0) {		/* already exists */
		*cp = '/';
		return (cp[1] == '\0');		/* return (lastchar == '/') */
	}
	*cp = '/';

	for (cp = name; *cp; cp++) {
		if (*cp != '/')
			continue;
		*cp = '\0';
		if (access(name, 0) < 0) {
			if (mkdir(name, 0777) < 0) {
				perror(name);
				*cp = '/';
				return (0);
			}
			chown(name, stbuf.st_uid, stbuf.st_gid);
			if (pflag && cp[1] == '\0')	/* dir on the tape */
				chmod(name, stbuf.st_mode & 07777);
		}
		*cp = '/';
	}
	return (cp[-1] == '/');
}

int
onintr()
{
	(void) signal(SIGINT, SIG_IGN);
	term++;
	return 0;
}

int
onquit()
{
	(void) signal(SIGQUIT, SIG_IGN);
	term++;
	return 0;
}

int
onhup()
{
	/* FGX: upstream re-armed with signal(SIGHUP, SIG_IGN) here.  SIGHUP
	 * became genuinely deliverable on 2026-08-04, and a handler body may
	 * only set a flag and return -- calling libc from one corrupts the
	 * call it interrupted (docs/userland-abi.md section 6A).  Dropping the
	 * re-arm is harmless: term++ twice reads the same as term++ once. */
	term++;
	return 0;
}

int
tomodes(sp)
	register struct stat *sp;
{
	register char *cp;

	for (cp = dblock.dummy; cp < &dblock.dummy[TBLOCK]; cp++)
		*cp = '\0';
	sprintf(dblock.dbuf.mode, "%6o ", sp->st_mode & 07777);
	sprintf(dblock.dbuf.uid, "%6o ", sp->st_uid);
	sprintf(dblock.dbuf.gid, "%6o ", sp->st_gid);
	sprintf(dblock.dbuf.size, "%11lo ", sp->st_size);
	sprintf(dblock.dbuf.mtime, "%11lo ", sp->st_mtime);
	return 0;
}

int
checksum()
{
	register int i;
	register char *cp;

	for (cp = dblock.dbuf.chksum;
	     cp < &dblock.dbuf.chksum[sizeof(dblock.dbuf.chksum)]; cp++)
		*cp = ' ';
	i = 0;
	for (cp = dblock.dummy; cp < &dblock.dummy[TBLOCK]; cp++)
		i += *cp & 0xFF;
	return (i);
}

int
checkw(c, name)
	int c;
	char *name;
{
	if (!wflag)
		return (1);
	printf("%c ", c);
	if (vflag)
		longt(&stbuf);
	printf("%s: ", name);
	return (response() == 'y');
}

int
response()
{
	int c;

	c = getchar();
	if (c != '\n')
		while (getchar() != '\n')
			;
	else
		c = 'n';
	return (c);
}

int
checkf(name, mode, howmuch)
	char *name;
	int mode, howmuch;
{
	int l;

	if ((mode & S_IFMT) == S_IFDIR) {
		if ((strcmp(name, "SCCS") == 0) || (strcmp(name, "RCS") == 0))
			return (0);
		return (1);
	}
	if ((l = strlen(name)) < 3)
		return (1);
	if (howmuch > 1 && name[l - 2] == '.' && name[l - 1] == 'o')
		return (0);
	if (strcmp(name, "core") == 0 ||
	    strcmp(name, "errs") == 0 ||
	    (howmuch > 1 && strcmp(name, "a.out") == 0))
		return (0);
	return (1);
}

int
done(n)
	int n;
{
	exit(n);
	return 0;
}

/*
 * Do we want the next entry on the tape, i.e. is it selected?  If not, skip
 * over the entire entry.  Return -1 if reached end of tape.
 */
int
wantit(argv)
	char *argv[];
{
	register char **cp;

	getdir();
	if (endtape())
		return (-1);
	if (*argv == 0)
		return (1);
	for (cp = argv; *cp; cp++)
		if (prefix(*cp, dblock.dbuf.name))
			return (1);
	passtape();
	return (0);
}

/* Does s2 begin with the string s1, on a directory boundary? */
int
prefix(s1, s2)
	register char *s1, *s2;
{
	while (*s1)
		if (*s1++ != *s2++)
			return (0);
	if (*s2)
		return (*s2 == '/');
	return (1);
}

int
readtape(buffer)
	char *buffer;
{
	char *bufp;

	if (first == 0)
		getbuf();
	(void) readtbuf(&bufp, TBLOCK);
	bcopy(bufp, buffer, TBLOCK);
	return (TBLOCK);
}

int
readtbuf(bufpp, size)
	char **bufpp;
	int size;
{
	register int i;

	if (recno >= nblock || first == 0) {
		if ((i = bread(mt, (char *)tbuf, TBLOCK * nblock)) < 0)
			mterr("read", i, 3);
		if (first == 0) {
			if ((i % TBLOCK) != 0) {
				fprintf(stderr, "tar: tape blocksize error\n");
				done(3);
			}
			i /= TBLOCK;
			if (i != nblock) {
				nblock = i;
			}
			first = 1;
		}
		recno = 0;
	}
	if (size > ((nblock - recno) * TBLOCK))
		size = (nblock - recno) * TBLOCK;
	*bufpp = (char *)&tbuf[recno];
	recno += (size / TBLOCK);
	return (size);
}

int
writetbuf(buffer, n)
	register char *buffer;
	register int n;
{
	int i;

	if (first == 0) {
		getbuf();
		first = 1;
	}
	if (recno >= nblock) {
		i = write(mt, (char *)tbuf, TBLOCK * nblock);
		if (i != TBLOCK * nblock)
			mterr("write", i, 2);
		recno = 0;
	}

	/*
	 * Special case: empty tape buffer + user data >= tape block size:
	 * write straight from the user's buffer.
	 */
	while (recno == 0 && n >= nblock) {
		i = write(mt, buffer, TBLOCK * nblock);
		if (i != TBLOCK * nblock)
			mterr("write", i, 2);
		n -= nblock;
		buffer += (nblock * TBLOCK);
	}

	while (n-- > 0) {
		bcopy(buffer, (char *)&tbuf[recno++], TBLOCK);
		buffer += TBLOCK;
		if (recno >= nblock) {
			i = write(mt, (char *)tbuf, TBLOCK * nblock);
			if (i != TBLOCK * nblock)
				mterr("write", i, 2);
			recno = 0;
		}
	}

	/* Tell the user how much to write to get in sync */
	return (nblock - recno);
}

int
flushtape()
{
	int i;

	i = write(mt, (char *)tbuf, TBLOCK * nblock);
	if (i != TBLOCK * nblock)
		mterr("write", i, 2);
	return 0;
}

int
mterr(operation, i, exitcode)
	char *operation;
	int i, exitcode;
{
	fprintf(stderr, "tar: tape %s error: ", operation);
	if (i < 0)
		perror("");
	else
		fprintf(stderr, "unexpected EOF\n");
	done(exitcode);
	return 0;
}

int
bread(fd, buf, size)
	int fd;
	char *buf;
	int size;
{
	int count;
	static int lastread = 0;

	if (!Bflag)
		return (read(fd, buf, size));

	for (count = 0; count < size; count += lastread) {
		lastread = read(fd, buf, size - count);
		if (lastread <= 0) {
			if (count > 0)
				return (count);
			return (lastread);
		}
		buf += lastread;
	}
	return (count);
}

/* 2.11BSD tar's OWN getcwd(): a one-arg wrapper around getwd() that dies with
 * the message getwd left in the buffer, so libc keeps only the BSD interface. */
char *
getcwd(buf)
	char *buf;
{
	if (getwd(buf) == NULL) {
		fprintf(stderr, "tar: %s\n", buf);
		done(1);
	}
	return (buf);
}

getbuf()
{
	if (nblock == 0)
		nblock = NBLOCK;
	tbuf = (union hblock *)malloc((unsigned)nblock * TBLOCK);
	if (tbuf == NULL) {
		fprintf(stderr,
		    "tar: blocksize %d too big, can't get memory\n", nblock);
		done(1);
	}
	return 0;
}

/*
 * Save this directory and its mtime on the stack, popping and setting the
 * mtimes of any stacked dirs which aren't parents of this one.  A null
 * directory unwinds the entire stack.  See the 2.11BSD comment for the
 * single-string prefix-sharing trick.
 */
char dirstack[NAMSIZ];
#define NTIM (NAMSIZ/2+1)
long mtimestk[NTIM];

int
dodirtimes(hp)
	union hblock *hp;
{
	register char *p = dirstack;
	register char *q = hp->dbuf.name;
	register int ndir = 0;
	char *savp;
	int savndir;

	while (*p == *q) {			/* find common prefix */
		if (*p++ == '/')
			++ndir;
		q++;
	}

	savp = p;
	savndir = ndir;
	while (*p) {
		/* Not a child: unwind the stack, setting the times. */
		if (*p++ == '/')
			if (mtimestk[++ndir] >= 0) {
				*--p = '\0';		/* zap the slash */
				setimes(dirstack, mtimestk[ndir]);
				*p++ = '/';
			}
	}
	p = savp;
	ndir = savndir;

	/* Push this one on the "stack" */
	while ((*p = *q++) != 0)		/* append the rest of the new dir */
		if (*p++ == '/')
			mtimestk[++ndir] = -1;
	mtimestk[ndir] = stbuf.st_mtime;	/* overwrite the last one */
	return 0;
}

int
setimes(path, mt)
	char *path;
	long mt;
{
	struct timeval tv[2];

	tv[0].tv_sec = time((long *)0);
	tv[1].tv_sec = mt;
	tv[0].tv_usec = tv[1].tv_usec = 0;
	if (utimes(path, tv) < 0) {
		fprintf(stderr, "tar: can't set time on %s: ", path);
		perror("");
	}
	return 0;
}

char *
getmem(size)
{
	char *p = malloc((unsigned) size);

	if (p == NULL && freemem) {
		fprintf(stderr,
		    "tar: out of memory, link and directory modtime info lost\n");
		freemem = 0;
	}
	return (p);
}
