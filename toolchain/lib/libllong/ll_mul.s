;==============================================================================
; ll_mul -- long long *: acc *= b, the low 64 bits (the same for signed and
; unsigned).  A member of the llong archive; the carrier and the call are
; described in ll_addsub.s.
;
; Shift and add, stopping as soon as the multiplier has no bits left.  The
; multiplicand rides _fcc_llm_x0-3 and w0 of the product _fcc_llm_w0; the
; second operand is consumed.
;==============================================================================
                MX      %00

                FGX2_EXPORT _fcc_ll_mul
_fcc_ll_mul     ENT
                STA     _fcc_llm_x0
                LDA     _fcc_long_hi
                STA     _fcc_llm_x1
                LDA     _fcc_q2
                STA     _fcc_llm_x2
                LDA     _fcc_q3
                STA     _fcc_llm_x3
                STZ     _fcc_llm_w0
                STZ     _fcc_long_hi
                STZ     _fcc_q2
                STZ     _fcc_q3
@llm_lp         LDA     _fcc_long_b_lo
                ORA     _fcc_long_b_hi
                ORA     _fcc_qb2
                ORA     _fcc_qb3
                BEQ     @llm_dn
                LSR     _fcc_qb3
                ROR     _fcc_qb2
                ROR     _fcc_long_b_hi
                ROR     _fcc_long_b_lo
                BCC     @llm_sh
                CLC
                LDA     _fcc_llm_w0
                ADC     _fcc_llm_x0
                STA     _fcc_llm_w0
                LDA     _fcc_long_hi
                ADC     _fcc_llm_x1
                STA     _fcc_long_hi
                LDA     _fcc_q2
                ADC     _fcc_llm_x2
                STA     _fcc_q2
                LDA     _fcc_q3
                ADC     _fcc_llm_x3
                STA     _fcc_q3
@llm_sh         ASL     _fcc_llm_x0
                ROL     _fcc_llm_x1
                ROL     _fcc_llm_x2
                ROL     _fcc_llm_x3
                BRA     @llm_lp
@llm_dn         LDA     _fcc_llm_w0
                RTL
