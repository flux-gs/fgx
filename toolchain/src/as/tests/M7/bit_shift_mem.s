; M7: BIT / ASL / LSR / ROL / ROR / INC / DEC / TRB / TSB — memory forms.
                MX      %00
                BIT     #$0042
                BIT     $10
                BIT     $1234
                BIT     $20,X
                BIT     $1234,X
                ASL     $10
                ASL     $1234
                ASL     $20,X
                ASL     $1234,X
                LSR     $10
                LSR     $1234
                ROL     $10
                ROL     $1234,X
                ROR     $10
                INC     $10
                INC     $1234
                INC     $20,X
                INC     $1234,X
                DEC     $10
                DEC     $1234
                TRB     $10
                TRB     $1234
                TSB     $10
                TSB     $1234
                RTS
