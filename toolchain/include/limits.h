/* FGX libc — limits.h.  ISO C implementation limits for the fcc target:
 * 8-bit char, 16-bit int/short, 32-bit long, and 64-bit long long, the C99
 * extension fcc adopts.  char is SIGNED (fcc sign-extends
 * an 8-bit load into a 16-bit register), so CHAR_MIN/MAX follow SCHAR.
 */
#ifndef _LIMITS_H
#define _LIMITS_H

#define CHAR_BIT   8

#define SCHAR_MIN  (-128)
#define SCHAR_MAX  127
#define UCHAR_MAX  255
#define CHAR_MIN   SCHAR_MIN
#define CHAR_MAX   SCHAR_MAX

#define SHRT_MIN   (-32768)
#define SHRT_MAX   32767
#define USHRT_MAX  65535

#define INT_MIN    (-32767 - 1)
#define INT_MAX    32767
#define UINT_MAX   65535U

#define LONG_MIN   (-2147483647L - 1L)
#define LONG_MAX   2147483647L
#define ULONG_MAX  4294967295UL

#define LLONG_MIN  (-9223372036854775807LL - 1LL)
#define LLONG_MAX  9223372036854775807LL
#define ULLONG_MAX 18446744073709551615ULL

#define MB_LEN_MAX 1

/* POSIX spellings of the two path ceilings the filesystem actually enforces.
 * THE NUMBERS ARE NOT FREE TO BE THE CLASSIC ONES: they are a third statement
 * of limits that already live in two places each, and a port that sizes a
 * buffer here gets whatever this file says.
 *
 *   PATH_MAX == MAXPATHLEN, sys/param.h and src/kernel/vfs/fsparam.h
 *   NAME_MAX == MAXNAMLEN,  sys/dir.h, src/kernel/vfs/dir.h and fsparam.h
 *
 * NAME_MAX is the filesystem's, and the filesystem is UFS.  Spelling it 15 --
 * the ProDOS cap -- is what truncated `dhclient.conf.sample' to
 * `dhclient.conf.s' through readdir (apple/fgx#317). */
#define PATH_MAX   128
#define NAME_MAX   63

#endif /* _LIMITS_H */
