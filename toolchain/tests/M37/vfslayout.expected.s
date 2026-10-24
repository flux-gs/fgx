                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from vfslayout.c
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
                LDA     #64
                TAX
                CMP     #64
                BEQ     _vfslayout_L0
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
_vfslayout_L0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gdi+12
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gdi
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #12
                BEQ     _vfslayout_L1
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
_vfslayout_L1
                LDA     #100
                TAX
                LDX     #104
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vfslayout_L3
                EOR     #$8000
_vfslayout_L3
                BPL     _vfslayout_L2
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
_vfslayout_L2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                BEQ     _vfslayout_L4
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
_vfslayout_L4
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+36
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CLC
                ADC     #64
                LDX     #100
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vfslayout_L6
                EOR     #$8000
_vfslayout_L6
                BPL     _vfslayout_L5
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
_vfslayout_L5
                LDA     #100
                TAX
                CMP     #100
                BEQ     _vfslayout_L7
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
_vfslayout_L7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+8
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #8
                BEQ     _vfslayout_L8
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
_vfslayout_L8
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+12
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #12
                BEQ     _vfslayout_L9
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
_vfslayout_L9
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+16
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #16
                BEQ     _vfslayout_L10
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
_vfslayout_L10
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+18
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #18
                BEQ     _vfslayout_L11
                LDA     #43
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L11
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+20
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #20
                BEQ     _vfslayout_L12
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
_vfslayout_L12
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+22
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #22
                BEQ     _vfslayout_L13
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
_vfslayout_L13
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+24
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #24
                BEQ     _vfslayout_L14
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
_vfslayout_L14
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+28
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #28
                BEQ     _vfslayout_L15
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
_vfslayout_L15
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+32
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #32
                BEQ     _vfslayout_L16
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
_vfslayout_L16
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gin+36
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gin
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #36
                BEQ     _vfslayout_L17
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
_vfslayout_L17
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gvn
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gvn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                BEQ     _vfslayout_L18
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
_vfslayout_L18
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gvn+2
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gvn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #2
                BEQ     _vfslayout_L19
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
_vfslayout_L19
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gvn+10
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gvn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #10
                BEQ     _vfslayout_L20
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
_vfslayout_L20
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gvn+14
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gvn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #14
                BEQ     _vfslayout_L21
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
_vfslayout_L21
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gvn+18
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gvn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #18
                BEQ     _vfslayout_L22
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
_vfslayout_L22
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gvn+22
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gvn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #22
                BEQ     _vfslayout_L23
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
_vfslayout_L23
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gvn+60
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gvn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #60
                BEQ     _vfslayout_L24
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
_vfslayout_L24
                LDA     #164
                PHA
                LDA     #60
                TAX
                CLC
                ADC     #104
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _vfslayout_L25
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
_vfslayout_L25
                LDA     #164
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gvn+60
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gvn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #104
                BEQ     _vfslayout_L26
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
_vfslayout_L26
                LDA     #100
                TAX
                CMP     #100
                BEQ     _vfslayout_L27
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
_vfslayout_L27
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gsf+4
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gsf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #4
                BEQ     _vfslayout_L28
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
_vfslayout_L28
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gsf+36
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gsf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #36
                BEQ     _vfslayout_L29
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
_vfslayout_L29
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gsf+68
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gsf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #68
                BEQ     _vfslayout_L30
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
_vfslayout_L30
                LDA     #130
                TAX
                CMP     #130
                BEQ     _vfslayout_L31
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
_vfslayout_L31
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gmn+26
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gmn
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #26
                BEQ     _vfslayout_L32
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
_vfslayout_L32
                LDA     #2048
                STA     gvn+0
                TAX
                CMP     #2048
                BEQ     _vfslayout_L33
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L33
                LDA     #8192
                STA     gbf+0
                TAX
                CMP     #8192
                BEQ     _vfslayout_L34
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L34
                LDA     #$0100
                STA     _fcc_long_hi
                LDA     #$0000
                STA     gmn+20
                TAY
                LDA     _fcc_long_hi
                STA     gmn+22
                TYA
                LDA     gmn+22
                STA     _fcc_long_hi
                LDA     gmn+20
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0100
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
                BEQ     _vfslayout_L35
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L35
                LDA     #1
                STA     gsi+8
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     gsi+10
                TYA
                LDA     gsi+10
                STA     _fcc_long_hi
                LDA     gsi+8
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
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _vfslayout_L36
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L36
                LDA     #4
                TAX
                CMP     #4
                BEQ     _vfslayout_L37
                LDA     #48
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L37
                LDA     #1024
                TAX
                CMP     #2048
                BNE     _vfslayout_L38
                LDA     #49
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L38
                LDA     #256
                TAX
                CMP     #512
                BNE     _vfslayout_L39
                LDA     #50
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L39
                LDA     #1
                TAX
                ORA     #2
                TAX
                ORA     #4
                TAX
                ORA     #256
                TAX
                ORA     #512
                TAX
                ORA     #1024
                TAX
                ORA     #2048
                TAX
                LDA     #1
                TAY
                TYA
                INC
                INC
                TAY
                TYA
                CLC
                ADC     #4
                TAY
                TYA
                CLC
                ADC     #256
                TAY
                TYA
                CLC
                ADC     #512
                TAY
                TYA
                CLC
                ADC     #1024
                TAY
                TYA
                CLC
                ADC     #2048
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _vfslayout_L40
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L40
                LDA     #14
                TAX
                CMP     #14
                BEQ     _vfslayout_L41
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L41
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gsi
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gsi
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                BEQ     _vfslayout_L42
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L42
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gsi+4
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gsi
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #4
                BEQ     _vfslayout_L43
                LDA     #58
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L43
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gsi+8
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gsi
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #8
                BEQ     _vfslayout_L44
                LDA     #59
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L44
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gsi+12
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gsi
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #12
                BEQ     _vfslayout_L45
                LDA     #60
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L45
                LDA     #4
                TAX
                CMP     #4
                BEQ     _vfslayout_L46
                LDA     #61
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L46
                LDA     #4
                TAX
                CMP     #4
                BEQ     _vfslayout_L47
                LDA     #62
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L47
                LDA     #4
                TAX
                CMP     #4
                BEQ     _vfslayout_L48
                LDA     #63
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L48
                LDA     #8
                TAX
                LDA     #8
                TAY
                TYA
                DEC
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                BEQ     _vfslayout_L49
                LDA     #64
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L49
                LDA     #64
                TAX
                CMP     #64
                BEQ     _vfslayout_L50
                LDA     #65
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L50
                LDA     #16
                TAX
                LDA     #16
                TAY
                TYA
                DEC
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                BEQ     _vfslayout_L51
                LDA     #66
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L51
                LDA     #158
                TAX
                CMP     #158
                BEQ     _vfslayout_L52
                LDA     #70
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L52
                LDA     #128
                TAX
                CMP     #128
                BEQ     _vfslayout_L53
                LDA     #71
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L53
                LDA     #2
                TAX
                SEC
                SBC     #2
                BVC     _vfslayout_L55
                EOR     #$8000
