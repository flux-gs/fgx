/* statlayout.h -- struct stat's byte offsets, for the kernel C that FILLS it.
 *
 * THE THIRD PLACE, AND IT IS CHECKED LIKE THE OTHER TWO.  The layout already
 * lives twice and cannot be collapsed: include/fs.s carries it as a Merlin32
 * DUM block (the STX_ names) and toolchain/include/sys/stat.h carries it as
 * the C struct userland reads directly.  tools/check_stat_layout.py holds
 * those two together and says why.
 *
 * root_stat fills the buffer from kernel C, so it needs the offsets in C too.
 * It cannot use the userland struct: this is far-bank kernel code compiled
 * against the kernel's includes, and it writes through a `char *' into the
 * kernel's own _fsStatBuf rather than into a declared object.  Naming the
 * offsets here and letting the checker police all THREE is the same trade the
 * checker's header already argued for -- a two-byte disagreement in this
 * struct does not fail loudly, it reports wrong sizes and wrong timestamps a
 * long way from the edit that caused it.
 *
 * THE LAYOUT IS 2.11BSD's EXACTLY (usr/sys/h/stat.h:14-31), spares included.
 * It was a 32-byte subset until 2026-09-05, and the ls port is what named the
 * cost: vendor's ls.c reads st_flags, which the subset did not have, and a
 * field appended to the end would have left every other offset disagreeing
 * with a real 2.11BSD binary anyway.  The spares are carried because their
 * POSITIONS are what put st_mtime and st_blocks where upstream has them.
 *
 * SBSET16/SBSET32 write little-endian, which is what the 65816 reads and what
 * both other copies describe.  A 32-bit store is FOUR BYTE STORES and not a
 * cast-and-assign: `sb' is a char* into the kernel bank with no alignment
 * guarantee, and fcc has no unaligned long store.
 */
#ifndef _STATLAYOUT_H
#define _STATLAYOUT_H

#define STX_dev      0
#define STX_ino      2
#define STX_mode     4
#define STX_nlink    6
#define STX_uid      8
#define STX_gid     10
#define STX_rdev    12
#define STX_size    14
#define STX_atime   18
#define STX_spare1  22
#define STX_mtime   24
#define STX_spare2  28
#define STX_ctime   30
#define STX_spare3  34
#define STX_blksize 36
#define STX_blocks  40
#define STX_flags   44
#define STX_spare4  46
#define STAT_SIZE   52

/* Mode bits, fs.s's 16-bit packing (S_IFREG 0x8000), NOT classic Unix octal.
 * The permission bits ARE the classic ones and are masked out of va_mode with
 * 07777, which is why the two can share a word. */
#define S_IFMT      0xF000
#define S_IFREG     0x8000
#define S_IFDIR     0x4000
#define S_IFCHR     0x2000
#define S_IFBLK     0x6000
#define S_IFLNK     0xA000
#define S_IFSOCK    0xC000      /* matches toolchain/include/sys/stat.h:74, which
                                 * is what S_ISSOCK tests in userland */

/* The permission bits are the classic octal ones and are what va_mode already
 * holds, masked with 07777 -- see root_stat.  Named here only so the mask has
 * a spelling; nothing in the kernel tests an individual bit yet, because
 * nothing ENFORCES one (ufs_access is ufs_enotsup). */
#define S_IPERM     07777

/* FUNCTIONS AND NOT MACROS, and that was measured.  As macros these expanded
 * at every one of the fifteen call sites in root_stat, and each 32-bit store
 * is three shifts a 16-bit machine performs with runtime helper calls -- the
 * far bank went 306 bytes OVER its 60,480-byte ceiling when the struct grew to
 * 2.11BSD's full 52.  One copy of each, called, fits. */
void sb_put16();
void sb_put32();
#define SBSET16(b, off, v) sb_put16((b) + (off), (int)(v))
#define SBSET32(b, off, v) sb_put32((b) + (off), (long)(v))

#endif
