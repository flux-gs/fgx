/* FGX platform library -- <fgx.h> (BSD-foundations P1, 2026-07-16).
 *
 * Everything FGX-specific lives in libfgx (lib/libfgx_c/libfgx.c), not
 * libc: libc carries only ISO C / POSIX / 2.11BSD names, so a BSD port
 * can never collide with an FGX-native symbol.  FGX-native tools include
 * this header; ports never do. */
#ifndef _FGX_H
#define _FGX_H

/* Large memory: a locked/fixed Memory-Manager block that MAY span banks
 * (SYS_MM_ALLOC) -- for data past the 64 KB data bank.  mm_alloc returns
 * the handle (0 = ENOMEM) and writes the block's 24-bit base to *base;
 * compute with the base ((char *)(long) casts carry all 24 bits), free
 * with the handle. */
long mm_alloc(unsigned long size, unsigned long *base);
int  mm_free(long handle);

/* Cooperative scheduling / keyboard / time. */
int  yield(void);
int  waitkey(void);                /* blocking key read (raw, low byte) */
int  pollkey(void);                /* -1 when the ring is empty */
long ticks(void);                  /* full 32-bit 60 Hz counter */

/* Console / video. */
int  border(int idx);
int  setpal(int role, int rgb12);
int  fontload(char *path);
int  fontrevert(void);
int  fontname(char *buf, int max);
int  screen_ctl(int mode);         /* 1 = claim SHR (console suspended),
                                      0 = release, 2 = claim + 3200 engine,
                                      3 = stop the engine */

/* Diagnostics.  Buffer args follow the caller-DBR contract: pass
 * file-scope (data-bank) buffers, not locals. */
int  dmesg(char *buf, int max);
int  slotscan(char *buf, int max);
int  meminfo(int subcmd, char *buf, int max);
/* SYS_PROCS's record, the kernel's PI_* layout (include/kernel.s).  THE TWO
 * MUST MOVE TOGETHER -- the record carries no version tag, so a field added on
 * one side and not the other is read as the neighbouring one.  ps(1) and w(1)
 * both fill an array of these. */
#define PROC_NAME_MAX   16
#define PROC_TTY_MAX     8              /* = TTYNAME_MAX */

struct procinfo {
    int  pid;
    int  ppid;
    int  pgid;
    int  state;
    char name[PROC_NAME_MAX];
    int  stksize;               /* reserved bank-0 stack bytes (incl guard) */
    int  stkhwm;                /* peak bytes touched; 0 = not measurable */
    int  arena_used;            /* pid 0 only: arena pages in use */
    int  arena_free;            /* pid 0 only: arena pages free */
    unsigned heaphwm;           /* high-water break (dataBank:HEAP_HWM); 0 = no
                                 * data bank.  UNSIGNED on purpose: a nearly-full
                                 * heap puts the break above $7FFF, which a
                                 * signed int reads as negative. */
    char ttyname[PROC_TTY_MAX]; /* controlling terminal, NUL-padded, no "/dev/"
                                 * prefix ("console", "ttyv1"); "" = none */
};

int  procs(char *buf, int max);         /* fill an array of struct procinfo */
int  listdir(char *path, char *buf, int size);

/* Interface control (SYS_IFCONFIG).  ifr is a raw 32-byte kernel ifreq
 * record (see src/userland/ifconfig/ifconfig.c IFR_* offsets); op is
 * IFC_GETN/IFC_GET/IFC_SET/IFC_SETDHCP. */
int  ifctl(int op, char *ifr);

/* Process creation, FGX's spawn family beside fork(2) and execve(2).  argv and
 * envp are NULL-terminated char **, which is BSD's shape (4.3BSD-Reno has no
 * spawn; its execve takes char **argp).  The kernel takes them through an
 * arg-block of far pointers and walks the vectors in place, as it does for
 * execve, so a caller need not know which bank its strings are in.  spawnx's
 * file_actions is still a pointer into the caller's own bank. */
int  spawnv(char *path, char **argv);
int  spawnvp(char *file, char **argv);  /* $PATH walk over spawnv */
int  spawnve(char *path, char **argv, char **envp);
int  spawnx(char *path, char **argv, void *file_actions);

#endif
