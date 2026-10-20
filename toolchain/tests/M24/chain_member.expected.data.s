;---------------------------------------
; fcc 0.0 — data segment for chain_member.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
s1              DS      8
s2              DS      8

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _chain_member_S0
_chain_member_S0             HEX     78,00
                FGX2_RELOC_COUNT 2
