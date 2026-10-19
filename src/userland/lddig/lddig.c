/*
 * lddig -- check what ld_load left in resident libraries' banks against the
 * host's layout of the same libraries (toolchain/src/ld/fgx_lddigest.py,
 * staged as /testbin/ld.digest).  Per library: its row (READY, base, banks,
 * template and tag offsets, block rows); every byte that holds a runtime
 * bank -- each reloc's, each code import site's -- equal to the bank it
 * names; and each bank's digest, those bytes and the per-process fixups
 * taken as 0, equal to the host's.  Prints `LDD <lib> ok' once all of a
 * library's checks pass, else `LDD FAIL <lib> <what>'.  -f names another
 * digest file (ld.digest.pad: the arena moved before termlib).
 *
 * Usage: lddig [-f digests] lib ...
 *
 * The digest h = rotl16(h, 1) ^ byte is linear: byte b at index i of n
 * contributes rotl16(b, (n - 1 - i) % 16), so a byte is taken out by XORing
 * its contribution away, with no copy of the bank.
 *
 * FGX-Provenance: none
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/ldctl.h>

static struct ld_work w;
static char wbuf[4096];
static unsigned char hdr[88], *rel, *tr;
static unsigned trlen, nrel, nseg, core, tmpl, core_at, tmpl_at;
static unsigned long tagend;
static unsigned char banks[8];
static unsigned dg[8];
static unsigned long dlen[8];
static char *digests = "/testbin/ld.digest";
static int bad;

static unsigned
rd16(p)
unsigned char *p;
{
    return p[0] | (p[1] << 8);
}

static unsigned
rotl(v, n)
unsigned v, n;
{
    n &= 15;
    return n ? (v << n) | (v >> (16 - n)) : v;
}

static unsigned char *
at(seg, off, bi, pos)
int seg;
unsigned off;
int *bi;
unsigned *pos;
{
    *bi = seg < core ? seg : core - 1;
    *pos = seg < core ? off : (seg == core ? core_at : tmpl_at) + off;
    return (unsigned char *)(((unsigned long)banks[*bi] << 16) | *pos);
}

/* Take the byte at (bank bi, pos) out of that bank's digest. */
static void
mask(bi, pos)
int bi;
unsigned pos;
{
    unsigned char *p;

    p = (unsigned char *)(((unsigned long)banks[bi] << 16) | pos);
    dg[bi] ^= rotl(*p, (unsigned)((dlen[bi] - 1 - pos) & 15));
}

static void
fail(lib, what)
char *lib, *what;
{
    if (!bad)
        printf("LDD FAIL %s %s\n", lib, what);
    bad = 1;
}

static unsigned char *
tblk(tag, len)
char *tag;
unsigned *len;
{
    unsigned pos, n;

    for (pos = 17; pos + 8 <= trlen; pos += 8 + n) {
        n = rd16(tr + pos + 4);
        if (memcmp((char *)tr + pos, tag, 4) == 0) {
            *len = n;
            return tr + pos + 8;
        }
    }
    *len = 0;
    return (unsigned char *)0;
}

static int
want(lib, base, nb, d)
char *lib;
unsigned *base, *nb, *d;
{
    FILE *f;
    char nm[16];
    int mj, i;

    f = fopen(digests, "r");
    if (f == (FILE *)0)
        return -1;
    while (fscanf(f, "%15s %d %x %u", nm, &mj, base, nb) == 4) {
        for (i = 0; i < *nb && i < 8; i++)
            fscanf(f, "%x", &d[i]);
        if (strcmp(nm, lib) == 0) {
            fclose(f);
            return 0;
        }
    }
    fclose(f);
    return -1;
}

