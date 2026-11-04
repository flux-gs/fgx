;==============================================================================
; net_asm.s - the network code's assembly in bsdnet0: the C-to-kernel seam the
; other kernel modules share, unchanged.  kc_sys.s only moves D, and reads a C
; string through the caller's DBR, which is the data bank where C's strings are.
; tools/build_bsdnet.py PUTs that file first: a macro from a nested PUT is not
; visible to the file that PUT it.
;==============================================================================
_modFnPtrTab    ANOP
_modFnPtrBytes  EQU     0

; kc_printstr(s) - log a string with no newline handling of its own.
kc_printstr     MX      %00
                ENTERK
                LDA     6,S
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                LEAVEK
                RTL

;------------------------------------------------------------------------------
; spl.  The 65816 has one mask, so what these return is the I bit as it was and
; splx puts it back, as kc_spltty does in the tty bank.
;
; splnet MASKS NOTHING.  It exists on the PDP-11 to hold off the network software
; interrupt, and netintr runs only at the kernel's deferred-work drain, which no
; kernel code reaches until it sleeps.  So a region at splnet cannot be entered,
; and masking through TCP processing would stop the VBL.  Nothing may call
; protocol code from an interrupt while this holds.
;
; splimp and splhigh set I: they guard what the driver touches at interrupt time.
;------------------------------------------------------------------------------
splimp          MX      %00
                PHP
                SEI
                SEP     #$20
                MX      %10
                PLA
                AND     #$04
                REP     #$20
                MX      %00
                AND     #$00FF
                RTL

splhigh         MX      %00
                PHP
                SEI
                SEP     #$20
                MX      %10
                PLA
                AND     #$04
                REP     #$20
                MX      %00
                AND     #$00FF
                RTL

splnet          MX      %00
                PHP
                SEP     #$20
                MX      %10
                PLA
                AND     #$04
                REP     #$20
                MX      %00
                AND     #$00FF
                RTL

splx            MX      %00
                LDA     4,S
                AND     #$0004
                BNE     @sx_keep
                CLI
                RTL
@sx_keep        SEI
                RTL

;------------------------------------------------------------------------------
; The drain's two doors, in the tty bank (src/kernel/tty/net_hooks.s).  The kernel
; bank comes from SYS_KCALL's bank-0 JML cell, so nothing here needs a core entry.
;------------------------------------------------------------------------------
setsoftnet      MX      %00
_nhSoft         JSL     KTTY_NET_SOFT   ; the bank byte is stamped by net_hookinit
                RTL

; net_hookinit() - stamp that JSL and hand the drain netintr_enter.
net_hookinit    MX      %00
                PHB
                PHK
                PLB
                SEP     #$20
                MX      %10
                LDAL    SYS_KCALL+3     ; the live kernel bank
                CLC
                ADC     #2              ; the tty bank
                STA     |_nhSoft+3
                STA     |@hook+3
                PHK
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                LDA     #netintr_enter
@hook           JSL     KTTY_NET_HOOK
                PLB
                RTL

; netintr_enter - the drain calls this.  D is already kernel C's: the tty bank's
; bracket set it.  DBR is set here to the data bank.
netintr_enter   MX      %00
                PHB
                PHK
                PLB
                SEP     #$20
                MX      %10
                LDA     |_bnDataBank
                PHA
                PLB
                REP     #$20
                MX      %00
                PHK
                PEA     @ret-1
                PHK
                PEA     netintr-1
                RTL
@ret            PLB
                RTL
