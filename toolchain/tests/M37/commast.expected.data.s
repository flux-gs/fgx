;---------------------------------------
; fcc 0.0 — data segment for commast.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
_tty            DS      2
gwin            DS      4
_rawmode        DS      2
_tty_ch         DS      2
nxstty          DS      2
seen_flags      DS      2
                FGX2_RELOC_COUNT 1
