                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from void_for_clause.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT vbefore
vbefore            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vbefore_FRAMESIZE
                DO      vbefore_STKGUARD
                BCC     vbefore_stkovf
                CMP     _fcc_stkfloor
                BCS     vbefore_stkok
vbefore_stkovf       JMP     _fcc_stkoflow
                FIN
vbefore_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     gtrace
                TAX
                INC
                STA     gtrace
                TAY
                TSC
                CLC
                ADC     #vbefore_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vbefore_FRAMESIZE   EQU     0
vbefore_STKGUARD    EQU     0
                FGX2_EXPORT vafter
vafter            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vafter_FRAMESIZE
                DO      vafter_STKGUARD
                BCC     vafter_stkovf
                CMP     _fcc_stkfloor
                BCS     vafter_stkok
vafter_stkovf       JMP     _fcc_stkoflow
                FIN
vafter_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     gtrace
                TAX
                CLC
                ADC     #10
                STA     gtrace
                TAY
                TSC
                CLC
                ADC     #vafter_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vafter_FRAMESIZE   EQU     0
vafter_STKGUARD    EQU     0
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
                STA     gtrace
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                FGX2_FARCALL vbefore
                LDA     #1
                STA     bavar
_void_for_clause_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     bavar
                BEQ     _void_for_clause_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
_void_for_clause_L1
                FGX2_FARCALL vafter
                LDA     #0
                STA     bavar
                BRA     _void_for_clause_L0
_void_for_clause_L2
                LDA     gtrace
                TAX
                CMP     #11
                BEQ     _void_for_clause_L3
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
_void_for_clause_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #1
                BEQ     _void_for_clause_L4
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
_void_for_clause_L4
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
                FGX2_RELOC_COUNT 6
