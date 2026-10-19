; M6: LDA (dp),Y — post-indexed-Y indirect.  Core fcc deref shape.
                MX      %00
                LDA     ($10),Y
                STA     ($20),Y
                ADC     ($30),Y
                CMP     ($40),Y
                AND     ($50),Y
                ORA     ($60),Y
                EOR     ($70),Y
                SBC     ($80),Y
                RTS
