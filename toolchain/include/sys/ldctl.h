/* FGX libc -- sys/ldctl.h.  SYS_LDCTL (syscall 8), the shared-library
 * registry ld.mod keeps (shared libc SP4 spec, section 4), and the state
 * ld_load(3) works in.
 *
 * Every service takes the 50-byte block below by offset and bank (X, Y)
 * and copies the row back into it.  ACQUIRE answers 1 "load it" (the
 * caller now owns the row LOADING) or 0 (READY, the caller counted a
 * user); GRANT adds nbanks banks to the row and, given a core_size (0
 * for banks alone), places the core and answers core_base; COMMIT takes
 * minor, crc, the offsets, rows, binder, pinned and deps; ABORT frees the
 * row and keeps its banks; LOOKUP only reads.  -1 and errno on failure. */
#ifndef _SYS_LDCTL_H
#define _SYS_LDCTL_H

#include <sys/uio.h>

#define SYS_LDCTL       8
#define LDS_ACQUIRE     0
#define LDS_GRANT       1
#define LDS_COMMIT      2
#define LDS_ABORT       3
#define LDS_LOOKUP      4

#define LD_FREE         1
#define LD_LOADING      2
#define LD_READY        3
#define LD_MAXBANKS     8

struct ldblk {
    char name[16];
    unsigned char major, minor;
    unsigned char crc[4];
    unsigned char row, nbanks;
    unsigned char banks[LD_MAXBANKS];
    unsigned core_base, core_size, tmpl_off, expt_off, rows;
    unsigned char binder[3];
    unsigned char state, users, pinned;
    unsigned deps;              /* bit r: this row imports from row r */
};

/* A library another needs, from its IMPS table. */
struct ld_need {
    char name[16];
    unsigned char major, minor;
    unsigned char crc[4];
    unsigned core_base;         /* the base it was linked against */
};

/* ld_load(3)'s state, all of it, in the caller's data bank: SYS_LDCTL and
 * read(2) reach only that bank, and the binder calls ld_load before this
 * process's blocks exist.  A load reads through msg until it has a message
 * to say: a window on the /lib directory, then a run of relocs.  A
 * library's trailer goes by readv(2), whose iovec here may point anywhere,
 * into the top of the library's own last bank.  buf is scratch only
 * ld_needs reads a trailer into, before any bank is granted; the binder
 * never calls it. */
struct ld_work {
    struct ldblk blk;
    struct iovec iov;
    char path[48];              /* /lib/<name>.so.<major>.<minor> */
    unsigned char hdr[88];      /* header and segment table, 9 segments */
    char msg[96];               /* a message, assembled for write(2) */
    char *buf;
    unsigned bufsz;
};

/* A segment once loaded: where its offset 0 is (_ld_patch's table). */
struct ld_seg {
    unsigned off;
    unsigned char bank, pad;
};

/* _ld_patch(sites, n, segs, kind, val, bank, only): kind 0 sites are
 * (seg, off), 3 bytes, stored val:bank; kind 1 sites are (seg, off, orig),
 * 5 bytes, stored orig + val; only = 0xFF all sites, else that segment's. */
void _ld_patch();
int ld_ctl();
int ld_need();
int ld_needs();

#endif /* _SYS_LDCTL_H */
