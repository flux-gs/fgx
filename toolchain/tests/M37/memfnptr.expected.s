                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from memfnptr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT add3
add3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add3_FRAMESIZE
                DO      add3_STKGUARD
                BCC     add3_stkovf
                CMP     _fcc_stkfloor
                BCS     add3_stkok
add3_stkovf       JMP     _fcc_stkoflow
                FIN
add3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add3_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add3_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #add3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add3_FRAMESIZE   EQU     0
add3_STKGUARD    EQU     0
                FGX2_EXPORT dbl
dbl            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dbl_FRAMESIZE
                DO      dbl_STKGUARD
                BCC     dbl_stkovf
                CMP     _fcc_stkfloor
                BCS     dbl_stkok
dbl_stkovf       JMP     _fcc_stkoflow
                FIN
dbl_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+dbl_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dbl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dbl_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                ASL
                TAY
                TSC
                CLC
                ADC     #dbl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dbl_FRAMESIZE   EQU     0
dbl_STKGUARD    EQU     0
                FGX2_EXPORT setside
setside            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #setside_FRAMESIZE
                DO      setside_STKGUARD
                BCC     setside_stkovf
                CMP     _fcc_stkfloor
                BCS     setside_stkok
setside_stkovf       JMP     _fcc_stkoflow
                FIN
setside_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #30
                STA     g_side
                TAY
                TSC
                CLC
                ADC     #setside_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
setside_FRAMESIZE   EQU     0
setside_STKGUARD    EQU     0
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
                LDA     #g_o
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_e
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                SEP     #$20
                MX      %10
                LDA     _memfnptr_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _memfnptr_FA0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     g_in+0
                TAY
                LDA     _fcc_ptr+2
                STA     g_in+2
                TYA
                LDA     #0
                STA     g_in+4
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #g_in
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _memfnptr_FA1+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _memfnptr_FA1
                STA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _memfnptr_FA2+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _memfnptr_FA2
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #5
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _memfnptr_L4-1
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
_memfnptr_L4
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _memfnptr_L3
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_memfnptr_L3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #7
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _memfnptr_L6-1
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
_memfnptr_L6
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _memfnptr_L5
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_memfnptr_L5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #3
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _memfnptr_L7-1
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
_memfnptr_L7
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _memfnptr_L8-1
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
_memfnptr_L8
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     g_side
                TAX
                LDA     #30
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _memfnptr_L9
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_memfnptr_L9
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr1+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                LDA     #9
                PHA
                LDA     3,S
                STA     _fcc_fpr1
                LDA     5,S
                STA     _fcc_fpr1+2
                PHK
                PEA     _memfnptr_L10-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                DEC
                PHA
                RTL
_memfnptr_L10
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _memfnptr_L11
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_memfnptr_L11
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
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 5
