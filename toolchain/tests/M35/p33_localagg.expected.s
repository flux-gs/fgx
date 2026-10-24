                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from p33_localagg.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT mk
mk            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #mk_FRAMESIZE
                DO      mk_STKGUARD
                BCC     mk_stkovf
                CMP     _fcc_stkfloor
                BCS     mk_stkok
mk_stkovf       JMP     _fcc_stkoflow
                FIN
mk_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+mk_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+mk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+mk_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+mk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+mk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+mk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      10+mk_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+mk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+mk_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                DO      12+mk_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+mk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+mk_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                LDY     #2
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #mk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
mk_FRAMESIZE   EQU     0
mk_STKGUARD    EQU     0
                FGX2_EXPORT psum
psum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #psum_FRAMESIZE
                DO      psum_STKGUARD
                BCC     psum_stkovf
                CMP     _fcc_stkfloor
                BCS     psum_stkok
psum_stkovf       JMP     _fcc_stkoflow
                FIN
psum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+psum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+psum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+psum_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+psum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+psum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+psum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #psum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
psum_FRAMESIZE   EQU     0
psum_STKGUARD    EQU     0
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
                LDA     #4
                PHA
                LDA     #3
                PHA
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mk
                TSC
                CLC
                ADC     #8
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #3
                BNE     _p33_localagg_L1
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #4
                BEQ     _p33_localagg_L0
_p33_localagg_L1
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
_p33_localagg_L0
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL psum
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                CMP     #7
                BEQ     _p33_localagg_L2
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
_p33_localagg_L2
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_img0
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_img1
_p33_localagg_L3
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                TAX
                SEC
                SBC     #3
                BVC     _p33_localagg_L6
                EOR     #$8000
_p33_localagg_L6
                BPL     _p33_localagg_L5
                LDA     #0
                STA     _fcc_img0
_p33_localagg_L7
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #2
                BVC     _p33_localagg_L10
                EOR     #$8000
_p33_localagg_L10
                BPL     _p33_localagg_L9
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     _fcc_img1
                ASL
                ASL
                PHA
                LDA     _fcc_img0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_img0
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
                STA     [_fcc_ptr]
                PLA
_p33_localagg_L8
                INC     _fcc_img0
                BRA     _p33_localagg_L7
_p33_localagg_L9
_p33_localagg_L4
                INC     _fcc_img1
                BRA     _p33_localagg_L3
_p33_localagg_L5
                LDA     _fcc_img0
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_img1
                STA     5,S   ; fccstk d=0 b=5
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     #0
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                BEQ     _p33_localagg_L11
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
_p33_localagg_L11
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     #2
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                CMP     #21
                BEQ     _p33_localagg_L12
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
_p33_localagg_L12
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                CMP     #10
                BEQ     _p33_localagg_L13
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
_p33_localagg_L13
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
main_FRAMESIZE   EQU     20
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
