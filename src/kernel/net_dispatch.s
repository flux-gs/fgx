;==============================================================================
; net_dispatch.s - NET op dispatch helpers (net.mod, the kernel side).
;
; Direct clone of fst_dispatch.s (the FST FOP dispatcher): the kernel's
; networking syscall thunks reach net.mod's resident net_op_table through here.
; Two entry points:
;
;   _Net_LoadOpsPtr   Look up VT_NET in the module registry, populate
;                     _net_ops_save (kernel-bank static triple) with bank:voffset
;                     of net_op_table.  C=1 ok / C=0+A=ENOSYS if unregistered
;                     (net.mod not loaded — the thunks then return ENOSYS).
;
;   _Net_Dispatch     Given Y = NETOP byte offset (0/3/6/...), self-patch a
;                     5-byte LDAL/RTS cell to read the op's voffset out of
;                     net_op_table, patch a JSL/RTL cell with it (the JSL bank
;                     comes from the registry, _net_ops_save+2, NOT the table's
;                     baked ^ byte), JSL through.
;                     The op runs in net.mod's bank with DBR = the live kernel
;                     bank ($20 under reloc, $02 legacy) + kernel DP, and RTLs
;                     back.  Returns whatever the op returned (A+C).  RELOC: the
;                     _netReadOp self-modifying cell is patched DBR-relative (it
;                     executes via JSR at PB == DBR == kernel bank); _net_ops_save
;                     is reached DBR-relative too (`|` abs at the live kernel bank,
;                     $20 under reloc; $02 = assembly ORG) everywhere, incl. the
;                     _NetThunkExec gate — a plain LDA there read the wrong copy.
;
; Op args: _Net_Dispatch clobbers A (preserves X), so net ops read their
; syscall args from the dispatcher's _Sys_Saved* statics (and _Sys_CallerBank),
; NOT the live registers — exactly as FST FOPs read kernel statics.
;
; No DP scratch (same rationale as fst_dispatch.s).
;==============================================================================

                MX      %00

;------------------------------------------------------------------------------
; _Net_LoadOpsPtr - resolve VT_NET and load _net_ops_save.
; In: nothing.  MX %00.  Out: C=1 + _net_ops_save populated, or
; C=0 + A=ENOSYS (also leaves the bank byte 0 so the thunks can detect it).
; Preserves caller M/X via PHP/PLP.  Clobbers A, X, Y.
;------------------------------------------------------------------------------
_Net_LoadOpsPtr     ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                LDA     #VT_NET
                JSR     Mod_FindVtable
                BCC     @nlo_miss
                ; Hit: A = voffset (16-bit), X.lo = bank.
                STA     |_net_ops_save          ; lo+mid (16-bit) — DBR-rel ($20)
                SEP     #$20
                MX      %10
                TXA
                STA     |_net_ops_save+2        ; bank
                REP     #$20
                MX      %00
                PLP
                SEC
                RTS
@nlo_miss       SEP     #$20                    ; net.mod absent: zero the bank
                MX      %10                     ; byte so thunks detect ENOSYS
                LDA     #$00
                STA     |_net_ops_save+2
                REP     #$20
                MX      %00
                PLP
                CLC
                LDA     #ENOSYS
                RTS

