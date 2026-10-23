                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pdplayout.c
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
                LDA     #2
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _pdplayout_L0
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
_pdplayout_L0
                LDA     #2
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _pdplayout_L1
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
_pdplayout_L1
                LDA     #4
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _pdplayout_L2
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
_pdplayout_L2
                LDA     #4
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _pdplayout_L3
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
_pdplayout_L3
                LDA     #2
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _pdplayout_L4
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
_pdplayout_L4
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gp
                INC
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gp
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _pdplayout_L5
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
_pdplayout_L5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gp
                CLC
                ADC     #6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gp
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #6
                BNE     *+5
                BRL     _pdplayout_L6
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
_pdplayout_L6
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gp
                CLC
                ADC     #8
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gp
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #8
                BNE     *+5
                BRL     _pdplayout_L7
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
_pdplayout_L7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gp
                CLC
                ADC     #12
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gp
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _pdplayout_L8
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
_pdplayout_L8
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gp
                CLC
                ADC     #20
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gp
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #20
                BNE     *+5
                BRL     _pdplayout_L9
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
_pdplayout_L9
                LDA     #24
                TAX
                TXA
                CMP     #24
                BNE     *+5
                BRL     _pdplayout_L10
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
_pdplayout_L10
                LDA     #64
                TAX
                TXA
                CMP     #64
                BNE     *+5
                BRL     _pdplayout_L11
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
_pdplayout_L11
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _pdplayout_L12
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
_pdplayout_L12
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                INC
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _pdplayout_L13
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
_pdplayout_L13
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                CLC
                ADC     #4
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _pdplayout_L14
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
_pdplayout_L14
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                CLC
                ADC     #6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #6
                BNE     *+5
                BRL     _pdplayout_L15
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
_pdplayout_L15
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                CLC
                ADC     #8
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #8
                BNE     *+5
                BRL     _pdplayout_L16
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
_pdplayout_L16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                CLC
                ADC     #12
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _pdplayout_L17
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
_pdplayout_L17
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                CLC
                ADC     #40
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #40
                BNE     *+5
                BRL     _pdplayout_L18
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
_pdplayout_L18
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                CLC
                ADC     #50
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #50
                BNE     *+5
                BRL     _pdplayout_L19
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
_pdplayout_L19
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                CLC
                ADC     #52
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #52
                BNE     *+5
                BRL     _pdplayout_L20
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
_pdplayout_L20
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                CLC
                ADC     #8
                CLC
                ADC     #52
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #60
                BNE     *+5
                BRL     _pdplayout_L21
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
_pdplayout_L21
                LDA     #70
                TAX
                TXA
                CMP     #70
                BNE     *+5
                BRL     _pdplayout_L22
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
_pdplayout_L22
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdir
                INC
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdir
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _pdplayout_L23
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
_pdplayout_L23
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdir
                CLC
                ADC     #4
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdir
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _pdplayout_L24
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
_pdplayout_L24
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdir
                CLC
                ADC     #6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdir
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #6
                BNE     *+5
                BRL     _pdplayout_L25
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
_pdplayout_L25
                LDA     #446
                TAX
                TXA
                CMP     #446
                BNE     *+5
                BRL     _pdplayout_L26
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
_pdplayout_L26
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                INC
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _pdplayout_L27
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
_pdplayout_L27
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #6
                BNE     *+5
                BRL     _pdplayout_L28
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
_pdplayout_L28
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #8
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #8
                BNE     *+5
                BRL     _pdplayout_L29
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
_pdplayout_L29
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #208
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #208
                BNE     *+5
                BRL     _pdplayout_L30
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
_pdplayout_L30
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #210
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #210
                BNE     *+5
                BRL     _pdplayout_L31
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
_pdplayout_L31
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #410
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #410
                BNE     *+5
                BRL     _pdplayout_L32
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
_pdplayout_L32
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #414
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #414
                BNE     *+5
                BRL     _pdplayout_L33
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
_pdplayout_L33
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #418
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #418
                BNE     *+5
                BRL     _pdplayout_L34
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
_pdplayout_L34
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #422
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #422
                BNE     *+5
                BRL     _pdplayout_L35
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
_pdplayout_L35
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #428
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #428
                BNE     *+5
                BRL     _pdplayout_L36
                LDA     #37
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pdplayout_L36
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #440
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #440
                BNE     *+5
                BRL     _pdplayout_L37
                LDA     #38
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pdplayout_L37
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #444
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #444
                BNE     *+5
                BRL     _pdplayout_L38
                LDA     #39
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pdplayout_L38
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #8
                STA     _fcc_fpr1
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _pdplayout_L39
                LDA     #40
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pdplayout_L39
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #210
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfs
                CLC
                ADC     #210
                STA     _fcc_fpr1
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _pdplayout_L40
                LDA     #41
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pdplayout_L40
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                CLC
                ADC     #12
                STA     _fcc_fpr1
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _pdplayout_L41
                LDA     #42
                TAX
                TXA
                INC
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pdplayout_L41
                LDA     #$0102
                STA     _fcc_long_hi
                LDA     #$0304
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                AND     #255
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _pdplayout_L42
                LDA     #44
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pdplayout_L42
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                AND     #255
                TAX
                TXA
                CMP     #3
                BNE     *+5
                BRL     _pdplayout_L43
                LDA     #45
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pdplayout_L43
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                AND     #255
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _pdplayout_L44
                LDA     #46
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pdplayout_L44
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                AND     #255
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _pdplayout_L45
                LDA     #47
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pdplayout_L45
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
                FGX2_RELOC_COUNT 2
