;---------------------------------------
; fcc 0.0 — data segment for struct_ecopy.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
arr             DS      40
gs              DS      4

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _struct_ecopy_S0
_struct_ecopy_S0             HEX     68,69,00
                FGX2_RELOC_COUNT 2
