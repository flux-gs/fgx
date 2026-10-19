/* FGX-Origin: original -- FGX code.  Nothing here derives from the Regents'
 * work.  It follows BSD's modload(8) only in the order it asks the kernel for
 * things, and it follows Apple's OMF loader (GS.OS/Loader/ExpressLoad.a in
 * System 6.0.1) in what each relocation record means.
 */
/* loadcda(8) -- install a classic desk accessory.
 *
 *     loadcda file
 *
 * A CDA is an OMF load file (ProDOS type $B9).  This reads its static load
 * segments, asks /dev/cda (cda.mod) for a block to hold them all, relocates
 * each segment for its place in that block, copies it in, and has the Desk
 * Manager install it -- so it appears in the Ctrl-OA-Esc menu until the machine
 * restarts.  The first load segment must begin with the CDA header, as the
 * Desk Manager requires.
 *
 * THE ORDER IS BSD modload(8)'s over /dev/lkm: reserve (the kernel says where),
 * relocate here, load, then make it live; closing the device before the last
 * step gives the block back.  Only the super-user can open /dev/cda.
 *
 * WHAT IS REFUSED, BY NAME: an OMF version other than 2, a dynamic segment
 * other than ~ExpressLoad (which only speeds a GS/OS load and is skipped), a
 * segment that is neither code nor data, a segment with an absolute ORG, a CDA
 * whose static segments do not fit one bank, and any record this does not
 * implement -- among them the SUPER INTERSEG forms.  A half-relocated image is
 * worse than none.
 *
 * A DESK ACCESSORY MAY READ ITS OWN RESOURCE FORK, so this hands cda.mod a
 * second block: the file's absolute pathname as a class 1 GS/OS string (a
 * length word, then the characters), then the resource fork from `._NAME'
 * beside it, the AppleDouble file (RFC 1740, big-endian) FGX's ProDOS
 * filesystem presents and a copy onto UFS keeps.  Without a `._NAME' the block
 * holds the pathname alone.  cda.mod serves both from memory while the CDA
 * runs, through its GS/OS and System Loader stubs.
 *
 * THE ARGUMENT STRUCTURES AND THE COPY BUFFER MUST LIVE IN THE DATA BANK.  The
 * kernel takes an ioctl argument's bank from the caller's data bank, and so
 * does cda.mod for the buffer it copies from; malloc under $F000 comes from the
 * break, which is in the data bank (libc_c/malloc.c), so the segment buffers
 * qualify as well as the globals.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/param.h>

/* MUST match src/modules/cda/cda.s. */
#define CDAIOCRESERVE   0x6301
#define CDAIOCLOAD      0x6302
#define CDAIOCINSTALL   0x6303
#define CDAIOCFORK      0x6304

struct cdareserve {
    unsigned long size;         /* in */
    unsigned long addr;         /* out: the block's address */
};

struct cdaload {
    unsigned off;               /* where in the block */
    unsigned len;
    unsigned buf;               /* low 16 bits of a data-bank buffer */
    unsigned which;             /* 0 the CDA, 1 its pathname and fork */
};

#define MAXSEG      16
#define HDRLEN      0x2C        /* OMF v2 segment header through DISPDATA */
#define CHUNK       1024
#define KIND_TYPE   0x1F
#define KIND_DYN    0x8000
#define AD_MAGIC    0x00051607L /* RFC 1740 AppleDouble */
#define AD_HDRLEN   26          /* magic, version, filler, entry count */
#define AD_RSRC     2L          /* entry ID: Resource Fork */

struct seg {
    long          pos;          /* file offset of its header */
    unsigned long bytecnt;
    unsigned long length;
    unsigned      dispdata;
    unsigned      num;
    unsigned      off;          /* offset in the block; load segments only */
    int           load;
};

struct cdareserve rsv;
struct cdareserve fk;
struct cdaload    ld;
struct seg        segs[MAXSEG];
int               nseg;
unsigned char     hdr[HDRLEN];
char             *prog = "loadcda";
char             *path;
char              apath[MAXPATHLEN * 2];
char              adpath[MAXPATHLEN * 2 + 2];
unsigned char     buf[CHUNK];

int
fail(why)
char *why;
{
    printf("%s: %s: %s\n", prog, path, why);
    return (1);
}

unsigned
w16(p)
unsigned char *p;
{
    return (p[0] | (p[1] << 8));
}

unsigned long
w32(p)
unsigned char *p;
{
    return ((unsigned long)w16(p) | ((unsigned long)w16(p + 2) << 16));
}

