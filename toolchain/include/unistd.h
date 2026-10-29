/* FGX libc — unistd.h.  POSIX declarations for the primitives FGX provides.
 *
 * Only functions actually in the FGX libc (lib/libc_c + libc.s) are declared
 * here; BSD ports that reference primitives FGX lacks (see the note at the
 * bottom) fail at link, not compile, which is the honest signal.
 */
#ifndef _UNISTD_H
#define _UNISTD_H

#include <sys/types.h>          /* size_t, off_t, caddr_t */

/* lseek(2) whences (also in <stdio.h>). */
#ifndef SEEK_SET
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
#endif

/* Standard file descriptors. */
#define STDIN_FILENO   0
#define STDOUT_FILENO  1
#define STDERR_FILENO  2

/* access(2) mode bits (FGX access() checks existence only; mode is ignored). */
#define F_OK  0
#define X_OK  1
#define W_OK  2
#define R_OK  4

/* I/O primitives. */
int   read(int fd, char *buf, int n);
int   write(int fd, char *buf, int n);
int   close(int fd);
long  lseek(int fd, long off, int whence);
int   dup(int fd);
int   dup2(int oldfd, int newfd);
int   pipe(int *fds);
int   fsync(int fd);            /* SYS_FSYNC #97: flush ONE fd's data+metadata */
void  sync(void);               /* SYS_SYNC: flush every dirty buffer + the
                                 * block bitmap.  Both have been in libc since
                                 * the block-write train; they were just never
                                 * declared here, so callers got an implicit
                                 * int-returning decl (2026-08-04). */
int   access(char *path, int mode);
int   unlink(char *path);
int   rmdir(char *path);
int   chdir(char *path);
char *getwd(char *buf);         /* 4.xBSD: buf >= MAXPATHLEN; msg in buf on failure.
                                 * No getcwd(): BSD sources call getwd, and a
                                 * private getcwd forced per-port adaptation. */
int   isatty(int fd);
char *ttyname(int fd);          /* "/dev/<name>" for a tty fd, NULL otherwise.
                                 * MUST be declared before use: it returns a
                                 * 4-byte FAR pointer, and an implicit-int
                                 * declaration keeps only 2 bytes of it -- the
                                 * same defect class as the 2026-07-26 signal()
                                 * decl/def return-width bug.  Points at a
                                 * static buffer valid until the next call. */
int   ttyslot(void);            /* 1-based /etc/ttys position of the
                                 * terminal on fd 0, 1 or 2; 0 = not a
                                 * listed line.  The /etc/utmp record
                                 * number -- see <utmp.h>. */
int   gethostname(char *name, int namelen);  /* /etc/hostname, one line */
int   readlink(char *path, char *buf, int bufsiz);
int   link(char *from, char *to);             /* SYS_LINK(9).  A second name for
                                               * one inode, on a mounted root;
                                               * `from' is resolved with FOLLOW,
                                               * so linking a symlink links what
                                               * it points at. */
int   symlink(char *target, char *linkname);   /* SYS_SYMLINK(113).  target is
                                               * the link's CONTENTS, not a path
                                               * this call resolves. */

/* Memory. */
char *sbrk(int incr);           /* The increment is SIGNED and the kernel adds
                                 * it, so 32767 is the most one call can move
                                 * the break -- upstream's sbrk.s has no such
                                 * cap; apple/fgx#399.
                                 * POSIX: (char *)-1 + errno on refusal, and it
                                 * RETURNS.  It briefly _exit()ed instead; #13
                                 * put that back and taught sh to check, which
                                 * 2.11BSD's own fault.c already did. */
int   brk(char *addr);

/* Process control. */
int   getpid(void);
/* getppid() — SYS_GETPPID=39.  The syscall predates the wrapper; the libc side
 * was added while building apple/fgx#105. */
int   getppid(void);
/* alarm(sec) — SYS_ALARM=64, 0 cancels.  Shipped in the C pile since the vi
 * port; like setpgid below it had no prototype, so callers reached it through
 * K&R's implicit int.  That is benign for an int-returning function and a
 * silent corruption for a pointer-returning one, which is why these are now
 * declared rather than left to the implicit rule.  Signature is int/int, not
 * BSD's unsigned/unsigned: that is what the C pile defines, and a prototype
 * that disagrees with its definition is worse than none. */
int   alarm(int sec);
/* setpgid(pid, pgid) — SYS_SETPGID=80.  The libc wrapper has shipped since job
 * control landed; only the prototype was missing, so every caller reached it
 * through K&R's implicit int and no header ever said it existed. */
