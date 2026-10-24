;---------------------------------------
; fcc 0.0 — data segment for idxcall.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT _idxcall_digs
_idxcall_digs   DFB     $30
                DFB     $31
                DFB     $32
                DFB     $33
                DFB     $34
                DFB     $35
                DFB     $36
                DFB     $37
                DFB     $38
                DFB     $39
                DFB     $00
_idxcall_nums   DA      $000A
                DA      $000B
                DA      $000C
                DA      $000D
_idxcall_lnum   DA      $1170
                DA      $0001
                DA      $1171
                DA      $0001
                DA      $1172
                DA      $0001
_idxcall_strs   FGX2_LONG_PTR _Sa;_idxcall_S0;0
                FGX2_LONG_PTR _Sa;_idxcall_S1;0
                FGX2_LONG_PTR _Sa;_idxcall_S2;0
gp              LIBC_DATA_PTR _Spg;_idxcall_digs

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _idxcall_S0
_idxcall_S0             HEX     61,00
                FGX2_EXPORT _idxcall_S1
_idxcall_S1             HEX     62,00
                FGX2_EXPORT _idxcall_S2
_idxcall_S2             HEX     63,00
                FGX2_RELOC_COUNT 9
