/*
 * ld_bind -- bind a dynamic program to its shared libraries on the machine
 * (shared libc SP4 spec, section 5.3): each needed library resident (loaded
 * on first use by ld_need), the program's sites patched -- the recorded
 * values when the library's export CRC is the recorded one, else each name
 * through the library's export index -- each needed core copied into this
 * data bank with its per-process fixups set, HEAP_LIM lowered to the
 * lowest.  crt0_dyn has already copied libc's core, and hands over libc's
 * row as its ACQUIRE left it; _ld_bind seeded libc's _fcc_dbr.
 *
 * Per exec this is the cost a dynamic program pays over a static one
 * (spec section 8), so libc costs no syscall, a library's row comes from
 * the ACQUIRE or COMMIT that made it resident, each library's tagged
 * blocks are walked once, and its block table's address is the program's
 * own import of _<lib>_blktab -- which a program that wants none of the
 * library's blocks does not import, since its crt0 has no _lib_init call
 * to make for it.
 *
 * The program's code is shared text (SP5 spec, section 5.2): its tables end
 * with a bind record -- the banks, core base and export CRC of each library
 * the code segments were patched against.  When it matches the rows this
 * exec ACQUIREd, only the data segment's sites are patched; otherwise the
 * record is cleared, every site patched, and the record written last.
 *
 * With LD_TRACE_LOADED_OBJECTS in the environment it prints each library
 * as rtld does (`-lc.1 => /lib/libc.so.1.0' and FGX's fields) and exits;
 * with LD_BIND_DIGEST, a digest of every site it patched, each bank
 * normalised to (library, segment), and exits -- fgx_bind --digest prints
 * the same for the same libraries.
 *
 * No statics and no stdio: this process's blocks do not exist yet.  Its
 * struct ld_work sits above the break, and a first-use load needs no room
 * past it: ld_load reads /lib and the relocs through w->msg and a library's
 * trailer into that library's own bank.  Messages are SunOS 4.1.3 rtld's (lang/rtld/rtld.c).
 */
#define LB_NLIB     4
#define LB_NSEG     10

struct lb_lib {
    char name[16];
    unsigned char major, minor, pre, loaded, last, rows;
    unsigned char crc[4], rcrc[4];              /* as linked against; the row's */
    unsigned char banks[LD_MAXBANKS];
    unsigned base, abase, csize, tmpl, recbase, nexp, nfix, blktab;
    unsigned char *bits, *expt, *xidx, *fixs;
};

static char *
lb_far(bank, off)
unsigned bank, off;
{
    return (char *)(((unsigned long)bank << 16) | off);
}

/* The library's row (`b', as ACQUIRE or COMMIT left it) into L, and its
 * tagged blocks -- EXPT, FIXS, XIDX up to END -- found once.  0 if the chain
 * is not well formed within the bank. */
static int
lb_row(L, b)
struct lb_lib *L;
struct ldblk *b;
{
    unsigned char *p;
    unsigned at, n, k;

    for (k = 0; k < LD_MAXBANKS; k++)
        L->banks[k] = b->banks[k];
    L->last = b->banks[b->nbanks - 1];
    L->base = b->core_base;
    L->csize = b->core_size;
    L->tmpl = b->tmpl_off;
    L->minor = b->minor;
    for (L->pre = 1, k = 0; k < 4; k++) {
        L->rcrc[k] = b->crc[k];
        if (b->crc[k] != L->crc[k])
            L->pre = 0;
    }
    L->expt = L->xidx = L->fixs = (unsigned char *)0;
    for (at = b->expt_off; at < 0xFFF8; at += 8 + n) {
        p = (unsigned char *)lb_far(L->last, at);
        n = ld_rd16(p + 4);
        if (p[0] == 'E' && p[1] == 'N' && p[2] == 'D')
            break;
        if (p[0] == 'E' && p[1] == 'X')
            L->expt = p + 8;
        else if (p[0] == 'F' && p[1] == 'I') {
            L->fixs = p + 8;
            L->nfix = n / 2;
        } else if (p[0] == 'X' && p[1] == 'I')
            L->xidx = p + 8;
        if ((unsigned long)at + 8 + n > 0xFFF8L)
            return 0;
    }
    if (L->expt == 0 || L->xidx == 0 || at >= 0xFFF8)
        return 0;
    L->abase = ld_rd16(L->xidx);
    L->nexp = ld_rd16(L->xidx + 2);
    return b->rows == L->rows ? 1 : -1;
}

