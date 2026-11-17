;==============================================================================
; net_kcall.s - pipe.s's calls into the kernel.  PUT by net.s.
;
; Three routes, and which one a call takes is not a style choice:
;   - SYS_NETKC_* : bank-0 JT slots that already existed for net.mod;
;   - SYS_KCALL   : the multiplexed service slot, X = service number;
;   - nothing     : Kmalloc/Kern_LogStr/_Halt/_SoftGlob_ValidatePtr were only
;                   ever called from _AllocPipeTable, which stays in the core
;                   bank -- so they are not here at all.
;
; Each shim keeps the caller's register contract exactly as a kernel JSR does.
;==============================================================================
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

