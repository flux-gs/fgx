;==============================================================================
; net_loop.s - 127.0.0.1 loopback socket transport.  MOVED INTO net.mod
; 2026-08-11 (was src/kernel/net_loop.s), together with pipe.s -- the pair move
; together because this file calls four _Pipe_* routines, and moving either
; alone would mean temporary gateway shims that the second move deletes.
;
; Bodies are UNCHANGED except for the kernel-call target names (see the shim
; block at the head of this file).  They run at DBR = kernel bank, so every
; DBR-relative read of the _loop* / _sock* statics -- which STAYED in the core
; bank -- is byte-identical to the in-kernel code.
;
; The statics stayed because syscall.s and fs.s write them directly AND because
; they are how arguments reach these routines: _Net_Dispatch clobbers A on the
; way in, so nothing may be passed in a register.
;==============================================================================


;==============================================================================
; Kernel callbacks for the moved net_loop.s + pipe.s bodies.
;
; Three routes, and which one a call takes is not a style choice:
;   - SYS_NETKC_* : bank-0 JT slots that already existed for net.mod;
;   - SYS_KCALL   : the multiplexed service slot, X = service number;
;   - nothing     : Kmalloc/Kern_LogStr/_Halt/_SoftGlob_ValidatePtr were only
;                   ever called from _AllocPipeTable, which STAYED in the core
;                   bank -- so they are not here at all.
;
; Each shim keeps the caller's register contract exactly as the in-kernel JSR
; did, so the bodies below changed only in the call target's NAME.
;==============================================================================
_NlKC_SockFdToDesc MX %00                       ; A = fd
                JSL     SYS_NETKC_SOCKFDTODESC
                RTS
_NlKC_FcbAlloc  MX      %00
                JSL     SYS_NETKC_FCBALLOC
                RTS
_NlKC_ConPollKey MX     %00
                JSL     SYS_NETKC_CONPOLLKEY
                RTS
_NlKC_Sleep     MX      %00                     ; A = chan
                JSL     SYS_NETKC_SLEEP         ; net.mod has its own slot for
                RTS                             ;   this one already
_NlKC_Wakeup    MX      %00                     ; A = chan
                LDX     #KSVC_WAKEUP
                JSL     SYS_KCALL
                RTS
_NlKC_Kmalloc   MX      %00                     ; A = bytes, X = M_* type
                TXY                             ; KSVC takes the type in Y
                LDX     #KSVC_KMALLOC
                JSL     SYS_KCALL
                RTS
; Pointer staged in _kmallocResult, the way Kmalloc RETURNS one -- which is what
; both call sites here already do, and neither ever loaded A/Y.  The header said
; "A = offset, Y = bank" and the thunk forwarded whatever the caller happened to
; leave in them; @kc_free then wrote those over the correctly staged value.  In
; _Pipe_FreeSlot that meant A = the real bank byte with a stale B above it and
; Y = the pipe record's field offset, so Kfree was handed $05:F141 -- a bank
; taken from a struct offset -- on every pipe close.  apple/fgx#113.
_NlKC_Kfree     MX      %00
                LDA     _kmallocResult+2
                AND     #$00FF                  ; bank byte only
                TAY                             ; KSVC takes the bank in Y...
                LDA     _kmallocResult          ; ...and the offset in A
                LDX     #KSVC_KFREE
                JSL     SYS_KCALL
                RTS
_NlKC_TaskLookup MX     %00                     ; A = pid -> C=1 + X = TCB off
                LDX     #KSVC_TASKLOOKUP
                JSL     SYS_KCALL
                RTS
; The two FCB helpers want M=8 and are CALLED at M=8 in the bodies below.  The
; gateway runs at %00, so widen here and narrow back -- the kernel arm sets M=8
; again for the callee.  Doing it here keeps every body byte-identical.
_NlKC_FcbFree   MX      %10                     ; A.lo = fd
                REP     #$30
                MX      %00
                AND     #$00FF
                LDX     #KSVC_FCBFREE
                JSL     SYS_KCALL
                SEP     #$20
                MX      %10
                RTS
_NlKC_FcbLookupPtr MX   %10                     ; A.lo = fd
                REP     #$30
                MX      %00
                AND     #$00FF
                LDX     #KSVC_FCBLOOKUPPTR
                JSL     SYS_KCALL
                SEP     #$20
                MX      %10
                RTS
_NlKC_SigRaise  MX      %00                     ; A = signum
                LDX     #KSVC_SIGRAISE
                JSL     SYS_KCALL
                RTS

;==============================================================================
; net_loop.s - loopback (127.0.0.1) transport.  KERNEL-RESIDENT, on purpose.
;
; A loopback connection is two pipe.s rings — one per direction — with no
; hardware socket behind it.  It costs a socket DESCRIPTOR but none of the four
; W5100 hw sockets, so `telnet 127.0.0.1` -> local telnetd fits inside
; SOCKD_MAX without contending with /dev/bpf0's socket 0 or a DHCP lease.
;
; WHY HERE AND NOT IN net.mod.  The obvious home looks like net_xport.s, beside
; the W5100 cores at the _Net_Xport_* seam — that is what this campaign's plan
; said twice.  It is wrong: net_xport.s lives INSIDE net.mod, which reaches the
; kernel through exactly four gateway slots (SYS_NETKC_{FCBALLOC,SOCKFDTODESC,
; CONPOLLKEY,SLEEP}, include/modules.s).  This transport is built on pipe.s,
; which is kernel-resident, so building it in the module would mean widening the
; module ABI with new gateway slots purely to reach code the kernel already has
; — for a transport that touches no hardware and has no business in a driver
; module.  _Sock_FdToDesc already resolves the descriptor (and _sockTmpHw)
; kernel-side BEFORE the thunks dispatch into net.mod (net_dispatch.s:150-154),
; so the loopback check belongs at that point and pipe.s is a plain JSR away.
;
; DISPATCH KEY is SOCK_HwIdx == SOCK_HW_LOOP, never SOCK_Proto.  A loopback
; socket is an ordinary SOCK_STREAM to userland with the same TCP_* states;
; re-tagging its proto would break every `SOCK_Proto == XPORT_TCP` test.
;
; Increment 2 of P1: pair allocation + teardown only.  connect/accept/send/recv
; land in the increments after this; nothing calls into here yet.
;==============================================================================

;------------------------------------------------------------------------------
; _Loop_PairAlloc - claim the two rings that make up one loopback connection.
;
; Out: C=1 + _loopRingA / _loopRingB = pipe indices (0..PIPE_MAX-1)
;      C=0 + A = errno (ENFILE: no free pipe slot; ENOMEM: ring Kmalloc failed)
; MX %00.  Clobbers A, X, Y.
;
; Both rings or neither: if the SECOND _Pipe_Alloc fails, the first is released
; before returning.  A pipe slot leaked here would be permanent — nothing else
; knows the ring exists, since the descriptor fields are only written on the
; success path below — and the pipe table is small enough that two leaks would
; be visible as an unexplained ENFILE much later, far from the cause.
;------------------------------------------------------------------------------
_Loop_PairAlloc MX      %00
                LDA     #SOCK_LOOP_NONE
                STA     _loopRingA
                STA     _loopRingB
                JSR     _Pipe_Alloc             ; -> C=1 + Y=recoff, _pipeAllocIdx
                BCS     @nl_pa_gotA
                RTS                             ; C=0, A = errno (passthrough)
