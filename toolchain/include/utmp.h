/* FGX libc -- utmp.h.  BSD login accounting: the /etc/utmp record and the
 * login(3)/logout(3) pair that maintains it.
 *
 * One record per /etc/ttys line, indexed by ttyslot(3), so record 0 is never
 * used and a line keeps its place.  Written by login(1), blanked by whoever
 * owns the line when the session ends.  Read by who(1), w(1) and tcsh's
 * `watch'.
 *
 * THE FIELDS ARE 2.11BSD's IN ORDER BUT NOT IN WIDTH.  usr/include/utmp.h has
 * the same four in the same sequence; its UT_NAMESIZE is 15 where this is 8,
 * so the record is 36 bytes rather than 2.11BSD's 43.  FGX writes and reads
 * its own /etc/utmp and nothing exchanges the file, so what matters is that
 * the one number is stated: a login name longer than 8 characters is
 * truncated in the record, and every name in the shipped /etc/passwd fits.
 *
 * A wtmp accounting log is kept too, at _PATH_WTMP, for last(1) and ac(8):
 * login(3) appends a start record and logwtmp(3) the end record a caller writes
 * after a logout(3) that cleared one, so the file is the running history
 * who(1)/w(1) cannot show.  Appending is O_APPEND with no
 * O_CREAT, so accounting is on exactly when the file exists (FGX ships it empty)
 * -- remove /etc/wtmp to turn it off.
 */
#ifndef _UTMP_H
#define _UTMP_H

#define UT_NAMESIZE 8
#define UT_LINESIZE 8
#define UT_HOSTSIZE 16

struct utmp {
    char ut_line[UT_LINESIZE];  /* tty name */
    char ut_name[UT_NAMESIZE];  /* user id */
    char ut_host[UT_HOSTSIZE];  /* host name, if remote */
    long ut_time;               /* time entry was made */
};

/* login(3): write *ut at record ttyslot() of /etc/utmp (a caller whose terminal
 * is not a listed line gets no utmp record) and append it to /etc/wtmp.
 * logout(3): blank the live record for `line' (the bare name, "ttyp0", as
 * ut_line holds it); returns 1 if a utmp record was found.
 * logwtmp(3): append {line, name, host, now} to /etc/wtmp; the session-end
 * record is logwtmp(line, "", "").  ttyslot(3) is declared in <unistd.h>
 * beside the other descriptor-answering calls. */
void login(struct utmp *ut);
int  logout(char *line);
void logwtmp(char *line, char *name, char *host);

#define _PATH_UTMP  "/etc/utmp"
#define _PATH_WTMP  "/etc/wtmp"

#endif /* _UTMP_H */
