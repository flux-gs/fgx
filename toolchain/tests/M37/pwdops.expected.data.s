;---------------------------------------
; fcc 0.0 — data segment for pwdops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _pwdops_S0
_pwdops_S0             HEX     72,6F,6F,74,00
                FGX2_EXPORT _pwdops_S1
_pwdops_S1             HEX     2F,72,6F,6F,74,00
                FGX2_EXPORT _pwdops_S2
_pwdops_S2             HEX     2F,62,69,6E,2F,73,68,00
                FGX2_EXPORT _pwdops_S3
_pwdops_S3             HEX     6E,6F,73,75,63,68,75,73,65,72,00
                FGX2_RELOC_COUNT 5
