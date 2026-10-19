/* H1: BSD getopt(3) in the pile — flag bundling, '--' terminator, ':'
 * options with attached and separate arguments, '?' on unknown (opterr
 * suppressed), optind landing on the first operand.  Host clang
 * cross-checks against its own getopt.  6+6+6+6+6+6+6 = 42. */
#include <stdlib.h>
#ifndef __FGX__
#include <unistd.h>              /* host: getopt lives here */
#endif

int streq(char *s, char *t)
{
    int i = 0;
    while (s[i] && s[i] == t[i]) i++;
    return s[i] == t[i];
}

char *av[8];

int main(void)
{
    int r = 0, c, la = 0, xf = 0, of = 0, bad = 0, done = 0;

    av[0] = "prog"; av[1] = "-la"; av[2] = "-o"; av[3] = "out.txt";
    av[4] = "-zfattach"; av[5] = "--"; av[6] = "-l"; av[7] = 0;
    opterr = 0;
    while ((c = getopt(7, av, "alo:f:x")) != -1) {
        if (c == 'l') la |= 1;
        else if (c == 'a') la |= 2;
        else if (c == 'o') { if (streq(optarg, "out.txt")) of = 1; }
        else if (c == 'f') { if (streq(optarg, "attach")) xf = 1; }
        else if (c == '?') { if (optopt == 'z') bad = 1; }
        else done = -1;
    }
    if (la == 3)         r += 6;   /* bundled -la */
    if (of)              r += 6;   /* separate argument */
    if (xf)              r += 6;   /* attached argument */
    if (bad)             r += 6;   /* unknown flagged with optopt */
    if (done == 0)       r += 6;   /* no stray returns */
    if (optind == 6)     r += 6;   /* '--' consumed, lands on "-l" operand */
    if (streq(av[optind], "-l")) r += 6;
    return r;
}
