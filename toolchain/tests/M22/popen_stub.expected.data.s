;---------------------------------------
; fcc 0.0 — data segment for popen_stub.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _popen_stub_S0
_popen_stub_S0             HEX     6D,61,69,6C,20,72,6F,6F,74,00
                FGX2_EXPORT _popen_stub_S1
_popen_stub_S1             HEX     77,00
                FGX2_RELOC_COUNT 3
