/* FGX libc -- sys/cdio.h.  CD-ROM ioctls, netbsd-0-9's sys/sys/cdio.h, of
 * which FGX carries one.  The value is upstream's _IO('c', 24) less the size
 * and direction bits, which FGX's 16-bit ioctl numbers do not carry; the
 * kernel's copy is CDIOCEJECT in include/loader.s. */
#ifndef _SYS_CDIO_H_
#define _SYS_CDIO_H_

#define CDIOCEJECT      0x6318          /* eject the disc */

#endif /* !_SYS_CDIO_H_ */
