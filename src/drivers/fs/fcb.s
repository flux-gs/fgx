;==============================================================================
; fcb.s - File Control Block lifecycle for the FGX fs driver.
;
; Public:
;   _Fcb_Alloc       Find the lowest free fd (POSIX, so 0/1/2 too), Kmalloc an
;                    FCB, store the ptr at that slot, return fd in A (M=1).
;                    C=1 ok; C=0 + A=EMFILE if no free slot.
;   _Fcb_Free        A = fd (M=1).  Read the FCB ptr, Kfree it (and any
;                    cached data/index/master buffers it owns), zero the slot.
;                    C=1.
;   _Fcb_LookupPtr   A = fd (M=1).  Read the slot's 24-bit FCB ptr into
;                    _fcbPtr (DP, 3 bytes).  C=1 ok; C=0 + A=EBADF if fd
;                    out of range or slot is empty.
;
; Each task owns its own fd table — 8 long-pointer slots (3 bytes each =
; 24 bytes) Kmalloc'd from M_FS by Task_AllocFdTable.  The kernel-DP slot
; _fd_table_ptr always reflects the *current* task's table; the dispatcher
; repoints it from _curTask's TCB_FdTablePtr on every syscall entry.
;
; Slot index = fd * 3.  A slot reads 0,0,0 when closed; non-zero =
; pointer to a 32-byte FCB (also M_FS heap).
;
;
; There is no console descriptor of the kernel's making: init starts with an
; empty table, as 2.11BSD's does, and a console user opens /dev/console.
;==============================================================================

