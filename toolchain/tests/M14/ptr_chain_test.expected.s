                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_chain_test.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT poke_ints
poke_ints            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #poke_ints_FRAMESIZE
                DO      poke_ints_STKGUARD
                BCC     poke_ints_stkovf
                CMP     _fcc_stkfloor
                BCS     poke_ints_stkok
poke_ints_stkovf       JMP     _fcc_stkoflow
                FIN
poke_ints_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      14+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+poke_ints_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                DO      8+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      16+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+poke_ints_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                DO      8+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      18+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+poke_ints_FRAMESIZE,S   ; fccstk d=4 b=14 fs
                FIN
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                DO      8+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #3
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      20+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+poke_ints_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                DO      8+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #4
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      22+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+poke_ints_FRAMESIZE,S   ; fccstk d=4 b=18 fs
                FIN
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                DO      8+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+poke_ints_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #5
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      24+poke_ints_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+poke_ints_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+poke_ints_FRAMESIZE,S   ; fccstk d=4 b=20 fs
                FIN
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                TAY
                TSC
                CLC
                ADC     #poke_ints_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
poke_ints_FRAMESIZE   EQU     0
poke_ints_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #3
                PHA
                LDA     #7
                PHA
                LDA     #2
                PHA
                LDA     #21
                PHA
                LDA     #1
                PHA
                LDA     #14
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_bag
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL poke_ints
                TSC
                CLC
                ADC     #16
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_bag
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
