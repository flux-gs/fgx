;==============================================================================
; socket.s - kernel-resident socket residue (② net-mod reclaim Phase 2).
;
; The BSD socket layer (SYS_SOCKET/BIND/SENDTO/RECVFROM/SETSOCKOPT/CONNECT/
; SEND/RECV/LISTEN/ACCEPT handlers + the _Sock_FdToDesc/_Sock_NewConnFd/
; _Sock_EnsureBound/_Sock_CheckSrcAddr helpers) MOVED to net.mod
; (src/modules/net/net.s, the net_op_* table); the kernel keeps thin dispatch
; thunks (net_dispatch.s) that route #71-78/84/85 into the module.
;
; What STAYS kernel-resident here:
;   - _AllocSockTable: boot Kmalloc of the descriptor table (allocated
;     kernel-side; the module reaches it via the _sockTablePtr DP long-ptr).
;   - _Sock_Teardown: routed from Fs_Close's FCB_FL_SOCKET branch; calls the
;     (kernel) transport close + _W5_SockFree.
;   - the _sock* scratch block: read+written by BOTH the moved net.mod handlers
;     (DBR-relative via the gen_kernel_exports manifest) AND the kept kernel
;     transport cores (uthernet.s) + _Sock_PollIntr's cross-block save/restore.
;
; The socket-descriptor table is a Kmalloc'd soft-global reached via the DP
; long-pointer _sockTablePtr (dpmap.s); records are SOCK_* (include/socket.s),
; one per W5100 hardware socket, accessed [_sockTablePtr],Y.
;
; PUT by src/kernel/main.s.
; Spec: docs/superpowers/specs/2026-06-05-fgx-udp-sockets-dhclient-design.md
;==============================================================================

;==============================================================================
; _AllocSockTable - Kmalloc(SOCKTBL_BLK_SIZE, M_KERN) -> _sockTablePtr (DP).
; Mirrors _AllocIfTable.  Boot, after _AllocIfTable.
;==============================================================================
_AllocSockTable MX      %00
                PHP
                REP     #$30
                LDA     #SOCKTBL_BLK_SIZE
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @ast_ok
                LDA     #_panic_msg_socktbl
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
@ast_ok         LDA     _kmallocResult
                STA     _sockTablePtr
                SEP     #$20
                LDA     _kmallocResult+2
                STA     _sockTablePtr+2
                REP     #$20
                JSR     _SoftGlob_ValidatePtr   ; always-on heap-ptr panic
                LDY     #0                      ; zero the table
                SEP     #$20
                LDA     #0
@ast_zL         STA     [_sockTablePtr],Y
                INY
                CPY     #SOCKTBL_BLK_SIZE
                BCC     @ast_zL
                REP     #$20
                PLP
                RTS

_panic_msg_socktbl ASC  'PANIC: cannot alloc sockTable',00

;==============================================================================
; (_Sock_Teardown MOVED to net.mod — net_op_sockteardown — Phase 3, since it
; calls the now-in-module _Net_Xport_Close + _W5_SockFree.  Fs_Close's
; FCB_FL_SOCKET branch dispatches NETOP_SockTeardown into the module.)
;==============================================================================

;==============================================================================
; _Sock_FdToDesc - resolve a socket fd to its descriptor + hw socket.
; In: A = fd.  MX %00.  Out: C=1 + Y = descriptor offset + _sockTmpHw = hw idx,
; or C=0 + A = EBADF.  STAYS kernel-side: used by BOTH net.mod's socket handlers
; (via the _Net_KCall_SockFdToDesc wrapper) AND the kernel read/write seam
; (_RdOp_Socket/_WrOp_Socket in syscall.s).
;==============================================================================
_Sock_FdToDesc  MX      %00
                SEP     #$20
                MX      %10
                JSR     _Fcb_LookupPtr          ; A=fd (M=1) -> C=1 + _fcbPtr / C=0 EBADF
                BCC     @s2d_bad
                LDY     #FCB_Flags
                LDA     [_fcbPtr],Y
                BIT     #FCB_FL_SOCKET
                BEQ     @s2d_notsock
                LDY     #FCB_SockIdx
                LDA     [_fcbPtr],Y             ; descriptor offset (byte)
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY                             ; Y = descriptor offset
                PHY
                INY                             ; SOCK_HwIdx
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     _sockTmpHw
                PLY                             ; Y = descriptor offset
                SEC
                RTS
