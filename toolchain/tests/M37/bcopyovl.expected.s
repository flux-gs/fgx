                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bcopyovl.c
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
                LDA     #0
                STA     _fcc_img0
_bcopyovl_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #40
                BVC     _bcopyovl_L3
                EOR     #$8000
_bcopyovl_L3
                BPL     _bcopyovl_L2
                LDA     #a
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img0
                CLC
                ADC     #w
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #65
                CLC
                ADC     _fcc_img0
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
_bcopyovl_L1
                INC     _fcc_img0
                BRA     _bcopyovl_L0
_bcopyovl_L2
                TAY
                TSC
                CLC
                ADC     #fill_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fill_FRAMESIZE   EQU     2
fill_STKGUARD    EQU     0
                FGX2_EXPORT ref
ref            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ref_FRAMESIZE
                DO      ref_STKGUARD
                BCC     ref_stkovf
                CMP     _fcc_stkfloor
                BCS     ref_stkok
ref_stkovf       JMP     _fcc_stkoflow
                FIN
ref_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+ref_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ref_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ref_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img1
                DO      6+ref_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ref_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ref_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+ref_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ref_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ref_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                LDA     #0
                STA     _fcc_img0
_bcopyovl_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _bcopyovl_L7
                EOR     #$8000
_bcopyovl_L7
                BPL     _bcopyovl_L6
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img2
                CLC
                ADC     _fcc_img0
                TAX
                LDA:    w,X
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
_bcopyovl_L5
                INC     _fcc_img0
                BRA     _bcopyovl_L4
_bcopyovl_L6
                LDA     #0
                STA     _fcc_img0
_bcopyovl_L8
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _bcopyovl_L11
                EOR     #$8000
_bcopyovl_L11
                BPL     _bcopyovl_L10
                LDA     #w
                PHA
                LDA     _fcc_img3
                CLC
                ADC     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
_bcopyovl_L9
                INC     _fcc_img0
                BRA     _bcopyovl_L8
_bcopyovl_L10
                LDA     #0
                STA     _fcc_img0
_bcopyovl_L12
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #40
                BVC     _bcopyovl_L15
                EOR     #$8000
_bcopyovl_L15
                BPL     _bcopyovl_L14
                LDA     _fcc_img0
                TAX
                LDA:    a,X
                AND     #$00FF
                PHA
                LDA     _fcc_img0
                TAX
                LDA:    w,X
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _bcopyovl_L16
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #ref_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bcopyovl_L16
_bcopyovl_L13
                INC     _fcc_img0
                BRA     _bcopyovl_L12
_bcopyovl_L14
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #ref_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ref_FRAMESIZE   EQU     42
ref_STKGUARD    EQU     0
                FGX2_EXPORT one
one            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #one_FRAMESIZE
                DO      one_STKGUARD
                BCC     one_stkovf
                CMP     _fcc_stkfloor
                BCS     one_stkok
one_stkovf       JMP     _fcc_stkoflow
                FIN
one_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                FGX2_FARCALL fill
                DO      10+one_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+one_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+one_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                DO      10+one_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+one_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+one_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                CLC
                ADC     #a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+one_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+one_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+one_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                CLC
                ADC     #a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bcopy
                TSC
                CLC
                ADC     #10
                TCS
                DO      10+one_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+one_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+one_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                DO      10+one_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+one_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+one_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                PHA
                DO      10+one_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+one_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+one_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                PHA
                FGX2_FARCALL ref
                TAY
                PLA
                PLA
                PLA
                TYA
                TAY
                TSC
                CLC
                ADC     #one_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
one_FRAMESIZE   EQU     0
one_STKGUARD    EQU     0
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
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #7
                PHA
                LDA     #5
                PHA
                LDA     #4
                PHA
                FGX2_FARCALL one
                TAY
                PLA
                PLA
                PLA
                TYA
                BEQ     _bcopyovl_L17
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_bcopyovl_L17
                LDA     #8
                PHA
                LDA     #5
                PHA
                LDA     #4
                PHA
                FGX2_FARCALL one
                TAY
                PLA
                PLA
                PLA
                TYA
                BEQ     _bcopyovl_L18
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_bcopyovl_L18
                LDA     #7
                PHA
                LDA     #4
                PHA
                LDA     #5
                PHA
                FGX2_FARCALL one
                TAY
                PLA
                PLA
                PLA
                TYA
                BEQ     _bcopyovl_L19
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_bcopyovl_L19
                LDA     #8
                PHA
                LDA     #4
                PHA
                LDA     #5
                PHA
                FGX2_FARCALL one
                TAY
                PLA
                PLA
                PLA
                TYA
                BEQ     _bcopyovl_L20
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_bcopyovl_L20
                LDA     #13
                PHA
                LDA     #20
                PHA
                LDA     #0
                PHA
                FGX2_FARCALL one
                TAY
                PLA
                PLA
                PLA
                TYA
                BEQ     _bcopyovl_L21
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_bcopyovl_L21
                LDA     #9
                PHA
                LDA     #3
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL one
                TAY
                PLA
                PLA
                PLA
                TYA
                BEQ     _bcopyovl_L22
                LDA     #1
                PHA
                LDA     #9
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL one
                TAY
                PLA
                PLA
                PLA
                TYA
                BEQ     _bcopyovl_L22
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_bcopyovl_L22
                FGX2_FARCALL fill
                LDA     #0
                PHA
                LDA     #2
                CLC
                ADC     #a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                CLC
                ADC     #a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bcopy
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #$FFFF
                PHA
                LDA     #2
                CLC
                ADC     #a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                CLC
                ADC     #a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bcopy
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #0
                PHA
                LDA     #0
                PHA
                LDA     #0
                PHA
                FGX2_FARCALL ref
                TAY
                PLA
                PLA
                PLA
                TYA
                BEQ     _bcopyovl_L23
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_bcopyovl_L23
                LDA     1,S   ; fccstk d=0 b=1
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
                FGX2_RELOC_COUNT 19
