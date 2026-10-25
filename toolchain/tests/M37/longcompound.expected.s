                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from longcompound.c
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
                LDA     #$6A52
                STA     _fcc_long_hi
                LDA     #$0001
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                TYA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                LDX     #60
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_add
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                TYA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                LDX     #61
                STX     _fcc_long_b_lo
                LDX     #27218
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _longcompound_L0
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
_longcompound_L0
                LDA     #2
                STA     5,S   ; fccstk d=0 b=5
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
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
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                TYA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                LDX     #59
                STX     _fcc_long_b_lo
                LDX     #27218
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _longcompound_L1
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
_longcompound_L1
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     h+2
                STA     _fcc_long_hi
                LDA     h
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                TYA
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                LDX     #64
                STX     _fcc_long_b_lo
                LDX     #27220
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _longcompound_L2
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
_longcompound_L2
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                LDX     #20
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_add
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                LDX     #20
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _longcompound_L3
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
_longcompound_L3
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                LDX     #40
                STX     _fcc_long_b_lo
                LDX     #2
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _longcompound_L4
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
_longcompound_L4
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