/* be32 -- a big-endian long, as RFC 1740 stores every AppleDouble field. */
unsigned long
be32(p)
unsigned char *p;
{
    return (((unsigned long)p[0] << 24) | ((unsigned long)p[1] << 16) |
            ((unsigned long)p[2] << 8) | (unsigned long)p[3]);
}

/* sbyte -- a relocation record's bit shift, a signed byte (negative is right). */
int
sbyte(b)
unsigned b;
{
    return (b > 127 ? (int)b - 256 : (int)b);
}

/* readall -- n bytes at pos into buf.  0 or -1. */
int
readall(fd, pos, buf, n)
int            fd;
long           pos;
unsigned char *buf;
unsigned       n;
{
    int k;

    if (lseek(fd, pos, 0) != pos)
        return (-1);
    while (n > 0) {
        k = read(fd, (char *)buf, n > 16000 ? 16000 : n);
        if (k <= 0)
            return (-1);
        buf += k;
        n -= k;
    }
    return (0);
}

/* put -- n bytes at p into block `which' at off, a chunk at a time.  0 or -1. */
int
put(dev, which, off, p, n)
int            dev;
unsigned       which;
unsigned       off;
unsigned char *p;
unsigned       n;
{
    unsigned k;

    for (k = 0; k < n; k += ld.len) {
        ld.which = which;
        ld.off = off + k;
        ld.len = n - k > CHUNK ? CHUNK : n - k;
        ld.buf = (unsigned)(unsigned long)p + k;
        if (ioctl(dev, CDAIOCLOAD, (char *)&ld) < 0)
            return (-1);
    }
    return (0);
}

/* segbase -- the absolute address of load segment `num', or 0. */
unsigned long
segbase(num)
unsigned num;
{
    int i;

    for (i = 0; i < nseg; i++)
        if (segs[i].load && segs[i].num == num)
            return (rsv.addr + segs[i].off);
    return (0L);
}

/* patch -- ExpressLoad's shift_patch: store `v' shifted by `shift' (negative
 * is right) in the `cnt' bytes of the image at `at'. */
int
patch(img, len, at, cnt, shift, v)
unsigned char *img;
unsigned       len;
unsigned long  at;
int            cnt;
int            shift;
unsigned long  v;
{
    unsigned i;

    if (cnt < 1 || cnt > 4 || at + cnt > len)
        return (-1);
    if (shift < 0)
        v >>= -shift;
    else
        v <<= shift;
    for (i = (unsigned)at; i < (unsigned)at + cnt; i++) {
        img[i] = (unsigned char)v;
        v >>= 8;
    }
    return (0);
}

/* super -- a SUPER RELOC2 (width 2) or RELOC3 (width 3) record's body: page-
 * coded offsets, ExpressLoad's reloc2 and reloc3.  A byte with its high bit set
 * skips that many pages; otherwise its low seven bits plus one offsets follow,
 * each patched in the current page, and the page advances by one. */
int
super(img, len, d, n, width, base)
unsigned char *img;
unsigned       len;
unsigned char *d;
unsigned       n;
int            width;
unsigned long  base;
{
    unsigned      i, page, k, a;
    unsigned long at, v;
    int           cnt;

    i = 0;
    page = 0;
    while (i < n) {
        k = d[i++];
        if (k & 0x80) {
            page += k & 0x7F;
            continue;
        }
        for (cnt = (k & 0x7F) + 1; cnt > 0; cnt--) {
            if (i >= n)
                return (-1);
            at = ((unsigned long)page << 8) + d[i++];
            if (at + width > len)
                return (-1);
            a = (unsigned)at;
            if (width == 2) {
                v = (unsigned long)w16(img + a) + (base & 0xFFFFL);
                img[a] = (unsigned char)v;
                img[a + 1] = (unsigned char)(v >> 8);
            } else {
                v = (unsigned long)w16(img + a)
                    | ((unsigned long)img[a + 2] << 16);
                v += base;
                img[a] = (unsigned char)v;
                img[a + 1] = (unsigned char)(v >> 8);
                img[a + 2] = (unsigned char)(v >> 16);
            }
        }
        page++;
    }
    return (0);
}

