;---------------------------------------
; fcc 0.0 — data segment for addr_member_elem.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
c               DS      74
cp              DS      4
one             FGX2_LONG_PTR _Sg;_addr_member_elem_S0;0
two             FGX2_LONG_PTR _Sg;_addr_member_elem_S1;0

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _addr_member_elem_S0
_addr_member_elem_S0             HEX     6F,6E,65,00
                FGX2_EXPORT _addr_member_elem_S1
_addr_member_elem_S1             HEX     74,77,6F,00
                FGX2_RELOC_COUNT 5
