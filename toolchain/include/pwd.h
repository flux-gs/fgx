/* FGX libc — pwd.h.  The REAL passwd database, read from /etc/passwd.
 *
 * struct passwd is the 2.11BSD shape, field-for-field (usr/include/pwd.h in the
 * vendored tree), so BSD ports compile unmodified and login/getty have the
 * fields they need rather than a synthetic subset.  It replaced an earlier
 * 4-field synthetic struct whose comment said "FGX is single-user with no
 * /etc/passwd" -- that is no longer true.
 *
 * The file format is the classic 7-colon-field 2.11BSD /etc/passwd:
 *     name:passwd:uid:gid:gecos:dir:shell
 * pw_class/pw_change/pw_expire exist in the struct for API compatibility (4.4BSD
 * added them) but are NOT in the file, so they read back "" / 0.  The 2.11BSD
 * libc reaches this database through ndbm with a flat-file fallback; FGX has no
 * ndbm, so only the flat-file path is ported -- which is the fallback's own
 * scanpw() parsing, kept faithful.
 */
#ifndef _PWD_H
#define _PWD_H

#define _PATH_PASSWD    "/etc/passwd"

struct passwd {
    char *pw_name;      /* user name */
    char *pw_passwd;    /* encrypted password */
    int   pw_uid;       /* user uid */
    int   pw_gid;       /* user gid */
    long  pw_change;    /* password change time (not in the file: 0) */
    char *pw_class;     /* user access class    (not in the file: "") */
    char *pw_gecos;     /* Honeywell login info */
    char *pw_dir;       /* home directory */
    char *pw_shell;     /* default shell */
    long  pw_expire;    /* account expiration   (not in the file: 0) */
};

struct passwd *getpwent();
struct passwd *getpwuid();
struct passwd *getpwnam();
int  setpwent();
void endpwent();


int setpassent(int stayopen);

#endif /* _PWD_H */
