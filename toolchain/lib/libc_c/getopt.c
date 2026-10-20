/* ---- getopt (H1) ----------------------------------------------------------
 * Classic BSD getopt(3): flag bundling (-la), '--' terminator, ':' options
 * with arguments (attached or separate), '?' + stderr message on unknown
 * (opterr gates it).  optind/optarg/opterr/optopt are the public cells —
 * fcc-emitted pile data, so user reads of the extern globals are proper
 * far accesses (no legacy 2-byte-cell trap).  Ends the era of every port
 * hand-rolling its option scan (man/ul/tput each did). */
int  optind = 1;
int  opterr = 1;
int  optopt;
char *optarg;
/* optreset -- 2.11BSD's getopt(3) extension, and the reason it exists is a
 * program that parses TWO argument vectors.  Upstream's own line is
 * `if (optreset || !*place)' with `optreset = 0' inside the reset
 * (usr/lib/libc/stdlib/getopt.c:66), so setting it makes the next call start
 * a fresh scan rather than continuing inside a bundled argument.
 *
 * WANTED BY mount(8), whose mount_ufs() opens `optind = optreset = 1' before
 * re-parsing the argv it was handed -- upstream runs it as a separate binary
 * with its own getopt state, and this port links it in, so the state is
 * genuinely shared and genuinely needs resetting.  Without it a second parse
 * resumes at __lc_optpos inside the first vector's last option. */
int  optreset;
static int __lc_optpos;                 /* cursor within a bundled arg */

int getopt(int argc, char **argv, char *ostr)
{
    char *arg, *oli;
    int c;

    optarg = (char *)0;
    if (optreset) {                     /* 2.11BSD getopt.c:66-67 */
        optreset    = 0;
        __lc_optpos = 0;
    }
    if (optind >= argc)
        return -1;                      /* EOF */
    arg = argv[optind];
    if (__lc_optpos == 0) {
        if (arg[0] != '-' || arg[1] == 0)
            return -1;                  /* non-option / bare "-" */
        if (arg[1] == '-' && arg[2] == 0) {
            optind++;                   /* "--" terminator */
            return -1;
        }
        __lc_optpos = 1;
    }
    c = arg[__lc_optpos] & 0xFF;
    optopt = c;
    oli = strchr(ostr, c);
    if (c == ':' || oli == 0) {
        if (opterr)
            fprintf(__lc_fptr(2), "%s: illegal option -- %c\n",
                      argv[0], c);
        __lc_optpos++;
        if (arg[__lc_optpos] == 0) { optind++; __lc_optpos = 0; }
        return '?';
    }
    if (oli[1] == ':') {                /* option takes an argument */
        if (arg[__lc_optpos + 1] != 0) {
            optarg = arg + __lc_optpos + 1;      /* attached: -ofile */
        } else {
            optind++;
            if (optind >= argc) {
                if (opterr)
                    fprintf(__lc_fptr(2),
                              "%s: option requires an argument -- %c\n",
                              argv[0], c);
                __lc_optpos = 0;
                return '?';
            }
            optarg = argv[optind];
        }
        optind++;
        __lc_optpos = 0;
        return c;
    }
    __lc_optpos++;
    if (arg[__lc_optpos] == 0) { optind++; __lc_optpos = 0; }
    return c;
}

