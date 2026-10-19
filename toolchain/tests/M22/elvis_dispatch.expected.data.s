;---------------------------------------
; fcc 0.0 — data segment for elvis_dispatch.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
tbl             FGX2_LONG_PTR _Sa;_elvis_dispatch_S0;0
                FGX2_LONG_PTR _Fa;add5;0
                FGX2_LONG_PTR _Sa;_elvis_dispatch_S1;0
                FGX2_LONG_PTR _Fa;add37;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _elvis_dispatch_S0
_elvis_dispatch_S0             HEX     61,00
                FGX2_EXPORT _elvis_dispatch_S1
_elvis_dispatch_S1             HEX     62,00
                FGX2_RELOC_COUNT 7
