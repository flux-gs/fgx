/* ---- stdio FILE layer (C4 batch 13 — the LAST shim tier) -----------------
 * FGX stdio is UNBUFFERED: every byte round-trips a syscall; a FILE is just
 * {fd, flag} in the shared _libc_FILE_table (libc_data, frozen prefix), and
 * a FILE* is a far ptr to its entry.  The engines below sit directly on the
 * C fd surface (open/read/write/lseek/close), so caller buffers
 * keep their own banks end to end — the asm layer's 127-byte staging cap
 * (fputs) and DBR gymnastics are gone.
 *
 * BANK RULE: an incoming FILE*'s bank byte is UNTRUSTWORTHY — the legacy
 * stdin/stdout/stderr cells are 2-byte DA offsets (a C read of the 4-byte
 * extern picks up a junk bank), and the asm shims never read the bank
 * either.  So every entry access REBASES the offset onto our own far view
 * of the table (__lc_fent).  Widening those three cells to loader-patched
 * far ptrs is a later, separate fix. */


static int *__lc_fent(char *fp)
{
    unsigned off  = (unsigned)(unsigned long)fp;
    unsigned base = (unsigned)(unsigned long)&_libc_FILE_table[0];
    return &_libc_FILE_table[(off - base) >> 1];
}

/* far FILE* for table slot i (the tgetstr bank-recovery composition) */
static char *__lc_fptr(int i)
{
    return (char *)(((unsigned long)&_libc_FILE_table[0] >> 16 << 16)
                    | (unsigned)(unsigned long)&_libc_FILE_table[i * 2]);
}

/* shared fgetc core: one byte via SYS_READ; flags per the asm engine
 * (0 bytes -> _IOEOF, syscall fail -> _IOERR; both return -1) */
static int __lc_getc1(int *e)
{
    char ch;
    int r = read(e[0], &ch, 1);
    if (__syscall_c() == 0) { e[1] |= _IOERR; return -1; }
    if (r == 0)             { e[1] |= _IOEOF; return -1; }
    return ch & 0xFF;
}

/* ---- READ BUFFERING (apple/fgx#50) ---------------------------------------
 * A syscall per byte made every fgets() cost ~0.77 ms per character.  Measured
 * on the login path: getttynam() spent 156 ticks (2.6 s) walking the 3.4 KB of
 * /etc/ttys that precedes the getty lines, which was ~80% of the pause between
 * the login name and the Password: prompt.  getpwnam()'s 91-byte file at 5
 * ticks sat on the same per-byte constant, so this was never about one file.
 *
 * A READ STREAM IS BUFFERED UNLESS ITS DESCRIPTOR IS A TERMINAL, which is
 * where 2.11BSD draws the line too.  Upstream's _filbuf (libc/stdio/filbuf.c)
 * buffers ANY read stream including stdin, keyed on the stream's own _IONBF
 * flag rather than on the descriptor number, and sizes the buffer from
 * fstat's st_blksize.  Nothing there excludes fd 0.
 *
 * AN INTERACTIVE STREAM STAYS UNBUFFERED.  getpass(3) reads the password
 * from /dev/tty, or from stdin when there is no controlling terminal, and a
 * buffered terminal would let a long login name silently supply the password
 * -- the exact hazard login's own readname() guard exists to close.
 * Interactive echo timing depends on the same one-byte path.
 *
 * SO THE TEST IS isatty, NOT THE SLOT NUMBER.  A terminal keeps the one-byte
 * path and pays what it always paid, which costs nothing because a terminal
 * hands over a line at a time anyway.  A file or pipe on fd 0 -- which is what
 * `freopen(file, "r", stdin)' produces, grep's whole I/O loop -- is buffered
 * like any other, turning 49,152 read(2) calls for a 48 KB file into 96.
 * The decision is made once per descriptor and remade when the descriptor
 * changes under the slot, mirroring what the write side does with _lc_wline.
 *
 * EVERY stdin READER MUST GO THROUGH THE BUFFER or they interleave: a raw
 * read(0, ...) beside a buffered one skips whatever the buffer is holding.
 * getchar() and gets() route through __lc_getcb for that reason.
 *
 * THE BUFFERS ARE MALLOC'D, NOT STATIC, AND THAT IS FORCED.  Static buffers land
 * in the process DATA SEGMENT, and elvis fills that to within ~157 bytes of the
 * 64 KB ceiling -- 5 x 128 bytes of static buffer overflows it and the link
 * fails by name (`Object code size > 64 KB`, vi.data.s).  Allocating on first
 * buffered read costs ~50 bytes of segment for the table and takes the 512-byte
 * buffers from the heap instead, which is also what BSD stdio does.  A program
 * that never fopen()s a file for reading pays nothing at all.
 *
 * 512 = one ProDOS block per fill.  Buffers are NOT freed at fclose: a slot is
 * reused far more often than it is retired, the peak is bounded at 5 x 512, and
 * churning the heap for it would fragment more than it saves.
 *
 * IF malloc FAILS, THE FILE STAYS UNBUFFERED rather than failing the read --
 * correctness never depends on the buffer existing.  The failure is remembered,
 * because retrying a malloc that is out of heap on every single character would
 * be slower than the syscall-per-byte path this replaces. */
