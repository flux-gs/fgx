                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from setjmp_jump.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT jump_from_deep
jump_from_deep            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #jump_from_deep_FRAMESIZE
                DO      jump_from_deep_STKGUARD
                BCC     jump_from_deep_stkovf
                CMP     _fcc_stkfloor
                BCS     jump_from_deep_stkok
jump_from_deep_stkovf       JMP     _fcc_stkoflow
                FIN
jump_from_deep_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     marker
                TAX
                DO      6+jump_from_deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+jump_from_deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+jump_from_deep_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                TXA
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
                DO      8+jump_from_deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+jump_from_deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+jump_from_deep_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                INC
                PLX
                FGX2_FARCALL longjmp
                TAY
                TSC
                CLC
                ADC     #jump_from_deep_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
jump_from_deep_FRAMESIZE   EQU     0
jump_from_deep_STKGUARD    EQU     0
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
                STA     marker
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
                STA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BNE     _setjmp_jump_L0
                LDA     #40
                PHA
                FGX2_FARCALL jump_from_deep
                TAY
                PLA
                TYA
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
_setjmp_jump_L0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #41
                BEQ     _setjmp_jump_L1
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
_setjmp_jump_L1
                LDA     marker
                TAX
                CMP     #40
                BEQ     _setjmp_jump_L2
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
_setjmp_jump_L2
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
                STA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BNE     _setjmp_jump_L3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #env
                PHA
                LDA     #0
                PLX
                FGX2_FARCALL longjmp
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
_setjmp_jump_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #1
                BEQ     _setjmp_jump_L4
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
_setjmp_jump_L4
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
                CMP     #0
                BEQ     _setjmp_jump_L6
                CMP     #7
                BEQ     _setjmp_jump_L7
                BRA     _setjmp_jump_L8
_setjmp_jump_L6
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #env
                PHA
                LDA     #7
                PLX
                FGX2_FARCALL longjmp
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
_setjmp_jump_L7
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
_setjmp_jump_L8
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_setjmp_jump_L5
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 10
