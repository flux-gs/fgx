                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bitfield_access.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _bitfield_access_ok
_bitfield_access_ok            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_bitfield_access_ok_FRAMESIZE
                DO      _bitfield_access_ok_STKGUARD
                BCC     _bitfield_access_ok_stkovf
                CMP     _fcc_stkfloor
                BCS     _bitfield_access_ok_stkok
_bitfield_access_ok_stkovf       JMP     _fcc_stkoflow
                FIN
_bitfield_access_ok_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_bitfield_access_ok_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_bitfield_access_ok_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_bitfield_access_ok_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_bitfield_access_ok_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_bitfield_access_ok_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_bitfield_access_ok_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$0007
                TAX
                CMP     #1
                BNE     _bitfield_access_L0
                LDA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                AND     #$00FF
                TAX
                CMP     #2
                BNE     _bitfield_access_L0
                LDA     #1
                BRA     _bitfield_access_L1
_bitfield_access_L0
                LDA     #0
_bitfield_access_L1
                TAY
                TSC
                CLC
                ADC     #_bitfield_access_ok_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bitfield_access_ok_FRAMESIZE   EQU     0
_bitfield_access_ok_STKGUARD    EQU     0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     hp
                LDA     _fcc_fpr0+2
                STA     hp+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     ghh+2
                TAY
                LDA     _fcc_ptr+2
                STA     ghh+4
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ghh
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     hhp
                LDA     _fcc_fpr0+2
                STA     hhp+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh+2
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #1
                STA     11,S   ; fccstk d=0 b=11
                LDA     gh+2
                AND     #$FFF8
                STA     gh+2
                LDA     #1
                AND     #$0007
                ORA     gh+2
                STA     gh+2
                AND     #$00FF
                STA     gh+2
                LDA     #2
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ORA     gh+2
                STA     gh+2
                LDA     #1
                AND     #$0007
                STA     _fcc_tmp_b
                LDA     gh+6
                AND     #$FFF8
                ORA     _fcc_tmp_b
                STA     gh+6
                AND     #$0007
                LDA     #2
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                LDA     gh+6
                AND     #$00FF
                ORA     _fcc_tmp_b
                STA     gh+6
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                AND     #$00FF
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
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #1
                AND     #$0007
                STA     _fcc_tmp_b
                LDA     [_fcc_fpr0]
                AND     #$FFF8
                ORA     _fcc_tmp_b
                STA     [_fcc_fpr0]
                AND     #$0007
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
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #2
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                LDA     [_fcc_fpr0]
                AND     #$00FF
                ORA     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                AND     #$00FF
                LDA     gh+2
                AND     #$FF07
                STA     gh+2
                LDA     #3
                AND     #$001F
                ASL
                ASL
                ASL
                ORA     gh+2
                STA     gh+2
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #3
                BNE     _bitfield_access_L3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _bitfield_access_ok
                PLY
                PLY
                CMP     #0
                BNE     _bitfield_access_L2
_bitfield_access_L3
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_bitfield_access_L2
                LDA     #4
                AND     #$001F
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                LDA     [_fcc_img16]
                AND     #$FF07
                ORA     _fcc_tmp_b
                STA     [_fcc_img16]
                LSR
                LSR
                LSR
                AND     #$001F
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #4
                BNE     _bitfield_access_L5
                LDA     gh+2
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #4
                BNE     _bitfield_access_L5
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _bitfield_access_ok
                PLY
                PLY
                CMP     #0
                BNE     _bitfield_access_L4
_bitfield_access_L5
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_bitfield_access_L4
                SEP     #$20
                MX      %10
                LDA     hp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hp
                INC
                INC
                STA     _fcc_fpr0
                LDA     #9
                AND     #$001F
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                LDA     [_fcc_fpr0]
                AND     #$FF07
                ORA     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                SEP     #$20
                MX      %10
                LDA     hp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hp
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #9
                BNE     _bitfield_access_L7
                LDA     gh+2
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #9
                BNE     _bitfield_access_L7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _bitfield_access_ok
                PLY
                PLY
                CMP     #0
                BNE     _bitfield_access_L6
_bitfield_access_L7
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_bitfield_access_L6
                SEP     #$20
                MX      %10
                LDA     hhp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hhp
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                INC
                INC
                STA     _fcc_fpr0
                LDA     #5
                AND     #$001F
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                LDA     [_fcc_fpr0]
                AND     #$FF07
                ORA     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                SEP     #$20
                MX      %10
                LDA     hhp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hhp
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #5
                BNE     _bitfield_access_L9
                LDA     gh+2
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #5
                BNE     _bitfield_access_L9
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _bitfield_access_ok
                PLY
                PLY
                CMP     #0
                BNE     _bitfield_access_L8
_bitfield_access_L9
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_bitfield_access_L8
                SEP     #$20
                MX      %10
                LDA     hp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hp
                INC
                INC
                STA     _fcc_fpr0
                LDA     #6
                AND     #$001F
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                LDA     [_fcc_fpr0]
                AND     #$FF07
                ORA     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                SEP     #$20
                MX      %10
                LDA     hp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hp
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #6
                BNE     _bitfield_access_L11
                LDA     gh+2
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #6
                BNE     _bitfield_access_L11
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _bitfield_access_ok
                PLY
                PLY
                CMP     #0
                BNE     _bitfield_access_L10
_bitfield_access_L11
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_bitfield_access_L10
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
                LDA     11,S   ; fccstk d=0 b=11
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #7
                AND     #$001F
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                LDA     [_fcc_fpr0]
                AND     #$FF07
                ORA     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
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
                LDA     11,S   ; fccstk d=0 b=11
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #7
                BNE     _bitfield_access_L13
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
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #7
                BNE     _bitfield_access_L13
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _bitfield_access_ok
                PLY
                PLY
                CMP     #0
                BNE     _bitfield_access_L12
_bitfield_access_L13
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_bitfield_access_L12
                SEP     #$20
                MX      %10
                LDA     hp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hp
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     11,S   ; fccstk d=0 b=11
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #8
                AND     #$001F
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                LDA     [_fcc_fpr0]
                AND     #$FF07
                ORA     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                SEP     #$20
                MX      %10
                LDA     hp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     hp
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     11,S   ; fccstk d=0 b=11
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #8
                BNE     _bitfield_access_L15
                LDA     gh+6
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #8
                BNE     _bitfield_access_L15
                LDA     #1
                ASL
                CLC
                ADC     #gh+4
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
                FGX2_FARCALL _bitfield_access_ok
                PLY
                PLY
                CMP     #0
                BNE     _bitfield_access_L14
_bitfield_access_L15
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_bitfield_access_L14
                LDA     #31
                CLC
                ADC     #32
                STA     _fcc_tmp_b
                LDA     gh+2
                AND     #$FF07
                STA     gh+2
                LDA     _fcc_tmp_b
                AND     #$001F
                ASL
                ASL
                ASL
                ORA     gh+2
                STA     gh+2
                LSR
                LSR
                LSR
                AND     #$001F
                TAX
                CMP     #31
                BNE     _bitfield_access_L17
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _bitfield_access_ok
                PLY
                PLY
                CMP     #0
                BNE     _bitfield_access_L16
_bitfield_access_L17
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_bitfield_access_L16
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
main_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     16
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 11
