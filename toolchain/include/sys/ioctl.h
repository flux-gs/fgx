/* FGX libc — sys/ioctl.h.  tty + socket ioctls.
 *
 * FGX ioctl cmd words are the low 16 bits of the matching BSD ioctl (the sgtty
 * TIOC* set lives in the kernel's @si_tty dispatch; see include/loader.s), and
 * the libc shim takes a 16-bit `int cmd` — the sgttyb/tchars structs and TIOC*
 * codes come in via <sgtty.h>; ttychars gives CTRL()/default control chars.
 * Window size is PER-TTY (apple/fgx#150): the console and virtual consoles
 * report the 25x80 viewport, a pty reports whatever its far end last set via
 * TIOCSWINSZ (telnetd pushes the client's size from NAWS).
 * ws_xpixel/ws_ypixel read as 0 -- no FGX terminal can answer them honestly.
 */
#ifndef _SYS_IOCTL_H
#define _SYS_IOCTL_H
#include <sgtty.h>
#include <sys/ttychars.h>   /* CTRL(), default control chars (2.11BSD) */

#define TIOCGWINSZ 0x7468       /* *arg = struct winsize (BSD 't'<<8|104) */
/* Setting a DIFFERENT size also sends SIGWINCH to the line's foreground group,
 * as 2.11BSD tty.c:558 does; setting the same size signals nobody. */
#define TIOCSWINSZ 0x7467       /* *arg -> winsize   (BSD 't'<<8|103) */

struct winsize {
    short ws_row;               /* rows, chars */
    short ws_col;               /* columns, chars */
    short ws_xpixel;            /* 0 on FGX */
    short ws_ypixel;            /* 0 on FGX */
};

/* Socket/file ioctls — low 16 bits of the BSD _IOxx encoding (the FGX cmd
 * word).  Runtime support is the networking-scope non-blocking-I/O work item;
 * defined here so the 2.11BSD net ports (telnet) compile against a 16-bit cmd. */
#ifndef FIONBIO
#define FIONBIO    0x667e       /* set/clear non-blocking I/O (BSD low 16) */
#endif
#ifndef FIONREAD
#define FIONREAD   0x667f       /* bytes available to read (BSD low 16) */
#endif
#ifndef SIOCATMARK
#define SIOCATMARK 0x7307       /* at OOB mark? (BSD low 16) */
#endif
/* Interface ioctls on a socket, 2.11BSD h/ioctl.h's `_IOWR(i, n, ...)'
 * (low 16 bits): the getters that fill a struct ifreq / struct ifconf
 * (<net/if.h>).  The setters are not served. */
#define SIOCGIFADDR    0x690d   /* get ifnet address */
#define SIOCGIFFLAGS   0x6911   /* get ifnet flags */
#define SIOCGIFBRDADDR 0x6912   /* get broadcast addr */
#define SIOCGIFCONF    0x6914   /* get ifnet list */
#define SIOCGIFNETMASK 0x6915   /* get net addr mask */
#ifndef FIOCLEX
#define FIOCLEX    0x6601       /* set close-on-exec ('f'<<8|1, BSD low 16) */
#endif
#ifndef FIONCLEX
#define FIONCLEX   0x6602       /* clear close-on-exec ('f'<<8|2, BSD low 16) */
#endif

/* FIODGNAME: fill the caller's buffer with this fd's device name, NUL-terminated
 * and WITHOUT a "/dev/" prefix (e.g. "console", "ttyp0").  FreeBSD spells this
 * _IOW('f', 120, struct fiodgname_arg); FGX takes a bare char* because the tty
 * ioctl dispatch has no struct-arg convention and the name is bounded.
 *
 * This exists because BSD's ttyname(3) -- fstat, then readdir /dev matching
 * st_rdev -- cannot work on FGX: /dev is a synthetic short-circuit in
 * Path_Resolve (_fsResolveIsChardev), not an enumerable directory, and stat has
 * no st_rdev.  Asking the tty directly is the available answer.
 *
 * Returns -1/ENOTTY for any fd that is not a tty, so callers need no separate
 * isatty() probe. */
#ifndef FIODGNAME
#define FIODGNAME  0x6678       /* get device name ('f'<<8|120, BSD low 16) */
#endif
/* Buffer bytes the caller must supply, NUL included.  MUST equal the kernel's
 * TTYNAME_MAX (src/kernel/signal.s, beside _ttyNames) -- the kernel truncates at
 * that width, so a smaller buffer here overflows the caller.  The two numbers
 * are separate only because the kernel cannot see this header. */
#define FIODGNAME_MAX 8

int ioctl(int fd, int cmd, char *arg);

#endif /* _SYS_IOCTL_H */
