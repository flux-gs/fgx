                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_mods.c
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #2
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L0
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
_long_mods_L0
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #5
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L1
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
_long_mods_L1
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$03E8
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L2
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
_long_mods_L2
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #7
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L3
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
_long_mods_L3
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L4
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
_long_mods_L4
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$03E8
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #647
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L5
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
_long_mods_L5
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                JSR     _fcc_long_neg
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #2
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L6
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
_long_mods_L6
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                JSR     _fcc_long_neg
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #5
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L7
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L7
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$03E8
                JSR     _fcc_long_neg
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L8
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L8
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #65534
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L9
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L9
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #65531
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L10
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L10
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #65529
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L11
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L11
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                JSR     _fcc_long_neg
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #65534
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L12
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L12
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                JSR     _fcc_long_neg
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #65531
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L13
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L13
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$03E8
                JSR     _fcc_long_neg
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #64889
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L14
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L14
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0315
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divs
                STA     q
                TAY
                LDA     _fcc_long_hi
                STA     q+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     q+2
                STA     _fcc_long_hi
                LDA     q
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L15
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L15
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0315
                JSR     _fcc_long_neg
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divs
                STA     q
                TAY
                LDA     _fcc_long_hi
                STA     q+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     q+2
                STA     _fcc_long_hi
                LDA     q
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L16
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L16
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0315
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divs
                STA     q
                TAY
                LDA     _fcc_long_hi
                STA     q+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     q+2
                STA     _fcc_long_hi
                LDA     q
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L17
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L17
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0315
                JSR     _fcc_long_neg
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divs
                STA     q
                TAY
                LDA     _fcc_long_hi
                STA     q+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     q+2
                STA     _fcc_long_hi
                LDA     q
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L18
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L18
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0315
                JSR     _fcc_long_neg
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #64747
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_les
                CMP     #0
                BNE     _long_mods_L20
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_gts
                CMP     #0
                BEQ     _long_mods_L19
_long_mods_L20
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L19
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0315
                JSR     _fcc_long_neg
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #789
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ges
                CMP     #0
                BNE     _long_mods_L22
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_lts
                CMP     #0
                BEQ     _long_mods_L21
_long_mods_L22
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L21
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L23
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L23
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L24
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L24
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L25
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L25
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$3039
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mods
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                LDX     #12345
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _long_mods_L26
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_mods_L26
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