static void
check(lib)
char *lib;
{
    char path[48];
    FILE *f;
    unsigned wbase, wnb, wd[8], elen, flen, len, i, j, k, c, ni, off, pos, d, nexp;
    unsigned long sum, left;
    unsigned char *p, *q, *r, *s, *b, dbanks[4 * 8];
    int bi, src, tgt, nd;

    bad = 0;
    if (want(lib, &wbase, &wnb, wd) < 0) {
        fail(lib, "not in the digest file");
        return;
    }
    memset((char *)&w.blk, 0, sizeof w.blk);
    strcpy(w.blk.name, lib);
    w.blk.major = 1;
    if (ld_ctl(&w, LDS_LOOKUP) < 0 || w.blk.state != LD_READY) {
        fail(lib, "not resident");
        return;
    }
    sprintf(path, "/lib/%s.so.1.%d", lib, w.blk.minor);
    if ((f = fopen(path, "r")) == (FILE *)0) {
        fail(lib, "no file");
        return;
    }
    fread((char *)hdr, 1, 16, f);
    nseg = hdr[6];
    fread((char *)hdr + 16, 1, 8 * nseg, f);
    for (sum = 16 + 8 * nseg, i = 0; i < nseg; i++)
        sum += rd16(hdr + 16 + 8 * i);
    fseek(f, sum, 0);
    nrel = rd16(hdr + 11);
    rel = (unsigned char *)malloc(4 * nrel + 1);
    fread((char *)rel, 1, 4 * nrel, f);
    tr = (unsigned char *)malloc(12288);
    trlen = fread((char *)tr, 1, 12288, f);
    fclose(f);
    core = tr[7];
    tmpl = tr[8];
    core_at = rd16(hdr + 16 + 8 * (core - 1));
    tmpl_at = core_at + rd16(hdr + 16 + 8 * core);
    p = tblk("EXPT", &elen);
    for (nexp = 0, i = 0; p && i < elen; i += 1 + p[i] + 6)
        nexp++;
    tblk("FIXS", &flen);
    tagend = (unsigned long)tmpl_at + rd16(hdr + 16 + 8 * tmpl) + 8 + elen + 8 + flen
        + 12 + 2L * nexp + 8;
    for (i = 0; i < 8; i++)
        banks[i] = w.blk.banks[i];
    tblk("BLKS", &len);
    if (w.blk.nbanks != core || w.blk.core_base != wbase || wnb != core ||
        w.blk.tmpl_off != core_at ||
        w.blk.expt_off != tmpl_at + rd16(hdr + 16 + 8 * tmpl) || w.blk.rows != len / 6)
        fail(lib, "its row");

    /* Digest every bank whole, then take the runtime bytes out. */
    for (i = 0; i < core; i++) {
        dlen[i] = i < core - 1 ? rd16(hdr + 16 + 8 * i) : tagend;
        b = (unsigned char *)((unsigned long)banks[i] << 16);
        for (d = 0, left = dlen[i]; left; left--)
            d = ((d << 1) | (d >> 15)) ^ *b++;
        dg[i] = d;
    }
    for (i = 0; i < nrel; i++) {
        p = rel + 4 * i;
        src = p[0];
        tgt = p[3];
        q = at(src, rd16(p + 1), &bi, &pos);
        if (*q != banks[tgt == tmpl ? core - 1 : tgt])
            fail(lib, "a reloc's bank byte");
        mask(bi, pos);
    }
    p = tblk("FIXS", &flen);
    for (i = 0; i + 2 <= flen; i += 2) {
        at(core, rd16(p + i), &bi, &pos);
        mask(bi, pos);
    }
    p = tblk("IMPS", &len);
    if (p && len) {
        nd = *p++;
        if (nd > 4) {
            fail(lib, "needs more than 4 libraries");
            nd = 0;
        }
        for (i = 0; i < nd; i++) {
            memset((char *)&w.blk, 0, sizeof w.blk);
            memcpy(w.blk.name, (char *)p + 1, p[0]);
            w.blk.major = p[1 + p[0]];
            ld_ctl(&w, LDS_LOOKUP);
            memcpy((char *)dbanks + 8 * i, (char *)w.blk.banks, 8);
            p += 1 + p[0] + 8;
            p += 1 + (p[0] + 7) / 8;
        }
        ni = rd16(p);
        r = p + 2;
        for (s = r, i = 0; i < ni; i++)
            s += 4 + s[3] + 6;
        for (i = 0; i < ni; i++) {
            k = r[4 + r[3]];                    /* kind */
            j = r[5 + r[3]];                    /* segment */
            nd = r[0];                          /* library */
            r += 4 + r[3] + 6;
            for (c = 0; c < 3; c++) {
                len = rd16(s);
                s += 2;
                for (off = 0; off < len; off++, s += c == 2 ? 5 : 3) {
                    if (k != 0 || c == 2)
                        continue;
                    q = at(s[0], rd16(s + 1) + 2, &bi, &pos);
                    if (*q != dbanks[8 * nd + j])
                        fail(lib, "a code import's bank byte");
                    mask(bi, pos);
                }
            }
        }
    }
    for (i = 0; i < core; i++)
        if (dg[i] != wd[i]) {
            sprintf(path, "bank %d digest %04x, host %04x", i, dg[i], wd[i]);
            fail(lib, path);
        }
    free((char *)rel);
    free((char *)tr);
    if (!bad)
        printf("LDD %s ok\n", lib);
}

int
main(argc, argv)
int argc;
char **argv;
{
    int i;

    w.buf = wbuf;
    w.bufsz = sizeof wbuf;
    i = 1;
    if (argc > 2 && strcmp(argv[1], "-f") == 0) {
        digests = argv[2];
        i = 3;
    }
    for (; i < argc; i++)
        check(argv[i]);
    return 0;
}
