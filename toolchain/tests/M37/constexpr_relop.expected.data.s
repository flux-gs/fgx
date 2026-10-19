;---------------------------------------
; fcc 0.0 — data segment for constexpr_relop.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
_sa_dinode_is_64 DS      1
_sa_pdp_alignment DS      1
_sa_eq          DS      1
_sa_ne          DS      1
_sa_lt          DS      1
_sa_gt          DS      1
_sa_le          DS      1
_sa_ge          DS      1
_sa_andand      DS      1
_sa_oror        DS      1
_sa_not         DS      1
_sa_add_over_cmp DS      1
_sa_rel_over_eq DS      1
_sa_eq_over_and DS      1
_sa_and_over_or DS      1
_sa_shift_over_cmp DS      1
_sa_cond_true   DS      1
_sa_cond_false  DS      1
_sa_cond_nest_then DS      1
_sa_cond_nest_else DS      1
_sa_cond_loosest DS      1
                FGX2_RELOC_COUNT 1
