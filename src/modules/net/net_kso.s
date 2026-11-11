;==============================================================================
; net_kso.s - UDP sockets on the kernel's network stack.  PUT by net.s.
;
; An AF_INET datagram socket is a 2.11BSD struct socket in the network modules
; (bsdnetd and bsdnet0-3).  net.mod keeps what it has always kept for it -- the
; system-call entry, the descriptor and the FCB -- and the descriptor carries
; XPORT_KSO and, in SOCK_KsoSo, the socket's offset in bsdnetd's bank.  Every
; op on such a descriptor comes here first and goes no further in this module:
; _Kso_Do hands the call to bsdnet's bn_sysent with a call block naming the
; syscall's registers, and src/kernel/bsdnet/machine/bn_sys.c turns that into
; the argument block uipc_syscalls.c's body reads.
;
; THE TEST COMES FIRST IN EACH OP, ahead of the AF_UNIX and loopback arms: a
; kernel socket bound to 127.0.0.1 is the kernel's, and _Loop_BindTry would
; otherwise claim it for net_loop.s's rings.
;
; Nothing in this module's scratch is read after a forward returns, because the
; forward may have slept and another process may have used the scratch.
;==============================================================================

BN_SYS_OFF      EQU     22              ; bsdnetd: bn_sys, the cell after bn_tap
                                        ;   (tools/build_bsdnet.py)

;------------------------------------------------------------------------------
; _Kso_Is - C=1 if the descriptor at _sockTmpOff is a kernel socket.  MX %00.
; Clobbers A, Y.
;------------------------------------------------------------------------------
_Kso_Is         MX      %00
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
                CMP     #XPORT_KSO
                BEQ     @ki_yes
                CLC
                RTS
@ki_yes         SEC
                RTS

;------------------------------------------------------------------------------
; _Kso_Try - the first thing an op does whose fd is _Sys_SavedX.  In: Y = the
; BNOP_*.  A kernel socket is forwarded and the OP returns from here (RTL);
; anything else RTSes with A, X, Y clobbered and _sockTmpOff possibly set.
; JSR'd from the op's first instruction, before it pushes anything.
;------------------------------------------------------------------------------
_Kso_Try        MX      %00
                PHY
                LDA     _Sys_SavedX
                AND     #$00FF
                JSL     SYS_NETKC_SOCKFDTODESC
                BCC     @kt_no                  ; not a socket: the op says so
                STY     _sockTmpOff
                JSR     _Kso_Is
                BCC     @kt_no
                PLY
                PLX                             ; the JSR's return: the op is done
                JSR     _Kso_Do
                RTL
@kt_no          PLY
                RTS

;------------------------------------------------------------------------------
; _Kso_TryOff - the same for an op whose descriptor the kernel already put in
; _sockTmpOff (read, write, shutdown).  In: Y = the BNOP_*.
;------------------------------------------------------------------------------
_Kso_TryOff     MX      %00
                PHY
                JSR     _Kso_Is
                BCC     @kto_no
                PLY
                PLX
                JSR     _Kso_Do
                RTL
@kto_no         PLY
                RTS

;------------------------------------------------------------------------------
; _Kso_Refuse - listen(2) and accept(2) on a kernel socket.  In: A = fd, Y =
; the errno: udp_usrreq answers PRU_LISTEN with EOPNOTSUPP, and accept on a
; socket that is not listening is EINVAL (uipc_syscalls.c accept).  Returns from
; the op with it, or RTSes for any other descriptor.
;------------------------------------------------------------------------------
_Kso_Refuse     MX      %00
                PHY
                AND     #$00FF
                JSL     SYS_NETKC_SOCKFDTODESC
                BCC     @kr_no
                STY     _sockTmpOff
                JSR     _Kso_Is
                BCC     @kr_no
                PLA                             ; the errno
                PLX                             ; the JSR's return
                CLC
                RTL
@kr_no          PLY
                RTS

