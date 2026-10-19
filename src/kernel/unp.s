;==============================================================================
; unp.s - WHAT THE AF_UNIX SOCK_DGRAM TRANSPORT LEAVES IN THE CORE BANK.
;
; The implementation is src/modules/net/unp.s.  This file is the statics half,
; and it exists because _Net_Dispatch clobbers A on the way into a net op, so
; nothing may travel in a register; core-bank statics are also not module-local
; data, so reading them DBR-relative from the module is the pattern
; check_module_data_refs is built around rather than the one it rejects.
;
; There are no dispatch stubs here.  The AF_UNIX arms hang off the EXISTING
; net_op_send/recv/connect handlers as `try' calls, the way loopback's do since
; it moved into net.mod, so no new NETOP slot and no bank-0 jump table entry is
; spent.
;
; THESE ARE ONE CONTIGUOUS BLOCK AND A BLOCKING RECV SAVES THE WHOLE THING on the
; task's kernel stack, which is the discipline _Pipe_PollIntr already applies to
; the _pipe* scratch for the same reason: they are GLOBALS, so while this task
; sleeps another task's socket call runs _Unp_Claim, which zeroes _unpHandled and
; rewrites the rest.  Without the save, a resumed recv returns to a net_op_recv
; that reads _unpHandled as 0 and falls through to loopback and then the W5100 --
; with a datagram already taken off the ring.
;
; _unpBlkEnd IS THE LENGTH'S ANCHOR, not the last live cell.  _PIPE_SCRATCH_LEN's
; header records what happens otherwise: a cell added after the anchor leaves the
; length untouched, so the save loop keeps copying the old byte count and the new
; cell is silently outside it.  A cell added anywhere ABOVE this marker is covered
; by construction.
;
; The caller's BANK is deliberately NOT here.  _Sys_CallerBank is saved and
; restored per task by the scheduler (SE_CallerBank, src/kernel/sched.s) exactly
; so a blocked syscall's caller bank survives an intervening task's syscall, so
; it is already stronger than a copy in a plain global would be.  _Sys_SavedA has
; no such slot and the dispatcher rewrites it, which is why _unpArgBlk does exist.
;==============================================================================

;------------------------------------------------------------------------------
_unpHandled     DS      2               ; 1 = this call was serviced by AF_UNIX
_unpArgBlk      DS      2               ; the caller's arg-block offset
_unpDescOff     DS      2               ; this descriptor's record offset
_unpPeerOff     DS      2               ; peer descriptor's record offset
_unpRingOff     DS      2               ; pipe record offset of the target ring
_unpPayLen      DS      2               ; payload bytes for this datagram
_unpNeed        DS      2               ; UNP_HDR_LEN + _unpPayLen, the whole
                                        ; record.  The space test is against
                                        ; THIS and not the payload: a header that
                                        ; fits where its payload does not is a
                                        ; truncated record, and every boundary
                                        ; after it is lost.
_unpGot         DS      2               ; bytes delivered to the caller's buffer
_unpHdr         DS      4               ; header staging: len(2) + namelen(1),
                                        ; +1 pad to keep the block even.  The
                                        ; NAME is not staged here: a SENDER's
                                        ; name is scoped out, so namelen is 0 and
                                        ; a record carries three bytes of header.
_unpUio         DS      2               ; the caller's uio (from _sockUio) and the
_unpUioBank     DS      2               ;   source-address offset (_sockSrcOff),
_unpFrom        DS      2               ;   copied in at entry: the receive wait
                                        ;   sleeps in _Pipe_PollIntr, which does
                                        ;   not save the _sock block
_unpBlkEnd      DS      2               ; the save length's anchor; see above

; THE NAME SEAM'S TWO CELLS, deliberately OUTSIDE the saved block.  _unpSlot is
; an OUT parameter for a lookup -- the far bank writes the descriptor slot it
; found -- so restoring it from a save would throw the answer away.  The bind and
; connect arms therefore preserve the two cells they actually need across the far
; call (_unpHandled and _unpDescOff) by pushing them, and read _unpSlot before
; anything else can run.
_unpNameOp      DS      2               ; UNP_OP_BIND / UNP_OP_LOOKUP
_unpSlot        DS      2               ; descriptor slot: in for bind, out for
                                        ; lookup.  Stored on the vnode as slot+1
                                        ; so that zero means "no socket here",
                                        ; which a bare index cannot -- descriptor
                                        ; 0 is a live descriptor, and a VSOCK node
                                        ; outliving its socket is the ordinary
                                        ; case after a restart.
