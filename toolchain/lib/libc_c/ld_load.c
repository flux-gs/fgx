/*
 * ld_load -- make a shared library resident: read it into banks the
 * registry grants, relocate it once for the boot, bind its own imports
 * and commit it (shared libc SP4 spec, section 5.2).  /sbin/ldload calls
 * it at boot; the binder calls it on a library's first use.
 *
 * No statics: every byte of state is the caller's struct ld_work
 * (<sys/ldctl.h>).  Messages are SunOS 4.1.3 rtld's where it has one
 * (lang/rtld/rtld.c, cache_rtld.c), assembled in w->msg because a literal
 * here is in libc's code bank, which write(2) cannot read.
 *
 * The file is an FGX3 library: a 16-byte header, a segment table, its
 * segments -- code banks, the core template, the block templates -- then
 * 4-byte relocs (segment, offset, target segment) and the FGXL trailer
 * (toolchain/src/ld/fgx_ld.py).  In memory, the core template, the block
 * templates and the trailer's EXPT and FIXS blocks follow the last code
 * bank's bytes, as fgx_bind lays a library out (add_lib), then an export
 * index (XIDX) this file builds, the tagged blocks ended by an END tag.  A reloc's byte is its target's bank, and a
 * target placed past offset 0 adds its offset to the word below.  A
 * per-process fixup (a core pointer into the core) is left for the binder
 * to set at each core copy.
 *
 * A library's imports bind only against the libraries it was linked with
 * (equal export CRCs): code imports take the recorded values, data sites
 * move by the needed core's base less the base recorded.
 */
#define LD_NDEP         4               /* needed libraries, at most */
#define LD_CHUNK        16384           /* readv(2) carries < 32768 a call */

static int ld_readin();

static char *
ld_far(bank, off)
unsigned bank, off;
{
    return (char *)(((unsigned long)bank << 16) | off);
}

static unsigned
ld_rd16(p)
unsigned char *p;
{
    return p[0] | (p[1] << 8);
}

static void
ld_wr16(p, v)
unsigned char *p;
unsigned v;
{
    p[0] = v;
    p[1] = v >> 8;
}

static char *
ld_cat(d, s)
char *d, *s;
{
    while (*s)
        *d++ = *s++;
    return d;
}

static char *
ld_num(d, v)
char *d;
unsigned v;
{
    char t[6];
    int n;

    n = 0;
    do {
        t[n++] = '0' + v % 10;
        v /= 10;
    } while (v);
    while (n)
        *d++ = t[--n];
    return d;
}

/* "<a><name>.so.<major><b>\n" on fd 2; name may be 0. */
static void
ld_msg(w, a, name, major, b)
struct ld_work *w;
char *a, *name, *b;
int major;
{
    char *p;

    p = ld_cat(w->msg, a);
    if (name) {
        p = ld_cat(p, name);
        p = ld_cat(p, ".so.");
        p = ld_num(p, major);
    }
    p = ld_cat(p, b);
    *p++ = '\n';
    write(2, w->msg, p - w->msg);
}

/* SunOS cache_rtld.c:180's warning: "<file> has older revision than
 * expected <minor>". */
static void
ld_old(w, name, major, have, want)
struct ld_work *w;
char *name;
int major, have, want;
{
    char *p;

    p = ld_cat(w->msg, "ld.so: warning: ");
    p = ld_cat(p, name);
    p = ld_cat(p, ".so.");
    p = ld_num(p, major);
    *p++ = '.';
    p = ld_num(p, have);
    p = ld_cat(p, " has older revision than expected ");
    p = ld_num(p, want);
    *p++ = '\n';
    write(2, w->msg, p - w->msg);
}

int
ld_ctl(w, svc)
struct ld_work *w;
int svc;
{
    unsigned long a;
    int r;

    a = (unsigned long)(char *)&w->blk;
    r = (int)__syscall(SYS_LDCTL, svc, (unsigned)a, (unsigned)(a >> 16));
    if (__syscall_c() == 0) {
        errno = r;
        return -1;
    }
    return r;
}

static void
ld_set(w, name, major)
struct ld_work *w;
char *name;
int major;
{
    char *p;
    int i;

    p = (char *)&w->blk;
    for (i = 0; i < sizeof w->blk; i++)
        p[i] = 0;
    for (i = 0; i < 15 && name[i]; i++)
        w->blk.name[i] = name[i];
    w->blk.major = major;
}

