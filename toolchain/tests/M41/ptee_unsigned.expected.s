                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptee_unsigned.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT viaptr
viaptr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #viaptr_FRAMESIZE
                DO      viaptr_STKGUARD
                BCC     viaptr_stkovf
                CMP     _fcc_stkfloor
                BCS     viaptr_stkok
viaptr_stkovf       JMP     _fcc_stkoflow
                FIN
viaptr_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+viaptr_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+viaptr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+viaptr_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+viaptr_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+viaptr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+viaptr_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+viaptr_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+viaptr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+viaptr_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #viaptr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
viaptr_FRAMESIZE   EQU     0
viaptr_STKGUARD    EQU     0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                LDX     #62024
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptee_unsigned_L0
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #10
                STA     9,S   ; fccstk d=0 b=9
_ptee_unsigned_L0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                LDX     #62024
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptee_unsigned_L1
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #10
                STA     9,S   ; fccstk d=0 b=9
_ptee_unsigned_L1
                LDA     #0
                ASL
                TAX
                LDA:    a,X
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                LDX     #62024
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptee_unsigned_L2
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #10
                STA     9,S   ; fccstk d=0 b=9
_ptee_unsigned_L2
                LDA     #0
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL viaptr
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                LDX     #62024
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptee_unsigned_L3
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #12
                STA     9,S   ; fccstk d=0 b=9
_ptee_unsigned_L3
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
