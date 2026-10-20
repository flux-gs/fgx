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
AF_UNIX         EQU     1           ; local to host -- unp.s, SOCK_DGRAM only
AF_INET         EQU     2
SOCK_DGRAM      EQU     2
SOL_SOCKET      EQU     $FFFF       ; setsockopt level
; sosetopt's boolean bag (2.11BSD usr/sys/sys/uipc_socket.c:666-672), less
; SO_LINGER -- that one carries a `struct linger' rather than an int and has no
; implementation here, so it is refused with the rest rather than half-accepted.
; SO_BROADCAST and SO_REUSEADDR have consumers here -- the sendto broadcast
; guard and the UDP bind's in_pcbbind lookup (_Udp_PortShare) -- and are kept
; in SOCK_Flags at their own values.  The other five are ACCEPTED AND NOT
; STORED: upstream records them in `so_options' for its
; protocols to consult, and no transport here consults any of them -- a word to
; hold bits nothing reads would be the same absent-behaviour-behind-a-present-
; interface this validation exists to remove.  The increment that gives one of
; them a reader adds the storage it needs (SO_OOBINLINE at apple/fgx#424).
SO_DEBUG        EQU     $0001
SO_REUSEADDR    EQU     $0004
SO_KEEPALIVE    EQU     $0008
SO_DONTROUTE    EQU     $0010
SO_BROADCAST    EQU     $0020       ; option name (and our descriptor flag bit)
SO_USELOOPBACK  EQU     $0040
SO_OOBINLINE    EQU     $0100
SOCK_RAW        EQU     3           ; BSD socket type for raw IP (ping)
IPPROTO_ICMP    EQU     1           ; IP protocol number (raw socket proto)
SOCK_STREAM     EQU     1           ; BSD stream socket (TCP)
IPPROTO_TCP     EQU     6           ; IP protocol number (TCP)
MSG_DONTWAIT    EQU     $80         ; recv/send: this-call non-blocking (BSD)
MSG_OOB         EQU     $01         ; recv/send: out-of-band (BSD).  No transport
                                    ; here can carry urgent data, so the socket
                                    ; layer refuses it -- see net_op_send.

; Socket ioctl(2) cmd words — low 16 bits of the BSD _IOxx encoding (match
; toolchain include/sys/ioctl.h).  FIONBIO sets/clears the SOCK_NB flag.
FIONBIO         EQU     $667E       ; *arg != 0 -> non-blocking I/O
FIONREAD        EQU     $667F       ; *arg <- RX bytes available
SIOCATMARK      EQU     $7307       ; *arg <- at-OOB-mark? (always 0; no urgent)

;------------------------------------------------------------------------------
; Transport tags (kernel-internal, stored in SOCK_Proto) + link-driver
; capability bits.  The socket core resolves (type,proto) -> a tag and routes
; through the driver's offload handler for that tag.  See spec
; docs/superpowers/specs/2026-06-05-fgx-net-icmp-offload-design.md.
;------------------------------------------------------------------------------
XPORT_NONE      EQU     0
XPORT_UDP       EQU     1
XPORT_ICMP      EQU     2
XPORT_TCP       EQU     3           ; SOCK_STREAM over the W5100 (net.s,
                                    ; net_xport.s), or loopback (net_loop.s)
XPORT_UNIX      EQU     4           ; AF_UNIX SOCK_DGRAM (unp.s).  A new TAG
                                    ; rather than a SOCK_HwIdx sentinel like
                                    ; loopback's: loopback IS an ordinary
                                    ; SOCK_STREAM to userland, so re-tagging it
                                    ; would break every SOCK_Proto == XPORT_TCP
                                    ; test, but AF_UNIX must NOT inherit
                                    ; XPORT_UDP's paths, which read sin_port and
                                    ; sin_addr out of a sockaddr_in that an
                                    ; AF_UNIX caller never supplies.

OFFLOAD_UDP     EQU     $01
OFFLOAD_ICMP    EQU     $02
OFFLOAD_TCP     EQU     $04         ; reserved; no consumer

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
; The arg block libc passes to SYS_SEND/RECV/SENDTO/RECVFROM (_sock_argblk,
; toolchain/lib/libc_data.s, which carries the whole layout).  The block is read
; through _Sys_CallerBank; the BUFFER is read through the bank the block names,
; which is what lets a caller's buffer sit on the bank-0 stack.  All four calls
; share +0 buf offset, +2 len, +4 MSG_* flags and this bank word.
;------------------------------------------------------------------------------
SOCKARG_BANK    EQU     6           ; 2  the buffer's bank, in the low byte
SOCKARG_FROM    EQU     8           ; 2  recvfrom: source-address staging offset

;------------------------------------------------------------------------------
; Kernel socket-descriptor table — Kmalloc'd soft-global, SOCKD_MAX entries.
; Reached via _sockTablePtr [dp],Y.
;------------------------------------------------------------------------------
; SOCKD_MAX sizes the DESCRIPTOR TABLE.  W5_NSOCK is how many sockets the CHIP
; has.  They used to be one constant, which welded two unrelated numbers
; together: _W5_SockAlloc bounded itself on SOCKD_MAX, so raising the descriptor
; count would have handed out hardware sockets that do not exist.
;
; W5_NSOCK is fixed by the PART, not by policy -- a W5100 has four (0..3), and
; socket 0 is reserved for /dev/bpf0 MACRAW capture (the chip supports MACRAW on
; socket 0 only), so _W5_SockAlloc hands out 1..3.  Raising it buys nothing:
; there is no more hardware.
;
; A DESCRIPTOR CLAIMS ITS HARDWARE SOCKET WHEN IT FIRST NEEDS THE WIRE, not at
; socket(): a UDP or ICMP bind() that opens the chip, a TCP connect() or
; listen() that drives it (_Xport_Claim, net_xport.s).  Until then it carries
; SOCK_HW_UNCLAIMED.  2.11BSD's PRU_ATTACH allocates a pcb and socket buffers
; and nothing belonging to an interface (udp_usrreq.c, in_pcballoc), so
; socket() cannot run out of a device's resources there; here the three chip
; sockets are the scarce thing, and a descriptor that binds 127/8 or never
; leaves the machine never touches one.  Exhaustion is ENOBUFS from the verb
; that needed the socket.
; SOCKD_MAX IS BOUNDED BY FCB_SockIdx, which holds the record's BYTE offset:
; (SOCKD_MAX-1)*SOCK_REC_SIZE must stay below 256, so 12 at 20 bytes a record.
; A networked boot spends eight before a user runs anything -- syslogd's
; /dev/log, ntpd's three port-123 sockets and its syslog client, inetd's
; listener and syslog client, cron's syslog client.
SOCKD_MAX       EQU     12
W5_NSOCK        EQU     4
SOCK_InUse      EQU     0           ; 1  descriptor allocated
SOCK_HwIdx      EQU     1           ; 1  W5100 hardware socket 0..3
SOCK_Flags      EQU     2           ; 1  SO_BROADCAST etc.
SOCK_Bound      EQU     3           ; 1  bind() done (W5100 OPEN issued)
SOCK_LPort      EQU     4           ; 2  local port (host order)
SOCK_Proto      EQU     6           ; 1  transport tag (XPORT_*)
SOCK_State      EQU     7           ; 1  TCP connection state (TCP_* below); was pad
TCP_CLOSED      EQU     0
TCP_CONNECTING  EQU     1
TCP_ESTABLISHED EQU     2
TCP_LISTEN      EQU     3           ; server: bound + LISTEN issued, awaiting a peer
; Loopback transport state (telnetd campaign P1).  A 127.0.0.1 connection is
; two pipe.s rings — A->B and B->A — with no hardware socket behind it, so it
; costs a socket DESCRIPTOR but none of the four W5100 hw sockets.  This socket
; WRITES SOCK_LoopTx and READS SOCK_LoopRx; its peer holds the mirror pair.
;
; BEFORE GROWING THIS RECORD, READ EVERY USER OF SOCK_REC_SIZE.  Two kinds
; exist and only one is safe by inspection.  Routines are named rather than
; line numbers cited, because line numbers rot and a stale citation is how a
; user gets missed:
;
;   - Stride adds, `ADC #SOCK_REC_SIZE`, in the descriptor scan loops:
;     net_op_socket and _Sock_NewConnFd (net.s), _Loop_FindListener and
;     _Loop_DescAlloc (net_loop.s).  Safe for any size.
;   - INDEX <-> OFFSET conversions, both in net_loop.s: _Loop_OffToIdx
;     subtracts the constant in a loop, _Loop_IdxToOff adds it in a loop.
;     Safe ONLY because each names the constant; keep both as loops.  A
;     shift-or-multiply form here bakes the size into the instruction stream
;     where a grep for this symbol cannot find it.
;
; SOCKTBL_BLK_SIZE below multiplies it, which is the one place that is meant to.
; Cost of the record itself is 16 more bytes in the Kmalloc'd table, none of it
; in the kernel bank.
SOCK_LoopPeer   EQU     8           ; 1  peer descriptor index; $FF = unpaired
SOCK_LoopRx     EQU     9           ; 1  pipe index this socket READS ($FF none)
SOCK_LoopTx     EQU     10          ; 1  pipe index this socket WRITES ($FF none)
SOCK_LoopFlags  EQU     11          ; 1  SLF_* below
; AF_UNIX SOCK_DGRAM state (unp.s).  A datagram lands in the RECEIVER's buffer
; -- 4.3BSD-Reno kern/uipc_usrreq.c, PRU_SEND's SOCK_DGRAM arm is
; `sbappendaddr(&so2->so_rcv, from, m, control)' -- so the ring belongs to the
; BOUND socket and a client holds none.  One ring for /dev/log therefore serves
; every client however many processes log, which is what keeps this inside
; NPIPE 8 (include/kernel.s), the whole machine's pipe count, shared with shell
; pipes.  A per-connection ring would have starved it.
;
; These are SEPARATE from the SOCK_Loop* fields above even though a socket is
; never both loopback and AF_UNIX and the three loopback fields already carry
; the semantics AF_UNIX needs.  Sharing them would be one name serving two
; paths, which is the shape that hides defects in the gap between them.
; unp_nameop's three operations, staged in _unpNameOp for the KSVC arm.  The C
; side spells these in src/kernel/vfs/vnode.h and the two must agree; there is no
; header a KSVC arm and a far-bank C function can both include.
; UNBIND IS ZERO ON PURPOSE: the KSVC arm must know before it copies a path
; whether there is one, and at 0 that test is `LDX _unpNameOp / BEQ' -- five
; bytes where a CPX against a non-zero value is eight.  The core bank had four
; bytes free when this landed.  src/kernel/vfs/vnode.h says the same.
UNP_OP_UNBIND   EQU     0               ; close: drop the vnode bind took and
                                        ; clear its back pointer, which is
                                        ; Reno's unp_detach.  Without it every
                                        ; bind pinned a vnode for the rest of
                                        ; the boot.
UNP_OP_BIND     EQU     1
UNP_OP_LOOKUP   EQU     2

SOCK_UnpRx      EQU     12          ; 1  pipe index this BOUND socket reads
                                    ;    (SOCK_LOOP_NONE = not bound)
SOCK_UnpPeer    EQU     13          ; 1  peer descriptor index for a connected
                                    ;    client (SOCK_LOOP_NONE = unconnected)
; The UDP peer: 2.11BSD's inp_faddr/inp_fport, set by connect(2) through
; _Udp_Connect (in_pcbconnect) and zero on an unconnected socket.  udp_output
; tests inp_faddr against INADDR_ANY for "connected", and so does this
; (_So_UdpPeer).  Network order, as the chip and the sockaddr carry them.
SOCK_FAddr      EQU     14          ; 4  connected peer address (0 = none)
SOCK_FPort      EQU     18          ; 2  connected peer port
SOCK_REC_SIZE   EQU     20

SLF_PENDING     EQU     $01         ; listener: a connect is waiting for accept()
SOCK_LOOP_NONE  EQU     $FF         ; "no peer" / "no pipe" sentinel for the above

SOCK_WILD       EQU     $02         ; SOCK_Flags bit: bound to INADDR_ANY.
                                    ; BSD's 0.0.0.0 means EVERY local address,
                                    ; which spans both of FGX's transports, and
                                    ; bind() is the only place that still knows
                                    ; which address was asked for -- the record
                                    ; keeps a port and no address.  listen()
                                    ; needs the answer (apple/fgx#128), so bind
                                    ; leaves it here.  Cleared on a bind to a
                                    ; specific address, so a rebind cannot
                                    ; inherit it.
SOCK_NB         EQU     $01         ; SOCK_Flags bit: non-blocking I/O (FIONBIO).
                                    ; read/recv -> EAGAIN when no data; send ->
                                    ; EAGAIN when TX full.  (SO_BROADCAST is $20.)
SOCK_HW_NONE    EQU     $FF         ; SOCK_HwIdx sentinel: descriptor owns no hw socket
                                    ; (accept detaches the listener's hw -> the connfd,
                                    ; so close(listenfd) frees the desc but not the hw)
SOCK_HW_UNCLAIMED EQU   $FD         ; SOCK_HwIdx sentinel: AF_INET descriptor that
                                    ; has not needed the chip yet (_Xport_Claim)
SOCK_HW_LOOP    EQU     $FE         ; SOCK_HwIdx sentinel: loopback -- serviced by
                                    ; net_loop.s (in net.mod) instead of the chip.
                                    ; SOCK_Proto STAYS XPORT_TCP: to userland this
                                    ; is an ordinary SOCK_STREAM with the same TCP_*
                                    ; states, and re-tagging the proto would break
                                    ; every `SOCK_Proto == XPORT_TCP` test.
SOCKTBL_BLK_SIZE EQU    SOCKD_MAX*SOCK_REC_SIZE      ; 240 at SOCKD_MAX 12

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
