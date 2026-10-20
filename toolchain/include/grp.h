/* FGX libc -- grp.h.  The group database, getgrent(3).
 *
 * struct group IS 2.11BSD's, field for field (vendor/2.11BSD/usr/include/grp.h,
 * "grp.h 4.1 83/05/03"): a name, a password, a gid and a NULL-terminated member
 * vector.  Nothing is reordered or dropped -- ls(1) reads gr_name and fsck and
 * login can read the rest.
 *
 * `int gr_gid' AND NOT gid_t, which is upstream's own spelling here and not an
 * oversight of ours: the 4.1 header predates gid_t and every caller compares it
 * against an int. Kept so a port that assigns between the two compiles without
 * a cast.
 *
 * K&R prototypes (unspecified args) to match the port's call sites, as pwd.h
 * does two files over.
 */
#ifndef _GRP_H
#define _GRP_H

struct group {                  /* see getgrent(3) */
    char    *gr_name;
    char    *gr_passwd;
    int      gr_gid;
    char   **gr_mem;
};

struct group *getgrent();
struct group *getgrgid();
struct group *getgrnam();
void          setgrent();
void          endgrent();

/* getgrouplist(3) and initgroups(3).  FGX has ONE group per process
 * (sys/param.h: NGROUPS 1), so both answer with the base gid alone -- see
 * libc_c/groups.c for why that is the accurate answer here and not a stub. */
int           getgrouplist();
int           initgroups();

#endif