static int
lb_cmp(r, name, n)
unsigned char *r, *name;
int n;
{
    int i;

    for (i = 0; i < r[0] && i < n; i++)
        if (r[1 + i] != name[i])
            return r[1 + i] < name[i] ? -1 : 1;
    return r[0] < n ? -1 : r[0] > n;
}

/* The export `name' (n bytes): its recorded ordinal first, then a binary
 * search of EXPT's sorted names through the index. */
static unsigned char *
lb_find(L, ordinal, name, n)
struct lb_lib *L;
unsigned ordinal;
unsigned char *name;
int n;
{
    unsigned char *r;
    unsigned lo, hi, mid;
    int c;

    if (ordinal < L->nexp) {
        r = L->expt + ld_rd16(L->xidx + 4 + 2 * ordinal);
        if (lb_cmp(r, name, n) == 0)
            return r;
    }
    lo = 0;
    hi = L->nexp;
    while (lo < hi) {
        mid = (lo + hi) / 2;
        r = L->expt + ld_rd16(L->xidx + 4 + 2 * mid);
        c = lb_cmp(r, name, n);
        if (c == 0)
            return r;
        if (c < 0)
            lo = mid + 1;
        else
            hi = mid;
    }
    return (unsigned char *)0;
}

/* "ld.so: <a><b><c>\n" on fd 2 (b: n bytes, up to 40), then exit 1. */
static void
lb_die(w, a, b, n, c)
struct ld_work *w;
char *a, *c;
unsigned char *b;
int n;
{
    char *p;
    int i;

    p = ld_cat(w->msg, "ld.so: ");
    p = ld_cat(p, a);
    for (i = 0; b && i < n && i < 40; i++)
        *p++ = b[i];
    p = ld_cat(p, c);
    *p++ = '\n';
    write(2, w->msg, p - w->msg);
    _exit(1);
}

static int
lb_len(s)
char *s;
{
    int n;

    for (n = 0; s[n]; n++)
        ;
    return n;
}

static char *
lb_hex(p, v, n)
char *p;
unsigned v;
int n;
{
    while (n--)
        *p++ = "0123456789abcdef"[(v >> (4 * n)) & 15];
    return p;
}

/* Does import `nm' (n bytes) name library L's block table, _<lib>_blktab? */
static int
lb_isbt(L, nm, n)
struct lb_lib *L;
unsigned char *nm;
int n;
{
    int k, ln;

    ln = lb_len(L->name);
    if (n != ln + 8 || nm[0] != '_')
        return 0;
    for (k = 0; k < ln; k++)
        if (nm[1 + k] != L->name[k])
            return 0;
    return nm[1 + ln] == '_' && nm[2 + ln] == 'b' && nm[3 + ln] == 'l' &&
           nm[4 + ln] == 'k' && nm[5 + ln] == 't' && nm[6 + ln] == 'a' &&
           nm[7 + ln] == 'b';
}

#define LB_TRACE    1
#define LB_DIGEST   2

/* LD_TRACE_LOADED_OBJECTS and LD_BIND_DIGEST, in one walk of the kernel's
 * frame (bank 0: argc, then argv's 16-bit pointers to a 0, then envp's). */
static int
lb_env(frame)
unsigned frame;
{
    unsigned *v;
    char *e, *var;
    int i, j, f;

    f = 0;
    v = (unsigned *)(unsigned long)frame + 1;
    while (*v)
        v++;
    for (v++; *v; v++) {
        e = (char *)(unsigned long)*v;
        if (e[0] != 'L' || e[1] != 'D')
            continue;
        for (j = 0; j < 2; j++) {
            var = j ? "LD_BIND_DIGEST" : "LD_TRACE_LOADED_OBJECTS";
            for (i = 0; var[i] && e[i] == var[i]; i++)
                ;
            if (var[i] == 0 && e[i] == '=')
                f |= 1 << j;
        }
    }
    return f;
}

static unsigned
lb_rotx(h, b)
unsigned h, b;
{
    return ((h << 1) | (h >> 15)) ^ (b & 0xFF);
}

int
ld_bind(frame, tab, copy, blk)
unsigned frame;
unsigned char *tab;
int (*copy)();
struct ldblk *blk;
{
    struct lb_lib lib[LB_NLIB];
    struct ld_seg seg[LB_NSEG];
    struct lb_lib *L;
    struct ld_work *w;
    unsigned long bank;
    unsigned brk, at0, lowest, need, nseg, i, k, c, n, val, delta, ni, ord, at, h, nd, f, w5;
    unsigned dseg, ilen, nskip;
    unsigned char *p, *r, *s, *e, *nm, *bt, *rec;
    char *prog, *q;
    int nlib, li, kind, sg, rr, isc, fl, j, match;

