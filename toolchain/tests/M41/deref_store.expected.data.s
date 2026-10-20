;---------------------------------------
; fcc 0.0 — data segment for deref_store.c
;---------------------------------------
                FGX2_MODE 2

;-------------------------------
; M7 globals
;-------------------------------
                FGX2_EXPORT _deref_store_dv
_deref_store_dv DS      24
                FGX2_EXPORT _deref_store_dp
_deref_store_dp LIBC_DATA_PTR _Spg;_deref_store_dv
_deref_store_dpp LIBC_DATA_PTR _Spg;_deref_store_dp
                FGX2_EXPORT _deref_store_qv
_deref_store_qv DS      16
                FGX2_EXPORT _deref_store_qp
_deref_store_qp LIBC_DATA_PTR _Spg;_deref_store_qv
_deref_store_qpp LIBC_DATA_PTR _Spg;_deref_store_qp
                FGX2_EXPORT _deref_store_iv
_deref_store_iv DS      6
                FGX2_EXPORT _deref_store_ip
_deref_store_ip LIBC_DATA_PTR _Spg;_deref_store_iv
_deref_store_ipp LIBC_DATA_PTR _Spg;_deref_store_ip
                FGX2_EXPORT _deref_store_lv
_deref_store_lv DS      8
_deref_store_lp LIBC_DATA_PTR _Spg;_deref_store_lv
                FGX2_EXPORT _deref_store_fv
_deref_store_fv DS      8
_deref_store_fp LIBC_DATA_PTR _Spg;_deref_store_fv
                FGX2_RELOC_COUNT 17
