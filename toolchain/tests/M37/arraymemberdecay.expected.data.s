;---------------------------------------
; fcc 0.0 — data segment for arraymemberdecay.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
vd              DS      64
vl              DS      54
vu              DS      18
vf              DS      18
vp              DS      18
vi              DS      18
vc              DS      10

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _arraymemberdecay_S0
_arraymemberdecay_S0             HEX     78,00
                FGX2_RELOC_COUNT 2
