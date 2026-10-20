/* c33_statmtime.c — stat(2) st_mtime/st_ctime epoch synthesis from the raw
 * ProDOS date/time words in the native SYS_STAT image (c_stat translate,
 * 2026-07-06 quick-win).  /etc/hostname is stamped by cadius at image build
 * time, so its mtime is a real recent epoch — written through the caller's
 * SOFT-STACK struct via the bank-carrying [_fcc_ptr]. */
#include <sys/stat.h>

int c33_check(void)
{
	struct stat sb;

	sb.st_mtime = 0;
	sb.st_ctime = 0;
	if (stat("/etc/hostname", &sb) != 0) return 0;
	if (sb.st_mtime < 1500000000) return 0;   /* image stamped before 2017?! */
	if (sb.st_mtime > 2100000000) return 0;
	return sb.st_ctime == sb.st_mtime;
}
