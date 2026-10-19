;==============================================================================
; ll_shift -- long long << and >>.  A member of the llong archive; the carrier
; and the call are described in ll_addsub.s.
;
; The count is _fcc_long_b_lo, masked to 0..63 (a count of 64 or more is
; undefined in C).  w0 rides _fcc_llsh_w0 while the loop runs.
;==============================================================================
                MX      %00

                FGX2_EXPORT _fcc_ll_shl
_fcc_ll_shl     ENT
                STA     _fcc_llsh_w0
                LDA     _fcc_long_b_lo
                AND     #$003F
                TAX
                BEQ     @llsl_dn
@llsl_lp        ASL     _fcc_llsh_w0
                ROL     _fcc_long_hi
                ROL     _fcc_q2
                ROL     _fcc_q3
                DEX
                BNE     @llsl_lp
@llsl_dn        LDA     _fcc_llsh_w0
                RTL

; Logical right shift, for an unsigned left operand.
                FGX2_EXPORT _fcc_ll_shru
_fcc_ll_shru    ENT
                STA     _fcc_llsh_w0
                LDA     _fcc_long_b_lo
                AND     #$003F
                TAX
                BEQ     @llsru_dn
@llsru_lp       LSR     _fcc_q3
                ROR     _fcc_q2
                ROR     _fcc_long_hi
                ROR     _fcc_llsh_w0
                DEX
                BNE     @llsru_lp
@llsru_dn       LDA     _fcc_llsh_w0
                RTL

; Arithmetic right shift, for a signed one: ASL of w3 puts its sign in C, and
; the ROR of w3 shifts that same bit back in at the top.
                FGX2_EXPORT _fcc_ll_shr
_fcc_ll_shr     ENT
                STA     _fcc_llsh_w0
                LDA     _fcc_long_b_lo
                AND     #$003F
                TAX
                BEQ     @llsr_dn
@llsr_lp        LDA     _fcc_q3
                ASL
                ROR     _fcc_q3
                ROR     _fcc_q2
                ROR     _fcc_long_hi
                ROR     _fcc_llsh_w0
                DEX
                BNE     @llsr_lp
@llsr_dn        LDA     _fcc_llsh_w0
                RTL