/* build -- one load segment's image from its body, relocated.  0 or a reason. */
char *
build(sg, body, blen, img)
struct seg    *sg;
unsigned char *body;
unsigned       blen;
unsigned char *img;
{
    unsigned      p, pc, len, n;
    unsigned long base, tb, v, off;
    int           op, cnt, shift;

    len = (unsigned)sg->length;
    base = rsv.addr + sg->off;
    p = 0;
    pc = 0;
    for (;;) {
        if (p >= blen)
            return ("segment has no END record");
        op = body[p];
        if (op == 0x00)
            return ((char *)0);
        if (op < 0xE0) {                        /* CONST */
            if (p + 1 + op > blen || pc + op > len)
                return ("CONST past its segment");
            memcpy((char *)img + pc, (char *)body + p + 1, op);
            pc += op;
            p += 1 + op;
            continue;
        }
        switch (op) {
        case 0xF2:                              /* LCONST */
            n = (unsigned)w32(body + p + 1);
            if (p + 5 + n > blen || pc + n > len)
                return ("LCONST past its segment");
            memcpy((char *)img + pc, (char *)body + p + 5, n);
            pc += n;
            p += 5 + n;
            break;
        case 0xF1:                              /* DS */
            n = (unsigned)w32(body + p + 1);
            if (w32(body + p + 1) > (unsigned long)(len - pc))
                return ("DS past its segment");
            pc += n;
            p += 5;
            break;
        case 0xE2:                              /* RELOC */
            cnt = body[p + 1];
            shift = sbyte(body[p + 2]);
            off = w32(body + p + 3);
            v = base + w32(body + p + 7);
            if (patch(img, len, off, cnt, shift, v) < 0)
                return ("RELOC out of range");
            p += 11;
            break;
        case 0xF5:                              /* cRELOC */
            cnt = body[p + 1];
            shift = sbyte(body[p + 2]);
            off = w16(body + p + 3);
            v = base + w16(body + p + 5);
            if (patch(img, len, off, cnt, shift, v) < 0)
                return ("cRELOC out of range");
            p += 7;
            break;
        case 0xE3:                              /* INTERSEG */
            if (w16(body + p + 7) != 1)
                return ("INTERSEG into another file");
            tb = segbase(w16(body + p + 9));
            if (tb == 0L)
                return ("INTERSEG to a segment not loaded");
            cnt = body[p + 1];
            shift = sbyte(body[p + 2]);
            off = w32(body + p + 3);
            if (patch(img, len, off, cnt, shift, tb + w32(body + p + 11)) < 0)
                return ("INTERSEG out of range");
            p += 15;
            break;
        case 0xF6:                              /* cINTERSEG */
            tb = segbase(body[p + 5]);
            if (tb == 0L)
                return ("cINTERSEG to a segment not loaded");
            cnt = body[p + 1];
            shift = sbyte(body[p + 2]);
            off = w16(body + p + 3);
            if (patch(img, len, off, cnt, shift, tb + w16(body + p + 6)) < 0)
                return ("cINTERSEG out of range");
            p += 8;
            break;
        case 0xF7:                              /* SUPER */
            n = (unsigned)w32(body + p + 1);
            if (n < 1 || p + 5 + n > blen)
                return ("SUPER past its segment");
            if (body[p + 5] > 1)
                return ("SUPER INTERSEG records are not supported");
            if (super(img, len, body + p + 6, n - 1,
                      body[p + 5] == 0 ? 2 : 3, base) < 0)
                return ("SUPER relocation out of range");
            p += 5 + n;
            break;
        default:
            return ("an OMF record this loader does not implement");
        }
    }
}