    bank = (unsigned long)(char *)&errno & 0xFF0000L;  /* libc's core: this data bank */
    brk = *(unsigned *)(bank | 0xFFFEL);                 /* HEAP_BRK, the data's end */
    prog = (char *)(unsigned long)((unsigned *)(unsigned long)frame)[1];  /* argv[0] */
    fl = lb_env(frame);
    h = nd = nskip = 0;
    at0 = (brk + 1) & 0xFFFE;
    w = (struct ld_work *)(bank | at0);
    if ((unsigned long)at0 + sizeof *w >= blk->core_base) {
        /* Not through lb_die: its message is built in w->msg, and w is
         * exactly what does not fit -- it would land in libc's core, which
         * crt0 has just copied and this code runs on. */
        j = lb_len(prog);
        write(2, "ld.so: ", 7);
        write(2, prog, j < 40 ? j : 40);
        write(2, ": no room for its data\n", 23);
        _exit(1);
    }
    w->bufsz = 0;                                       /* no ld_needs here */

    nseg = ld_rd16(tab);
    if (nseg > LB_NSEG)
        lb_die(w, "", (unsigned char *)prog, lb_len(prog), ": too many segments");
    dseg = tab[2];
    if (dseg >= nseg)
        lb_die(w, "", (unsigned char *)prog, lb_len(prog), ": a bad import table");
    for (i = 0; i < nseg; i++) {
        seg[i].off = ld_rd16(tab + 4 + 4 * i);
        seg[i].bank = tab[4 + 4 * i + 2];
    }
    /* The data segment is this process's, read fresh from the file: its
     * cell was relocated once, by the first load of this text, and holds
     * that process's bank (SP5 spec, section 5.2). */
    seg[dseg].bank = (unsigned char)(bank >> 16);
    ilen = ld_rd16(tab + 4 + 4 * nseg);
    p = tab + 6 + 4 * nseg;                             /* IMPS */
    rec = p + ilen;                                     /* the bind record */

    /* The libraries, in load order: each resident, its row read. */
    nlib = *p++;
    if (nlib > LB_NLIB)
        lb_die(w, "", (unsigned char *)prog, lb_len(prog), ": needs too many libraries");
    for (li = 0; li < nlib; li++) {
        L = &lib[li];
        n = *p++;
        for (k = 0; k < n && k < 15; k++)
            L->name[k] = p[k];
        L->name[k] = 0;
        p += n;
        L->major = p[0];
        for (k = 0; k < 4; k++)
            L->crc[k] = p[2 + k];
        L->recbase = ld_rd16(p + 6);
        L->rows = p[8];
        L->bits = p + 9;
        L->blktab = 0;
        isc = L->name[0] == 'l' && L->name[1] == 'i' && L->name[2] == 'b' &&
              L->name[3] == 'c' && L->name[4] == 0 && L->major == 1;
        if (isc) {                                      /* crt0's ACQUIRE */
            L->loaded = 0;
            rr = lb_row(L, blk);
        } else {
            rr = ld_need(w, L->name, L->major, p[1], 0);
            if (rr < 0) {
                if (!(fl & LB_TRACE))
                    _exit(1);                           /* ld_need said why */
                q = ld_cat(w->msg, "\t-l");
                q = ld_cat(q, L->name + 3);             /* libfoo -> foo */
                *q++ = '.';
                q = ld_num(q, L->major);
                q = ld_cat(q, " => not found\n");
                write(1, w->msg, q - w->msg);
                L->base = 0;                            /* absent: traced, skipped */
                p += 9 + (p[8] + 7) / 8;
                continue;
            }
            L->loaded = rr == 1;
            rr = lb_row(L, &w->blk);                    /* ACQUIRE's or COMMIT's row */
        }
        if (rr == 0)
            lb_die(w, "", (unsigned char *)L->name, lb_len(L->name),
                   ": a bad export table");
        if (rr < 0) {
            q = ld_cat(w->path, L->name);               /* lb_die builds in msg */
            q = ld_cat(q, ": ");
            *q = 0;
            lb_die(w, w->path, (unsigned char *)prog, lb_len(prog), " needs relinking");
        }
        p += 9 + (p[8] + 7) / 8;
    }

