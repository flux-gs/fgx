;---------------------------------------
; fcc 0.0 — data segment for b5_intptr_arr.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT x
x               DA      $0014
                FGX2_EXPORT y
y               DA      $002A
                FGX2_EXPORT z
z               DA      $0007
arr             LIBC_DATA_PTR _Ga;x
                LIBC_DATA_PTR _Ga;y
                LIBC_DATA_PTR _Ga;z
                FGX2_RELOC_COUNT 7
