;==============================================================================
; ll_cmp -- long long comparisons.  A member of the llong archive; the carrier
; and the call are described in ll_addsub.s.
;
; A = $FFFF (acc < b), 0 (equal), 1 (acc > b), with N/Z set from A at the RTL
; (which leaves P alone), so the caller branches on them directly.  The signed
; form compares the top words signed and the rest unsigned; the unsigned form
; compares all four unsigned.  The accumulator is not preserved.
;==============================================================================
                MX      %00

                FGX2_EXPORT _fcc_ll_cmps
_fcc_ll_cmps    ENT
                TAY
                LDA     _fcc_q3
                CMP     _fcc_qb3
                BEQ     @llcs_w2
                SEC
                SBC     _fcc_qb3
                BVC     @llcs_nv
                EOR     #$8000
@llcs_nv        BMI     @llcs_lt
                LDA     #1
                RTL
@llcs_w2        LDA     _fcc_q2
                CMP     _fcc_qb2
                BNE     @llcs_ne
                LDA     _fcc_long_hi
                CMP     _fcc_long_b_hi
                BNE     @llcs_ne
                TYA
                CMP     _fcc_long_b_lo
                BNE     @llcs_ne
                LDA     #0
                RTL
@llcs_ne        BCC     @llcs_lt
                LDA     #1
                RTL
@llcs_lt        LDA     #$FFFF
                RTL

                FGX2_EXPORT _fcc_ll_cmpu
_fcc_ll_cmpu    ENT
                TAY
                LDA     _fcc_q3
                CMP     _fcc_qb3
                BNE     @llcu_ne
                LDA     _fcc_q2
                CMP     _fcc_qb2
                BNE     @llcu_ne
                LDA     _fcc_long_hi
                CMP     _fcc_long_b_hi
                BNE     @llcu_ne
                TYA
                CMP     _fcc_long_b_lo
                BNE     @llcu_ne
                LDA     #0
                RTL
@llcu_ne        BCC     @llcu_lt
                LDA     #1
                RTL
@llcu_lt        LDA     #$FFFF
                RTL
