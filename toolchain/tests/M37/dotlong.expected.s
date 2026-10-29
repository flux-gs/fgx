                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dotlong.c
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
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                STA     g+0
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                TYA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g+0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #60
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     g+0
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                TYA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g+0
                LDX     #60
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _dotlong_L0
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
_dotlong_L0
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g+0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     g+0
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                TYA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g+0
                LDX     #61
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _dotlong_L1
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
_dotlong_L1
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g+0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                STA     g+0
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                TYA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g+0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g+0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     g+0
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                TYA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g+0
                LDX     #120
                STX     _fcc_long_b_lo
                LDX     #2
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _dotlong_L2
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
_dotlong_L2
                LDA     #$0003
                STA     _fcc_long_hi
                LDA     #$0001
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                LDX     #3
                STX     _fcc_long_b_lo
                LDX     #3
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _dotlong_L3
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
_dotlong_L3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                LDX     #4
                STX     _fcc_long_b_lo
                LDX     #3
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _dotlong_L4
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
_dotlong_L4
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
