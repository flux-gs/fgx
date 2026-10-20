                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from indir_promote.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT ip_callee
ip_callee            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ip_callee_FRAMESIZE
                DO      ip_callee_STKGUARD
                BCC     ip_callee_stkovf
                CMP     _fcc_stkfloor
                BCS     ip_callee_stkok
ip_callee_stkovf       JMP     _fcc_stkoflow
                FIN
ip_callee_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+ip_callee_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ip_callee_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ip_callee_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_indir_promote_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _indir_promote_L3
                EOR     #$8000
_indir_promote_L3
                BMI     *+5
                BRL     _indir_promote_L2
                LDA     _fcc_img1
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
_indir_promote_L1
                INC     _fcc_img0
                BRL     _indir_promote_L0
_indir_promote_L2
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #ip_callee_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ip_callee_FRAMESIZE   EQU     4
ip_callee_STKGUARD    EQU     0
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
                LDA     _indir_promote_FA4+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _indir_promote_FA4
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
_indir_promote_L5
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _indir_promote_L8
                EOR     #$8000
_indir_promote_L8
                BMI     *+5
                BRL     _indir_promote_L7
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #7
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PHK
                PEA     _indir_promote_L9-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_indir_promote_L9
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
_indir_promote_L6
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #1
                STA     7,S   ; fccstk d=0 b=7
                BRL     _indir_promote_L5
_indir_promote_L7
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 3