int
main(argc, argv)
int    argc;
char **argv;
{
    int            fd, dev, rfd, i;
    long           pos, end;
    unsigned       total, n, blen, k, lablen, dispname, plen;
    unsigned long  foff, flen, done;
    unsigned char *body, *img;
    char          *why, name[16];

    if (argc != 2) {
        printf("usage: loadcda file\n");
        return (1);
    }
    path = argv[1];
    fd = open(path, O_RDONLY);
    if (fd < 0)
        return (fail(strerror(errno)));
    end = lseek(fd, 0L, 2);

    /* Every segment header, and where each load segment goes. */
    total = 0;
    for (pos = 0L; pos < end; pos += segs[nseg++].bytecnt) {
        if (nseg == MAXSEG)
            return (fail("too many segments"));
        if (readall(fd, pos, hdr, HDRLEN) < 0)
            return (fail("short segment header"));
        if (hdr[0x0F] != 2 || hdr[0x0E] != 4 || hdr[0x20] != 0)
            return (fail("not an OMF version 2 load file"));
        segs[nseg].pos = pos;
        segs[nseg].bytecnt = w32(hdr);
        segs[nseg].length = w32(hdr + 8);
        segs[nseg].num = w16(hdr + 0x22);
        segs[nseg].dispdata = w16(hdr + 0x2A);
        if (segs[nseg].bytecnt < HDRLEN || pos + segs[nseg].bytecnt > end)
            return (fail("segment runs past the end of the file"));

        lablen = hdr[0x0D];
        dispname = w16(hdr + 0x28);
        memset(name, 0, sizeof(name));
        if (lablen == 0) {
            if (readall(fd, pos + dispname + 10, (unsigned char *)name, 1) < 0)
                return (fail("short segment name"));
            k = (unsigned char)name[0];
            if (k > 15)
                k = 15;
            if (readall(fd, pos + dispname + 11, (unsigned char *)name, k) < 0)
                return (fail("short segment name"));
            name[k] = 0;
        }

        k = w16(hdr + 0x14);
        if (k & KIND_DYN) {
            if (strcmp(name, "~ExpressLoad") != 0)
                return (fail("a dynamic segment"));
            continue;                           /* only speeds a GS/OS load */
        }
        if ((k & KIND_TYPE) > 1)
            return (fail("a segment that is neither code nor data"));
        if (w32(hdr + 0x18) != 0L)
            return (fail("a segment with an absolute ORG"));
        if (segs[nseg].length > 0xFFFFL - total)
            return (fail("larger than one bank"));
        segs[nseg].load = 1;
        segs[nseg].off = total;
        total += (unsigned)segs[nseg].length;
    }
    if (total == 0)
        return (fail("no load segments"));

    dev = open("/dev/cda", O_RDWR);
    if (dev < 0) {
        path = "/dev/cda";
        return (fail(strerror(errno)));
    }
    rsv.size = total;
    if (ioctl(dev, CDAIOCRESERVE, (char *)&rsv) < 0)
        return (fail(strerror(errno)));

    for (i = 0; i < nseg; i++) {
        if (!segs[i].load)
            continue;
        blen = (unsigned)(segs[i].bytecnt - segs[i].dispdata);
        n = (unsigned)segs[i].length;
        body = (unsigned char *)malloc((unsigned long)blen);
        img = (unsigned char *)malloc((unsigned long)(n ? n : 1));
        if (body == 0 || img == 0)
            return (fail("out of memory"));
        memset((char *)img, 0, n);
        if (readall(fd, segs[i].pos + segs[i].dispdata, body, blen) < 0)
            return (fail("short segment body"));
        why = build(&segs[i], body, blen, img);
        if (why)
            return (fail(why));
        if (put(dev, 0, segs[i].off, img, n) < 0)
            return (fail(strerror(errno)));
        free(body);
        free(img);
    }
    close(fd);

    /* The pathname, made absolute. */
    apath[0] = 0;
    if (*path != '/') {
        if (getwd(apath) == 0)
            return (fail(apath));
        if (strcmp(apath, "/") != 0)
            strcat(apath, "/");
    }
    if (strlen(apath) + strlen(path) >= sizeof(apath))
        return (fail("pathname too long"));
    strcat(apath, path);
    plen = strlen(apath);

    /* `._NAME' beside it, and the Resource Fork entry in it. */
    strcpy(adpath, apath);
    for (k = plen; k > 0 && adpath[k - 1] != '/'; k--)
        ;
    strcpy(adpath + k, "._");
    strcat(adpath, apath + k);
    foff = 0L;
    flen = 0L;
    rfd = open(adpath, O_RDONLY);
    if (rfd >= 0) {
        path = adpath;
        if (readall(rfd, 0L, hdr, AD_HDRLEN) < 0 || be32(hdr) != AD_MAGIC)
            return (fail("not an AppleDouble file"));
        n = (hdr[24] << 8) | hdr[25];
        for (k = 0; k < n; k++) {
            if (readall(rfd, (long)AD_HDRLEN + 12L * k, hdr, 12) < 0)
                return (fail("short AppleDouble entry"));
            if (be32(hdr) == AD_RSRC) {
                foff = be32(hdr + 4);
                flen = be32(hdr + 8);
            }
        }
        if (flen > 0xFFFFL - 2L - plen)
            return (fail("resource fork larger than one bank"));
    }

    fk.size = 2L + plen + flen;
    if (ioctl(dev, CDAIOCFORK, (char *)&fk) < 0)
        return (fail(strerror(errno)));
    buf[0] = (unsigned char)plen;
    buf[1] = (unsigned char)(plen >> 8);
    if (put(dev, 1, 0, buf, 2) < 0 ||
        put(dev, 1, 2, (unsigned char *)apath, plen) < 0)
        return (fail(strerror(errno)));
    for (done = 0L; done < flen; done += n) {
        n = flen - done > (unsigned long)CHUNK ? CHUNK : (unsigned)(flen - done);
        if (readall(rfd, (long)(foff + done), buf, n) < 0)
            return (fail("short resource fork"));
        if (put(dev, 1, 2 + plen + (unsigned)done, buf, n) < 0)
            return (fail(strerror(errno)));
    }
    if (rfd >= 0)
        close(rfd);

    if (ioctl(dev, CDAIOCINSTALL, (char *)0) < 0)
        return (fail(strerror(errno)));
    close(dev);
    return (0);
}