#define _LC_NBUF     8                  /* slots 0..7: stdin plus fopen's range */
#define _LC_BUFSZ    512                /* one ProDOS block */

static char *_lc_buf[_LC_NBUF];         /* NULL until the first buffered read */
static int   _lc_bpos[_LC_NBUF];        /* next byte to hand out */
static int   _lc_blen[_LC_NBUF];        /* valid bytes currently held */
static int   _lc_bfail[_LC_NBUF];       /* malloc said no; do not ask again */
static int   _lc_bfd[_LC_NBUF];         /* fd the isatty answer was taken for,
                                         * BIASED BY 1 so a zeroed table reads
                                         * as "not asked yet" and fd 0 is not
                                         * mistaken for a decision. */
static char  _lc_btty[_LC_NBUF];        /* that answer: 1 = terminal, stay raw */

/* AN UNBUFFERED STREAM STILL HOLDS THE BYTE IT LAST READ, one per slot, so
 * ungetc(3) has a place to push it back into: K&R 2nd ed B.1.4 guarantees
 * one character of pushback per stream, and scanf's field scan stops by
 * reading one character too many and pushing it back.  This is 2.11BSD's
 * _smallbuf: filbuf.c reads an _IONBF stream one byte at a time into
 * &_smallbuf[fileno(iop)], which ungetc.c steps back into like any buffer. */
static char  _lc_small[_LC_NBUF];

/* The bytes a slot hands out from: its malloc'd buffer, or its one-byte
 * _lc_small when the stream is a terminal or the malloc failed. */
static char *__lc_bptr(int b)
{
    if (_lc_btty[b] || _lc_buf[b] == (char *)0)
        return &_lc_small[b];
    return _lc_buf[b];
}

/* FILE* -> table slot.  Two ints per slot, so 4 bytes -- the shift freopen
 * already uses. */
static int __lc_slot(char *fp)
{
    unsigned off  = (unsigned)(unsigned long)fp;
    unsigned base = (unsigned)(unsigned long)&_libc_FILE_table[0];
    return (int)((off - base) >> 2);
}

/* Buffer index for a slot, or -1 when this FILE is not buffered. */
static int __lc_bufidx(int slot, int *e)
{
    if (slot < _LC_FIRSTBUF || slot >= _LC_FIRSTBUF + _LC_NBUF)
        return -1;
    if ((e[1] & _IOREAD) == 0)
        return -1;                      /* write side stays unbuffered */
    return slot - _LC_FIRSTBUF;
}

/* Forget whatever is held.  Every path that moves the fd out from under the
 * buffer -- fopen, freopen, fclose, fseek -- has to call this, or the next read
 * hands back bytes from the previous file or the previous offset. */
