                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from macdecl_paren.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT add7
add7            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add7_FRAMESIZE
                DO      add7_STKGUARD
                BCC     add7_stkovf
                CMP     _fcc_stkfloor
                BCS     add7_stkok
add7_stkovf       JMP     _fcc_stkoflow
                FIN
add7_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                TAX
                DO      6+add7_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add7_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add7_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #add7_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add7_FRAMESIZE   EQU     0
add7_STKGUARD    EQU     0
                FGX2_EXPORT noop
noop            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #noop_FRAMESIZE
                DO      noop_STKGUARD
                BCC     noop_stkovf
                CMP     _fcc_stkfloor
                BCS     noop_stkok
noop_stkovf       JMP     _fcc_stkoflow
                FIN
noop_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                TAY
                TSC
                CLC
                ADC     #noop_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
noop_FRAMESIZE   EQU     0
noop_STKGUARD    EQU     0
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
                FGX2_FARCALL noop
                LDA     #35
                PHA
                FGX2_FARCALL add7
                PLY
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
                FGX2_RELOC_COUNT 6
