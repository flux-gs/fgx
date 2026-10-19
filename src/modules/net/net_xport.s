;==============================================================================
; net_xport.s - W5100 transport cores + ring I/O, lifted from src/kernel/
; uthernet.s (② net-mod reclaim Phase 3).  PUT by net.s (same module assembly).
;   _W5_SockAlloc/Free, _Net_Xport_*, _Xport_LoadTag, _Udp_*, _Icmp_*, _Tcp_*,
;   _Sock_PollIntr, _W5_SetSnAR, _W5_TxStream, _W5_RxSetup/RxCopy/RxAdvance.
; Runs in net.mod bank w/ DBR=kernel-bank ($02 = assembly ORG) + kernel DP: reaches the _sock*/_u2*/
;   _w5SockInUse/_tcpNextPort kernel statics via the gen_kernel_exports manifest,
;   the W5100 hw directly (U2_* EQUs + U2_LOCK/UNLOCK macros, defined in net.s),
;   and Con_PollKey/_sleep via the _Net_KCall_* RTL wrappers (in _Sock_PollIntr).
;==============================================================================

;------------------------------------------------------------------------------
; _W5_SockAlloc - claim a free W5100 hardware socket (1..3).
;   Out: C=1 + A = hw socket index (1..3), with that bit set in _w5SockInUse;
;        C=0 if all are in use.  MX %00.  DBR=kernel-bank (for _w5SockInUse).
;   Socket 0 is RESERVED for /dev/bpf0 MACRAW capture (_Net_CaptureStart) —
;   the W5100 supports MACRAW mode ONLY on socket 0, so UDP sockets start at 1.
;------------------------------------------------------------------------------
;
; THE BIT MASK IS COMPUTED, NOT TABLED, AND THAT IS LOAD-BEARING (apple/fgx#93).
; There was a `_w5SockMask HEX 01020408` table here, read as `LDA
; _w5SockMask,X`.  That is DBR-relative absolute -- and this module runs with
; DBR = THE KERNEL BANK, not its own.  So the read never touched the table: it
; fetched the KERNEL's byte at the table's module-relative offset ($23BE+X),
; which is ordinary kernel code and MOVES WHENEVER THE KERNEL DOES.  Measured:
; two inert bytes added to modload.s put `LDA _mlcState` ($AD $B0 $1D) there,
; so socket 1's "mask" read as $1D, `ORA` wrote $1D into _w5SockInUse, and the
; next socket() saw every socket busy and failed EMFILE.
;
; _w5SockInUse itself is a KERNEL static, so DBR-relative is correct for it --
; which is exactly why this was invisible: the same addressing mode was right
; for one operand and wrong for the next line.  Module-local DATA needs the
; module's own bank (PHK/PLB, as _wpBaseLow does in net.s); a 2-bit shift needs
; no data at all.  tools/check_module_data_refs.py now fails the build on the
; general case.
;------------------------------------------------------------------------------
_W5_SockAlloc   MX      %00
                PHP
                SEP     #$20
                MX      %10
                LDX     #1                      ; skip socket 0 (MACRAW capture)
                LDA     #$02                    ; ...so start at socket 1's bit
@wsa_l          BIT     _w5SockInUse            ; Z=1 -> this socket is free
                BEQ     @wsa_free
                ASL                             ; next socket's bit
                INX
                CPX     #W5_NSOCK
                BCC     @wsa_l
                ; all in use
                REP     #$20
                MX      %00
                PLP
                CLC
                RTS
@wsa_free       ORA     _w5SockInUse            ; mark in use
                STA     _w5SockInUse
                TXA                             ; A = the index (8-bit)
                REP     #$20
                MX      %00
                AND     #$00FF
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _W5_SockFree - release a W5100 hardware socket.  In: A.lo = hw idx.  MX %00.
;------------------------------------------------------------------------------
_W5_SockFree    MX      %00
                PHP
                AND     #$00FF
                ; REFUSE ANYTHING THAT IS NOT A REAL HW INDEX.  SOCK_HW_LOOP
                ; ($FE) reaches here through a caller that guards only
                ; SOCK_HW_NONE, and a bad index used to be turned into memory
                ; corruption by a table read (see the #93 note on _W5_SockAlloc);
                ; the shift below would instead spin the mask out to zero and
                ; clear nothing.  Neither is a socket free, so refuse both.
                CMP     #W5_NSOCK
                BCS     @wsf_done               ; sentinel or wild -> no-op
                TAX
                SEP     #$20
                MX      %10
                LDA     #$01                    ; socket 0's bit...
@wsf_sh         CPX     #0                      ; ...shifted up to socket X's
                BEQ     @wsf_clr
                ASL
                DEX
                BRA     @wsf_sh
@wsf_clr        EOR     #$FF                    ; clear that bit
                AND     _w5SockInUse
                STA     _w5SockInUse
                REP     #$20
                MX      %00
@wsf_done       PLP
                RTS

;==============================================================================
; _Net_Xport_{Open,Send,Recv} - offload-agnostic transport seam.
; The socket core (socket.s) calls these with the descriptor resolved
; (_sockTmpOff + _sockTmpHw set, plus op-specific _sock* state staged) and
; dispatches on SOCK_Proto (the transport tag).  ONE driver today (W5100), so
; this is a tag branch; a 2nd driver would make it an indirect call through the
; ifnet's driver_ops.  Cross-file targets use JMP (in-bank absolute) — a branch
; can't reach socket.s.  MX %00 throughout.
; (ICMP/IPRAW handlers land in Task 5; until then non-UDP -> EINVAL.)
;==============================================================================
_Net_Xport_Open MX      %00
                JSR     _Xport_LoadTag          ; A = SOCK_Proto
                CMP     #XPORT_UDP
                BNE     @nxo_icmp
                JSR     _Xport_Chip             ; no chip: bound, nothing to open
                BCC     @nxo_none
                JSR     _Udp_PortShare          ; in_pcbbind's lookup
                BCC     @nxo_out                ;   EADDRINUSE
                CMP     #0
                BNE     @nxo_shared             ;   bound onto a held chip socket
                JSR     _Xport_Claim
                BCC     @nxo_out
                JMP     _Udp_OpenAt
@nxo_shared     LDA     #0
                SEC
                RTS
@nxo_icmp       CMP     #XPORT_ICMP
                BNE     @nxo_tcp
                JSR     _Xport_Chip
                BCC     @nxo_none
                JSR     _Xport_Claim
                BCC     @nxo_out
                JMP     _Icmp_OpenAt
@nxo_none       LDA     #0                      ; in_pcbbind takes INADDR_ANY with
                SEC                             ;   no interface; see _Xport_Chip
                RTS
@nxo_tcp        CMP     #XPORT_TCP
                BNE     @nxo_bad
                JMP     _Tcp_BindAt             ; TCP bind: record local port (no chip
                                                ; OPEN yet — that happens at listen)
@nxo_bad        LDA     #EINVAL
                CLC
@nxo_out        RTS

_Net_Xport_Send MX      %00
                JSR     _Xport_ChipTag          ; A = tag, or C=0 + A = errno
                BCS     @nxs_have
                RTS
@nxs_have       PHA                             ; NO CHIP SOCKET, NOTHING TO SEND
                JSR     _Xport_HwOk             ;   ON: a TCP socket that never
                PLA                             ;   connected, or a spent listener.
                BCS     @nxs_chip               ;   A datagram socket reaches here
                LDA     #ENOTCONN               ;   bound (sendto, connect), so
                CLC                             ;   only a stream can be refused
                RTS
@nxs_chip       CMP     #XPORT_UDP
                BNE     @nxs_icmp
                JMP     _Udp_SendCore
@nxs_icmp       CMP     #XPORT_ICMP
                BNE     @nxs_tcp
                JMP     _Icmp_SendCore
@nxs_tcp        CMP     #XPORT_TCP
                BNE     @nxs_bad
                JMP     _Tcp_SendCore
@nxs_bad        LDA     #EINVAL
                CLC
                RTS

_Net_Xport_Recv MX      %00
                JSR     _Xport_ChipTag
                BCS     @nxr_chip
                CMP     #EADDRNOTAVAIL          ; no chip: nothing can arrive,
                BNE     @nxr_out                ;   which a receive says EAGAIN
                LDA     #EAGAIN
@nxr_out        CLC
                RTS
@nxr_chip       PHA                             ; no chip socket: a stream is not
                JSR     _Xport_HwOk             ;   connected (soreceive's
                PLA                             ;   PR_CONNREQUIRED test), and
                BCS     @nxr_hw                 ;   nothing can arrive for a
                CMP     #XPORT_TCP              ;   datagram, as with no chip
                BNE     @nxr_dgram
                LDA     #ENOTCONN
                CLC
                RTS
@nxr_dgram      LDA     #EAGAIN
                CLC
                RTS
@nxr_hw         CMP     #XPORT_UDP
                BNE     @nxr_icmp
                JMP     _Udp_RecvCore
@nxr_icmp       CMP     #XPORT_ICMP
                BNE     @nxr_tcp
                JMP     _Icmp_RecvCore
@nxr_tcp        CMP     #XPORT_TCP
                BNE     @nxr_bad
                JMP     _Tcp_RecvCore
@nxr_bad        LDA     #EINVAL
                CLC
                RTS

;------------------------------------------------------------------------------
; _Net_Xport_SockStatus - select(2) non-blocking readiness poll.  In: _sockTmpOff
; + _sockTmpHw (staged by kernel _Sys_Select via _Sock_FdToDesc).  Out: A = ready
; bits (bit0=readable, bit1=writable, bit2=except always 0 — W5100 exposes no TCP
; urgent), C=1.  NEVER sleeps, NEVER consumes RX (pure status-register reads).
;   TCP: readable = RX_RSR>0 OR SR in {CLOSE_WAIT,CLOSED} (data or EOF);
;        writable = SR==ESTABLISHED AND TX_FSR>0.
;   UDP/ICMP: readable = RX_RSR>0; writable = always.
; _W5_SetSnAR preserves X/Y, so SR rides in X and the result rides in Y across
; the register reads; _sockTmp2 is the transient 16-bit hi|lo nonzero test.
;------------------------------------------------------------------------------
_Net_Xport_SockStatus MX %00
                ; REFUSE ANYTHING THAT IS NOT A REAL HW INDEX.  This guard used
                ; to name SOCK_HW_NONE ($FF) alone, so SOCK_HW_LOOP ($FE) fell
                ; through and was used as a W5100 socket NUMBER; on a machine
                ; with no card the "readiness" that came back was open bus
                ; (apple/fgx#97).  The bound lives in _Xport_HwOk now -- see
                ; there for why it is a bound rather than a list of sentinels.
                JSR     _Xport_Chip             ; no chip: nothing is ready, and
                BCC     @nss_none               ;   FIONREAD must read 0, not the
                JSR     _Xport_HwOk             ;   last socket's count
                BCS     @nss_go
@nss_none       STZ     _sockRxLen
                LDA     #0
                SEC
                RTS
@nss_go         JSR     _Xport_LoadTag          ; A = SOCK_Proto
                CMP     #XPORT_TCP
                BEQ     @nss_tcp
                ; --- UDP / ICMP: readable = RSR>0, writable = always ---
                U2_LOCK
                SEP     #$30
                MX      %11
                LDY     #%00000010              ; writable always
                LDA     #SN_RX_RSR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT                  ; RSR hi
                STA     _sockRxLen+1            ; stash 16-bit RSR (FIONREAD reads it)
                STA     _sockTmp2
                LDAL    U2_DAT                  ; RSR lo
                STA     _sockRxLen
                ORA     _sockTmp2               ; hi|lo != 0  iff  RSR>0
                BEQ     @nss_u_done
                LDY     #%00000011              ; + readable
@nss_u_done     REP     #$30
                MX      %00
                U2_UNLOCK
                TYA
                AND     #$00FF
                SEC
                RTS
                ; --- TCP ---
@nss_tcp        ; A LISTENER IS NOT A CONNECTION, and the EOF rule further down
                ; must not be applied to one.  For a connected socket
                ; "RSR==0 and SR==CLOSED" means the peer went away and recv will
                ; return 0, so readable is right.  For a LISTENER, CLOSED means
                ; the descriptor is spent -- accept(2) DETACHES its hardware
                ; socket to the accepted connection -- and calling it readable
                ; tells select the exact opposite of the truth.
                ;
                ; MEASURED over the wire: after the first connection, inetd's
                ; select woke on the dead listener, accept answered ENOTCONN,
                ; and the loop spun at full speed printing
                ; "accept: Socket is not connected" until the console was full.
                ; The machine was deaf to every later connection and busy doing
                ; it, which is a far louder failure than the missed wake-up
                ; apple/fgx#140 fixed on the loopback side.
                ;
                ; The right question for a listener is the one _Tcp_Accept
                ; itself asks: the W5100 socket goes LISTEN -> ESTABLISHED when
                ; a peer arrives, so ESTABLISHED is "a connection is pending".
                ; Never writable -- BSD does not select a listener for write.
                LDA     _sockTmpOff
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #TCP_LISTEN
                REP     #$30
                MX      %00
                BNE     @nss_tcpconn
                BRL     @nss_tcplisten          ; out of BEQ range
@nss_tcpconn    U2_LOCK
                SEP     #$30
                MX      %11
                LDY     #0                      ; result accumulator (bits)
                LDA     #SN_SR                  ; SR -> X (held across reads)
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                TAX
                LDA     #SN_RX_RSR              ; readable if RSR>0
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockRxLen+1            ; stash 16-bit RSR (FIONREAD reads it)
                STA     _sockTmp2
                LDAL    U2_DAT
                STA     _sockRxLen
                ORA     _sockTmp2
                BEQ     @nss_t_eof
                LDY     #%00000001              ; readable (data queued)
                BRA     @nss_t_wr
@nss_t_eof      TXA                             ; RSR==0: SR distinguishes EOF
                CMP     #SR_CLOSE_WAIT
                BEQ     @nss_t_rdset
                CMP     #SR_CLOSED
                BNE     @nss_t_wr
@nss_t_rdset    LDY     #%00000001              ; readable (EOF: recv returns 0)
@nss_t_wr       TXA                             ; writable = ESTABLISHED && TX_FSR>0
                CMP     #SR_ESTABLISHED
                BNE     @nss_t_done
                LDA     #SN_TX_FSR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockTmp2
                LDAL    U2_DAT
                ORA     _sockTmp2
                BEQ     @nss_t_done             ; TX buffer full -> not writable
                TYA
                ORA     #%00000010
                TAY
@nss_t_done     REP     #$30
                MX      %00
                U2_UNLOCK
                TYA
                AND     #$00FF
                SEC
                RTS

; A WIRE LISTENER: readable iff a peer has arrived.  The SR is stashed and the
; compare made AFTER the unlock, because U2_UNLOCK is a macro and not something
; to carry flags across.
@nss_tcplisten  ; FIONREAD READS _sockRxLen AFTER THIS RETURNS (syscall.s @sisn_hw),
                ; and the conn arm below sets it from RSR.  This arm has no RSR
                ; to report, so without the zero the ioctl hands back whatever
                ; the last socket op of ANY process left in the cell.  A
                ; listener's true answer is 0, which is also what the fall
                ; through to the conn arm used to produce.
                STZ     _sockRxLen
                U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_SR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockTmp2
                REP     #$30
                MX      %00
                U2_UNLOCK
                LDA     _sockTmp2
                AND     #$00FF
                CMP     #SR_ESTABLISHED
                BEQ     @nss_tl_rd
                ; CLOSE_WAIT COUNTS TOO, and leaving it out wedged the listener.
                ; The chip completes the handshake by itself, so a client that
                ; connects and FINs before accept(2) runs leaves the socket in
                ; CLOSE_WAIT -- a real connection, already half-closed.  BSD
                ; accepts it and hands the server the EOF.  Reporting it
                ; not-ready instead meant select never woke, accept never ran,
                ; and one fast-disconnecting client (a port scan, a health
                ; check, an impatient user) deafened the service permanently.
                ; MEASURED: four connect-then-close-immediately clients, 14 s
                ; apart, got 1 accepted and 3 timeouts.
                CMP     #SR_CLOSE_WAIT
                BEQ     @nss_tl_rd
                LDA     #0                      ; LISTEN (waiting) or CLOSED
                SEC                             ;   (spent) -> not ready
                RTS
@nss_tl_rd      LDA     #%00000001              ; a connection is pending
                SEC
                RTS

;------------------------------------------------------------------------------
; _Net_Xport_Connect - TCP, and UDP's in_pcbconnect (_Udp_Connect).
; _Net_Xport_Close - TCP only (UDP/ICMP have no chip teardown).  Tag-dispatch
; like the other verbs; JMP to the cores.  MX %00.
;------------------------------------------------------------------------------
_Net_Xport_Connect MX   %00
                ; REFUSE A DESCRIPTOR THAT OWNS NO CHIP SOCKET (apple/fgx#139).
                ; A descriptor claimed for 127/8 carries SOCK_HW_LOOP ($FE),
                ; and connect() to a NON-127 address walks straight past the
                ; loopback pre-check -- _Loop_ConnectTry declines a destination
                ; that is not its own -- and arrives here.  Without this,
                ; _Tcp_Connect drove _W5_SetSnAR with $FE as a socket NUMBER,
                ; landing well past the four real register blocks, and then
                ; spun a full 16-bit counter waiting for an INIT that open bus
                ; was never going to report: a wild write followed by a bogus
                ; ETIMEDOUT.  EINVAL is what BSD answers when the address does
                ; not suit the socket, and it is the same eligibility question
                ; _Loop_ClaimEligible asks from the loopback side.
                LDA     _sockTmpHw              ; the index question FIRST, so a
                AND     #$00FF                  ;   loopback descriptor answers
                CMP     #SOCK_HW_UNCLAIMED      ;   EINVAL with a card or without;
                BEQ     @nxc_idxok              ;   an unclaimed one claims below
                JSR     _Xport_HwOk
                BCC     @nxc_nohw
@nxc_idxok      JSR     _Xport_Chip
                BCS     @nxc_chip
                LDA     #EADDRNOTAVAIL          ; no chip: no interface to connect
                CLC                             ;   through
                RTS
@nxc_chip       JSR     _Xport_LoadTag
                CMP     #XPORT_TCP
                BEQ     @nxc_tcp
                CMP     #XPORT_UDP
                BNE     @nxc_nosup
                JMP     _Udp_Connect
@nxc_nosup      LDA     #ENOTSUP               ; EOPNOTSUPP: connect on raw ICMP
                CLC
                RTS
@nxc_nohw       LDA     #EINVAL
                CLC
                RTS
@nxc_tcp        JSR     _Xport_Claim
                BCC     @nxc_out
                JMP     _Tcp_Connect
@nxc_out        RTS

_Net_Xport_Close MX     %00
                JSR     _Xport_LoadTag
                CMP     #XPORT_TCP
                BEQ     @nxcl_tcp
                LDA     #0                     ; UDP/ICMP: no chip teardown (current)
                SEC
                RTS
@nxcl_tcp       JMP     _Tcp_Close

;------------------------------------------------------------------------------
; _Net_Xport_Listen / _Net_Xport_Accept - TCP server seam verbs.  MX %00.
;------------------------------------------------------------------------------
_Net_Xport_Listen MX    %00
                JSR     _Xport_LoadTag
                CMP     #XPORT_TCP
                BEQ     @nxl_tcp
                LDA     #ENOTSUP
                CLC
                RTS
@nxl_tcp        JSR     _Xport_Claim
                BCC     @nxl_out
                JMP     _Tcp_Listen
@nxl_out        RTS

_Net_Xport_Accept MX    %00
                JSR     _Xport_LoadTag
                CMP     #XPORT_TCP
                BEQ     @nxa_tcp
                LDA     #ENOTSUP
                CLC
                RTS
@nxa_tcp        JMP     _Tcp_Accept

;------------------------------------------------------------------------------
; _Xport_LoadTag - A := SOCK_Proto for the descriptor at _sockTmpOff.  MX %00.
; Clobbers Y (the cores read their state from _sock* statics, not Y, so this
; is safe across the seam).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; _Sock_FillSrc - recvfrom's source address, into libc's staging for it.
; _sockSrcOff is an offset in the caller's DATA bank -- the arg block's, where
; libc points it -- but by the time a datagram has been copied _libcTmp2's bank
; is the BUFFER's (_Sock_BufBank), so the bank is put back before the fill.
; MX %00.  Clobbers A, Y.
;------------------------------------------------------------------------------
_Sock_FillSrc   MX      %00
                LDA     _sockSrcOff             ; 0: the call asked for no address
                BNE     @fs_want                ;   (recv, read), which 2.11BSD's
                RTS                             ;   recvit copies none for
@fs_want        STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                                                ; falls through into the fill
;------------------------------------------------------------------------------
; _Sock_FillSin - write a sockaddr_in into the caller's buffer.
; In: _libcTmp2 = far pointer to the caller's 16-byte record; _sockSrcIp[4] =
; address in NETWORK order; _sockSrcPort[2] = port in NETWORK order (hi first).
; MX %00 in/out.  Clobbers A, Y.
;
; This existed twice, spelled out by hand, in the UDP and IPRAW recv paths --
; and the sockaddr layout comment in include/socket.s has said since it was
; written that accept and getpeername would want the same fill.  They do, so it
; is a routine now.  The FAMILY is the part worth having in one place: it is a
; 2-byte 2.11BSD short and a caller that reads AF_INET back is relying on the
; high byte being zeroed, which is exactly the kind of thing a fourth hand-copy
; forgets.
;------------------------------------------------------------------------------
_Sock_FillSin   MX      %00
                SEP     #$20
                MX      %10
                LDY     #SIN_FAMILY
                LDA     #AF_INET
                STA     [_libcTmp2],Y           ; sin_family lo = AF_INET
                INY
                LDA     #0
                STA     [_libcTmp2],Y           ; sin_family hi = 0 (2.11BSD short)
                LDY     #SIN_PORT
                LDA     _sockSrcPort            ; hi (network order)
                STA     [_libcTmp2],Y
                INY
                LDA     _sockSrcPort+1          ; lo
                STA     [_libcTmp2],Y
                LDY     #SIN_ADDR
                LDA     _sockSrcIp
                STA     [_libcTmp2],Y
                INY
                LDA     _sockSrcIp+1
                STA     [_libcTmp2],Y
                INY
                LDA     _sockSrcIp+2
                STA     [_libcTmp2],Y
                INY
                LDA     _sockSrcIp+3
                STA     [_libcTmp2],Y
                LDY     #SIN_ZERO               ; BSD callers memcmp whole records
                LDA     #0                      ;   (and pass them to bind), so the
@sfs_z          STA     [_libcTmp2],Y           ;   pad must be zero, not whatever
                INY                             ;   the caller's stack held
                CPY     #SIN_SIZE
                BCC     @sfs_z
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Tcp_PeerName - stage _sockSrcIp / _sockSrcPort from the chip's connected-peer
; registers (Sn_DIPR, Sn_DPORT) for the socket at _sockTmpHw.  Both are already
; network order on the wire and in the register file, so this is a straight
; copy.  MX %00 in/out.  Caller has already checked _Xport_HwOk and the state.
;------------------------------------------------------------------------------
_Tcp_PeerName   MX      %00
                U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_DIPR
                JSR     _W5_SetSnAR
                LDX     #0
@tpn_ip         LDAL    U2_DAT
                STA     _sockSrcIp,X
                INX
                CPX     #4
                BCC     @tpn_ip
                LDA     #SN_DPORT
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockSrcPort            ; hi
                LDAL    U2_DAT
                STA     _sockSrcPort+1          ; lo
                REP     #$30
                MX      %00
                U2_UNLOCK
                RTS

; _Xport_Chip - is a W5100 fitted at all?  C=1 yes, C=0 no.  MX %00.  Clobbers A.
;
; WITH NO CARD EVERY CHIP REGISTER READ IS NOISE.  _u2Slot is 0 and
; _W5_PatchSlot leaves the U2_* sites aimed at slot 1, whose I/O space nothing
; drives, so Sn_RX_RSR comes back as whatever the bus last carried.  Measured on
; the card-less harness, one socket bound to 0.0.0.0:514: select answered
; readable, not, readable; FIONREAD answered 0, -7968, -8064; and recvfrom
; returned 0 bytes as a success, and on an unbound socket 64 bytes of garbage
; as a datagram (apple/fgx#296).  There is no failure to decide by, because
; garbage reads as data, so this is the one place the seam asks whether the
; card exists -- where _Loop_* decide loopback by the chip FAILING instead.
;
; Each verb then gives the answer 2.11BSD gives with no interface configured:
; in_pcbbind takes the wildcard, so bind succeeds; nothing can arrive, so the
; socket is never readable and a receive finds nothing; and in_pcbconnect --
; which udp_output calls for a sendto (udp_usrreq.c:214) -- ends
; `if (ia == 0) ia = in_ifaddr; if (ia == 0) return (EADDRNOTAVAIL)'
; (vendor/2.11BSD/usr/sys/netinet/in_pcb.c:190-193), so a send and a connect
; answer EADDRNOTAVAIL.  _u2Slot is a kernel static and DBR is the kernel bank
; in every net op.
_Xport_Chip     MX      %00
                LDA     |_u2Slot
                AND     #$00FF
                CMP     #1                      ; C=1 iff a slot was detected
                RTS

; _Xport_ChipTag - the send and receive seam's opening.  C=1 + A = SOCK_Proto
; when the descriptor names a chip transport and a chip is fitted.  C=0 + A =
; errno otherwise: EINVAL for a tag no chip transport owns, which is the answer
; the tag branch gave before it asked about the card, and EADDRNOTAVAIL for a
; chip transport with no chip.  The tag goes first so that an AF_UNIX socket,
; which the chip never serves, answers the same with a card as without.  MX %00.
_Xport_ChipTag  MX      %00
                JSR     _Xport_LoadTag
                CMP     #XPORT_UNIX             ; UDP, ICMP and TCP are the
                BCS     @xct_bad                ;   chip's: 1..3, below UNIX's 4
                CMP     #XPORT_UDP              ;   and above NONE's 0
                BCC     @xct_bad
                PHA
                JSR     _Xport_Chip
                PLA
                BCS     @xct_ok
                LDA     #EADDRNOTAVAIL
                CLC
@xct_ok         RTS
@xct_bad        LDA     #EINVAL
                CLC
                RTS

; _Xport_HwOk - is _sockTmpHw a REAL W5100 socket index?  C=1 yes, C=0 it is a
; sentinel (SOCK_HW_NONE $FF, SOCK_HW_LOOP $FE) or wild.  MX %00.  Clobbers A.
;
; ONE BOUND, ONE DEFINITION.  This test has been added to the seam four separate
; times, each after a defect (#97 select, #132 the free, #138 shutdown, #139
; connect), and twice it was written as an ENUMERATION of the sentinels -- which
; is what produced two of those defects, because the second sentinel was added
; later and nothing that enumerated the first had to change to keep assembling.
; The ANSWER to a bad index is local to each verb (a status of "not ready", a
; teardown no-op, EINVAL from connect), so callers still branch for themselves;
; only the question is shared.  A new verb that drives the chip needs two lines
; here, not a fifth copy of the reasoning.
_Xport_HwOk     MX      %00
                LDA     _sockTmpHw
                AND     #$00FF
                CMP     #W5_NSOCK               ; >= W5_NSOCK is sentinel or wild
                BCS     @xho_bad
                SEC
                RTS
@xho_bad        CLC
                RTS

;------------------------------------------------------------------------------
; _Xport_Claim - give the descriptor at _sockTmpOff a W5100 socket if it has
; none yet.  C=1: _sockTmpHw is what it was, or the socket just claimed (also
; written to SOCK_HwIdx).  C=0 + A = ENOBUFS: all three are in use.  MX %00.
;
; Only SOCK_HW_UNCLAIMED is claimed for.  A loopback or detached descriptor
; keeps its sentinel and the verb's own _Xport_HwOk answer.  ENOBUFS is
; 2.11BSD's errno for a network resource running out under a verb
; (in_pcballoc, sosend's sbspace); the descriptor stays unclaimed and usable.
;------------------------------------------------------------------------------
_Xport_Claim    MX      %00
                LDA     _sockTmpHw
                AND     #$00FF
                CMP     #SOCK_HW_UNCLAIMED
                BEQ     @xcl_take
                SEC
                RTS
@xcl_take       JSR     _W5_SockAlloc
                BCS     @xcl_got
                LDA     #ENOBUFS
                RTS                             ; C=0 from _W5_SockAlloc
@xcl_got        STA     _sockTmpHw
                LDA     _sockTmpOff
                CLC
                ADC     #SOCK_HwIdx
                TAY
                SEP     #$20
                MX      %10
                LDA     _sockTmpHw
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                SEC
                RTS

_Xport_LoadTag  MX      %00
                LDA     _sockTmpOff
                CLC
                ADC     #SOCK_Proto
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                RTS

;==============================================================================
; Shared W5100 ring helpers — transport-agnostic plumbing reused by the UDP and
; ICMP/IPRAW transport cores.  The cores write the transport-specific framing
; (dest addr/port, header parse); these do the generic TX/RX ring mechanics.
; All assume the caller holds U2_LOCK.  In: _sockTmpHw + the named _sock* state.

;==============================================================================
; W5100 transport cores (UDP + ICMP/IPRAW) — relocated from socket.s in
; Increment 2 so the BSD socket core stays hardware-generic.  Reached only via
; the _Net_Xport_* seam (JMP); read their state from _sock* statics (socket.s,
; bank \$02).  Call the shared _W5_* helpers above.
;==============================================================================
;==============================================================================
; _Udp_OpenAt - W5100 UDP open for the descriptor at _sockTmpOff.
; In: _sockTmp2 = port (hi at +1, lo at +0), _sockTmpHw, _sockTmpOff.  MX %00.
; Opens Sn_MR=UDP on the port, waits SR=$22, marks SOCK_Bound.  Out: A=0, C=1.
; Reached via _Net_Xport_Open; its RTS returns to the bind() syscall caller.
;==============================================================================
_Udp_OpenAt     MX      %00
                U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #$00                    ; Sn_MR offset
                JSR     _W5_SetSnAR
                LDA     #$02                    ; UDP
                STAL    U2_DAT
                LDA     #$04                    ; Sn_PORT offset
                JSR     _W5_SetSnAR
                LDA     _sockTmp2+1             ; port hi
                STAL    U2_DAT
                LDA     _sockTmp2               ; port lo
                STAL    U2_DAT
                LDA     #$01                    ; Sn_CR offset
                JSR     _W5_SetSnAR
                LDA     #$01                    ; OPEN
                STAL    U2_DAT
                LDX     #$00
@uo_srW         LDA     #$03                    ; Sn_SR offset
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                CMP     #$22                    ; SOCK_UDP
                BEQ     @uo_srOK
                DEX
                BNE     @uo_srW
@uo_srOK        REP     #$30
                MX      %00
                U2_UNLOCK
                LDA     _sockTmpOff             ; SOCK_LPort, host order: the
                CLC                             ;   port _Udp_PortShare matches
                ADC     #SOCK_LPort
                TAY
                LDA     _sockTmp2
                STA     [_sockTablePtr],Y
                ; mark bound
                LDY     _sockTmpOff
                TYA
                CLC
                ADC     #SOCK_Bound
                TAY
                SEP     #$20
                MX      %10
                LDA     #$01
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                LDA     #0
                SEC
                RTS
_Udp_SendCore   MX      %00
                JSR     _So_TxFill              ; the uio -> the bounce (sosend's
                                                ;   mbuf); _libcTmp2 = the bounce
                ; --- W5100 UDP send (no ring wrap) ---
                U2_LOCK
                SEP     #$20
                MX      %10
                LDA     #$0C                    ; Sn_DIPR
                JSR     _W5_SetSnAR
                LDA     _sockDstIp
                STAL    U2_DAT
                LDA     _sockDstIp+1
                STAL    U2_DAT
                LDA     _sockDstIp+2
                STAL    U2_DAT
                LDA     _sockDstIp+3
                STAL    U2_DAT
                LDA     #$10                    ; Sn_DPORT
                JSR     _W5_SetSnAR
                LDA     _sockDstPort            ; hi
                STAL    U2_DAT
                LDA     _sockDstPort+1          ; lo
                STAL    U2_DAT
                JSR     _W5_TxStream            ; ring stream + SEND (MX %10 in, %00 out)
                U2_UNLOCK
                LDA     _sockLen
                SEC
                RTS
_Udp_RecvCore   MX      %00
                U2_LOCK
                JSR     _W5_RxSetup             ; C=1 + AR at header / C=0 empty
                BCS     @ur_have
                U2_UNLOCK                       ; no datagram -> EAGAIN
                LDA     #EAGAIN
                CLC
                RTS
@ur_have        ; --- 8-byte UDP header [srcIP(4) srcPort(2) len(2)] (AR auto-inc) ---
                SEP     #$20
                MX      %10
                LDAL    U2_DAT
                STA     _sockSrcIp
                LDAL    U2_DAT
                STA     _sockSrcIp+1
                LDAL    U2_DAT
                STA     _sockSrcIp+2
                LDAL    U2_DAT
                STA     _sockSrcIp+3
                LDAL    U2_DAT
                STA     _sockSrcPort            ; hi (net order)
                LDAL    U2_DAT
                STA     _sockSrcPort+1          ; lo
                LDAL    U2_DAT
                STA     _sockRxLen+1            ; payload len hi (big-endian)
                LDAL    U2_DAT
                STA     _sockRxLen              ; lo
                REP     #$20
                MX      %00
                LDA     #8                      ; UDP header length
                STA     _w5RxHdrLen
                ; A CONNECTED SOCKET HEARS ONLY ITS PEER.  udp_input finds the
                ; socket with in_pcblookup(src, sport, dst, dport), and a pcb
                ; whose inp_faddr is set matches only that exact source
                ; (vendor/2.11BSD/usr/sys/netinet/in_pcb.c, in_pcblookup), so a
                ; datagram from anyone else never reaches it.  The chip socket
                ; has already taken it, so it is consumed here and the receive
                ; answers as if nothing had come.
                JSR     _So_UdpPeer
                BCC     @ur_take
                JSR     _So_UdpFrom
                BCS     @ur_take
                JSR     _W5_RxAdvance           ; drop it: Sn_RX_RD past it, RECV
                U2_UNLOCK
                LDA     #EAGAIN
                CLC
                RTS
@ur_take        JSR     _W5_RxCopy              ; payload -> the bounce, set _sockCapLen
                JSR     _So_RxDrain             ; the bounce -> the caller's uio
                JSR     _W5_RxAdvance           ; Sn_RX_RD += 8 + rxLen, RECV
                U2_UNLOCK
                JSR     _Sock_FillSrc           ; the datagram's source address
                LDA     _sockCapLen
                SEC
                RTS

;------------------------------------------------------------------------------
; _Udp_PortShare - in_pcbbind's EADDRINUSE lookup for a UDP bind to a port the
; chip already has open.  In: _sockTmp2 = the port (host order), _sockTmpOff,
; SOCK_Flags already carrying SOCK_WILD for this bind.  MX %00.  Clobbers X, Y.
; Out: C=0 + A = EADDRINUSE; C=1 + A=0 no holder, open a chip socket as usual;
; C=1 + A=1 bound onto the holder's chip socket (SOCK_HwIdx, SOCK_Bound,
; SOCK_LPort written, _sockTmpHw set).
;
; vendor/2.11BSD/usr/sys/netinet/in_pcb.c, in_pcbbind: without SO_REUSEADDR
; the lookup is INPLOOKUP_WILDCARD, so a pcb on the port with a wildcard
; address on either side is a conflict; with it, only an exact local address
; is.  This machine has one address, so a UDP pcb's local address is the
; card's or the wildcard (SOCK_WILD), and the two outcomes are:
;   same address as the holder                  -> EADDRINUSE
;   the other one, and this socket SO_REUSEADDR -> both bound
; ntpd's pair is the second case: 0.0.0.0:123 and <card>:123.  Both are the
; same endpoint on the wire, because the W5100 demultiplexes UDP by port alone,
; so the second descriptor takes the first one's chip socket rather than a
; second socket on the same port.  A datagram then goes to whichever reads it
; first; udp_input gives it to one pcb as well, the most specific.  Teardown
; closes the chip socket with its last holder (_Sock_HwShared).
;
; Port 0 is not looked up: in_pcbbind picks an ephemeral port there, and
; _Sock_EphemPort has already chosen one.
;------------------------------------------------------------------------------
_Udp_PortShare  MX      %00
                LDA     _sockTmp2
                BNE     @ups_scan
                LDA     #0
                SEC
                RTS
@ups_scan       LDX     #0
@ups_l          CPX     _sockTmpOff
                BEQ     @ups_next
                TXY                             ; +0 InUse, +1 HwIdx
                LDA     [_sockTablePtr],Y
                AND     #$00FF
                BEQ     @ups_next
                LDA     [_sockTablePtr],Y
                XBA
                AND     #$00FF
                CMP     #W5_NSOCK               ; holds a real chip socket
                BCS     @ups_next
                TXA
                CLC
                ADC     #SOCK_Proto
                TAY
                LDA     [_sockTablePtr],Y
                AND     #$00FF
                CMP     #XPORT_UDP
                BNE     @ups_next
                TXA
                CLC
                ADC     #SOCK_LPort
                TAY
                LDA     [_sockTablePtr],Y
                CMP     _sockTmp2
                BEQ     @ups_hit
@ups_next       TXA
                CLC
                ADC     #SOCK_REC_SIZE
                TAX
                CPX     #SOCKTBL_BLK_SIZE
                BCC     @ups_l
                LDA     #0                      ; nobody holds the port
                SEC
                RTS
@ups_hit        TXA                             ; the holder's SOCK_WILD ...
                CLC
                ADC     #SOCK_Flags
                TAY
                LDA     [_sockTablePtr],Y
                PHA
                LDA     _sockTmpOff             ; ... against this bind's
                CLC
                ADC     #SOCK_Flags
                TAY
                LDA     [_sockTablePtr],Y
                EOR     1,S
                AND     #SOCK_WILD
                BEQ     @ups_inuse0             ; the same address: always a clash
                PLA
                LDA     [_sockTablePtr],Y       ; this socket's SO_REUSEADDR
                AND     #SO_REUSEADDR
                BEQ     @ups_inuse              ; wildcard lookup matches it
                TXY                             ; share: this SOCK_HwIdx := the
                INY                             ;   holder's
                LDA     [_sockTablePtr],Y
                AND     #$00FF
                STA     _sockTmpHw
                LDA     _sockTmpOff
                CLC
                ADC     #SOCK_HwIdx
                TAY
                SEP     #$20
                MX      %10
                LDA     _sockTmpHw
                STA     [_sockTablePtr],Y
                INY                             ; SOCK_Flags
                INY                             ; SOCK_Bound
                LDA     #$01
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                INY                             ; SOCK_LPort
                LDA     _sockTmp2
                STA     [_sockTablePtr],Y
                LDA     #1
                SEC
                RTS
@ups_inuse0     PLA
@ups_inuse      LDA     #EADDRINUSE
                CLC
                RTS

;------------------------------------------------------------------------------
; _Udp_Connect - connect(2) on a UDP socket: 2.11BSD udp_usrreq PRU_CONNECT,
; which is in_pcbconnect (vendor/2.11BSD/usr/sys/netinet/in_pcb.c) plus
; soconnect's disconnect-first rule (sys/uipc_socket.c).  In: _libcTmp2 = the
; caller's sockaddr_in, _sockDstIp / _sockDstPort staged from it, _sockTmpOff,
; _sockTmpHw; a chip is fitted.  Out: A=0 + C=1, or A = errno + C=0.  MX %00.
;
; soconnect: "if connected, try to disconnect first.  This allows user to
; disconnect by connecting to, e.g., a null address."  So the old peer goes
; before the new address is judged, and a refused address leaves the socket
; unconnected.  Then in_pcbconnect's order:
;   sin_family != AF_INET              -> EAFNOSUPPORT
;   sin_port == 0                      -> EADDRNOTAVAIL
;   sin_addr == INADDR_ANY             -> the interface's own address
;   inp_lport == 0                     -> in_pcbbind(inp, 0): an ephemeral port
; and the peer is recorded.  It does not do in_pcbconnect's two other steps:
; 255.255.255.255 is not rewritten to the interface's broadcast address, and
; there is no in_pcblookup for an identical association (EADDRINUSE) -- one
; interface and a chip socket per descriptor leave no second pcb to collide
; with except through SO_REUSEADDR.
;------------------------------------------------------------------------------
_Udp_Connect    MX      %00
                LDA     _sockTmpOff             ; soconnect: disconnect first
                CLC
                ADC     #SOCK_FAddr
                TAY
                LDA     #0
                STA     [_sockTablePtr],Y       ; SOCK_FAddr 0..1
                INY
                INY
                STA     [_sockTablePtr],Y       ; SOCK_FAddr 2..3
                INY
                INY
                STA     [_sockTablePtr],Y       ; SOCK_FPort
                LDY     #SIN_FAMILY
                LDA     [_libcTmp2],Y
                CMP     #AF_INET
                BEQ     @uc_fam
                LDA     #EAFNOSUPPORT
                CLC
                RTS
@uc_fam         LDA     _sockDstPort
                BNE     @uc_port
                LDA     #EADDRNOTAVAIL
                CLC
                RTS
@uc_port        LDA     _sockDstIp
                ORA     _sockDstIp+2
                BNE     @uc_addr
                LDA     _ifS1Off                ; INADDR_ANY: the primary address
                AND     #$00FF
                CLC
                ADC     #IF_Ip
                TAY
                LDA     [_ifTablePtr],Y
                STA     _sockDstIp
                INY
                INY
                LDA     [_ifTablePtr],Y
                STA     _sockDstIp+2
@uc_addr        JSR     _Sock_EnsureBound       ; in_pcbbind if unbound; claims
                BCC     @uc_out                 ;   the chip socket
                LDA     _sockTmpOff
                CLC
                ADC     #SOCK_FAddr
                TAY
                LDA     _sockDstIp
                STA     [_sockTablePtr],Y
                INY
                INY
                LDA     _sockDstIp+2
                STA     [_sockTablePtr],Y
                INY
                INY
                LDA     _sockDstPort
                STA     [_sockTablePtr],Y
                LDA     #0
                SEC
@uc_out         RTS

;==============================================================================
; _Icmp_OpenAt - open the hw socket in IPRAW mode for ICMP (Sn_PROTO=1).
; In: _sockTmpHw, _sockTmpOff.  MX %00.  Sets Sn_PROTO=$01 (offset $14),
; Sn_MR=$03 (IPRAW), waits Sn_SR=$32 (SOCK_IPRAW), marks SOCK_Bound.
; Out: A=0, C=1.  Reached via _Net_Xport_Open.
;==============================================================================
_Icmp_OpenAt    MX      %00
                U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #$14                    ; Sn_PROTO offset
                JSR     _W5_SetSnAR
                LDA     #IPPROTO_ICMP           ; = 1
                STAL    U2_DAT
                LDA     #$00                    ; Sn_MR offset
                JSR     _W5_SetSnAR
                LDA     #$03                    ; IPRAW
                STAL    U2_DAT
                LDA     #$01                    ; Sn_CR offset
                JSR     _W5_SetSnAR
                LDA     #$01                    ; OPEN
                STAL    U2_DAT
                LDX     #$00
@io_srW         LDA     #$03                    ; Sn_SR offset
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                CMP     #$32                    ; SOCK_IPRAW
                BEQ     @io_srOK
                DEX
                BNE     @io_srW
@io_srOK        REP     #$30
                MX      %00
                U2_UNLOCK
                LDY     _sockTmpOff
                TYA
                CLC
                ADC     #SOCK_Bound
                TAY
                SEP     #$20
                MX      %10
                LDA     #$01
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                LDA     #0
                SEC
                RTS

;==============================================================================
; _Icmp_SendCore - ICMP/IPRAW send: write Sn_DIPR only (no port), then stream
; the ICMP message (header+payload, L4 checksum supplied by userland).  The
; chip builds the IP header, ARPs, and checksums IP.  MX %00.  Reached via
; _Net_Xport_Send.  Out: A=bytes, C=1.
;==============================================================================
_Icmp_SendCore  MX      %00
                JSR     _So_TxFill              ; the uio -> the bounce
                U2_LOCK
                SEP     #$20
                MX      %10
                LDA     #$0C                    ; Sn_DIPR
                JSR     _W5_SetSnAR
                LDA     _sockDstIp
                STAL    U2_DAT
                LDA     _sockDstIp+1
                STAL    U2_DAT
                LDA     _sockDstIp+2
                STAL    U2_DAT
                LDA     _sockDstIp+3
                STAL    U2_DAT
                JSR     _W5_TxStream            ; ring stream + SEND (MX %10 in, %00 out)
                U2_UNLOCK
                LDA     _sockLen
                SEC
                RTS

;==============================================================================
; _Icmp_RecvCore - ICMP/IPRAW recv.  6-byte IPRAW header [srcIP(4) len(2)] (no
; port).  Fills the caller sockaddr with sin_port=0.  MX %00.  Reached via
; _Net_Xport_Recv.  Out: A=bytes + C=1, or A=EAGAIN + C=0.
;==============================================================================
_Icmp_RecvCore  MX      %00
                U2_LOCK
                JSR     _W5_RxSetup             ; C=1 + AR at header / C=0 empty
                BCS     @ir_have
                U2_UNLOCK                       ; no packet -> EAGAIN
                LDA     #EAGAIN
                CLC
                RTS
@ir_have        ; --- 6-byte IPRAW header [srcIP(4) len(2)] (AR auto-inc) ---
                SEP     #$20
                MX      %10
                LDAL    U2_DAT
                STA     _sockSrcIp
                LDAL    U2_DAT
                STA     _sockSrcIp+1
                LDAL    U2_DAT
                STA     _sockSrcIp+2
                LDAL    U2_DAT
                STA     _sockSrcIp+3
                LDAL    U2_DAT
                STA     _sockRxLen+1            ; payload len hi (big-endian)
                LDAL    U2_DAT
                STA     _sockRxLen              ; lo
                REP     #$20
                MX      %00
                LDA     #6                      ; IPRAW header length
                STA     _w5RxHdrLen
                JSR     _W5_RxCopy              ; payload -> the bounce, set _sockCapLen
                JSR     _So_RxDrain             ; the bounce -> the caller's uio
                JSR     _W5_RxAdvance           ; Sn_RX_RD += 6 + rxLen, RECV
                U2_UNLOCK
                ; --- fill the caller's src sockaddr_in (raw: sin_port = 0) ---
                SEP     #$20
                MX      %10
                LDA     #0                      ; a raw socket has no port
                STA     _sockSrcPort
                STA     _sockSrcPort+1
                REP     #$20
                MX      %00
                JSR     _Sock_FillSrc
                LDA     _sockCapLen
                SEC
                RTS

;==============================================================================

;==============================================================================
; W5100 TCP transport cores (XPORT_TCP).  Outbound client: connect/send/recv/
; close.  Reached via the _Net_Xport_* seam (JMP); read state from the _sock*
; statics (socket.s).  Blocking + ^C-interruptible (EINTR); recv honors
; MSG_DONTWAIT.  MX %00 in/out.  All chip sequences U2_LOCK-wrapped.
;==============================================================================
_Tcp_Connect    MX      %00
                JSR     _Sock_EphemPort       ; ephemeral local port -> _sockTmp2
                ; RECORD IT IN THE DESCRIPTOR, not only in the chip.  The port
                ; chosen here went straight into Sn_PORT and nowhere else, so
                ; the socket's own SOCK_LPort stayed 0 -- which nothing read
                ; until getsockname(2) existed, and which made it report a
                ; connected socket as having no local port while the PEER could
                ; see the real one (apple/fgx#142).
                LDY     _sockTmpOff
                TYA
                CLC
                ADC     #SOCK_LPort
                TAY
                SEP     #$20
                MX      %10
                LDA     _sockTmp2             ; port lo (host order, as bind writes)
                STA     [_sockTablePtr],Y
                INY
                LDA     _sockTmp2+1           ; port hi
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_MR
                JSR     _W5_SetSnAR
                LDA     #MR_TCP
                STAL    U2_DAT
                LDA     #SN_PORT
                JSR     _W5_SetSnAR
                LDA     _sockTmp2+1           ; port hi (big-endian)
                STAL    U2_DAT
                LDA     _sockTmp2             ; port lo
                STAL    U2_DAT
                LDA     #SN_CR
                JSR     _W5_SetSnAR
                LDA     #CR_OPEN
                STAL    U2_DAT
                LDX     #$0000
@tc_initW       LDA     #SN_SR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                CMP     #SR_INIT
                BEQ     @tc_init
                DEX
                BNE     @tc_initW
                REP     #$30                  ; OPEN never reached INIT
                MX      %00
                U2_UNLOCK
                JSR     _Tcp_CloseHw
                LDA     #ETIMEDOUT
                CLC
                RTS
@tc_init        MX      %11                  ; reached via BEQ at M8 (prev path was M16)
                LDA     #SN_DIPR              ; dest IP
                JSR     _W5_SetSnAR
                LDA     _sockDstIp
                STAL    U2_DAT
                LDA     _sockDstIp+1
                STAL    U2_DAT
                LDA     _sockDstIp+2
                STAL    U2_DAT
                LDA     _sockDstIp+3
                STAL    U2_DAT
                LDA     #SN_DPORT
                JSR     _W5_SetSnAR
                LDA     _sockDstPort          ; hi (net order)
                STAL    U2_DAT
                LDA     _sockDstPort+1        ; lo
                STAL    U2_DAT
                LDA     #SN_CR
                JSR     _W5_SetSnAR
                LDA     #CR_CONNECT
                STAL    U2_DAT
                REP     #$30
                MX      %00
                U2_UNLOCK
@tc_pollC       U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_SR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockTmp2             ; SR (low byte)
                REP     #$30
                MX      %00
                U2_UNLOCK
                LDA     _sockTmp2
                AND     #$00FF
                CMP     #SR_ESTABLISHED
                BNE     @tc_xpne              ; forward >128B after U2_LOCK growth -> BRL
                BRL     @tc_estab
@tc_xpne        CMP     #SR_CLOSED
                BEQ     @tc_failed
                JSR     _Sock_PollIntr        ; C=1 if ^C pending
                BCS     @tc_intr
                BRL     @tc_pollC             ; retry (long back-branch)
@tc_intr        JSR     _Tcp_CloseHw
                LDA     #EINTR
                CLC
                RTS
@tc_failed      U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_IR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                AND     #IR_TIMEOUT
                STA     _sockTmp2
                REP     #$30
                MX      %00
                U2_UNLOCK
                JSR     _Tcp_CloseHw
                LDA     _sockTmp2
                AND     #$00FF
                BEQ     @tc_refused
                LDA     #ETIMEDOUT
                CLC
                RTS
@tc_refused     LDA     #ECONNREFUSED
                CLC
                RTS
@tc_estab       LDY     _sockTmpOff           ; SOCK_Bound = 1
                TYA
                CLC
                ADC     #SOCK_Bound
                TAY
                SEP     #$20
                MX      %10
                LDA     #$01
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                LDY     _sockTmpOff           ; SOCK_State = ESTABLISHED
                TYA
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     #TCP_ESTABLISHED
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Tcp_CloseHw - chip CLOSE only (caller frees the descriptor).  MX %00.
;------------------------------------------------------------------------------
_Tcp_CloseHw    MX      %00
                U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_CR
                JSR     _W5_SetSnAR
                LDA     #CR_CLOSE
                STAL    U2_DAT
                REP     #$30
                MX      %00
                U2_UNLOCK
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Tcp_Close - graceful DISCON (FIN) then CLOSE.  Reached via _Net_Xport_Close
; (from _Sock_Teardown).  MX %00.
;------------------------------------------------------------------------------
_Tcp_Close      MX      %00
                U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_CR
                JSR     _W5_SetSnAR
                LDA     #CR_DISCON
                STAL    U2_DAT
                LDX     #$0040                ; brief bounded wait for CLOSED
@tcl_w          LDA     #SN_SR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                CMP     #SR_CLOSED
                BEQ     @tcl_done
                DEX
                BNE     @tcl_w
@tcl_done       LDA     #SN_CR
                JSR     _W5_SetSnAR
                LDA     #CR_CLOSE
                STAL    U2_DAT
                REP     #$30
                MX      %00
                U2_UNLOCK
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Net_Xport_Shutdown - TCP half-close: send FIN (CR_DISCON) on _sockTmpHw's
; socket, leaving it in FIN_WAIT so recv() still drains queued data + sees the
; peer FIN as EOF.  Does NOT CLOSE/free the hw socket (close() does the full
; teardown).  No-hw / UDP / ICMP: no-op success.  Out: A=0, C=1.  MX %00.
;------------------------------------------------------------------------------
_Net_Xport_Shutdown MX  %00
                ; BOUND, NOT AN ENUMERATION OF SENTINELS (see _Xport_HwOk).
                ; This tested SOCK_HW_NONE alone, so a LOOPBACK socket walked
                ; straight past it: its _sockTmpHw is SOCK_HW_LOOP ($FE) and it
                ; deliberately keeps SOCK_Proto = XPORT_TCP, so both guards below
                ; passed too and _W5_SetSnAR drove the W5100 at register index
                ; $FE -- a wild address -- to fire CR_DISCON at hardware that is
                ; not there.  There is no _Loop_ShutdownTry, so _Sys_Shutdown
                ; dispatches loopback straight in here.
                JSR     _Xport_HwOk
                BCC     @nsh_ok                 ; sentinel or wild -> nothing to do
                JSR     _Xport_LoadTag          ; A = SOCK_Proto
                CMP     #XPORT_TCP
                BNE     @nsh_ok                 ; UDP/ICMP: no FIN to send
                U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_CR
                JSR     _W5_SetSnAR
                LDA     #CR_DISCON              ; FIN; socket -> FIN_WAIT (RX still open)
                STAL    U2_DAT
                REP     #$30
                MX      %00
                U2_UNLOCK
@nsh_ok         LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Tcp_BindAt - TCP bind: record the local port in SOCK_LPort + mark SOCK_Bound.
; No chip OPEN here (TCP opens at listen()).  Reached via _Net_Xport_Open from
; the bind() syscall.  Out: A=0, C=1.  MX %00.
;------------------------------------------------------------------------------
_Tcp_BindAt     MX      %00
                LDY     _sockTmpOff           ; SOCK_LPort = _sockTmp2 (host order)
                TYA
                CLC
                ADC     #SOCK_LPort
                TAY
                SEP     #$20
                MX      %10
                LDA     _sockTmp2             ; port lo
                STA     [_sockTablePtr],Y
                INY
                LDA     _sockTmp2+1           ; port hi
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                LDY     _sockTmpOff           ; SOCK_Bound = 1
                TYA
                CLC
                ADC     #SOCK_Bound
                TAY
                SEP     #$20
                MX      %10
                LDA     #$01
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Tcp_Listen - TCP server: open the bound W5100 socket in TCP mode on SOCK_LPort
; (OPEN -> INIT), then LISTEN (-> SR_LISTEN).  SOCK_State = TCP_LISTEN.  Reached
; via _Net_Xport_Listen.  Out: A=0/C=1, or A=errno/C=0.  MX %00.
;------------------------------------------------------------------------------
_Tcp_Listen     MX      %00
                LDY     _sockTmpOff           ; load SOCK_LPort -> _sockTmp2
                TYA
                CLC
                ADC     #SOCK_LPort
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y     ; port lo
                STA     _sockTmp2
                INY
                LDA     [_sockTablePtr],Y     ; port hi
                STA     _sockTmp2+1
                REP     #$20
                MX      %00
                U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_MR
                JSR     _W5_SetSnAR
                LDA     #MR_TCP
                STAL    U2_DAT
                LDA     #SN_PORT
                JSR     _W5_SetSnAR
                LDA     _sockTmp2+1           ; port hi (big-endian)
                STAL    U2_DAT
                LDA     _sockTmp2             ; port lo
                STAL    U2_DAT
                LDA     #SN_CR
                JSR     _W5_SetSnAR
                LDA     #CR_OPEN
                STAL    U2_DAT
                LDX     #$0000
@tl_initW       LDA     #SN_SR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                CMP     #SR_INIT
                BEQ     @tl_init
                DEX
                BNE     @tl_initW
                REP     #$30                  ; OPEN never reached INIT
                MX      %00
                U2_UNLOCK
                JSR     _Tcp_CloseHw
                LDA     #ETIMEDOUT
                CLC
                RTS
@tl_init        MX      %11                  ; reached via BEQ at M8 (prev path was M16)
                LDA     #SN_CR               ; issue LISTEN
                JSR     _W5_SetSnAR
                LDA     #CR_LISTEN
                STAL    U2_DAT
                LDX     #$0000
@tl_lW          LDA     #SN_SR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                CMP     #SR_LISTEN
                BEQ     @tl_ok
                DEX
                BNE     @tl_lW
                REP     #$30                  ; LISTEN never reached SR_LISTEN
                MX      %00
                U2_UNLOCK
                JSR     _Tcp_CloseHw
                LDA     #ETIMEDOUT
                CLC
                RTS
@tl_ok          REP     #$30
                MX      %00
                U2_UNLOCK
                LDY     _sockTmpOff           ; SOCK_State = TCP_LISTEN
                TYA
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     #TCP_LISTEN
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Tcp_Accept - block (poll Sn_SR via the socket-sleep path) until the listening
; W5100 socket transitions to ESTABLISHED (a peer connected).  Marks the
; descriptor's SOCK_State = ESTABLISHED; the _Sys_Accept caller then hands the
; connection to a new fd and detaches the listener.  Reached via
; _Net_Xport_Accept.  Out: A=0/C=1 (established), or A=errno/C=0 (EINTR on ^C).
; MX %00.  _sockTmpOff / _sockTmpHw survive the block (saved by _Sock_PollIntr).
;------------------------------------------------------------------------------
_Tcp_Accept     MX      %00
@ta_pollC       U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_SR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockTmp2             ; SR (low byte)
                REP     #$30
                MX      %00
                U2_UNLOCK
                LDA     _sockTmp2
                AND     #$00FF
                CMP     #SR_ESTABLISHED
                BEQ     @ta_estab
                ; A HALF-CLOSED PEER IS STILL A CONNECTION.  The chip completes
                ; the handshake on its own, so a client that FINs before accept
                ; runs leaves CLOSE_WAIT -- and recognising only ESTABLISHED and
                ; CLOSED left this loop sleeping on it forever while select (now
                ; correctly) reported it pending.  BSD accepts and lets the
                ; server read the EOF, which is what the caller is equipped for.
                CMP     #SR_CLOSE_WAIT
                BEQ     @ta_estab
                CMP     #SR_CLOSED
                BEQ     @ta_failed
                JSR     _Sock_PollIntr        ; C=1 if ^C pending
                BCS     @ta_intr
                BRL     @ta_pollC             ; retry (long back-branch)
@ta_intr        LDA     #EINTR
                CLC
                RTS
@ta_failed      LDA     #ENOTCONN            ; listener closed before a peer arrived
                CLC
                RTS
@ta_estab       LDY     _sockTmpOff           ; SOCK_State = ESTABLISHED
                TYA
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     #TCP_ESTABLISHED
                STA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Tcp_SendCore - send _sockLen bytes from [_libcTmp2].  Requires ESTABLISHED
; (else ENOTCONN); peer-closed -> EPIPE; caps to Sn_TX_FSR, blocks for space
; (^C->EINTR).  Out: A=bytes,C=1; A=errno,C=0.  MX %00.
;------------------------------------------------------------------------------
_Tcp_SendCore   MX      %00
                LDY     _sockTmpOff
                TYA
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                CMP     #TCP_ESTABLISHED
                BEQ     @ts_chk
                LDA     #ENOTCONN
                CLC
                RTS
@ts_chk         U2_LOCK
                SEP     #$30
                MX      %11
                LDA     #SN_SR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                CMP     #SR_ESTABLISHED
                BEQ     @ts_fsr
                REP     #$30
                MX      %00
                U2_UNLOCK
                LDA     #EPIPE
                CLC
                RTS
@ts_fsr         MX      %11                  ; reached via BEQ at M8 (EPIPE path was M16)
                LDA     #SN_TX_FSR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockTmp2+1           ; FSR hi (BE)
                LDAL    U2_DAT
                STA     _sockTmp2             ; FSR lo
                REP     #$30
                MX      %00
                LDA     _sockTmp2
                BNE     @ts_cap
                U2_UNLOCK                     ; no space -> block (^C?) or EAGAIN
                ; TWO WAYS TO BE NON-BLOCKING, and this honoured only one.
                ; MSG_DONTWAIT is the per-CALL flag; SOCK_NB is the per-
                ; DESCRIPTOR one that ioctl(FIONBIO) sets.  The receive path
                ; forty lines down tests both; this one could not, because the
                ; send arg block carried no flags word to test until
                ; apple/fgx#440 added it.  A caller that used the per-call flag
                ; to avoid touching descriptor state blocked anyway, with
                ; nothing anywhere saying the flag had been ignored
                ; (apple/fgx#441).
                ;
                ; _sockSendFlags is staged by every path that reaches here:
                ; net_op_send and net_op_sendto from their arg blocks, and
                ; _WrOp_Socket zeroes it, because write(2) is send(fd, buf,
                ; count, 0) and must not inherit the last send's flags.
                LDA     _sockSendFlags
                AND     #MSG_DONTWAIT
                BNE     @ts_wouldblk
                LDA     _sockTmpOff             ; SOCK_NB (FIONBIO): don't block
                CLC
                ADC     #SOCK_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                AND     #SOCK_NB
                REP     #$30
                MX      %00
                BEQ     @ts_block
@ts_wouldblk    LDA     #EAGAIN                ; TX full + non-blocking -> EAGAIN
                CLC
                RTS
@ts_block       JSR     _Sock_PollIntr
                BCS     @ts_intr
                BRL     @ts_chk               ; retry (long back-branch)
@ts_intr        LDA     #EINTR
                CLC
                RTS
@ts_cap         CMP     _sockLen
                BCS     @ts_useLen            ; FSR >= len -> send len
                STA     _sockLen              ; cap to FSR (short write)
@ts_useLen      JSR     _So_TxFill            ; the capped length, uio -> bounce
                SEP     #$20
                MX      %10
                JSR     _W5_TxStream          ; stream + SEND + wait SEND_OK (wrap-aware T8)
                REP     #$30
                MX      %00
                U2_UNLOCK
                LDA     _sockLen
                SEC
                RTS

;------------------------------------------------------------------------------
; _Tcp_RecvCore - copy up to _sockLen stream bytes into the caller's uio,
; through the bounce.  Blocking
; (^C->EINTR); MSG_DONTWAIT (_sockRecvFlags) -> EAGAIN.  Peer-closed + drained
; -> A=0,C=1 (EOF).  RX_RD advances by bytes CONSUMED.  Out: A=bytes,C=1;
; A=errno,C=0.  MX %00.
;------------------------------------------------------------------------------
_Tcp_RecvCore   MX      %00
                LDY     _sockTmpOff           ; require ESTABLISHED (else ENOTCONN)
                TYA
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                CMP     #TCP_ESTABLISHED
                BEQ     @tr_poll
                LDA     #ENOTCONN
                CLC
                RTS
@tr_poll        U2_LOCK
                JSR     _W5_RxSetup           ; C=1 + _sockTmp2=RSR + AR at data / C=0
                BCS     @tr_have
                SEP     #$30                  ; RSR==0: SR distinguishes EOF vs no-data
                MX      %11
                LDA     #SN_SR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockTmp2
                REP     #$30
                MX      %00
                U2_UNLOCK
                LDA     _sockTmp2
                AND     #$00FF
                CMP     #SR_CLOSE_WAIT
                BEQ     @tr_eof
                CMP     #SR_CLOSED
                BEQ     @tr_eof
                ; ESTABLISHED, no data yet.  TWO WAYS TO BE NON-BLOCKING, and
                ; this only ever honoured one of them.
                ;
                ; MSG_DONTWAIT is the per-CALL flag; SOCK_NB is the per-
                ; DESCRIPTOR one that ioctl(FIONBIO) sets.  Checking only the
                ; call flag meant recv() on a descriptor the caller had
                ; carefully made non-blocking BLOCKED anyway -- and the send
                ; path forty lines up tests SOCK_NB, so the omission was an
                ; oversight rather than a decision.
                ;
                ; It cost telnetd over the wire.  Its relay sets FIONBIO on both
                ; ends and then alternates read(pty) / recv(socket); with the
                ; recv blocking, the pty half only ran when a byte arrived from
                ; the client.  So the login banner sat unsent until the user
                ; pressed a key, and every echo was delivered one keystroke
                ; late -- type `root' and see `roo'.  Loopback was unaffected
                ; because _Loop_SoIo honours SOCK_NB, which is exactly why
                ; every loopback fixture passed while the wire did this.
                LDA     _sockRecvFlags
                AND     #MSG_DONTWAIT
                BNE     @tr_wouldblk
                LDA     _sockTmpOff
                CLC
                ADC     #SOCK_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                AND     #SOCK_NB
                REP     #$30
                MX      %00
                BEQ     @tr_block
@tr_wouldblk    LDA     #EAGAIN
                CLC
                RTS
@tr_block       JSR     _Sock_PollIntr
                BCS     @tr_intr
                BRL     @tr_poll              ; retry (long back-branch)
@tr_intr        LDA     #EINTR
                CLC
                RTS
@tr_eof         LDA     #0                    ; EOF (peer closed, buffer drained)
                SEC
                RTS
@tr_have        LDA     _sockTmp2             ; RSR -> _sockRxLen (no header)
                STA     _sockRxLen
                LDA     #0
                STA     _w5RxHdrLen           ; TCP: no per-packet header
                JSR     _W5_RxCopy            ; _sockCapLen = min(_sockRxLen,_sockLen) (wrap-aware T8)
                JSR     _So_RxDrain           ; the bounce -> the caller's uio
                LDA     _sockCapLen           ; advance RX_RD by bytes CONSUMED
                STA     _sockRxLen            ; (_W5_RxAdvance adds _w5RxHdrLen(0)+_sockRxLen)
                JSR     _W5_RxAdvance
                U2_UNLOCK
                LDA     _sockCapLen
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sock_PollIntr - BLOCK a socket op (recv/connect/send) until something it
; cares about may have changed, or a signal wants this task.  Phase 4.2: was a
; busy-poll; now _sleep on WCHAN_SOCK (the CPU idles) until swtch wakes socket
; sleepers (W5100 RX/TX/conn IRQ woke the WAI, or a keypress).  The caller then
; re-checks its own condition (data ready / TX space / SR).
; Out: C=1 -> a signal will act on this task (caller -> EINTR); C=0 -> ordinary
; wake (caller retries).  Preserves X/Y across the block.  MX %00.
;
; The verdict is _sleep's own carry, forwarded through _Net_KCall_Sleep
; (P4/T1-T2, 2026-08-01).  Carry survives that thunk: `JSL SYS_NETKC_SLEEP`
; lands on a bank-0 JT cell holding `JML _Net_KCall_Sleep`, which is
; `JSR _sleep / RTL` -- JML, JSR and RTL all leave P alone.  This used to peek
; the keyboard ring for a literal $03 instead, a check that can never fire once
; a shell owns the tty (the heartbeat consumes ^C as a SIGNAL and never
; enqueues the byte) and that DEQUEUED and discarded whatever key it did find.
; See _Pipe_PollIntr in pipe.s for the measured failure that retired the twin.
;
; Concurrent socket users: recv/connect/send keep cross-block scratch in the
; contiguous _sock* block (_sockSrcOff.._sockPhys).  We SAVE that block on this
; task's per-task kernel stack across the _sleep and restore it on wake, so a
; concurrent task's socket op can't clobber what we need after the block (the
; cross-block-global-state class — cf. SE_CallerBank / the _Sys_Wait fix).
; _Sys_Rd* are consumed into _sock* before the poll loop, so saving the block
; covers the dest descriptor too.  (Only the blocking path pays the cost.)
;
; _libcTmp2 IS ALSO SAVED HERE, and the block does not cover it (apple/fgx#100).
; This comment used to claim _W5_RxCopy recomputed it from _sockBufOff.  That was
; never true of all three bytes: RxCopy rebuilds only the LOW WORD and keeps the
; caller's BANK in _libcTmp2+2, which the dispatcher staged before entering the
; module.  _libcTmp2 is a shared kernel DIRECT-PAGE cell and swtch saves no DP
; scratch (sched.s), so any concurrent task's syscall overwrites the bank while
; we sleep.  A woken recv then copies arriving bytes to
; (another process's bank : the right offset), and a woken _W5_TxStream streams
; outbound bytes from it.  Saving it at THIS choke point is what makes RxCopy's
; "keep caller bank +2" true, rather than each waking path rebuilding it.
;
; The 4 bytes come off the per-task kernel stack, and only on the blocking path.
; That is the one case the kernel stack is used for here: a value that genuinely
; must survive re-entry.
;------------------------------------------------------------------------------
_Sock_PollIntr  MX      %00
                PHX
                PHY
                ; Preserve the caller's _libcTmp2 (3 bytes in 2 words, the
                ; overlapping-word trick -- _BlkCache_PinGet precedent,
                ; blkcache.s).  Pushed OUTSIDE the _sock* block so it pops last.
                LDA     _libcTmp2+1
                PHA
                LDA     _libcTmp2
                PHA
                ; Save the _sock* cross-block scratch (high word first so the
                ; forward pop lands each word back at its own offset).
                LDX     #_SOCK_SCRATCH_LEN-2
@spi_save       LDA     _sockSrcOff,X
                PHA
                DEX
                DEX
                BPL     @spi_save
                LDA     #WCHAN_SOCK
                LDX     #PRIO_NORMAL          ; pri (reserved); X restored below
                JSL     SYS_NETKC_SLEEP      ; idle until a socket sleeper wakes;
                                              ;   C=1 = a signal will act on us
                LDY     #0                    ; stash the verdict: the restore loop
                BCC     @spi_flag             ;   below needs A and X, and Y is
                LDY     #1                    ;   already saved on the stack
@spi_flag       LDX     #0                    ; restore _sock* (forward = pop order)
@spi_rest       PLA
                STA     _sockSrcOff,X
                INX
                INX
                CPX     #_SOCK_SCRATCH_LEN
                BCC     @spi_rest
                PLA                           ; restore caller's _libcTmp2; PLA
                STA     _libcTmp2             ;   touches N/Z only, and the CPY
                PLA                           ;   below re-establishes carry, so
                STA     _libcTmp2+1           ;   ordering here is free
                CPY     #1                    ; C=1 iff Y=1 -> interrupted (EINTR);
                PLY                           ;   C=0 -> caller re-checks + retries.
                PLX                           ;   PLY/PLX leave carry alone.
                RTS

;------------------------------------------------------------------------------
; _W5_SetSnAR - point the W5100 indirect AR at socket-N register (offset in A).
; Socket-N register block = $0400 + N*$0100; so AR.hi = $04 + hw, AR.lo = offset.
; In: A = register offset (lo byte); _sockTmpHw = hw idx.  MX %11 (M8/X8).
; (Moved from socket.s in Increment 2 — co-located with the W5100 driver.)
;------------------------------------------------------------------------------
_W5_SetSnAR     MX      %11
                PHA
                LDA     _sockTmpHw
                CLC
                ADC     #$04                    ; hi = $04 + hw
                STAL    U2_ARH
                PLA
                STAL    U2_ARL                  ; lo = register offset
                RTS

;------------------------------------------------------------------------------
; _W5_TxStream - stream _sockLen bytes from [_libcTmp2] (the bounce, which
; _So_TxFill fills from the caller's uio) into the socket TX ring,
; commit Sn_TX_WR, issue SEND, wait SEND_OK.  Entry MX %10 (caller wrote dest +
; holds lock).  Out: MX %00.  Uses _sockTxWr/_sockTxBase/_sockPhys scratch.
;------------------------------------------------------------------------------
_W5_TxStream    MX      %10                     ; entry M8/X16 (caller wrote dest, holds lock)
                LDA     #$24                    ; Sn_TX_WR (read current)
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockTxWr+1             ; hi (big-endian)
                LDAL    U2_DAT
                STA     _sockTxWr               ; lo
                ; phys = ($4000 + hw*$0800) + (TX_WR & $07FF)
                REP     #$20
                MX      %00
                LDA     _sockTmpHw
                AND     #$00FF
                ASL
                ASL
                ASL                             ; hw*8
                CLC
                ADC     #$0040                  ; $40 + hw*8 (hi byte)
                XBA
                AND     #$FF00                  ; TX_base
                STA     _sockTxBase
                LDA     _sockTxWr
                AND     #$07FF                  ; ringOff
                STA     _sockRingRun            ; (temp) ringOff
                CLC
                ADC     _sockTxBase
                STA     _sockPhys               ; phys = base + ringOff
                LDA     #$0800                  ; bytesToEnd = $0800 - ringOff
                SEC
                SBC     _sockRingRun
                CMP     _sockLen                ; run1 = min(len, bytesToEnd)
                BCS     @ts_run1len             ; bytesToEnd >= len -> run1 = len
                STA     _sockRingRun            ; run1 = bytesToEnd
                BRA     @ts_run1set
@ts_run1len     LDA     _sockLen
                STA     _sockRingRun
@ts_run1set     SEP     #$20
                MX      %10
                LDA     _sockPhys+1
                STAL    U2_ARH
                LDA     _sockPhys
                STAL    U2_ARL
                REP     #$10
                MX      %10
                LDY     #0
@ts_run1        CPY     _sockRingRun            ; X16: compare 16-bit
                BCS     @ts_wrap
                LDA     [_libcTmp2],Y
                STAL    U2_DAT
                INY
                BRA     @ts_run1
@ts_wrap        CPY     _sockLen                ; run1 == len -> no wrap
                BCS     @ts_strmDone
                LDA     _sockTxBase+1           ; re-point AR to ring base
                STAL    U2_ARH
                LDA     _sockTxBase
                STAL    U2_ARL
@ts_run2        CPY     _sockLen
                BCS     @ts_strmDone
                LDA     [_libcTmp2],Y
                STAL    U2_DAT
                INY
                BRA     @ts_run2
@ts_strmDone
                ; Sn_TX_WR += len
                REP     #$20
                MX      %00
                LDA     _sockTxWr
                CLC
                ADC     _sockLen
                STA     _sockTxWr
                SEP     #$20
                MX      %10
                LDA     #$24
                JSR     _W5_SetSnAR
                LDA     _sockTxWr+1
                STAL    U2_DAT
                LDA     _sockTxWr
                STAL    U2_DAT
                LDA     #$01                    ; Sn_CR
                JSR     _W5_SetSnAR
                LDA     #$20                    ; SEND
                STAL    U2_DAT
                REP     #$10
                MX      %10
                LDX     #$0000
@ts_wait        LDA     #$02                    ; Sn_IR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                AND     #$10
                BNE     @ts_sent
                DEX
                BNE     @ts_wait
@ts_sent        LDA     #$02                    ; clear Sn_IR SEND_OK (write-1)
                JSR     _W5_SetSnAR
                LDA     #$10
                STAL    U2_DAT
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _W5_RxSetup - if a datagram is queued, point the indirect AR at the RX ring
; header start; else report empty.  Entry MX %00 (caller holds lock).
; Out: C=1 + AR at header (MX %00), or C=0 (no data, MX %00).
; Leaves the RX_RD base in _sockTxWr (reused) for _W5_RxAdvance.
;------------------------------------------------------------------------------
_W5_RxSetup     MX      %00                     ; entry M16/X16 (caller holds lock)
                SEP     #$20
                MX      %10
                LDA     #$26                    ; Sn_RX_RSR
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockTmp2+1
                LDAL    U2_DAT
                STA     _sockTmp2
                REP     #$20
                MX      %00
                LDA     _sockTmp2
                BNE     @rs_have
                CLC                             ; no datagram queued
                RTS
@rs_have        SEP     #$20
                MX      %10
                LDA     #$28                    ; Sn_RX_RD
                JSR     _W5_SetSnAR
                LDAL    U2_DAT
                STA     _sockTxWr+1             ; reuse _sockTxWr for rx_rd
                LDAL    U2_DAT
                STA     _sockTxWr
                REP     #$20
                MX      %00
                LDA     _sockTmpHw
                AND     #$00FF
                ASL
                ASL
                ASL                             ; hw*8
                CLC
                ADC     #$0060                  ; $60 + hw*8 (RX base hi)
                XBA
                AND     #$FF00
                STA     _sockTxBase
                LDA     _sockTxWr
                AND     #$07FF
                CLC
                ADC     _sockTxBase
                STA     _sockPhys
                SEP     #$20
                MX      %10
                LDA     _sockPhys+1
                STAL    U2_ARH
                LDA     _sockPhys
                STAL    U2_ARL
                REP     #$30
                MX      %00
                SEC                             ; data present, AR at header
                RTS

;------------------------------------------------------------------------------
; _W5_RxCopy - caplen = min(_sockRxLen, _sockLen); copy caplen payload bytes
; from the RX ring (U2_DAT auto-inc, continuing from the header) into the
; buffer at _sockBufOff, bank in _libcTmp2+2 -- the bounce, which _So_Recv
; stages and _So_RxDrain moves into the caller's uio.  Entry MX %00
; (caller already read the header).  Out: MX %00, _sockCapLen set.
;------------------------------------------------------------------------------
_W5_RxCopy      MX      %00                     ; entry M16/X16
                LDA     _sockRxLen
                CMP     _sockLen
                BCC     @rc_cap
                LDA     _sockLen
@rc_cap         STA     _sockCapLen
                ; run1 = min(capLen, $0800 - (rx_rd & $07FF))
                LDA     _sockTxWr               ; rx_rd (set by _W5_RxSetup)
                AND     #$07FF
                STA     _sockRingRun            ; (temp) ringOff
                LDA     #$0800
                SEC
                SBC     _sockRingRun            ; bytesToEnd
                CMP     _sockCapLen
                BCS     @rc_run1len             ; bytesToEnd >= capLen -> run1 = capLen
                STA     _sockRingRun            ; run1 = bytesToEnd
                BRA     @rc_run1set
@rc_run1len     LDA     _sockCapLen
                STA     _sockRingRun
@rc_run1set     LDA     _sockBufOff
                STA     _libcTmp2               ; buf ptr lo16 (keep caller bank +2)
                REP     #$10
                MX      %10
                LDY     #0
@rc_run1        CPY     _sockRingRun
                BCS     @rc_wrap
                LDAL    U2_DAT
                STA     [_libcTmp2],Y
                INY
                BRA     @rc_run1
@rc_wrap        CPY     _sockCapLen             ; run1 == capLen -> no wrap
                BCS     @rc_done
                LDA     _sockTxBase+1           ; re-point AR to RX ring base
                STAL    U2_ARH
                LDA     _sockTxBase
                STAL    U2_ARL
@rc_run2        CPY     _sockCapLen
                BCS     @rc_done
                LDAL    U2_DAT
                STA     [_libcTmp2],Y
                INY
                BRA     @rc_run2
@rc_done        REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _W5_RxAdvance - Sn_RX_RD += _w5RxHdrLen + _sockRxLen; issue RECV.  Entry MX
; %00 (RX_RD base in _sockTxWr from _W5_RxSetup).  Out: MX %00.
;------------------------------------------------------------------------------
_W5_RxAdvance   MX      %00                     ; entry M16/X16
                LDA     _sockTxWr
                CLC
                ADC     _w5RxHdrLen
                CLC
                ADC     _sockRxLen
                STA     _sockTxWr
                SEP     #$20
                MX      %10
                LDA     #$28                    ; Sn_RX_RD
                JSR     _W5_SetSnAR
                LDA     _sockTxWr+1
                STAL    U2_DAT
                LDA     _sockTxWr
                STAL    U2_DAT
                LDA     #$01                    ; Sn_CR
                JSR     _W5_SetSnAR
                LDA     #$40                    ; RECV
                STAL    U2_DAT
                REP     #$30
                MX      %00
                RTS

