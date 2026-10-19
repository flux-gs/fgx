;---------------------------------------
; fcc 0.0 — data segment for libso_calls.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT _libc_blk_libso_calls
_libc_blk_libso_calls DA      libso_calls__BT
                FGX2_EXPORT libso_calls__BT
libso_calls__BT          ANOP
                ERR     *-libso_calls__BT-0
_libso_calls_jb DS      16
                FGX2_RELOC_COUNT 3
