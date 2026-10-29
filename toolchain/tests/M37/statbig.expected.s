                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from statbig.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                TSC
                SEC
                SBC     #main_FRAMESIZE-2
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #420
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_statbig_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL creat
                PLY
                PLY
                PLY
                STA     3,S   ; fccstk d=0 b=3
                CMP     #0
                BPL     _statbig_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_statbig_L0
                LDA     #0
                STA     _fcc_img16
_statbig_L1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #66
                BVC     _statbig_L4
                EOR     #$8000
_statbig_L4
                BPL     _statbig_L3
                LDA     #500
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL write
                PLY
                PLY
                PLY
                PLY
_statbig_L2
                INC     _fcc_img16
                BRA     _statbig_L1
_statbig_L3
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                FGX2_FARCALL close
                PLY
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_statbig_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL stat
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _statbig_L5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_statbig_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                PLY
                PLY
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRA     main_bandx
_statbig_L5
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_long_hi
                LDA     23,S   ; fccstk d=0 b=23
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_statbig_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                PLY
                PLY
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                LDX     #33000
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _statbig_L6
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRA     main_bandx
_statbig_L6
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
main_bandx
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     62
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