;------------------------------------------------------------------------------
; _Kso_Do - call bn_sysent for the descriptor at _sockTmpOff.  In: Y = BNOP_*.
; Out: C=1 + A = the call's value + X = its second value, or C=0 + A = errno.
;
; The call block goes on this stack, which is the caller's kernel slot, and
; bn_sys.c reads it through a bank-0 pointer as its struct bncall:
;   +0 op  +2 so  +4 A  +6 X  +8 Y  +10 bank  +12 uio  +14 uio bank  +16 nb
; It is pushed last field first, so it reads upward.
;------------------------------------------------------------------------------
_Kso_Do         MX      %00
                PHY
                LDA     _sockTmpOff
                CLC
                ADC     #SOCK_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                REP     #$20
                MX      %00
                AND     #SOCK_NB
                PLY
                PHA                             ; +16 nb
                LDA     _sockUioBank            ; +14
                PHA
                LDA     _sockUio                ; +12
                PHA
                LDA     _Sys_CallerBank
                AND     #$00FF
                PHA                             ; +10 bank
                LDA     _Sys_SavedY             ; +8
                PHA
                LDA     _Sys_SavedX             ; +6
                PHA
                LDA     _Sys_SavedA             ; +4
                PHA
                JSR     _Kso_SoOp               ; +2 so, +0 op
                JSR     _Kso_Call
                PLY                             ; nine words; PLY keeps A, X and C
                PLY
                PLY
                PLY
                PLY
                PLY
                PLY
                PLY
                PLY
                RTS

; _Kso_DoIoctl - the 'i' group: the command in X, the ifreq's far pointer in Y
; and bank.  In: _sockTmpOff.  Out as _Kso_Do.
_Kso_DoIoctl    MX      %00
                PEA     0                       ; +16 nb
                PEA     0                       ; +14
                PEA     0                       ; +12
                LDA     _Sys_IoctlArgBank
                AND     #$00FF
                PHA                             ; +10 bank
                LDA     _Sys_IoctlArgLo         ; +8 Y
                PHA
                LDA     _Sys_IoctlCmd           ; +6 X
                PHA
                PEA     0                       ; +4 A
                LDY     #BNOP_IOCTL
                JSR     _Kso_SoOp
                JSR     _Kso_Call
                PLY
                PLY
                PLY
                PLY
                PLY
                PLY
                PLY
                PLY
                PLY
                RTS

; _Kso_IfChanged - tell the kernel's stack the interface's address changed
; (SYS_IFCONFIG's IFC_SET, net_op_ifconfig).  No descriptor: the block is all
; zero but its op.  Without the modules, or if the stack refuses, the chip has
; the address all the same and this is silent.  MX %00.  Clobbers A, X, Y.
_Kso_IfChanged  MX      %00
                LDX     #8                      ; +16 .. +2, eight words of 0
@kic_z          PEA     0
                DEX
                BNE     @kic_z
                PEA     BNOP_IFCHANGED          ; +0 op
                JSR     _Kso_Call
                LDX     #9
@kic_p          PLY
                DEX
                BNE     @kic_p
                RTS

; _Kso_SoOp - push +2 so and +0 op UNDER this routine's own return address,
; which it moves down, so the caller's block stays contiguous.  In: Y = op.
_Kso_SoOp       MX      %00
                PHY                             ; the op, while so is read
                LDA     _sockTmpOff
                CLC
                ADC     #SOCK_KsoSo
                TAY
                LDA     [_sockTablePtr],Y
                TAX                             ; so
                PLY                             ; op
                PLA                             ; our return address
                PHX                             ; +2 so
                PHY                             ; +0 op
                PHA                             ; return address on top again
                RTS

;------------------------------------------------------------------------------
; _Kso_Call - JSL bn_sysent with A = the call block's offset in bank 0.  MX %00.
; The block starts above this routine's return address.  bn_sysent's address
; is the far pointer bsdnetd keeps in its bn_sys cell; with no modules
; registered there is no kernel socket to have reached here, and this answers
; EPROTONOSUPPORT rather than jump nowhere.
;------------------------------------------------------------------------------
_Kso_Call       MX      %00
                LDA     #VT_BSDNET
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @kc_have
                LDA     #EPROTONOSUPPORT
                CLC
                RTS
@kc_have        CLC
                ADC     #BN_SYS_OFF
                STA     _libcTmp2
                TXA
                SEP     #$20
                MX      %10
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDA     [_libcTmp2]             ; the cell's offset in bsdnetd
                STA     _libcTmp2
                LDY     #2
                LDA     [_libcTmp2],Y           ; bn_sysent's bank
                TAX
                LDA     [_libcTmp2]             ; and its offset
                DEC                             ; less one: RTL adds it back
                STA     _libcTmp2
                TXA
                SEP     #$20
                MX      %10
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                PHK                             ; return to @kc_ret
                PEA     @kc_ret-1
                SEP     #$20
                MX      %10
                LDA     _libcTmp2+2
                PHA                             ; bn_sysent's bank
                REP     #$20
                MX      %00
                PEI     _libcTmp2               ; and offset - 1
                TSC                             ; the block: past these 6 bytes
                CLC                             ;   and our return's 2
                ADC     #6+2+1
                RTL                             ; -> bn_sysent
@kc_ret         RTS
