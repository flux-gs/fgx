;---------------------------------------
; fcc 0.0 — data segment for pp_paste.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
var123          DA      $0014
xONE            DA      $000F
x1              DA      $0007
cat3_obj        DA      $0000

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _pp_paste_S0
_pp_paste_S0             HEX     61,62,63,00
                FGX2_EXPORT _pp_paste_S1
_pp_paste_S1             HEX     4F,4E,45,00
                FGX2_EXPORT _pp_paste_S2
_pp_paste_S2             HEX     61,20,22,71,5C,6E,22,20,62,00
                FGX2_RELOC_COUNT 4
