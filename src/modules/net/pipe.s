;==============================================================================
; pipe.s - the pipe(2) rings.  MOVED INTO net.mod 2026-08-11 (was
; src/kernel/pipe.s), together with net_loop.s, which calls four routines here.
;
; WHAT STAYED IN THE CORE BANK, and why it matters more than it looks:
; _AllocPipeTable.  main.s calls it at boot, long before Mod_LoadConf -- the
; same rule that kept _Pty_Init behind.  It is ALSO the only caller of Kmalloc,
; Kern_LogStr, _Halt and _SoftGlob_ValidatePtr in this file, so leaving it
; behind removed four kernel callbacks outright.
;
; The scratch statics stayed too: syscall.s stages the caller's uio in
; _pipeUio/_pipeUioBank before the call, which is how arguments still arrive.
;
; _kfp110's `JSL KFAR_CON_POLLKEY` is GONE: that was a far-call patch site
; carried in the kernel's tracked far_patchsites.s, and a module cannot host
; one.  It goes through the bank-0 SYS_NETKC_CONPOLLKEY slot instead, which
; does the far call kernel-side.
;==============================================================================


; The cross-block scratch length.  In-kernel this was `EQU *-_pipeRecOff` over
; the statics; those stayed in the core bank, so it is DERIVED HERE from the
; exported addresses instead of hardcoded.
;
; ANCHORED TO THE FIRST TRANSIENT, NOT THE LAST SAVED CELL.  It used to read
; `_pipeBufBank+2-_pipeRecOff`, and claimed in this comment that adding a field
; to the block would move kernel_exports.s and "this follows".  It does not: a
; cell added AFTER _pipeBufBank leaves that expression untouched, so the save
; loop keeps copying the old byte count and the new cell is silently outside it.
; That is exactly what happened when _pipeNonBlk was moved into the block --
; the move assembled clean, changed no emitted bytes, and fixed nothing.
;
; _pipeChunk is the first cell of the transient region, so this length is "the
; whole block up to where the transients begin" and any cell added inside the
; block is covered by construction.  src/kernel/pipe.s ERR-guards that
; _pipeChunk really does sit at the boundary, which is what makes the two
; definitions of this symbol agree.
_PIPE_SCRATCH_LEN EQU   _pipeChunk-_pipeRecOff

_Pipe_Alloc     MX      %00
                LDY     #0                      ; record offset
                LDX     #0                      ; idx
@pa_scan        SEP     #$20
                MX      %10
                LDA     [_pipeTablePtr],Y       ; PIPE_InUse (Y = record base)
                BEQ     @pa_free
                REP     #$20
                MX      %00
                TYA
                CLC
                ADC     #PIPE_REC_SZ
                TAY
                INX
                CPX     #NPIPE
                BCC     @pa_scan
                REP     #$20                    ; no free slot
                MX      %00
                LDA     #ENFILE
                CLC
                RTS
@pa_free        REP     #$20
                MX      %00
                STY     _pipeRecOff             ; remember record offset
                STX     _pipeAllocIdx
                LDA     #PIPE_BUFSZ             ; allocate the ring
                LDX     #M_KERN
                JSR     _NlKC_Kmalloc
                BCS     @pa_kok
                LDA     #ENOMEM                ; ring OOM -> leave slot free
                CLC
                RTS
@pa_kok         ; init the record (slot stays at _pipeRecOff).
                LDY     _pipeRecOff
                SEP     #$20
                MX      %10
                LDA     #1                      ; PIPE_InUse = 1   (+0)
                STA     [_pipeTablePtr],Y
                INY                             ; PIPE_RdClosed = 0 (+1)
                LDA     #0
                STA     [_pipeTablePtr],Y
                INY                             ; PIPE_WrClosed = 0 (+2)
                STA     [_pipeTablePtr],Y
                INY                             ; PIPE_BufPtr (+3, 3 bytes) = ring
                LDA     _kmallocResult
                STA     [_pipeTablePtr],Y
                INY
                LDA     _kmallocResult+1
                STA     [_pipeTablePtr],Y
                INY
                LDA     _kmallocResult+2
                STA     [_pipeTablePtr],Y
                REP     #$20
                MX      %00
                ; Head/Tail/Count (+6/+8/+10, 16-bit) = 0
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_Head
                TAY
                LDA     #0
                STA     [_pipeTablePtr],Y       ; Head = 0
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_Tail
                TAY
                LDA     #0
                STA     [_pipeTablePtr],Y       ; Tail = 0
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_Count
                TAY
                LDA     #0
                STA     [_pipeTablePtr],Y       ; Count = 0
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_BufSz
                TAY
                LDA     #PIPE_BUFSZ
                STA     [_pipeTablePtr],Y       ; BufSz = initial 512 (Stage P:
                                                ; grows on demand to the max)
                LDY     _pipeRecOff
                SEC
                RTS

