;---------------------------------------
; fcc 0.0 — data segment for fileops.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _fileops_S0
_fileops_S0             HEX     2F,74,6D,70,2F,63,34,62,34,00
                FGX2_EXPORT _fileops_S1
_fileops_S1             HEX     61,62,63,64,65,66,00
                FGX2_EXPORT _fileops_S2
_fileops_S2             HEX     63,64,65,66,00
                FGX2_EXPORT _fileops_S3
_fileops_S3             HEX     2F,74,6D,70,2F,4E,4F,50,45,63,34,00
                FGX2_RELOC_COUNT 5