_vfslayout_L55
                BPL     _vfslayout_L54
                LDA     #72
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L54
                LDA     #24
                TAX
                CMP     #24
                BEQ     _vfslayout_L56
                LDA     #73
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L56
                LDA     #4
                TAX
                CMP     #4
                BEQ     _vfslayout_L57
                LDA     #74
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L57
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfl
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfl
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                BEQ     _vfslayout_L58
                LDA     #77
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L58
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfl+2
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfl
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #2
                BEQ     _vfslayout_L59
                LDA     #78
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L59
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfl+4
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfl
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #4
                BEQ     _vfslayout_L60
                LDA     #79
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L60
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfl+6
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfl
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #6
                BEQ     _vfslayout_L61
                LDA     #80
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L61
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfl+8
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfl
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #8
                BEQ     _vfslayout_L62
                LDA     #81
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L62
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfl+12
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfl
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #12
                BEQ     _vfslayout_L63
                LDA     #82
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L63
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfl+16
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfl
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #16
                BEQ     _vfslayout_L64
                LDA     #83
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L64
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gfl+20
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gfl
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #20
                BEQ     _vfslayout_L65
                LDA     #84
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L65
                LDA     #64
                TAX
                LDA     #3
                TAY
                TYA
                CLC
                ADC     #32
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vfslayout_L67
                EOR     #$8000
