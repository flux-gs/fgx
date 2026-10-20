; M5: BRK (1-byte) + RTI.  Merlin32 v1.1.10 rejects `COP #$nn`; fas
; follows suit and does not accept COP as a mnemonic.
                MX      %00
                BRK
                RTI
                NOP
