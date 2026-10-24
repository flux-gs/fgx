                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pidx_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _pidx_param_f
_pidx_param_f            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_pidx_param_f_FRAMESIZE
                DO      _pidx_param_f_STKGUARD
                BCC     _pidx_param_f_stkovf
                CMP     _fcc_stkfloor
                BCS     _pidx_param_f_stkok
_pidx_param_f_stkovf       JMP     _fcc_stkoflow
                FIN
_pidx_param_f_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_pidx_param_f_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_pidx_param_f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_pidx_param_f_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+_pidx_param_f_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_pidx_param_f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_pidx_param_f_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_pidx_param_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _pidx_param_L3
                EOR     #$8000
_pidx_param_L3
                BMI     *+5
                BRL     _pidx_param_L2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     _fcc_img0
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
                STA     _fcc_img1
_pidx_param_L1
                INC     _fcc_img0
                BRL     _pidx_param_L0
_pidx_param_L2
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #_pidx_param_f_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pidx_param_f_FRAMESIZE   EQU     4
_pidx_param_f_STKGUARD    EQU     0
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
                LDA     #_pidx_param_a
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #10
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #_pidx_param_a
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #15
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #_pidx_param_a
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #17
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pidx_param_a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _pidx_param_f
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
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
                FGX2_RELOC_COUNT 4
