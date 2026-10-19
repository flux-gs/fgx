;---------------------------------------
; fcc 0.0 — data segment for strcopy_test.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
g_buf           DS      16
g_greet         FGX2_LONG_PTR _Sg;_strcopy_test_S0;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _strcopy_test_S0
_strcopy_test_S0             HEX     68,69,00
                FGX2_RELOC_COUNT 3