;==============================================================================
; _Pipe_FreeSlot - Kfree the ring + mark the descriptor free.
; In: _pipeRecOff = record offset.  MX %00.
;==============================================================================
_Pipe_FreeSlot  MX      %00
                ; load ring ptr (PIPE_BufPtr) -> _kmallocResult, then Kfree
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_BufPtr
                TAY
                LDA     [_pipeTablePtr],Y
                STA     _kmallocResult
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     [_pipeTablePtr],Y
                STA     _kmallocResult+2
                REP     #$20
                MX      %00
                JSR     _NlKC_Kfree
                ; InUse = 0, BufPtr = 0 (3 bytes) so a stale ptr can't double-free
                LDY     _pipeRecOff
                SEP     #$20
                MX      %10
                LDA     #0
                STA     [_pipeTablePtr],Y       ; InUse (+0)
                ; INY AND NOT `LDA _pipeRecOff / ADC #PIPE_BufPtr / TAY', which
                ; is the form the entry block above uses.  That form needs A
                ; SIXTEEN BITS WIDE and A is eight here: the load would take the
                ; low byte of the offset while TAY transferred the full 16-bit C,
                ; so Y's high byte would be whatever B was left holding -- the
                ; ring offset _NlKC_Kfree just returned in A -- and these three
                ; stores would land (B<<8) bytes past the pipe table, in the
                ; middle of the kernel heap.
                ;
                ; Y already holds _pipeRecOff from the LDY above and the index
                ; registers are 16-bit, so three INYs are the same addition with
                ; no accumulator involved.  The ERR pins the count to the
                ; constant rather than leaving 3 spelled twice.
                ERR     PIPE_BufPtr-3
                INY
                INY
                INY
                LDA     #0
                STA     [_pipeTablePtr],Y
                INY
                STA     [_pipeTablePtr],Y
                INY
                STA     [_pipeTablePtr],Y
                REP     #$20
                MX      %00
                RTS

;==============================================================================
; _Sys_Pipe - SYS_PIPE (#88): pipe(int fd[2]).
; Entry: _Sys_SavedX = caller-bank offset of int fd[2]; _Sys_CallerBank = bank.
; MX %00.  Writes fd[0] = read end, fd[1] = write end.  Returns A=0 + C=1, or
; A=errno + C=0 (ENFILE/ENOMEM no pipe, EMFILE no fd).  Unwinds partial allocs.
;==============================================================================
_Sys_Pipe       MX      %00
                LDA     _Sys_SavedX             ; user &fd[2] offset
                STA     _pipeUserFdOff
                JSR     _Pipe_Alloc             ; C=1 + Y=recOff + _pipeAllocIdx / C=0
                BCS     @sp_haveSlot
                CLC
                RTS                             ; A = ENFILE / ENOMEM
@sp_haveSlot    STY     _pipeRecOff
                ; --- read-end FCB ---
                REP     #$30
                MX      %00
                JSR     _NlKC_FcbAlloc              ; C=1 + A=fd (M=1!), _fcbPtr set / C=0
                BCS     @sp_rdOk
                BRL     @sp_rdFail              ; (long branch — BCC out of range)
@sp_rdOk        STA     _pipeRdFd               ; (M=1: low byte)
                LDY     #FCB_Flags
                LDA     #FCB_FL_PIPE
                STA     [_fcbPtr],Y
                LDY     #FCB_FstIdx
                LDA     #0
                STA     [_fcbPtr],Y
                LDY     #FCB_PipeIdx
                LDA     _pipeAllocIdx           ; pipe idx (low byte)
                STA     [_fcbPtr],Y
                ; --- write-end FCB ---
                REP     #$30
                MX      %00
                JSR     _NlKC_FcbAlloc
                BCS     @sp_wrOk
                BRL     @sp_wrFail              ; (long branch — BCC out of range)
@sp_wrOk        STA     _pipeWrFd
                LDY     #FCB_Flags
                LDA     #FCB_FL_PIPE+FCB_FL_WRITE   ; disjoint bits -> + == OR
                STA     [_fcbPtr],Y
                LDY     #FCB_FstIdx
                LDA     #0
                STA     [_fcbPtr],Y
                LDY     #FCB_PipeIdx
                LDA     _pipeAllocIdx
                STA     [_fcbPtr],Y
                ; --- write fd[0]=rdFd, fd[1]=wrFd to the user buffer ---
                REP     #$30
                MX      %00
                LDA     _pipeUserFdOff
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDY     #0
                LDA     _pipeRdFd
                AND     #$00FF
                STA     [_libcTmp2],Y           ; fd[0] = read end (16-bit int)
                LDY     #2
                LDA     _pipeWrFd
                AND     #$00FF
                STA     [_libcTmp2],Y           ; fd[1] = write end
                LDA     #0
                SEC
                RTS
@sp_wrFail      ; 2nd _Fcb_Alloc failed (A=errno, M=1).  Free read end + pipe slot.
                PHA                             ; save errno (M=1)
                SEP     #$20
                MX      %10
                LDA     _pipeRdFd
                JSR     _NlKC_FcbFree               ; refcount 1 -> frees FCB + zeroes slot
                REP     #$30
                MX      %00
                JSR     _Pipe_FreeSlot
                SEP     #$20
                MX      %10
                PLA                             ; errno
                REP     #$20
                MX      %00
                AND     #$00FF
                CLC
                RTS
@sp_rdFail      ; 1st _Fcb_Alloc failed (A=errno, M=1).  Free the pipe slot.
                PHA
                REP     #$30
                MX      %00
                JSR     _Pipe_FreeSlot
                SEP     #$20
                MX      %10
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                CLC
                RTS

;==============================================================================
; _Pipe_FdToIdx - resolve a pipe fd to its descriptor record offset.
; In: A = fd (MX %00).  Out: C=1 + Y = record offset (idx<<4) + _fcbPtr live,
; or C=0 + A = EBADF (not a valid pipe fd).  DBR=kernel-bank.
;==============================================================================
_Pipe_FdToIdx   MX      %00
                SEP     #$20
                MX      %10
                JSR     _NlKC_FcbLookupPtr          ; A=fd (M=1) -> C=1 + _fcbPtr / C=0
                BCC     @pf_bad
                LDY     #FCB_Flags
                LDA     [_fcbPtr],Y
                BIT     #FCB_FL_PIPE
                BEQ     @pf_notpipe
                LDY     #FCB_PipeIdx
                LDA     [_fcbPtr],Y             ; pipe idx (0..NPIPE-1)
                REP     #$20
                MX      %00
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL                             ; idx<<4 = record offset
                TAY
                SEC
                RTS
@pf_notpipe     REP     #$20
                MX      %00
                LDA     #EBADF
                CLC
                RTS
@pf_bad         REP     #$20
                MX      %00
                AND     #$00FF                  ; A = EBADF from _Fcb_LookupPtr
                CLC
                RTS

;==============================================================================
; _Pipe_Read - 2.11BSD readp(fp, uio): block until at least one byte is
; available (or all writers are gone -> EOF), then move up to uio_resid bytes
; from the ring into the uio (sys_pipe.c:101-150, where rwip does the move).
; Entry: A = fd; _pipeUio/_pipeUioBank = the caller's uio.  MX %00.
; Out: A = bytes (0 = EOF) + C=1, or A = errno + C=0 (EBADF/EINTR).
;==============================================================================
_Pipe_Read      MX      %00
                STZ     _pipeNonBlk             ; fd path blocks, as it always has
                JSR     _Pipe_FdToIdx           ; C=1 + Y=recOff / C=0 + A=EBADF
                BCS     @pr_have
                CLC
                RTS
@pr_have        STY     _pipeRecOff
                BRA     _Pipe_ReadUio

;==============================================================================
; _Pipe_ReadAt - _Pipe_Read's body, entered with _pipeRecOff ALREADY SET and the
; destination as a BUFFER: _pipeBufOff/_pipeBufBank/_pipeReqLen.  It becomes the
; kernel-static uio _pipeKUio here and the uio body runs.  MX %00.  Same Out
; contract.  AF_UNIX's record header is the one caller (_Pipe_BufUio says why).
;
; The ring bodies are entered by record offset as well as by fd because a
; socket's rings -- loopback's pair, AF_UNIX's receive ring -- belong to a
; SOCKET descriptor that _Pipe_FdToIdx cannot resolve.  _Loop_SoIo and
; unp.s enter _Pipe_ReadUio/_Pipe_WriteUio with _pipeRecOff set, and so
; inherit the blocking, wrap, EOF-on-writers-gone and _wakeup ordering the
; pipe fixtures cover.
;==============================================================================
_Pipe_ReadAt    MX      %00
                LDA     #UIO_READ
                JSR     _Pipe_BufUio
_Pipe_ReadUio   MX      %00
                JSR     _Pipe_UioResid          ; _pipeReqLen = uio_resid
;------------------------------------------------------------------------------
; _Pipe_ReadCapped - the read body with _pipeReqLen already set by the caller,
; no more than the uio's resid.  AF_UNIX reads a record's payload this way: the
; ring holds the NEXT record's header right after it, so the read must stop at
; the record and not at the caller's buffer.
;------------------------------------------------------------------------------
_Pipe_ReadCapped MX     %00
                STZ     _pipeDone               ; read is single-shot
@pr_wait        ; Count > 0 ?
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_Count
                TAY
                LDA     [_pipeTablePtr],Y       ; 16-bit Count
                BNE     @pr_data
                ; empty: WrClosed -> EOF
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_WrClosed
                TAY
                SEP     #$20
                MX      %10
                LDA     [_pipeTablePtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @pr_eof
                LDA     _pipeNonBlk             ; O_NONBLOCK/SOCK_NB: no data, do
                BNE     @pr_eagain              ;   not sleep -- report EAGAIN
                JSR     _Pipe_PollIntr          ; block; C=1 if ^C pending
                BCS     @pr_intr
                BRL     @pr_wait                ; recheck (long back-branch)
@pr_eagain      LDA     #EAGAIN
                CLC
                RTS
@pr_eof         LDA     #0
                SEC
                RTS
@pr_intr        LDA     #EINTR
                CLC
                RTS
@pr_data        ; A = Count (>0).  copyN = min(Count, _pipeReqLen).
                CMP     _pipeReqLen
                BCC     @pr_haveN               ; Count < req -> copyN = Count
                LDA     _pipeReqLen
@pr_haveN       STA     _pipeChunk
                JSR     _Pipe_CopyOut           ; ring[Head..] -> user; advance Head, Count -=
                LDA     #WCHAN_PIPE             ; space freed -> wake a blocked writer
                JSR     _NlKC_Wakeup
                LDA     _pipeChunk
                SEC
                RTS

;==============================================================================
; _Pipe_Write - 2.11BSD writep(fp, uio): move the whole uio into the ring,
; sleeping while it is full and waking readers as it fills (sys_pipe.c:152-213).
; A partial count on ^C.  Broken pipe (all readers gone) -> SIGPIPE / EPIPE.
; Entry: A = fd; _pipeUio/_pipeUioBank = the caller's uio.  MX %00.
; Out: A = bytes written + C=1, or A = errno + C=0 (EBADF/EPIPE/EINTR).
;==============================================================================
_Pipe_Write     MX      %00
                STZ     _pipeNonBlk             ; fd path blocks, as it always has
                JSR     _Pipe_FdToIdx
                BCS     @pw_have
                CLC
                RTS
@pw_have        STY     _pipeRecOff
                BRA     _Pipe_WriteUio

;==============================================================================
; _Pipe_WriteAt - _Pipe_Write's body, entered with _pipeRecOff ALREADY SET and
; the source as a BUFFER, as for _Pipe_ReadAt.  MX %00.  See _Pipe_ReadAt's
; header for why the split exists.
;==============================================================================
_Pipe_WriteAt   MX      %00
                LDA     #UIO_WRITE
                JSR     _Pipe_BufUio
_Pipe_WriteUio  MX      %00
                JSR     _Pipe_UioResid          ; _pipeReqLen = uio_resid
                STZ     _pipeDone
@pw_loop        ; finished?  (done == req)
                LDA     _pipeDone
                CMP     _pipeReqLen
                BCC     @pw_more
                LDA     _pipeDone
                SEC
                RTS
@pw_more        ; RdClosed -> broken pipe
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_RdClosed
                TAY
                SEP     #$20
                MX      %10
                LDA     [_pipeTablePtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @pw_space
                ; reader gone.  If we already wrote some, return the partial count.
                LDA     _pipeDone
                BEQ     @pw_broken
                LDA     _pipeDone
                SEC
                RTS
@pw_broken      JSR     _Pipe_OnBrokenPipe      ; Task 3: _Sig_Raise(SIGPIPE); A=EPIPE
                CLC
                RTS
@pw_space       ; free = PIPE_BufSz - Count  (Stage P: the CURRENT ring size)
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_Count
                TAY
                LDA     [_pipeTablePtr],Y
                STA     _pipeCount
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_BufSz
                TAY
                LDA     [_pipeTablePtr],Y
                SEC
                SBC     _pipeCount              ; A = free bytes
                BNE     @pw_haveFree
                ; full: GROW the ring (Stage P) before ever blocking -- the
                ; deferred-parent backquote shape has the sole reader
                ; suspended while a pre-exec child writes, so a fixed ring
                ; would deadlock; growth also helps every heavy pipeline.
                ; At PIPE_MAX_BUFSZ (or ring OOM) fall back to blocking.
                JSR     _Pipe_TryGrow
                BCC     @pw_noGrow
                BRL     @pw_loop                ; grew -- recompute space
@pw_noGrow      LDA     _pipeNonBlk             ; would block with a full ring
                BEQ     @pw_blockok
                LDA     _pipeDone               ; POSIX: partial count if we wrote
                BNE     @pw_partial             ;   anything, EAGAIN only at zero
                LDA     #EAGAIN
                CLC
                RTS
@pw_partial     SEC
                RTS
@pw_blockok     JSR     _Pipe_PollIntr
                BCS     @pw_intr
                BRL     @pw_loop
@pw_haveFree    STA     _pipeChunk              ; tentative chunk = free
                LDA     _pipeReqLen             ; remaining = req - done
                SEC
                SBC     _pipeDone
                CMP     _pipeChunk
                BCS     @pw_chunkSet            ; remaining >= free -> chunk = free
                STA     _pipeChunk              ; chunk = remaining
@pw_chunkSet    JSR     _Pipe_CopyIn            ; user[bufOff+done..] -> ring[Tail]; Tail+, Count+
                LDA     #WCHAN_PIPE             ; data available -> wake a blocked reader
                JSR     _NlKC_Wakeup
                LDA     _pipeDone               ; done += chunk
                CLC
                ADC     _pipeChunk
                STA     _pipeDone
                BRL     @pw_loop
@pw_intr        ; interrupted: return partial count if any, else EINTR
                LDA     _pipeDone
                BEQ     @pw_eintr
                SEC
                RTS
@pw_eintr       LDA     #EINTR
                CLC
                RTS

;==============================================================================
; _Pipe_OnBrokenPipe - write to a pipe whose read end is fully closed.
; Raises SIGPIPE on the current (writer) task; its default action is SA_TERM,
; so _Sys_CheckSignal terminates the writer at this syscall's exit (->
; _Exit_Core, WIFSIGNALED).  We still return EPIPE (C=0) as a defensive
; fallthrough in case delivery is ever deferred — so a writer that somehow
; survives sees the error rather than spinning.  MX %00.
;==============================================================================
_Pipe_OnBrokenPipe MX   %00
                LDA     #SIGPIPE                ; 13 (default SA_TERM)
                JSR     _NlKC_SigRaise              ; post to _curTask; kills at syscall exit
                LDA     #EPIPE                  ; defensive: surface error if not delivered
                RTS

;==============================================================================
; _Pipe_CopyOut - move _pipeChunk bytes from ring[Head] into the uio, honoring
; the wrap.  Advances Head, decrements Count.
; In: _pipeRecOff, _pipeChunk, _pipeUio.  MX %00.
;==============================================================================
_Pipe_CopyOut   MX      %00
                LDA     _pipeRecOff             ; _pipeCur = Head
                CLC
                ADC     #PIPE_Head
                TAY
                LDA     [_pipeTablePtr],Y
                STA     _pipeCur
                JSR     _Pipe_RingMove          ; ring -> uio; _pipeCur = new Head
                LDA     _pipeRecOff             ; store Head back
                CLC
                ADC     #PIPE_Head
                TAY
                LDA     _pipeCur
                STA     [_pipeTablePtr],Y
                LDA     _pipeRecOff             ; Count -= chunk
                CLC
                ADC     #PIPE_Count
                TAY
                LDA     [_pipeTablePtr],Y
                SEC
                SBC     _pipeChunk
                STA     [_pipeTablePtr],Y
                RTS

;==============================================================================
; _Pipe_CopyIn - move _pipeChunk bytes from the uio into ring[Tail], honoring
; the wrap.  Advances Tail, increments Count.
; In: _pipeRecOff, _pipeChunk, _pipeUio.  MX %00.
;==============================================================================
_Pipe_CopyIn    MX      %00
                LDA     _pipeRecOff             ; _pipeCur = Tail
                CLC
                ADC     #PIPE_Tail
                TAY
                LDA     [_pipeTablePtr],Y
                STA     _pipeCur
                JSR     _Pipe_RingMove          ; uio -> ring; _pipeCur = new Tail
                LDA     _pipeRecOff             ; store Tail back
                CLC
                ADC     #PIPE_Tail
                TAY
                LDA     _pipeCur
                STA     [_pipeTablePtr],Y
                LDA     _pipeRecOff             ; Count += chunk
                CLC
                ADC     #PIPE_Count
                TAY
                LDA     [_pipeTablePtr],Y
                CLC
                ADC     _pipeChunk
                STA     [_pipeTablePtr],Y
                RTS

;==============================================================================
; _Pipe_RingMove - uiomove _pipeChunk bytes between the ring at _pipeCur and the
; uio, in whichever direction the uio's uio_rw says.  A chunk that crosses the
; end of the ring is two moves, the second from offset 0.
;
; This is rwip's job in 2.11BSD (sys_pipe.c readp/writep hand the uio to rwip,
; which uiomoves), and uiomove walks the iovecs -- so no caller here knows how
; many entries the uio has.
;
; In:  _pipeRecOff, _pipeCur = the ring cursor, _pipeChunk.  MX %00.
; Out: _pipeCur = the cursor after the move, wrapped.  Clobbers A, X, Y.
;==============================================================================
_Pipe_RingMove  MX      %00
                JSR     _Pipe_LoadRingPtr       ; _kCopyPtr = ring base
                JSR     _Pipe_LoadBufSz         ; _pipeBufSz = current ring size
                LDA     _pipeBufSz              ; seg = min(chunk, size - cur)
                SEC
                SBC     _pipeCur
                CMP     _pipeChunk
                BCC     @rm_seg1
                LDA     _pipeChunk
@rm_seg1        STA     _pipeSeg
                LDA     _kCopyPtr
                CLC
                ADC     _pipeCur                ; the ring never crosses a bank
                LDY     _pipeSeg
                JSR     _Net_Uio1
                LDA     _pipeCur
                CLC
                ADC     _pipeSeg
                CMP     _pipeBufSz
                BCC     @rm_noWrap
                LDA     #0
@rm_noWrap      STA     _pipeCur
                LDA     _pipeChunk              ; the rest, from the ring's start
                SEC
                SBC     _pipeSeg
                BEQ     @rm_done
                STA     _pipeSeg
                LDA     _kCopyPtr
                LDY     _pipeSeg
                JSR     _Net_Uio1
                LDA     _pipeSeg
                STA     _pipeCur
@rm_done        RTS

;==============================================================================
; _Pipe_UioResid - _pipeReqLen = the caller uio's uio_resid.  MX %00.
;==============================================================================
_Pipe_UioResid  MX      %00
                JSR     _Pipe_LoadUio           ; _libcTmp2 = the uio
                LDY     #UIO_RESID
                LDA     [_libcTmp2],Y
                STA     _pipeReqLen
                RTS

_Pipe_LoadUio   MX      %00
                LDA     _pipeUio
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _pipeUioBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                RTS

;==============================================================================
; _Pipe_BufUio - turn the buffer form (_pipeBufOff/_pipeBufBank/_pipeReqLen)
; into the kernel-static one-entry uio _pipeKUio, and point _pipeUio at it.
;
; KERNEL STATIC, NOT PER TASK.  The only caller is AF_UNIX's three-byte record
; header, a kernel buffer that is moved without ever sleeping; the caller's
; payload uio is in the u-area, and building this one there would overwrite it.
;
; In:  A = UIO_READ or UIO_WRITE.  MX %00.  Clobbers A, Y, _kCopyPtr.
;==============================================================================
_Pipe_BufUio    MX      %00
                PHA                             ; rw
                LDA     #_pipeKIov
                STA     _kCopyPtr
                LDA     #_pipeKUio
                STA     _libcTmp2
                STA     _pipeUio
                PHB                             ; both are in the kernel bank,
                SEP     #$20                    ;   which is DBR here
                MX      %10
                PLA
                STA     _kCopyPtr+2
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                AND     #$00FF
                STA     _pipeUioBank
                PLA
                BRA     _Uio_Fill

;==============================================================================
; _Uio_Fill - fill a one-entry uio at [_libcTmp2] whose iovec is at [_kCopyPtr],
; over (_pipeBufOff, _pipeBufBank, _pipeReqLen): 2.11BSD read()/write()'s aiov
; and auio (sys_generic.c:84-100).  uio_offset 0, uio_segflg UIO_USERSPACE --
; uiomove copies for either flag, a kernel buffer being a far pointer too.
;
; In:  A = uio_rw.  MX %00.  Clobbers A, Y.
;==============================================================================
_Uio_Fill       MX      %00
                PHA                             ; rw
                LDA     _pipeBufOff
                LDY     #0
                STA     [_kCopyPtr],Y           ; iov_base lo16
                LDA     _pipeBufBank
                AND     #$00FF
                LDY     #2
                STA     [_kCopyPtr],Y           ; iov_base bank (pad 0)
                LDA     _pipeReqLen
                LDY     #4
                STA     [_kCopyPtr],Y           ; iov_len
                LDY     #UIO_RESID
                STA     [_libcTmp2],Y
                LDA     _kCopyPtr               ; uio_iov
                LDY     #0
                STA     [_libcTmp2],Y
                LDA     _kCopyPtr+2
                AND     #$00FF
                LDY     #2
                STA     [_libcTmp2],Y
                LDA     #1
                LDY     #4
                STA     [_libcTmp2],Y           ; uio_iovcnt
                LDA     #0
                LDY     #UIO_OFFSET
                STA     [_libcTmp2],Y           ; uio_offset, both halves
                LDY     #UIO_OFFSET+2
                STA     [_libcTmp2],Y
                LDY     #12
                STA     [_libcTmp2],Y           ; uio_segflg
                PLA
                LDY     #UIO_RW
                STA     [_libcTmp2],Y
                RTS

;==============================================================================
; _Net_Uio1 - one uiomove(cp, n, uio) from this module: cp = _kCopyPtr's bank
; with offset A, n = Y, uio = _pipeUio.
;
; pty.s's _Pty_Uio1 is the pattern, and its header carries the frame argument:
; the saved DBR and D go on BELOW the arguments, D becomes FGX_DP_KERNELC only
; after they are pushed, and the call is a pile-call through RTL.  The one
; difference is cp's bank, which is the ring's here rather than the kernel's.
;
; vfs.mod's uiomove is resolved on first use through KSVC_FINDVTABLE; vfs.mod
; is staged by the boot program before /etc/rc loads this module.
;
; Out: A = uiomove's errno.  X, Y clobbered.
; ponytail: the errno is not acted on.  uiomove answers EFAULT only for a uio
; whose iovecs do not cover its resid, and every uio this module moves is one
; it or the syscall layer just built.
;==============================================================================
_Net_Uio1       MX      %00
                STA     |_netUioCp              ; cp offset
                LDA     |_netVfsBank
                BNE     @nu_have
                PHY
                JSR     _Net_ResolveVfs
                PLY
@nu_have        PHB                             ; the kernel bank, for the exit
                PHD                             ; the kernel page, likewise
                LDA     |_pipeUioBank
                PHA                             ; uio bank
                LDA     |_pipeUio
                PHA                             ; uio offset
                PHY                             ; n
                LDA     _kCopyPtr+2
                AND     #$00FF
                PHA                             ; cp bank: the ring's
                LDA     |_netUioCp
                PHA                             ; cp offset
                LDA     |_netVfsUiomove         ; the target, read while DBR is
                TAX                             ;   still the kernel's
                LDA     #FGX_DP_KERNELC
                TCD                             ; fcc's register file, for C
                SEP     #$20
                MX      %10
                LDA     |_netVfsBank
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$30
                MX      %00
                PHK                             ; netret_uio is in OUR bank
                PEA     netret_uio-1
                PHB                             ; target bank: DBR is vfs.mod's
                TXA
                DEC     A
                PHA                             ; target - 1
                RTL                             ; PILECALL
netret_uio      TAY                             ; park the errno
                TSC
                CLC
                ADC     #10                     ; drop the argument frame
                TCS
                PLD                             ; the kernel page back...
                PLB                             ; ...and the kernel bank
                TYA
                RTS

;------------------------------------------------------------------------------
; _Net_ResolveVfs - _netVfsUiomove/_netVfsBank from vfs.mod's VT_VFSCORE table,
; read the way _Pty_ResolveVfs does (pty.s): DBR to vfs.mod for the slot read,
; back via PLB, the bank stored LAST because it is the flag.  MX %00.
;------------------------------------------------------------------------------
_Net_ResolveVfs MX      %00
                LDA     #VT_VFSCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @nr_have
                RTS                             ; no vfs.mod: the flag stays 0
@nr_have        CLC
                ADC     #VFSCORE_Uiomove
                TAY
                PHB
                SEP     #$20
                MX      %10
                TXA
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$30
                MX      %00
                LDA     |$0000,Y                ; `|': not the direct-page form
                PLB
                STA     |_netVfsUiomove
                TXA
                AND     #$00FF
                STA     |_netVfsBank            ; LAST: this is the flag
                RTS

