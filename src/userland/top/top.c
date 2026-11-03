/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) Dave Plummer
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: davepl/pdpsrc bsd/top (commit f489ca9), Dave Plummer's
 *   top for 2.11BSD; vendor/pdpsrc/bsd/top/top.c.  Its author states his
 *   pdpsrc code is BSD-2-Clause.
 *
 * Upstream's display, sorting, keys and timing are kept as written.  What
 * changes is where the numbers come from: upstream reads the proc table,
 * cp_time and each u-area through nlist(3), /dev/kmem, /dev/mem and
 * /dev/swap, which FGX does not have (apple/fgx#538).  Here:
 *   - the process table is procs(2), one fixed record per process with its
 *     uid, priority and user and system ticks (struct procinfo, <fgx.h>);
 *   - cp_time is the vm.cp_time sysctl, the clock rate kern.clockrate;
 *   - memory is vm.meter's resident and free pages: FGX has no hw.physmem;
 *   - swap is reported as absent: FGX has none.
 * A record is read in one call, so upstream's second validation read and
 * its unavailable/swapped states have no counterpart.  FGX keeps no nice
 * value (setpriority(2) stores nothing) and no text size or start time per
 * process, so NI is 0, TEXT is `-', DATA is the heap's high-water break
 * and STACK the reserved bank-0 stack.  A slot's history is keyed by pid
 * and accepts only a growing tick count, in place of upstream's pid plus
 * u_start.
 */
/*
 * top -- a process monitor for 2.11BSD on the PDP-11.
 *
 * Written for the native 2.11BSD C compiler and termcap.
 * The kernel interfaces were checked against this system's ps(1), vmstat(1)
 * and the 2.11BSD top by Digby Tarvin and its subsequent contributors.
 * The presentation follows the supplied mentec terminal reference.
 */
#include <sys/param.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <sys/vmparam.h>
#include <sys/vmmeter.h>
#include <sys/dk.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <sys/signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <pwd.h>
#include <utmp.h>
#include <sgtty.h>
#include <fgx.h>
#include "screen.h"
#include "format.h"

#define FIRSTPROC 7
#define NCACHE 32
#define MAXCOMLEN (PROC_NAME_MAX - 1)
#define NPROCREC 33             /* the kernel's record and NPROC tasks */

/* Three views keep sampling separate from presentation:
 * - procs is one snapshot of the kernel's fixed-size process slots;
 * - rows contains only occupied slots, enriched with user-area accounting;
 * - history remembers the previous identity and CPU time for each slot.
 * A slot can be reused. PID plus start time prevents charging the new
 * process for CPU time accumulated by its previous occupant. */
struct row {
    short pid, uid, pri, nice;
    unsigned short text, data, stack;
    unsigned short slot, address; /* identity/location for final validation */
    char state, swapped, valid;
    long ticks, delta, start;
    char command[MAXCOMLEN + 1];
};

struct history {
    short pid;
    char valid;
    long ticks, start;
};

struct username {
    short uid;
    char valid, name[9];
};

static struct procinfo *procs;
static struct row *rows;
/* qsort moves two-byte indices, not the much larger process records. */
static unsigned short *row_index;
static struct history *history;
static struct username names[NCACHE];
static unsigned int nproc;
static unsigned int row_capacity;
static int hz, count, running, sleeping, stopped, zombies;
static int order = 9, showidle = 1, limit = 0;
static volatile int want_quit, want_resize;
static int help_on;
static int name_next;
static long delay_us = 1000000L;
static unsigned long cpu_old[CPUSTATES];
static unsigned int cpu[CPUSTATES];
/* The first screen has totals but no elapsed interval to compare yet. */
static int interval_valid;
static unsigned long totalmem, free_memory, totalswap, freeswap;
static struct timeval boottime;
static char hostname[64];
static char error_text[160];
static char status_text[160];

/* Native cc reserves dedicated local registers only for explicit register
 * declarations. Its three word registers suit frequently reused loop indices
 * and pointers; using them avoids repeated stack accesses in these paths. */
static int sample(), compare(), keywait();
static void draw(), putrow(), usage();

static int
getvalue(group, item, buf, size)
int group, item;
char *buf;
size_t size;
{
    int mib[2];
    size_t got;
    mib[0] = group;
    mib[1] = item;
    got = size;
    /* 2.11BSD returns the byte count on success, unlike newer BSDs. */
    return sysctl(mib, 2, buf, &got, NULL, 0) >= 0 && got == size;
}

/* The tables are sized once, for every record procs(2) can return. */
static int
setup()
{
    struct clockinfo ci;
    unsigned int i;

    nproc = NPROCREC;
    if (!getvalue(CTL_KERN, KERN_CLOCKRATE, (char *)&ci, sizeof(ci)) ||
        ci.hz <= 0) {
        strcpy(error_text, "cannot read the kernel clock rate");
        return 0;
    }
    hz = ci.hz;
    row_capacity = nproc;
    procs = (struct procinfo *)malloc(nproc * sizeof(struct procinfo));
    rows = (struct row *)malloc(row_capacity * sizeof(struct row));
    history = (struct history *)calloc(nproc, sizeof(struct history));
    row_index = (unsigned short *)malloc(nproc * sizeof(*row_index));
    if (!procs || !rows || !history || !row_index) {
        strcpy(error_text, "not enough data space for process tables");
        return 0;
    }
    if (!getvalue(CTL_KERN, KERN_BOOTTIME,
            (char *)&boottime, sizeof(boottime))) {
        strcpy(error_text, "cannot obtain kernel boot time");
        return 0;
    }
    gethostname(hostname, sizeof(hostname) - 1);
    hostname[sizeof(hostname) - 1] = 0;
    for (i = 0; hostname[i]; i++) {
        if (hostname[i] == '.') {
            hostname[i] = 0;
            break;
        }
        if (hostname[i] < ' ' || hostname[i] > '~')
            hostname[i] = '?';
    }
    return 1;
}

/* Most rows share a handful of users. Cache their names so screen refresh
 * does not reopen the password database for every displayed process. */
static char *
username(uid)
short uid;
{
    register int i;
    struct passwd *pw;
    struct username *entry;
    for (i = 0; i < NCACHE; i++)
        if (names[i].valid && names[i].uid == uid)
            return names[i].name;
    entry = &names[name_next];
    name_next = (name_next + 1) % NCACHE;
    entry->uid = uid;
    entry->valid = 1;
    pw = getpwuid(uid);
    if (pw) {
        strncpy(entry->name, pw->pw_name, 8);
        entry->name[8] = 0;
        if (strlen(pw->pw_name) > 8)
            entry->name[7] = '+';
    } else
        sprintf(entry->name, "%u", (unsigned int)uid);
    return entry->name;
}

/* Collect a coherent-enough observation without stopping the system.
 * procs(2) copies every record in one call, so a row cannot describe two
 * different processes; a pid whose tick count went backwards is a reused
 * pid and starts over with no interval time. */
static int
sample(baseline)
int baseline;
{
    register unsigned int i;
    unsigned int j, n;
    unsigned long ticks[CPUSTATES], diff[CPUSTATES], sum, scaled, divisor;
    int wrapped_sum;
    struct vmtotal vt;
    register struct procinfo *p;
    register struct row *r;
    struct history *h;

    n = procs((char *)procs, nproc);
    if ((int)n <= 0 ||
        !getvalue(CTL_VM, VM_CPTIME, (char *)ticks, sizeof(ticks))) {
        strcpy(error_text, "kernel statistics read failed");
        return 0;
    }
    sum = 0;
    wrapped_sum = 0;
    for (i = 0; i < CPUSTATES; i++) {
        diff[i] = ticks[i] - cpu_old[i];
        cpu_old[i] = ticks[i];
        if (sum + diff[i] < sum) wrapped_sum = 1;
        sum += diff[i];
    }
    /* Tenths of a percent are enough for the screen. Integer arithmetic avoids
     * expensive floating conversion for each state on a 16-bit processor. */
    /* Forced refreshes can occur within one clock tick. Keep the last
     * measured ratio in that case: no new ticks is not a lost baseline. */
    if (baseline) interval_valid = 0;
    else if (sum > 0 || wrapped_sum) interval_valid = !wrapped_sum;
    if (!baseline && sum > 0 && !wrapped_sum) {
        for (i = 0; i < CPUSTATES; i++) {
            scaled = diff[i];
            divisor = sum;
            /* Unsigned subtraction handles a kernel counter wrapping once.
             * After a long suspension, scaling first could overflow. Reduce
             * both sides of the ratio together until *1000 fits in 32 bits. */
            /* 4294967 is the largest 32-bit unsigned value / 1000. */
            while (divisor > 4294967UL) { scaled >>= 1; divisor >>= 1; }
            cpu[i] = (unsigned int)(scaled * 1000UL / divisor);
        }
    }

    count = running = sleeping = stopped = zombies = 0;
    for (i = 0; i < nproc; i++)
        history[i].valid &= 1;  /* bit 0 valid last time, bit 1 seen now */
    for (i = 0; i < n; i++) {
        p = &procs[i];
        if (p->pid < 0 || p->pid >= (int)nproc)
            continue;
        h = &history[p->pid];
        r = &rows[count++];
        /* Every path below writes a terminated command string. Reset only
         * the scalar fields; clearing the unused tail of each command on
         * every refresh would not change any displayed character. */
        memset((char *)r, 0, (char *)r->command - (char *)r);
        r->pid = p->pid;
        r->uid = p->uid;
        r->slot = p->pid;
        switch (p->state) {
        case 3: r->state = 'S'; sleeping++; break;
        case 1: case 2: r->state = 'R'; running++; break;
        case 5: r->state = 'T'; stopped++; break;
        case 4: r->state = 'Z'; zombies++; break;
        default: r->state = '?'; sleeping++; break;
        }
        r->pri = p->pri;
        r->data = p->heaphwm;
        r->stack = p->stksize;
        r->valid = 1;
        r->ticks = p->utime + p->stime;
        if (h->valid && h->pid == r->pid && r->ticks >= h->ticks &&
            !baseline)
            r->delta = r->ticks - h->ticks;
        if (r->pid == 0)
            strcpy(r->command, "[kernel]");
        else if (r->state == 'Z')
            strcpy(r->command, "<defunct>");
        else {
            for (j = 0; j < MAXCOMLEN && p->name[j]; j++) {
                r->command[j] = p->name[j];
                if (r->command[j] < ' ' || r->command[j] > '~')
                    r->command[j] = '?';
            }
            r->command[j] = 0;
            if (j == 0)
                strcpy(r->command, "[unknown]");
        }
        h->valid = 3;
        h->pid = r->pid;
        h->ticks = r->ticks;
    }
    for (i = 0; i < nproc; i++)
        history[i].valid = history[i].valid == 3;
    /* vm.meter's pages are 256 bytes; t_free is already in kilobytes. */
    if (!getvalue(CTL_VM, VM_METER, (char *)&vt, sizeof(vt))) {
        strcpy(error_text, "cannot read memory totals");
        return 0;
    }
    free_memory = (unsigned long)vt.t_free * 1024L;
    totalmem = (unsigned long)vt.t_rm * 256L + free_memory;
    return 1;
}

/* Subtracting two 32-bit counters and returning a 16-bit int can overflow
 * or truncate to zero. Comparisons must return only -1, 0, or 1. */
static int
cmp_long(a, b)
long a, b;
{
    return a < b ? -1 : (a > b ? 1 : 0);
}

static int
compare(ai, bi)
unsigned short *ai, *bi;
{
    register struct row *a, *b;
    int n;
    a = &rows[*ai];
    b = &rows[*bi];
    n = 0;
    switch (order) {
    case 0: n = cmp_long((long)a->pid, (long)b->pid); break;
    case 1: n = cmp_long((long)a->uid, (long)b->uid); break;
    case 2: n = b->pri - a->pri; break;
    case 3: n = a->nice - b->nice; break;
    case 4: n = cmp_long((long)b->text, (long)a->text); break;
    case 5: n = cmp_long((long)b->data, (long)a->data); break;
    case 6: n = cmp_long((long)b->stack, (long)a->stack); break;
    case 7: n = a->state - b->state; break;
    case 9:
        n = cmp_long(b->delta, a->delta);
        if (n) break;
        /* Fall through: cumulative time breaks equal interval times. */
    case 8: n = cmp_long(b->ticks, a->ticks); break;
    case 10: n = strcmp(a->command, b->command); break;
    }
    if (!n) n = cmp_long((long)a->pid, (long)b->pid);
    return n;
}

static int
user_count()
{
    static FILE *f;
    struct utmp u;
    int n;
    n = 0;
    /* Login/logout update utmp records in place. Retain its open stream,
     * as the system top does, but reread the records on every refresh.
     * rewind discards buffered data and clears EOF; open/close plus buffer
     * allocation on every frame would add work without fresher records.
     * If the initial open failed, a later frame retries it. */
    if (f) rewind(f);
    else f = fopen(_PATH_UTMP, "r");
    if (f) {
        while (fread((char *)&u, sizeof(u), 1, f) == 1)
            if (u.ut_name[0]) n++;
    }
    return n;
}

/* Fixed-point decimal output avoids floating arithmetic in every process row.
 * This private helper accepts one or two decimal places and a positive
 * scale no greater than 32767 (the largest native clock frequency).
 * Callers provide 24 bytes, enough for a 32-bit value and its fraction.
 * Those scale bounds keep remainder * 100 + scale / 2 within 32 bits. */
/* Split before multiplying: scaling a large cumulative counter directly
 * could overflow 32 bits. Only the remainder is scaled, then rounded; a
 * carry such as 9.96 -> 10.0 is applied to the integer part explicitly. */
static char *
fixed(buf, value, scale, digits)
char *buf;
unsigned long value, scale;
int digits;
{
    unsigned long quotient, remainder;
    unsigned int base, fraction, small_quotient;
    register unsigned int n, small;
    char reversed[10];
    register char *out;

    base = digits == 2 ? 100 : 10;
    /* Quotient and remainder describe the same division: value = q*s + r.
     * This compiler does not combine / and % into one operation. Deriving
     * r by subtraction avoids repeating a software 32-bit divide. Since
     * q*s <= value, the multiplication itself cannot overflow. */
    /* These are the two memory units used by the display. Their powers of
     * two let shifts/masks do the same exact split without a library divide.
     * Division by one is an identity; bypassing it also avoids this system's
     * uldiv edge case for an unsigned quotient above the signed-long limit. */
    if (scale == 16) { quotient = value >> 4; remainder = value & 15; }
    else if (scale == 1024) { quotient = value >> 10; remainder = value & 1023; }
    else if (scale == 1) { quotient = value; remainder = 0; }
    else {
        quotient = value / scale;
        remainder = value - quotient * scale;
    }
    fraction = (remainder * base + scale / 2) / scale;
    value = quotient;
    if (fraction == base) { value++; fraction = 0; }

    /* A 32-bit unsigned integer needs at most ten decimal digits. Build
     * those digits backwards, then reverse them into the caller's buffer.
     * Avoiding a second printf format parse for EVERY numeric cell matters
     * more here than it would on a modern machine. This handles zero too. */
    n = 0;
    /* Most displayed integer parts fit in 16 bits. Use the wider divide
     * only while it is needed, then finish with native word arithmetic.
     * 65535 is the unsigned range limit on the target, not a display cap. */
    while (value > 65535UL) {
        quotient = value / 10;
        reversed[n++] = '0' + (value - quotient * 10);
        value = quotient;
    }
    small = (unsigned int)value;
    do {
        small_quotient = small / 10;
        reversed[n++] = '0' + (small - small_quotient * 10);
        small = small_quotient;
    } while (small);
    out = buf;
    while (n) *out++ = reversed[--n];
    *out++ = '.';
    if (digits == 2) *out++ = '0' + fraction / 10;
    *out++ = '0' + fraction % 10;
    *out = 0;
    return buf;
}

static void
putrow(y, text, reverse)
int y, reverse;
char *text;
{
    screen_row(y, text, reverse);
}

/* Cache only header formatting. Every call still reads the current time,
 * utmp user count and all three load averages. Those fresh values, the
 * load-query result and screen width are the complete changing key;
 * hostname and boot time were fixed by setup(). Thus a login, failed or
 * recovered query, clock tick or resize cannot reuse stale header text. */
static char *
header_text()
{
    static char text[256];
    static double previous_loads[3];
    static time_t previous_time;
    static int previous_users, previous_result, previous_cols, valid;
    char load[80];
    double loads[3];
    time_t now;
    struct tm *tm;
    long up;
    int users, result, days, hours, minutes;

    time(&now);
    users = user_count();
    loads[0] = loads[1] = loads[2] = 0.0;
    result = getloadavg(loads, 3);
    if (valid && now == previous_time && users == previous_users &&
            result == previous_result && screen_cols == previous_cols &&
            !memcmp((char *)loads, (char *)previous_loads, sizeof(loads)))
        return text;

    tm = localtime(&now);
    up = now - boottime.tv_sec;
    if (up < 0) up = 0;
    days = up / 86400L;
    hours = (up / 3600L) % 24;
    minutes = (up / 60L) % 60;
    if (result == 3)
        sprintf(load, "%.2f, %.2f, %.2f", loads[0], loads[1], loads[2]);
    else
        strcpy(load, "unavailable");
    sprintf(text, "%.16s - %02d:%02d:%02d up %2d days, %2d:%02d, %3d user%s,  load average: %s",
        hostname, tm->tm_hour, tm->tm_min, tm->tm_sec,
        days, hours, minutes, users, users == 1 ? "" : "s", load);
    if (strlen(text) >= screen_cols) {
        /* Both layouts reuse one conversion of the fresh load values. */
        sprintf(text, "%.8s %02d:%02d:%02d up %dd %d:%02d, %d user%s, load %s",
            hostname, tm->tm_hour, tm->tm_min, tm->tm_sec,
            days, hours, minutes, users, users == 1 ? "" : "s", load);
    }
    previous_time = now;
    previous_users = users;
    previous_result = result;
    previous_cols = screen_cols;
    memcpy((char *)previous_loads, (char *)loads, sizeof(loads));
    valid = 1;
    return text;
}

static void
draw()
{
    char line[256], field[4][24], *header;
    struct output_line row_text;
    register int i;
    int y, shown;
    register struct row *r;

    header = header_text();
    screen_begin();
    if (screen_rows < 9 || screen_cols < 40) {
        putrow(0, "top: enlarge terminal to at least 40x9", 0);
        putrow(1, "q quits; resize to continue", 0);
        screen_finish();
        return;
    }
    putrow(0, header, 0);
    sprintf(line, "Tasks:%4d total, %3d running, %4d sleeping, %3d stopped, %3d zombie",
        count, running, sleeping, stopped, zombies);
    putrow(1, line, 0);
    if (interval_valid)
        sprintf(line, "Cpu  : %5s%% us, %5s%% ni, %5s%% sy, %5s%% id",
            fixed(field[0], (unsigned long)cpu[0], 10L, 1),
            fixed(field[1], (unsigned long)cpu[1], 10L, 1),
            fixed(field[2], (unsigned long)cpu[2], 10L, 1),
            fixed(field[3], (unsigned long)cpu[3], 10L, 1));
    else strcpy(line, "Cpu  : waiting for interval sample");
    putrow(2, line, 0);
    sprintf(line, "Mem  : %7sK total, %7sK free, %7sK used (%2ld%%)",
        fixed(field[0], totalmem, 1024L, 1),
        fixed(field[1], free_memory, 1024L, 1),
        fixed(field[2], totalmem - free_memory, 1024L, 1),
        totalmem ? (totalmem - free_memory) * 100L / totalmem : 0L);
    putrow(3, line, 0);
    putrow(4, "Swap : none", 0);
    if (help_on) {
        putrow(5, "Keys: q quit  SPACE refresh  ^L redraw  I hide/show idle", 1);
        putrow(7, "s change refresh delay (seconds)   o choose sort column", 0);
        putrow(8, "P interval CPU time   T total CPU time   N PID   M data size", 0);
        putrow(10, "Order: 0 PID  1 UID  2 PR  3 NI  4 TEXT  5 DATA  6 STACK", 0);
        putrow(11, "       7 state  8 TIME  9 DTIME  10 COMMAND", 0);
        putrow(13, "TIME is user + system CPU seconds; DTIME is since last sample.", 0);
        putrow(14, "An s after state means swapped out. ? means unavailable data.", 0);
        putrow(16, "h or ? closes help. Terminal size changes are automatic.", 0);
    } else {
        putrow(5, status_text, 0);
        putrow(6, "  PID USER      PR  NI  TEXT  DATA STACK S     TIME   DTIME COMMAND ", 1);
        for (i = 0; i < count; i++) row_index[i] = i;
        qsort((char *)row_index, count, sizeof(*row_index), compare);
        shown = 0;
        for (i = 0, y = FIRSTPROC; i < count && y < screen_rows; i++) {
            r = &rows[row_index[i]];
            if (!showidle && r->delta == 0 && r->state != 'R') continue;
            if (limit && shown >= limit) break;
            /* The process-row layout never changes. Typed appends avoid
             * reparsing two printf formats for every process on every frame.
             * Each call still states the field width beside its value. */
            line_start(&row_text, line, sizeof(line));
            line_number(&row_text, r->pid, 5);
            line_character(&row_text, ' ');
            line_text(&row_text, username(r->uid), -8, 8);
            line_number(&row_text, r->pri, 4);
            line_number(&row_text, r->nice, 4);
            line_text(&row_text, "-", 6, 0);
            line_text(&row_text,
                fixed(field[0], (unsigned long)r->data, 1024L, 1), 5, 0);
            line_character(&row_text, 'K');
            line_text(&row_text,
                fixed(field[0], (unsigned long)r->stack, 1024L, 1), 5, 0);
            line_character(&row_text, 'K');
            line_character(&row_text, ' ');
            line_character(&row_text, r->state);
            line_character(&row_text, r->swapped ? 's' : ' ');
            if (r->valid) {
                line_text(&row_text,
                    fixed(field[0], (unsigned long)r->ticks,
                        (unsigned long)hz, 2), 8, 0);
                line_character(&row_text, ' ');
                line_text(&row_text, interval_valid ?
                    fixed(field[0], (unsigned long)r->delta,
                        (unsigned long)hz, 2) : "-", 7, 0);
            } else line_text(&row_text, "       ?       ?", 0, 0);
            line_character(&row_text, ' ');
            line_text(&row_text, r->command, 0, 0);
            line_finish(&row_text);
            putrow(y++, line, 0);
            shown++;
        }
    }
    screen_finish();
}

/* A signal may interrupt malloc or stdio. Set a flag here and perform
 * resizing/cleanup in the main loop, where those operations are safe. */
static void
on_signal(sig)
int sig;
{
    if (sig == SIGWINCH) want_resize = 1;
    else want_quit = 1;
}

/* Waiting on the terminal uses no busy loop. A timeout requests the next
 * sample; input or a signal wakes us early so quitting stays responsive. */
static int
keywait(usec)
long usec;
{
    struct timeval tv;
    fd_set fds;
    char c;
    int n;
    if (want_quit) return 'q';
    if (want_resize) return 0;
    tv.tv_sec = usec / 1000000L;
    tv.tv_usec = usec % 1000000L;
    FD_ZERO(&fds);
    FD_SET(0, &fds);
    n = select(1, &fds, NULL, NULL, &tv);
    if (n > 0) {
        if (read(0, &c, 1) != 1) {
            want_quit = 1;
            return 'q';
        }
        return c & 0177;
    }
    if (n < 0 && errno != EINTR) want_quit = 1;
    return want_quit ? 'q' : 0;
}

static int
prompt(label, answer, size)
char *label, *answer;
int size;
{
    char line[160];
    int n, c;
    n = 0;
    answer[0] = 0;
    while (!want_quit && !want_resize) {
        sprintf(line, "%s%s", label, answer);
        putrow(5, line, 0);
        screen_flush();
        c = keywait(1000000L);
        if (c == '\r' || c == '\n') return n > 0;
        if (c == 27) return 0;
        if (c == 127 || c == '\b') { if (n) answer[--n] = 0; }
        else if (c >= ' ' && c <= '~' && n < size - 1) {
            answer[n++] = c;
            answer[n] = 0;
        }
    }
    return 0;
}

static long
parse_delay(s)
char *s;
{
    long whole, fraction, scale, value;
    int digits;
    whole = fraction = 0;
    digits = 0;
    while (*s >= '0' && *s <= '9') {
        whole = whole * 10 + *s++ - '0';
        if (whole > 1800) return -1L;
        digits++;
    }
    if (*s == '.') {
        s++;
        scale = 100000L;
        while (*s >= '0' && *s <= '9') {
            if (scale == 0) return -1L;
            fraction += (*s++ - '0') * scale;
            scale /= 10;
            digits++;
        }
    }
    value = whole * 1000000L + fraction;
    if (!digits || *s || value < 100000L || value > 1800000000L)
        return -1L;
    return value;
}

static int
parse_int(s, low, high)
char *s;
int low, high;
{
    char *end;
    long n;
    n = strtol(s, &end, 10);
    if (s == end || *end || n < low || n > high) return -1;
    return (int)n;
}

static void
usage()
{
    fprintf(stderr, "usage: top [-s seconds] [-o column] [-n rows] [-I] [-h]\n");
    fprintf(stderr, "  -s  refresh interval, 0.1 to 1800 seconds (default 1)\n");
    fprintf(stderr, "  -o  sort column 0..10; default 9 (DTIME then TIME)\n");
    fprintf(stderr, "  -n  maximum processes displayed (0 fills the screen)\n");
    fprintf(stderr, "  -I  initially hide idle processes; h shows interactive help\n");
}

int
main(argc, argv)
int argc;
char **argv;
{
    int c, result, number;
    long newdelay;
    char answer[32];

    while ((c = getopt(argc, argv, "hs:o:n:I")) != EOF) {
        switch (c) {
        case 's':
            delay_us = parse_delay(optarg);
            if (delay_us < 0) { usage(); return 1; }
            break;
        case 'o':
            order = parse_int(optarg, 0, 10);
            if (order < 0) { usage(); return 1; }
            break;
        case 'n':
            limit = parse_int(optarg, 0, 1000);
            if (limit < 0) { usage(); return 1; }
            break;
        case 'I': showidle = 0; break;
        case 'h': usage(); return 0;
        default: usage(); return 1;
        }
    }
    if (optind != argc) { usage(); return 1; }
    if (!isatty(0) || !isatty(1)) {
        fprintf(stderr, "top: run from an interactive terminal\n");
        return 1;
    }
    if (!setup()) {
        fprintf(stderr, "top: %s\n", error_text);
        return 1;
    }
    signal(SIGWINCH, on_signal);
    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);
    signal(SIGHUP, on_signal);
    result = 0;
    if (!sample(1)) result = 1;
    else if (!screen_start()) {
        strcpy(error_text, screen_error);
        result = 1;
    }
    else {
        /* Show useful totals immediately; interval fields become valid later. */
        draw();
        while (!want_quit) {
            /* Handle the key we just read, including the first key after
             * startup. Sampling before dispatch used to discard that key. */
            c = keywait(delay_us);
            if (want_quit || c == 'q' || c == 'Q') break;
            status_text[0] = 0;
            switch (c) {
            case 'h': case '?': help_on = !help_on; break;
            case 'I': case 'i': showidle = !showidle; break;
            case 'P': order = 9; break;
            case 'T': order = 8; break;
            case 'N': order = 0; break;
            case 'M': order = 5; break;
            case 12: screen_clear(); break;
            case 's':
                if (prompt("Refresh seconds: ", answer, sizeof(answer))) {
                    newdelay = parse_delay(answer);
                    if (newdelay > 0) delay_us = newdelay;
                    else strcpy(status_text, "Delay must be 0.1 to 1800 seconds");
                }
                break;
            case 'o':
                if (prompt("Sort column (0..10): ", answer, sizeof(answer))) {
                    number = parse_int(answer, 0, 10);
                    if (number >= 0) order = number;
                    else strcpy(status_text, "Sort column must be 0 through 10");
                }
                break;
            }
            if (want_quit) break;
            if (want_resize) {
                /* Clear before work, so a second signal during allocation
                 * remains pending for the next trip through the loop. */
                want_resize = 0;
                if (!screen_start()) {
                    strcpy(error_text, screen_error); result = 1; break;
                }
            }
            if (!sample(0)) { result = 1; break; }
            draw();
        }
    }
    screen_stop();
    if (result) fprintf(stderr, "top: %s\n", error_text);
    return result;
}
