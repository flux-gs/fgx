;---------------------------------------
; fcc 0.0 — data segment for llong_store.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
ga              DS      8
gb              DS      8
lo_neg          DA      $FFFB
                DA      $FFFF
lo_big          DA      $CDEF
                DA      $89AB
                FGX2_RELOC_COUNT 1
