;---------------------------------------
; fcc 0.0 — data segment for m11_libc_test.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _m11_libc_test_S0
_m11_libc_test_S0             HEX     68,65,6C,6C,6F,00
                FGX2_EXPORT _m11_libc_test_S1
_m11_libc_test_S1             HEX     65,71,00
                FGX2_EXPORT _m11_libc_test_S2
_m11_libc_test_S2             HEX     6E,3D,25,64,20,65,71,3D,25,64,0A,00
                FGX2_RELOC_COUNT 4