int   setpgid(int pid, int pgid);
int   fork(void);
int   vfork(void);
int   execv(char *path, char **argv);
int   execve(char *path, char **argv, char **envp);
int   execl(char *path, ...);
int   execle(char *path, ...);             /* argv..., 0, envp */
int   execlp(char *name, ...);             /* execl with a $PATH search */
int   execvp(char *name, char **argv);     /* execv with a $PATH search */
int   getdtablesize(void);                 /* NOFILE */
void  _exit(int code);
/* daemon(nochdir, noclose) -- fork, detach from the controlling terminal, and
 * optionally chdir("/") and reopen 0/1/2 on /dev/null.  2.11BSD declares it in
 * <stdlib.h>; FGX keeps it beside the fork it is built on. */
int   daemon(int nochdir, int noclose);

/* Identity.  These issue real syscalls (SYS_GETUID=24, SYS_GETGID=47) rather
 * than returning a constant, so userland reads whatever the kernel reports.
 * Today that is still 0/0 — the kernel holds one process's credentials in
 * globals — but callers need no change when credentials become per-process.
 * The effective forms delegate to the real ones: FGX has no setuid yet, so
 * real and effective cannot differ. */
int   getuid(void);
int   geteuid(void);
int   getgid(void);
int   getegid(void);

/* Credential changes (P2).  The kernel enforces POSIX rules: root sets real,
 * effective and saved-set; a non-root caller may move only its EFFECTIVE id,
 * and only to its real or saved-set id.  Anything else fails with EPERM. */
int   setuid(int uid);
int   setgid(int gid);
int   seteuid(int uid);
int   setegid(int gid);

/* Time. */
int   sleep(int sec);

/* Password hashing.  NOT DES -- see the block comment above crypt() in
 * lib/libc_c/libc_c.c.  Returns a pointer to a static buffer that the next
 * call overwrites; callers strcpy out of it. */
char *crypt(char *key, char *salt);
/* The salt that produced a stored hash.  EVERY reader of /etc/passwd's hash
 * field needs this: passing the stored hash straight to crypt() is right for
 * an untagged DES hash and silently wrong for a tagged one, which is
 * apple/fgx#414. */
char *crypt_salt(char *hash);

/* getpass(3) -- 2.11BSD's (libc_c/getpass.c): read a line from /dev/tty, or
 * stdin when it cannot be opened, with echo off and the stream unbuffered,
 * printing `prompt` first.  Returns a pointer to a static buffer the next
 * call overwrites, truncated to _PASSWORD_LEN. */
#define _PASSWORD_LEN 32
char *getpass();

/* mktemp(3)/mkstemp(3) -- turn a "...XXXXXX" template into a unique name.
 * mkstemp returns an open fd (O_CREAT|O_EXCL, so the name is claimed
 * atomically); mktemp returns the template, or NULL, and only tells you the
 * name was free a moment ago.  BOTH REWRITE THE TEMPLATE IN PLACE, so it must
 * be writable storage, never a string literal.  ProDOS caps a basename at 15
 * characters. */
char *mktemp(char *template);
int   mkstemp(char *template);

/* ftruncate(2)/truncate(2) -- set a file's LENGTH.  Shorter hides the tail
 * from read(2) and stat(2); longer extends it with zeros; the file offset is
 * NOT moved.  ProDOS EOF is 24-bit, so a length above 16 MB gives EINVAL.
 * The blocks a shrink orphans are not returned to the volume until the file is
 * unlinked (apple/fgx#68) -- length semantics are exact, free space is not. */
int   ftruncate(int fd, long length);
int   truncate(char *path, long length);

/* chown(2) -- set a file's owner and group.  -1 in either field leaves that
 * one alone, which is the same -1 the kernel's vattr uses for "not set".  It
 * does NOT follow a final symlink; chmod(2) does.  See chown(2). */
int   chown(char *path, int uid, int gid);
/* fchown(2), fchmod(2) -- chown(2) and chmod(2) on an open file's descriptor. */
int   fchown(int fd, int uid, int gid);
int   fchmod(int fd, int mode);

/* getgroups(2).  FGX has ONE group per process (sys/param.h: NGROUPS 1), so
 * this answers 1 and the effective gid; a zero length asks HOW MANY, which is
 * 2.11BSD's convention.  setgroups(2) is still absent: installing a LIST needs
 * a kernel that can hold one. */
int   getgroups();

/* getlogin(3)/setlogin(2).  The SESSION's login name -- the one the terminal
 * logged in as, which survives fork, exec and su(1).  It lives in the u-area
 * (2.11BSD h/user.h:143) and setlogin is super-user only, which is upstream's
 * own rule for a kernel with no sessions.  getlogin answers NULL when nothing
 * ever set one: the primary console runs init's shell with no login(1). */
char *getlogin();
int   setlogin();

/* Not provided by the FGX libc (declare + implement in libc before use):
 *   fchdir.  Also absent: setgroups -- installing a supplementary LIST needs a
 *   kernel that can hold one; see the credentials plan §6.
 */

#endif /* _UNISTD_H */