    /* The bind record (SP5 spec, sections 5.2, 5.3): the code segments were
     * patched against these banks, core bases and export CRCs.  A match
     * skips their sites; anything else repatches them, the record cleared
     * first so an lb_die part-way leaves none behind.  The digest patches
     * every site and leaves a matching record as it is. */
    match = rec[0] | rec[1];
    for (li = 0; li < nlib && match; li++) {
        L = &lib[li];
        e = rec + 2 + 14 * li;
        if (L->base == 0 || ld_rd16(e + 8) != L->base)
            match = 0;
        for (k = 0; k < LD_MAXBANKS && match; k++)
            if (e[k] != L->banks[k])
                match = 0;
        for (k = 0; k < 4 && match; k++)
            if (e[10 + k] != L->rcrc[k])
                match = 0;
    }
    if (!match)
        rec[0] = rec[1] = 0;
    if (fl & LB_DIGEST)
        match = 0;

    /* The imports: their records, then their sites, two cursors. */
    ni = ld_rd16(p);
    r = p + 2;
    for (s = r, i = 0; i < ni; i++)
        s += 4 + s[3] + 6;
    for (i = 0; i < ni; i++) {
        li = r[0];
        ord = ld_rd16(r + 1);
        n = r[3];
        nm = r + 4;
        kind = r[4 + n];
        sg = r[5 + n];
        val = ld_rd16(r + 6 + n);
        L = &lib[li];
        if (L->base == 0) {                             /* absent, under the trace */
            r += 4 + n + 6;
            for (k = 0; k < 3; k++)
                s += 2 + (k == 2 ? 5 : 3) * ld_rd16(s);
            continue;
        }
        if (L->pre)
            delta = L->base - L->recbase;
        else {
            e = lb_find(L, ord, nm, n);
            if (e == 0 || e[1 + e[0]] != kind ||
                (kind == 1 && ld_rd16(e + 1 + e[0] + 4) < ld_rd16(r + 8 + n)))
                lb_die(w, "Undefined symbol: ", nm, n, "");
            at = ld_rd16(e + 1 + e[0] + 2);
            if (kind == 0) {
                sg = e[1 + e[0] + 1];
                val = at;
            } else
                delta = at + (L->base - L->abase) - val;
        }
        if (kind == 1 && lb_isbt(L, nm, n))
            L->blktab = val + delta;                    /* where its table now is */
        r += 4 + n + 6;
        for (k = 0; k < 3; k++) {                       /* call, ptr, data */
            c = ld_rd16(s);
            s += 2;
            if (c && (kind == 0) != (k < 2))
                lb_die(w, "", (unsigned char *)prog, lb_len(prog),
                       ": a bad import table");
            w5 = k == 2 ? 5 : 3;                        /* a data site carries its word */
            if (c)
                _ld_patch(s, c, seg, kind, kind == 0 ? val : delta,
                          kind == 0 ? L->banks[sg] : 0, match ? dseg : 0xFF);
            if (match && (fl & LB_TRACE))
                for (j = 0; j < c; j++)
                    nskip += s[w5 * j] != dseg;
            if (fl & LB_DIGEST)
                for (j = 0; j < c; j++, nd++) {
                    e = (unsigned char *)lb_far(seg[s[w5 * j]].bank,
                                                seg[s[w5 * j]].off + ld_rd16(s + w5 * j + 1));
                    h = lb_rotx(h, e[0]);
                    h = lb_rotx(h, e[1]);
                    if (k < 2)
                        h = lb_rotx(h, 16 * li + sg);
                }
            s += w5 * c;
        }
    }

    /* Every site patched: the record, last. */
    if (!match && !(fl & LB_DIGEST)) {
        for (li = 0; li < nlib; li++) {
            L = &lib[li];
            if (L->base == 0)
                break;                                  /* traced absent: no record */
            e = rec + 2 + 14 * li;
            for (k = 0; k < LD_MAXBANKS; k++)
                e[k] = L->banks[k];
            e[8] = (unsigned char)L->base;
            e[9] = (unsigned char)(L->base >> 8);
            for (k = 0; k < 4; k++)
                e[10 + k] = L->rcrc[k];
        }
        if (li == nlib)
            rec[0] = 1;                                 /* bound */
    }

