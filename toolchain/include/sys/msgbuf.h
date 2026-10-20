/* FGX libc -- sys/msgbuf.h.  The kernel message buffer, as syslogd(8) sizes its
 * /dev/klog reads by.
 *
 * MSG_BSIZE MATCHES FGX'S ACTUAL RING and is not carried over as a number:
 * `KMEM_LOGBUF_SIZE' (include/memmap.s) is $1000, which is upstream's 4096, so
 * the two agree.  If the kernel ring is ever resized this has to move with it --
 * a syslogd reading 4096 bytes from a smaller ring would be asking for bytes
 * that are not there.
 *
 * The struct is here for fidelity with
 * `vendor/2.11BSD/usr/sys/h/msgbuf.h' and is NOT the layout of FGX's ring, which
 * is the kernel's own and is reached through /dev/klog or SYS_DMESG rather than
 * by mapping this over anything.  Nothing in FGX reads it; syslogd uses only
 * MSG_BSIZE.
 */
#ifndef _SYS_MSGBUF_H
#define _SYS_MSGBUF_H

#define MSG_MAGIC       0x063061
#define MSG_BSIZE       4096            /* == KMEM_LOGBUF_SIZE, include/memmap.s */

struct msgbuf {
    long     msg_magic;
    int      msg_bufx;                  /* write cursor */
    int      msg_bufr;                  /* read cursor */
    unsigned short msg_click;
    char    *msg_bufc;
};

#define logMSG          0               /* /dev/klog */
#define logDEV          1               /* /dev/erlg -- not present in FGX */
#define logACCT         2               /* /dev/acct -- not present in FGX */

#endif /* _SYS_MSGBUF_H */
