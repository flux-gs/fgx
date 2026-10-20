; M1: ORG sets PC; subsequent labels reflect the new PC.
                ORG     $0100
here            EQU     *
                DA      here
                DA      *
