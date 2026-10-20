;---------------------------------------
; fcc 0.0 — data segment for fltpr_ecvt.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      40

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _fltpr_ecvt_S0
_fltpr_ecvt_S0             HEX     33,31,34,31,36,00
                FGX2_EXPORT _fltpr_ecvt_S1
_fltpr_ecvt_S1             HEX     31,32,33,34,35,37,00
                FGX2_EXPORT _fltpr_ecvt_S2
_fltpr_ecvt_S2             HEX     31,32,35,00
                FGX2_EXPORT _fltpr_ecvt_S3
_fltpr_ecvt_S3             HEX     25,45,00
                FGX2_EXPORT _fltpr_ecvt_S4
_fltpr_ecvt_S4             HEX     31,2E,32,33,34,35,30,30,45,2B,30,34,00
                FGX2_EXPORT _fltpr_ecvt_S5
_fltpr_ecvt_S5             HEX     25,47,00
                FGX2_EXPORT _fltpr_ecvt_S6
_fltpr_ecvt_S6             HEX     31,2E,32,33,45,2D,30,35,00
                FGX2_EXPORT _fltpr_ecvt_S7
_fltpr_ecvt_S7             HEX     25,67,00
                FGX2_EXPORT _fltpr_ecvt_S8
_fltpr_ecvt_S8             HEX     31,30,30,30,30,30,00
                FGX2_EXPORT _fltpr_ecvt_S9
_fltpr_ecvt_S9             HEX     31,65,2B,30,36,00
                FGX2_EXPORT _fltpr_ecvt_S10
_fltpr_ecvt_S10            HEX     30,2E,30,30,30,31,00
                FGX2_EXPORT _fltpr_ecvt_S11
_fltpr_ecvt_S11            HEX     25,65,00
                FGX2_EXPORT _fltpr_ecvt_S12
_fltpr_ecvt_S12            HEX     30,2E,30,30,30,30,30,30,65,2B,30,30,00
                FGX2_EXPORT _fltpr_ecvt_S13
_fltpr_ecvt_S13            HEX     25,2E,30,65,00
                FGX2_EXPORT _fltpr_ecvt_S14
_fltpr_ecvt_S14            HEX     35,65,2B,30,31,00
                FGX2_EXPORT _fltpr_ecvt_S15
_fltpr_ecvt_S15            HEX     25,66,00
                FGX2_EXPORT _fltpr_ecvt_S16
_fltpr_ecvt_S16            HEX     69,6E,66,00
                FGX2_EXPORT _fltpr_ecvt_S17
_fltpr_ecvt_S17            HEX     2D,69,6E,66,00
                FGX2_EXPORT _fltpr_ecvt_S18
_fltpr_ecvt_S18            HEX     30,2E,31,00
                FGX2_EXPORT _fltpr_ecvt_S19
_fltpr_ecvt_S19            HEX     31,2E,35,65,33,00
                FGX2_EXPORT _fltpr_ecvt_S20
_fltpr_ecvt_S20            HEX     2D,32,2E,35,00
                FGX2_EXPORT _fltpr_ecvt_S21
_fltpr_ecvt_S21            HEX     31,30,00
                FGX2_EXPORT _fltpr_ecvt_S22
_fltpr_ecvt_S22            HEX     25,2E,33,65,00
                FGX2_EXPORT _fltpr_ecvt_S23
_fltpr_ecvt_S23            HEX     31,2E,30,30,30,65,2B,33,30,30,00
                FGX2_RELOC_COUNT 25
