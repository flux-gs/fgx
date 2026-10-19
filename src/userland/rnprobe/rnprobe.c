/* rnprobe -- bisect rename(2).  TEST-ONLY (/testbin).
 *
 * mv(1) is unusable because rename(2) never takes effect (apple/fgx#29), and
 * every shell-level probe of it so far has been vacuous: a `;` separator makes
 * the marker print regardless, and a literal marker string can be matched from
 * the command line the shell ECHOES.  This probe removes both traps.  Its only
 * file operations are the ones mv performs, each bracketed by a marker written
 * with write(2) directly -- no stdio buffering, no shell, and the markers are
 * NOT present in the command line that invokes it.
 *
 *   rnprobe FROM TO
 */
#include <sys/stat.h>
#include <errno.h>

static int say(s, n)
	char *s;
	int n;
{
	return write(2, s, n);
}

int main(argc, argv)
	int argc;
	char **argv;
{
	struct stat s1, s2;
	int r;

	if (argc < 3) {
		say("usage\n", 6);
		return 1;
	}
	say("<p1>\n", 5);
	if (stat(argv[1], &s1) < 0) {
		say("<nosrc>\n", 8);
		return 1;
	}
	say("<p2>\n", 5);
	if (stat(argv[2], &s2) >= 0)
		say("<dsthere>\n", 10);
	else
		say("<dstgone>\n", 10);
	say("<p3>\n", 5);
	r = rename(argv[1], argv[2]);
	say("<p4>\n", 5);
	if (r >= 0) {
		say("<renyes>\n", 9);
		return 0;
	}
	if (errno == EXDEV)
		say("<exdev>\n", 8);
	else
		say("<renerr>\n", 9);
	return 1;
}
