                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from derefstore.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT bump
bump            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bump_FRAMESIZE
                DO      bump_STKGUARD
                BCC     bump_stkovf
                CMP     _fcc_stkfloor
                BCS     bump_stkok
bump_stkovf       JMP     _fcc_stkoflow
                FIN
bump_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+bump_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bump_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bump_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bump_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bump_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bump_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #10
                STA     [_fcc_fpr0]
                DO      8+bump_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bump_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bump_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bump_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bump_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bump_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      8+bump_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bump_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bump_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+bump_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bump_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bump_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                TAX
                TXA
                CLC
                ADC     #5
                STA     [_fcc_fpr0]
                DO      6+bump_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bump_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bump_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+bump_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bump_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bump_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                STA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #bump_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bump_FRAMESIZE   EQU     2
bump_STKGUARD    EQU     0
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #hdr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bump
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     #1
                ASL
                TAX
                LDA:    hdr,X
                TAX
                TXA
                CMP     #15
                BEQ     *+5
                BRL     _derefstore_L0
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #15
                STA     5,S   ; fccstk d=0 b=5
_derefstore_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #hdr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                INC
                INC
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                TAX
                LDA:    hdr,X
                TAX
                TXA
                CMP     #17
                BEQ     *+5
                BRL     _derefstore_L1
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #12
                STA     5,S   ; fccstk d=0 b=5
_derefstore_L1
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
