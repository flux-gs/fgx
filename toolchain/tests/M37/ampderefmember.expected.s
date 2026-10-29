                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ampderefmember.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT fill
fill            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fill_FRAMESIZE
                DO      fill_STKGUARD
                BCC     fill_stkovf
                CMP     _fcc_stkfloor
                BCS     fill_stkok
fill_stkovf       JMP     _fcc_stkoflow
                FIN
fill_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                LDA     [_fcc_img2]
                PHA
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                CLC
                ADC     #3
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     #77
                SEP     #$20
                MX      %10
                STA     [_fcc_img0]
                REP     #$20
                MX      %00
                LDA     [_fcc_img2]
                PHA
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                PLA
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                STA     [_fcc_img4]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_img4],Y
                TXA
                LDA     [_fcc_img2]
                PHA
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                CLC
                ADC     #5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     #55
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #fill_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fill_FRAMESIZE   EQU     8
fill_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #main_FRAMESIZE-8
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #bufs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #data
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bufs+10
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fill
                PLY
                PLY
                LDA     #3
                TAX
                LDA:    data,X
                AND     #$00FF
                TAX
                CMP     #77
                BEQ     _ampderefmember_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ampderefmember_L0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #bufs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #6
                LDA     [_fcc_fpr0],Y
                LDX     #57920
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ampderefmember_L1
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ampderefmember_L1
                LDA     #5
                TAX
                LDA:    data,X
                AND     #$00FF
                TAX
                CMP     #55
                BEQ     _ampderefmember_L2
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ampderefmember_L2
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     #bufs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #6
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ampderefmember_L3
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ampderefmember_L3
                LDA     [_fcc_img16]
                PHA
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #9
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #bufs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                CMP     #9
                BEQ     _ampderefmember_L4
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ampderefmember_L4
                LDA     [_fcc_img16]
                PHA
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                CLC
                ADC     #6
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #bufs+16
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ampderefmember_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ampderefmember_L7
                LDA     #0
                BRA     _ampderefmember_L8
_ampderefmember_L7
                LDA     #1
_ampderefmember_L8
                CMP     #0
                BNE     _ampderefmember_L6
                LDA     [_fcc_img16]
                PHA
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ampderefmember_L9
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ampderefmember_L9
                LDA     #1
                BRA     _ampderefmember_L10
_ampderefmember_L9
                LDA     #0
_ampderefmember_L10
                CMP     #0
                BEQ     _ampderefmember_L5
_ampderefmember_L6
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRA     main_bandx
_ampderefmember_L5
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #data
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     [_fcc_img18]
                PHA
                LDY     #2
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #3
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                STA     _fcc_ptr
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #77
                BEQ     _ampderefmember_L11
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRA     main_bandx
_ampderefmember_L11
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
main_bandx
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     32
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
