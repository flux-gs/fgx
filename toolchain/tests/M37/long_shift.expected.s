                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_shift.c
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
                LDA     #$0001
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                ASL
                ROL     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
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
                BEQ     _long_shift_L0
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
_long_shift_L0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
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
                BEQ     _long_shift_L1
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
_long_shift_L1
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$1234
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$2340
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
                BEQ     _long_shift_L2
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
_long_shift_L2
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                ASL
                ROL     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
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
                BEQ     _long_shift_L3
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
_long_shift_L3
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                ASL
                ROL     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L4
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
_long_shift_L4
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a
                STA     _fcc_long_hi
                LDA     #0
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
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
                BEQ     _long_shift_L5
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
_long_shift_L5
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$1234
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a
                STA     _fcc_long_hi
                LDA     #0
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$0000
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
                BEQ     _long_shift_L6
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
_long_shift_L6
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a
                ASL
                STA     _fcc_long_hi
                LDA     #0
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0002
                STA     _fcc_long_hi
                LDA     #$0000
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
                BEQ     _long_shift_L7
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
_long_shift_L7
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_long_hi
                LDA     #0
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L8
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
_long_shift_L8
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$2340
                STA     ua
                TAY
                LDA     _fcc_long_hi
                STA     ua+2
                TYA
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                STA     ur
                TAY
                LDA     _fcc_long_hi
                STA     ur+2
                TYA
                LDA     ur+2
                STA     _fcc_long_hi
                LDA     ur
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$1234
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
                BEQ     _long_shift_L9
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
_long_shift_L9
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                STA     ua
                TAY
                LDA     _fcc_long_hi
                STA     ua+2
                TYA
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                STA     ur
                TAY
                LDA     _fcc_long_hi
                STA     ur+2
                TYA
                LDA     ur+2
                STA     _fcc_long_hi
                LDA     ur
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
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
                BEQ     _long_shift_L10
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
_long_shift_L10
                LDA     #$0003
                STA     _fcc_long_hi
                LDA     #$0000
                STA     ua
                TAY
                LDA     _fcc_long_hi
                STA     ua+2
                TYA
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                STA     ur
                TAY
                LDA     _fcc_long_hi
                STA     ur+2
                TYA
                LDA     ur+2
                STA     _fcc_long_hi
                LDA     ur
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$8000
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
                BEQ     _long_shift_L11
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
_long_shift_L11
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     ua
                TAY
                LDA     _fcc_long_hi
                STA     ua+2
                TYA
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #15
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shru
                STA     ur
                TAY
                LDA     _fcc_long_hi
                STA     ur+2
                TYA
                LDA     ur+2
                STA     _fcc_long_hi
                LDA     ur
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                BEQ     _long_shift_L12
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
_long_shift_L12
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                STA     ua
                TAY
                LDA     _fcc_long_hi
                STA     ua+2
                TYA
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                STZ     _fcc_long_hi
                STA     ur
                TAY
                LDA     _fcc_long_hi
                STA     ur+2
                TYA
                LDA     ur+2
                STA     _fcc_long_hi
                LDA     ur
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$1234
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
                BEQ     _long_shift_L13
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
_long_shift_L13
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                STA     ua
                TAY
                LDA     _fcc_long_hi
                STA     ua+2
                TYA
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                LSR
                LSR
                LSR
                LSR
                STZ     _fcc_long_hi
                STA     ur
                TAY
                LDA     _fcc_long_hi
                STA     ur+2
                TYA
                LDA     ur+2
                STA     _fcc_long_hi
                LDA     ur
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0123
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
                BEQ     _long_shift_L14
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
_long_shift_L14
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     ua
                TAY
                LDA     _fcc_long_hi
                STA     ua+2
                TYA
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                STZ     _fcc_long_hi
                STA     ur
                TAY
                LDA     _fcc_long_hi
                STA     ur+2
                TYA
                LDA     ur+2
                STA     _fcc_long_hi
                LDA     ur
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                BEQ     _long_shift_L15
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
_long_shift_L15
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$2340
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                LDX     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                CPX     #$8000
                BCC     _long_shift_L16
                ORA     #$F000
_long_shift_L16
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$1234
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
                BEQ     _long_shift_L17
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
_long_shift_L17
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                LDX     #0
                CMP     #$8000
                BCC     _long_shift_L18
                LDX     #$FFFF
_long_shift_L18
                STX     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$1234
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
                BEQ     _long_shift_L19
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
_long_shift_L19
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                LDX     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                CPX     #$8000
                BCC     _long_shift_L20
                ORA     #$8000
_long_shift_L20
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L21
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
_long_shift_L21
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                LDX     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                CPX     #$8000
                BCC     _long_shift_L22
                ORA     #$8000
_long_shift_L22
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L23
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
_long_shift_L23
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0400
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                LDX     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                CPX     #$8000
                BCC     _long_shift_L24
                ORA     #$FFC0
_long_shift_L24
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L25
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
_long_shift_L25
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0401
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                LDX     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                CPX     #$8000
                BCC     _long_shift_L26
                ORA     #$FFC0
_long_shift_L26
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L27
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
_long_shift_L27
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                LDX     #0
                CMP     #$8000
                BCC     _long_shift_L28
                LDX     #$FFFF
_long_shift_L28
                STX     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L29
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
_long_shift_L29
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                LDX     #0
                CMP     #$8000
                BCC     _long_shift_L30
                LDX     #$FFFF
_long_shift_L30
                STX     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L31
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
_long_shift_L31
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #31
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L32
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
_long_shift_L32
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #15
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L33
                LDA     #26
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L33
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                LDX     #0
                CMP     #$8000
                BCC     _long_shift_L34
                LDX     #$FFFF
_long_shift_L34
                STX     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L35
                LDA     #27
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L35
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                ASL
                ROL     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
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
                BEQ     _long_shift_L36
                LDA     #28
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L36
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                ASL
                ROL     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
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
                BEQ     _long_shift_L37
                LDA     #29
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L37
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
                JSR     _fcc_long_neg
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                ASL
                ROL     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                JSR     _fcc_long_neg
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
                BEQ     _long_shift_L38
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L38
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a
                STA     _fcc_long_hi
                LDA     #0
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0005
                STA     _fcc_long_hi
                LDA     #$0000
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
                BEQ     _long_shift_L39
                LDA     #31
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L39
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
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
                BEQ     _long_shift_L40
                LDA     #32
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L40
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #3
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$012C
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
                BEQ     _long_shift_L41
                LDA     #33
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L41
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
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
                BEQ     _long_shift_L42
                LDA     #34
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L42
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
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
                BEQ     _long_shift_L43
                LDA     #35
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L43
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                TYA
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0010
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
                BEQ     _long_shift_L44
                LDA     #36
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_shift_L44
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
