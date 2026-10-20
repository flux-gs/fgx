; M7: LDAL/STAL/etc. long-absolute family (3-byte operand).  With
; ,X indexing → AM_ABS24_X (BF/9F/etc.).
                MX      %00
                LDAL    $E0C029
                STAL    $E0C029
                LDAL    $E0C034,X
                STAL    $E0C035,X
                ADCL    $123456
                CMPL    $123456,X
                ANDL    $0B0000
                ORAL    $0B0000,X
                EORL    $0B0000
                SBCL    $0B0000,X
                RTS
