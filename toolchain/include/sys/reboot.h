/* FGX libc -- sys/reboot.h.  2.11BSD usr/sys/h/reboot.h, whole, at upstream's
 * values.  The kernel's copy of the three it reads is in include/kernel.s.
 *
 * THE WHOLE SET IS HERE BECAUSE reboot(8) PARSES IT, not because the kernel
 * honours it: upstream's `-a', `-s', `-d', `-f', `-R' and `-D' each set a bit
 * that the PDP-11's boot program passes on to init, and the tool needs the
 * names to compile whatever the kernel then does with them.  What FGX's kernel
 * reads is RB_NOSYNC and RB_HALT; its cold start is the IIgs firmware's PWRUP,
 * which takes no arguments, so the rest reach the syscall and are ignored.
 */
#ifndef _SYS_REBOOT_H
#define _SYS_REBOOT_H

#define RB_AUTOBOOT     0       /* flags for system auto-booting itself */

#define RB_ASKNAME      0x001   /* ask for file name to reboot from */
#define RB_SINGLE       0x002   /* reboot to single user only */
#define RB_NOSYNC       0x004   /* dont sync before reboot -- READ BY THE KERNEL */
#define RB_HALT         0x008   /* don't reboot, just halt -- READ BY THE KERNEL */
#define RB_INITNAME     0x010   /* name given for /etc/init */
#define RB_DFLTROOT     0x020   /* use compiled-in rootdev */
#define RB_DUMP         0x040   /* take a dump before rebooting */
#define RB_NOFSCK       0x080   /* don't perform fsck's on reboot */
#define RB_POWRFAIL     0x100   /* reboot caused by power failure */
#define RB_RDONLY       0x200   /* mount root fs read-only */
#define RB_AUTODEBUG    0x400   /* init runs autoconfig with "-d" (debug) */

#define RB_PANIC        0       /* reboot due to panic */
#define RB_BOOT         1       /* reboot due to boot() */

int reboot();

#endif /* _SYS_REBOOT_H */
