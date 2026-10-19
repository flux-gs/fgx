; M2: arithmetic chain — exercises ADC/SBC/CMP/AND/ORA/EOR in mixed modes.
                MX      %00
                CLC
                ADC     #$0001
                SEC
                SBC     $42
                CMP     #$1234
                AND     5,S
                ORA     $1000
                EOR     #$00FF
