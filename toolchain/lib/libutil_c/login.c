/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- login(3): the line's /etc/utmp record and its wtmp start record -----
 * 4.3BSD-Reno libutil/login.c; 2.11BSD usr.lib/libutil/login.c is the same
 * interface.
 *
 * The record goes at ttyslot(3) of /etc/utmp, and the same record is appended
 * to /etc/wtmp for last(1) and ac(8).  The append is O_APPEND with NO O_CREAT,
 * upstream's switch: accounting is on exactly when /etc/wtmp exists.
 */
#include <fcntl.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <utmp.h>

/* Append *ut to the wtmp accounting log.  O_APPEND and NO O_CREAT is upstream's
 * own switch (libutil/login.c): the record lands iff /etc/wtmp already exists,
 * so accounting is enabled by the file's presence and login keeps working when
 * it is gone.  login(3)'s session-start record; the end record and init's `~'
 * records are logwtmp(3)'s. */
static void _ut_wtmp(ut)
    struct utmp *ut;
{
    int fd;

    fd = open(_PATH_WTMP, O_WRONLY | O_APPEND, 0);
    if (fd < 0)
        return;                         /* no wtmp: accounting off */
    (void)write(fd, (char *)ut, sizeof(struct utmp));
    close(fd);
}

void login(ut)
    struct utmp *ut;
{
    long off;
    int fd, tty;

    /* THE UTMP RECORD at ttyslot(), 1-based, so record 0 is never used and a
     * line keeps its place across boots.  The multiply is done in LONG:
     * upstream's `(long)(tty * sizeof(struct utmp))' promotes after the fact,
     * and int is 16 bits here.  Seeking past EOF is upstream's own way of
     * reaching a record the file has not grown to yet -- the gap is a hole and
     * reads as zeroes, which is a blank record (M37/seekrw arm 1).  A caller
     * whose terminal is not a listed line (ttyslot() == 0) gets no utmp record
     * but is still written to wtmp below -- upstream files wtmp unconditionally,
     * which is why the early return this once had is gone. */
    tty = ttyslot();
    if (tty > 0 && (fd = open(_PATH_UTMP, O_WRONLY | O_CREAT, 0644)) >= 0) {
        off = (long)tty * (long)sizeof(struct utmp);
        if (lseek(fd, off, SEEK_SET) == off)
            write(fd, (char *)ut, sizeof(struct utmp));
        close(fd);
    }

    /* THE WTMP RECORD, the half login.c used to drop: the same login record,
     * appended to the accounting log for last(1) and ac(8). */
    _ut_wtmp(ut);
}

