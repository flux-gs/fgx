;---------------------------------------
; fcc 0.0 — data segment for f_printf.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      32

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _f_printf_S0
_f_printf_S0             HEX     25,66,00
                FGX2_EXPORT _f_printf_S1
_f_printf_S1             HEX     33,2E,31,34,30,30,30,30,00
                FGX2_EXPORT _f_printf_S2
_f_printf_S2             HEX     32,2E,30,30,30,30,30,30,00
                FGX2_EXPORT _f_printf_S3
_f_printf_S3             HEX     25,2E,32,66,00
                FGX2_EXPORT _f_printf_S4
_f_printf_S4             HEX     33,2E,31,34,00
                FGX2_EXPORT _f_printf_S5
_f_printf_S5             HEX     2D,31,2E,35,30,30,30,30,30,00
                FGX2_EXPORT _f_printf_S6
_f_printf_S6             HEX     25,2E,33,66,00
                FGX2_EXPORT _f_printf_S7
_f_printf_S7             HEX     30,2E,35,30,30,00
                FGX2_EXPORT _f_printf_S8
_f_printf_S8             HEX     34,32,2E,30,30,30,30,30,30,00
                FGX2_EXPORT _f_printf_S9
_f_printf_S9             HEX     25,2E,30,66,00
                FGX2_EXPORT _f_printf_S10
_f_printf_S10            HEX     35,32,00
                FGX2_EXPORT _f_printf_S11
_f_printf_S11            HEX     30,00
                FGX2_EXPORT _f_printf_S12
_f_printf_S12            HEX     35,33,00
                FGX2_EXPORT _f_printf_S13
_f_printf_S13            HEX     25,2E,30,65,00
                FGX2_EXPORT _f_printf_S14
_f_printf_S14            HEX     35,65,2B,30,31,00
                FGX2_EXPORT _f_printf_S15
_f_printf_S15            HEX     25,2E,31,65,00
                FGX2_EXPORT _f_printf_S16
_f_printf_S16            HEX     35,2E,32,65,2B,30,31,00
                FGX2_EXPORT _f_printf_S17
_f_printf_S17            HEX     31,2E,30,65,2B,30,31,00
                FGX2_EXPORT _f_printf_S18
_f_printf_S18            HEX     25,2E,31,66,00
                FGX2_EXPORT _f_printf_S19
_f_printf_S19            HEX     31,30,2E,30,00
                FGX2_RELOC_COUNT 21
