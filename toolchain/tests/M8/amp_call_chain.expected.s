                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from amp_call_chain.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT pick
pick            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pick_FRAMESIZE
                DO      pick_STKGUARD
                BCC     pick_stkovf
                CMP     _fcc_stkfloor
                BCS     pick_stkok
pick_stkovf       JMP     _fcc_stkoflow
                FIN
pick_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+pick_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     slot+0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #slot
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pick_FRAMESIZE   EQU     0
pick_STKGUARD    EQU     0
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
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #table
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #4
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #3
                PHA
                FGX2_FARCALL pick
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_ptr
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                CMP     #3
                BNE     _amp_call_chain_L0
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #10
                STA     9,S   ; fccstk d=0 b=9
_amp_call_chain_L0
                LDA     #15
                STA     [_fcc_fpr0]
                LDA     slot+0
                TAX
                CMP     #15
                BNE     _amp_call_chain_L1
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #10
                STA     9,S   ; fccstk d=0 b=9
_amp_call_chain_L1
                LDA     #1
                PHA
                FGX2_FARCALL pick
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #6
                STA     [_fcc_img16]
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #12
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     slot+2
                CMP     #6
                BNE     _amp_call_chain_L2
                LDA     slot+4
                CMP     #12
                BNE     _amp_call_chain_L2
                LDA     9,S   ; fccstk d=0 b=9
                CLC
                ADC     #18
                STA     9,S   ; fccstk d=0 b=9
_amp_call_chain_L2
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                LDA     #0
                ASL
                TAX
                LDA:    table,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
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
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 5