static void __lc_bdrop(int b)
{
    if (b >= 0) {
        _lc_bpos[b] = 0;
        _lc_blen[b] = 0;
    }
}

/* Unconsumed bytes: how far the fd is AHEAD of the caller's logical position.
 * ftell/fseek(SEEK_CUR) subtract this; without it a seek-relative read lands
 * one bufferful too far in. */
static int __lc_bavail(int b)
{
    return b >= 0 ? _lc_blen[b] - _lc_bpos[b] : 0;
}

/* Buffered getc.  b < 0 falls through to the one-byte path. */
static int __lc_getcb(int *e, int b)
{
    int n;
    char *p;

    if (b < 0)
        return __lc_getc1(e);
    /* Ask isatty ONCE per descriptor.  Re-asked when the fd changes under the
     * slot, which is what freopen(file, "r", stdin) does -- the stream starts
     * as a terminal and becomes a file, and the answer has to change with it.
     * Held bytes belong to the old descriptor, so they go. */
    if (_lc_bfd[b] != e[0] + 1) {
        _lc_bfd[b]  = e[0] + 1;
        _lc_btty[b] = isatty(e[0]) ? 1 : 0;
        _lc_bpos[b] = 0;
        _lc_blen[b] = 0;
    }
    if (!_lc_btty[b] && _lc_buf[b] == (char *)0 && !_lc_bfail[b]) {
        _lc_buf[b] = malloc(_LC_BUFSZ);
        if (_lc_buf[b] == (char *)0)
            _lc_bfail[b] = 1;           /* no heap: stay unbuffered, silently */
    }
    if (_lc_bpos[b] >= _lc_blen[b] && __lc_bptr(b) == &_lc_small[b]) {
        _lc_bpos[b] = 0;
        _lc_blen[b] = 0;
        n = __lc_getc1(e);
        if (n < 0)
            return -1;
        _lc_small[b] = (char)n;
        _lc_bpos[b] = 1;
        _lc_blen[b] = 1;
        return n;
    }
    if (_lc_bpos[b] >= _lc_blen[b]) {
        n = read(e[0], _lc_buf[b], _LC_BUFSZ);
        _lc_bpos[b] = 0;
        _lc_blen[b] = 0;
        if (__syscall_c() == 0) { e[1] |= _IOERR; return -1; }
        if (n <= 0)             { e[1] |= _IOEOF; return -1; }
        _lc_blen[b] = n;
    }
    /* The post-increment is split out of the subscript deliberately: fcc has
     * a history of miscompiling a side effect inside an index expression, and
     * this costs nothing to write plainly. */
    n = _lc_bpos[b];
    _lc_bpos[b] = n + 1;
    p = __lc_bptr(b);
    return p[n] & 0xFF;
}

/* ---- write buffering (apple/fgx#373) --------------------------------------
 * putchar/fputc issued one write(2) per character, and ufs_write turns every
 * write into a synchronous block write, so byte-at-a-time output ran at about
 * 95 bytes/second -- measured 10.57 ms per character to a file and 4.50 ms to
 * the console.
 *
 * KEYED BY DESCRIPTOR, NOT BY FILE.  printf stages into its own 64-byte buffer
 * and writes straight to the descriptor; if putchar buffered separately, a
 * program mixing the two on one stream would emit them out of order -- and od,
 * uniq, ul and fold all mix them.  One buffer per descriptor puts every libc
 * output path in the same queue, which is BSD's shape too: printf is built on
 * the FILE buffer there.
 *
 * A program that mixes stdio with its own write(2) on the same descriptor is
 * undefined here exactly as it is in BSD.  /bin/sh is not affected: its prs()
 * and prc() are the shell's own, and call write(2) directly.
 *
 * stderr is NEVER buffered, per BSD, so a diagnostic survives a crash.
 * Line-buffered on a tty and fully buffered otherwise, which is what keeps an
 * interactive program's output appearing as it is produced.
 *
 * Buffers are malloc'd on first use for the reason the read buffers are: a
 * static table overflows elvis's data segment, which fills to within ~157
 * bytes of the 64 KB ceiling.  A malloc failure is remembered rather than
 * retried per character, and leaves output correct but unbuffered.
 */