    /* The cores: each but libc's copied (crt0 copied libc's), every
     * core's per-process fixups set to this data bank; the fit, the data's
     * end below the lowest core less the blocks the bitmaps reach. */
    lowest = 0xFFF8;
    need = 0;
    for (li = 0; li < nlib; li++) {
        L = &lib[li];
        if (L->base == 0)
            continue;                                   /* absent, under the trace */
        if (L->base < lowest)
            lowest = L->base;
        isc = li == 0 && L->name[3] == 'c' && L->name[4] == 0;
        if (!isc)
            (*copy)(lb_far((unsigned)(bank >> 16), L->base),
                    lb_far(L->last, L->tmpl), L->csize);
        for (k = 0; k < L->nfix; k++)
            *(unsigned char *)(bank | (unsigned long)(L->base + ld_rd16(L->fixs + 2 * k))) =
                (unsigned char)(bank >> 16);
        if ((fl & LB_DIGEST) && !isc)                   /* each copy this made is */
            for (i = 0; i < L->csize; i++) {            /* its template but at its
                                                         * fixups (libc's core is
                                                         * this binder's own state) */
                r = (unsigned char *)lb_far((unsigned)(bank >> 16), L->base + i);
                e = (unsigned char *)lb_far(L->last, L->tmpl + i);
                if (*r == *e)
                    continue;
                for (f = 0, k = 0; k < L->nfix; k++)
                    f |= ld_rd16(L->fixs + 2 * k) == i;
                if (!f)
                    lb_die(w, "", (unsigned char *)L->name, lb_len(L->name),
                           ": core copy differs");
            }
        if (L->blktab == 0) {                           /* no table imported: */
            for (k = 0; k < L->rows; k++)               /* only right when it */
                if (L->bits[k >> 3] & (1 << (k & 7)))   /* wants no block */
                    lb_die(w, "", (unsigned char *)prog, lb_len(prog),
                           ": a bad import table");
            continue;
        }
        bt = (unsigned char *)(bank | (unsigned long)L->blktab);
        for (k = 0; ld_rd16(bt + 8 * k); k++)
            if (L->bits[k >> 3] & (1 << (k & 7)))
                need += ld_rd16(bt + 8 * k + 6);
    }
    if (brk > lowest - need) {
        q = ld_cat(w->path, ": no room for its data (ends $");
        q = lb_hex(q, brk, 4);
        q = ld_cat(q, ", LIM $");
        q = lb_hex(q, lowest - need, 4);
        q = ld_cat(q, ")");
        *q = 0;
        lb_die(w, "", (unsigned char *)prog, lb_len(prog), w->path);
    }
    *(unsigned *)(bank | 0xFFF8L) = lowest;             /* HEAP_LIM */
    if (fl & LB_DIGEST) {
        q = ld_cat(w->msg, "LDB sites ");
        q = lb_hex(q, h, 4);
        q = ld_cat(q, " n=");
        q = ld_num(q, nd);
        *q++ = '\n';
        write(1, w->msg, q - w->msg);
        _exit(0);
    }
    if (fl & LB_TRACE) {
        for (li = 0; li < nlib; li++) {
            L = &lib[li];
            if (L->base == 0)
                continue;
            q = ld_cat(w->msg, "\t-l");
            q = ld_cat(q, L->name + 3);                 /* libc -> c */
            *q++ = '.';
            q = ld_num(q, L->major);
            q = ld_cat(q, " => /lib/");
            q = ld_cat(q, L->name);
            q = ld_cat(q, ".so.");
            q = ld_num(q, L->major);
            *q++ = '.';
            q = ld_num(q, L->minor);
            q = ld_cat(q, " (core $");
            q = lb_hex(q, L->base, 4);
            q = ld_cat(q, L->pre ? ", prebound, " : ", by name, ");
            q = ld_cat(q, L->loaded ? "loaded)\n" : "resident)\n");
            write(1, w->msg, q - w->msg);
        }
        q = ld_cat(w->msg, match ? "\ttext bound, " : "\ttext patched, ");
        q = ld_num(q, nskip);
        q = ld_cat(q, " code sites skipped\n");
        write(1, w->msg, q - w->msg);
        for (need = 0xFFF8 - lowest, li = 0; li < nlib; li++)
            need -= lib[li].base ? lib[li].csize : 0;
        q = ld_cat(w->msg, "\t");
        q = ld_num(q, need);
        q = ld_cat(q, " bytes of unused cores between them\n");
        write(1, w->msg, q - w->msg);
        _exit(0);
    }
    return 0;
}