;==============================================================================
; _Pipe_LoadRingPtr - _kCopyPtr = the ring base (PIPE_BufPtr) of _pipeRecOff.
; A transient DP long-ptr; no _sleep happens during the copy loop, so the
; "caller-saved scratch" _kCopyPtr is stable for the duration.  MX %00.
;==============================================================================
_Pipe_LoadRingPtr MX    %00
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_BufPtr
                TAY
                LDA     [_pipeTablePtr],Y       ; ring ptr lo16
                STA     _kCopyPtr
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     [_pipeTablePtr],Y       ; ring ptr bank
                STA     _kCopyPtr+2
                REP     #$20
                MX      %00
                RTS

;==============================================================================
; _Pipe_LoadBufSz - _pipeBufSz = the CURRENT ring size (PIPE_BufSz) of
; _pipeRecOff (Stage P: rings grow on demand, so wraps compare against the
; field, never the PIPE_BUFSZ constant).  MX %00.
;==============================================================================
_Pipe_LoadBufSz MX      %00
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_BufSz
                TAY
                LDA     [_pipeTablePtr],Y
                STA     _pipeBufSz
                RTS

;==============================================================================
; _Pipe_TryGrow - double a FULL ring, up to PIPE_MAX_BUFSZ (Stage P).
;
; Why: the deferred-parent backquote shape has the pipe's only reader
; suspended (fork/vfork parent) while a pre-exec child writes; a fixed
; ring would deadlock at 512 bytes.  Growth is unconditional-on-full, so
; every heavy pipeline benefits, and pipe.s needs no fork-awareness.
;
; The resident bytes are copied UNWRAPPED to the new ring (old[Head..]
; in ring order -> new[0..Count)), so afterward Head=0 and Tail=Count.
;
; In:  _pipeRecOff.  MX %00.  No _sleep in here.
; Out: C=1 ring doubled (caller re-loops and recomputes free space);
;      C=0 at the max already, or ring Kmalloc failed (caller blocks
;      exactly as before -- growth is an optimization, never a right).
;==============================================================================
_Pipe_TryGrow   MX      %00
                JSR     _Pipe_LoadBufSz
                LDA     _pipeBufSz
                CMP     #PIPE_MAX_BUFSZ
                BCC     @pg_canGrow
                CLC
                RTS
