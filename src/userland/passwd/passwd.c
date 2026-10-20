/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD passwd(1)
 *   Ported from passwd(1), 2.11BSD (passwd.c 4.35 (Berkeley) 3/16/89).
 *   Copyright (c) 1988
 *   The Regents of the University of California.  All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * passwd(1) - change a login password in /etc/passwd.
 *
 * Kept from upstream: the argument shape (passwd [user]), the uid gate (root
 * may change anyone's password; everyone else must prove they know the current
 * one and may only change their own), the SIG_IGN block, the O_EXCL claim on
 * /etc/ptmp, the prompt loop with its quality rules and its "Password
 * unchanged" escape, a salt drawn from the clock, and copy()'s line-by-line
 * rewrite of the database.
 *
 * Deleted (not stubbed): ndbm and the mkpasswd(8) fork that rebuilds
 * passwd.dir/passwd.pag, the fork-and-let-the-parent-exit dance that existed to
 * hide mkpasswd's runtime, setrlimit, setpriority, and flock.  FGX's passwd
 * database is the flat file and nothing else, so there is no second copy to
 * keep in step and nothing to hold a lock against.
 *
 * THE ONE STRUCTURAL DIFFERENCE: FGX's rename(2) is not a REPLACING rename.
 * SYS_RENAME (drivers/fs/write.s _Fs_Rename) renames in place only when source
 * and target share a parent AND THE TARGET DOES NOT EXIST; otherwise it returns
 * EXDEV, which is what makes mv(1) fall back to copy+unlink.  So the usual
 * "write a temp file, rename it over the original" recipe is simply not
 * available here: the rename over /etc/passwd would fail every time.
 *
 * What this does instead is rotate through a backup, which is the same shape
 * upstream uses for its own passwd.orig:
 *
 *      write /etc/ptmp      (the live file is untouched)
 *      unlink /etc/opasswd  (last run's backup, if any)
 *      rename /etc/passwd -> /etc/opasswd
 *      rename /etc/ptmp    -> /etc/passwd
 *
 * The live file is never opened for writing and never truncated, so no crash
 * can leave a half-written /etc/passwd -- the failure mode that leaves a
 * machine nobody can log into.  There is a two-syscall window between the two
 * renames in which /etc/passwd does not exist; a login started inside it fails,
 * but a complete database is on disk under /etc/opasswd the whole time and the
 * second rename failing rolls the first one back.  That window is the best
 * available without a replacing rename, and it is bounded by two directory-entry
 * writes rather than by the length of the file.
 */
#include <stdio.h>
#include <stdlib.h>
#include <pwd.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <time.h>
#include <errno.h>

int rename(char *from, char *to);       /* SYS_RENAME; not in any header yet */

#define PTMP    "/etc/ptmp"     /* the new file.  In /etc, because the rename
                                 * below only works within one directory. */
#define POLD    "/etc/opasswd"  /* the previous file, kept as the recovery copy
                                 * across the swap and as this run's undo */
#define LINEMAX 256             /* == libc's _PW_LINEMAX: a line getpwent()
                                 * can read is a line this can carry across */

/* File scope, not automatics: a 256-byte frame is real money against the bank-0
 * soft stack, and login.c keeps its own line buffer the same way. */
static char line[LINEMAX];
static char first[_PASSWORD_LEN + 1];
static char salt[3];

/* The salt alphabet.  Neither ':' (the field separator) nor '$' (crypt's hash
 * tag) is in it, so a salt can never make a passwd line unparseable or a tag
 * ambiguous.  Upstream picks any printable byte except ':' and gets away with
 * it because DES crypt folds the salt away; FGX's crypt copies both salt bytes
 * verbatim into the "$f$xy$" field, so they have to be safe to store. */
static char saltch[] =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./";

/* Two salt characters from the clock, never a constant: with a fixed salt two
 * users who pick the same password get byte-identical hashes, and /etc/passwd
 * then says so to anyone who reads it. */
static char *
newsalt()
{
	long t;

	/* time() alone is not enough to rely on.  It returns -1 when the clock
	 * cannot be read, which would hand every user the salt "//", and an
	 * unset clock sitting at the epoch gives everyone "aa" -- a degenerate
	 * salt is exactly the "two users, one hash" failure this is here to
	 * prevent, and it is invisible from the outside.  The pid is not
	 * secret, but it moves when the clock does not. */
	t = time((long *)0) ^ ((long)getpid() << 6);
	salt[0] = saltch[(int)(t & 63L)];
	salt[1] = saltch[(int)((t >> 6) & 63L)];
	salt[2] = '\0';
	return salt;
}

/* The salt that produced a stored hash -- login.c's saltof(), same reasoning:
 * a "$f$xy$........" hash carries its salt AFTER the tag, and passing the whole
 * field to crypt() would fold "$f" instead of "xy" and never match. */
static char *
saltof(hash)
	char *hash;
{
	if (hash[0] == '$' && hash[1] != '\0' && hash[2] == '$')
		return hash + 3;
	return hash;
}

/* Copy /etc/passwd to `fp`, swapping `user`'s password field for `np`.  Every
 * other byte of every other line is carried across verbatim, including the
 * leading "# name:passwd:uid:..." comment and any trailing fields this port
 * does not know about -- a rewrite driven by getpwent() would silently drop
 * both.  Returns 1 only if the user's line was actually seen: writing a file
 * that quietly lost the entry would be worse than writing nothing.
 */
static int
copypw(fp, user, np)
	FILE *fp;
	char *user, *np;
{
	FILE *in;
	char *rest;
	int n, done;

	in = fopen(_PATH_PASSWD, "r");
	if (in == (FILE *)0) {
		fprintf(stderr, "passwd: cannot read %s\n", _PATH_PASSWD);
		return 0;
	}
	n = strlen(user);
	done = 0;
	while (fgets(line, sizeof line, in) != (char *)0) {
		/* A line that did not fit the buffer is a line the copy would
		 * silently split in two.  Refuse the whole rewrite. */
		if (strchr(line, '\n') == (char *)0) {
			fprintf(stderr, "passwd: %s: line too long\n",
			        _PATH_PASSWD);
			fclose(in);
			return 0;
		}
		rest = (char *)0;
		if (!done && strncmp(line, user, n) == 0 && line[n] == ':')
			rest = strchr(line + n + 1, ':');
		if (rest == (char *)0) {
			fputs(line, fp);
			continue;
		}
		fprintf(fp, "%s:%s:%s", user, np, rest + 1);
		done = 1;
	}
	fclose(in);
	if (!done)
		fprintf(stderr, "passwd: %s: no entry for %s\n",
		        _PATH_PASSWD, user);
	return done;
}

/* Prompt for the new password and return its hash.  Exits rather than
 * returning on every path that must not change the file, exactly as upstream
 * does -- nothing has been created yet at this point, so there is nothing to
 * clean up on the way out. */
static char *
getnewpasswd(pw)
	struct passwd *pw;
{
	char *p;
	int i, root;

	root = getuid() == 0;

	/* BSD's rule: root sets anyone's password without knowing it, everyone
	 * else proves they know the current one.  FGX runs everything as uid 0
	 * today -- the kernel answers SYS_GETUID from a single _kProcUid global
	 * -- so this arm cannot be reached yet.  It is written for the day
	 * credentials move into the u-area, not stubbed out, because the day it
	 * starts mattering is not a day anyone will remember to come back. */
	if (!root) {
		/* Upstream guards the proof with `pw_passwd[0] != '\0' &&`,
		 * because on 2.11BSD an empty field means "no password
		 * required" and there is nothing to prove.  FGX's login(1)
		 * fails CLOSED on an empty field -- it means the account is
		 * LOCKED -- so keeping upstream's short circuit here would let
		 * the owner of a locked account unlock it while knowing
		 * nothing, which is the whole point of locking it. */
		if (pw->pw_passwd[0] == '\0') {
			fprintf(stderr, "passwd: %s is locked; ask root.\n",
			        pw->pw_name);
			exit(1);
		}
		if (strcmp(pw->pw_passwd,
		           crypt(getpass("Old password:"),
		                 saltof(pw->pw_passwd))) != 0) {
			fprintf(stderr, "passwd: %s\n", strerror(EACCES));
			exit(1);
		}
	}

	for (;;) {
		p = getpass("New password:");
		/* Also the EOF path: getpass() returns an empty string at end
		 * of file, so ^D quits without changing anything. */
		if (*p == '\0') {
			printf("Password unchanged.\n");
			exit(0);
		}
		/* Upstream applies these to everybody.  FGX exempts root, the
		 * modern BSD/Linux behaviour: root has to be able to set a
		 * password the rules forbid (recovering an account, or setting
		 * up a machine that is not on a network at all), and root can
		 * already edit /etc/passwd directly, so refusing here only
		 * costs the audit trail this program leaves. */
		if (!root) {
			if (strlen(p) <= 5) {
				printf("Please enter a longer password.\n");
				continue;
			}
			for (i = 0; p[i] >= 'a' && p[i] <= 'z'; i++)
				;
			if (p[i] == '\0') {
				printf("Please don't use an all-lower case password.\n");
				printf("Unusual capitalization or digits are suggested.\n");
				continue;
			}
		}
		strcpy(first, p);
		if (strcmp(first, getpass("Retype new password:")) == 0)
			break;
		printf("Mismatch; try again, EOF to quit.\n");
	}
	return crypt(first, newsalt());
}

int
main(argc, argv)
	int argc;
	char **argv;
{
	struct passwd *pw;
	char *np;
	FILE *out;
	int fd, uid, e;

	uid = getuid();
	if (argc == 1) {
		pw = getpwuid(uid);
		if (pw == (struct passwd *)0) {
			fprintf(stderr, "passwd: unknown user: uid %d\n", uid);
			return 1;
		}
	} else if (argc == 2) {
		pw = getpwnam(argv[1]);
		if (pw == (struct passwd *)0) {
			fprintf(stderr, "passwd: unknown user %s.\n", argv[1]);
			return 1;
		}
		if (uid != 0 && uid != pw->pw_uid) {
			fprintf(stderr, "passwd: %s\n", strerror(EACCES));
			return 1;
		}
	} else {
		fprintf(stderr, "usage: passwd [user]\n");
		return 1;
	}

	/* A signal between the two renames below would leave /etc/passwd
	 * missing rather than merely stale, so refuse to take one.  ^D at any
	 * prompt is the way out, and it exits without touching the file. */
	signal(SIGHUP, SIG_IGN);
	signal(SIGINT, SIG_IGN);
	signal(SIGQUIT, SIG_IGN);
	signal(SIGTSTP, SIG_IGN);

	printf("Changing password for %s.\n", pw->pw_name);
	np = getnewpasswd(pw);          /* exits on cancel or refusal */

	/* O_EXCL is upstream's lock: a second passwd already partway through a
	 * rewrite owns /etc/ptmp, and two of them interleaving would produce a
	 * file with one user's line from each.  Claimed AFTER the prompts, not
	 * before them as upstream does, so a session sitting at "New password:"
	 * does not hold the whole database hostage. */
	fd = open(PTMP, O_WRONLY | O_CREAT | O_EXCL, 0600);
	if (fd < 0) {
		if (errno == EEXIST)
			fprintf(stderr,
			    "passwd: password file busy -- try again later.\n");
		else
			fprintf(stderr, "passwd: %s: %s\n", PTMP,
			        strerror(errno));
		return 1;
	}
	close(fd);
	out = fopen(PTMP, "w");
	if (out == (FILE *)0) {
		fprintf(stderr, "passwd: cannot write %s\n", PTMP);
		unlink(PTMP);
		return 1;
	}
	if (!copypw(out, pw->pw_name, np) || ferror(out) || fclose(out) != 0) {
		fprintf(stderr, "passwd: password unchanged.\n");
		unlink(PTMP);
		return 1;
	}

	/* The swap.  See the rotate-through-a-backup note at the top of the
	 * file for why this is three calls and not one rename. */
	unlink(POLD);                   /* absent on the first run: ignore */
	if (rename(_PATH_PASSWD, POLD) < 0) {
		fprintf(stderr, "passwd: %s: %s; password unchanged.\n",
		        _PATH_PASSWD, strerror(errno));
		unlink(PTMP);
		return 1;
	}
	if (rename(PTMP, _PATH_PASSWD) < 0) {
		e = errno;                      /* the rollback overwrites it */
		/* TEST the rollback.  If it also fails there is no
		 * /etc/passwd at all, and "password unchanged" would be a lie
		 * told to the one person who can still fix it by hand -- the
		 * unbootable machine this whole design exists to avoid. */
		if (rename(POLD, _PATH_PASSWD) < 0)
			fprintf(stderr,
			    "passwd: %s is MISSING -- recover with: mv %s %s\n",
			    _PATH_PASSWD, POLD, _PATH_PASSWD);
		else
			fprintf(stderr, "passwd: %s: %s; password unchanged.\n",
			        PTMP, strerror(e));
		unlink(PTMP);
		return 1;
	}
	return 0;
}
