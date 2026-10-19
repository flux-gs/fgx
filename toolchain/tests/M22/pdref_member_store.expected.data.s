;---------------------------------------
; fcc 0.0 — data segment for pdref_member_store.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
a               DS      2
b               DS      2
c               DS      2
tbl             DS      24

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _pdref_member_store_S0
_pdref_member_store_S0             HEX     61,00
                FGX2_EXPORT _pdref_member_store_S1
_pdref_member_store_S1             HEX     62,00
                FGX2_EXPORT _pdref_member_store_S2
_pdref_member_store_S2             HEX     63,00
                FGX2_RELOC_COUNT 4
