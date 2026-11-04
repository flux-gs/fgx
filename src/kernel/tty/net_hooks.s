;==============================================================================
; net_hooks.s - the network code's seat at the deferred-work drain.
;
; netintr runs where the tty bank's soft output work runs, at the sites that call
; _Tty_DrainOutPend: syscall exit and the idle loop.  No C context is live at
; either, so the shared kernel-C register file is free.  Both exist already and
; test one word, so a kernel with no network modules loaded pays nothing new.
;
; A module reaches these slots from the live kernel bank + 2, and takes that bank
; from SYS_KCALL's bank-0 JML cell.
;==============================================================================
_netDrainVec    DS      2               ; netintr_enter, in its module
_netDrainBank   DS      2               ; 0 until the network modules load

; _Net_SetSoft (KTTY_NET_SOFT) - ask for the next drain.  Safe from an interrupt:
; _Tty_DrainOutPend clears the summary before it looks.  Clobbers A.
_Net_SetSoft    MX      %00
                LDA     #1
_ctp080         STAL    _kTtyOutAny
                RTL

; _Net_Hook (KTTY_NET_HOOK) - A = the entry's offset, X = its bank.
_Net_Hook       MX      %00
                PHB
                PHK
                PLB
                STA     |_netDrainVec
                STX     |_netDrainBank
                PLB
                RTL

; _Net_TtDrain (slot 39) - kc_ttdrain, then the network's entry when there is one.
; A = lines restarted, kc_ttdrain's answer, which the core's probes read.  DBR is
; this bank: KTTY_KC_ENTER set it.
_Net_TtDrain    MX      %00
                PHK
                PEA     @ret-1
                JMP     kc_ttdrain
@ret            PHA
                LDA     |_netDrainBank
                BEQ     @none
                PHK
                PEA     @back-1
                SEP     #$20
                MX      %10
                LDA     |_netDrainBank
                PHA
                REP     #$20
                MX      %00
                LDA     |_netDrainVec
                DEC
                PHA
                RTL
@back           PHK
                PLB
@none           PLA
                RTL