/* w->path = /lib/<name>.so.<major>.<highest minor> -> that minor, or -1.
 * <name>.so.<major>. then digits only: a pile is libc.so.<10 hex>.
 *
 * The directory is read through a descriptor, as 2.11BSD's readdir(3) does
 * (lib/libc/gen/readdir.c: read the directory, step by d_reclen, skip
 * d_ino == 0, and stop at a record whose d_reclen is 0 or runs past its
 * DIRBLKSIZ block).  A record is 2.11BSD's struct direct (sys/dir.h): d_ino,
 * d_reclen and d_namlen, 16 bits each, then the name and its NUL, at most
 * 6 + 63 + 1 bytes.  It is read through w->msg, a window of 96 bytes, and
 * read again from a record whose name runs past the window, so the listing
 * needs no more room however long /lib is. */
#define LD_DIRBLK       512             /* sys/dir.h DIRBLKSIZ */

static int
ld_find(w, name, major)
struct ld_work *w;
char *name;
int major;
{
    char pfx[32], *e, *s;
    unsigned char *b;
    long pos;
    int fd, n, loc, rl, nl, best, v, k, ok;

    e = ld_cat(pfx, name);
    e = ld_cat(e, ".so.");
    e = ld_num(e, major);
    *e++ = '.';
    *e = 0;
    e = ld_cat(w->path, "/lib");
    *e = 0;
    fd = open(w->path, 0);
    if (fd < 0)
        return -1;
    best = -1;
    for (pos = 0; lseek(fd, pos, 0) == pos &&
                  (n = read(fd, w->msg, sizeof w->msg)) >= 6; pos += loc) {
        for (loc = 0; loc + 6 <= n; loc += rl) {
            b = (unsigned char *)w->msg + loc;
            rl = ld_rd16(b + 2);
            nl = ld_rd16(b + 4);
            if (rl == 0 || rl > LD_DIRBLK - (((int)pos + loc) & (LD_DIRBLK - 1)) ||
                nl + 7 > rl)
                goto done;
            if (loc + 6 + nl > n)
                break;                          /* read again from here */
            if (ld_rd16(b) == 0)
                continue;
            s = (char *)b + 6;
            for (k = 0; pfx[k] && k < nl && s[k] == pfx[k]; k++)
                ;
            if (pfx[k] || k == nl)
                continue;
            for (ok = 1, v = 0; k < nl; k++) {
                if (s[k] < '0' || s[k] > '9')
                    ok = 0;
                v = v * 10 + (s[k] - '0');
            }
            if (ok && v > best)
                best = v;
        }
        if (loc == 0)
            break;                              /* a record cut short: the end */
    }
done:
    close(fd);
    if (best < 0)
        return -1;
    e = ld_cat(w->path, "/lib/");
    e = ld_cat(e, pfx);
    e = ld_num(e, best);
    *e = 0;
    return best;
}

/* Open the library and read its header into w->hdr -> the fd, at the
 * trailer, *tlen = the trailer's length; -1 failed (named). */
static int
ld_open(w, name, major, tlen)
struct ld_work *w;
char *name;
int major;
unsigned *tlen;
{
    int fd, n, i;
    unsigned long pos, end;

    if (ld_find(w, name, major) < 0) {
        ld_msg(w, "ld.so: ", name, major, ": not found");
        return -1;
    }
    fd = open(w->path, 0);
    if (fd < 0) {
        ld_msg(w, "ld.so: ", name, major, ": not found");
        return -1;
    }
    if (read(fd, (char *)w->hdr, 16) != 16 || !(w->hdr[10] & 2) ||
        (n = w->hdr[6]) > 9 || read(fd, (char *)w->hdr + 16, 8 * n) != 8 * n)
        goto bad;
    pos = 16 + 8 * n + 4L * ld_rd16(w->hdr + 11);
    for (i = 0; i < n; i++)
        pos += ld_rd16(w->hdr + 16 + 8 * i);
    end = lseek(fd, 0L, 2);
    if (end < pos || end - pos > 0xFFF0L || end - pos < 17 ||
        lseek(fd, pos, 0) != pos)
        goto bad;
    *tlen = end - pos;
    return fd;
bad:
    ld_msg(w, "ld.so: ", name, major, ": not a shared library this loader reads");
    close(fd);
    return -1;
}

/* Whether b, read from the trailer's offset, is an FGXL version 2 head. */
static int
ld_isfgxl(b)
unsigned char *b;
{
    return b[0] == 'F' && b[1] == 'G' && b[2] == 'X' && b[3] == 'L' && b[4] == 2;
}

