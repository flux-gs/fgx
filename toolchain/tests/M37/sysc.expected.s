                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sysc.c
;---------------------------------------

                MX      %00
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
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_sysc_path
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_fpr0
                STA     11,S   ; fccstk d=0 b=11
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                STZ     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                PHA
                LDA     #0
                PHA
                LDA     #0
                TAY
                PLX
                PLA
                JSL     SYS_TRAMP
                DFB     24
                LDX     #0
                BCC     _sysc_L1
                LDX     #1
_sysc_L1
                STX     __sys_c
                STY     __sys_y
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _sysc_L0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_sysc_L0
                LDA     __sys_c
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _sysc_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #20
                STA     1,S   ; fccstk d=0 b=1
_sysc_L2
                LDA     __sys_y
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _sysc_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #2
                STA     1,S   ; fccstk d=0 b=1
_sysc_L3
                PHB
                LDA     10,S   ; fccstk d=1 b=9
                PHA
                LDA     #0
                PHA
                LDA     #0
                PHA
                LDA     14,S   ; fccstk d=7 b=7
                SEP     #$20
                MX      %10
                PHA
                PLB
                REP     #$20
                MX      %00
                PLY
                PLX
                PLA
                JSL     SYS_TRAMP
                DFB     5
                PLB
                LDX     #0
                BCC     _sysc_L4
                LDX     #1
_sysc_L4
                STX     __sys_c
                STY     __sys_y
                LDA     __sys_c
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _sysc_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #12
                STA     1,S   ; fccstk d=0 b=1
_sysc_L5
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
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
