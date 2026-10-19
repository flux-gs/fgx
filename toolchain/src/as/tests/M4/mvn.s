; M4: MVN srcbank,dstbank — 3-byte block move.
; Assembler syntax MVN src,dst; machine wire order 54 dst src.
; Caller is responsible for X (src addr) / Y (dst addr) / A (count-1)
; setup; those use opcodes that land in later milestones, so this
; fixture isolates MVN's encoding only.
                MX      %00
                MVN     $02,$03
                RTS
