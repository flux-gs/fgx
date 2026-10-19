/* utimetest — SYS_UTIME round-trip check (Phase 2b test vector).
 *
 * Sets a file's mod time to a fixed, minute-aligned epoch via utimes(), reads
 * it back with stat(), and verifies the value survives the
 * epoch -> ProDOS-packed-date -> epoch conversion EXACTLY.  ProDOS mod time is
 * minute-granular (no seconds) and spans 1940..2039, so a minute-aligned epoch
 * in that window is a lossless round-trip: stat's st_mtime must equal what
 * utimes was handed.  500000040 = 1985-11-05 00:54:00 UTC.
 *
 * Test-only (/testbin); the real utimes() consumer is tar(1).
 */
#include <sys/stat.h>
#include <sys/time.h>
#include <stdio.h>

int main(argc, argv)
	int argc;
	char **argv;
{
	struct timeval tv[2];
	struct stat sb;
	long want;

	if (argc < 2) {
		printf("usage: utimetest file\n");
		return 1;
	}
	want = 500000040L;                     /* minute-aligned: 1985-11-05 00:54 */
	tv[0].tv_sec = want; tv[0].tv_usec = 0;
	tv[1].tv_sec = want; tv[1].tv_usec = 0;

	if (utimes(argv[1], tv) < 0) {
		printf("UTIMES_FAIL\n");
		return 1;
	}
	if (stat(argv[1], &sb) < 0) {
		printf("STAT_FAIL\n");
		return 1;
	}
	printf("mtime=%ld want=%ld\n", sb.st_mtime, want);
	printf(sb.st_mtime == want ? "UTIME_OK\n" : "UTIME_MISMATCH\n");
	return 0;
}
