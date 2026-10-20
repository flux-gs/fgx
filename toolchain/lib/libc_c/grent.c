/* ---- group database (/etc/group) -----------------------------------------
 * PORTED FROM 2.11BSD's own getgrent.c (vendor/2.11BSD/usr/lib/libc/gen/
 * getgrent.c, "5.2 (Berkeley) 3/9/86"), which is four short functions over a
 * colon-delimited flat file:
 *
 *     name:passwd:gid:member,member,...
 *
 * Upstream's parse is a `grskip' that walks to a delimiter, NULs it and returns
 * the next byte; the member list is then the same walk over commas. That shape
 * is kept -- it is why gr_mem points into the line buffer rather than into
 * allocations, and why the returned struct stays valid only until the next
 * call, which is the BSD contract callers already expect.
 *
 * WHAT DIVERGES, and it is one thing: MAXGRP is 32 here and 200 upstream. The
 * vector is a static array of pointers and 200 of them is 800 bytes of a
 * userland data bank for a system whose /etc/group has four lines. Overflow is
 * handled exactly as upstream handles it -- members past the cap are dropped,
 * the vector stays NUL-terminated -- so the behaviour differs only past a
 * group this system cannot have.
 *
 * As an FGX tolerance (BSD does not do this) blank lines and '#' comments are
 * skipped, matching pwent.c above so the shipped file can document its format.
 */
#define _GR_LINEMAX 256
#define MAXGRP      32

static FILE        *_gr_fp;
static struct group _gr_group;
static char         _gr_line[_GR_LINEMAX];
static char        *_gr_mem[MAXGRP];

/* Upstream's grskip: walk to `c', NUL it, return the byte after. */
static char *_gr_skip(p, c)
register char *p;
register int   c;
{
    while (*p != '\0' && *p != c)
        ++p;
    if (*p != '\0')
        *p++ = '\0';
    return (p);
}

void setgrent()
{
    if (_gr_fp == (FILE *)0)
        _gr_fp = fopen("/etc/group", "r");
    else
        rewind(_gr_fp);
}

void endgrent()
{
    if (_gr_fp != (FILE *)0) {
        fclose(_gr_fp);
        _gr_fp = (FILE *)0;
    }
}

struct group *getgrent()
{
    register char  *p;
    register char **q;

    if (_gr_fp == (FILE *)0 && (_gr_fp = fopen("/etc/group", "r")) == (FILE *)0)
        return ((struct group *)0);
    for (;;) {
        if ((p = fgets(_gr_line, sizeof(_gr_line) - 1, _gr_fp)) == (char *)0)
            return ((struct group *)0);
        if (*p != '\0' && *p != '#' && *p != '\n')
            break;
    }
    _gr_group.gr_name   = p;
    _gr_group.gr_passwd = p = _gr_skip(p, ':');
    _gr_group.gr_gid    = atoi(p = _gr_skip(p, ':'));
    _gr_group.gr_mem    = _gr_mem;
    p = _gr_skip(p, ':');
    _gr_skip(p, '\n');
    q = _gr_mem;
    while (*p != '\0') {
        if (q < &_gr_mem[MAXGRP - 1])
            *q++ = p;
        p = _gr_skip(p, ',');
    }
    *q = (char *)0;
    return (&_gr_group);
}

struct group *getgrgid(gid)
int gid;
{
    register struct group *g;

    setgrent();
    while ((g = getgrent()) != (struct group *)0)
        if (g->gr_gid == gid)
            return (g);
    return ((struct group *)0);
}

struct group *getgrnam(name)
char *name;
{
    register struct group *g;

    setgrent();
    while ((g = getgrent()) != (struct group *)0)
        if (strcmp(g->gr_name, name) == 0)
            return (g);
    return ((struct group *)0);
}
