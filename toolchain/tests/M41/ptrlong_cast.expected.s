                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptrlong_cast.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT f
f            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f_FRAMESIZE
                DO      f_STKGUARD
                BCC     f_stkovf
                CMP     _fcc_stkfloor
                BCS     f_stkok
f_stkovf       JMP     _fcc_stkoflow
                FIN
f_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                TYA
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     q
                TAY
                LDA     _fcc_long_hi
                STA     q+2
                LDA     _fcc_q2
                STA     q+4
                LDA     _fcc_q3
                STA     q+6
                TYA
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptrlong_cast_L0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                BRA     _ptrlong_cast_L1
_ptrlong_cast_L0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
_ptrlong_cast_L1
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f_FRAMESIZE   EQU     8
f_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #main_FRAMESIZE
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                FGX2_FARCALL f
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ptrlong_cast_L2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL f
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptrlong_cast_L2
                LDA     q+6
                STA     _fcc_q3
                LDA     q+4
                STA     _fcc_q2
                LDA     q+2
                STA     _fcc_long_hi
                LDA     q
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptrlong_cast_L2
                LDA     #42
                BRA     _ptrlong_cast_L3
_ptrlong_cast_L2
                LDA     #7
_ptrlong_cast_L3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 5
