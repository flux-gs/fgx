;---------------------------------------
; fcc 0.0 — data segment for libso_addr.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT _libc_blk_libso_addr
_libc_blk_libso_addr DA      libso_addr__BT
                FGX2_EXPORT libso_addr__BT
libso_addr__BT          ANOP
                ERR     *-libso_addr__BT-0
_libso_addr_s   DA      $0005
                FGX2_RELOC_COUNT 3
