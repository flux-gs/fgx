; M1: left-to-right expression eval, no precedence.
; (1 + 2) * 3 = 9 in Merlin's left-to-right, NOT 7.
                DFB     1+2*3
                DFB     10-3-2
