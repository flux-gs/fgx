;==============================================================================
; socket.s - the core bank's part of the socket calls.  PUT by main.s.
;
; Every socket is a 2.11BSD struct socket in the network modules, and its FCB
; names it (FCB_SockSo, its offset in their data bank).  The calls themselves
; are net.mod's (src/modules/net/net.s, net_kso.s), reached through the thunks
; in net_dispatch.s; what stays here is the fd lookup the core's read, write,
; ioctl, select and shutdown seams share with net.mod, and the cells they pass
; through.
;==============================================================================

;==============================================================================
; _Sock_FdToDesc - resolve a socket fd.  In: A = fd.  MX %00.
; Out: C=1 + _sockTmpSo = the fd's socket; or C=0 + A = EBADF, for a bad fd or
; one that is not a socket.  Used by net.mod's ops (through
; _Net_KCall_SockFdToDesc) and by the core's read/write/ioctl/select/shutdown.
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
                REP     #$20
                MX      %00
                LDY     #FCB_SockSo
                LDA     [_fcbPtr],Y
                STA     _sockTmpSo
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
; The cells a socket call passes through (syscall context; net.mod reads and
; writes them DBR-relative through its kernel_exports.s).  Nothing reads one
; after a call into the network modules returns, because that call may sleep and
; another task's call rewrite it -- except _sockTmpSo, which net_kso.s's _Kso_Do
; keeps on the caller's stack and puts back.
;------------------------------------------------------------------------------
_sockTmpSo      DS      2               ; the fd's struct socket (_Sock_FdToDesc)
_sockRxLen      DS      2               ; FIONREAD's count, from select's poll
_sockUio        DS      2               ; read/write's struct uio, a far pointer:
_sockUioBank    DS      2               ;   offset, then bank

; An AF_UNIX name's op and socket for KSVC_UNPNAME (jumptable.s), written by the
; network modules' kc_unpname.
_unpNameOp      DS      2               ; UNP_OP_BIND / LOOKUP / UNBIND
_unpSlot        DS      2               ; the socket: in for bind and unbind,
                                        ;   out for lookup

; KSVC_UNPFILE's block (jumptable.s), written and read by the network modules'
; kc_unpfile: op, three arguments, then four results (vfs_file.c unp_fileop).
_unpfArgs       DS      16
