;==============================================================================
; socket.s - BSD socket ABI constants.
;
; Address-family / type / option constants, the sockaddr_in field offsets
; (shared by the kernel + the userland C tools — the C side uses RAW byte
; offsets, NOT an fcc struct, because fcc pads struct members; see
; docs/superpowers/specs/2026-06-05-fgx-net-config-design.md section 13), and
; the kernel socket-descriptor record layout.
;
; PUT by src/kernel/main.s.  C mirror: src/userland/lib/socket_h.h.
; Spec: docs/superpowers/specs/2026-06-05-fgx-udp-sockets-dhclient-design.md
;==============================================================================

;------------------------------------------------------------------------------
; Address family / socket type / setsockopt option constants (BSD values).
;------------------------------------------------------------------------------
AF_UNIX         EQU     1           ; local to host (uipc_usrreq.c)
AF_INET         EQU     2
SOCK_DGRAM      EQU     2
SOL_SOCKET      EQU     $FFFF       ; setsockopt level
; Option names: the socket's sosetopt (2.11BSD sys/uipc_socket.c) answers them.
SO_DEBUG        EQU     $0001
SO_REUSEADDR    EQU     $0004
SO_KEEPALIVE    EQU     $0008
SO_DONTROUTE    EQU     $0010
SO_BROADCAST    EQU     $0020
SO_USELOOPBACK  EQU     $0040
SO_OOBINLINE    EQU     $0100
SOCK_RAW        EQU     3           ; BSD socket type for raw IP (ping)
IPPROTO_ICMP    EQU     1           ; IP protocol number (raw socket proto)
SOCK_STREAM     EQU     1           ; BSD stream socket (TCP)
IPPROTO_TCP     EQU     6           ; IP protocol number (TCP)
MSG_DONTWAIT    EQU     $80         ; recv/send: this-call non-blocking (BSD)
MSG_OOB         EQU     $01         ; recv/send: out-of-band (BSD): TCP's urgent data

; Socket ioctl(2) cmd words — low 16 bits of the BSD _IOxx encoding (match
; toolchain include/sys/ioctl.h).  The socket's soo_ioctl answers them.
FIONBIO         EQU     $667E       ; *arg != 0 -> non-blocking I/O
FIONREAD        EQU     $667F       ; *arg <- RX bytes available
SIOCATMARK      EQU     $7307       ; *arg <- at-OOB-mark? (always 0; no urgent)

;------------------------------------------------------------------------------
; struct sockaddr_in (16 bytes, 2.11BSD layout — matches toolchain
; netinet/in.h `short sin_family`).  Field byte offsets.
;   sin_family(2) sin_port(2,net) sin_addr(4,net) sin_zero(8)
; Input paths read only sin_port@2 / sin_addr@4 (family ignored); output
; fills (recvfrom src, and future accept/getpeername peer) write the family
; as a 2-byte short at offset 0 so a 2.11BSD caller reads AF_INET back.
;------------------------------------------------------------------------------
SIN_FAMILY      EQU     0           ; 2  AF_INET (short, low byte first)
SIN_PORT        EQU     2           ; 2  network order (big-endian)
SIN_ADDR        EQU     4           ; 4  network order
SIN_ZERO        EQU     8           ; 8
SIN_SIZE        EQU     16

;------------------------------------------------------------------------------
; unp_nameop's three operations, staged in _unpNameOp for the KSVC arm.  The C
; side spells these in src/kernel/vfs/vnode.h and the two must agree; there is no
; header a KSVC arm and a far-bank C function can both include.
; UNBIND IS ZERO ON PURPOSE: the KSVC arm must know before it copies a path
; whether there is one, and at 0 that test is `LDX _unpNameOp / BEQ' -- five
; bytes where a CPX against a non-zero value is eight.  src/kernel/vfs/vnode.h
; says the same.
;------------------------------------------------------------------------------
UNP_OP_UNBIND   EQU     0               ; close: drop the vnode bind took and
                                        ; clear its back pointer, which is
                                        ; Reno's unp_detach.
UNP_OP_BIND     EQU     1
UNP_OP_LOOKUP   EQU     2

;------------------------------------------------------------------------------
; W5100 socket-register offsets (relative to the socket-N base; set via
; _W5_SetSnAR in uthernet.s) + Sn_CR commands + Sn_SR states / Sn_IR bits.
; Named for the TCP cores; the UDP/ICMP cores predate these and use literals.
;------------------------------------------------------------------------------
SN_MR           EQU     $00         ; socket mode
SN_CR           EQU     $01         ; command
SN_IR           EQU     $02         ; interrupt
SN_SR           EQU     $03         ; status
SN_PORT         EQU     $04         ; local port (2)
SN_DIPR         EQU     $0C         ; dest IP (4)
SN_DPORT        EQU     $10         ; dest port (2)
SN_TX_FSR       EQU     $20         ; TX free size (2, BE)
SN_TX_WR        EQU     $24         ; TX write pointer (2, BE)
SN_RX_RSR       EQU     $26         ; RX received size (2, BE)
SN_RX_RD        EQU     $28         ; RX read pointer (2, BE)
CR_OPEN         EQU     $01
CR_LISTEN       EQU     $02         ; TCP server: enter LISTEN (await SYN)
CR_CONNECT      EQU     $04
CR_DISCON       EQU     $08
CR_CLOSE        EQU     $10
CR_SEND         EQU     $20
CR_RECV         EQU     $40
SR_CLOSED       EQU     $00
SR_INIT         EQU     $13
SR_LISTEN       EQU     $14         ; socket is listening (server)
SR_ESTABLISHED  EQU     $17
SR_CLOSE_WAIT   EQU     $1C
MR_TCP          EQU     $01
IR_SENDOK       EQU     $10
IR_TIMEOUT      EQU     $08
