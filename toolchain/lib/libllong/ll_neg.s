;==============================================================================
; ll_neg -- long long unary minus: acc = -acc, as ~acc + 1.  A member of the
; llong archive; the carrier and the call are described in ll_addsub.s.
;==============================================================================
                MX      %00

                FGX2_EXPORT _fcc_ll_neg
_fcc_ll_neg     ENT
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
                RTL
