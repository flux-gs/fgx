;---------------------------------------
; fcc 0.0 — data segment for libcadds.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
_libcadds_ov    DFB     $61
                DFB     $62
                DFB     $63
                DFB     $64
                DFB     $65
                DFB     $66
                DFB     $00
                DFB     $00

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _libcadds_S0
_libcadds_S0             HEX     6D,33,39,00
                FGX2_EXPORT _libcadds_S1
_libcadds_S1             HEX     61,62,61,62,63,64,00
                FGX2_EXPORT _libcadds_S2
_libcadds_S2             HEX     61,62,63,64,63,64,00
                FGX2_EXPORT _libcadds_S3
_libcadds_S3             HEX     32,31,2E,30,00
                FGX2_RELOC_COUNT 5
