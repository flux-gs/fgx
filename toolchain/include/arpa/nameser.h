/* FGX libc — arpa/nameser.h.  DNS wire-format constants, lifted (macros only)
 * from 2.11BSD arpa/nameser.h.  The 2.11BSD `HEADER` bitfield struct is
 * deliberately NOT included — fcc has no bitfields, and FGX's slim resolver
 * lays the 12-byte header out by byte offset (see libc_c.c _dns_resolve). */
#ifndef _ARPA_NAMESER_H
#define _ARPA_NAMESER_H

#define PACKETSZ        512     /* maximum UDP packet size            */
#define HFIXEDSZ        12      /* fixed header size                  */
#define QFIXEDSZ        4       /* fixed question size (qtype+qclass) */

/* Opcodes / flag bits (byte 2 of the header, high->low): QR OPCODE(4) AA TC RD */
#define QUERY           0x0     /* standard query opcode              */
#define DNS_RD          0x01    /* recursion desired (byte[2] bit 0)  */
#define DNS_TC          0x02    /* truncated (byte[2] bit 1)          */

/* Response codes (low nibble of byte 3). */
#define NOERROR         0
#define FORMERR         1
#define SERVFAIL        2
#define NXDOMAIN        3
#define NOTIMP          4
#define REFUSED         5

/* Resource-record / query types. */
#define T_A             1       /* host address                       */
#define T_NS            2       /* authoritative server               */
#define T_CNAME         5       /* canonical name                     */
#define T_PTR           12      /* domain name pointer (reverse)      */
#define T_MX            15      /* mail exchange                      */

/* Classes. */
#define C_IN            1       /* the ARPA internet                  */

/* Compression: a label length byte with the top two bits set is a pointer. */
#define INDIR_MASK      0xC0

#endif
