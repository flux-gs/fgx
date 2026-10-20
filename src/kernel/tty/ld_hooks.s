;==============================================================================
; ld_hooks.s - the kernel's side of shared-library residency (shared libc SP4
; spec, sections 4 and 6).  The core calls these through tty-bank export
; slots 49-54; each calls LD_TRAMP, the bank-0 JML ld.mod points at its
; dispatcher.  Until ld.mod loads, LD_TRAMP holds _Ld_Absent's address.
; Bare bodies: immediates and JSL LD_TRAMP only, so no DBR or D of their own.
;==============================================================================

; _Ld_Absent - LD_TRAMP's target while no ld.mod is loaded: a service is
; ENOSYS, a hook does nothing (RECLAIM: nothing freed).  A/X/Y preserved for
; a hook.
_Ld_Absent      MX      %00
                CMP     #LDH_EXIT
                BCS     @la_hook
                LDA     #ENOSYS
@la_hook        CLC
                RTL

; _Ld_Ctl (KTTY_LD_CTL) - SYS_LDCTL's body.  In: A = service, X/Y = block
; offset/bank.  A hook selector from user code is ENOSYS, never a hook.
_Ld_Ctl         MX      %00
                CMP     #LDS_COUNT
                BCC     @lc_go
                LDA     #ENOSYS
                CLC
                RTL
@lc_go          JSL     LD_TRAMP
                RTL

; _Ld_Exit / _Ld_Fork / _Ld_Exec / _Ld_Talloc (KTTY_LD_EXIT .. TALLOC) - A =
; the pid, whose high byte is not always clear at the call sites, so it is
; masked here; X/Y preserved.
_Ld_Exit        MX      %00
                PHY
                LDY     #LDH_EXIT
                BRA     _Ld_Hook
_Ld_Fork        MX      %00
                PHY
                LDY     #LDH_FORK
                BRA     _Ld_Hook
_Ld_Exec        MX      %00
                PHY
                LDY     #LDH_EXEC
                BRA     _Ld_Hook
_Ld_Talloc      MX      %00
                PHY
                LDY     #LDH_TALLOC
_Ld_Hook        PHX
                AND     #$00FF
                PHA
                TYA                             ; A = the selector
                PLY                             ; Y = the pid
                JSL     LD_TRAMP
                PLX
                PLY
                RTL

; _Ld_Reclaim (KTTY_LD_RECLAIM) - C=1 when ld.mod gave a bank back.  Bank_Alloc's
; dry-pool chain calls it.  Clobbers A/X, preserves Y.
_Ld_Reclaim     MX      %00
                PHY
                LDA     #LDH_RECLAIM
                JSL     LD_TRAMP
                PLY                             ; PLY leaves the carry alone
                RTL