@pg_canGrow     ASL                             ; new size = 2x
                STA     _pgNewSz
                LDX     #M_KERN
                JSR     _NlKC_Kmalloc
                BCS     @pg_haveNew
                CLC                             ; OOM: block instead
                RTS
@pg_haveNew     ; park the new ring's ptr (Kfree consumes _kmallocResult later)
                LDA     _kmallocResult
                STA     _pgNew
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2
                STA     _pgNew+2
                REP     #$20
                MX      %00
                ; old ring -> _kCopyPtr; walker over the new ring -> _libcTmp2
                JSR     _Pipe_LoadRingPtr
                LDA     _pgNew
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _pgNew+2
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                ; Head + Count
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_Head
                TAY
                LDA     [_pipeTablePtr],Y
                STA     _pgHead
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_Count
                TAY
                LDA     [_pipeTablePtr],Y
                STA     _pgCount
                ; copy Count bytes, old ring order (Head, wrap at OLD BufSz)
                LDX     #0
                LDY     _pgHead
                SEP     #$20
                MX      %10
@pg_cL          CPX     _pgCount
                BCS     @pg_cDone
                LDA     [_kCopyPtr],Y
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2               ; new-ring walker
                INY
                CPY     _pipeBufSz              ; OLD wrap
                BCC     @pg_noWrap
                LDY     #0