extern void (*_lc_flush_hook)();     /* stdio_hook.c; see there for why */
static void __lc_wflushall();       /* defined below; its address is taken
                                     * above it, at first buffer alloc */

#define _LC_NWBUF   4               /* concurrently buffered output fds */
#define _LC_WBUFSZ  1024            /* one UFS block; the read side's 512 is
                                     * one ProDOS block and predates the swap */

static int   _lc_wfd[_LC_NWBUF];    /* descriptor, or -1 for a free slot */
static char *_lc_wbuf[_LC_NWBUF];
static int   _lc_wcnt[_LC_NWBUF];   /* bytes held */
static int   _lc_wline[_LC_NWBUF];  /* 1 = flush on newline (tty) */
static int   _lc_wready;            /* the table starts all-zero and 0 is a
                                     * valid fd, so say when it is initialised */
static int   _lc_wnomem;            /* malloc said no; do not ask again */

static void __lc_wsetup(void)
{
    int i;

    if (_lc_wready)
        return;
    _lc_wready = 1;
    for (i = 0; i < _LC_NWBUF; i++)
        _lc_wfd[i] = -1;
}

/* Push what a slot holds.  The count is cleared BEFORE the write: a failed
 * write must not leave the bytes queued to be retried on every later call. */
static int __lc_wpush(int i)
{
    int n, r;

    if (i < 0 || _lc_wcnt[i] <= 0)
        return 0;
    n = _lc_wcnt[i];
    _lc_wcnt[i] = 0;
    r = write(_lc_wfd[i], _lc_wbuf[i], n);
    return (r == n) ? 0 : -1;
}

/* Slot holding fd, claiming one if it has none.  -1 means write straight
 * through -- stderr, a full table, or no heap. */
static int __lc_wslot(int fd)
{
    int i, freei;

    if (fd == 2)
        return -1;
    __lc_wsetup();
    freei = -1;
    for (i = 0; i < _LC_NWBUF; i++) {
        if (_lc_wfd[i] == fd)
            return i;
        if (_lc_wfd[i] < 0 && freei < 0)
            freei = i;
    }
    if (freei < 0 || _lc_wnomem)
        return -1;
    if (_lc_wbuf[freei] == (char *)0) {
        _lc_wbuf[freei] = malloc(_LC_WBUFSZ);
        if (_lc_wbuf[freei] == (char *)0) {
            _lc_wnomem = 1;
            return -1;
        }
    }
    _lc_wfd[freei]   = fd;
    _lc_wcnt[freei]  = 0;
    _lc_wline[freei] = isatty(fd) ? 1 : 0;
    /* Tell the exit-time hook we exist.  Registering HERE rather than exporting
     * the flush from this member is what keeps a program that never prints from
     * linking any of this: see stdio_hook.c. */
    _lc_flush_hook = __lc_wflushall;
    return freei;
}

/* Flush one descriptor.  Safe on an unbuffered one. */
static int __lc_wflush(int fd)
{
    int i;

    __lc_wsetup();
    for (i = 0; i < _LC_NWBUF; i++)
        if (_lc_wfd[i] == fd)
            return __lc_wpush(i);
    return 0;
}

static void __lc_wflushall(void)
{
    int i;

    __lc_wsetup();
    for (i = 0; i < _LC_NWBUF; i++)
        (void)__lc_wpush(i);
}

/* Flush and unbind, so a reused descriptor number does not inherit the old
 * file's held bytes or its tty decision. */
