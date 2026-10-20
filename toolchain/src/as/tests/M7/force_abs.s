; M7: force-abs colon — `LDA: $10` keeps 2-byte abs form even when
; the operand fits in 1 byte (dp form normally selected).
                MX      %00
                LDA     $10
                LDA:    $10
                LDA:    $10,X
                STA:    $20,Y
                ADC:    $30
                RTS
