                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dirops.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT nameis
nameis            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #nameis_FRAMESIZE
                DO      nameis_STKGUARD
                BCC     nameis_stkovf
                CMP     _fcc_stkfloor
                BCS     nameis_stkok
nameis_stkovf       JMP     _fcc_stkoflow
                FIN
nameis_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+nameis_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+nameis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+nameis_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+nameis_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+nameis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+nameis_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+nameis_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+nameis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+nameis_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+nameis_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+nameis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+nameis_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img0
_dirops_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                BEQ     _dirops_L1
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _dirops_L1
                INC     _fcc_img0
                BRA     _dirops_L0
_dirops_L1
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_eq16
                TAY
                TSC
                CLC
                ADC     #nameis_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
nameis_FRAMESIZE   EQU     2
nameis_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img22
                TSC
                SEC
                SBC     #main_FRAMESIZE-14
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
                STA     13,S   ; fccstk d=0 b=13
                LDA     #0
                STA     15,S   ; fccstk d=0 b=15
                LDA     #0
                STA     17,S   ; fccstk d=0 b=17
                LDA     #1
                STA     _fcc_img22
                LDA     #0
                STA     21,S   ; fccstk d=0 b=21
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_dirops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL opendir
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _dirops_L3
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirops_L3
                LDA     #1
                BRA     _dirops_L4
_dirops_L3
                LDA     #0
_dirops_L4
                CMP     #0
                BEQ     _dirops_L2
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-14
                TCS
                BRL     main_bandx
_dirops_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_dirops_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL opendir
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
                LDA     _fcc_img21
                STA     _fcc_fpr0+2
                LDA     _fcc_img20
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _dirops_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirops_L6
                LDA     #0
                BRA     _dirops_L7
_dirops_L6
                LDA     #1
_dirops_L7
                CMP     #0
                BEQ     _dirops_L5
                LDA     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img20
                FGX2_FARCALL readdir
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _dirops_L9
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirops_L9
                LDA     #0
                BRA     _dirops_L10
_dirops_L9
                LDA     #1
_dirops_L10
                CMP     #0
                BEQ     _dirops_L8
                LDY     #2
                LDA     [_fcc_img18],Y
                CMP     #0
                BNE     _dirops_L8
                LDA     21,S   ; fccstk d=0 b=21
                TAX
                CLC
                ADC     #9
                STA     21,S   ; fccstk d=0 b=21
_dirops_L8
                LDA     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img20
                FGX2_FARCALL closedir
                PLY
                PLY
_dirops_L5
_dirops_L11
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                FGX2_FARCALL readdir
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _dirops_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirops_L13
                LDA     #0
                BRA     _dirops_L14
_dirops_L13
                LDA     #1
_dirops_L14
                CMP     #0
                BNE     *+5
                BRL     _dirops_L12
                LDA     13,S   ; fccstk d=0 b=13
                INC
                STA     13,S   ; fccstk d=0 b=13
                LDY     #2
                LDA     [_fcc_img16],Y
                TAX
                SEC
                SBC     #1
                BVC     _dirops_L17
                EOR     #$8000
_dirops_L17
                BMI     _dirops_L16
                LDY     #2
                LDA     [_fcc_img16],Y
                LDX     #15
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirops_L18
                EOR     #$8000
_dirops_L18
                BPL     _dirops_L15
_dirops_L16
                LDA     #0
                STA     _fcc_img22
_dirops_L15
                LDA     [_fcc_img16]
                BNE     _dirops_L19
                LDA     #0
                STA     _fcc_img22
_dirops_L19
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_dirops_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL nameis
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _dirops_L20
                LDA     #1
                STA     15,S   ; fccstk d=0 b=15
_dirops_L20
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_dirops_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL nameis
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _dirops_L21
                LDA     #1
                STA     17,S   ; fccstk d=0 b=17
_dirops_L21
                BRL     _dirops_L11
_dirops_L12
                LDA     13,S   ; fccstk d=0 b=13
                LDX     #10
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirops_L23
                EOR     #$8000
_dirops_L23
                BPL     _dirops_L22
                LDA     21,S   ; fccstk d=0 b=21
                TAX
                CLC
                ADC     #8
                STA     21,S   ; fccstk d=0 b=21
_dirops_L22
                LDA     _fcc_img22
                BEQ     _dirops_L24
                LDA     21,S   ; fccstk d=0 b=21
                TAX
                CLC
                ADC     #8
                STA     21,S   ; fccstk d=0 b=21
_dirops_L24
                LDA     15,S   ; fccstk d=0 b=15
                BEQ     _dirops_L25
                LDA     17,S   ; fccstk d=0 b=17
                BEQ     _dirops_L25
                LDA     21,S   ; fccstk d=0 b=21
                TAX
                CLC
                ADC     #8
                STA     21,S   ; fccstk d=0 b=21
_dirops_L25
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                FGX2_FARCALL closedir
                PLY
                PLY
                CMP     #0
                BEQ     *+5
                BRL     _dirops_L26
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_dirops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL opendir
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _dirops_L28
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirops_L28
                LDA     #0
                BRA     _dirops_L29
_dirops_L28
                LDA     #1
_dirops_L29
                CMP     #0
                BEQ     _dirops_L27
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                FGX2_FARCALL readdir
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _dirops_L31
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirops_L31
                LDA     #0
                BRA     _dirops_L32
_dirops_L31
                LDA     #1
_dirops_L32
                CMP     #0
                BEQ     _dirops_L30
                LDY     #2
                LDA     [_fcc_img16],Y
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirops_L33
                EOR     #$8000
_dirops_L33
                BPL     _dirops_L30
                LDA     21,S   ; fccstk d=0 b=21
                TAX
                CLC
                ADC     #9
                STA     21,S   ; fccstk d=0 b=21
_dirops_L30
                LDA     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img18
                FGX2_FARCALL closedir
                PLY
                PLY
_dirops_L27
_dirops_L26
                LDA     21,S   ; fccstk d=0 b=21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-14
                TCS
main_bandx
                PLA
                STA     _fcc_img22
                PLA
                STA     _fcc_img21
                PLA
                STA     _fcc_img20
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
main_FRAMESIZE   EQU     36
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 14