_vfslayout_L67
                BPL     _vfslayout_L66
                LDA     #75
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L66
                LDA     #32
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                TAX
                LDX     #64
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vfslayout_L69
                EOR     #$8000
_vfslayout_L69
                BMI     _vfslayout_L68
                LDA     #76
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L68
                LDA     #50
                TAX
                CMP     #50
                BEQ     _vfslayout_L70
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
_vfslayout_L70
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbf+2
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gbf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #2
                BEQ     _vfslayout_L71
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
_vfslayout_L71
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbf+22
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gbf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #22
                BEQ     _vfslayout_L72
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
_vfslayout_L72
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbf+24
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gbf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #24
                BEQ     _vfslayout_L73
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
_vfslayout_L73
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbf+28
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gbf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #28
                BEQ     _vfslayout_L74
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
_vfslayout_L74
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbf+32
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gbf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #32
                BEQ     _vfslayout_L75
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
_vfslayout_L75
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbf+38
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gbf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #38
                BEQ     _vfslayout_L76
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
_vfslayout_L76
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbf+42
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gbf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #42
                BEQ     _vfslayout_L77
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
_vfslayout_L77
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbf+46
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gbf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #46
                BEQ     _vfslayout_L78
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
_vfslayout_L78
                LDA     #4
                TAX
                CMP     #4
                BEQ     _vfslayout_L79
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
_vfslayout_L79
                LDA     #4
                TAX
                CMP     #4
                BEQ     _vfslayout_L80
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
_vfslayout_L80
                LDA     #4
                TAX
                CMP     #4
                BEQ     _vfslayout_L81
                LDA     #43
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L81
                LDA     #64
                TAX
                LDA     #32
                TAY
                TYA
                CLC
                ADC     #14
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _vfslayout_L83
                EOR     #$8000
_vfslayout_L83
                BPL     _vfslayout_L82
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
_vfslayout_L82
                LDA     #64
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #164
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
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #14
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #130
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
                LDA     #16
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #50
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
                JSR     _fcc_long_gts
                CMP     #0
                BEQ     _vfslayout_L84
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
_vfslayout_L84
                LDA     #16
                JSR     _fcc_long_from_int
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
                JSR     _fcc_long_gts
                CMP     #0
                BEQ     _vfslayout_L85
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
_vfslayout_L85
                LDA     #1024
                TAX
                CMP     #1024
                BEQ     _vfslayout_L86
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
_vfslayout_L86
                LDA     #16
                TAX
                CMP     #16
                BEQ     _vfslayout_L87
                LDA     #77
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L87
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gui
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gui
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                BEQ     _vfslayout_L88
                LDA     #78
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L88
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gui+4
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gui
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #4
                BEQ     _vfslayout_L89
                LDA     #79
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L89
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gui+6
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gui
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #6
                BEQ     _vfslayout_L90
                LDA     #80
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L90
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gui+10
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gui
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #10
                BEQ     _vfslayout_L91
                LDA     #81
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L91
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gui+12
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gui
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #12
                BEQ     _vfslayout_L92
                LDA     #82
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L92
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gui+14
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gui
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #14
                BEQ     _vfslayout_L93
                LDA     #83
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L93
                LDA     #6
                TAX
                CMP     #6
                BEQ     _vfslayout_L94
                LDA     #84
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L94
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gui
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gui
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                BEQ     _vfslayout_L95
                LDA     #85
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_vfslayout_L95
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
