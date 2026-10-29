                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from deref_postfix.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT probe
probe            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #probe_FRAMESIZE
                DO      probe_STKGUARD
                BCC     probe_stkovf
                CMP     _fcc_stkfloor
                BCS     probe_stkok
probe_stkovf       JMP     _fcc_stkoflow
                FIN
probe_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+probe_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+probe_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #65
                BEQ     _deref_postfix_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #probe_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_deref_postfix_L0
                DO      8+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+probe_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+probe_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #66
                BEQ     _deref_postfix_L1
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #probe_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_deref_postfix_L1
                DO      8+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+probe_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+probe_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_ptr+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #66
                BEQ     _deref_postfix_L2
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #probe_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_deref_postfix_L2
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #probe_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
probe_FRAMESIZE   EQU     6
probe_STKGUARD    EQU     0
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
                LDA     #tab
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     g0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     g0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #tab
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     g1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     g1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL probe
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
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
                FGX2_RELOC_COUNT 4
