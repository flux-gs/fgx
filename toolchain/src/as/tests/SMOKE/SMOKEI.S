; SMOKEI.S - included by SMOKE.S via PUT.  Provides the message buffer
; + a never-called nop helper.  Forward refs (msg / msg_end) from
; SMOKE.S resolve in fas pass 2.

msg             ASC     'fas smoke ok'
                DFB     $0D
msg_end         EQU     *

nop_helper      MX      %00
@spin           NOP
                NOP
                RTS
