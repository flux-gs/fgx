;---------------------------------------
; fcc 0.0 — data segment for libcadds.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      16

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _libcadds_S0
_libcadds_S0             HEX     2F,74,6D,70,2F,6C,63,61,00
                FGX2_EXPORT _libcadds_S1
_libcadds_S1             HEX     77,00
                FGX2_EXPORT _libcadds_S2
_libcadds_S2             HEX     61,62,63,00
                FGX2_EXPORT _libcadds_S3
_libcadds_S3             HEX     72,00
                FGX2_EXPORT _libcadds_S4
_libcadds_S4             HEX     61,00
                FGX2_EXPORT _libcadds_S5
_libcadds_S5             HEX     64,00
                FGX2_RELOC_COUNT 7
