;---------------------------------------
; fcc 0.0 — data segment for locfnp.c
;---------------------------------------
                FGX2_MODE 2
_locfnp_FA0       FGX2_LONG_PTR _Fa;f2;0
_locfnp_FA1       FGX2_LONG_PTR _Fa;add8;0
_locfnp_FA4       FGX2_LONG_PTR _Fa;f30;0
_locfnp_FA5       FGX2_LONG_PTR _Fa;f2;0

;-------------------------------
; M7 globals
;-------------------------------
b1              DS      2
b2              DS      2
                FGX2_RELOC_COUNT 5
