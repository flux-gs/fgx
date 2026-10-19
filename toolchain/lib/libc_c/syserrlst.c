/* ---- syserrlst(3): the message for an error number, or NULL -----------
 * 2.11BSD gen/syserrlst.c reads the messages from /etc/syserrlst to save
 * PDP-11 memory.  FGX keeps the interface and holds the table in libc: the
 * messages are read-only strings, so a shared libc costs no process
 * anything for them.  Wording is 4.3BSD-Reno sys/errno.h's; message 0 is
 * 2.11BSD's (usr.lib/liberrlst/errlst.c).
 */
static char *_sys_errmsg[] = {
    "Undefined error: 0",                      /*  0 */
    "Operation not permitted",                 /*  1 */
    "No such file or directory",               /*  2 */
    "No such process",                         /*  3 */
    "Interrupted system call",                 /*  4 */
    "Input/output error",                      /*  5 */
    "Device not configured",                   /*  6 */
    "Argument list too long",                  /*  7 */
    "Exec format error",                       /*  8 */
    "Bad file descriptor",                     /*  9 */
    "No child processes",                      /* 10 */
    "Resource temporarily unavailable",        /* 11 */
    "Cannot allocate memory",                  /* 12 */
    "Permission denied",                       /* 13 */
    "Bad address",                             /* 14 */
    "Block device required",                   /* 15 */
    "Device busy",                             /* 16 */
    "File exists",                             /* 17 */
    "Cross-device link",                       /* 18 */
    "Operation not supported by device",       /* 19 */
    "Not a directory",                         /* 20 */
    "Is a directory",                          /* 21 */
    "Invalid argument",                        /* 22 */
    "Too many open files in system",           /* 23 */
    "Too many open files",                     /* 24 */
    "Inappropriate ioctl for device",          /* 25 */
    "Text file busy",                          /* 26 */
    "File too large",                          /* 27 */
    "No space left on device",                 /* 28 */
    "Illegal seek",                            /* 29 */
    "Read-only file system",                   /* 30 */
    "Too many links",                          /* 31 */
    "Broken pipe",                             /* 32 */
    "Numerical argument out of domain",        /* 33 */
    "Numerical result out of range",           /* 34 */
    (char *)0,                               /* 35 */
    (char *)0,                               /* 36 */
    (char *)0,                               /* 37 */
    "Socket operation on non-socket",          /* 38 */
    "Destination address required",            /* 39 */
    "Message too long",                        /* 40 */
    "Protocol wrong type for socket",          /* 41 */
    "Protocol not available",                  /* 42 */
    (char *)0,                               /* 43 */
    (char *)0,                               /* 44 */
    "Operation not supported",                 /* 45 */
    (char *)0,                               /* 46 */
    "Address family not supported by protocol family", /* 47 */
    "Address already in use",                  /* 48 */
    "Cannot assign requested address",         /* 49 */
    (char *)0,                               /* 50 */
    (char *)0,                               /* 51 */
    (char *)0,                               /* 52 */
    (char *)0,                               /* 53 */
    "Connection reset by peer",                /* 54 */
    "No buffer space available",               /* 55 */
    "Socket is already connected",             /* 56 */
    "Socket is not connected",                 /* 57 */
    (char *)0,                               /* 58 */
    (char *)0,                               /* 59 */
    "Operation timed out",                     /* 60 */
    "Connection refused",                      /* 61 */
    "Too many levels of symbolic links",       /* 62 */
    "File name too long",                      /* 63 */
    (char *)0,                               /* 64 */
    (char *)0,                               /* 65 */
    "Directory not empty",                     /* 66 */
    (char *)0,                               /* 67 */
    (char *)0,                               /* 68 */
    (char *)0,                               /* 69 */
    (char *)0,                               /* 70 */
    (char *)0,                               /* 71 */
    (char *)0,                               /* 72 */
    (char *)0,                               /* 73 */
    (char *)0,                               /* 74 */
    (char *)0,                               /* 75 */
    (char *)0,                               /* 76 */
    (char *)0,                               /* 77 */
    "Function not implemented",                /* 78 */
};
#define _SYS_NERR (sizeof(_sys_errmsg) / sizeof(_sys_errmsg[0]))

char *syserrlst(err)
    int err;
{
    if ((unsigned)err >= _SYS_NERR)
        return (char *)0;
    return _sys_errmsg[err];
}
