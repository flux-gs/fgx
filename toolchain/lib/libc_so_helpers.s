; libc_so_helpers.s -- far entries for the fcc runtime helpers
; libc.so exports (tools/helper_census.py writes this file; do
; not edit it).  Each is JSL-reachable: JSR the helper, RTL.

                FGX2_EXPORT _fcc_fcmp_far
_fcc_fcmp_far JSR    _fcc_fcmp
                RTL
                FGX2_EXPORT _fcc_fdiv_far
_fcc_fdiv_far JSR    _fcc_fdiv
                RTL
                FGX2_EXPORT _fcc_ffloor_far
_fcc_ffloor_far JSR    _fcc_ffloor
                RTL
                FGX2_EXPORT _fcc_fmul_far
_fcc_fmul_far JSR    _fcc_fmul
                RTL
                FGX2_EXPORT _fcc_ftoi_far
_fcc_ftoi_far JSR    _fcc_ftoi
                RTL
                FGX2_EXPORT _fcc_ftol_far
_fcc_ftol_far JSR    _fcc_ftol
                RTL
                FGX2_EXPORT _fcc_itof_far
_fcc_itof_far JSR    _fcc_itof
                RTL
                FGX2_EXPORT _fcc_long_divs_far
_fcc_long_divs_far JSR    _fcc_long_divs
                RTL
                FGX2_EXPORT _fcc_long_mods_far
_fcc_long_mods_far JSR    _fcc_long_mods
                RTL
