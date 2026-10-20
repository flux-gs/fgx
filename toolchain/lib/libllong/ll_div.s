;==============================================================================
; ll_div -- long long / and %, signed and unsigned.  A member of the llong
; archive; the carrier and the call are described in ll_addsub.s.
;
; The public entries return with RTL; the helpers they share are near (JSR/RTS)
; and private to this member, including its own negate -- a far call to
; ll_neg's would cost a relocation for a routine this short.
;==============================================================================
                MX      %00

; Unsigned acc / b: the quotient in the carrier, the remainder in
; _fcc_lld_r0-3.  Restoring division, 64 rounds.  The remainder can reach 65
; bits for one instant (it is < b before the shift, and b may use all 64), so
; the bit shifted out of it is kept in _fcc_lld_c and forces the subtraction.
; Division by zero is undefined; it answers all ones.
_fcc_lld_divmodu
                STA     _fcc_lld_w0
                STZ     _fcc_lld_r0
                STZ     _fcc_lld_r1
                STZ     _fcc_lld_r2
                STZ     _fcc_lld_r3
                LDX     #64
@lldv_lp        ASL     _fcc_lld_w0
                ROL     _fcc_long_hi
                ROL     _fcc_q2
                ROL     _fcc_q3
                ROL     _fcc_lld_r0
                ROL     _fcc_lld_r1
                ROL     _fcc_lld_r2
                ROL     _fcc_lld_r3
                LDA     #0
                ROL
                STA     _fcc_lld_c
                SEC
                LDA     _fcc_lld_r0
                SBC     _fcc_long_b_lo
                STA     _fcc_lld_d0
                LDA     _fcc_lld_r1
                SBC     _fcc_long_b_hi
                STA     _fcc_lld_d1
                LDA     _fcc_lld_r2
                SBC     _fcc_qb2
                STA     _fcc_lld_d2
                LDA     _fcc_lld_r3
                SBC     _fcc_qb3
                BCS     @lldv_take
                LDY     _fcc_lld_c
                BEQ     @lldv_nx
@lldv_take      STA     _fcc_lld_r3
                LDA     _fcc_lld_d0
                STA     _fcc_lld_r0
                LDA     _fcc_lld_d1
                STA     _fcc_lld_r1
                LDA     _fcc_lld_d2
                STA     _fcc_lld_r2
                INC     _fcc_lld_w0
@lldv_nx        DEX
                BNE     @lldv_lp
                LDA     _fcc_lld_w0
                RTS

; The remainder becomes the carrier.
_fcc_lld_remacc
                LDA     _fcc_lld_r1
                STA     _fcc_long_hi
                LDA     _fcc_lld_r2
                STA     _fcc_q2
                LDA     _fcc_lld_r3
                STA     _fcc_q3
                LDA     _fcc_lld_r0
                RTS

; acc = -acc, near.
_fcc_lld_neg
                EOR     #$FFFF
                CLC
                ADC     #1
                TAY
                LDA     _fcc_long_hi
                EOR     #$FFFF
                ADC     #0
                STA     _fcc_long_hi
                LDA     _fcc_q2
                EOR     #$FFFF
                ADC     #0
                STA     _fcc_q2
                LDA     _fcc_q3
                EOR     #$FFFF
                ADC     #0
                STA     _fcc_q3
                TYA
                RTS

; Signed division truncates toward zero, so that (a/b)*b + a%b == a (K&R
; A.7.6): divide the magnitudes, then the quotient takes the XOR of the two
; signs and the remainder the dividend's.  This records the signs and makes
; both operands non-negative.
_fcc_lld_sprep
                TAY
                LDA     _fcc_q3
                AND     #$8000
                STA     _fcc_lld_sr
                STA     _fcc_lld_sq
                LDA     _fcc_qb3
                AND     #$8000
                EOR     _fcc_lld_sq
                STA     _fcc_lld_sq
                TYA
                LDX     _fcc_lld_sr
                BEQ     @llsp_a
                JSR     _fcc_lld_neg
@llsp_a         TAY
                LDA     _fcc_qb3
                BPL     @llsp_b
                SEC
                LDA     #0
                SBC     _fcc_long_b_lo
                STA     _fcc_long_b_lo
                LDA     #0
                SBC     _fcc_long_b_hi
                STA     _fcc_long_b_hi
                LDA     #0
                SBC     _fcc_qb2
                STA     _fcc_qb2
                LDA     #0
                SBC     _fcc_qb3
                STA     _fcc_qb3
@llsp_b         TYA
                RTS

                FGX2_EXPORT _fcc_ll_divu
_fcc_ll_divu    ENT
                JSR     _fcc_lld_divmodu
                RTL

                FGX2_EXPORT _fcc_ll_modu
_fcc_ll_modu    ENT
                JSR     _fcc_lld_divmodu
                JSR     _fcc_lld_remacc
                RTL

                FGX2_EXPORT _fcc_ll_divs
_fcc_ll_divs    ENT
                JSR     _fcc_lld_sprep
                JSR     _fcc_lld_divmodu
                LDX     _fcc_lld_sq
                BEQ     @llds_dn
                JSR     _fcc_lld_neg
@llds_dn        RTL

                FGX2_EXPORT _fcc_ll_mods
_fcc_ll_mods    ENT
                JSR     _fcc_lld_sprep
                JSR     _fcc_lld_divmodu
                JSR     _fcc_lld_remacc
                LDX     _fcc_lld_sr
                BEQ     @llms_dn
                JSR     _fcc_lld_neg
@llms_dn        RTL
