;---------------------------------------
; fcc 0.0 — data segment for static_fnptr.c
;---------------------------------------
                FGX2_MODE 2
_static_fnptr_FA1       FGX2_LONG_PTR _Fa;seven;0
_static_fnptr_FA2       FGX2_LONG_PTR _Fa;thirty;0

;-------------------------------
; M7 globals
;-------------------------------
keep_sl_a       DS      4
keep_sl_b       DS      4
keep_sl_c       FGX2_LONG_PTR _Fa;five;0
                FGX2_RELOC_COUNT 4