@pg_noWrap      INX
                SEP     #$20
                MX      %10
                BRA     @pg_cL
@pg_cDone       REP     #$20
                MX      %00
                ; free the OLD ring (its base is still in _kCopyPtr)
                LDA     _kCopyPtr
                STA     _kmallocResult
                SEP     #$20
                MX      %10
                LDA     _kCopyPtr+2
                STA     _kmallocResult+2
                REP     #$20
                MX      %00
                JSR     _NlKC_Kfree
                ; record: BufPtr = new ring, Head = 0, Tail = Count, BufSz = 2x
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_BufPtr
                TAY
                LDA     _pgNew
                STA     [_pipeTablePtr],Y
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     _pgNew+2
                STA     [_pipeTablePtr],Y
                REP     #$20
                MX      %00
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_Head
                TAY
                LDA     #0
                STA     [_pipeTablePtr],Y
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_Tail
                TAY
                LDA     _pgCount
                STA     [_pipeTablePtr],Y
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_BufSz
                TAY
                LDA     _pgNewSz
                STA     [_pipeTablePtr],Y
                SEC
                RTS

;==============================================================================
; _Pipe_PollIntr - block a pipe read/write until a peer makes progress, or a
; signal wants this task.  Mirrors _Sock_PollIntr: _sleep on WCHAN_PIPE, then
; C=1 -> caller returns EINTR, C=0 -> caller re-checks its condition + retries.
; Saves the contiguous _pipe* cross-block scratch on this task's kernel stack
; across the _sleep so a concurrent task's pipe op can't clobber it.
; Preserves X/Y.  MX %00.
;
; The verdict is _sleep's own carry (P4/T1-T2, 2026-08-01).  This used to peek
; the keyboard ring for a literal $03 instead, and that check could never fire
; once a shell owned the tty: the heartbeat consumes ^C as a SIGNAL and never
; enqueues the byte.  Worse, the peek DEQUEUED whatever key it found and threw
; it away, and _sleep returns immediately (C=1) while a signal is pending -- so
; a signalled pipe reader span here eating every keystroke typed at the console
; and never reached the dispatcher exit where _Sys_CheckSignal would have
; applied it.  Measured: `sleep 60 | cat &` + `kill -2 <cat>` under bsh left the
; shell unable to read another character (probe p4_pipe_eintr).
;==============================================================================
_Pipe_PollIntr  MX      %00
                PHX
                PHY
                ; PRE-JOB-CONTROL FALLBACK.  When NO process group owns the tty
                ; (TTY_FgPgrp == 0 -- bsh, jsh, /etc/rc), the heartbeat does not
                ; turn ^C into a signal at all: toolbox.s gates that conversion
                ; on FgPgrp != 0 and otherwise enqueues the raw byte.  So for
                ; those sessions the ring peek IS the only ^C path, and deleting
                ; it outright made a blocked pipe read un-interruptible under
                ; bsh (`sleep 60 | cat` + ^C hung, where it had worked).  Keep
                ; the peek ONLY for that case: once a shell claims the tty the
                ; heartbeat produces a real signal and _sleep's carry below is
                ; the answer, so tcsh never pays the key-stealing cost the old
                ; unconditional peek imposed.
                ; t_pgrp is in the TTY BANK since T3 stage 1c; a module reaches
                ; the core through SYS_KCALL, not by JSL to an exported address.
                ; The caller's X/Y are already parked by this routine's own
                ; PHX/PHY, so the call need only be stack-neutral.
                LDA     #0                          ; console tty[0], offset 0
                LDX     #KSVC_TTYPGRP
                JSL     SYS_KCALL
                CMP     #0                          ; the call defines the carry
                BNE     @ppi_block                  ; a shell owns it -> signals
                JSR     _NlKC_ConPollKey            ; C=1 + A=key / C=0 + A=0
                BCC     @ppi_block
                AND     #$00FF
                CMP     #$03                        ; ^C -> interrupt
                BEQ     @ppi_intr
                ; a non-^C key was consumed (ignored, as before job control)
