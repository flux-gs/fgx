; M7: abs,X and dp,X indexed forms for LDA-family.  dp/abs
; auto-select shrinks values < $100 to the 2-byte dp,X opcode.
                MX      %00
                LDA     $10,X
                LDA     $1234,X
                STA     $20,X
                STA     $5678,X
                ADC     $30,X
                CMP     $40,X
                AND     $50,X
                ORA     $60,X
                EOR     $70,X
                SBC     $80,X
                RTS