static void __lc_wrelease(int fd)
{
    int i;

    __lc_wsetup();
    for (i = 0; i < _LC_NWBUF; i++) {
        if (_lc_wfd[i] == fd) {
            (void)__lc_wpush(i);
            _lc_wfd[i] = -1;
        }
    }
}

static int __lc_wputc(int fd, int c)
{
    int i;
    char ch;

    i = __lc_wslot(fd);
    if (i < 0) {
        ch = c;
        return (write(fd, &ch, 1) == 1) ? 0 : -1;
    }
    _lc_wbuf[i][_lc_wcnt[i]] = (char)c;
    _lc_wcnt[i] = _lc_wcnt[i] + 1;
    if (_lc_wcnt[i] >= _LC_WBUFSZ)
        return __lc_wpush(i);
    if (_lc_wline[i] && (c & 0xFF) == 10)
        return __lc_wpush(i);
    return 0;
}

/* Bulk append.  Returns n, or -1.  A run at least as large as the buffer goes
 * straight out -- but only AFTER what is already held, or it would overtake
 * it. */
static int __lc_wwrite(int fd, char *p, int n)
{
    int i, room, k, j, nl, want;

    if (n <= 0)
        return n;
    want = n;
    i = __lc_wslot(fd);
    if (i < 0)
        return write(fd, p, n);
    if (n >= _LC_WBUFSZ) {
        if (__lc_wpush(i) < 0)
            return -1;
        return write(fd, p, n);
    }
    nl = 0;
    if (_lc_wline[i]) {
        for (j = 0; j < n; j++)
            if ((p[j] & 0xFF) == 10) { nl = 1; break; }
    }
    while (n > 0) {
        room = _LC_WBUFSZ - _lc_wcnt[i];
        k = (n < room) ? n : room;
        memcpy(_lc_wbuf[i] + _lc_wcnt[i], p, k);
        _lc_wcnt[i] = _lc_wcnt[i] + k;
        p = p + k;
        n = n - k;
        if (_lc_wcnt[i] >= _LC_WBUFSZ && __lc_wpush(i) < 0)
            return -1;
    }
    if (nl && __lc_wpush(i) < 0)
        return -1;
    return want;
}

/* mode string -> open flags; "r"/"w"/"a", then an optional '+' and an
 * optional 'b' (a no-op) in either order; else -1.
 *
 * '+' IS UPDATE: the same open, O_RDWR in place of the one-way access mode,
 * which is 2.11BSD's fopen (lib/libc/stdio/fopen.c) -- `rw = (mode[1] ==
 * '+')' picks O_RDWR in each of its three arms.  crontab(1) writes its new
 * table through a "w+" stream, rewinds it and reads it back to check it.
 *
 * "w" PASSES O_TRUNC AND STILL UNLINKS, and it needs both because the two
 * filesystems under it truncate in different places.
 *
 * It used to pass only O_WRONLY|O_CREAT and rely on the unlink, on the
 * reasoning "FGX SYS_OPEN ignores O_TRUNC".  That was true of the legacy
 * resolver and is NOT true of a mounted root: apple/fgx#318 routes open(2)
 * through vn_open, which honours FTRUNC itself and calls VOP_SETATTR with
 * va_size = 0 -> ufs_itrunc.  The unlink is what was carrying the truncate,
 * and on a UFS root unlink has no hook yet -- it answers EIO, and line 181
 * IGNORES THE RESULT.  So `fopen(path, "w")' on an existing file opened it
 * WITHOUT truncating and wrote over the front, leaving the old tail behind:
 * dhclient rewrote /etc/resolv.conf with 41 bytes and the last 42 bytes of
 * the shipped comment survived as a third line.
 *
 * AND THE UNLINK IS GONE, WHICH THE FIRST CUT OF THIS FIX GOT WRONG.  It was
 * kept "for the legacy path, where SYS_OPEN still drops O_TRUNC" -- but that
 * path left with ProDOS, and the unlink was never merely redundant: it
 * DELETES what it is pointed at.  `fopen("/dev/tty", "w")' removed the
 * character node and made a plain file in its place, which is what creat(2)
 * was doing to /dev/console (apple/fgx#323).  It was invisible only while
 * unlink answered EIO on a UFS root; the moment unlink worked, every "w" open
 * of a device node destroyed it.
 *
 * O_TRUNC is what carries the meaning, it is what POSIX says "w" is, and it
 * is the only thing here now. */
