;==============================================================================
; ll_addsub -- long long + and -.  A member of the llong archive
; (toolchain/lib/libllong/, apple/fgx#447; docs/history/plans/2026-09-23-fcc-
; long-long-plan.md).
;
; THE CARRIER.  A long long is a long with two more words: w0 in A, w1 in
; _fcc_long_hi (DP), w2/w3 in _fcc_q2/_fcc_q3 (data bank, fcc_runtime_data.s).
; The second operand is _fcc_long_b_lo/_fcc_long_b_hi (DP) and _fcc_qb2/
; _fcc_qb3.  Results land in the carrier.
;
; THE CALL.  fcc reaches every archive routine with FGX2_FARCALL, so each public
; entry returns with RTL.  Entry MX %00, DBR = the caller's data bank (a JSL does
; not change it), which is where _fcc_q2.. live.  X and Y are scratch.
;==============================================================================
                MX      %00

; acc += b / acc -= b.  TAY and LDA leave the carry alone, so it ripples
; through all four words.
                FGX2_EXPORT _fcc_ll_add
_fcc_ll_add     ENT
                CLC
                ADC     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                ADC     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_q2
                ADC     _fcc_qb2
                STA     _fcc_q2
                LDA     _fcc_q3
                ADC     _fcc_qb3
                STA     _fcc_q3
                TYA
                RTL

                FGX2_EXPORT _fcc_ll_sub
_fcc_ll_sub     ENT
                SEC
                SBC     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                SBC     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_q2
                SBC     _fcc_qb2
                STA     _fcc_q2
                LDA     _fcc_q3
                SBC     _fcc_qb3
                STA     _fcc_q3
                TYA
                RTL
