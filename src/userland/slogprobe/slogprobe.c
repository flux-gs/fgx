/* slogprobe - reboot(8)'s syslog line, in isolation, with the stack measured.
 *
 * FGX-Provenance: none
 *
 * apple/fgx#404.  `/sbin/reboot' prints its shutdown line with characters
 * corrupted -- `D-Fm>t: -; rebooted by rootD8m<' where the text is `reboot: -;
 * rebooted by root'.
 *
 * THE TAG IS NO LONGER COPIED, which changes what this probe rules out.  When it
 * was written, openlog() copied the ident into a 16-byte libc static, and that is
 * what excluded argv going stale underneath it.  The port of 2.11BSD's syslog.c
 * keeps upstream's `LogTag = ident' -- the caller's POINTER -- so a caller that
 * hands over a stack buffer, or frees the string, now has a dangling tag, and
 * that is a live way to produce this symptom rather than one already excluded.
 * The literal this probe passes cannot go stale, so its own assertion still
 * means what it meant.
 *
 * This runs the same three calls reboot(8) makes, in the same order, with
 * markers either side so a corrupted line is visible without a reboot to chase
 * it through, and reports its own stack high-water mark -- procinfo's stkhwm
 * against stksize -- because a hardware stack that overflows its per-binary
 * hint writes into whatever is below it, and strings are what that looks like.
 *
 * THE LINE IS READ BACK FROM WHERE syslogd(8) PUT IT, which is how the #404
 * corruption check survives syslog(3) reaching a socket rather than stderr.
 * reboot(8) logs LOG_AUTH|LOG_CRIT, and /etc/syslog.conf sends that to
 * /usr/adm/messages (`*.err;auth.notice;*.info;...'); this probe notes the
 * file's size before the call and then waits for a line past that offset that
 * carries the text EXACTLY -- `reboot: -; rebooted by <user>' -- so a corrupted
 * line never matches, and a daemon that is not running, or a syslog that never
 * reached it, times out.  syslogd owns /dev/log; this probe does not touch it.
 *
 * The console also shows the line, because the same conf sends *.crit to
 * /dev/console, so the needle the fixture asserts is SPLINE's own `found',
 * which only this probe prints and only on the exact match.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <syslog.h>
#include <pwd.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fgx.h>

struct procinfo plist[24];

#define MESSAGES "/usr/adm/messages"

static void stackreport(tag)
char *tag;
{
	int n, i, me;

	me = getpid();
	n = procs((char *)plist, 24);
	for (i = 0; i < n; i++)
		if (plist[i].pid == me) {
			printf("SP %s stksize=%d stkhwm=%d heaphwm=%u\n",
			       tag, plist[i].stksize, plist[i].stkhwm,
			       plist[i].heaphwm);
			return;
		}
	printf("SP %s NOT FOUND\n", tag);
}

/* Wait up to `secs' for a line of MESSAGES, past byte `from', that holds
 * `want'.  Prints it as SPLINE and answers 1, or answers 0 at the deadline. */
static int
findline(from, want, secs)
long from;
char *want;
int secs;
{
	FILE *fp;
	char  line[256];

	while (secs-- > 0) {
		if ((fp = fopen(MESSAGES, "r")) != NULL) {
			(void)fseek(fp, from, 0);
			while (fgets(line, sizeof line, fp) != NULL)
				if (strstr(line, want) != NULL) {
					printf("SPLINE found: %s", line);
					(void)fclose(fp);
					return (1);
				}
			(void)fclose(fp);
		}
		sleep(1);
	}
	return (0);
}

/* The run of `x' that follows want in the log, or -1 if want never appears.
 * findline cannot measure it: its fgets reads a long line in pieces. */
static int
xrun(from, want, secs)
long from;
char *want;
int secs;
{
	FILE *fp;
	int   c, m, n, len;

	len = strlen(want);
	while (secs-- > 0) {
		if ((fp = fopen(MESSAGES, "r")) != NULL) {
			(void)fseek(fp, from, 0);
			m = 0;
			while ((c = getc(fp)) != EOF) {
				if (m < len) {
					m = c == want[m] ? m + 1 : c == want[0];
					continue;
				}
				for (n = 0; c == 'x'; c = getc(fp))
					n++;
				(void)fclose(fp);
				return (n);
			}
			(void)fclose(fp);
		}
		sleep(1);
	}
	return (-1);
}

int
main(argc, argv)
	int argc;
	char **argv;
{
	struct passwd *pw;
	struct stat    sb;
	char          *user;
	char           want[64];
	long           from;

	printf("SPSTART\n");
	stackreport("entry");

	user = getlogin();
	printf("SP getlogin=%s\n", user ? user : "(null)");
	if (user == (char *)0 && (pw = getpwuid(getuid())))
		user = pw->pw_name;
	if (user == (char *)0)
		user = "root";
	printf("SP user=%s\n", user);
	stackreport("afterpw");

	from = stat(MESSAGES, &sb) == 0 ? sb.st_size : 0L;

	openlog("reboot", 0, LOG_AUTH);
	printf("SPBEFORE\n");
	syslog(LOG_CRIT, "%s; %s by %s", "-", "rebooted", user);
	printf("SPAFTER\n");
	stackreport("exit");
	closelog();

	/* Nothing here has printed the message text: the needle can only come
	 * out of the file, through syslogd. */
	sprintf(want, "reboot: -; rebooted by %s", user);
	if (!findline(from, want, 20)) {
		printf("SP FAIL not-in-messages after 20s\n");
		return (1);
	}

	/* A MESSAGE LONGER THAN syslog(3)'s LINE BUFFER IS CUT AT IT.  The buffer
	 * is 640 bytes, two of them kept for LOG_CONS's "\r\n", and this message
	 * is 1,399: bounded, the line carries 637 bytes less its "<13>" date and
	 * "SPBIG: " head, 610 `x's.  Unbounded, the message runs past the buffer
	 * into fmt_cpy, the format vsprintf is still reading, so it reads its own
	 * `x's back as text and runs away through the bank: this probe never
	 * prints again. */
	{
		static char big[1400];
		int         n;

		memset(big, 'x', sizeof big - 1);
		openlog("SPBIG", 0, LOG_USER);
		syslog(LOG_NOTICE, "%s", big);
		closelog();
		n = xrun(from, "SPBIG: ", 20);
		printf("SP bigline x=%d\n", n);
		if (n <= 0 || n >= 640) {
			printf("SP FAIL long-line\n");
			return (1);
		}
	}
	printf("SPDONE\n");
	return (0);
}