static int __lc_mode_flags(char *mode)
{
    int fl, rw = 0, i;

    if (mode[0] == 'r') fl = 0;                  /* O_RDONLY */
    else if (mode[0] == 'w') fl = 0x0601;        /* O_WRONLY|O_CREAT|O_TRUNC */
    else if (mode[0] == 'a') fl = 0x0209;        /* O_WRONLY|O_CREAT|O_APPEND */
    else return -1;
    for (i = 1; mode[i] != 0; i++) {
        if (i > 2 || (mode[i] != '+' && mode[i] != 'b')
            || (i == 2 && mode[2] == mode[1]))
            return -1;
        if (mode[i] == '+')
            rw = 1;
    }
    if (rw)
        fl = (fl & ~3) | 2;                      /* O_RDWR */
    return fl;
}

/* The FILE's direction word for a mode __lc_mode_flags accepted.  An update
 * stream is both: 2.11BSD marks it _IORW and lets _filbuf and _flsbuf set
 * the direction in use.  Here fseek and rewind push held output and drop held
 * input, and fflush pushes held output -- the calls ANSI requires between a
 * write and a read, and fseek or rewind between a read and a write -- which
 * is that switch. */
static int __lc_mode_dir(char *mode)
{
    if (mode[1] == '+' || (mode[1] != 0 && mode[2] == '+'))
        return _IOREAD | _IOWRT;
    return (mode[0] == 'r') ? _IOREAD : _IOWRT;
}

char *fopen(char *path, char *mode)
{
    int i, fd, fl;


    fl = __lc_mode_flags(mode);
    if (fl < 0) { errno = 22; return (char *)0; }          /* EINVAL */
    for (i = 3; i < 8; i++)
        if (_libc_FILE_table[i * 2] == -1)
            break;
    if (i == 8) { errno = 23; return (char *)0; }          /* ENFILE */
    fd = open(path, fl, 0666);      /* "w" carries O_TRUNC; see __lc_mode_flags.
                                     * 0666 is BOTH ancestors' -- 2.11BSD and
                                     * 4.3BSD-Reno lib/libc/stdio/fopen.c:44 are
                                     * the same line, `open(file, oflags, 0666)'
                                     * -- and the umask is what narrows it. */
    if (fd < 0)
        return (char *)0;              /* errno set by open */
    _libc_FILE_table[i * 2]     = fd;
    _libc_FILE_table[i * 2 + 1] = __lc_mode_dir(mode);
    __lc_bdrop(i - _LC_FIRSTBUF);       /* a reused slot must not inherit the
                                         * previous file's held bytes */
    return __lc_fptr(i);
}

int fclose(char *fp)
{
    int *e = __lc_fent(fp);
    int r = 0;

    __lc_bdrop(__lc_slot(fp) - _LC_FIRSTBUF);
    if (e[0] != -1) {
        __lc_wrelease(e[0]);            /* flush and unbind: a reused fd number
                                         * must not inherit this file's bytes */
        r = close(e[0]);
    }
    e[0] = -1;
    e[1] = 0;
    return r;
}

char *fgets(char *s, int size, char *fp)
{
    int *e = __lc_fent(fp);
    int b = __lc_bufidx(__lc_slot(fp), e);
    int i = 0, ch;

    while (i < size - 1) {
        ch = __lc_getcb(e, b);
        if (ch < 0)
            break;
        s[i] = ch;
        i++;
        if (ch == 10)                            /* '\n' ends the line */
            break;
    }
    if (i == 0)
        return (char *)0;
    s[i] = 0;
    return s;
}

