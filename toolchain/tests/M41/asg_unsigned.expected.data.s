;---------------------------------------
; fcc 0.0 — data segment for asg_unsigned.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
ua              DS      4
st              DS      2
                FGX2_EXPORT uv
uv              DS      2
up              LIBC_DATA_PTR _Spg;uv
                FGX2_RELOC_COUNT 3
