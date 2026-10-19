/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- logwtmp(3): one record appended to /etc/wtmp -------------------------
 * FGX-Provenance: 2.11BSD usr.lib/libutil/logwtmp.c (5.3 (Berkeley) 4/2/89)
 *   vendored at vendor/2.11BSD/usr/usr.lib/libutil/logwtmp.c.  Copyright (c)
 *   1988 The Regents of the University of California.  All rights
 *   reserved.  UCB notice retained per the BSD license; FGX changes are
 *   BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * Upstream's body.  The append is O_APPEND with no O_CREAT: accounting is on
 * exactly when /etc/wtmp exists.  A short write is cut back off with
 * ftruncate so a half record never desynchronises the file's readers.
 * Callers: init(8) and telnetd(8) after a logout(3) that cleared a live utmp
 * record (`if (logout(line)) logwtmp(line, "", "")', as 2.11BSD's rlogind
 * does), and init for the `~' reboot and shutdown records.
 */
#include <fcntl.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <utmp.h>

void logwtmp(line, name, host)
    char *line, *name, *host;
{
    struct utmp ut;
    struct stat buf;
    int fd;

    if ((fd = open(_PATH_WTMP, O_WRONLY|O_APPEND, 0)) < 0)
        return;
    if (!fstat(fd, &buf)) {
        (void)strncpy(ut.ut_line, line, sizeof(ut.ut_line));
        (void)strncpy(ut.ut_name, name, sizeof(ut.ut_name));
        (void)strncpy(ut.ut_host, host, sizeof(ut.ut_host));
        (void)time(&ut.ut_time);
        if (write(fd, (char *)&ut, sizeof(struct utmp)) !=
            sizeof(struct utmp))
            (void)ftruncate(fd, buf.st_size);
    }
    (void)close(fd);
}
