                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from p33_setjmp_local.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT deep
deep            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #deep_FRAMESIZE
                DO      deep_STKGUARD
                BCC     deep_stkovf
                CMP     _fcc_stkfloor
                BCS     deep_stkok
deep_stkovf       JMP     _fcc_stkoflow
                FIN
deep_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img0
_p33_setjmp_local_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _p33_setjmp_local_L3
                EOR     #$8000
_p33_setjmp_local_L3
                BMI     *+5
                BRL     _p33_setjmp_local_L2
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                PHA
                LDA     _fcc_img0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img0
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                PLA
_p33_setjmp_local_L1
                INC     _fcc_img0
                BRL     _p33_setjmp_local_L0
_p33_setjmp_local_L2
                LDA     _fcc_img0
                STA     1,S   ; fccstk d=0 b=1
                LDA     marker
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                PHA
                LDA     #3
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     marker
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #env
                PHA
                LDA     #1
                PLX
                FGX2_FARCALL longjmp
                TAY
                TSC
                CLC
                ADC     #deep_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
deep_FRAMESIZE   EQU     18
deep_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                LDA     #314
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #env
                TAX
                FGX2_FARCALL setjmp
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _p33_setjmp_local_L4
                FGX2_FARCALL deep
_p33_setjmp_local_L4
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #314
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_setjmp_local_L5
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_setjmp_local_L5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAX
                LDA     #314
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_setjmp_local_L6
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_setjmp_local_L6
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_setjmp_local_L7
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_setjmp_local_L7
                LDA     marker
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_setjmp_local_L8
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_setjmp_local_L8
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fpr0
                STA     7,S   ; fccstk d=0 b=7
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr1+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _p33_setjmp_local_L10
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _p33_setjmp_local_L10
                LDA     #0
                BRL     _p33_setjmp_local_L11
_p33_setjmp_local_L10
                LDA     #1
_p33_setjmp_local_L11
                CMP     #0
                BNE     *+5
                BRL     _p33_setjmp_local_L9
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_setjmp_local_L9
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAX
                LDA     #314
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_setjmp_local_L12
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_setjmp_local_L12
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
