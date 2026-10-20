;---------------------------------------
; fcc 0.0 — data segment for externafter.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
a               DA      $0028
b               DS      2
c               DS      2
p               FGX2_LONG_PTR _Sg;_externafter_S0;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _externafter_S0
_externafter_S0             HEX     78,00
                FGX2_RELOC_COUNT 3