/* The tagged block `tag' in the trailer at b -> its payload, *len; 0 if none. */
static unsigned char *
ld_blk(b, tlen, tag, len)
unsigned char *b;
unsigned tlen;
char *tag;
unsigned *len;
{
    unsigned pos, n;

    for (pos = 17; pos + 8 <= tlen; pos += 8 + n) {
        n = ld_rd16(b + pos + 4);
        if (b[pos] == tag[0] && b[pos + 1] == tag[1] && b[pos + 2] == tag[2] &&
            b[pos + 3] == tag[3]) {
            *len = n;
            return b + pos + 8;
        }
    }
    *len = 0;
    return (unsigned char *)0;
}

/* The needed libraries out of IMPS -> how many, or -1. */
static int
ld_parse_needs(p, len, need, max)
unsigned char *p;
unsigned len;
struct ld_need *need;
int max;
{
    int n, i, k, nl;

    if (p == 0 || len == 0)
        return 0;
    n = *p++;
    if (n > max)
        return -1;
    for (i = 0; i < n; i++) {
        nl = *p++;
        for (k = 0; k < nl && k < 15; k++)
            need[i].name[k] = p[k];
        need[i].name[k] = 0;
        p += nl;
        need[i].major = p[0];
        need[i].minor = p[1];
        for (k = 0; k < 4; k++)
            need[i].crc[k] = p[2 + k];
        need[i].core_base = ld_rd16(p + 6);
        p += 9 + (p[8] + 7) / 8;
    }
    return n;
}

int
ld_needs(w, name, major, need, max)
struct ld_work *w;
char *name;
int major, max;
struct ld_need *need;
{
    unsigned tlen, len;
    unsigned char *p;
    int fd, n;

    fd = ld_open(w, name, major, &tlen);
    if (fd < 0)
        return -1;
    p = (unsigned char *)w->buf;
    if (tlen > w->bufsz ||
        ld_readin(w, fd, (unsigned)((unsigned long)p >> 16), (unsigned)(unsigned long)p,
                  (unsigned long)tlen) < 0 || !ld_isfgxl(p)) {
        ld_msg(w, "ld.so: ", name, major, ": not a shared library this loader reads");
        close(fd);
        return -1;
    }
    close(fd);
    p = ld_blk(p, tlen, "IMPS", &len);
    n = ld_parse_needs(p, len, need, max);
    if (n < 0)
        ld_msg(w, "ld.so: ", name, major, ": needs too many libraries");
    return n;
}

/* Where a library's segment lives once loaded. */
struct ld_map {
    unsigned char banks[LD_MAXBANKS];
    unsigned ncode, core_at, tmpl_at;
    struct ld_seg seg[LD_MAXBANKS + 2];         /* code banks, core, templates */
};

static unsigned char *
ld_at(m, seg, off)
struct ld_map *m;
int seg;
unsigned off;
{
    if (seg < m->ncode)
        return (unsigned char *)ld_far(m->banks[seg], off);
    return (unsigned char *)ld_far(m->banks[m->ncode - 1],
                                   (seg == m->ncode ? m->core_at : m->tmpl_at) + off);
}

static int
ld_readin(w, fd, bank, off, n)
struct ld_work *w;
int fd;
unsigned bank, off;
unsigned long n;
{
    unsigned k;

    while (n) {
        k = n > LD_CHUNK ? LD_CHUNK : n;
        w->iov.iov_base = ld_far(bank, off);
        w->iov.iov_len = k;
        if (readv(fd, &w->iov, 1) != k)
            return -1;
        off += k;
        n -= k;
    }
    return 0;
}

/* A needed library, as the binding of imports sees it. */
struct ld_dep {
    unsigned char banks[LD_MAXBANKS];
    unsigned delta;             /* its row's base less the base recorded */
};

/* Bind one library's imports through its sites (fgx_imports.py's IMPS
 * layout: per needed library `namelen name major minor crc(4) core_base(2)
 * rows bitmap', then every import's record, then every import's sites in
 * the same order, so two cursors walk it together). */
static int
ld_bind_imps(m, p, dep)
struct ld_map *m;
unsigned char *p;
struct ld_dep *dep;
{
    unsigned char *r, *s;
    unsigned ni, i, k, c, val;
    int lib, kind, seg;

