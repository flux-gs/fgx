                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from int_to_ptr_implicit.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT pick
pick            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pick_FRAMESIZE
                DO      pick_STKGUARD
                BCC     pick_stkovf
                CMP     _fcc_stkfloor
                BCS     pick_stkok
pick_stkovf       JMP     _fcc_stkoflow
                FIN
pick_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+pick_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _int_to_ptr_implicit_L0
                SEP     #$20
                MX      %10
                LDA     cmdadr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     cmdadr
                STA     _fcc_fpr0
                BRL     _int_to_ptr_implicit_L1
_int_to_ptr_implicit_L0
                LDA     #0
                STA     dolg
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
_int_to_ptr_implicit_L1
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pick_FRAMESIZE   EQU     4
pick_STKGUARD    EQU     0
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
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                TAY
                JSR     _fcc_bank_for_int
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #bump_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bump_FRAMESIZE   EQU     4
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
                LDA     #0
                STA     guard
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PHA
                FGX2_FARCALL bump
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #42
                STA     [_fcc_fpr0]
                LDA     g
                TAX
                LDA     #42
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _int_to_ptr_implicit_L2
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
_int_to_ptr_implicit_L2
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _int_to_ptr_implicit_L3
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
_int_to_ptr_implicit_L3
                LDA     #1
                STA     dolg
                LDA     #9
                PHA
                FGX2_FARCALL pick
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _int_to_ptr_implicit_L4
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
_int_to_ptr_implicit_L4
                LDA     #0
                PHA
                FGX2_FARCALL pick
                TAY
                PLA
                TYA
                SEP     #$20
                MX      %10
                LDA     cmdadr+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     cmdadr
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _int_to_ptr_implicit_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _int_to_ptr_implicit_L6
                LDA     #0
                BRL     _int_to_ptr_implicit_L7
_int_to_ptr_implicit_L6
                LDA     #1
_int_to_ptr_implicit_L7
                CMP     #0
                BNE     *+5
                BRL     _int_to_ptr_implicit_L5
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
_int_to_ptr_implicit_L5
                LDA     #0
                STA     guard
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #guard
                STA     _fcc_fpr0
                PHA
                FGX2_FARCALL bump
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #7
                STA     [_fcc_fpr0]
                LDA     guard
                TAX
                LDA     #7
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _int_to_ptr_implicit_L8
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
_int_to_ptr_implicit_L8
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
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