@nl_pa_gotA       LDA     _pipeAllocIdx
                AND     #$00FF
                STA     _loopRingA
                JSR     _Pipe_Alloc
                BCS     @nl_pa_gotB
                ; Second ring failed — hand back the first, preserving A's errno
                ; across the free (_Pipe_FreeSlot clobbers A via the Kfree path).
                PHA
                JSR     _Loop_FreeRingA
                PLA
                CLC
                RTS
@nl_pa_gotB       LDA     _pipeAllocIdx
                AND     #$00FF
                STA     _loopRingB
                SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_FreeRingA - release the ring named by _loopRingA and mark it gone.
; Idempotent: SOCK_LOOP_NONE means "already released / never allocated".
; MX %00.  Clobbers A, Y.  Does NOT preserve the caller's errno — callers that
; need one across this must stack it (see _Loop_PairAlloc).
;------------------------------------------------------------------------------
_Loop_FreeRingA MX      %00
                LDA     _loopRingA
                AND     #$00FF
                CMP     #SOCK_LOOP_NONE
                BEQ     @nl_fa_done
                ASL                             ; idx -> record offset (idx<<4)
                ASL
                ASL
                ASL
                STA     _pipeRecOff
                JSR     _Pipe_FreeSlot
                LDA     #SOCK_LOOP_NONE
                STA     _loopRingA
@nl_fa_done       RTS

;------------------------------------------------------------------------------
; _Loop_FreeRingB - the _loopRingB half.  Same contract as _Loop_FreeRingA.
;------------------------------------------------------------------------------
_Loop_FreeRingB MX      %00
                LDA     _loopRingB
                AND     #$00FF
                CMP     #SOCK_LOOP_NONE
                BEQ     @nl_fb_done
                ASL
                ASL
                ASL
                ASL
                STA     _pipeRecOff
                JSR     _Pipe_FreeSlot
                LDA     #SOCK_LOOP_NONE
                STA     _loopRingB
@nl_fb_done       RTS

;------------------------------------------------------------------------------
; _Loop_PairFree - release both rings of a pair.  Idempotent on each half.
; MX %00.  Clobbers A, Y.
;------------------------------------------------------------------------------
_Loop_PairFree  MX      %00
                JSR     _Loop_FreeRingA
                JSR     _Loop_FreeRingB
                RTS

;------------------------------------------------------------------------------
; _Loop_ConnectTry - loopback pre-check for SYS_CONNECT, run BEFORE the thunk
; dispatches into net.mod.
;
; In:  _Sys_SavedA = caller-bank offset of the sockaddr_in, _Sys_SavedX = fd,
;      _Sys_CallerBank.  MX %00.
; Out: _loopHandled = 0 -> NOT a loopback destination; caller falls through to
;                          the W5100 path.  A/C are meaningless.
;      _loopHandled = 1 -> handled; A + C are the syscall's result
;                          (C=1 + A=0 connected, or C=0 + A=errno).
; Clobbers A, X, Y.
;
; The destination has to be peeked HERE rather than reused from net.mod's copy:
; net_op_connect stages _sockDstIp/_sockDstPort itself (net.s:867-905), and that
; runs inside the module, after the point where a loopback call must already
; have been diverted.  So the 6 bytes are read again on this path only -- a
; duplicated read, but confined to the loopback branch, which is cheaper than
; adding a module gateway slot to hand the address back out.
;------------------------------------------------------------------------------
_Loop_ConnectTry MX     %00
                STZ     _loopHandled
                ; --- point _libcTmp2 at the caller's sockaddr_in ---
                LDA     _Sys_SavedA
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                ; --- 127.0.0.0/8 test: first octet only, per BSD ---
                LDY     #SIN_ADDR
                LDA     [_libcTmp2],Y
                CMP     #127
                BEQ     @nl_ct_isloop
                REP     #$30
                MX      %00
                RTS                             ; _loopHandled = 0: not loopback
@nl_ct_isloop   ; destination port, network order (hi,lo) -> host order in X
                LDY     #SIN_PORT
                LDA     [_libcTmp2],Y
                XBA                             ; hi byte -> A.hi
                INY
                LDA     [_libcTmp2],Y           ; lo byte -> A.lo
                REP     #$30
                MX      %00
                AND     #$FFFF
                STA     _loopDstPort
                ; From here on this call IS ours: every exit sets _loopHandled.
                LDA     #1
                STA     _loopHandled
                ; --- resolve the CONNECTING descriptor (fd in _Sys_SavedX) ---
                LDA     _Sys_SavedX
                JSR     _NlKC_SockFdToDesc          ; C=1 + Y = desc offset
                BCS     @nl_ct_havefd
                RTS                             ; C=0 + A = EBADF, handled
@nl_ct_havefd   STY     _loopConnOff
                ; --- the descriptor has to be claimable before we take it ---
                JSR     _Loop_ClaimEligible
                BCS     @nl_ct_claimok
                LDA     #EISCONN                ; BSD's answer to connect() on a
                CLC                             ;   socket that already has one
                RTS
@nl_ct_claimok  ; --- scan for a TCP_LISTEN descriptor on _loopDstPort ---
                JSR     _Loop_FindListener      ; C=1 + Y = listener desc offset
                BCS     @nl_ct_found
                LDA     #ECONNREFUSED           ; nothing listening on 127.0.0.1:p
                CLC
                RTS
@nl_ct_found    STY     _loopLisOff
                ; --- two rings, or fail without side effects ---
                JSR     _Loop_PairAlloc
                BCS     @nl_ct_paired
                CLC
                RTS                             ; A = ENFILE/ENOMEM, handled
@nl_ct_paired   JSR     _Loop_WireConnector
                ; The listener is not wired here: accept() allocates the peer
                ; descriptor and claims the mirror ends.  Flagging it PENDING is
                ; what accept() (and select) look at.
                JSR     _Loop_MarkPending
                JSR     _Loop_WakeSel           ; blocked accept() AND select()
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_FindListener - find a descriptor in TCP_LISTEN on _loopDstPort.
; Out: C=1 + Y = descriptor record offset; C=0 = none.  MX %00.  Clobbers A, Y.
;
; Linear over SOCKD_MAX -- a port hash would be more code than the table.
; A descriptor already carrying a PENDING connect is skipped: the W5100 path
; accepts one peer at a time (accept DETACHES the listener), and matching that
; here keeps 127.0.0.1 behaving like the wire instead of quietly supporting a
; backlog the real path does not have.
;------------------------------------------------------------------------------
_Loop_FindListener MX   %00
                LDY     #0
@nl_fl_L        PHY
                TYA
                CLC
                ADC     #SOCK_InUse
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                BEQ     @nl_fl_next             ; slot free
                PLY
                PHY
                JSR     @nl_fl_match
                BCS     @nl_fl_hit
@nl_fl_next     PLY
                TYA
                CLC
                ADC     #SOCK_REC_SIZE
                TAY
                CPY     #SOCKTBL_BLK_SIZE
                BCC     @nl_fl_L
                CLC
                RTS
@nl_fl_hit      PLY
                SEC
                RTS

; helper: Y = record offset -> C=1 if this descriptor is a free LISTEN on the
; wanted port.  Clobbers A; leaves Y as passed.
@nl_fl_match    MX      %00
                PHY
                TYA
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #TCP_LISTEN
                REP     #$30
                MX      %00
                BEQ     @nl_fl_m_state
                PLY
                CLC
                RTS