    for (i = *p++; i; i--) {                    /* skip the libraries */
        p += 1 + p[0] + 8;                      /* name, major..core_base */
        p += 1 + (p[0] + 7) / 8;                /* rows, bitmap */
    }
    ni = ld_rd16(p);
    r = p + 2;
    for (s = r, i = 0; i < ni; i++)             /* the sites start after */
        s += 4 + s[3] + 6;
    for (i = 0; i < ni; i++) {
        lib = r[0];
        kind = r[4 + r[3]];
        seg = r[5 + r[3]];
        val = ld_rd16(r + 6 + r[3]);
        r += 4 + r[3] + 6;
        for (k = 0; k < 3; k++) {               /* call, ptr, data */
            c = ld_rd16(s);
            s += 2;
            if (c && (kind == 0) != (k < 2))
                return -1;                      /* a class this kind has not */
            if (c)
                _ld_patch(s, c, m->seg, kind,
                          kind == 0 ? val : dep[lib].delta,
                          kind == 0 ? dep[lib].banks[seg] : 0, 0xFF);
            s += (k == 2 ? 5 : 3) * c;                  /* a data site carries its word */
        }
    }
    return 0;
}

/* A needed library ld_fill found absent: this process now owns it LOADING. */
struct ld_miss {
    struct ld_need n;
    int row, have;
};

/* Load `name', whose row this process owns LOADING (row, holding `have'
 * banks): one listing of /lib, one read of the file.  Commits and answers
 * 1, or aborts and says why and answers -1; or, when a library it needs is
 * absent, answers -2 with that library in *x, owned LOADING, and this row
 * still LOADING, for ld_need to load the one and call again. */
static int
ld_fill(w, name, major, minor, pin, row, have, x)
struct ld_work *w;
char *name;
int major, minor, pin, row, *have;
struct ld_miss *x;
{
    struct ld_need need[LD_NDEP];
    struct ld_dep dep[LD_NDEP];
    struct ld_map m;
    unsigned tlen, len, elen, flen, blen, base, csize, cbase, deps, i, k, n, off, to, tat, nexp;
    unsigned long expt_at, nrel, left;
    unsigned char *p, *e, *f, *q, *r, *t;
    int fd, nd, core, tmpl, nseg, src, tgt, fmin;
    char crc[4];

    fd = ld_open(w, name, major, &tlen);
    if (fd < 0)
        goto abort;
    /* The banks first, which the file's header alone sizes: a library is
     * its code banks, then the core template, then the block templates, so
     * the core is segment nseg - 2 and the code banks number that many.
     * The core is placed only once what it needs is resident (below). */
    nseg = w->hdr[6];
    core = nseg - 2;
    tmpl = core + 1;
    if (nseg < 3 || core > LD_MAXBANKS)
        goto bad;
    for (i = 0; i < nseg; i++)
        if (ld_rd16(w->hdr + 18 + 8 * i) || (i < core && w->hdr[20 + 8 * i]))
            goto bad;                           /* no bss; code banks CODE */
    csize = ld_rd16(w->hdr + 16 + 8 * core);
    ld_set(w, name, major);
    w->blk.row = row;
    w->blk.nbanks = core > *have ? core - *have : 0;
    if (ld_ctl(w, LDS_GRANT) < 0) {
        ld_msg(w, "ld.so: ", name, major, ": out of memory");
        goto close;
    }
    *have = w->blk.nbanks;
    m.ncode = core;
    for (k = 0; k < LD_MAXBANKS; k++)
        m.banks[k] = w->blk.banks[k];
    m.core_at = ld_rd16(w->hdr + 16 + 8 * (core - 1));
    m.tmpl_at = m.core_at + csize;
    for (k = 0; k < core; k++) {
        m.seg[k].off = 0;
        m.seg[k].bank = m.banks[k];
    }
    m.seg[core].off = m.core_at;
    m.seg[core].bank = m.banks[core - 1];
    m.seg[tmpl].off = m.tmpl_at;
    m.seg[tmpl].bank = m.banks[core - 1];
    expt_at = (unsigned long)m.tmpl_at + ld_rd16(w->hdr + 16 + 8 * tmpl);

