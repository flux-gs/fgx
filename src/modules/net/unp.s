;==============================================================================
; unp.s - AF_UNIX SOCK_DGRAM transport.  Lives in net.mod beside net_loop.s,
; which it is modelled on: a socket with no hardware behind it, delivering
; through pipe.s rings.  Statics half: src/kernel/unp.s.
;
; FGX-Provenance: none.  Original FGX code.  The ALGORITHM is 2.11BSD's -- the
; PRU_SEND arm quoted below, its sbspace pre-check, and the EMSGSIZE/ENOBUFS
; split -- and naming the source of an algorithm is not derivation of its text;
; none of upstream's C is carried here.  docs/PROVENANCE.md registers the C that
; IS a port, `unp_nameop' in src/kernel/vfs/vfs_syscalls.c.
;
; THE RING BELONGS TO THE BOUND SOCKET, NOT THE CONNECTION.  2.11BSD
; usr/sys/sys/uipc_usrreq.c, PRU_SEND, the SOCK_DGRAM arm:
;
;       so2 = unp->unp_conn->unp_socket;
;       if (sbspace(&so2->so_rcv) > 0 &&
;           sbappendaddr(&so2->so_rcv, from, m, rights)) {
;               sorwakeup(so2);
;               m = 0;
;       } else
;               error = ENOBUFS;
;
; The datagram is appended to the RECEIVER's receive buffer, so one ring serves
; /dev/log however many clients log into it, and a client descriptor owns no ring
; at all -- only its peer's index in SOCK_UnpPeer.  That is what keeps this
; inside NPIPE 8, the whole machine's pipe count, shared with shell pipes; a
; ring per connection would have starved it.
;
; 2.11BSD'S EXPLICIT sbspace() TEST IS WHY THE SPACE CHECK IS FIRST.  4.3BSD-Reno
; drops that clause and leans on sbappendaddr's own return, which it can afford:
; sbappendaddr totals the whole record and refuses before copying a byte.
; _Pipe_WriteAt makes no such promise -- it writes in chunks, grows the ring, and
; returns a PARTIAL count rather than failing -- so the check has to happen here,
; before the first byte goes in.  A truncated record desynchronises every
; boundary after it, and the reader cannot tell.
;
; A RECORD IS FRAMED BECAUSE pipe.s IS A BYTE STREAM.  sbappendaddr appends the
; address and the data as one record; a ring has no record concept, so the
; boundary is carried explicitly:
;
;       +0  2 B  payload length
;       +2  1 B  sender name length (0 = unnamed)
;       +3  n B  sender name, when named
;       +3+n     payload
;
; Upstream stores a FIXED-SIZE struct sockaddr here (sizeof(*asa), 16 bytes, and
; `sun_noname' for an unbound sender).  This carries a length instead, and namelen
; is 0 for every record the transport moves: a SENDER's name is scoped out, which
; bind(2) landing did not change -- a bound socket's name identifies where
; datagrams are delivered TO, not who sent one.  recvfrom fills a zero-length
; sockaddr_un from that, which is what sun_noname MEANS.  The observable answer is upstream's; 16
; constant bytes per record in a 512-byte ring, and a 16-byte staging buffer in
; the core bank, are not.
;
; THE DATA MOVES THROUGH TWO uios.  A record's payload goes through the caller's
; own (the u-area's, which _So_Send/_So_Recv hand in as _sockUio), and its
; three-byte header, a core-bank static, through pipe.s's kernel-static
; _pipeKUio.  They cannot share: the header is moved in the middle of the
; payload's call, and building it in the u-area would overwrite the caller's.
; pipe.s's calls clobber _libcTmp2, so bind and connect, which read their arg
; block through it, rebuild it with _Unp_LoadArgs after one.
;==============================================================================

                MX      %00

UNP_HDR_LEN     EQU     3               ; length(2) + namelen(1), name absent
UNP_NONAME_LEN  EQU     16              ; sizeof(struct sockaddr), 2.11BSD

; The save block's length, DERIVED from the exported addresses rather than
; hardcoded -- _PIPE_SCRATCH_LEN does the same for the same reason.  _unpBlkEnd
; is the anchor, so a cell added anywhere above it is covered by construction.
_UNP_SCRATCH_LEN EQU    _unpBlkEnd-_unpHandled

;------------------------------------------------------------------------------
; _Unp_Claim - the entry test for the bind and connect arms.
;
; Resolves _Sys_SavedX (the fd) to a descriptor and decides whether this call is
; ours.  The RTS-on-miss is the contract:
; an fd that is not a socket at all leaves _unpHandled zero so the normal path
; answers EBADF, rather than this arm inventing an answer for it.
;
; Out: C=1 -> ours, _unpDescOff set, _unpHandled = 1.
;      C=0 -> not ours, _unpHandled = 0.
; MX %00.  Clobbers A, X, Y.
;------------------------------------------------------------------------------
_Unp_Claim      MX      %00
                STZ     _unpHandled
                ; _Sys_SavedA is captured because the dispatcher rewrites it and
                ; it has no per-task save slot; _Sys_CallerBank needs no copy --
                ; the scheduler saves and restores it per task (SE_CallerBank).
                LDA     _Sys_SavedA
                STA     _unpArgBlk
                LDA     _Sys_SavedX
                AND     #$00FF
                JSR     _NlKC_SockFdToDesc      ; C=1 + Y = desc record offset
                BCC     @uc_no
                STY     _unpDescOff
                TYA
                CLC
                ADC     #SOCK_Proto
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #XPORT_UNIX
                REP     #$30
                MX      %00
                BNE     @uc_no
                LDA     #$0001
                STA     _unpHandled
                SEC
                RTS
@uc_no          CLC
                RTS

;------------------------------------------------------------------------------
; _Unp_RingFromByte - A.lo = pipe index -> _unpRingOff = pipe record offset.
;
; PIPE_REC_SZ is 16 -- include/kernel.s says it is 16 precisely so this is a
; clean ASL x4 -- which is the opposite of SOCK_REC_SIZE, where the same
; conversion must be a loop.  Two different constants, two different shapes, and
; the reason is the power of two.
;
; Out: C=1 + _unpRingOff set, or C=0 + A = ENOTCONN when the byte is the
; "no ring" sentinel.  MX %00.
;------------------------------------------------------------------------------
_Unp_RingFromByte MX    %00
                AND     #$00FF
                CMP     #SOCK_LOOP_NONE
                BEQ     @urb_none
                ASL
                ASL
                ASL
                ASL                             ; idx * PIPE_REC_SZ
                STA     _unpRingOff
                SEC
                RTS
@urb_none       LDA     #ENOTCONN
                CLC
                RTS

;------------------------------------------------------------------------------
; _Unp_RingFree - A = free bytes in the ring at _unpRingOff.  MX %00.
;
; free = PIPE_BufSz - PIPE_Count, which is the one dimension an FGX ring has:
; upstream's sbspace is a MIN of a byte budget and an mbuf budget, and there are
; no mbufs here, so the min collapses to a subtraction.  Both fields are read
; through [_pipeTablePtr],Y and PIPE_Count sits two bytes below PIPE_BufSz, so
; the whole thing is one DEY pair and an SBC with no scratch cell borrowed.
;------------------------------------------------------------------------------
_Unp_RingFree   MX      %00
                LDA     _unpRingOff
                CLC
                ADC     #PIPE_BufSz
                TAY
                LDA     [_pipeTablePtr],Y       ; the ring's current size
                DEY
                DEY                             ; PIPE_BufSz - 2 == PIPE_Count
                SEC
                SBC     [_pipeTablePtr],Y       ; ... minus the bytes resident
                RTS

;------------------------------------------------------------------------------
; _Unp_StageBank - _pipeBufBank = the LIVE kernel bank, for a copy whose source
; is a core-bank static (_unpHdr).
;
; Read from DBR rather than baked: the module bodies run with DBR = the live
; kernel bank, which is $20 relocated and $02 at the assembly ORG, and baking
; either one is the defect class tools/check_baked_addrs.py exists to stop.
; MX %00 in/out.  Clobbers A.
;------------------------------------------------------------------------------
_Unp_StageBank  MX      %00
                PHB
                SEP     #$20
                MX      %10
                PLA                             ; A.lo = DBR
                STA     _pipeBufBank
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Unp_StatusTry - the XPORT_UNIX arm of net_op_loopstatus: select(2) readiness.
;
; In:  Y = descriptor record offset, which the kernel staged in _sockTmpOff
;      before the thunk (net.s says why the thunk destroys the register).
; Out: _unpHandled = 0 -> not ours; the loopback arm answers next.
;      _unpHandled = 1 -> the op's OUT cells carry the answer: _loopHandled = 1,
;      _loopBits = b0 read / b1 write / b2 except, _loopRxLen = FIONREAD's count.
; MX %00.  Clobbers A, X, Y.
;
; NOT `_Unp_Claim'.  That resolves _Sys_SavedX, the fd of a socket CALL, and
; select is not one: it arrives with the descriptor already resolved, in Y,
; exactly as _Loop_StatusTry does.  The claim test itself is the same single
; SOCK_Proto compare.
;
; THE PREDICATES ARE UPSTREAM'S, AND THE WRITABLE ONE IS NOT WHAT IT LOOKS LIKE.
; `soo_select' answers FREAD with `soreadable(so)' and FWRITE with
; `sowriteable(so)' (vendor/2.11BSD/usr/sys/sys/sys_socket.c), which
; usr/sys/h/socketvar.h:105-115 spells out:
;
;     #define soreadable(so) \
;         ((so)->so_rcv.sb_cc || ((so)->so_state & SS_CANTRCVMORE) || \
;          (so)->so_qlen || (so)->so_error)
;     #define sowriteable(so) \
;         (sbspace(&(so)->so_snd) > 0 && \
;          (((so)->so_state&SS_ISCONNECTED) || \
;           ((so)->so_proto->pr_flags&PR_CONNREQUIRED)==0) || ...
;
; ALWAYS WRITABLE, and that is faithfulness rather than a shortcut.  The local
; domain's SOCK_DGRAM protosw entry is `PR_ATOMIC|PR_ADDR|PR_RIGHTS'
; (usr/sys/sys/uipc_proto.c:35) and carries NO PR_CONNREQUIRED, so the connected
; clause is vacuous for this transport: a datagram socket is writable whether or
; not it ever connected.  Its so_snd is never filled either -- uipc_usrreq's
; PRU_SEND appends the datagram to the PEER's so_rcv -- so sbspace(so_snd) is the
; whole send buffer and the space test cannot fail.
;
; The roadmap asked for "writable when the reader is present and the ring is not
; full".  That is the loopback STREAM contract, and porting it one transport over
; would answer not-writable for an unconnected sender that upstream calls
; writable.  Read the protosw entry, not the neighbour.
;
; READABLE REDUCES TO sb_cc, the bytes resident in MY receive ring: so_qlen is a
; listen queue and a datagram socket has none, so_error is not tracked on this
; transport, and SS_CANTRCVMORE reaches a datagram socket only through
; shutdown(SHUT_RD), for which there is no arm here.  A client that never bound
; owns no ring and is not readable -- _Unp_RingFromByte refuses SOCK_LOOP_NONE,
; which is that same answer and needs no test of its own.
;------------------------------------------------------------------------------
_Unp_StatusTry  MX      %00
                STZ     _unpHandled
                STY     _unpDescOff
                TYA
                CLC
                ADC     #SOCK_Proto
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #XPORT_UNIX
                REP     #$30
                MX      %00
                BEQ     @ust_mine
                RTS                             ; not ours: loopback answers next
@ust_mine       LDA     #$0001
                STA     _unpHandled
                STA     _loopHandled            ; the op's OUT flag, either arm
                LDA     #$0002                  ; writable, always -- see above
                STA     _loopBits
                STZ     _loopRxLen
                LDA     _unpDescOff
                CLC
                ADC     #SOCK_UnpRx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y       ; A.lo = my receive pipe index
                REP     #$30
                MX      %00
                JSR     _Unp_RingFromByte       ; masks A.lo itself; C=0 = unbound
                BCC     @ust_done
                LDA     _unpRingOff
                CLC
                ADC     #PIPE_Count
                TAY
                LDA     [_pipeTablePtr],Y       ; sb_cc, and FIONREAD's answer
                STA     _loopRxLen
                BEQ     @ust_done
                LDA     _loopBits
                ORA     #$0001                  ; readable
                STA     _loopBits
@ust_done       RTS

;------------------------------------------------------------------------------
; _Unp_Send - sosend for an AF_UNIX datagram socket: one record, whole or not at
; all, into the connected peer's receive ring.
;
; In:  _sockTmpOff = the descriptor; _sockUio = the caller's uio;
;      _sockSendFlags.  _So_Send (net.s) routes here, sendto excluded: an
;      AF_UNIX socket here is connected once and sends to the ring connect found.
; Out: A = the PAYLOAD count + C=1 -- what send(2) promises -- or A = errno + C=0.
; MX %00.
;------------------------------------------------------------------------------
_Unp_Send       MX      %00
                JSR     _Unp_Take               ; descriptor + uio into the block
                ; peer descriptor index -> _unpPeerOff
                LDA     _unpDescOff
                CLC
                ADC     #SOCK_UnpPeer
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                AND     #$00FF
                CMP     #SOCK_LOOP_NONE
                BNE     @us_havePeer
                LDA     #ENOTCONN
                CLC
                RTS
@us_havePeer    JSR     _Loop_IdxToOff          ; descriptor idx -> record offset
                STA     _unpPeerOff
                LDA     _unpPeerOff
                CLC
                ADC     #SOCK_UnpRx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                JSR     _Unp_RingFromByte       ; C=0 + ENOTCONN if peer unbound
                BCS     @us_haveRing
                RTS
@us_haveRing    LDA     _sockSendFlags
                AND     #MSG_OOB
                BEQ     @us_noOob
                LDA     #ENOTSUP
                CLC
                RTS
@us_noOob       JSR     _Unp_UioResid           ; the payload is the uio's resid
                STA     _unpPayLen
                ; need = UNP_HDR_LEN + payload, and the test is against NEED
                CLC
                ADC     #UNP_HDR_LEN
                BCS     @us_emsgsize
                STA     _unpNeed
                CMP     #PIPE_MAX_BUFSZ+1
                BCC     @us_sizeOk
@us_emsgsize    LDA     #EMSGSIZE
                CLC
                RTS
@us_sizeOk      ; Grow until the whole record fits, or refuse.  The ring write
@us_growL       JSR     _Unp_RingFree           ;   below never sleeps, so the
                CMP     _unpNeed                ;   space has to be proven here.
                BCS     @us_haveSpace
                LDA     _unpRingOff
                STA     _pipeRecOff             ; _Pipe_TryGrow reads this
                JSR     _Pipe_TryGrow
                BCS     @us_growL
                LDA     #ENOBUFS
                CLC
                RTS
@us_haveSpace   ; Header: payload length, then a zero namelen.
                LDA     _unpPayLen
                STA     _unpHdr
                SEP     #$20
                MX      %10
                LDA     #$00
                STA     _unpHdr+2               ; namelen: nothing binds yet
                REP     #$30
                MX      %00
                LDA     _unpRingOff
                STA     _pipeRecOff
                LDA     #UNP_HDR_LEN
                STA     _pipeReqLen
                LDA     #_unpHdr
                STA     _pipeBufOff
                JSR     _Unp_StageBank          ; source is a core-bank static
                LDA     #$0001
                STA     _pipeNonBlk             ; space is proven; must not block
                JSR     _Pipe_WriteAt           ; the buffer form: _pipeKUio
                BCC     @us_wrFail
                CMP     #UNP_HDR_LEN            ; a SHORT write is not a success
                BNE     @us_short
                ; Payload: the caller's own uio.
                JSR     _Unp_UseUio
                LDA     #$0001
                STA     _pipeNonBlk
                JSR     _Pipe_WriteUio
                BCC     @us_wrFail
                CMP     _unpPayLen
                BNE     @us_short
                STZ     _pipeNonBlk             ; leave the shared flag as the fd
                LDA     _unpPayLen              ; send(2) reports the PAYLOAD
                SEC
                RTS
@us_short       STZ     _pipeNonBlk
                LDA     #ENOBUFS
                CLC
                RTS
@us_wrFail      STZ     _pipeNonBlk
                CLC                             ; A already holds the errno
                RTS

;------------------------------------------------------------------------------
; _Unp_Recv - soreceive for an AF_UNIX datagram socket.
;
; In:  _sockTmpOff; _sockUio; _sockRecvFlags; _sockSrcOff = where recvfrom
;      wants the source address, 0 for none.
; Out: A = bytes delivered + C=1, or A = errno + C=0.  MX %00.
;
; THIS ROUTINE OWNS ITS BLOCKING, and every ring read runs non-blocking.  pipe.s
; would sleep inside the read, and every cell this routine works in is a
; core-bank GLOBAL, so the wait is hoisted to one place -- @ur_wait, which peeks
; PIPE_Count with no kernel call -- and the _unp* block, which holds the uio and
; the source-address offset too, is saved across the sleep there and nowhere
; else.  Once Count is non-zero a whole record is resident, by the send side's
; all-or-nothing guarantee, so no read can then block or short-read.
;
; TRUNCATION IS soreceive's: a record longer than the caller's uio delivers what
; fits and the rest is dropped (sbdroprecord for a PR_ATOMIC protocol,
; uipc_socket.c), so the next read starts at the next record's header.
;
; THE SOURCE ADDRESS, when asked for: every sender here is unnamed (see the file
; header), and upstream attaches the same address to every such datagram --
; `struct sockaddr sun_noname = { AF_UNIX }' (2.11BSD uipc_usrreq.c:30, handed
; to sbappendaddr at :172) -- a 16-byte sockaddr, the family and then zeros.  It
; is written at _sockSrcOff in the caller's bank, which is libc's staging, and
; libc copies what the caller asked for.
;------------------------------------------------------------------------------
_Unp_Recv       MX      %00
                JSR     _Unp_Take
                LDA     _sockSrcOff
                STA     _unpFrom
                ; MY OWN receive ring -- a client that never bound has none
                LDA     _unpDescOff
                CLC
                ADC     #SOCK_UnpRx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                JSR     _Unp_RingFromByte
                BCS     @ur_haveRing
                RTS
@ur_haveRing    LDA     _sockRecvFlags
                AND     #MSG_OOB
                BEQ     @ur_noOob
                LDA     #ENOTSUP
                CLC
                RTS
@ur_noOob       ; --- 0: wait until a whole record is resident ---
                STZ     _unpNeed                ; borrow: 1 = do not sleep
                LDA     _sockRecvFlags
                AND     #MSG_DONTWAIT
                BEQ     @ur_ckSockNb
                LDA     #$0001
                STA     _unpNeed
@ur_ckSockNb    LDA     _unpDescOff
                CLC
                ADC     #SOCK_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                AND     #SOCK_NB
                REP     #$30
                MX      %00
                BEQ     @ur_wait
                LDA     #$0001
                STA     _unpNeed
@ur_wait        LDA     _unpRingOff
                CLC
                ADC     #PIPE_Count
                TAY
                LDA     [_pipeTablePtr],Y
                BNE     @ur_haveData
                LDA     _unpNeed
                BEQ     @ur_sleep
                LDA     #EAGAIN
                CLC
                RTS
@ur_sleep       JSR     _Unp_SaveBlk            ; the _unp* globals, onto the
                JSR     _Pipe_PollIntr          ;   task's stack across the sleep
                PHP
                JSR     _Unp_RestBlk
                PLP
                BCC     @ur_wait
                LDA     #EINTR
                CLC
                RTS
@ur_haveData    ; --- 1: the header.  Cannot block: Count > 0. ---
                LDA     _unpRingOff
                STA     _pipeRecOff
                LDA     #UNP_HDR_LEN
                STA     _pipeReqLen
                LDA     #_unpHdr
                STA     _pipeBufOff
                JSR     _Unp_StageBank
                LDA     #$0001
                STA     _pipeNonBlk
                JSR     _Pipe_ReadAt            ; the buffer form: _pipeKUio
                BCS     @ur_hdrRead
                BRL     @ur_rdFail
@ur_hdrRead     CMP     #UNP_HDR_LEN
                BEQ     @ur_hdrOk
                STZ     _pipeNonBlk
                LDA     #EIO
                CLC
                RTS
@ur_hdrOk       LDA     _unpHdr
                STA     _unpPayLen
                SEP     #$20
                MX      %10
                LDA     _unpHdr+2               ; namelen
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @ur_noName
                STZ     _pipeNonBlk
                LDA     #EIO
                CLC
                RTS
@ur_noName      ; --- 2: the payload, up to the caller's uio ---
                STZ     _unpGot
                LDA     _unpPayLen
                BEQ     @ur_done
                JSR     _Unp_UioResid           ; copy = min(payload, resid): the
                CMP     _unpPayLen              ;   ring holds the NEXT record's
                BCC     @ur_copyLen             ;   header right after this one
                LDA     _unpPayLen
@ur_copyLen     STA     _pipeReqLen
                JSR     _Unp_UseUio
                LDA     #$0001
                STA     _pipeNonBlk
                JSR     _Pipe_ReadCapped
                BCS     @ur_payRead
                BRL     @ur_rdFail
@ur_payRead     STA     _unpGot
                LDA     _unpPayLen
                SEC
                SBC     _unpGot
                BEQ     @ur_done
                JSR     _Unp_Discard            ; the rest of THIS record
@ur_done        STZ     _pipeNonBlk
                LDA     _unpFrom                ; recvfrom: the source address
                BEQ     @ur_noFrom
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                LDA     #AF_UNIX                ; sa_family, a 2-byte short
                LDY     #0
@ur_fill        STA     [_libcTmp2],Y
                LDA     #0                      ; then sa_data, all zero
                INY
                INY
                CPY     #UNP_NONAME_LEN
                BCC     @ur_fill
@ur_noFrom      LDA     _unpGot
                SEC
                RTS
@ur_rdFail      STZ     _pipeNonBlk
                CLC
                RTS

;------------------------------------------------------------------------------
; _Unp_Take - _unpDescOff = _sockTmpOff and _unpUio = _sockUio: into the block
; _Unp_SaveBlk parks across the receive wait.  MX %00.
; _Unp_UseUio - point the ring at the caller's uio (_pipeUio = _unpUio).
; _Unp_UioResid - A = the caller uio's uio_resid.
;------------------------------------------------------------------------------
_Unp_Take       MX      %00
                LDA     _sockTmpOff
                STA     _unpDescOff
                LDA     _sockUio
                STA     _unpUio
                LDA     _sockUioBank
                STA     _unpUioBank
                STZ     _unpFrom
                RTS

_Unp_UseUio     MX      %00
                LDA     _unpRingOff
                STA     _pipeRecOff
                LDA     _unpUio
                STA     _pipeUio
                LDA     _unpUioBank
                STA     _pipeUioBank
                RTS

_Unp_UioResid   MX      %00
                LDA     _unpUio
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _unpUioBank
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                LDY     #UIO_RESID
                LDA     [_libcTmp2],Y
                RTS

;------------------------------------------------------------------------------
; _Unp_LoadArgs - _libcTmp2 = _Sys_CallerBank : _unpArgBlk, for bind and
; connect's arg block.  MX %00.
;------------------------------------------------------------------------------
_Unp_LoadArgs   MX      %00
                LDA     _unpArgBlk
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Unp_SaveBlk / _Unp_RestBlk - the _unp* block onto and off this task's kernel
; stack, across a sleep.  High word pushed first so the forward pop lands each
; word back at its own offset, which is _Pipe_PollIntr's shape exactly.
; Clobbers A, X.  MX %00.  The two must bracket one sleep and nothing else.
;------------------------------------------------------------------------------
_Unp_SaveBlk    MX      %00
                LDX     #_UNP_SCRATCH_LEN-2
@usb_L          LDA     _unpHandled,X
                PHA
                DEX
                DEX
                BPL     @usb_L
                RTS

_Unp_RestBlk    MX      %00
                LDX     #0
@urb_L          PLA
                STA     _unpHandled,X
                INX
                INX
                CPX     #_UNP_SCRATCH_LEN
                BCC     @urb_L
                RTS

;------------------------------------------------------------------------------
; _Unp_Discard - drop A bytes from the front of the ring at _unpRingOff.
;
; Advances PIPE_Head (wrapping at PIPE_BufSz) and decreases PIPE_Count, which is
; what _Pipe_CopyOut does after a copy.  The cursors are touched directly rather
; than by reading into a throwaway buffer, because the alternative is a loop of up
; to PIPE_MAX_BUFSZ/4 iterations for the same O(1) effect; _Loop_StatusTry already
; reads PIPE_Count and PIPE_BufSz this way, and this routine makes no kernel call,
; so nothing can interleave between its reads and its writes.
;
; It borrows NO statics and needs no scratch cell: the 65816 has SBC, ADC and CMP
; in [dp],Y, which pipe.s already uses for LDA and STA, so the ring's own fields
; are read in place and X carries the value between the two cursor addresses.
;
; In: A = byte count, 0 < A <= PIPE_Count.  MX %00.  Clobbers A, X, Y.
;------------------------------------------------------------------------------
_Unp_Discard    MX      %00
                TAX                             ; X = the drop count
                ; Count -= drop, in place: A = ~drop, then ADC the memory with
                ; carry set gives Count + ~drop + 1 == Count - drop.
                LDA     _unpRingOff
                CLC
                ADC     #PIPE_Count
                TAY
                TXA
                EOR     #$FFFF
                SEC
                ADC     [_pipeTablePtr],Y
                STA     [_pipeTablePtr],Y
                ; Head = (Head + drop) mod BufSz.  X carries the value between the
                ; two cursor addresses so no scratch cell is needed.
                LDA     _unpRingOff
                CLC
                ADC     #PIPE_Head
                TAY
                TXA
                CLC
                ADC     [_pipeTablePtr],Y       ; Head + drop
                TAX
                LDA     _unpRingOff
                CLC
                ADC     #PIPE_BufSz
                TAY
                TXA
                CMP     [_pipeTablePtr],Y
                BCC     @ud_store               ; no wrap; CMP sets C when equal,
                SEC                             ;   so Head+drop == BufSz wraps to 0
                SBC     [_pipeTablePtr],Y
@ud_store       TAX
                LDA     _unpRingOff
                CLC
                ADC     #PIPE_Head
                TAY
                TXA
                STA     [_pipeTablePtr],Y
                RTS

;------------------------------------------------------------------------------
; _Unp_CloseTry - the XPORT_UNIX arm of net_op_sockteardown: free the receive
; ring when a bound AF_UNIX descriptor is closed.
;
; Nothing else does.  _Loop_CloseTry claims a socket only when SOCK_HwIdx is
; SOCK_HW_LOOP and an AF_UNIX descriptor carries SOCK_HW_NONE, so it declines;
; net_op_sockteardown then takes its `CMP #W5_NSOCK / BCS' arm and frees the
; DESCRIPTOR alone.  Without this the ring leaks for the life of the boot, and
; NPIPE is 8 and shared with shell pipes -- eight of these and pipe(2) stops
; working machine-wide.
;
; THE NAME IS NOT UNLINKED, which is upstream's behaviour and the reason syslogd
; does `(void) unlink(LogName)' before it binds.
;
; In: Y = the descriptor's record offset.  MX %00.  Out: nothing; always returns.
;------------------------------------------------------------------------------
_Unp_CloseTry   MX      %00
                STY     _unpDescOff
                TYA
                CLC
                ADC     #SOCK_Proto
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #XPORT_UNIX
                REP     #$30
                MX      %00
                BEQ     @uc_ours
                RTS                             ; not an AF_UNIX descriptor
@uc_ours        ; THE NAME GOES BEFORE THE RING, which is unp_detach's own order
                ; (4.3BSD-Reno kern/uipc_usrreq.c: the vnode first, then the
                ; connection).  UNP_OP_UNBIND clears the slot the bind left in
                ; the node's `v_un' and drops the vnode reference the bind kept;
                ; without it the name kept naming this descriptor, and the next
                ; socket to be handed the same slot inherited every stale name
                ; pointing at it.
                ;
                ; UNCONDITIONAL, not gated on this descriptor owning a ring: the
                ; far side answers 0 for a slot holding no vnode, so an unbound
                ; client end costs one call and a bind that got its node but not
                ; its ring is still cleaned up.  The errno is ignored because a
                ; close cannot refuse.
                ;
                ; It can SLEEP -- vrele reaches VOP_INACTIVE -- and that is safe
                ; on this path: _Fcb_Free, a few instructions later in the same
                ; close, already ends in vn_close for a vnode descriptor
                ; (src/drivers/fs/fs.s).  _Unp_NameCall parks _unpDescOff across
                ; the call, which is what the reload below depends on.
                LDA     _unpDescOff
                JSR     _Loop_OffToIdx
                STA     _unpSlot
                LDA     #$0000                  ; no sockaddr: UNBIND has no path
                LDX     #UNP_OP_UNBIND
                JSR     _Unp_NameCall
                LDA     _unpDescOff
                CLC
                ADC     #SOCK_UnpRx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                AND     #$00FF
                CMP     #SOCK_LOOP_NONE
                BEQ     @uc_noRing              ; a client end owns none
                JSR     _Unp_RingFromByte
                BCC     @uc_noRing
                LDA     _unpRingOff
                STA     _pipeRecOff
                JSR     _Pipe_FreeSlot          ; Kfree the ring, mark it free
                LDA     _unpDescOff
                CLC
                ADC     #SOCK_UnpRx
                TAY
                SEP     #$20
                MX      %10
                LDA     #SOCK_LOOP_NONE
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
@uc_noRing      RTS

;------------------------------------------------------------------------------
; _Unp_NameCall - stage and make the KSVC_UNPNAME call.
;
; In:  A = the sockaddr's offset in the caller's bank, X = UNP_OP_*,
;      _unpSlot = the descriptor slot for a bind (ignored for a lookup).
; Out: C=1 + _unpSlot = the slot a lookup found; or C=0 + A = errno.
; MX %00.
;
; IT PRESERVES _unpHandled AND _unpDescOff ACROSS THE CALL, because namei can
; sleep on disk I/O and every one of these cells is a core-bank global -- another
; task's _Unp_Claim would zero the flag and rewrite the descriptor offset, exactly
; as it would across a blocking recv.  _unpSlot is deliberately NOT saved: it is
; the OUT parameter, and restoring it would throw the answer away.
;------------------------------------------------------------------------------
_Unp_NameCall   MX      %00
                STX     _unpNameOp              ; the op, where the arm reads it
                ; &sun_path, NOT &sockaddr: the path begins at SIN_PORT, which is
                ; offset 2, sa_family being the two bytes before it exactly as
                ; sockaddr_un lays out sun_path.  The add happens HERE rather than
                ; in the KSVC arm because it costs the same two bytes on either
                ; side of the seam and this module has room where the core kernel
                ; bank has none.  Harmless on an UNBIND, which passes no address
                ; and whose arm never reads A.
                CLC
                ADC     #SIN_PORT
                PHA                             ; the sockaddr offset
                LDA     _unpHandled
                PHA
                LDA     _unpDescOff
                PHA
                ; _sockTmpOff IS PARKED TOO, AND IT IS NOT THIS TRANSPORT'S CELL.
                ; net_op_sockteardown holds the descriptor offset there, calls
                ; _Unp_CloseTry, and RE-READS the cell afterwards to clear
                ; SOCK_InUse -- so once UNP_OP_UNBIND made that call sleep
                ; (vrele reaches VOP_INACTIVE), another task's socket syscall
                ; could land between the two reads and the teardown would clear
                ; InUse on a LIVE descriptor belonging to someone else, leaking
                ; its own.  Roughly sixteen sites write the cell.  It is parked
                ; HERE rather than around the call site because this is where the
                ; sleep is, which is the discipline _Pipe_PollIntr set for the
                ; _pipe* scratch and the reason the two cells above are parked.
                LDA     _sockTmpOff
                PHA
                LDA     7,S                     ; the sockaddr offset again
                LDX     #KSVC_UNPNAME
                JSL     SYS_KCALL               ; A = 0 or errno
                TAY                             ; park it: the pops need A
                PLA
                STA     _sockTmpOff
                PLA
                STA     _unpDescOff
                PLA
                STA     _unpHandled
                PLA                             ; drop the saved offset
                ; THE VERDICT IS THE ERRNO AND NOT THE CARRY.  Restoring the
                ; globals takes six instructions that each touch the flags, so a
                ; carry carried across them would have to be pushed -- and a PHP
                ; pushes one byte where a 16-bit PLY pulls two, which is how the
                ; first cut of this desynchronised the stack.  0 means success.
                CPY     #$0000
                BNE     @unc_err
                SEC
                RTS
@unc_err        TYA
                CLC
                RTS

;------------------------------------------------------------------------------
; _Unp_BindTry - the XPORT_UNIX arm of net_op_bind.  4.3BSD-Reno's unp_bind.
;
; In:  _Sys_SavedA = caller-bank offset of the sockaddr, _Sys_SavedX = fd.
; Out: _unpHandled = 0 -> not ours; 1 -> A + C are the call's result.
;      A = 0 + C=1 on success.
; MX %00.
;
; The receive ring is allocated HERE and not at socket() time, because only a
; BOUND socket has one: a client holds its peer's index and no ring at all.
;------------------------------------------------------------------------------
_Unp_BindTry    MX      %00
                JSR     _Unp_Claim
                BCS     @ub_mine
                RTS
@ub_mine        ; already bound?  upstream: "if (unp->unp_vnode != NULL) EINVAL"
                LDA     _unpDescOff
                CLC
                ADC     #SOCK_UnpRx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                AND     #$00FF
                CMP     #SOCK_LOOP_NONE
                BEQ     @ub_notBound
                LDA     #EINVAL
                CLC
                RTS
@ub_notBound    JSR     _Unp_CheckFamily
                BCS     @ub_famOk
                RTS
@ub_famOk       ; The ring first: a name that exists with no ring behind it would
                ; answer ECONNREFUSED to every connect, and unbinding on the way
                ; out of a failed ring alloc means unlinking a node this did not
                ; create.  Allocate, then name; free the ring if naming fails.
                JSR     _Pipe_Alloc             ; C=1 + _pipeAllocIdx / C=0 + A
                BCS     @ub_ringOk
                CLC
                RTS
@ub_ringOk      LDA     _pipeAllocIdx
                STA     _unpSlot                ; borrow, before the real slot
                LDA     _unpDescOff
                CLC
                ADC     #SOCK_UnpRx
                TAY
                LDA     _unpSlot
                SEP     #$20
                MX      %10
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                ; the slot the NAME records is this descriptor's index
                LDA     _unpDescOff
                JSR     _Loop_OffToIdx
                STA     _unpSlot
                LDA     _unpArgBlk
                LDX     #UNP_OP_BIND
                JSR     _Unp_NameCall
                BCS     @ub_named
                ; naming failed: give the ring back rather than leak it
                PHA                             ; the errno
                LDA     _unpDescOff
                CLC
                ADC     #SOCK_UnpRx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                JSR     _Unp_RingFromByte
                BCC     @ub_noRing
                LDA     _unpRingOff
                STA     _pipeRecOff
                JSR     _Pipe_FreeSlot
                LDA     _unpDescOff
                CLC
                ADC     #SOCK_UnpRx
                TAY
                SEP     #$20
                MX      %10
                LDA     #SOCK_LOOP_NONE
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
@ub_noRing      PLA
                CLC
                RTS
@ub_named       LDA     #$0000
                SEC
                RTS

;------------------------------------------------------------------------------
; _Unp_ConnectTry - the XPORT_UNIX arm of net_op_connect.  4.3BSD-Reno's
; unp_connect: the name is looked up, its type and write permission checked, and
; the socket behind it becomes this descriptor's peer.
;
; In:  _Sys_SavedA = caller-bank offset of the sockaddr, _Sys_SavedX = fd.
; Out: _unpHandled = 0 -> not ours; 1 -> A + C are the call's result.
;      A = 0 + C=1 on success.
; MX %00.
;------------------------------------------------------------------------------
_Unp_ConnectTry MX      %00
                JSR     _Unp_Claim
                BCS     @ucn_mine
                RTS
@ucn_mine       JSR     _Unp_CheckFamily
                BCS     @ucn_famOk
                RTS
@ucn_famOk      LDA     _unpArgBlk
                LDX     #UNP_OP_LOOKUP
                JSR     _Unp_NameCall           ; -> _unpSlot = the peer's index
                BCS     @ucn_found
                RTS
@ucn_found      ; THE SLOT MUST STILL NAME A LIVE AF_UNIX SOCKET.  The node
                ; carries a descriptor INDEX, and an index proves nothing by
                ; itself: a name whose socket has closed, or one left by an
                ; earlier boot, resolves to a slot that is now free or has been
                ; handed to a different transport.  Upstream tests the socket it
                ; found rather than the name -- 4.3BSD-Reno kern/uipc_usrreq.c's
                ; unp_connect answers ECONNREFUSED for `vp->v_socket == 0' and
                ; EPROTOTYPE for `so->so_type != so2->so_type' -- so the two
                ; conditions are separated here the same way: a free slot is a
                ; refused connection, a live slot of the wrong transport is the
                ; wrong type.
                ;
                ; Without this a stale name delivered datagrams into whichever
                ; socket happened to hold the slot.
                LDA     _unpSlot
                JSR     _Loop_IdxToOff          ; clobbers X
                STA     _unpPeerOff
                TAY                             ; SOCK_InUse is offset 0
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @ucn_gone               ; slot free: the socket is gone
                LDA     _unpPeerOff
                CLC
                ADC     #SOCK_Proto
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #XPORT_UNIX
                REP     #$30
                MX      %00
                BNE     @ucn_badType
                LDA     _unpDescOff
                CLC
                ADC     #SOCK_UnpPeer
                TAY
                LDA     _unpSlot
                SEP     #$20
                MX      %10
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     #$0000
                SEC
                RTS
@ucn_gone       LDA     #ECONNREFUSED
                CLC
                RTS
@ucn_badType    LDA     #EPROTOTYPE
                CLC
                RTS

;------------------------------------------------------------------------------
; _Unp_CheckFamily - the sockaddr's family must be AF_UNIX.
; Out: C=1 ok, or C=0 + A = EAFNOSUPPORT.  MX %00.
;------------------------------------------------------------------------------
_Unp_CheckFamily MX     %00
                JSR     _Unp_LoadArgs
                LDY     #SIN_FAMILY
                LDA     [_libcTmp2],Y
                AND     #$00FF
                CMP     #AF_UNIX
                BEQ     @ucf_ok
                LDA     #EAFNOSUPPORT
                CLC
                RTS
@ucf_ok         SEC
                RTS
