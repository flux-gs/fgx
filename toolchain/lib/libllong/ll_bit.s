;==============================================================================
; ll_bit -- long long & | ^ and ~, word by word.  A member of the llong archive;
; the carrier and the call are described in ll_addsub.s.
;==============================================================================
                MX      %00

                FGX2_EXPORT _fcc_ll_and
_fcc_ll_and     ENT
                AND     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                AND     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_q2
                AND     _fcc_qb2
                STA     _fcc_q2
                LDA     _fcc_q3
                AND     _fcc_qb3
                STA     _fcc_q3
                TYA
                RTL

                FGX2_EXPORT _fcc_ll_or
_fcc_ll_or      ENT
                ORA     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                ORA     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_q2
                ORA     _fcc_qb2
                STA     _fcc_q2
                LDA     _fcc_q3
                ORA     _fcc_qb3
                STA     _fcc_q3
                TYA
                RTL

                FGX2_EXPORT _fcc_ll_xor
_fcc_ll_xor     ENT
                EOR     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                EOR     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_q2
                EOR     _fcc_qb2
                STA     _fcc_q2
                LDA     _fcc_q3
                EOR     _fcc_qb3
                STA     _fcc_q3
                TYA
                RTL

; acc = ~acc
                FGX2_EXPORT _fcc_ll_com
_fcc_ll_com     ENT
                EOR     #$FFFF
                TAY
                LDA     _fcc_long_hi
                EOR     #$FFFF
                STA     _fcc_long_hi
                LDA     _fcc_q2
                EOR     #$FFFF
                STA     _fcc_q2
                LDA     _fcc_q3
                EOR     #$FFFF
                STA     _fcc_q3
                TYA
                RTL
