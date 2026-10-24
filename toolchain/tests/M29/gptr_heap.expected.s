                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from gptr_heap.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT store
store            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #store_FRAMESIZE
                DO      store_STKGUARD
                BCC     store_stkovf
                CMP     _fcc_stkfloor
                BCS     store_stkok
store_stkovf       JMP     _fcc_stkoflow
                FIN
store_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     dol+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     dol
                INC
                INC
                STA     _fcc_fpr0
                STA     dol
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                SEP     #$20
                MX      %10
                LDA     dot+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     dot
                CLC
                ADC     #2
                STA     _fcc_fpr0
                STA     dot
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
_gptr_heap_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     _fcc_img5
                STA     _fcc_fpr1+2
                LDA     _fcc_img4
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                PHA
                LDA     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_gtu16
                CMP     #0
                BEQ     _gptr_heap_L1
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                DEC
                DEC
                STA     _fcc_img2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                SEC
                SBC     #2
                STA     _fcc_img0
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr1]
                STA     [_fcc_fpr0]
                BRA     _gptr_heap_L0
_gptr_heap_L1
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                DO      6+store_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+store_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+store_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     [_fcc_fpr0]
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #store_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
store_FRAMESIZE   EQU     12
store_STKGUARD    EQU     0
                FGX2_EXPORT parse
parse            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #parse_FRAMESIZE
                DO      parse_STKGUARD
                BCC     parse_stkovf
                CMP     _fcc_stkfloor
                BCS     parse_stkok
parse_stkovf       JMP     _fcc_stkoflow
                FIN
parse_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     zero+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     zero
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                DO      6+parse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+parse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+parse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     zero+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     zero
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                PHA
                LDA     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_ltu16
                CMP     #0
                BNE     _gptr_heap_L3
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     dol+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     dol
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                PHA
                LDA     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_gtu16
                CMP     #0
                BEQ     _gptr_heap_L2
_gptr_heap_L3
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #parse_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_gptr_heap_L2
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #parse_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
parse_FRAMESIZE   EQU     4
parse_STKGUARD    EQU     0
                FGX2_EXPORT consume
consume            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #consume_FRAMESIZE
                DO      consume_STKGUARD
                BCC     consume_stkovf
                CMP     _fcc_stkfloor
                BCS     consume_stkok
consume_stkovf       JMP     _fcc_stkoflow
                FIN
consume_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+consume_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+consume_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+consume_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #consume_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
consume_FRAMESIZE   EQU     0
consume_STKGUARD    EQU     0
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
                LDA     #64
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL malloc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0
                STA     zero
                LDA     _fcc_fpr0+2
                STA     zero+2
                SEP     #$20
                MX      %10
                LDA     zero+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     zero
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _gptr_heap_L5
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _gptr_heap_L5
                LDA     #1
                BRA     _gptr_heap_L6
_gptr_heap_L5
                LDA     #0
_gptr_heap_L6
                CMP     #0
                BEQ     _gptr_heap_L4
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_gptr_heap_L4
                SEP     #$20
                MX      %10
                LDA     zero+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     zero
                STA     _fcc_fpr0
                STA     dol
                LDA     _fcc_fpr0+2
                STA     dol+2
                LDA     _fcc_fpr0
                STA     dot
                LDA     _fcc_fpr0+2
                STA     dot+2
                LDA     #2
                PHA
                FGX2_FARCALL store
                TAY
                PLA
                TYA
                LDA     #6
                PHA
                FGX2_FARCALL store
                TAY
                PLA
                TYA
                LDA     #10
                PHA
                FGX2_FARCALL store
                TAY
                PLA
                TYA
                LDA     #1
                PHA
                FGX2_FARCALL parse
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                STA     addr1
                LDA     _fcc_fpr0+2
                STA     addr1+2
                LDA     #3
                PHA
                FGX2_FARCALL parse
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                STA     addr2
                LDA     _fcc_fpr0+2
                STA     addr2+2
                SEP     #$20
                MX      %10
                LDA     addr1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     addr1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _gptr_heap_L9
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _gptr_heap_L9
                LDA     #1
                BRA     _gptr_heap_L10
_gptr_heap_L9
                LDA     #0
_gptr_heap_L10
                CMP     #0
                BNE     _gptr_heap_L8
                SEP     #$20
                MX      %10
                LDA     addr2+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     addr2
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _gptr_heap_L11
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _gptr_heap_L11
                LDA     #1
                BRA     _gptr_heap_L12
_gptr_heap_L11
                LDA     #0
_gptr_heap_L12
                CMP     #0
                BEQ     _gptr_heap_L7
_gptr_heap_L8
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_gptr_heap_L7
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                SEP     #$20
                MX      %10
                LDA     addr1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     addr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_gptr_heap_L13
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_ptr+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_tmp_b
                INC
                INC
                STA     3,S   ; fccstk d=2 b=1
                LDA     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                PHA
                FGX2_FARCALL consume
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
_gptr_heap_L14
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     addr2+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     addr2
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                PHA
                LDA     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_leu16
                CMP     #0
                BEQ     _gptr_heap_L15
                BRA     _gptr_heap_L13
_gptr_heap_L15
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #18
                BEQ     _gptr_heap_L16
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                AND     #255
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_gptr_heap_L16
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 12
