/* ---- passwd database (/etc/passwd) ---------------------------------------
 * A REAL flat-file database, not the synthetic single entry pwd.h used to
 * describe.  login/getty want the actual fields, so the struct is the 2.11BSD
 * shape and the file is the classic SEVEN-field format:
 *
 *     name:passwd:uid:gid:gecos:dir:shell
 *
 * Note the 2.11BSD libc's own scanpw() parses TEN fields, splitting
 * class/change/expire in between gid and gecos -- that is the MASTER passwd
 * shape (its normal path is ndbm; scanpw is the fallback).  The actual
 * /etc/passwd in the vendored tree is 7-field ("root:*:0:1:The Man:/:/bin/sh"),
 * so 7 is what is parsed here and scanpw's field order is deliberately NOT
 * copied.  pw_class/pw_change/pw_expire exist for API compatibility and read
 * back ""/0.
 *
 * The returned struct points into a static line buffer and stays valid until the
 * next call -- the BSD contract, so callers that strcpy out of it are unchanged.
 * As an FGX tolerance (BSD does not do this) blank lines and '#' comments are
 * skipped, so the shipped file can document its own format. */
#define _PW_LINEMAX 256

static FILE         *_pw_fp;
static struct passwd _pw_passwd;
static char          _pw_line[_PW_LINEMAX];

/* One colon-delimited field, advancing *bp.  This is strsep(&bp, ":"), which FGX
 * libc does not have; inlined rather than adding a public strsep whose only
 * caller would be this file. */
static char *_pw_field(char **bp)
{
    char *s = *bp;
    char *p;

    if (s == (char *)0)
        return (char *)0;
    for (p = s; *p != '\0' && *p != ':'; p++)
        ;
    if (*p == ':') {
        *p  = '\0';
        *bp = p + 1;
    } else {
        *bp = (char *)0;          /* last field */
    }
    return s;
}


int setpwent()
{
    if (_pw_fp != (FILE *)0)
        (void)fclose(_pw_fp);
    _pw_fp = fopen(_PATH_PASSWD, "r");
    return _pw_fp != (FILE *)0;
}

/* setpassent(3) -- 2.11BSD.  Rewind the database and, if `stayopen' is set,
 * keep it open across getpw* calls so a run of lookups costs one open.
 *
 * FGX HOLDS THE FILE OPEN EITHER WAY.  getpwnam/getpwuid here call setpwent
 * and endpwent around each search, so the flag has nothing to switch off; what
 * this does provide is upstream's REWIND, which is the half callers depend on
 * -- fsck calls setpassent(1) once at startup before any lookup.  Returns 1 on
 * success, 0 if the database cannot be opened, as upstream does. */
int setpassent(stayopen)
int stayopen;
{
    (void)stayopen;
    return (setpwent());
}

void endpwent()
{
    if (_pw_fp != (FILE *)0) {
        (void)fclose(_pw_fp);
        _pw_fp = (FILE *)0;
    }
}

struct passwd *getpwent()
{
    char *bp, *cp;

    if (_pw_fp == (FILE *)0 && !setpwent())
        return (struct passwd *)0;
    for (;;) {
        if (fgets(_pw_line, _PW_LINEMAX, _pw_fp) == (char *)0)
            return (struct passwd *)0;
        cp = strchr(_pw_line, '\n');
        if (cp != (char *)0)
            *cp = '\0';
        if (_pw_line[0] == '\0' || _pw_line[0] == '#')
            continue;                             /* FGX: blank / comment */
        bp = _pw_line;
        _pw_passwd.pw_name   = _pw_field(&bp);
        _pw_passwd.pw_passwd = _pw_field(&bp);
        cp = _pw_field(&bp);
        if (cp == (char *)0) continue;            /* short line: skip it */
        _pw_passwd.pw_uid = atoi(cp);
        cp = _pw_field(&bp);
        if (cp == (char *)0) continue;
        _pw_passwd.pw_gid = atoi(cp);
        _pw_passwd.pw_gecos = _pw_field(&bp);
        _pw_passwd.pw_dir   = _pw_field(&bp);
        _pw_passwd.pw_shell = _pw_field(&bp);
        if (_pw_passwd.pw_shell == (char *)0)
            continue;                             /* fewer than 7 fields */
        _pw_passwd.pw_class  = "";                /* not in a 7-field file */
        _pw_passwd.pw_change = 0L;
        _pw_passwd.pw_expire = 0L;
        return &_pw_passwd;
    }
}

struct passwd *getpwnam(nam)
    char *nam;
{
    struct passwd *pw;

    if (!setpwent())
        return (struct passwd *)0;
    while ((pw = getpwent()) != (struct passwd *)0)
        if (strcmp(nam, pw->pw_name) == 0)
            break;
    endpwent();               /* the line buffer outlives the close */
    return pw;
}

struct passwd *getpwuid(uid)
    int uid;
{
    struct passwd *pw;

    if (!setpwent())
        return (struct passwd *)0;
    while ((pw = getpwent()) != (struct passwd *)0)
        if (pw->pw_uid == uid)
            break;
    endpwent();
    return pw;
}