@nl_fl_m_state  PLY
                PHY
                TYA
                CLC
                ADC     #SOCK_LoopFlags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                AND     #SLF_PENDING
                REP     #$30
                MX      %00
                BEQ     @nl_fl_m_port
                PLY
                CLC
                RTS                             ; already has a caller waiting
@nl_fl_m_port   PLY
                PHY
                TYA
                CLC
                ADC     #SOCK_LPort
                TAY
                LDA     [_sockTablePtr],Y       ; 16-bit local port, host order
                PLY                             ; RESTORE Y *BEFORE* the compare.
                                                ; PLY sets N/Z from the PULLED
                                                ; value, so pulling between CMP
                                                ; and BEQ threw the comparison
                                                ; away and branched on "is the
                                                ; record offset zero" instead.
                                                ; Both halves were wrong, not
                                                ; just one: descriptor 0 matched
                                                ; EVERY port, and a listener at
                                                ; any NONZERO offset could never
                                                ; match at all.  Loopback worked
                                                ; only because the single
                                                ; listener every caller binds
                                                ; lands at descriptor 0 -- which
                                                ; is also why loopback_pair
                                                ; passed throughout
                                                ; (apple/fgx#127).
                CMP     _loopDstPort
                BEQ     @nl_fl_m_yes
                CLC
                RTS
@nl_fl_m_yes    SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_WireConnector - turn the descriptor at _loopConnOff into a live
; loopback endpoint: it WRITES ring A and READS ring B, owns no hw socket, and
; is ESTABLISHED.  Its peer (created by accept) takes the mirror.  MX %00.
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; _Loop_ReleaseHw - give back the W5100 hardware socket this descriptor holds,
; if it holds one, as it becomes loopback.
;
; In:  A = descriptor record offset.  MX %00.  Clobbers A, X, Y.
;
; A descriptor claims a chip socket only when a verb first drives the chip
; (_Xport_Claim), so bind() and connect() reach here with SOCK_HW_UNCLAIMED and
; this does nothing.  The listener fallback is the case that holds one:
; _Net_Xport_Listen claimed it and the hardware listen then failed.  Stamping
; SOCK_HW_LOOP over SOCK_HwIdx without clearing the allocator bit strands that
; slot for the rest of the boot, and teardown cannot undo it: it skips the free
; for anything >= W5_NSOCK, which the sentinel is by construction
; (apple/fgx#132).
;
; A listen that failed left nothing OPEN on the chip, so the allocator bit is
; the only live state.  _W5_SockFree is the existing primitive for exactly that
; and already refuses sentinels and wild indices (the #93 hardening), so this
; reads the index and hands it over rather than recomputing a mask.  A private
; mask TABLE would have been the wrong answer twice over: net_loop.s runs at
; DBR = the KERNEL bank, so a module-local table read is the #93 bug itself.
;
; net_loop.s and net_xport.s are PUT into the same module image, so this is an
; ordinary JSR rather than a gateway slot.
;------------------------------------------------------------------------------
_Loop_ReleaseHw MX      %00
                CLC
                ADC     #SOCK_HwIdx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y       ; the REAL index, read before
                REP     #$30                    ;   the sentinel overwrites it
                MX      %00
                AND     #$00FF
                JSR     _W5_SockFree            ; guards range + sentinels
                RTS

;------------------------------------------------------------------------------
; _Loop_ClaimEligible - may this descriptor be claimed for loopback at all?
;
; In:  _loopConnOff = descriptor record offset.  MX %00.  Clobbers A, Y.
; Out: C=1 eligible, C=0 not.
;
; The claim RELEASES the descriptor's W5100 slot (_Loop_ReleaseHw), and that is
; sound only while the slot has never been OPENed on the chip.  Nothing used to
; ask: a connect() to 127/8 -- or a rebind to it -- on a descriptor already
; carrying a live wire connection, or a bound UDP socket, handed a LIVE hardware
; socket back to the allocator.  The next claim re-issued the same index, two
; descriptors then drove one chip socket, and their closes were a genuine double
; free.  Before the release existed (apple/fgx#132) the same misuse merely
; STRANDED the slot, which is why it stayed invisible: #132's fix is what turned
; a leak into corruption (apple/fgx#133).
;
; SOCK_Bound is set by the bind() that issues the chip OPEN and SOCK_State
; leaves TCP_CLOSED only once a connection exists, so the pair covers the UDP
; shape and the TCP shape respectively.  A descriptor fresh from socket() holds
; no chip socket yet (SOCK_HW_UNCLAIMED) and is the only shape that passes here.
;------------------------------------------------------------------------------
_Loop_ClaimEligible MX  %00
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_Bound
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                BNE     @nl_ce_no               ; already bound -> chip is OPEN
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y       ; TCP_CLOSED is 0, so the load's
                REP     #$30                    ;   own Z answers it
                MX      %00
                BNE     @nl_ce_no
                SEC
                RTS
@nl_ce_no       CLC
                RTS

_Loop_WireConnector MX  %00
                LDA     _loopConnOff            ; any chip socket goes back before
                JSR     _Loop_ReleaseHw         ;   the SOCK_HW_LOOP stamp below
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_HwIdx
                TAY
                SEP     #$20
                MX      %10
                LDA     #SOCK_HW_LOOP
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_LoopTx
                TAY
                SEP     #$20
                MX      %10
                LDA     _loopRingA              ; connector writes A->B
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_LoopRx
                TAY
                SEP     #$20
                MX      %10
                LDA     _loopRingB              ; connector reads B->A
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     #TCP_ESTABLISHED
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Loop_WakeSel - wake a loopback peer, on BOTH channels it might be parked on.
;
; A blocked accept() sleeps on WCHAN_SOCK, but a blocking select(2) sleeps on
; WCHAN_SELECT (syscall.s: `_nSelSleepers` + `LDA #WCHAN_SELECT / JSR _NlKC_Sleep`) --
; NOT on WCHAN_SOCK.  Every wake site here used to raise WCHAN_SOCK alone, with
; comments asserting that select parked there too.  It does not, so a loopback
; send landed bytes in the ring and woke NOBODY: telnetd relayed the login
; prompt into the pair, telnet slept in select forever, and the prompt never
; appeared.  It looked non-deterministic only because a client that happened to
; CALL select after the data landed saw it via the readiness scan -- so any
; unrelated perturbation of the client's timing "fixed" it.
;
; pty.s (@pw_nosel) is the pattern this mirrors: raise the specific channel,
; then WCHAN_SELECT guarded by _nSelSleepers so the common case costs one
; compare.  Clobbers A/X/Y, as _wakeup does.  MX %00.
;------------------------------------------------------------------------------
_Loop_WakeSel   MX      %00
                LDA     #WCHAN_SOCK
                JSR     _NlKC_Wakeup
                LDA     _nSelSleepers
                BEQ     @nl_ws_done
                LDA     #WCHAN_SELECT
                JSR     _NlKC_Wakeup
@nl_ws_done     RTS

;------------------------------------------------------------------------------
; _Loop_MarkPending - record on the listener at _loopLisOff that a connector is
; waiting, and which descriptor it is, so accept() can find it.  MX %00.
;------------------------------------------------------------------------------
_Loop_MarkPending MX    %00
                LDA     _loopLisOff
                CLC
                ADC     #SOCK_LoopPeer
                TAY
                LDA     _loopConnOff
                JSR     _Loop_OffToIdx          ; A = index (preserves Y)
                SEP     #$20
                MX      %10
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     _loopLisOff
                CLC
                ADC     #SOCK_LoopFlags
                TAY
                SEP     #$20
                MX      %10
                LDA     #SLF_PENDING
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Loop_OffToIdx - A = descriptor RECORD OFFSET -> A = descriptor INDEX.
; SOCK_REC_SIZE is not a power of two, so this is a subtract loop over the
; constant rather than a shift -- the mirror of _Loop_IdxToOff's add loop, and
; size-agnostic for the same reason.  MX %00.
;------------------------------------------------------------------------------
_Loop_OffToIdx  MX      %00
                LDX     #0
@nl_oi_L        CMP     #SOCK_REC_SIZE
                BCC     @nl_oi_done
                SEC
                SBC     #SOCK_REC_SIZE
                INX
                BRA     @nl_oi_L
@nl_oi_done     TXA
                RTS

;------------------------------------------------------------------------------
; _Loop_AcceptTry - loopback pre-check for SYS_ACCEPT, run BEFORE the thunk
; dispatches into net.mod.
;
; In:  _Sys_SavedA = listener fd.  MX %00.
; Out: _loopHandled = 0 -> no loopback caller pending; fall through to net.mod.
;      _loopHandled = 1 -> handled; A + C are the syscall result
;                          (C=1 + A = new fd, or C=0 + A = errno).
;
; DISPATCH KEY here is SLF_PENDING on the LISTENER, not SOCK_HW_LOOP.  The
; listener is an ordinary (possibly W5100-backed) socket; only its pending
; CALLER is loopback.  connect() flags it, accept() consumes the flag.
;
; A blocking accept with nothing pending is NOT handled here: it falls through
; and blocks in the W5100 path exactly as before, and _Loop_ConnectTry's
; _Loop_WakeSel (which raises WCHAN_SOCK) is what re-runs the syscall so this
; check sees the flag on the second pass.
;------------------------------------------------------------------------------
_Loop_AcceptTry MX      %00
                STZ     _loopHandled
                LDA     _Sys_SavedA
                AND     #$00FF
                JSR     _NlKC_SockFdToDesc          ; C=1 + Y = listener desc offset
                BCS     @nl_at_havefd
                RTS                             ; not even a valid fd -> let the
                                                ; normal path produce EBADF
@nl_at_havefd   STY     _loopLisOff
@nl_at_recheck  LDA     _loopLisOff
                CLC
                ADC     #SOCK_LoopFlags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                AND     #SLF_PENDING
                REP     #$30
                MX      %00
                BNE     @nl_at_pending
                ; Nothing pending.  If this is a LOOPBACK listener we must wait
                ; here rather than fall through: the W5100 accept does not block
                ; on a machine with no Uthernet fitted, it returns ENOTCONN
                ; immediately -- so a server that called accept() before its
                ; client connected died instead of waiting.  Found by running
                ; telnetd against the telnet client; review had signed off on
                ; "fall through and block in the W5100 path exactly as before",
                ; which is true only when there IS a W5100.
                LDA     _loopLisOff
                CLC
                ADC     #SOCK_HwIdx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #SOCK_HW_LOOP
                REP     #$30
                MX      %00
                BEQ     @nl_at_wait
                RTS                             ; _loopHandled = 0: hw listener
@nl_at_wait     LDA     #1
                STA     _loopHandled
                LDA     _loopLisOff             ; FIONBIO -> EWOULDBLOCK
                CLC
                ADC     #SOCK_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                AND     #SOCK_NB
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @nl_at_sleep
                LDA     #EAGAIN
                CLC
                RTS
@nl_at_sleep    LDA     #WCHAN_SOCK             ; connect() wakes this channel
                JSR     _NlKC_Sleep             ; C=1 = a signal will act on us
                ; THE VERDICT IS NOT OPTIONAL.  Looping on it instead of
                ; returning spins at kernel priority and starves the machine --
                ; the failure _Tty_GetByte's @tgb_vcWait already names in its
                ; third numbered protection.  A task parked here is in a
                ; syscall, and FGX delivers signals at syscall EXIT, so
                ; re-checking forever means the SIGTERM that woke us is never
                ; delivered: the task stays TASK_RUNNING with the signal
                ; pending and nothing else ever runs (apple/fgx#125 --
                ; `telnetd &` then `kill %` wedged the console).
                ; _Sock_PollIntr (net_xport.s) and _Pipe_PollIntr (pipe.s) both
                ; forward this carry since P4/T1-T2 (2026-08-01); this site was
                ; the one blocking wait that never got it.
                PHP                             ; the repoint clobbers C
                JSR     _Loop_RepointFdTable    ; MUST re-point: see below
                PLP
                BCS     @nl_at_intr
                BRL     @nl_at_recheck
@nl_at_intr     LDA     #EINTR                  ; _loopHandled is already 1
                CLC
                RTS
@nl_at_pending  LDA     #1
                STA     _loopHandled
                ; --- the waiting connector, and the rings it already owns ---
                LDA     _loopLisOff
                CLC
                ADC     #SOCK_LoopPeer
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y       ; connector descriptor INDEX
                REP     #$30
                MX      %00
                AND     #$00FF
                JSR     _Loop_IdxToOff
                STA     _loopConnOff
                ; connector WRITES ring A and READS ring B; the accepted end
                ; takes the mirror, so read them off the connector rather than
                ; from _loopRing[AB] -- those globals belong to whichever pair
                ; was allocated most recently, which need not be this one.
                CLC
                ADC     #SOCK_LoopTx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                STA     _loopRingA
                REP     #$30
                MX      %00
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_LoopRx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                STA     _loopRingB
                REP     #$30
                MX      %00
                ; --- TAKE BOTH RESOURCES BEFORE CHANGING ANYTHING
                ;     (apple/fgx#145).  The descriptor and the fd are the only
                ;     two things here that can fail, and both are claimed now,
                ;     while every failure path is still a plain RTS with nothing
                ;     to unwind: the connector keeps its rings, the listener
                ;     keeps SLF_PENDING, and the caller can simply try again
                ;     once the pressure clears.
                ;
                ;     The fd used to be asked for LAST -- after the accepted end
                ;     was wired, after the two ends were cross-linked and after
                ;     the pending flag was consumed -- so one fd shortage
                ;     produced three kinds of stuck from a single failure: a
                ;     fully wired descriptor with no fd that nothing would ever
                ;     free (a SOCKD slot gone for the rest of the boot), a
                ;     connector left believing it was talking to a peer no
                ;     process could reach, and a listener that would never offer
                ;     the connection again.  _Loop_DescAlloc only FINDS a free
                ;     slot -- SOCK_InUse is written by _Loop_WireAccepted below
                ;     -- so it is safe to ask first and abandon.
                JSR     _Loop_DescAlloc         ; C=1 + Y = new desc offset
                BCS     @nl_at_gotdesc
                LDA     #EMFILE
                CLC
                RTS
@nl_at_gotdesc  STY     _loopAccOff
                JSR     _NlKC_FcbAlloc          ; C=1 + A = fd (M=1!), _fcbPtr live
                BCS     @nl_at_gotfd
                REP     #$30
                MX      %00
                LDA     #EMFILE
                CLC
                RTS
@nl_at_gotfd    REP     #$30
                MX      %00
                AND     #$00FF
                PHA                             ; keep the fd across everything below
                ; The FCB fields go in HERE, next to the alloc, so _fcbPtr is
                ; never carried across the wiring routines.
                SEP     #$20
                MX      %10
                LDY     #FCB_Flags
                LDA     #FCB_FL_SOCKET
                STA     [_fcbPtr],Y
                LDY     #FCB_FstIdx
                LDA     #$00
                STA     [_fcbPtr],Y
                LDY     #FCB_SockIdx
                LDA     _loopAccOff             ; FCB carries the OFFSET, as the
                STA     [_fcbPtr],Y             ;   W5100 accept path does
                REP     #$30
                MX      %00
                JSR     _Loop_WireAccepted
                ; --- cross-link the two ends ---
                LDA     _loopConnOff
                JSR     _Loop_OffToIdx
                PHA                             ; connector index
                LDA     _loopAccOff
                CLC
                ADC     #SOCK_LoopPeer
                TAY
                PLA
                SEP     #$20
                MX      %10
                STA     [_sockTablePtr],Y       ; accepted.peer = connector
                REP     #$30
                MX      %00
                LDA     _loopAccOff
                JSR     _Loop_OffToIdx
                PHA                             ; accepted index
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_LoopPeer
                TAY
                PLA
                SEP     #$20
                MX      %10
                STA     [_sockTablePtr],Y       ; connector.peer = accepted
                REP     #$30
                MX      %00
                ; --- the listener is free again (one caller at a time) ---
                LDA     _loopLisOff
                CLC
                ADC     #SOCK_LoopPeer
                TAY
                SEP     #$20
                MX      %10
                LDA     #SOCK_LOOP_NONE
                STA     [_sockTablePtr],Y       ; drop the consumed connector
                INY                             ; ...Rx, Tx untouched: the
                INY                             ;    listener never owned rings
                INY
                LDA     #$00
                STA     [_sockTablePtr],Y       ; SOCK_LoopFlags: no longer pending
                REP     #$30
                MX      %00
                ; --- the fd was bound above, before any of this ran ---
                JSR     _Loop_WakeSel           ; wake anyone blocked on the pair
                                                ; (clobbers A/X/Y; fd is on the stack)
                PLA
                SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_WireAccepted - make the descriptor at _loopAccOff the mirror end of the
; connector: reads ring A (what the connector writes), writes ring B.  Marks it
; in use, TCP/ESTABLISHED, owning no hw socket.  MX %00.
;------------------------------------------------------------------------------
_Loop_WireAccepted MX   %00
                LDA     _loopAccOff
                TAY
                SEP     #$20
                MX      %10
                LDA     #$01
                STA     [_sockTablePtr],Y       ; SOCK_InUse
                INY
                LDA     #SOCK_HW_LOOP
                STA     [_sockTablePtr],Y       ; SOCK_HwIdx
                INY
                LDA     #$00
                STA     [_sockTablePtr],Y       ; SOCK_Flags
                INY
                LDA     #$01
                STA     [_sockTablePtr],Y       ; SOCK_Bound
                INY
                LDA     #$00
                STA     [_sockTablePtr],Y       ; SOCK_LPort lo
                INY
                STA     [_sockTablePtr],Y       ; SOCK_LPort hi
                INY
                LDA     #XPORT_TCP              ; NOT a new proto tag -- see hdr
                STA     [_sockTablePtr],Y
                INY
                LDA     #TCP_ESTABLISHED
                STA     [_sockTablePtr],Y       ; SOCK_State
                INY
                LDA     #SOCK_LOOP_NONE
                STA     [_sockTablePtr],Y       ; SOCK_LoopPeer (set by caller)
                INY
                LDA     _loopRingA
                STA     [_sockTablePtr],Y       ; SOCK_LoopRx = connector's Tx
                INY
                LDA     _loopRingB
                STA     [_sockTablePtr],Y       ; SOCK_LoopTx = connector's Rx
                INY
                LDA     #$00
                STA     [_sockTablePtr],Y       ; SOCK_LoopFlags
                INY
                ; THE AF_UNIX BYTES ARE CLEARED HERE TOO, because this routine
                ; is the THIRD descriptor initialiser and the only one that
                ; writes the whole record positionally -- _Loop_DescAlloc just
                ; finds a free index and clears nothing, and teardown clears
                ; only SOCK_InUse.  Left out, a recycled slot would carry the
                ; previous tenant's SOCK_UnpPeer into a loopback accept, and a
                ; zero there reads as "descriptor 0 is my peer", which is a live
                ; descriptor.
                LDA     #SOCK_LOOP_NONE
                STA     [_sockTablePtr],Y       ; SOCK_UnpRx
                INY
                STA     [_sockTablePtr],Y       ; SOCK_UnpPeer
                LDA     #$00                    ; no datagram peer
                INY
                STA     [_sockTablePtr],Y       ; SOCK_FAddr
                INY
                STA     [_sockTablePtr],Y       ; SOCK_FAddr+1
                INY
                STA     [_sockTablePtr],Y       ; SOCK_FAddr+2
                INY
                STA     [_sockTablePtr],Y       ; SOCK_FAddr+3
                INY
                STA     [_sockTablePtr],Y       ; SOCK_FPort
                INY
                STA     [_sockTablePtr],Y       ; SOCK_FPort+1
                REP     #$30
                MX      %00
                ; THE ACCEPTED SOCKET'S LOCAL NAME IS THE LISTENER'S.  BSD
                ; reports 127.0.0.1:<listen port> from getsockname(2) on an
                ; accepted connection; the positional walk above had left this
                ; zero because nothing read SOCK_LPort on an accepted
                ; descriptor until getpeername/getsockname existed
                ; (apple/fgx#142).  Two bytes ride the stack rather than take a
                ; new static -- there is no call in between to lose them.
                LDA     _loopLisOff
                CLC
                ADC     #SOCK_LPort
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y       ; listener port lo
                PHA
                INY
                LDA     [_sockTablePtr],Y       ; listener port hi
                PHA
                REP     #$30
                MX      %00
                LDA     _loopAccOff
                CLC
                ADC     #SOCK_LPort+1
                TAY
                SEP     #$20
                MX      %10
                PLA                             ; hi first (pushed last)
                STA     [_sockTablePtr],Y
                DEY
                PLA                             ; lo
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Loop_DescAlloc - first free socket descriptor.
; Out: C=1 + Y = record offset; C=0 = table full.  MX %00.  Clobbers A, Y.
; Does NOT mark it in use -- _Loop_WireAccepted writes SOCK_InUse as its first
; store, so the slot is claimed before anything can yield.
;------------------------------------------------------------------------------
_Loop_DescAlloc MX      %00
                LDY     #0
@nl_da_L        SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y       ; SOCK_InUse is offset 0
                REP     #$30
                MX      %00
                BEQ     @nl_da_hit
                TYA
                CLC
                ADC     #SOCK_REC_SIZE
                TAY
                CPY     #SOCKTBL_BLK_SIZE
                BCC     @nl_da_L
                CLC
                RTS
@nl_da_hit      SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_IdxToOff - A = descriptor INDEX -> A = record OFFSET.  MX %00.
;
; Clobbers X.  Exit flags are whatever the terminating CPX set; both callers
; open with CLC/ADC of their own, so neither reads them.
;
; SOCK_REC_SIZE is not a power of two, so this is an ADD LOOP over the constant
; -- the mirror of _Loop_OffToIdx's subtract loop, and size-agnostic for the
; same reason: the size appears as a NAMED operand.  A shift-or-multiply form
; bakes it into the instruction stream instead, where a grep for the symbol
; cannot find this routine at all.
;
; A is trusted to be a real descriptor index.  Callers filter SOCK_LOOP_NONE but
; nothing here bounds A, so a corrupt byte runs that many iterations and returns
; an offset past the table.
;------------------------------------------------------------------------------
_Loop_IdxToOff  MX      %00
                AND     #$00FF
                TAX                             ; X = idx
                LDA     #0
@nl_i2o_L       CPX     #0
                BEQ     @nl_i2o_done
                CLC
                ADC     #SOCK_REC_SIZE
                DEX
                BRA     @nl_i2o_L
@nl_i2o_done    RTS

;------------------------------------------------------------------------------
; _Loop_SoIo - sosend/soreceive for a loopback socket: the pair's ring, moved
; through the caller's uio.
;
; In:  A = 0 send (SOCK_LoopTx), 1 receive (SOCK_LoopRx); _sockTmpOff = the
;      descriptor; _sockUio = the uio; _sockSendFlags / _sockRecvFlags.
; Out: A = bytes + C=1, or A = errno + C=0.  MX %00.
;
; Both directions run pipe.s's ring bodies (_Pipe_WriteUio/_Pipe_ReadUio) rather
; than a second copy of the same logic: blocking, ring wrap, EOF-when-the-writer-
; is-gone, SIGPIPE-when-the-reader-is-gone and the _wakeup ordering are already
; correct there and covered by the pipe fixtures.  read/write, send/recv and
; sendto/recvfrom all arrive here, through _So_Send/_So_Recv (net.s), so one
; loopback socket answers every data call the same way.
;
; Channel note: pipe.s blocks and wakes on WCHAN_PIPE at BOTH ends, so the two
; halves of a loopback pair stay self-consistent for free.  The _Loop_WakeSel
; below is for a peer parked in the SOCKET paths, which sleep on TWO DIFFERENT
; channels: a blocked accept() on WCHAN_SOCK, but a blocking select(2) on
; WCHAN_SELECT -- see _Loop_WakeSel.
;------------------------------------------------------------------------------
_Loop_SoIo      MX      %00
                STA     _loopIsRecv
                LDA     _sockTmpOff
                STA     _loopConnOff
                CLC
                LDX     _loopIsRecv
                BNE     @nl_so_rx
                ADC     #SOCK_LoopTx
                BRA     @nl_so_ring
@nl_so_rx       ADC     #SOCK_LoopRx
@nl_so_ring     TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                AND     #$00FF
                CMP     #SOCK_LOOP_NONE
                BNE     @nl_so_haveRing
                LDA     #ENOTCONN               ; loopback-tagged but unpaired
                CLC
                RTS
@nl_so_haveRing ASL                             ; pipe idx -> record offset
                ASL
                ASL
                ASL
                STA     _pipeRecOff
                ; --- MSG_DONTWAIT (this call) or SOCK_NB (FIONBIO) ---
                LDA     _sockSendFlags
                LDX     _loopIsRecv
                BEQ     @nl_so_fl
                LDA     _sockRecvFlags
@nl_so_fl       AND     #MSG_DONTWAIT
                STA     _loopMsgNb
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                AND     #SOCK_NB
                REP     #$30
                MX      %00
                ORA     _loopMsgNb              ; either flag means "do not sleep"
                BEQ     @nl_so_nb
                LDA     #1
@nl_so_nb       STA     _pipeNonBlk             ; 0 = block, 1 = EAGAIN
                LDA     _sockUio                ; the ring moves the caller's uio
                STA     _pipeUio
                LDA     _sockUioBank
                STA     _pipeUioBank
                LDA     _loopIsRecv
                BNE     @nl_so_read
                JSR     _Pipe_WriteUio
                BRA     @nl_so_done
@nl_so_read     JSR     _Pipe_ReadUio
@nl_so_done     PHP                             ; preserve the result carry
                PHA                             ;   and the byte count / errno
                JSR     _Loop_WakeSel           ; peer parked in accept OR select
                STZ     _pipeNonBlk             ; leave the shared flag as the fd
                PLA                             ;   wrappers expect to find it
                PLP
                RTS

;------------------------------------------------------------------------------
; _Loop_CloseTry - loopback pre-check for socket teardown (Fs_Close's
; FCB_FL_SOCKET branch).
;
; In:  Y = descriptor record offset.  MX %00.
; Out: _loopHandled = 0 -> not loopback; fall through to net_op_sockteardown.
;      _loopHandled = 1 -> handled; C=1.
;
; Half-close is pipe.s's own model, reused: this end stops WRITING its Tx ring
; (PIPE_WrClosed) so the peer's next read drains and then sees EOF, and stops
; READING its Rx ring (PIPE_RdClosed) so the peer's next write gets EPIPE.
; That is exactly BSD close-on-a-stream semantics, and it means SYS_SHUTDOWN
; can later set just one of the two flags without any new machinery.
;
; Rings are freed only when BOTH ends are done with them -- checked by testing
; the OTHER flag on each ring, not by tracking a refcount.  Freeing on first
; close would pull the buffer out from under a peer still draining it.
;------------------------------------------------------------------------------
_Loop_CloseTry  MX      %00
                STZ     _loopHandled
                STY     _loopConnOff
                TYA
                CLC
                ADC     #SOCK_HwIdx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #SOCK_HW_LOOP
                REP     #$30
                MX      %00
                BEQ     @nl_cl_mine
                RTS                             ; _loopHandled = 0
@nl_cl_mine     LDA     #1
                STA     _loopHandled
                ; Tx ring: no more writers from this end.
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_LoopTx
                TAY
                JSR     _Loop_RingOffFromDesc   ; A = ring record offset, C=0 if none
                BCC     @nl_cl_rx
                STA     _pipeRecOff
                CLC
                ADC     #PIPE_WrClosed
                TAY
                SEP     #$20
                MX      %10
                LDA     #$01
                STA     [_pipeTablePtr],Y
                REP     #$30
                MX      %00
                JSR     _Loop_FreeIfBothGone
@nl_cl_rx       ; Rx ring: no more readers at this end.
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_LoopRx
                TAY
                JSR     _Loop_RingOffFromDesc
                BCC     @nl_cl_clear
                STA     _pipeRecOff
                CLC
                ADC     #PIPE_RdClosed
                TAY
                SEP     #$20
                MX      %10
                LDA     #$01
                STA     [_pipeTablePtr],Y
                REP     #$30
                MX      %00
                JSR     _Loop_FreeIfBothGone
@nl_cl_clear    ; Drop this descriptor's loopback state and release the slot.
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_LoopPeer
                TAY
                SEP     #$20
                MX      %10
                LDA     #SOCK_LOOP_NONE
                STA     [_sockTablePtr],Y       ; peer
                INY
                STA     [_sockTablePtr],Y       ; Rx
                INY
                STA     [_sockTablePtr],Y       ; Tx
                INY
                LDA     #$00
                STA     [_sockTablePtr],Y       ; flags
                REP     #$30
                MX      %00
                LDA     _loopConnOff
                TAY
                SEP     #$20
                MX      %10
                LDA     #$00
                STA     [_sockTablePtr],Y       ; SOCK_InUse = 0
                INY                             ; SOCK_HwIdx
                LDA     #SOCK_HW_NONE           ; ...and DISOWN the transport.
                STA     [_sockTablePtr],Y       ; Clearing InUse alone left
                                                ; SOCK_HwIdx = SOCK_HW_LOOP on a
                                                ; freed slot, so every test of the
                                                ; form "HwIdx == SOCK_HW_LOOP"
                                                ; (_Loop_StatusTry:1074 is one)
                                                ; claims a dead descriptor as a
                                                ; live loopback socket and answers
                                                ; questions about it.  Observed:
                                                ; desc0 read InUse=0 with Hw=$FE
                                                ; and State=TCP_LISTEN long after
                                                ; the listener closed.  Same
                                                ; staleness family as the
                                                ; SOCK_Loop* fix (_Sock_ClearXportState)
                                                ; -- that cleared Rx/Tx/flags/peer
                                                ; but not the transport tag.
                REP     #$30
                MX      %00
                LDA     #WCHAN_PIPE             ; peer blocked in a ring...
                JSR     _NlKC_Wakeup
                JSR     _Loop_WakeSel           ; ...or in accept/select
                SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_RingOffFromDesc - Y = address of a SOCK_LoopRx/Tx byte -> A = that
; ring's pipe RECORD OFFSET, C=1.  C=0 (A undefined) if the field is
; SOCK_LOOP_NONE.  MX %00.
;------------------------------------------------------------------------------
_Loop_RingOffFromDesc MX %00
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                AND     #$00FF
                CMP     #SOCK_LOOP_NONE
                BNE     @nl_rofd_ok
                CLC
                RTS
@nl_rofd_ok     ASL
                ASL
                ASL
                ASL
                SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_FreeIfBothGone - release the ring at _pipeRecOff once BOTH its reader
; and its writer are gone.  MX %00.  Clobbers A, Y.
;------------------------------------------------------------------------------
_Loop_FreeIfBothGone MX %00
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_RdClosed
                TAY
                SEP     #$20
                MX      %10
                LDA     [_pipeTablePtr],Y
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @nl_fbg_no
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_WrClosed
                TAY
                SEP     #$20
                MX      %10
                LDA     [_pipeTablePtr],Y
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @nl_fbg_no
                JSR     _Pipe_FreeSlot          ; reads _pipeRecOff
@nl_fbg_no      RTS

;------------------------------------------------------------------------------
; _Loop_StatusTry - loopback pre-check for select(2) readiness.
;
; In:  Y = descriptor record offset.  MX %00.
; Out: _loopHandled = 0 -> not loopback; fall through to NETOP_SockStatus.
;      _loopHandled = 1 -> handled; A = ready bits (bit0 read, bit1 write), C=1.
;
; Matches _Net_Xport_SockStatus's contract: never sleeps, never consumes data.
; readable = bytes resident OR the writer is gone (so a drained, closed peer
; reports READY and the caller's recv() returns the EOF, rather than select
; parking forever on a connection that will never produce another byte).
; writable = the reader is still there and the ring is not full.
;------------------------------------------------------------------------------
_Loop_StatusTry MX      %00
                STZ     _loopHandled
                STY     _loopConnOff
                ; A PENDING LOOPBACK CALLER MAKES *ANY* LISTENER READABLE, AND
                ; THAT TEST HAS TO COME BEFORE THE SOCK_HW_LOOP GATE
                ; (apple/fgx#144).  _Loop_FindListener matches on TCP_LISTEN and
                ; the port and deliberately does NOT check SOCK_HwIdx -- a
                ; W5100-backed listener can be picked by a loopback connect()
                ; and have SLF_PENDING raised on it, which _Loop_AcceptTry
                ; supports on purpose ("the listener is an ordinary (possibly
                ; W5100-backed) socket; only its pending CALLER is loopback").
                ;
                ; select() did not follow: the readiness answer sat behind the
                ; gate below, so a wire listener was routed to NETOP_SockStatus,
                ; which knows nothing about SLF_PENDING.  `telnet localhost p'
                ; against a select-driven server bound to 0.0.0.0 on a machine
                ; WITH a card therefore printed Connected while the server slept
                ; forever -- apple/fgx#140's symptom, surviving #140's fix,
                ; because #140 only fixed the loopback-backed half.
                JSR     _Loop_ListenPending     ; C=1: a connect is waiting here
                BCC     @nl_st_gate
                LDA     #1
                STA     _loopHandled
                LDA     #$0001                  ; readable; never writable, as
                STA     _loopBits               ;   BSD does not select a
                STZ     _loopRxLen              ;   listener for write
                RTS
@nl_st_gate     LDA     _loopConnOff
                CLC
                ADC     #SOCK_HwIdx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #SOCK_HW_LOOP
                REP     #$30
                MX      %00
                BEQ     @nl_st_mine
                RTS
@nl_st_mine     LDA     #1
                STA     _loopHandled
                STZ     _loopBits
                STZ     _loopRxLen              ; no ring / no bytes -> zero, and
                                                ;   ZEROED HERE rather than at the
                                                ;   load below because the ring
                                                ;   lookup can fail and skip it
                ; A LISTENER OWNS NO RINGS -- _Loop_PairAlloc runs at connect,
                ; and the listener's mirror ends are claimed by accept() -- so
                ; it must not fall into the ring lookups below, which would fail
                ; and leave every bit clear by accident rather than on purpose.
                ; The READY answer for a listener is decided at the top of this
                ; routine by _Loop_ListenPending, which is reached before the
                ; SOCK_HW_LOOP gate so that a W5100-backed listener gets it too
                ; (apple/fgx#144); by the time control is here, the answer is
                ; "nothing pending", i.e. not ready.
                ;
                ; Not writable, ever: BSD does not select a listener for write
                ; either, and falling through to @nl_st_done leaves the bit
                ; clear without a Tx ring lookup that would also fail.
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #TCP_LISTEN
                REP     #$30
                MX      %00
                BNE     @nl_st_rd               ; ordinary endpoint: rings below
                BRL     @nl_st_done             ; listener, nothing pending
@nl_st_rd       ; ---- readable? ----
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_LoopRx
                TAY
                JSR     _Loop_RingOffFromDesc
                BCC     @nl_st_wr
                STA     _pipeRecOff
                CLC
                ADC     #PIPE_Count
                TAY
                LDA     [_pipeTablePtr],Y       ; 16-bit resident count
                STA     _loopRxLen              ; ...which is also FIONREAD's
                                                ;   answer.  STA leaves N/Z
                                                ;   alone, so the BNE below
                                                ;   still tests the COUNT.
                BNE     @nl_st_setrd
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_WrClosed
                TAY
                SEP     #$20
                MX      %10
                LDA     [_pipeTablePtr],Y
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @nl_st_wr
@nl_st_setrd    LDA     _loopBits
                ORA     #$0001
                STA     _loopBits
                ; ---- writable? ----
@nl_st_wr       LDA     _loopConnOff
                CLC
                ADC     #SOCK_LoopTx
                TAY
                JSR     _Loop_RingOffFromDesc
                BCC     @nl_st_done
                STA     _pipeRecOff
                CLC
                ADC     #PIPE_RdClosed
                TAY
                SEP     #$20
                MX      %10
                LDA     [_pipeTablePtr],Y
                REP     #$30
                MX      %00
                AND     #$00FF
                BNE     @nl_st_done             ; reader gone -> not writable
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_Count
                TAY
                LDA     [_pipeTablePtr],Y
                STA     _loopScratch
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_BufSz
                TAY
                LDA     [_pipeTablePtr],Y
                CMP     _loopScratch
                BEQ     @nl_st_done             ; full
                LDA     _loopBits
                ORA     #$0002
                STA     _loopBits
@nl_st_done     LDA     _loopBits
                SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_BindTry / _Loop_ListenTry - keep a 127/8 SERVER off the hardware.
;
; FOUND BY RUNNING THE GATE, not by review.  The original design assumed a
; loopback connect could match an ordinary listener, so bind/listen were left
; on the W5100 path.  On a machine with no Uthernet fitted -- which is every
; headless CI run, and the very configuration this transport exists to serve --
; listen() fails in the chip core, so there is never a listener for connect()
; to find.  loopprobe reported "FAIL listen" on its first run.
;
; So a socket bound to 127/8 is claimed for loopback AT BIND: it is tagged
; SOCK_HW_LOOP, its port is recorded, and neither call enters net.mod.  That
; also makes the tag mean one consistent thing -- "this descriptor is serviced
; by net_loop.s" -- for servers as well as for connected endpoints.
;
; In:  _Sys_SavedA = sockaddr_in offset, _Sys_SavedX = fd (bind);
;      _Sys_SavedA = fd (listen).  MX %00.
; Out: _loopHandled as elsewhere; A + C are the syscall result when handled.
;------------------------------------------------------------------------------
_Loop_BindTry   MX      %00
                STZ     _loopHandled
                LDA     _Sys_SavedA
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                LDY     #SIN_ADDR
                LDA     [_libcTmp2],Y
                CMP     #127
                BEQ     @nl_bt_isloop
                REP     #$30
                MX      %00
                RTS                             ; not 127/8 -> hardware path
@nl_bt_isloop   LDY     #SIN_PORT               ; host order from network order
                LDA     [_libcTmp2],Y
                XBA
                INY
                LDA     [_libcTmp2],Y
                REP     #$30
                MX      %00
                STA     _loopDstPort
                LDA     #1
                STA     _loopHandled
                LDA     _Sys_SavedX
                AND     #$00FF
                JSR     _NlKC_SockFdToDesc
                BCS     @nl_bt_havefd
                RTS                             ; EBADF, handled
@nl_bt_havefd   STY     _loopConnOff
                JSR     _Loop_ClaimEligible
                BCS     @nl_bt_claimok
                LDA     #EINVAL                 ; BSD's answer to a rebind
                CLC
                RTS
@nl_bt_claimok  LDA     _loopConnOff            ; any chip socket goes back
                JSR     _Loop_ReleaseHw
                LDY     _loopConnOff
                ; claim it for loopback and record the port
                TYA
                CLC
                ADC     #SOCK_HwIdx
                TAY
                SEP     #$20
                MX      %10
                LDA     #SOCK_HW_LOOP
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_LPort
                TAY
                LDA     _loopDstPort
                STA     [_sockTablePtr],Y       ; 16-bit, host order
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_Bound
                TAY
                SEP     #$20
                MX      %10
                LDA     #$01
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_ClaimListener - turn the descriptor at _sockTmpOff into a LOOPBACK
; listener: hand its W5100 slot back, stamp SOCK_HW_LOOP, mark TCP_LISTEN.
; Out: A=0, C=1 (this cannot fail -- it only gives things away).  MX %00.
;
; Reached from net_op_listen when the hardware listen failed on a socket bound
; to INADDR_ANY (apple/fgx#128).  The socket already carries the port from
; bind(), which is the only thing _Loop_FindListener needs, so nothing is
; recorded here that bind() did not already record.
;
; The slot release is not optional and not cosmetic: _W5_SockAlloc hands out
; three sockets for the whole machine, _Net_Xport_Listen claimed one for the
; listen that failed, and a descriptor stamped SOCK_HW_LOOP without the release
; strands it for the boot (apple/fgx#132).
;------------------------------------------------------------------------------
_Loop_ClaimListener MX  %00
                LDA     _sockTmpOff
                JSR     _Loop_ReleaseHw
                LDA     _sockTmpOff
                CLC
                ADC     #SOCK_HwIdx
                TAY
                SEP     #$20
                MX      %10
                LDA     #SOCK_HW_LOOP
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     _sockTmpOff
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     #TCP_LISTEN
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_ListenPending - is the descriptor at _loopConnOff a LISTENER with a
; loopback connect waiting on it?  Out: C=1 yes, C=0 no.  MX %00.  Clobbers A,Y.
;
; Both halves are needed and neither implies the other: SLF_PENDING is only ever
; raised on a listener, but a descriptor that has been recycled carries whatever
; its previous tenant left in SOCK_LoopFlags unless something cleared it, and
; SOCK_State is the field that says what this descriptor IS.  Asking both is one
; extra byte read and it is the difference between a predicate and a guess.
;------------------------------------------------------------------------------
_Loop_ListenPending MX  %00
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #TCP_LISTEN
                REP     #$30
                MX      %00
                BNE     @nl_lp_no
                LDA     _loopConnOff
                CLC
                ADC     #SOCK_LoopFlags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                AND     #SLF_PENDING
                REP     #$30
                MX      %00
                BEQ     @nl_lp_no
                SEC
                RTS
@nl_lp_no       CLC
                RTS

_Loop_ListenTry MX      %00
                STZ     _loopHandled
                LDA     _Sys_SavedA
                AND     #$00FF
                JSR     _NlKC_SockFdToDesc
                BCS     @nl_lt_havefd
                RTS                             ; let the normal path say EBADF
@nl_lt_havefd   STY     _loopConnOff
                TYA
                CLC
                ADC     #SOCK_HwIdx
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #SOCK_HW_LOOP
                REP     #$30
                MX      %00
                BEQ     @nl_lt_mine
                RTS                             ; hardware listener
@nl_lt_mine     LDA     #1
                STA     _loopHandled
                LDA     _loopConnOff            ; TCP_LISTEN, no chip involved
                CLC
                ADC     #SOCK_State
                TAY
                SEP     #$20
                MX      %10
                LDA     #TCP_LISTEN
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Loop_RepointFdTable - re-establish _fd_table_ptr for the CURRENT task.
;
; The syscall dispatcher points _fd_table_ptr at the caller's fd table on entry
; (syscall.s) and never touches it again -- which is correct only for syscalls
; that do not sleep.  A blocking accept DOES sleep, another task runs and its
; own syscalls repoint the pointer at ITS table, and on wake we are looking at
; the wrong one.  _Fcb_Alloc then scanned the peer's table, found the slot the
; peer had free, and handed back an fd that already belonged to this process's
; pty master -- two fds numbered 4, and send() on the socket returning EBADF.
;
; This is the first syscall in the tree that sleeps and THEN allocates an fd,
; which is why nothing had tripped it before: pipe.s sleeps too, but wakes into
; ring bookkeeping via the global _pipeTablePtr, never the per-task fd table.
;
; Same three loads the dispatcher does at entry.  MX %00.  Clobbers A, X.
;------------------------------------------------------------------------------
_Loop_RepointFdTable MX %00
                LDA     _curTask
                AND     #$00FF
                BEQ     @nl_rft_none
                JSR     _NlKC_TaskLookup
                BCC     @nl_rft_none
                LDA:    TCB_FdTablePtr,X
                STA     _fd_table_ptr
                SEP     #$20
                MX      %10
                LDA:    TCB_FdTablePtr+2,X
                STA     _fd_table_ptr+2
                REP     #$30
                MX      %00
@nl_rft_none    RTS

;------------------------------------------------------------------------------
; Kernel-bank statics (DBR-relative, like socket.s's _sock* set).
