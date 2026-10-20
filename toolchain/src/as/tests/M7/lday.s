; M7: abs,Y indexed form for LDA-family.  dp,Y exists only for
; LDX/STX (no dp,Y for LDA); LDA $10,Y must fall through to
; AM_ABS_Y.
                MX      %00
                LDA     $1234,Y
                STA     $5678,Y
                ADC     $0010,Y
                CMP     $0020,Y
                AND     $0030,Y
                ORA     $0040,Y
                EOR     $0050,Y
                SBC     $0060,Y
                RTS