    /* The trailer, into the top of the last code bank, above everything the
     * code read will put there: the fd is at it.  Its EXPT and FIXS blocks
     * are copied down to expt_at at the end, each to an address no higher
     * than its own, so the copy never overruns what it has yet to read. */
    tat = (0 - tlen) & 0xFFFE;
    if (expt_at > tat ||
        ld_readin(w, fd, m.banks[core - 1], tat, (unsigned long)tlen) < 0)
        goto bad;
    p = (unsigned char *)ld_far(m.banks[core - 1], tat);
    if (!ld_isfgxl(p) || p[7] != core || p[8] != tmpl || ld_rd16(p + 11) != csize)
        goto bad;
    fmin = p[6];
    cbase = ld_rd16(p + 9);
    for (k = 0; k < 4; k++)
        crc[k] = p[13 + k];
    if (fmin < minor)
        ld_old(w, name, major, fmin, minor);
    q = ld_blk(p, tlen, "IMPS", &len);
    nd = ld_parse_needs(q, len, need, LD_NDEP);
    if (nd < 0)
        goto bad;
    deps = 0;
    for (i = 0; i < nd; i++) {
        ld_set(w, need[i].name, need[i].major);
        if ((k = ld_ctl(w, LDS_ACQUIRE)) == 1) {
            q = (unsigned char *)&need[i];      /* ours LOADING: load it first */
            t = (unsigned char *)&x->n;
            for (k = 0; k < sizeof x->n; k++)
                t[k] = q[k];
            x->row = w->blk.row;
            x->have = w->blk.nbanks;
            close(fd);
            return -2;
        }
        if (k != 0) {
            ld_msg(w, "ld.so: ", need[i].name, need[i].major,
                   errno == EINTR ? ": interrupted" : ": registry error");
            goto close;
        }
        for (k = 0; k < 4; k++)
            if (w->blk.crc[k] != need[i].crc[k]) {
                ld_msg(w, "ld.so: ", name, major,
                       ": a library it needs differs from the one it was linked against");
                goto close;
            }
        for (k = 0; k < LD_MAXBANKS; k++)
            dep[i].banks[k] = w->blk.banks[k];
        dep[i].delta = w->blk.core_base - need[i].core_base;
        deps |= 1 << w->blk.row;
    }
    ld_set(w, name, major);
    w->blk.row = row;
    w->blk.core_size = csize;
    if (ld_ctl(w, LDS_GRANT) < 0) {
        ld_msg(w, "ld.so: ", name, major, errno == EINVAL ?
               ": its core size changed since it was loaded" : ": out of memory");
        goto close;
    }
    base = w->blk.core_base;
    e = ld_blk(p, tlen, "EXPT", &elen);
    f = ld_blk(p, tlen, "FIXS", &flen);
    ld_blk(p, tlen, "BLKS", &blen);
    if (e == 0 || f == 0 || f < e)
        goto bad;
    for (nexp = 0, i = 0; i < elen; i += 1 + e[i] + 6)
        nexp++;
    if (expt_at + 8 + elen + 8 + flen + 12 + 2L * nexp + 8 > 0x10000L)
        goto bad;

    /* The code banks, the last carrying the core and block templates. */
    if (lseek(fd, (long)(16 + 8 * nseg), 0) < 0)
        goto bad;
    for (i = 0; i < core; i++)
        if (ld_readin(w, fd, m.banks[i], 0, i < core - 1 ?
                      (unsigned long)ld_rd16(w->hdr + 16 + 8 * i) : expt_at) < 0)
            goto bad;

    /* The relocs, a window at a time, through w->msg. */
    nrel = ld_rd16(w->hdr + 11);
    n = sizeof w->msg / 4;
    for (left = nrel; left; left -= k) {
        k = left > n ? n : left;
        if (read(fd, w->msg, 4 * k) != 4 * k)
            goto bad;
        for (i = 0; i < k; i++) {
            r = (unsigned char *)w->msg + 4 * i;
            src = r[0];
            off = ld_rd16(r + 1);
            tgt = r[3];
            if (src >= nseg || tgt >= nseg || tgt == core ||
                off >= ld_rd16(w->hdr + 16 + 8 * src))
                goto bad;
            q = ld_at(&m, src, off);
            to = tgt == tmpl ? m.tmpl_at : 0;
            if (to)
                ld_wr16(q - 2, ld_rd16(q - 2) + to);
            *q = m.banks[tgt == tmpl ? core - 1 : tgt];
        }
    }

