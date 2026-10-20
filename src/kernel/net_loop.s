;==============================================================================
; net_loop.s - WHAT THE 127.0.0.1 LOOPBACK TRANSPORT LEAVES IN THE CORE BANK.
;
; The implementation is src/modules/net/net_loop.s (moved into net.mod
; 2026-08-11, together with pipe.s -- it calls four _Pipe_* routines, so the
; two had to move as a pair or the crossings would just change direction).
;
; The statics stay because syscall.s, fs.s and net_dispatch.s write them
; directly, and because they are how arguments reach the moved bodies:
; _Net_Dispatch clobbers A, so nothing may travel in a register.
;==============================================================================

;------------------------------------------------------------------------------
_loopHandled    DS      2               ; 1 = this call was serviced by loopback
_loopDstPort    DS      2               ; connect() destination port, host order
_loopConnOff    DS      2               ; connecting descriptor record offset
_loopLisOff     DS      2               ; matched listener descriptor offset
_loopAccOff     DS      2               ; accepted-end descriptor offset
_loopScratch    DS      2               ; _Loop_StatusTry: the ring's PIPE_Count,
                                        ; held to compare against PIPE_BufSz
_loopIsRecv     DS      2               ; 0 = send (Tx ring), 1 = recv (Rx)
_loopMsgNb      DS      2               ; 1 = this CALL passed MSG_DONTWAIT.
                                        ; Separate from SOCK_NB because they are
                                        ; separate questions -- per-call against
                                        ; per-descriptor.  _Loop_SoIo sets it from
                                        ; the call's MSG_DONTWAIT; read and write
                                        ; carry no MSG_* flags.
_loopBits       DS      2               ; _Loop_StatusTry readiness accumulator
_loopRxLen      DS      2               ; _Loop_StatusTry resident Rx byte count,
                                        ;   which is FIONREAD's answer for a
                                        ;   loopback fd -- there is no W5100
                                        ;   RX_RSR to ask (apple/fgx#98)
_loopRingA      DS      2               ; pipe idx, A->B direction; $FF = none
_loopRingB      DS      2               ; pipe idx, B->A direction; $FF = none

;==============================================================================
; DISPATCH STUBS.  The bodies are in src/modules/net/net_loop.s; these are the
; names the core bank links against.
;
; They cross on the EXISTING _NetThunkExec, which is why this migration needed
; no new patch machinery at all: the thunk already resolves net.mod's op table
; and already answers ENOSYS when the module is absent.  A tail JMP rather than
; JSR/RTS -- the thunk's RTS (and the ENOSYS arm's) returns straight to our
; caller.
;
; ARGUMENTS DO NOT TRAVEL IN REGISTERS.  _Net_Dispatch clobbers A on the way
; in, and THE THUNK ITSELF USES Y as the op selector -- so a caller that passes
; something in Y is just as broken as one that passes it in A, and that is far
; easier to miss.  _Loop_CloseTry is the one such site (fs.s does TAY with the
; socket index immediately before the call); it stages through
; _loopThunkSock below.  Every other entry already passed its arguments in the
; statics above.
;
; Getting this wrong does not crash: close() silently operates on the WRONG
; socket, the peer is never marked closed, and the reader waits forever for an
; EOF that never comes -- a round-trip that works followed by a hang.
;==============================================================================
_loopThunkSock  DS      2               ; Y = socket index, staged across the thunk

; The ops net_dispatch.s used to try loopback-first (bind, connect, listen,
; accept, send, recv, read, write) have NO stub here any more: that decision
; lives in net.mod's own NETOP handlers, and a socket's data goes through
; sosend/soreceive there, which pick the transport.
_Loop_StatusTry ENT
                MX      %00
                LDY     #NETOP_LoopStatus
                JMP     _NetThunkExec
_Loop_CloseTry  ENT
                MX      %00
                STY     _loopThunkSock          ; Y IS THE ARGUMENT -- see above
                LDY     #NETOP_LoopClose
                JMP     _NetThunkExec