@ppi_block      ; Save the _pipe* cross-block scratch (high word first so the
                ; forward pop lands each word back at its own offset).
                LDX     #_PIPE_SCRATCH_LEN-2
@ppi_save       LDA     _pipeRecOff,X
                PHA
                DEX
                DEX
                BPL     @ppi_save
                LDA     #WCHAN_PIPE
                LDX     #PRIO_NORMAL            ; pri (reserved); X restored below
                JSR     _NlKC_Sleep                  ; idle until a pipe peer wakes us;
                                                ;   C=1 = a signal will act on us
                LDY     #0                      ; stash the verdict: the restore
                BCC     @ppi_flag               ;   loop below needs A and X, and Y
                LDY     #1                      ;   is already saved on the stack
@ppi_flag       LDX     #0                      ; restore _pipe* (forward = pop order)
@ppi_rest       PLA
                STA     _pipeRecOff,X
                INX
                INX
                CPX     #_PIPE_SCRATCH_LEN
                BCC     @ppi_rest
                CPY     #1                      ; C=1 iff Y=1 -> interrupted (EINTR);
                PLY                             ;   C=0 -> caller re-checks + retries.
                PLX                             ;   PLY/PLX leave carry alone.
                RTS
@ppi_intr       PLY                             ; ring-peek ^C (no fg pgrp case)
                PLX
                SEC
                RTS

