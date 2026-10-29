                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from getfsstat_room.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                TSC
                SEC
                SBC     #main_FRAMESIZE-2
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
                STA     _fcc_img16
_getfsstat_room_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #300
                BVC     _getfsstat_room_L3
                EOR     #$8000
_getfsstat_room_L3
                BPL     _getfsstat_room_L2
                LDA     #gbuf
                PHA
                LDA     _fcc_img16
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #170
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
_getfsstat_room_L1
                INC     _fcc_img16
                BRA     _getfsstat_room_L0
_getfsstat_room_L2
                LDA     #0
                PHA
                LDA     #100
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbuf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getfsstat
                PLY
                PLY
                PLY
                PLY
                STA     3,S   ; fccstk d=0 b=3
                LDA     #100
                STA     _fcc_img16
_getfsstat_room_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                SEC
                SBC     #300
                BVC     _getfsstat_room_L7
                EOR     #$8000
_getfsstat_room_L7
                BPL     _getfsstat_room_L6
                LDA     _fcc_img16
                TAX
                LDA:    gbuf,X
                AND     #$00FF
                PHA
                LDA     #170
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _getfsstat_room_L8
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRA     main_bandx
_getfsstat_room_L8
_getfsstat_room_L5
                INC     _fcc_img16
                BRA     _getfsstat_room_L4
_getfsstat_room_L6
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #1
                BNE     _getfsstat_room_L9
                LDA     #42
                BRA     _getfsstat_room_L10
_getfsstat_room_L9
                LDA     #2
_getfsstat_room_L10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
main_bandx
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 3
