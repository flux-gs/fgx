;==============================================================================
; pipe.s - WHAT THE PIPE RINGS LEAVE IN THE CORE BANK.  The implementation
; is src/modules/net/pipe.s (moved 2026-08-11 with net_loop.s).  What stays:
; _AllocPipeTable (main.s calls it at boot, before Mod_LoadConf -- and it is
; the only caller of Kmalloc/Kern_LogStr/_Halt/_SoftGlob_ValidatePtr here, so
; leaving it removed four kernel callbacks), every scratch static (syscall.s
; stages them, which is how arguments still arrive), and the stubs below.
;
; original header follows.
; pipe.s - BSD pipe(2) core + the kernel pipe object (SYS_PIPE handler + the
; blocking read/write path that SYS_READ/SYS_WRITE route to for pipe fds).
;
; A pipe is a kernel-resident byte ring with two fd endpoints:
;   - the read end  (FCB_FL_PIPE)               -> _Pipe_Read
;   - the write end (FCB_FL_PIPE | FCB_FL_WRITE) -> _Pipe_Write
; Both FCBs carry the pipe's index (FCB_PipeIdx, 0..NPIPE-1) into the
; descriptor table reached via the DP long-pointer _pipeTablePtr (dpmap.s);
; records are PIPE_* (include/kernel.s), PIPE_REC_SZ each, accessed
; [_pipeTablePtr],Y with Y = idx<<4.  The ring itself is a separate
; Kmalloc(PIPE_BUFSZ) block reached via PIPE_BufPtr.
;
; Read/write block cooperatively on WCHAN_PIPE (no ISR — the only wakers are
; the peer's _Pipe_Read/_Pipe_Write/_Pipe_Teardown), so there is no lost-wakeup
; race: a cooperative task can't be preempted between testing the ring and
; calling _sleep.  Cross-block scratch (the contiguous _pipeRecOff.. block) is
; saved on the per-task kernel stack across the _sleep by _Pipe_PollIntr,
; mirroring _Sock_PollIntr — concurrent pipe users must not clobber each
; other's in-flight state (the cross-block-global-state class).
;
; Fs_Close routes FCB_FL_PIPE -> _Pipe_Teardown at refcount-0 (NOT on every
; close — pipe ends get dup'd by the shell, so an early teardown would free a
; ring the other dup still uses).
;
; PUT by src/kernel/main.s (after socket.s).
; Spec: docs/superpowers/specs/2026-06-09-jsh-pipes-design.md
;==============================================================================

;==============================================================================
; _AllocPipeTable - Kmalloc(NPIPE*PIPE_REC_SZ, M_KERN) -> _pipeTablePtr (DP).
; Mirrors _AllocSockTable.  Boot, after _AllocSockTable.  MX %00.
;==============================================================================
_AllocPipeTable MX      %00
                PHP
                REP     #$30
                LDA     #NPIPE*PIPE_REC_SZ
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @apt_ok
                LDA     #_panic_msg_pipetbl
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
@apt_ok         LDA     _kmallocResult
                STA     _pipeTablePtr
                SEP     #$20
                LDA     _kmallocResult+2
                STA     _pipeTablePtr+2
                REP     #$20
                JSR     _SoftGlob_ValidatePtr   ; always-on heap-ptr panic
                LDY     #0                      ; zero the table
                SEP     #$20
                LDA     #0
@apt_zL         STA     [_pipeTablePtr],Y
                INY
                CPY     #NPIPE*PIPE_REC_SZ
                BCC     @apt_zL
                REP     #$20
                PLP
                RTS

_panic_msg_pipetbl ASC  'PANIC: cannot alloc pipeTable',00

;==============================================================================
; _Pipe_Alloc - claim a free pipe descriptor + Kmalloc its ring.
; Out: C=1 + Y = record offset (idx<<4) + _pipeAllocIdx = idx; or
;      C=0 + A = errno (ENFILE no free slot / ENOMEM ring alloc).  MX %00.
;==============================================================================
;------------------------------------------------------------------------------
_pipeRecOff     DS      2               ; descriptor record offset (idx<<4)
_pipeReqLen     DS      2               ; bytes requested: the uio's resid at entry
_pipeDone       DS      2               ; bytes transferred so far (write; 0 for read)
_pipeUio        DS      2               ; the caller's struct uio, a far pointer:
_pipeUioBank    DS      2               ;   offset, then bank (low byte significant).
                                        ;   2.11BSD readp/writep take (fp, uio), and
                                        ;   the ring moves through uiomove as rwip's
                                        ;   does (sys_pipe.c).  The uio is a CURSOR the
                                        ;   copy advances across a sleep, so the
                                        ;   pointer is saved with the block.
_pipeNonBlk     DS      2               ; 1 = would-block returns EAGAIN instead of
                                        ;   sleeping (loopback sockets w/ SOCK_NB;
                                        ;   the fd wrappers pin it to 0).
                                        ;
                                        ; INSIDE THE SAVED BLOCK, and it has to be.
                                        ; It sat below with the transients, which
                                        ; the line beneath calls "recomputed each
                                        ; chunk; never live across _sleep" -- true
                                        ; of them and false of this one.  It is set
                                        ; ONCE per syscall and re-read on EVERY loop
                                        ; iteration, including the one after
                                        ; _Pipe_PollIntr sleeps (pipe.s @pr_wait and
                                        ; @pw_noGrow).  A blocking writer parked on a
                                        ; full ring therefore resumed and read
                                        ; whatever a loopback socket with SOCK_NB had
                                        ; left there, and a write with no O_NONBLOCK
                                        ; returned EAGAIN.
                                        ;
                                        ; Only 0 -> 1 can bite: a task whose own flag
                                        ; is 1 never sleeps, so nothing with a 1 is
                                        ; ever parked here to be corrupted.
_PIPE_SCRATCH_LEN EQU   *-_pipeRecOff
; _pipeNonBlk must live INSIDE the saved block.  It spent its whole life below
; it, among cells documented as never live across a sleep, and a blocking pipe
; operation could come back from _Pipe_PollIntr reading another task's flag.
; Moving it back out is a silent behaviour change, so it is an assembly error.
                ERR     {_pipeNonBlk+2-_pipeRecOff-1}/_PIPE_SCRATCH_LEN
; And the module's copy of this length anchors to _pipeChunk as "the first cell
; past the block", so _pipeChunk must sit exactly at the boundary or the two
; definitions of _PIPE_SCRATCH_LEN silently disagree and _Pipe_PollIntr saves
; the wrong byte count.  They cannot be cross-checked in source -- different
; assembly units -- so each side asserts its half.
                ERR     _pipeChunk-_pipeRecOff-_PIPE_SCRATCH_LEN
; --- transients (recomputed each chunk; never live across _sleep).  TEST that
;     claim before adding a cell here: anything read after a loop's sleep
;     belongs ABOVE this line, in the block _Pipe_PollIntr saves and restores.
_pipeChunk      DS      2               ; bytes in the current copy chunk
_pipeBufOff     DS      2               ; _Pipe_ReadAt/_Pipe_WriteAt's buffer form:
_pipeBufBank    DS      2               ;   offset, bank and length (_pipeReqLen),
                                        ;   turned into _pipeKUio at entry and
                                        ;   never read after it
_pipeKIov       DS      6               ; the buffer form's iovec and uio.  A
_pipeKUio       DS      16              ;   KERNEL static, not the u-area: its one
                                        ;   caller is AF_UNIX's record header,
                                        ;   which never sleeps, while the caller's
                                        ;   own uio for the payload is the u-area's
_pipeSeg        DS      2               ; one uiomove's length: a ring chunk splits
                                        ;   at the wrap into at most two
_netVfsUiomove  DS      2               ; vfs.mod's uiomove, resolved on first use;
_netVfsBank     DS      2               ;   the bank is the resolved flag (0 = not yet)
_netUioCp       DS      2               ; _Net_Uio1's cp offset, parked across the
                                        ;   frame build
_pipeCur        DS      2               ; ring cursor (Head for read / Tail for write)
_pipeCount      DS      2               ; cached PIPE_Count for the free-space compute
_pipeAllocIdx   DS      2               ; _Pipe_Alloc: chosen pipe index
_pipeRdFd       DS      2               ; _Sys_Pipe: read-end fd
_pipeWrFd       DS      2               ; _Sys_Pipe: write-end fd
_pipeUserFdOff  DS      2               ; _Sys_Pipe: user &fd[2] offset
_pipeBothTmp    DS      2               ; _Pipe_Teardown: both-closed accumulator
_pipeBufSz      DS      2               ; Stage P: cached CURRENT ring size
_pgNew          DS      4               ; Stage P: new ring long ptr (3B + pad)
_pgNewSz        DS      2               ; Stage P: doubled size
_pgHead         DS      2               ; Stage P: old Head at grow time
_pgCount        DS      2               ; Stage P: resident bytes at grow time

;==============================================================================
; DISPATCH STUBS.  Bodies in src/modules/net/pipe.s; see the note on the
; net_loop.s stubs for why a tail JMP through _NetThunkExec is all this takes.
;
; _Pipe_Read and _Pipe_Write are the ONLY two entries that took an argument in
; a REGISTER (A = fd).  _Net_Dispatch clobbers A, so the fd is staged in
; _pipeThunkFd here and the module's op reads it back.  Everything else already
; travelled in the statics above.
;==============================================================================
_pipeThunkFd    DS      2               ; A = fd, staged across the thunk

_Sys_Pipe       ENT
                MX      %00
                LDY     #NETOP_SysPipe
                JMP     _NetThunkExec
_Pipe_Read      ENT
                MX      %00
                STA     _pipeThunkFd
                LDY     #NETOP_PipeRead
                JMP     _NetThunkExec
_Pipe_Write     ENT
                MX      %00
                STA     _pipeThunkFd
                LDY     #NETOP_PipeWrite
                JMP     _NetThunkExec
_Pipe_Teardown  ENT
                MX      %00
                LDY     #NETOP_PipeTeardown
                JMP     _NetThunkExec