;------------------------------------------------------------------------------
; _Fcb_Alloc - allocate the lowest free fd (POSIX: including 0/1/2 once closed).
; Out: C=1 + A = fd (M=1), or C=0 + A=EMFILE.  M=1 X=0 on exit.
;
; MX:       Caller %00.  On exit, M=1, X=0 (Y is 16-bit).  PLP not used
;           (caller's M/X is overwritten — explicitly).
; Clobbers: A, X, Y, _shTmp0, _fcbPtr, _libcTmp2 (transitive via Kmalloc),
;           _kmem_*, _kmallocResult, _errno.  `_libcTmp2` left pointing at
;           the new chunk's header — see calling-conventions.md.
;------------------------------------------------------------------------------
_Fcb_Alloc      MX      %00
                PHP
                REP     #$30
                MX      %00

                ; Lowest free fd, from 0: POSIX requires open/creat/pipe to
                ; reuse a closed 0/1/2 (see _Sys_Dup); occupied slots are
                ; skipped by the in-use test below.
                LDX     #0                      ; X = candidate fd (16-bit)
@al_L           CPX     #FS_MAX_FDS
                BCC     @al_room
                BRL     @al_full                ; out of BCS range since the
                                                ;   file-table mirror landed
@al_room
                ; offset = X*3
                TXA
                ASL
                STA     _shTmp0
                TXA
                CLC
                ADC     _shTmp0                 ; A = X*3
                TAY
                ; Read the lo byte; if 0 AND hi+bank are 0, slot is free.
                ; Quick free-test: lo == 0 (most common case).
                SEP     #$20
                MX      %10
                LDA     [_fd_table_ptr],Y
                BNE     @al_taken
                ; (We accept a tiny risk of false positive if lo==0 but
                ;  slot is non-free — would only happen if some FCB landed
                ;  at exactly an offset $XX00 in its bank.  Kmalloc starts
                ;  arenas at offset 8 and aligns chunks to 2 B, so the lo
                ;  byte is rarely 0.  Belt-and-braces check the bank too.)
                INY
                INY
                LDA     [_fd_table_ptr],Y       ; bank byte
                BEQ     @al_free
                DEY
                DEY
@al_taken       REP     #$20
                MX      %00
                INX
                BRA     @al_L
@al_free        ; Slot is free.  Allocate a new FCB.
                DEY
                DEY                             ; Y = slot offset
                REP     #$20
                MX      %00
                PHX                             ; save fd
                PHY                             ; save slot offset
                LDA     #FCB_SIZE
                LDX     #M_FS
                JSR     Kmalloc
                BCS     @al_kok
                ; OOM
                PLY
                PLX
                PLP
                LDA     #ENOMEM
                STA     _errno
                CLC
                RTS
@al_kok         ; Zero the new FCB.
                LDA     _kmallocResult
                STA     _fcbPtr
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2
                STA     _fcbPtr+2
                REP     #$10
                MX      %10
                LDY     #0
                LDA     #0
@al_fzL         STA     [_fcbPtr],Y
                INY
                CPY     #FCB_SIZE
                BCC     @al_fzL
                ; New FCB starts with one reference (this fd slot).  BSD f_count.
                LDY     #FCB_RefCount
                LDA     #1
                STA     [_fcbPtr],Y
                ; Pop slot offset into Y, and write _fcbPtr's 3 bytes there.
                REP     #$20
                MX      %00
                PLY                             ; slot offset
                SEP     #$20
                MX      %10
                LDA     _fcbPtr
                STA     [_fd_table_ptr],Y
                INY
                LDA     _fcbPtr+1
                STA     [_fd_table_ptr],Y
                INY
                LDA     _fcbPtr+2
                STA     [_fd_table_ptr],Y
                REP     #$20
                MX      %00
                PLX                             ; fd

                ; MIRROR THE DESCRIPTOR IN THE FILE TABLE -- UFS 1.7d I2b.
                ;
                ; The scan above still decides the number, and this follows it.
                ; The other direction was tried and does not work incrementally:
                ; _Fd_Dup (syscall.s:1746) installs an FCB into this table
                ; without ever reaching here, so the file table cannot know
                ; which numbers are live.  Letting it choose handed fd 0 to the
                ; next open after getty dup2'd its tty onto 0, and the machine
                ; could not start a shell.  See fallocat in vfs_file.c.
                ;
                ; kdesc_alloc(pid, fcb, fd) -> errno, through far slot 29.
                ; fcc's convention is right to left, so fd goes down first and
                ; `pid' ends nearest the return address.  Within the 4-byte
                ; pointer the offset is the LOWEST address and so is pushed
                ; last of its three pieces.  The bank comes from the FCB itself
                ; -- never a `^' literal, which would bake the assembly bank
                ; into a relocated kernel.
                REP     #$30
                MX      %00
                PHX                             ; keep the fd for the return
                PHX                             ; fd (the argument)
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; fcb: pad
                LDA     _fcbPtr+2
                PHA                             ;      bank
                REP     #$30
                MX      %00
                LDA     _fcbPtr
                PHA                             ;      offset
                JSR     _Fcb_OwnerPid
                PHA                             ; pid
_kfp910         JSL     KFAR_VFS_DESCALLOC      ; bank byte patched by Far_Init
                TAY                             ; PARK THE ERRNO -- TSC below
                                                ;   clobbers A, and this used to
                                                ;   lose it before anything read
                                                ;   it
                TSC
                CLC
                ADC     #8                      ; drop the three arguments
                TCS
                TYA
                BNE     @al_mirror              ; the mirror refused: see below

                PLX                             ; fd back
                TXA
                SEP     #$20
                MX      %10
                PLP
                SEC
                RTS

                ; A MIRROR FAILURE IS FATAL TO THE OPEN NOW, AND THIS CODE
                ; ASKED FOR IT.  It used to be ignored, with a comment saying
                ; so: "Nothing dispatches through `struct file' yet -- the
                ; f_type ladder still classifies from FCB_Flags -- so a missing
                ; mirror entry costs coverage, while failing here would turn a
                ; full file table into an open(2) failure the machine does not
                ; have today.  WHEN I2c MAKES f_ops THE DISPATCH, THIS MUST
                ; BECOME FATAL: an fd with no `struct file' would then be a
                ; call through a null vector."
                ;
                ; That condition arrived: vfs_openat installs `vnops' and the
                ; descriptor dispatches through it.  So the open ALREADY failed
                ; -- vfs_openat opens with `getf(pid, fd)' and answers EBADF
                ; when the mirror has no struct for the fd -- and what ignoring
                ; the errno bought was the WRONG ONE.  MEASURED 2026-09-06 with
                ; /testbin/loopprobe -x: the 21st open of /etc/rc returned -1
                ; with errno 9, EBADF, which open(2) has no business answering
                ; about a descriptor it just allocated itself.  BSD's answer is
                ; ENFILE and 2.11BSD prints "file table overflow" beside it
                ; (Reno's falloc, kern/descrip.c:375); NFILE is 32 here and
                ; SYSTEM-WIDE, so a process holding twenty is not near its own
                ; FS_MAX_FDS of 30 and EMFILE would be a lie in the other
                ; direction.
                ;
                ; THE UNDO IS _Fcb_Free's, not a copy of it.  The FCB is
                ; allocated and the slot is written by the time the mirror is
                ; asked, so both have to go back -- and _Fcb_Free is the one
                ; routine that knows how, including the descriptor release.
@al_mirror      TAY                             ; Y = the mirror's errno
                PLX                             ; X = fd (the saved copy)
                PHY                             ; keep the errno across the call
                TXA                             ; A = fd
                SEP     #$20
                MX      %10
                JSR     _Fcb_Free               ; frees the FCB, clears the slot
                REP     #$30
                MX      %00
                PLA                             ; the errno back
                SEP     #$20
                MX      %10
                STA     _errno
                PLP
                CLC
                RTS
@al_full        SEP     #$20
                MX      %10
                LDA     #EMFILE
                STA     _errno
                PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; _Fcb_Free - free FCB + clear slot.  In: A = fd (M=1).  Out: C=1.
;
; MX:       Caller %10.  Preserves caller M/X via PHP/PLP.
; Clobbers: A, X, Y, _shTmp0, _fcbPtr, _libcTmp2 (transitive via Kfree),
;           _kmem_*, _kmallocResult.
;------------------------------------------------------------------------------
_Fcb_Free       MX      %10
                PHP
                ; RANGE-CHECK, do not MASK.  `AND #$0F` was only ever correct
                ; while the table had <=16 slots; once FS_MAX_FDS became 30
                ; (= BSD NOFILE, for the Bourne shell, which relocates its std
                ; fds to 10/11), close(16) masked to slot 0 and freed STDIN.
                ; _Fcb_LookupPtr bounds the same way -- match it.  Out of range
                ; = nothing to free, so return rather than corrupt a live slot.
                CMP     #FS_MAX_FDS
                BCS     @fr_ret
                STA     _shTmp0                 ; save fd
                ; ...and keep it: _shTmp0 is overwritten with fd*3 two
                ; instructions below, and the descriptor release needs the fd
                ; ITSELF, not the table offset.
                STA     _fcbFreeFd
                STZ     _fcbFreeFd+1
                ASL
                CLC
                ADC     _shTmp0                 ; A = fd*3 (8-bit)
                STA     _shTmp0                 ; slot offset (8-bit value)
                STZ     _shTmp0+1               ; clear high byte for 16-bit Y
                REP     #$10
                MX      %10
                LDY     _shTmp0
                ; Read FCB ptr from slot into _fcbPtr.
                LDA     [_fd_table_ptr],Y
                STA     _fcbPtr
                INY
                LDA     [_fd_table_ptr],Y
                STA     _fcbPtr+1
                INY
                LDA     [_fd_table_ptr],Y
                STA     _fcbPtr+2
                ; Drop one reference (BSD f_count).  Free the
                ; buffers + FCB only when the LAST referrer closes (refcount
                ; reaches 0); otherwise another fd still shares this FCB (e.g. a
                ; spawn-inherited copy in a child task) and freeing now would
                ; dangle it.  Always falls through to @fr_zero to clear THIS
                ; task's slot.
                LDY     #FCB_RefCount
                LDA     [_fcbPtr],Y
                BEQ     @fr_doFree              ; 0 already (defensive) -> free
                DEC
                STA     [_fcbPtr],Y
                BNE     @fr_zero                ; still referenced -> just drop slot
@fr_doFree      ; (P3.3-iv: the owner pointer is gone — no dangling-owner
                ; invalidation needed before Kfree.)
                SEP     #$20
                MX      %10
@fr_keepOwner   ; THE VNODE IS RELEASED UNDERNEATH, not here: _Fcb_Free ends
                ; in kdesc_free -> fdrelease -> closef -> fo_close -> vn_close,
                ; and vrele's ufs_inactive is what writes the inode back.
                ; Kfree the FCB itself (Kfree consumes _kmallocResult).
                REP     #$20
                MX      %00
                LDA     _fcbPtr
                STA     _kmallocResult
                SEP     #$20
                MX      %10
                LDA     _fcbPtr+2
                STA     _kmallocResult+2
                REP     #$20
                MX      %00
                JSR     Kfree
                SEP     #$20
                MX      %10
@fr_zero        ; Zero the fd_table slot (3 bytes).
                LDY     _shTmp0
                LDA     #0
                STA     [_fd_table_ptr],Y
                INY
                STA     [_fd_table_ptr],Y
                INY
                STA     [_fd_table_ptr],Y

                ; AND GIVE THE DESCRIPTOR BACK -- UFS 1.7d I2b, the other half
                ; of _Fcb_Alloc's kdesc_alloc.  Clearing this table's slot is
                ; not the close: the `struct file` lives in the FAR bank's file
                ; table and NFILE is 32.  Without this every close leaks one,
                ; boot and /etc/rc burn through them in about thirty opens, and
                ; falloc answers ENFILE for the rest of the machine's life --
                ; which presents as `init: console: cannot spawn '/bin/sh'`
                ; respawning forever.  A message about init, from a change to
                ; close(2).  MEASURED: with the leak still in, NFILE 32 -> 128
                ; made the machine boot, which is what identified it.
                ;
                ; THE SAME pid THE ALLOCATION USED.  fdrelease indexes the
                ; per-process array, so a close attributed to the wrong process
                ; clears someone else's descriptor and leaves this one live.
                ; _Fcb_OwnerPid, not _curTask: a spawn applying file actions is
                ; closing the CHILD's descriptors from inside the parent's
                ; syscall.
                ;
                ; ERRORS ARE DELIBERATELY IGNORED.  fdrelease answers EBADF for
                ; a descriptor the file table never had, and refusing to finish
                ; the close on that would strand the FCB.
                REP     #$30
                MX      %00
                LDA     _fcbFreeFd
                PHA                             ; fd  -- pushed first, so it
                                                ;   lands ABOVE pid; fcc reads
                                                ;   arguments right to left
                JSR     _Fcb_OwnerPid
                PHA                             ; pid -- nearest the return
_kfp911         JSL     KFAR_VFS_DESCFREE       ; bank byte patched by Far_Init
                TSC
                CLC
                ADC     #4                      ; drop the two arguments
                TCS
                SEP     #$20
                REP     #$10
                MX      %10
@fr_ret         PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _Fcb_InheritRefs - bump the refcount of every FCB referenced by
; the fd table whose 24-bit base is in _libcTmp2 (a DP long ptr).  Called from
; posix_spawn right AFTER the parent's fd table is memcpy'd into the child: the
; child's inherited slot copies are new references to the same shared
; open-file-descriptions, so each FCB's f_count must rise by one.  Without this
; the child's exit-time _Sys_CloseAllFds would Kfree an FCB the parent still
; holds -> use-after-free + double-free (the boot-time bug).
;
; In: _libcTmp2 = child fd-table base (preserved).  MX %00
; in/out (PHP/PLP).  Clobbers A,X,Y,_fcbPtr,_shTmp0.
;------------------------------------------------------------------------------
_Fcb_InheritRefs MX     %00
                PHP
                REP     #$30
                MX      %00
                LDX     #0                      ; fd index 0..FS_MAX_FDS-1
@ir_L           CPX     #FS_MAX_FDS
                BCS     @ir_done
                ; slot byte offset = X*3
                TXA
                ASL
                STA     _shTmp0
                TXA
                CLC
                ADC     _shTmp0
                TAY                             ; Y = slot offset
                ; Read this slot's 3-byte FCB ptr into _fcbPtr.
                SEP     #$20
                MX      %10
                LDA     [_libcTmp2],Y
                STA     _fcbPtr
                INY
                LDA     [_libcTmp2],Y
                STA     _fcbPtr+1
                INY
                LDA     [_libcTmp2],Y
                STA     _fcbPtr+2               ; bank byte (0 = empty slot)
                BEQ     @ir_next
                ; Bump f_count; saturate at 255 (leak, not wrap -> UAF).
                LDY     #FCB_RefCount
                LDA     [_fcbPtr],Y
                CMP     #$FF
                BEQ     @ir_next
                INC
                STA     [_fcbPtr],Y
@ir_next        REP     #$30
                MX      %00
                INX
                BRA     @ir_L
@ir_done        PLP
                RTS

;------------------------------------------------------------------------------
; _Fcb_DropRefs - the exact inverse of _Fcb_InheritRefs: walk the fd table whose
; 24-bit base is in _libcTmp2 (a DP long ptr) and DECREMENT every FCB's
; refcount by one (without freeing -- the holder we are releasing on behalf
; of is, by construction, never the last referrer: a successful spawn's child
; drops its refs through _Sys_CloseAllFds at exit, and a FAILED spawn's child
; never ran, so the parent still holds every inherited FCB).
;
; Why this exists: a failed posix_spawn (e.g. each non-matching $PATH directory
; an execvp-style search probes) bumps every open FCB via _Fcb_InheritRefs, then
; rolls back through Task_Free WITHOUT ever calling _Sys_CloseAllFds — so the
; inherited references leaked.  A leaked pipe write-end ref kept its refcount >=2
; forever, so Fs_Close's @fc_pipe teardown gate never fired, PIPE_WrClosed never
; got set, and a downstream reader blocked on EOF forever (spawned-writer
; pipeline deadlock).  Task_FreeFdTable now calls this before Kfree'ing the
; table, restoring the invariant "freeing a task's fd table releases the
; references it holds."  At normal exit the slots are already zeroed (a no-op);
; at spawn rollback they still point at the inherited FCBs (the real work).
;
; In: _libcTmp2 = fd-table base (preserved).  MX %00 in/out
; (PHP/PLP).  Clobbers A,X,Y,_fcbPtr,_shTmp0.
;------------------------------------------------------------------------------
_Fcb_DropRefs   MX      %00
                PHP
                REP     #$30
                MX      %00
                LDX     #0                      ; fd index 0..FS_MAX_FDS-1
@drp_L          CPX     #FS_MAX_FDS
                BCS     @drp_done
                ; slot byte offset = X*3
                TXA
                ASL
                STA     _shTmp0
                TXA
                CLC
                ADC     _shTmp0
                TAY                             ; Y = slot offset
                ; Read this slot's 3-byte FCB ptr into _fcbPtr.
                SEP     #$20
                MX      %10
                LDA     [_libcTmp2],Y
                STA     _fcbPtr
                INY
                LDA     [_libcTmp2],Y
                STA     _fcbPtr+1
                INY
                LDA     [_libcTmp2],Y
                STA     _fcbPtr+2               ; bank byte (0 = empty slot)
                BEQ     @drp_next
                ; Drop f_count; guard against underflow (defensive — an inherited
                ; ref is never the last, so this is always >= 1 here in practice).
                LDY     #FCB_RefCount
                LDA     [_fcbPtr],Y
                BEQ     @drp_next
                DEC
                STA     [_fcbPtr],Y
@drp_next       REP     #$30
                MX      %00
                INX
                BRA     @drp_L
@drp_done       PLP
                RTS

;------------------------------------------------------------------------------
; _Fcb_LookupPtr - resolve fd → _fcbPtr (24-bit DP slot).
; In:  A = fd (M=1).
; Out: C=1 + _fcbPtr filled, or C=0 + A=EBADF + _errno set.
;
; MX:       Caller %10.  Preserves M/X via PHP/PLP.
; Clobbers: A, X, Y, _shTmp0 (used as fd*3 byte-offset scratch), _fcbPtr,
;           _errno.  Note: `_shTmp0` clobber means callers using `_shTmp0`
;           for their own fd MUST save it elsewhere before calling Fs_Read /
;           Fs_Write and Fs_Close, both of which
;           call _Fcb_LookupPtr internally.

;------------------------------------------------------------------------------
; THE LEGACY fileops TABLES -- UFS 1.7d I2c.
;
; One `struct fileops' per descriptor type, in the layout include/vfs_equ.s
; publishes, so that f_ops is ONE shape whether a descriptor names vfs.mod's C
; `vnops' or one of these; only the bank it points into differs.  That matters
; at I3, when a real /dev puts vnode descriptors alongside these.
;
; THEY HOLD CORE-BANK ROUTINES WITH THE CORE'S CALLING CONVENTION, not fcc
; functions.  Nothing in the far bank may call through them -- which is why
; closef's fo_close call becomes vnode-only in the same step that installs
; these.  A pile call into an assembly arm that returns with SEC/RTS would
; return into the C's frame with a byte missing.
;
; FOUR SLOTS ARE FILLED; fo_close is the fifth and STAYS NULL.  That is not an
; omission: closef, in the FAR bank, is fo_close's caller, and these are
; core-bank routines that end SEC/RTS.  A legacy type's teardown belongs to
; Fs_Close's own per-type table, which is core code calling core code, and this
; slot fills only when a descriptor's ops are C in vfs.mod -- a vnode, at I3.
; A ZERO SLOT MEANS "not through f_ops" and no caller may jump to it;
; _Fcb_OpEntry returns C=0 for one.
;
; THE BANK BYTES ARE STAMPED AT BOOT by _Fcb_OpsInit.  A `^' literal here would
; assemble the ORG bank and the kernel is RELOCATED; the live bank is only
; knowable at run time.
;------------------------------------------------------------------------------
_kLegacyOps     ANOP
; 0: not a type.  Present so the index arithmetic needs no bias.
_kOpsNone       DA      0
                DFB     0,0             ; FO_READ  -- no legacy arm since ProDOS
                DA      0
                DFB     0,0             ; FO_WRITE -- left with it
                DA      _IoOp_Notty
                DFB     0,0             ; FO_IOCTL
                DA      0
                DFB     0,0             ; FO_SELECT
                DA      0
                DFB     0,0             ; FO_CLOSE
; 1: DTYPE_VNODE -- a file or directory.
_kOpsVnode      DA      0
                DFB     0,0             ; FO_READ  -- a vnode's ops are vfs.mod's
                DA      0
                DFB     0,0             ; FO_WRITE -- and cross the bank, so
                                        ;   _Fcb_OpEntry routes them far and
                                        ;   never reads these two slots
                DA      _IoOp_Notty
                DFB     0,0             ; FO_IOCTL
                DA      _SelOp_Default
                DFB     0,0             ; FO_SELECT
                DA      0
                DFB     0,0             ; FO_CLOSE
; 2: DTYPE_SOCKET.
_kOpsSocket     DA      _RdOp_Socket
                DFB     0,0             ; FO_READ
                DA      _WrOp_Socket
                DFB     0,0             ; FO_WRITE
                DA      _IoOp_Socket
                DFB     0,0             ; FO_IOCTL
                DA      _SelOp_Socket
                DFB     0,0             ; FO_SELECT
                DA      0
                DFB     0,0             ; FO_CLOSE
; 3: DTYPE_PIPE.
_kOpsPipe       DA      _RdOp_Pipe
                DFB     0,0             ; FO_READ
                DA      _WrOp_Pipe
                DFB     0,0             ; FO_WRITE
                DA      _IoOp_Notty
                DFB     0,0             ; FO_IOCTL
                DA      _SelOp_Default
                DFB     0,0             ; FO_SELECT
                DA      0
                DFB     0,0             ; FO_CLOSE
_kLegacyOpsEnd  ANOP
                ERR     _kOpsVnode-_kLegacyOps-FILEOPS_SIZE
                ERR     _kLegacyOpsEnd-_kLegacyOps-{4*FILEOPS_SIZE}

;------------------------------------------------------------------------------
; _Fcb_OpsInit - stamp the live bank into every non-null slot.  UFS 1.7d I2c.
;
; Called once from main.s.  Walks the tables as a flat byte array and writes
; PHK's bank into byte 2 of each 4-byte slot whose offset word is non-zero, so
; a filled slot becomes a real 24-bit pointer and an empty one stays zero --
; which is what _Fcb_OpEntry tests.
;
; MX %00 in and out.  Clobbers A, X, Y.
;------------------------------------------------------------------------------
_Fcb_OpsInit    MX      %00
                PHP
                REP     #$30
                MX      %00
                LDX     #0
@foi_L          CPX     #4*FILEOPS_SIZE
                BCS     @foi_done
                LDA     _kLegacyOps,X           ; the slot's offset word
                BEQ     @foi_next               ; empty slot: leave it null
                SEP     #$20
                MX      %10
                PHK
                PLA                             ; A.lo = the live bank
                STA     _kLegacyOps+2,X
                REP     #$20
                MX      %00
@foi_next       INX
                INX
                INX
                INX                             ; next slot, 4 bytes on
                BRA     @foi_L
@foi_done       PLP
                RTS

;------------------------------------------------------------------------------
; _Fcb_OpEntry - the routine that answers op `X' for descriptor `A'.
; UFS 1.7d I2c, and this is what "dispatch through f_ops" means here.
;
; It reads the answer OUT OF THE DESCRIPTOR rather than deriving it from
; FCB_Flags at every site, which is the whole point: a new descriptor type
; arrives by having an f_ops, not by being added to five branch chains.
;
; f_ops IS INSTALLED ON FIRST USE.  It cannot be installed at _Fcb_Alloc time,
; because the FS layer sets the FCB's type bit AFTER the allocation returns --
; the type is not known when the descriptor is made.  So the first operation on
; a descriptor derives the type once, through the classifier that has always
; owned that mapping, and writes f_ops and f_type into the struct; every later
; operation reads them.  There is still exactly one source for the mapping.
;
; THERE ARE THREE ANSWERS, NOT TWO -- UFS 1.7d I3.  A descriptor opened under
; /dev names `vnops', which is compiled into the FAR BANK, and the offset in
; its f_ops means nothing in this one: the sites jump with PHA/RTS, so a far
; offset would land at that offset in the CORE bank.  So the bank is read and
; COMPARED, and a mismatch is reported as its own answer rather than folded
; into C=0 -- the two want opposite handling, EBADF for "no vector" and
; route-the-syscall-over-the-seam for "not our vector".
;
; f_type CANNOT MAKE THIS DISTINCTION: a ProDOS file is DTYPE_VNODE too, and so
; is every descriptor kdesc_alloc mirrors.  Only the bank separates a real
; vnode from a legacy descriptor, which is why this is read from f_ops rather
; than derived from anything on the FCB.
;
; In:  A = fd (16-bit).  X = the op's offset (FO_READ..FO_CLOSE).
;      _fcbPtr = that descriptor's FCB, already resolved by the caller.
; Out: C=1 and A = the arm's offset in THIS bank.
;      C=0 and _fdOpsFar NONZERO: the ops are in another bank.  The caller
;      routes the whole syscall there; there is no arm for it to jump to.
;      C=0 and _fdOpsFar ZERO: the descriptor has no struct file, or the slot
;      is still empty -- the caller answers EBADF, or falls back to its own
;      per-type table where one still exists.
; MX:  %00 in and out.  Clobbers A, X, Y, _fdFilePtr, _fdOpsFar, _shTmp1,
;      _shTmp2.
;------------------------------------------------------------------------------
_Fcb_OpEntry    MX      %00
                PHP
                REP     #$30
                MX      %00
                STZ     _fdOpsFar               ; written before it can be read
                STX     _fdOpSlot
                JSR     _Fcb_FileOf             ; _fdFilePtr = struct file *
                BCC     @foe_none

                ; Installed already?  A null f_ops means this is the first
                ; operation on the descriptor.
                LDY     #F_OPS
                LDA     [_fdFilePtr],Y
                BNE     @foe_have
                JSR     _Fcb_InstallOps
                LDY     #F_OPS
                LDA     [_fdFilePtr],Y
                BEQ     @foe_none
@foe_have       TAX                             ; X = the fileops table offset
                SEP     #$20
                MX      %10
                LDY     #F_OPS+2
                LDA     [_fdFilePtr],Y
                STA     _shTmp2                 ; and its bank
                ; IS THAT BANK OURS?  PHK sources the LIVE one -- a `^' literal
                ; would be the assembly ORG and the kernel runs relocated,
                ; which is the same trap _Fcb_OpsInit and _Fcb_InstallOps both
                ; avoid three routines up.
                PHK
                PLA
                CMP     _shTmp2
                BNE     @foe_far
                REP     #$30
                MX      %00
                STX     _fdFilePtr              ; re-point at the fileops table
                SEP     #$20
                MX      %10
                LDA     _shTmp2
                STA     _fdFilePtr+2
                REP     #$30
                MX      %00
                LDY     _fdOpSlot
                LDA     [_fdFilePtr],Y          ; the arm's offset
                BEQ     @foe_none               ; slot not filled yet
                PLP
                SEC
                RTS
@foe_far        ; The ops are somewhere this bank cannot jump to.  Say WHICH
                ; kind of no it is and let the caller route.
                REP     #$30
                MX      %00
                LDA     #1
                STA     _fdOpsFar
                PLP
                CLC
                RTS
@foe_none       PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; _Fcb_InstallOps - give the descriptor in _fdFilePtr its f_ops and f_type.
;
; The type comes from _Fcb_ClassifyFlags, which has owned the FCB_Flags ->
; DTYPE_* mapping since 1.2a and still does; this stores its answer on the
; descriptor so that no later operation has to ask again.  When the five sites
; that set an FCB's type bit set f_type directly instead, the classifier and
; this function both go.
;
; In:  _fdFilePtr = struct file *.  _fcbPtr = its FCB.  MX %00.
; Out: F_TYPE and F_OPS written.  Clobbers A, X, Y.
;------------------------------------------------------------------------------
_Fcb_InstallOps MX      %00
                PHP
                SEP     #$20
                REP     #$10
                MX      %10
                LDY     #FCB_Flags
                LDA     [_fcbPtr],Y
                JSR     _Fcb_ClassifyFlags      ; A = DTYPE_*
                REP     #$30
                MX      %00
                AND     #$00FF
                STA     _shTmp1                 ; the type
                LDY     #F_TYPE
                STA     [_fdFilePtr],Y

                ; f_ops = _kLegacyOps + type * FILEOPS_SIZE.  FILEOPS_SIZE is
                ; 20, so <<4 + <<2, and an ERR refuses to assemble if that
                ; stops being true.
                ERR     FILEOPS_SIZE-20
                LDA     _shTmp1
                ASL
                ASL                             ; type * 4
                STA     _shTmp2
                ASL
                ASL                             ; type * 16
                CLC
                ADC     _shTmp2                 ; type * 20
                CLC
                ADC     #_kLegacyOps
                LDY     #F_OPS
                STA     [_fdFilePtr],Y
                SEP     #$20
                MX      %10
                PHK
                PLA                             ; the live bank, never a `^'
                LDY     #F_OPS+2
                STA     [_fdFilePtr],Y
                REP     #$30
                MX      %00
                PLP
                RTS

;------------------------------------------------------------------------------
; _Fcb_OwnerPid - the pid whose descriptors this layer is currently touching.
;
; UFS 1.7d I2b gave the FS layer a second descriptor table, and the two are
; addressed differently: the fd table through _fd_table_ptr, the file table BY
; PID.  Everywhere but one, _fd_table_ptr was derived from _curTask and the two
; questions have the same answer -- but _Sys_ApplyFdActions points the pointer
; at the CHILD while running inside the PARENT's spawn syscall, so a descriptor
; service reading _curTask there would touch the wrong process's entries.
;
; That is the hazard _kCttyTarget already exists for, and this follows it
; exactly: an override cell that is 0 for "the current task", set and cleared
; by the one routine that needs it.  See include/memmap.s.
;
; Out: A = pid (16-bit, zero-extended).  MX %00 in and out.  Touches nothing.
;------------------------------------------------------------------------------
_Fcb_OwnerPid   MX      %00
                LDA     _fdOwnerPid
                AND     #$00FF
                BNE     @fop_have
                LDA     _curTask
                AND     #$00FF
@fop_have       RTS



;------------------------------------------------------------------------------
; _Fcb_FileOf - the `struct file' that descriptor `fd' names.  UFS 1.7d I2c.
;
; THE CORE BANK READS THE FAR BANK'S TABLE DIRECTLY, and that is a deliberate
; choice rather than a shortcut.  f_ops is what the dispatch will call through,
; so this sits on read(2) and write(2); a far call to fetch it would be a bank
; round trip on the hottest path in the system.  The offsets it reads come from
; include/vfs_equ.s, which toolchain/tests/M37/vfslayout.c pins at runtime --
; that generated file exists so the C and the assembly read one descriptor, and
; this is the assembly it was generated for.
;
; The index arithmetic is fdbase()'s, in assembly: ofile_pool is a flat array of
; VFS_NPROC * FS_MAX_FDS pointers and pids are 1-based, so the slot is
; ((pid - 1) * FS_MAX_FDS + fd) * VFS_OFILE_PTR.  Both constants are generated
; beside the offsets, so neither side can drift.
;
; A ZERO BANK BYTE IS AN EMPTY SLOT -- the same test _Fcb_Alloc uses on the fd
; table, and it holds for the same reason: every live entry points into the far
; bank, and finit zeroes the array.
;
; In:  A = fd (16-bit, zero-extended).  MX %00.  DBR = kernel bank.
; Out: C=1 + _fdFilePtr = the 24-bit `struct file *'.
;      C=0 if there is no such descriptor, no far bank, or the pid has no
;      array.  _fdFilePtr is not meaningful then.
; MX:  %00 in and out (PHP/PLP).  Clobbers A, Y, _shTmp1, _shTmp2, _fdFilePtr.
;      _shTmp0 is deliberately NOT touched: _Fcb_LookupPtr uses it and runs
;      immediately before this at every call site.
;------------------------------------------------------------------------------
_Fcb_FileOf     MX      %00
                PHP
                REP     #$30
                MX      %00
                JSR     _Fcb_SlotIdx
                BCC     @ffo_none
                ASL
                ASL                             ; * 4 = VFS_OFILE_PTR
                ERR     VFS_OFILE_PTR-4
                TAY                             ; Y = byte offset into ofile_pool

                ; Point at the array, then read the slot through it.  One cell
                ; does both: the base is not needed once the slot is read.
                LDA     _kOfilePool
                STA     _fdFilePtr
                SEP     #$20
                MX      %10
                LDA     _kOfilePool+2
                STA     _fdFilePtr+2
                ; The slot is a 4-byte fcc pointer: offset word, bank, pad.
                LDA     [_fdFilePtr],Y
                STA     _shTmp2
                INY
                LDA     [_fdFilePtr],Y
                STA     _shTmp2+1
                INY
                LDA     [_fdFilePtr],Y          ; bank byte: 0 => empty slot
                BEQ     @ffo_none8
                STA     _shTmp1                 ; park it across the 16-bit store
                REP     #$30
                MX      %00
                LDA     _shTmp2
                STA     _fdFilePtr
                SEP     #$20
                MX      %10
                LDA     _shTmp1
                STA     _fdFilePtr+2
                REP     #$30
                MX      %00
                PLP
                SEC
                RTS

@ffo_none8      REP     #$30
                MX      %00
@ffo_none       PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; _Fcb_SlotIdx - descriptor `fd' of the owning process as an INDEX into the far
; bank's per-process arrays: (pid - 1) * FS_MAX_FDS + fd.  fdbase()'s
; arithmetic; ofile_pool and pofile_pool are both indexed by it.
; In:  A = fd (16-bit, zero-extended).  MX %00.
; Out: C=1 + A = the index; C=0 for a bad fd, no far bank, or no pid.
; Clobbers A, _shTmp1, _shTmp2.
;------------------------------------------------------------------------------
_Fcb_SlotIdx    MX      %00
                STA     _shTmp1                 ; fd
                CMP     #FS_MAX_FDS
                BCS     @fsi_none
                ; No far bank means no table.  _kOfilePool's bank byte is the
                ; honest test: _Vfs_FileInit is what writes it, and it does not
                ; run when Far_Init failed.
                LDA     _kOfilePool+2
                AND     #$00FF
                BEQ     @fsi_none
                JSR     _Fcb_OwnerPid           ; A = pid, 1-based
                BEQ     @fsi_none               ; boot before any task
                CMP     #CFG_KERNEL_NPROC+1
                BCS     @fsi_none
                DEC                             ; pid - 1

                ; (pid-1) * FS_MAX_FDS, as a shift pair rather than a multiply:
                ; FS_MAX_FDS is 30, so <<5 - <<1.  An ERR below refuses to
                ; assemble if that stops being true.
                ERR     FS_MAX_FDS-30
                STA     _shTmp2
                ASL
                ASL
                ASL
                ASL
                ASL                             ; (pid-1) * 32
                PHA
                LDA     _shTmp2
                ASL                             ; (pid-1) * 2
                STA     _shTmp2
                PLA
                SEC
                SBC     _shTmp2                 ; (pid-1) * 30
                CLC
                ADC     _shTmp1                 ; + fd  -> the slot index
                SEC
                RTS
@fsi_none       CLC
                RTS

;------------------------------------------------------------------------------
; _Fd_Pop - address descriptor `fd''s FLAG byte, Reno's `&u.u_pofile[fd]'.
; pofile_pool follows ofile_pool in the far arena (vfs_file.c finit), so it is
; _kOfilePool plus the generated VFS_POFILE_OFF, one byte per slot.
; In:  A = fd.  MX %00.
; Out: C=1 + [_fdFilePtr],Y = the flag byte; C=0 as _Fcb_SlotIdx.
; Clobbers A, Y, _shTmp1, _shTmp2, _fdFilePtr.
;------------------------------------------------------------------------------
_Fd_Pop         MX      %00
                JSR     _Fcb_SlotIdx
                BCC     @fp_none
                CLC
                ADC     #VFS_POFILE_OFF
                TAY
                LDA     _kOfilePool
                STA     _fdFilePtr
                SEP     #$20
                MX      %10
                LDA     _kOfilePool+2
                STA     _fdFilePtr+2
                REP     #$20
                MX      %00
                SEC
@fp_none        RTS

;------------------------------------------------------------------------------
; _Fcb_ClassifyFlags - what KIND of descriptor these flags describe.
;
; BSD's `f_type`, derived rather than stored -- see the DTYPE_* block in
; include/fs.s for why this slice derives it, and what storing it would cost.
; THIS IS THE ONLY PLACE THE MAPPING EXISTS.  Before it there were 35 separate
; flag tests in syscall.s alone, each re-deciding the same question, and each a
; place the answer could differ from its neighbours.
;
; A descriptor carries EXACTLY ONE type bit, so the order of the tests below
; cannot matter: every writer of a type bit is a plain store of a single
; constant (net.s and net_loop.s socket, pipe.s pipe), and every ORA onto
; FCB_Flags touches only non-type bits (WRITE, DIRTY, DIR).
;
; In:  A.lo = FCB_Flags.  M=1 (8-bit A) -- the immediates below assemble 8-bit,
;      so entering with M=0 misreads every one of them.  X's width is NOT part
;      of the contract: no index register is touched.  (This line used to gloss
;      %10 as "8-bit A and index"; %10 is 8-bit A and SIXTEEN-bit index.)
; Out: A.lo = DTYPE_*.  Flags clobbered; no memory touched.
;------------------------------------------------------------------------------
_Fcb_ClassifyFlags MX   %10
                PHA
                AND     #FCB_FL_SOCKET
                BEQ     @cf_notSock
                PLA
                LDA     #DTYPE_SOCKET
                RTS
@cf_notSock     PLA
                PHA
                AND     #FCB_FL_PIPE
                BEQ     @cf_notPipe
                PLA
                LDA     #DTYPE_PIPE
                RTS
                ; Everything else is a file -- including a DIRECTORY, which is
                ; a vnode in BSD and not a descriptor type of its own.
                ; FCB_FL_DIR stays a flag for exactly that reason.
@cf_notPipe     PLA
                LDA     #DTYPE_VNODE
                RTS

;------------------------------------------------------------------------------
_Fcb_LookupPtr  MX      %10
                PHP
                ; Range check.
                CMP     #FS_MAX_FDS
                BCC     @lp_inrange
                BRA     @lp_bad
@lp_inrange     ; offset = fd * 3
                STA     _shTmp0
                ASL
                CLC
                ADC     _shTmp0
                STA     _shTmp0                 ; byte offset (low)
                REP     #$10
                MX      %10
                LDY     _shTmp0                 ; 16-bit Y, hi byte from
                                                ; whatever — clear it:
                STZ     _shTmp0+1
                LDY     _shTmp0
                ; Read 3 bytes into _fcbPtr.
                LDA     [_fd_table_ptr],Y
                STA     _fcbPtr
                INY
                LDA     [_fd_table_ptr],Y
                STA     _fcbPtr+1
                INY
                LDA     [_fd_table_ptr],Y
                STA     _fcbPtr+2
                ; Empty slot test: bank=0 means closed.
                BNE     @lp_ok
                ; Could also be a true pointer with bank == 0 — but FGX
                ; never returns Kmalloc results in bank $00.  Safe.
@lp_bad         LDA     #EBADF
                STA     _errno
                PLP
                CLC
                RTS
@lp_ok          PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; Panic strings (boot-time OOM is fatal).
;------------------------------------------------------------------------------

;==============================================================================
; END fcb.s
;==============================================================================
