/* utmp.h -- FGX port shim for tcsh's `watch`/`who` (tc.who.c).  FGX is
 * single-user with no /etc/utmp login accounting; struct utmp exists so tcsh
 * compiles and the who-list degrades to empty. */
#ifndef _FGX_UTMP_H
#define _FGX_UTMP_H
#define UT_NAMESIZE 8
#define UT_LINESIZE 8
#define UT_HOSTSIZE 16
struct utmp {
    char ut_line[UT_LINESIZE];
    char ut_name[UT_NAMESIZE];
    char ut_host[UT_HOSTSIZE];
    long ut_time;
};
#define _PATH_UTMP "/etc/utmp"
#endif /* _FGX_UTMP_H */