    /* The trailer, still at p: core sites, imports, the tagged blocks. */
    q = ld_blk(p, tlen, "CSIT", &len);
    for (i = 0; i + 3 <= len; i += 3) {
        t = ld_at(&m, q[i], ld_rd16(q + i + 1));
        ld_wr16(t, ld_rd16(t) + (base - cbase));
    }
    q = ld_blk(p, tlen, "IMPS", &len);
    if (q && len && ld_bind_imps(&m, q, dep) < 0)
        goto bad;
    t = (unsigned char *)ld_far(m.banks[core - 1], (unsigned)expt_at);
    for (q = e - 8, i = 0; i < 8 + elen; i++)
        *t++ = *q++;
    for (q = f - 8, i = 0; i < 8 + flen; i++)
        *t++ = *q++;
    /* What follows overwrites the trailer: EXPT is read from its copy. */
    e = (unsigned char *)ld_far(m.banks[core - 1], (unsigned)expt_at + 8);
    /* XIDX: the assembled core base, the count, each EXPT record's offset,
     * so a binder takes an export by ordinal or by a binary search. */
    t[0] = 'X'; t[1] = 'I'; t[2] = 'D'; t[3] = 'X';
    ld_wr16(t + 4, 4 + 2 * nexp);
    t[6] = t[7] = 0;
    ld_wr16(t + 8, cbase);
    ld_wr16(t + 10, nexp);
    t += 12;
    for (i = 0; i < elen; i += 1 + e[i] + 6, t += 2)
        ld_wr16(t, i);
    t[0] = 'E'; t[1] = 'N'; t[2] = 'D'; t[3] = 0;
    t[4] = t[5] = t[6] = t[7] = 0;
    ld_set(w, name, major);
    w->blk.row = row;
    for (q = e, i = 0; i < elen; i += 1 + q[i] + 6) {   /* libc's binder entry */
        n = q[i];
        if (n == 8 && q[i + 1 + n] == 0 && q[i + 1] == '_' && q[i + 2] == 'l' &&
            q[i + 3] == 'd' && q[i + 4] == '_' && q[i + 5] == 'b' &&
            q[i + 6] == 'i' && q[i + 7] == 'n' && q[i + 8] == 'd') {
            off = ld_rd16(q + i + 1 + n + 2);
            w->blk.binder[0] = off;
            w->blk.binder[1] = off >> 8;
            w->blk.binder[2] = m.banks[q[i + 1 + n + 1]];
        }
    }
    close(fd);

    w->blk.minor = fmin;
    for (k = 0; k < 4; k++)
        w->blk.crc[k] = crc[k];
    w->blk.tmpl_off = m.core_at;
    w->blk.expt_off = expt_at;
    w->blk.rows = blen / 6;
    w->blk.pinned = pin;
    w->blk.deps = deps;
    if (ld_ctl(w, LDS_COMMIT) < 0) {
        ld_msg(w, "ld.so: ", name, major, ": the registry refused it");
        goto abort;
    }
    return 1;
bad:
    ld_msg(w, "ld.so: ", name, major, ": not a shared library this loader reads");
close:
    close(fd);
abort:
    ld_set(w, name, major);
    w->blk.row = row;
    ld_ctl(w, LDS_ABORT);
    return -1;
}

int
ld_need(w, name, major, minor, pin)
struct ld_work *w;
char *name;
int major, minor, pin;
{
    struct ld_miss x, y;
    int r, row, have;

    ld_set(w, name, major);
    r = ld_ctl(w, LDS_ACQUIRE);
    if (r < 0) {
        ld_msg(w, "ld.so: ", name, major, errno == EINTR ? ": interrupted" :
               errno == ENOSYS ? ": no library registry (ld.mod)" : ": registry error");
        return -1;
    }
    if (r == 0) {
        if (w->blk.minor < minor)
            ld_old(w, name, major, w->blk.minor, minor);
        return 0;
    }
    row = w->blk.row;
    have = w->blk.nbanks;
    /* A needed library absent: load it, then this one again.  IMPS lists
     * every library this one needs, each after those it needs, so the one
     * ld_fill reports finds its own needs READY. */
    while ((r = ld_fill(w, name, major, minor, pin, row, &have, &x)) == -2) {
        r = ld_fill(w, x.n.name, x.n.major, x.n.minor, 0, x.row, &x.have, &y);
        if (r != 1) {
            if (r == -2) {                      /* its own need absent: not in order */
                ld_msg(w, "ld.so: ", x.n.name, x.n.major,
                       ": a library it needs is not loaded");
                ld_set(w, y.n.name, y.n.major);
                w->blk.row = y.row;
                ld_ctl(w, LDS_ABORT);
                ld_set(w, x.n.name, x.n.major);
                w->blk.row = x.row;
                ld_ctl(w, LDS_ABORT);
            }
            ld_set(w, name, major);
            w->blk.row = row;
            ld_ctl(w, LDS_ABORT);
            return -1;
        }
    }
    return r;
}
