; M7: JMP (abs,X), JSR (abs,X), JML — vector-table dispatch shapes.
                MX      %00
                JMP     ($1234,X)
                JSR     ($5678,X)
                JML     $E10000
                RTS
