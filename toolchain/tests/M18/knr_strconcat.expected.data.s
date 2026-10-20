;---------------------------------------
; fcc 0.0 — data segment for knr_strconcat.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _knr_strconcat_S0
_knr_strconcat_S0             HEX     61,62,63,64,65,66,00
                FGX2_EXPORT _knr_strconcat_S1
_knr_strconcat_S1             HEX     68,69,21,00
                FGX2_EXPORT _knr_strconcat_S2
_knr_strconcat_S2             HEX     61,62,63,64,00
                FGX2_EXPORT _knr_strconcat_S3
_knr_strconcat_S3             HEX     01,32,00
                FGX2_RELOC_COUNT 5
