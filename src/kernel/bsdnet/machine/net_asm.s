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