;------------------------------------------------------------------------------
; _Net_Dispatch - JSL through a net_op_table slot.
; In: Y = NETOP byte offset (multiple of 3).  _net_ops_save must be set.
; Out: whatever the op returned (C=1 ok / C=0+A=errno).  Y clobbered, A used.
; MX %00 in/out.  Preserves DBR.  No DP scratch.
;------------------------------------------------------------------------------
_Net_Dispatch       ENT
                MX      %00
                PHY                             ; stash Y (op offset) on stack
                LDA     |_net_ops_save          ; A = voffset (16-bit) — DBR-rel ($20)
                CLC
                ADC     1,S                     ; + Y (still on stack)
                STA    |_netReadOp+1            ; patch operand lo+mid (DBR=$20, the
                                                ;   copy JSR _netReadOp executes; STAL
                                                ;   $02 here would split under reloc)
                SEP     #$20
                MX      %10
                LDA     |_net_ops_save+2        ; A = bank — DBR-rel ($20)
                STA    |_netReadOp+3            ; patch operand bank (DBR-rel, as above)
                REP     #$20
                MX      %00
                JSR     _netReadOp              ; A = net_op_table[Y..Y+1]
                STAL    _netTrampJSL+1          ; trampoline lo+mid (bank-0 gateway: STAL ok)
                ; JSL TARGET BANK = net.mod's RUNTIME bank (_net_ops_save+2, where net_op_table
                ; AND its op functions live).  Do NOT read the op table's stored ^ bank byte
                ; (net_op_table[Y+2]): it bakes net.mod's build bank and is correct today ONLY
                ; because net.mod self-patches its table at mod_init (net.s) — reading the
                ; registry bank here removes that dependency and is robust if a future VT_NET
                ; module ever skips that self-patch.  Same class as the fst_dispatch/chardev fix.
                SEP     #$20
                MX      %10
                LDA    |_net_ops_save+2         ; net.mod runtime bank
                STAL    _netTrampJSL+3          ; trampoline bank
                REP     #$20
                MX      %00
                PLY                             ; restore stack (Y don't-care)
                JSL     _netTrampJSL            ; -> net op -> RTL back here
                RTS

;==============================================================================
; Syscall thunks — the dispatch-table entries for the networking syscalls that
; now live in net.mod.  Each checks net.mod is registered (else ENOSYS), then
; routes into the module via _Net_Dispatch with the op's NETOP_* offset.  The
; ops read their args from _Sys_Saved*/_Sys_CallerBank, so the thunk needn't
; preserve A/X.  (Phase 1: SYS_IFCONFIG only; socket thunks arrive in Phase 2.)
;==============================================================================

;==============================================================================
; Module->kernel call trampolines.  net.mod runs in its own bank (PB), so it
; reaches a kernel routine by JSL to a build-resolved address (manifest).  But
; the kernel's helpers are JSR/RTS-terminated, and a JSL onto an RTS routine
; corrupts the stack (JSL pushes 3 bytes, RTS pops 2).  These thin RTL wrappers
; bridge it: the module JSLs the wrapper, the wrapper JSRs the real routine
; (same-bank, RTS) and RTLs back.  Same role as the $00:032E bank-0 JT-gateway slots,
; co-located here for the net seam.  (More wrappers arrive with Phases 2-3:
; _sleep / _Fcb_* / Fs_* / Con_PollKey etc.)
;------------------------------------------------------------------------------
; _Net_KCall_W5WriteIp - net.mod IFC_SET pushes the slot-1 IP config to the
; W5100 (_W5_WriteIpFromRec, uthernet.s).  MX %00; reads _ifS1Off/_ifTablePtr.
;------------------------------------------------------------------------------
_Net_KCall_W5WriteIp ENT
                MX      %00
                JSR     _W5_WriteIpFromRec
                RTL

;------------------------------------------------------------------------------
; Wrappers for the kernel routines net.mod still calls (after Phase 3 moved the
; transport in-module, only these remain kernel-side).  Each `JSR <rtn> / RTL`
; bridges a module JSL to a JSR/RTS kernel routine.
;   _Net_KCall_FcbAlloc / FcbLookup-not-needed / SockFdToDesc - FCB + socket-fd
;     resolution (socket() / accept() / the read-write seam).
;   _Net_KCall_ConPollKey / _Net_KCall_Sleep - for the now-in-module
;     _Sock_PollIntr (cooperative block: ^C poll + _sleep on WCHAN_SOCK).
;------------------------------------------------------------------------------
_Net_KCall_FcbAlloc ENT
                MX      %00
                JSR     _Fcb_Alloc
                RTL
; _Sock_FdToDesc stays kernel-side (shared with the read/write seam); net.mod's
; handlers reach it here.  MX %00; In A=fd, Out C=1 + Y=desc off + _sockTmpHw.
_Net_KCall_SockFdToDesc ENT
                MX      %00
                JSR     _Sock_FdToDesc
                RTL
_Net_KCall_ConPollKey ENT
                MX      %00
                JSR     _Tty_CurIsFg            ; bg socket op? return "no key" so a
                BCC     @nkcp_bg               ;   backgrounded job can't grab ^C /
_kfp106         JSL     KFAR_CON_POLLKEY        ;   steal the fg shell's keystrokes
                RTL
@nkcp_bg        LDA     #0
                CLC
                RTL
_Net_KCall_Sleep ENT
                MX      %00
                JSR     _sleep
                RTL

;------------------------------------------------------------------------------
; _NetThunkExec - In: Y = NETOP offset (MX %00).  If net.mod is registered,
; tail-JMP _Net_Dispatch (its RTS returns through the thunk to the dispatcher);
; else A=ENOSYS, C=0.  Y survives the bank-byte read.
;------------------------------------------------------------------------------
_NetThunkExec   MX      %00
                SEP     #$20                    ; net.mod loaded? (ops bank != 0)
                MX      %10
                LDA     |_net_ops_save+2        ; DBR-rel ($20) — consistent with the
                                                ;   DBR-rel writes in _Net_LoadOpsPtr and
                                                ;   reads in _Net_Dispatch (was baked $02
                                                ;   on both sides; now all live $20 and
                                                ;   zero-init by _KMem_ClearGlobals).
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @nte_nosys
                JMP     _Net_Dispatch           ; Y = NETOP; -> op -> RTS to the thunk
@nte_nosys      LDA     #ENOSYS
                CLC
                RTS

;------------------------------------------------------------------------------
; Syscall thunks: dispatch-table entries (#70-78, 84, 85) -> net.mod ops.
; The dispatch-table rows in syscall.s keep these same names, so no table edit.
;------------------------------------------------------------------------------
_Sys_Ifconfig   ENT
                MX      %00
                LDY     #NETOP_Ifconfig
                JSR     _NetThunkExec
                RTS
_Sys_Socket     ENT
                MX      %00
                LDY     #NETOP_Socket
                JSR     _NetThunkExec
                RTS
_Sys_Bind       ENT
                MX      %00
                LDY     #NETOP_Bind
                JSR     _NetThunkExec
                RTS
_Sys_Sendto     ENT
                MX      %00
                LDY     #NETOP_Sendto
                JSR     _NetThunkExec
                RTS
_Sys_Recvfrom   ENT
                MX      %00
                LDY     #NETOP_Recvfrom
                JSR     _NetThunkExec
                RTS
_Sys_Setsockopt ENT
                MX      %00
                LDY     #NETOP_Setsockopt
                JSR     _NetThunkExec
                RTS
_Sys_Connect    ENT
                MX      %00
                LDY     #NETOP_Connect
                JSR     _NetThunkExec
                RTS
_Sys_Send       ENT
                MX      %00
                LDY     #NETOP_Send
                JSR     _NetThunkExec
                RTS
_Sys_Recv       ENT
                MX      %00
                LDY     #NETOP_Recv
                JSR     _NetThunkExec
                RTS
_Sys_Listen     ENT
                MX      %00
                LDY     #NETOP_Listen
                JSR     _NetThunkExec
                RTS
_Sys_Accept     ENT
                MX      %00
                LDY     #NETOP_Accept
                JSR     _NetThunkExec
                RTS
_Sys_GetPeerName ENT
                MX      %00
                LDY     #NETOP_GetPeerName
                JSR     _NetThunkExec
                RTS
_Sys_GetSockName ENT
                MX      %00
                LDY     #NETOP_GetSockName
                JSR     _NetThunkExec
                RTS

;------------------------------------------------------------------------------
; _netReadOp - 5-byte self-modifying LDAL/RTS cell (see fst_dispatch.s).
;------------------------------------------------------------------------------
_netReadOp      DFB     $AF,$00,$00,$00         ; LDAL <addr>
                DFB     $60                     ; RTS

;------------------------------------------------------------------------------
; _netTrampJSL - 5-byte self-modifying JSL trampoline.
;------------------------------------------------------------------------------
; _netTrampJSL is now a bank-0 FGX_INTVEC gateway cell (include/memmap.s): the
; `JSL _netTrampJSL` + STAL patches target a fixed bank-0 address that survives
; kernel relocation; its $22/$6B opcodes are written once by _JT_Init.

;==============================================================================
; END net_dispatch.s
;==============================================================================
