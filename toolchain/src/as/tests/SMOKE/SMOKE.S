; SMOKE.S — fas multi-bank framework smoke test.
; Exercises: MX/ORG/EQU/DFB/DA/DS/HEX/ASC, <>^ byte extracts,
; label-arith operands, @local in 3 scopes, immediate / abs /
; DBR-rel / abs24 addressing, JSR/JSL/RTS/BCC backward/BRA self.
; (PUT inclusion is its own follow-up — works through fgetc-loop
; c_fread but the malloc'd g_src_path long-ptr chain hits a deeper
; multi-bank bug — see libc-shim-longptr-audit memory note.)
; Output: "fas smoke ok"+CR twice, exit 0.

                MX      %11
                ORG     $0B0000

SYS_EXIT        EQU     1
SYS_WRITE       EQU     4
SYS_TRAMP       EQU     $000328
STDOUT          EQU     1
TWO             EQU     2

; FGX1 header — <, >, ^ byte-extract on long literal; label-arith DA.
hdr             ASC     'FGX1'
                DFB     <$0B0000
                DFB     >$0B0000
                DFB     ^$0B0000
                DFB     $00
                DA      entry-$0B0000
                DA      end-text
                DA      0
                DFB     $00
                DFB     $00

text            EQU     *

; Entry — REP, immediate-mode loads, INX, CPX #imm, BCC backward,
; PHX/PLX, same-bank JSR + RTS, JSL abs24 + DFB syscall, BRA.
entry           MX      %00
                REP     #$30
                LDX     #0
@loop           PHX
                JSR     write_msg
                PLX
                INX
                CPX     #TWO
                BCC     @loop
                LDA     #0
                JSL     SYS_TRAMP
                DFB     SYS_EXIT
@safety         BRA     @safety

; write_msg — operand expression msg_end-msg, JSL syscall.
write_msg       MX      %00
                LDA     #STDOUT
                LDX     #msg
                LDY     #msg_end-msg
                JSL     SYS_TRAMP
                DFB     SYS_WRITE
                RTS

; Separate global label → fresh @local scope.  STA: / LDA: force abs.
mark_one        MX      %00
                LDA     #$0001
                STA:    mark_slot
@retry          LDA:    mark_slot
                BEQ     @retry
                RTS

mark_slot       DA      0
scratch         DS      4
pattern         HEX     DE,AD,BE,EF

; Pull message data + nop_helper in from SMOKEI via PUT (chasing the
; malloc'd-long-ptr-global corruption bug).
                PUT     SMOKEI

end             EQU     *
