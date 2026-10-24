                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sigjmpmask.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sjm_onint
sjm_onint            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sjm_onint_FRAMESIZE
                DO      sjm_onint_STKGUARD
                BCC     sjm_onint_stkovf
                CMP     _fcc_stkfloor
                BCS     sjm_onint_stkok
sjm_onint_stkovf       JMP     _fcc_stkoflow
                FIN
sjm_onint_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     sjm_hits
                INC
                STA     sjm_hits
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #sjm_env
                PHA
                LDA     #1
                PLX
                FGX2_FARCALL longjmp
                TAY
                TSC
                CLC
                ADC     #sjm_onint_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sjm_onint_FRAMESIZE   EQU     0
sjm_onint_STKGUARD    EQU     0
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
                LDA     _sigjmpmask_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _sigjmpmask_FA0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                FGX2_FARCALL signal
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #sjm_env
                TAX
                FGX2_FARCALL setjmp
                LDA     sjm_hits
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _sigjmpmask_L2
                EOR     #$8000
_sigjmpmask_L2
                BPL     _sigjmpmask_L1
                LDA     #2
                PHA
                FGX2_FARCALL getpid
                PHA
                FGX2_FARCALL kill
                TAY
                PLA
                PLA
                TYA
_sigjmpmask_L1
                LDA     sjm_hits
                TAX
                TXA
                CMP     #3
                BNE     _sigjmpmask_L3
                LDA     #21
                BRA     _sigjmpmask_L4
_sigjmpmask_L3
                LDA     #0
_sigjmpmask_L4
                STA     1,S   ; fccstk d=0 b=1
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL sigblock
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                TAX
                TXA
                SEC
                SBC     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shl
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
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
                BEQ     _sigjmpmask_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #21
                STA     1,S   ; fccstk d=0 b=1
_sigjmpmask_L5
                LDA     1,S   ; fccstk d=0 b=1
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
                FGX2_RELOC_COUNT 9