@s2d_notsock    REP     #$20
                MX      %00
                LDA     #EBADF
                CLC
                RTS
@s2d_bad        REP     #$20
                MX      %00
                AND     #$00FF                  ; A = EBADF from _Fcb_LookupPtr
                CLC
                RTS

;------------------------------------------------------------------------------
; socket-core scratch (bounded module-local statics; syscall context).  Layout
; MUST be stable: the kernel transport cores (uthernet.s) read these directly,
; net.mod's handlers read+write them DBR-relative via the manifest, and
; _Sock_PollIntr saves/restores the contiguous block across a blocking _sleep.
;------------------------------------------------------------------------------
_sockSrcOff     DS      2               ; recvfrom: caller src-sockaddr offset
_sockSrcIp      DS      4               ; recvfrom: datagram src IP (net order)
_sockSrcPort    DS      2               ; recvfrom: datagram src port (net order)
_sockRxLen      DS      2               ; recvfrom: datagram payload length
_sockCapLen     DS      2               ; recvfrom: bytes actually copied
_sockTmpHw      DS      2               ; hw-socket index being allocated
_sockTmpOff     DS      2               ; descriptor byte-offset being allocated
_sockTmp2       DS      2               ; port / general scratch
_sockTmpTag     DS      2               ; socket(): resolved transport tag
_sockTmpProto   DS      2               ; socket(): proto arg (Y) staged
_sockRecvFlags  DS      2               ; recv(): MSG_* flags for this call
_sockSendFlags  DS      2               ; send(): MSG_* flags for this call
_sockOptLevel   DS      2               ; setsockopt(): level
_sockOptName    DS      2               ; setsockopt(): option name
_sockOptLen     DS      2               ; setsockopt(): optlen
_sockOptVal     DS      2               ; setsockopt(): *(int *)optval
_sockRingRun    DS      2               ; TX/RX ring-wrap: first-run byte count
_w5RxHdrLen     DS      2               ; W5100 RX header length (8 UDP / 6 IPRAW)
_sockBindAddr   DS      4               ; raw bind(): staged sin_addr for validation
_sockBufOff     DS      2               ; sendto/recvfrom: user buffer offset
_sockLen        DS      2               ; payload length
_sockDstIp      DS      4               ; sendto: dst IP (network order)
_sockDstPort    DS      2               ; sendto: dst port (network order hi,lo)
_sockTxWr       DS      2               ; W5100 Sn_TX_WR working value
_sockTxBase     DS      2               ; W5100 TX buffer base for this hw socket
_sockPhys       DS      2               ; W5100 physical TX/RX buffer address
_sockUio        DS      2               ; the caller's struct uio, a far pointer:
_sockUioBank    DS      2               ;   offset, then bank.  sosend/soreceive
                                        ;   move the data through it, and a TCP
                                        ;   wait sleeps between staging and copy,
                                        ;   so it is saved with the block.
; Whole contiguous _sock* scratch block (_sockSrcOff.._sockPhys).  _Sock_PollIntr
; saves/restores it on the per-task kernel stack across a blocking _sleep so
; concurrent socket users don't clobber each other's cross-block state.  Self-
; computing — stays correct if fields are added/removed above.
_SOCK_SCRATCH_LEN EQU   *-_sockSrcOff
; Outside the saved block (set + used after the accept block, no _sleep between):
_sockAcceptLOff DS      2               ; accept(): listener desc offset (to detach)
_soHasDst       DS      2               ; 1 = sendto(): _sockDstIp/_sockDstPort name
                                        ;   the destination.  Read before any sleep.
_soBounce       DS      4               ; the W5100 bounce buffer, a far pointer
                                        ;   (offset, bank, pad); 0 until first use
; net.mod derives its own copy of the length as _sockAcceptLOff-_sockSrcOff, so
; this cell must be the FIRST one past the block or the two disagree and
; _Sock_PollIntr saves the wrong byte count.  Separate assembly units, so each
; side asserts its half.
                ERR     _sockAcceptLOff-_sockSrcOff-_SOCK_SCRATCH_LEN
