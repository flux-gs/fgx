;---------------------------------------
; fcc 0.0 — data segment for llong_printf.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
_llong_printf_b DS      64

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _llong_printf_S0
_llong_printf_S0             HEX     25,6C,6C,64,00
                FGX2_EXPORT _llong_printf_S1
_llong_printf_S1             HEX     38,31,39,38,35,35,32,39,32,31,36,34,38,36,38,39,35,00
                FGX2_EXPORT _llong_printf_S2
_llong_printf_S2             HEX     2D,39,32,32,33,33,37,32,30,33,36,38,35,34,37,37,35,38,30,38,00
                FGX2_EXPORT _llong_printf_S3
_llong_printf_S3             HEX     25,6C,6C,75,00
                FGX2_EXPORT _llong_printf_S4
_llong_printf_S4             HEX     31,38,34,34,36,37,34,34,30,37,33,37,30,39,35,35,31,36,31,35,00
                FGX2_EXPORT _llong_printf_S5
_llong_printf_S5             HEX     25,6C,6C,78,7C,25,6C,6C,58,00
                FGX2_EXPORT _llong_printf_S6
_llong_printf_S6             HEX     31,32,33,34,35,36,37,38,39,61,62,63,64,65,66,7C,31,32,33,34,35,36,37,38,39,41,42,43,44,45,46,00
                FGX2_EXPORT _llong_printf_S7
_llong_printf_S7             HEX     25,6C,6C,6F,00
                FGX2_EXPORT _llong_printf_S8
_llong_printf_S8             HEX     31,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,00
                FGX2_EXPORT _llong_printf_S9
_llong_printf_S9             HEX     25,71,64,7C,25,6C,6C,75,00
                FGX2_EXPORT _llong_printf_S10
_llong_printf_S10            HEX     2D,31,7C,30,00
                FGX2_EXPORT _llong_printf_S11
_llong_printf_S11            HEX     25,30,32,30,6C,6C,64,7C,25,2D,36,6C,6C,64,7C,25,36,6C,6C,64,00
                FGX2_EXPORT _llong_printf_S12
_llong_printf_S12            HEX     2D,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,34,32,7C,37,20,20,20,20,20,7C,20,20,20,20,2D,37,00
                FGX2_EXPORT _llong_printf_S13
_llong_printf_S13            HEX     25,64,20,25,6C,6C,64,20,25,6C,64,20,25,64,00
                FGX2_EXPORT _llong_printf_S14
_llong_printf_S14            HEX     33,20,38,31,39,38,35,35,32,39,32,31,36,34,38,36,38,39,35,20,37,30,30,30,30,20,39,00
                FGX2_RELOC_COUNT 16
