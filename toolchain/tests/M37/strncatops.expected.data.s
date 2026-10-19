;---------------------------------------
; fcc 0.0 — data segment for strncatops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
buf             DS      32

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _strncatops_S0
_strncatops_S0             HEX     61,62,63,00
                FGX2_EXPORT _strncatops_S1
_strncatops_S1             HEX     64,65,66,00
                FGX2_EXPORT _strncatops_S2
_strncatops_S2             HEX     61,62,63,64,65,66,00
                FGX2_EXPORT _strncatops_S3
_strncatops_S3             HEX     64,65,66,67,68,00
                FGX2_EXPORT _strncatops_S4
_strncatops_S4             HEX     61,62,63,64,65,00
                FGX2_EXPORT _strncatops_S5
_strncatops_S5             HEX     78,79,7A,00
                FGX2_EXPORT _strncatops_S6
_strncatops_S6             HEX     6B,65,65,70,00
                FGX2_EXPORT _strncatops_S7
_strncatops_S7             HEX     6A,75,6E,6B,00
                FGX2_RELOC_COUNT 9
