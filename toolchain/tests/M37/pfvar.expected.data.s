;---------------------------------------
; fcc 0.0 — data segment for pfvar.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      64

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _pfvar_S0
_pfvar_S0             HEX     25,64,25,64,25,64,25,64,25,64,25,64,25,64,25,64,25,64,25,64,25,64,00
                FGX2_EXPORT _pfvar_S1
_pfvar_S1             HEX     31,32,33,34,35,36,37,38,39,31,30,31,31,00
                FGX2_EXPORT _pfvar_S2
_pfvar_S2             HEX     25,64,00
                FGX2_EXPORT _pfvar_S3
_pfvar_S3             HEX     31,32,33,00
                FGX2_EXPORT _pfvar_S4
_pfvar_S4             HEX     25,2A,64,7C,25,2D,2A,64,00
                FGX2_EXPORT _pfvar_S5
_pfvar_S5             HEX     20,20,20,34,32,7C,37,20,20,20,00
                FGX2_EXPORT _pfvar_S6
_pfvar_S6             HEX     25,2E,33,73,00
                FGX2_EXPORT _pfvar_S7
_pfvar_S7             HEX     68,65,6C,6C,6F,00
                FGX2_EXPORT _pfvar_S8
_pfvar_S8             HEX     68,65,6C,00
                FGX2_EXPORT _pfvar_S9
_pfvar_S9             HEX     25,63,25,63,00
                FGX2_EXPORT _pfvar_S10
_pfvar_S10            HEX     51,7A,00
                FGX2_EXPORT _pfvar_S11
_pfvar_S11            HEX     25,2E,32,66,00
                FGX2_EXPORT _pfvar_S12
_pfvar_S12            HEX     31,2E,35,30,00
                FGX2_EXPORT _pfvar_S13
_pfvar_S13            HEX     25,67,00
                FGX2_EXPORT _pfvar_S14
_pfvar_S14            HEX     30,2E,33,37,35,00
                FGX2_EXPORT _pfvar_S15
_pfvar_S15            HEX     72,65,74,25,64,00
                FGX2_RELOC_COUNT 17
