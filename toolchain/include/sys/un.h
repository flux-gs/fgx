/* FGX libc -- sys/un.h.  The AF_UNIX address, 2.11BSD's usr/sys/h/un.h:18-21.
 *
 * sun_path IS 108 BYTES AND NOT 14.  A `struct sockaddr' is 16 bytes total and
 * an AF_UNIX address is not one: sizing an address buffer as a sockaddr
 * truncates every path past 13 characters, and bind(2) then names a DIFFERENT,
 * SHORTER file -- which succeeds, so the caller learns nothing until a later
 * stat of the name it meant comes back ENOENT.
 *
 * THE FIELDS ARE DECLARED BUT THE KERNEL READS THEM BY OFFSET, as it does for
 * sockaddr_in: fcc pads struct members, so the struct is the documentation and
 * the offsets are the contract -- sun_family is the first two bytes and
 * sun_path begins at offset 2.  src/userland/lib/socket_h.h says the same for
 * sockaddr_in and for the same reason.
 */
#ifndef _SYS_UN_H
#define _SYS_UN_H

#define SUN_PATH_MAX    108     /* 2.11BSD's sun_path[108] */
#define SUN_LEN         110     /* sizeof(struct sockaddr_un): 2 + 108 */

struct sockaddr_un {
    short sun_family;           /* AF_UNIX */
    char  sun_path[SUN_PATH_MAX];
};

#endif /* _SYS_UN_H */
