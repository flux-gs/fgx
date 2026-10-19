;---------------------------------------
; fcc 0.0 — data segment for sptrnull.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
gp              DA      $0000
                DA      $0000
gq              DA      $0000
                DA      $0000
sentinel        DFB     $01
                DFB     $02
                DFB     $03
                DFB     $04
ip              DA      $0000
                DA      $0000
cpp             DA      $0000
                DA      $0000
                FGX2_RELOC_COUNT 1
