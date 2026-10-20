/* dstest.c — FS create-date stamp probe (2026-07-06 quick-win).
 *
 * _fop_create now stamps ProDOS create+mod date/time from the RTC
 * (previously the $15..$24 zero-fill left them 0, so every FGX-created file
 * stat'ed as st_mtime 0).  Create a file, stat it, and cross-check the
 * synthesized st_mtime against time(2) — both sides share _libc_epoch, so
 * this proves the RTC-read -> ProDOS-pack -> epoch-unpack round trip.
 * ProDOS mod-time has minute granularity, hence the +/- slack.
 *
 * rc=42 pass; 2..7 identify the failing stage.
 */
#include <sys/stat.h>

extern long time();
extern int creat(char *path, int mode);
extern char *strcpy(char *dst, char *src);
extern int close(int fd);
extern int unlink(char *path);

char pathbuf[24];

int main()
{
	struct stat sb;
	int fd;
	long now;

	strcpy(pathbuf, "/tmp/dstest1");
	fd = creat(pathbuf, 0644);
	if (fd < 0) return 2;
	close(fd);
	if (stat(pathbuf, &sb) != 0) return 3;
	unlink(pathbuf);                          /* no leaked temp files */
	now = time(0);
	if (sb.st_mtime == 0) return 4;           /* not stamped at all */
	if (sb.st_mtime < 1577836800) return 5;    /* pre-2020: packing bogus */
	if (sb.st_mtime > now + 120) return 6;     /* stamped in the future */
	if (now - sb.st_mtime > 600) return 7;     /* stamped >10 min ago */
	return 42;
}
