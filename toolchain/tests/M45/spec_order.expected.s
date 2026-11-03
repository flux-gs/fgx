                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from spec_order.c
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
                LDA     bump_sl_n
                INC
                STA     bump_sl_n
                TAY
                TSC
                CLC
                ADC     #bump_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bump_FRAMESIZE   EQU     0
bump_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #5
                STA     23,S   ; fccstk d=0 b=23
                FGX2_FARCALL bump
                FGX2_FARCALL bump
                FGX2_FARCALL bump
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gc
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fpr0
                STA     7,S   ; fccstk d=0 b=7
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_ptr+2
                LDA     7,S   ; fccstk d=0 b=7
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                SEC
                SBC     #97
                STA     3,S   ; fccstk d=0 b=3
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #10
                STA     [_fcc_img16]
                LDA     #20
                LDY     #2
                STA     [_fcc_img16],Y
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                STA     21,S   ; fccstk d=0 b=21
                TYA
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                LDX     #4454
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_sub
                STA     25,S   ; fccstk d=0 b=25
                LDA     [_fcc_img16]
                PHA
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     3,S   ; fccstk d=0 b=3
                CLC
                ADC     5,S   ; fccstk d=0 b=5
                CLC
                ADC     23,S   ; fccstk d=0 b=23
                CLC
                ADC     25,S   ; fccstk d=0 b=25
                CLC
                ADC     _spec_order_gs
                TAX
                SEC
                SBC     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     30
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