;==============================================================================
; _Pipe_Teardown - one pipe end's FCB is fully closed (refcount hit 0).  Mark
; that end closed, wake any blocked peer (reader sees EOF / writer sees EPIPE),
; and free the ring + descriptor once BOTH ends are closed.
; In: _fcbPtr = the pipe FCB (read or write end).  MX %00.  Called from
; Fs_Close's FCB_FL_PIPE branch (gated on refcount-0 there).
;==============================================================================
_Pipe_Teardown  MX      %00
                PHP
                REP     #$30
                MX      %00
                ; record offset = FCB_PipeIdx << 4
                LDY     #FCB_PipeIdx
                SEP     #$20
                MX      %10
                LDA     [_fcbPtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                STA     _pipeRecOff
                ; which end? FCB_FL_WRITE distinguishes the write end.
                LDY     #FCB_Flags
                SEP     #$20
                MX      %10
                LDA     [_fcbPtr],Y
                AND     #FCB_FL_WRITE
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @pt_rdEnd
                LDA     _pipeRecOff             ; write end -> PIPE_WrClosed = 1
                CLC
                ADC     #PIPE_WrClosed
                TAY
                BRA     @pt_setClosed
@pt_rdEnd       LDA     _pipeRecOff             ; read end -> PIPE_RdClosed = 1
                CLC
                ADC     #PIPE_RdClosed
                TAY
@pt_setClosed   SEP     #$20
                MX      %10
                LDA     #1
                STA     [_pipeTablePtr],Y
                REP     #$20
                MX      %00
                LDA     #WCHAN_PIPE             ; wake any blocked peer to re-check
                JSR     _NlKC_Wakeup
                ; both ends closed? -> free the ring + descriptor.
                LDA     _pipeRecOff
                CLC
                ADC     #PIPE_RdClosed
                TAY
                SEP     #$20
                MX      %10
                LDA     [_pipeTablePtr],Y       ; RdClosed (0/1)
                STA     _pipeBothTmp
                INY                             ; PIPE_WrClosed = RdClosed+1
                LDA     [_pipeTablePtr],Y       ; WrClosed (0/1)
                AND     _pipeBothTmp            ; 1 iff both ends closed
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @pt_done
                JSR     _Pipe_FreeSlot          ; Kfree ring + InUse=0 (uses _pipeRecOff)
@pt_done        PLP
                RTS

;------------------------------------------------------------------------------
; pipe-core scratch (bounded module-local statics; syscall context).
; The first contiguous block (_pipeRecOff.._pipeNonBlk) is the cross-block
; state saved/restored by _Pipe_PollIntr across a blocking _sleep.  The length
; is anchored to _pipeChunk, the first TRANSIENT, so a field added anywhere
; inside the block is covered; it used to anchor to the last saved cell, which
; silently left a newly-appended cell outside the save.
