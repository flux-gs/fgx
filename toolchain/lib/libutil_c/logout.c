/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- logout(3): blank the line's live /etc/utmp record ---------------------
 * 4.3BSD-Reno libutil/logout.c; 2.11BSD usr.lib/libutil/logout.c is the same
 * interface.
 *
 * Writes no wtmp: the session-end record is the caller's logwtmp(3), made only
 * when logout found a live record (`if (logout(line)) logwtmp(line, "", "")').
 */
#include <fcntl.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <utmp.h>

/* logout(3) returns to the record it just read with upstream's own RELATIVE
 * seek, `(void)lseek(fd, -(long)sizeof(UTMP), L_INCR)'.  The write then leaves
 * the descriptor at the start of the NEXT record, which is where the
 * sequential read resumes -- the same place upstream's leaves it.
 *
 * A backwards SEEK_CUR is expressible because lseek(2) carries a signed 32-bit
 * off_t; M37/seekrw arm 4 is this sequence. */
static struct utmp _ut_rec;             /* data bank: the record under edit,
                                         * not an fcc local (a local aggregate
                                         * lands on the bank-0 stack) */

int logout(line)
    char *line;
{
    int fd, rval;

    rval = 0;
    fd = open(_PATH_UTMP, O_RDWR, 0);
    if (fd >= 0) {
        while (read(fd, (char *)&_ut_rec, sizeof(struct utmp))
               == sizeof(struct utmp)) {
            if (_ut_rec.ut_name[0] == '\0'
             || strncmp(_ut_rec.ut_line, line, UT_LINESIZE) != 0)
                continue;
            memset(_ut_rec.ut_name, 0, UT_NAMESIZE);
            memset(_ut_rec.ut_host, 0, UT_HOSTSIZE);
            _ut_rec.ut_time = time((long *)0);
            (void)lseek(fd, -(long)sizeof(struct utmp), SEEK_CUR);
            (void)write(fd, (char *)&_ut_rec, sizeof(struct utmp));
            rval = 1;
        }
        close(fd);
    }
    return rval;
}
