;==============================================================================
; chardev.s - character-device registry + dispatch.
;
; Public:
;   _Chardev_RegisterInternal  Register a chardev whose name + ops live in
;                              the kernel bank ($02 = assembly ORG; built-in
;                              core devices like
;                              /dev/null).  Cross-bank module callers go
;                              through the MOD_REGISTERCHARDEV jumptable
;                              slot (see _Mod_RegisterCharDevImpl in
;                              jumptable.s) — that path is stubbed in
;                              slice 1 and wired in slice 2 when
;                              serial.mod becomes the first cross-bank
;                              caller.
;
;   _Chardev_LookupSuffix      Linear-scan name → idx.  Called by
;                              Path_Resolve's device short-circuit
;                              (slice 1.3).
;
;   _Chardev_Open / Close / Read / Write / Ioctl / Poll
;                              Kernel-side dispatchers reached from
;                              the vnode road's KSVC_CD* seam and
;                              `_Chardev_Bulk'.  Each loads the
;                              registered module's COPS_* triple and
;                              JSLs through a self-modifying trampoline
;                              (_cdTrampJSL) — works equally for
;                              kernel-bank built-ins and future cross-bank
;                              modules.
;
; Architecture: the chardev table is a flat array of CD_REC_STRIDE-byte
; records in the kernel bank (memmap.s _chardev_table; $02 = assembly ORG).
; Each entry caches the
; registered name (length-prefixed, up to 15 bytes), a 24-bit long
; pointer to the module's CharDev_Ops vtable, and an opaque "minor"
; value passed through to every op.  No reentrancy, no scheduler
; awareness — fits cleanly into the current single-task kernel.
;
; The trampoline pattern is the one net_dispatch.s uses too: a
; 5-byte JSL/RTL cell in writable kernel-bank .text whose operand we
; patch per dispatch.  The 65816 has no `JSL [dp],Y` mode, hence the
; self-modifying step.
;==============================================================================

                MX      %00

;------------------------------------------------------------------------------
; _Chardev_RegisterInternal - register a chardev whose name + ops are in
; the kernel bank.
;
; In:   MX %00.  DBR=kernel-bank ($02 = assembly ORG).
;       X = kernel-bank ptr to NUL-terminated name (up to 15 chars).
;       A = COPS_* offset within the kernel bank (low 16 of long pointer; the
;           bank byte is captured live via _BANKK for built-in core chardevs).
;       Y.lo = minor (opaque byte passed back to ops on every dispatch).
;       Y.hi = CD_Flags (CDF_*).  ZERO FOR EVERY CALLER THAT PREDATES IT, which
;           is what made this the cheap place to put it: the routine already
;           discarded the high byte, so `LDY #minor' still means "no flags".
; Out:  C=1, A.lo = chardev idx (0..CHARDEV_MAX-1).
;       C=0, A = ENOSPC if the registry is full.
; Clobbers: A, X, Y.
;------------------------------------------------------------------------------
_Chardev_RegisterInternal ENT
                MX      %00
                PHP
                ; --- Save inputs into static scratch ---
                STA     _cdRegArgOpsLo
                SEP     #$20
                MX      %10
                _BANKK
                STA     _cdRegArgOpsBank
                TYA
                STA     _cdRegArgMinor
                REP     #$20                    ; the FLAGS are Y's HIGH byte, so
                MX      %00                     ;   reading them needs 16 bits
                TYA
                XBA
                SEP     #$20
                MX      %10
                STA     _cdRegArgFlags

                ; --- Slot check ---
                LDA     _chardev_count
                CMP     #CHARDEV_MAX
                BCC     @cri_haveSlot
                ; Full.
                REP     #$30
                MX      %00
                PLP
                LDA     #ENOSPC
                CLC
                RTS

@cri_haveSlot
                STA     _cdRegIdx               ; new entry idx

                ; --- entry_off = idx * 24 (16-bit) ---
                REP     #$20
                MX      %00
                LDA     _cdRegIdx
                AND     #$00FF
                ASL     A                       ; *2
                ASL     A                       ; *4
                ASL     A                       ; *8
                STA     _cdRegEntryOff
                ASL     A                       ; *16
                CLC
                ADC     _cdRegEntryOff          ; *24
                STA     _cdRegEntryOff

                ; --- Copy name into _chardev_table[entry_off + CD_Name] ---
                ; Use X for the source ptr (caller-provided, kernel-bank) and
                ; Y as the dst byte index (entry_off + CD_Name + i).
                ; Write byte 0 (CD_NameLen) after we know the length.
                SEP     #$20
                MX      %10
                LDY     _cdRegEntryOff          ; ... +0 byte; lo byte only fits
                ; Y is now (entry_off & $FF).  But _cdRegEntryOff fits in
                ; 9 bits (max 15*24=360), so we need 16-bit Y.  Re-do.
                REP     #$10
                MX      %00
                LDY     _cdRegEntryOff
                INY                             ; Y = entry_off + CD_Name (= +1)
                SEP     #$20
                MX      %10
@cri_copy
                LDA:    $0000,X                 ; FORCE ABS — without `:`
                                                ; Merlin silently folds to dp,X
                                                ; (per feedback_merlin32_force_abs_and_byte_stores)
                                                ; which reads $00:(X&FF), trashing
                                                ; the read.  DBR=kernel-bank abs,X
                                                ; reads from kernel-bank:X correctly.
                BEQ     @cri_copyDone
                STA     [_cdTablePtr],Y         ; -> heap table (entry+CD_Name+i)
                INX
                INY
                ; Cap at 15 chars: Y wraps to entry_off + CD_Name + 15
                ; i.e. _cdRegEntryOff + 16; break before storing the 16th.
                PHA
                REP     #$20
                MX      %00
                TYA
                SEC
                SBC     _cdRegEntryOff
                CMP     #16                     ; CD_Name + max len
                SEP     #$20
                MX      %10
                PLA                             ; restore A (just-stored char)
                BCC     @cri_copy
@cri_copyDone
                ; CD_NameLen = (final Y) - entry_off - CD_Name (= -1)
                REP     #$20
                MX      %00
                TYA
                SEC
                SBC     _cdRegEntryOff
                SEC
                SBC     #1                      ; subtract CD_Name (=1)
                SEP     #$20
                MX      %10
                LDY     _cdRegEntryOff          ; CD_NameLen lives at byte 0
                STA     [_cdTablePtr],Y

                ; --- Write ops triple at CD_OpsLo (=16), CD_OpsBank (=18), CD_Minor (=19) ---
                REP     #$20
                MX      %00
                LDA     _cdRegEntryOff
                CLC
                ADC     #CD_OpsLo
                TAY                             ; Y = entry_off + CD_OpsLo
                LDA     _cdRegArgOpsLo
                STA     [_cdTablePtr],Y         ; 16-bit ops lo
                INY
                INY                             ; Y = entry_off + CD_OpsBank
                SEP     #$20
                MX      %10
                LDA     _cdRegArgOpsBank
                STA     [_cdTablePtr],Y
                INY                             ; Y = entry_off + CD_Minor
                LDA     _cdRegArgMinor
                STA     [_cdTablePtr],Y

                ; --- ...and CD_Flags, which is NOT adjacent ---
                ; CD_OpenCount and CD_TtyOff sit between CD_Minor and CD_Flags.
                ; The offset is recomputed rather than walked with four INYs,
                ; which would read as a claim that the fields are neighbours.
                REP     #$20
                MX      %00
                LDA     _cdRegEntryOff
                CLC
                ADC     #CD_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     _cdRegArgFlags
                STA     [_cdTablePtr],Y

                ; --- Bump count, return idx ---
                INC     _chardev_count

                REP     #$30
                MX      %00
                PLP
                LDA     _cdRegIdx
                AND     #$00FF
                SEC
                RTS

;------------------------------------------------------------------------------
; _Chardev_LookupBank - look a device up by a NUL-terminated name in ANOTHER
; BANK.  UFS 1.7d I3.
;
; THE BODY WAS IN THE KSVC DISPATCHER and now has two callers, which is why it
; moved here beside the routine it wraps.  KSVC_CDLOOKUP serves a MODULE; the
; far kernel bank has no SYS_KCALL and reaches the core through _FarSh_* shims
; instead, so its own kc_cdlookup needed the same copy-then-look-up and would
; have been a second copy of this loop.
;
; WHY IT COPIES AT ALL.  _Chardev_LookupSuffix takes a KERNEL-bank pointer and
; an explicit length; a caller in another bank has neither to give.  So the
; name is read with a long pointer -- the only way to reach another bank
; without changing DBR out from under the registry -- into a kernel-bank
; buffer, and its length is measured on the way.
;
; BOUNDED BY THE REGISTRY'S OWN LIMIT.  CD_Name holds fifteen characters, so a
; name longer than that cannot match anything and the copy stops rather than
; running off the buffer.  A caller passing an unterminated string gets ENOENT,
; not a wander through its own bank.
;
; In:   MX %00.  DBR = kernel bank.  D = the KERNEL's page (_cdKcNamePtr is a
;       direct-page cell -- see include/dpmap.s -- so both callers arrive with
;       D already there).
;       A = name offset, Y.lo = the name's bank.
; Out:  C=1, A.lo = idx on match.  C=0, A = ENOENT on miss.
; Clobbers: A, X, Y, _cdKcNamePtr, _cdKcName.
;------------------------------------------------------------------------------
_Chardev_LookupBank ENT
                MX      %00
                STA     _cdKcNamePtr
                SEP     #$20
                MX      %10
                TYA
                STA     _cdKcNamePtr+2
                LDY     #0
@clb_copy       LDA     [_cdKcNamePtr],Y
                BEQ     @clb_done               ; the NUL ends it
                STA     |_cdKcName,Y
                INY
                CPY     #CDKCNAME_MAX
                BCC     @clb_copy
                ; Fifteen characters and no NUL: longer than any registered
                ; name, so it cannot match.  Fall through with Y = 15, which
                ; LookupSuffix will simply fail to find.
@clb_done       REP     #$30
                MX      %00
                TYA
                AND     #$00FF
                BEQ     @clb_empty              ; an empty name matches every
                                                ;   suffix; refuse it here
                TAY                             ; Y.lo = length
                LDX     #_cdKcName              ; X = kernel-bank pointer
                JMP     _Chardev_LookupSuffix   ; its C/A convention is ours
@clb_empty      LDA     #ENOENT
                CLC
                RTS

;------------------------------------------------------------------------------
; _Chardev_LookupSuffix - find chardev whose CD_Name matches a given suffix.
;
; In:   MX %00.  DBR=kernel-bank ($02 = assembly ORG).
;       X = kernel-bank ptr to suffix (no NUL term; length given explicitly).
;       Y.lo = suffix length (1..15).
; Out:  C=1, A.lo = idx on match.
;       C=0, A = ENOENT on miss.
; Clobbers: A, X, Y.
;------------------------------------------------------------------------------
_Chardev_LookupSuffix ENT
                MX      %00
                PHP
                STX     _cdLkpSuffixPtr
                TYA
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     _cdLkpSuffixLen
                STZ     _cdLkpIdx

@cls_loop
                LDA     _cdLkpIdx
                CMP     _chardev_count
                BCC     @cls_try
                ; Exhausted — miss.
                REP     #$30
                MX      %00
                PLP
                LDA     #ENOENT
                CLC
                RTS

@cls_try
                ; entry_off = idx * 24
                REP     #$30
                MX      %00
                LDA     _cdLkpIdx
                AND     #$00FF
                ASL     A                       ; *2
                ASL     A                       ; *4
                ASL     A                       ; *8
                STA     _cdLkpEntryOff
                ASL     A                       ; *16
                CLC
                ADC     _cdLkpEntryOff          ; *24
                STA     _cdLkpEntryOff

                ; Length compare.
                SEP     #$20
                MX      %10
                LDY     _cdLkpEntryOff
                LDA     [_cdTablePtr],Y         ; CD_NameLen
                CMP     _cdLkpSuffixLen
                BNE     @cls_next

                ; Byte-compare CD_Name vs suffix for _cdLkpSuffixLen bytes.
                ; (X = suffix base; we'll index with Y from 0..len-1.)
                LDA     _cdLkpSuffixLen
                STA     _cdLkpTmp               ; loop counter, byte
                LDX     _cdLkpSuffixPtr
                REP     #$10
                MX      %00
                LDY     _cdLkpEntryOff
                INY                             ; Y = entry_off + CD_Name
@cls_cmp
                SEP     #$20
                MX      %10
                LDA     _cdLkpTmp
                BEQ     @cls_match              ; ran out of bytes — all matched
                DEC     _cdLkpTmp
                LDA:    $0000,X                 ; suffix[i] (DBR=kernel-bank) —
                                                ; force-abs to dodge dp,X folding
                CMP     [_cdTablePtr],Y         ; entry name[i]
                BNE     @cls_next
                INX
                REP     #$10
                MX      %00
                INY
                BRA     @cls_cmp

@cls_match
                ; Found!  Return idx.
                REP     #$30
                MX      %00
                PLP
                LDA     _cdLkpIdx
                AND     #$00FF
                SEC
                RTS

@cls_next
                SEP     #$20
                MX      %10
                INC     _cdLkpIdx
                ; Stay M=8 into @cls_loop.  The bounds check there is a BYTE
                ; compare (_chardev_count is DS 1; idx is 0..15).  The old
                ; REP #$30 here returned to @cls_loop at M=16, so iter 2+ read
                ; _chardev_count as a 16-bit word — count $03 + its neighbour
                ; byte ($1103 in one layout) — and _cdLkpIdx with a stale high
                ; byte, bogus-bounding the loop.  Result: every chardev past
                ; idx 0 missed (the /dev/bpf0 "cannot open" wedge; /dev/null at
                ; idx 0 matched on iter 1 so it never tripped this).  @cls_try
                ; does its own REP #$30 for the entry_off math + masks idx.
                BRA     @cls_loop

;------------------------------------------------------------------------------
; _Chardev_Dispatch - internal helper.
;
; Loads chardev_table[idx].CD_Ops* into the JSL trampoline operand, then
; JSLs through it.  The caller has already arranged whatever the op
; expects on the stack / registers.
;
; In:   MX %00.  DBR=kernel-bank ($02 = assembly ORG).
;       A.lo = chardev idx (0..count-1; not bounds-checked here).
;       X    = COPS_* offset (0, 3, 6, 9, 12, or 15).
;       Other regs / stack as the op expects.
; Out:  Whatever the op returned (typically C=1 ok / C=0 + A=errno).
; Clobbers: per-op; this helper preserves nothing.
;------------------------------------------------------------------------------
_Chardev_Dispatch ENT
                MX      %00
                PHX                             ; preserve COPS_* offset across math

                ; --- entry_off = idx * 24 ---
                AND     #$00FF
                ASL     A                       ; *2
                ASL     A                       ; *4
                ASL     A                       ; *8
                STA     _cdDispEntryOff
                ASL     A                       ; *16
                CLC
                ADC     _cdDispEntryOff         ; *24
                STA     _cdDispEntryOff

                ; --- Cache CD_OpsLo / CD_OpsBank / CD_Minor for this idx ---
                LDA     _cdDispEntryOff
                CLC
                ADC     #CD_OpsLo
                TAY                                     ; Y = entry_off + CD_OpsLo
                LDA     [_cdTablePtr],Y                 ; module COPS base lo16
                STA     _cdDispOpsLo
                INY
                INY                                     ; Y = entry_off + CD_OpsBank
                SEP     #$20
                MX      %10
                LDA     [_cdTablePtr],Y                 ; module bank
                STA     _cdDispOpsBank
                INY                                     ; Y = entry_off + CD_Minor
                LDA     [_cdTablePtr],Y                 ; minor
                STA     _cdDispMinor
                REP     #$30
                MX      %00

                ; --- Patch _cdTrampReadOp to read module's COPS_*+X bytes ---
                ; operand_lo16 = _cdDispOpsLo + COPS_* offset (on stack)
                LDA     _cdDispOpsLo
                CLC
                ADC     1,S                     ; + COPS_* offset (PHX'd)
                STA     |_cdTrampReadOp+1       ; STA | (DBR-rel), NOT STAL: under
                                                ; reloc _cdTrampReadOp is a $20
                                                ; kernel-bank cell but STAL bakes
                                                ; $02 -> patch missed the live cell,
                                                ; JSR ran LDAL $000000 -> handler
                                                ; addr read as $00:0000 -> JSL
                                                ; $00:0000 -> wild jump (every
                                                ; chardev open).  DBR=$20 here.
                SEP     #$20
                MX      %10
                LDA     _cdDispOpsBank
                STA     |_cdTrampReadOp+3
                REP     #$30
                MX      %00

                ; Read target lo16 (16-bit LDAL).
                JSR     _cdTrampReadOp
                STAL    _cdTrampJSL+1           ; (bank-0 gateway cell — STAL is OK)

                ; JSL TARGET BANK = _cdDispOpsBank (the live bank where the ops
                ; vtable AND its handlers live, captured at registration via
                ; _BANKK).  Do NOT read the vtable's stored ^ bank byte: it is the
                ; build-time bank ($02 for built-ins) and is WRONG under relocation
                ; — JSLing through it lands in the empty $02 -> BRK instead of the
                ; handler (regression: chardev_dispatch_reloc).  The lo16 above is
                ; bank-relative within the ops bank, so it is already correct.
                SEP     #$20
                MX      %10
                LDA     _cdDispOpsBank
                STAL    _cdTrampJSL+3
                REP     #$30
                MX      %00

                PLX                             ; restore (caller doesn't need X back,
                                                ; but we balance the PHX)

                ; The module's op gets:
                ;   Y = minor byte (zero-extended)
                ;   A = arg byte (zero-extended) — meaningful for
                ;       COPS_Write (the byte to send); ignored by the
                ;       other ops.  Sourced from _cdArgByte which the
                ;       kernel-side caller sets up before the dispatch.
                ;   X = flag (VFS_IO_NDELAY today), from _cdArgFlag.
                ;
                ; X WAS NOT DELIVERED BEFORE, though include/chardev.s had said
                ; `X = flag' on COPS_Open and COPS_Close since the slots were
                ; declared.  What actually arrived was the COPS_* offset this
                ; routine had just finished with -- an accident of the PLX
                ; above -- and no op read it, which is why nothing broke and
                ; why the comment survived.  It is the second entry in that
                ; header describing an ABI that was never built; the frame
                ; table above COPS_Open is the first.
                ;
                ; ZEROED AS IT IS CONSUMED, so a caller that passes no flag
                ; gets 0 (blocking) rather than the previous caller's.  The
                ; alternative -- a STZ in each of the six dispatch entry
                ; points -- is five more places to forget.
                LDX     _cdArgFlag
                STZ     _cdArgFlag
                LDA     _cdDispMinor
                AND     #$00FF
                TAY
                LDA     _cdArgByte
                AND     #$00FF

                JSL     _cdTrampJSL
                RTS

;------------------------------------------------------------------------------
; _cdTrampReadOp - 5-byte self-modifying LDAL/RTS cell.  M flag at JSR
; time selects 16-bit or 8-bit load.  Lives in writable kernel-bank .text.
;------------------------------------------------------------------------------
_cdTrampReadOp  DFB     $AF,$00,$00,$00         ; LDAL <addr>
                DFB     $60                     ; RTS

;------------------------------------------------------------------------------
; _cdTrampJSL - 5-byte self-modifying JSL/RTL cell.  Patched per dispatch.
;------------------------------------------------------------------------------
; _cdTrampJSL is now a bank-0 FGX_INTVEC gateway cell (include/memmap.s): the
; `JSL _cdTrampJSL` + STAL patches target a fixed bank-0 address that survives
; kernel relocation; its $22/$6B opcodes are written once by _JT_Init.

;------------------------------------------------------------------------------
; Op-specific dispatch entry points.  Each pre-loads X with the COPS_*
; offset, then jumps into _Chardev_Dispatch.  Callers (slice 1.3:
; _Sys_Open / Read / Write / Close / Ioctl) arrange their op-specific
; stack frame before the JSR.
;
; In all of these: A.lo = chardev idx; rest per the op's stack/reg ABI.
;------------------------------------------------------------------------------
; OPEN AND CLOSE ARE NOT SYMMETRIC, and BSD is why.  openi() calls d_open on
; EVERY open; closei() calls d_close only once nothing else holds the device
; (sys_inode.c: it scans the file table for another inode on the same i_rdev and
; returns early if it finds one).  So the count below gates only the close.
;
; apple/fgx#76: FGX fired the Close op on the last close of a FILE HANDLE, which
; is a different thing.  Two separate open(2)s produce two FCBs each with
; refcount 1, so closing either ran the driver's device teardown while the other
; was still open -- reachable today on the pty slave, where _PtyS_Close clears
; PTYF_SOPEN and the master's next write then fails EIO.
_Chardev_Open   ENT
                MX      %00
                PHA                             ; chardev idx
                ; A NODE WHOSE DRIVER IS NOT HERE ANSWERS ENXIO, as BSD's
                ; cdevsw does for a major with no driver (`nodev').  A /dev
                ; node is made with a fixed number, and the driver that owns it
                ; may not have registered on this machine -- a serial channel
                ; AppleTalk owns, a module not loaded -- so its slot is empty
                ; (CD_NameLen 0), and a dispatch through it would jump through
                ; a zero operations pointer.
                JSR     _Cd_CountPtr            ; Y = entry_off + CD_OpenCount
                TYA
                SEC
                SBC     #CD_OpenCount
                TAY                             ; Y = entry_off + CD_NameLen
                SEP     #$20
                MX      %10
                LDA     [_cdTablePtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @co_registered
                PLA
                LDA     #ENXIO
                CLC
                RTS
                ; THE OPEN COUNTS ONLY ONCE THE DRIVER HAS AGREED.  2.11BSD
                ; vn_open (sys/vfs_vnops.c) answers an openi() error with
                ; `goto lbad' and iput()s the inode, so a refused open leaves
                ; nothing for closei()'s scan to find.  Counted before the
                ; dispatch, a refusal (klog's EBUSY, bpf's) leaked a count, the
                ; next close was no longer the last, and the driver's close
                ; never ran again (apple/fgx#462).  Open ops take A and the
                ; FCB globals, never stack arguments, so this is a JSR.
@co_registered  PLA
                PHA
                LDX     #COPS_Open
                JSR     _Chardev_Dispatch       ; C=0 + A=errno: refused
                BCC     @co_out
                PHA                             ; the op's answer
                LDA     3,S
                JSR     _Cd_CountPtr            ; Y = entry_off + CD_OpenCount
                SEP     #$20
                MX      %10
                LDA     [_cdTablePtr],Y
                INC                             ; one more live open
                STA     [_cdTablePtr],Y
                REP     #$20
                MX      %00
                PLA
                SEC
@co_out         PLX                             ; drop the idx; C and A kept
                RTS

; The driver's Close runs ONLY on the last open of the device.  On any earlier
; close the slot is still freed by the caller -- this returns success without
; dispatching, exactly as closei()'s early `return(0)` does.
_Chardev_Close  ENT
                MX      %00
                PHA                             ; chardev idx
                JSR     _Cd_CountPtr
                SEP     #$20
                MX      %10
                LDA     [_cdTablePtr],Y
                BEQ     @cc_last                ; already 0: never counted (a
                                                ;   device opened before this
                                                ;   accounting existed, or a
                                                ;   double close).  Fail safe by
                                                ;   running the teardown rather
                                                ;   than skipping it forever.
                DEC
                STA     [_cdTablePtr],Y
                BEQ     @cc_last
                ; Someone else still has it open.
                REP     #$20
                MX      %00
                PLA
                SEC                             ; closei()'s `return(0)`
                RTS
@cc_last        REP     #$20
                MX      %00
                PLA
                LDX     #COPS_Close
                JMP     _Chardev_Dispatch

; _Chardev_SetTtyOff - record which _ttyTable entry this chardev IS.
;
; A = chardev idx, Y = tty byte offset.  MX %00.
;
; STORED AS OFFSET+1, so that the stored zero means "no line recorded" and
; nothing else.  It used to store the offset raw with 0 doubling as the "not a
; tty" sentinel, which is unambiguous for every line EXCEPT the one whose
; offset is 0 -- the console.  That cost nothing while the console was
; DTYPE_CONSOLE and never reached the background-output gate; apple/fgx#121
; gave it a node, and the gate then skipped tty[0] silently.  Measured by
; contostop: LTOSTOP armed, a background child on its own controlling terminal,
; and the write sailed through.
; The background-output gate (apple/fgx#74) reads it; see CD_TtyOff.
;
; CORE-ONLY, DELIBERATELY.  A KSVC for this was written and then removed before
; it shipped: every tty chardev in the system -- both pty slaves and both
; virtual consoles -- is registered right here in _Chardev_InitBuiltins, so the
; service had no caller.  Adding one would have baked a jump-table number for a
; module that does not exist, which is the same "knob nothing sets" shape
; apple/fgx#74 is about.  The KSVC numbers are append-only, so the day a MODULE
; registers a tty chardev, adding the service then costs exactly what it costs
; now.
_Chardev_SetTtyOff MX   %00
                PHY                             ; tty offset
                JSR     _Cd_EntryOff            ; A = entry_off
                CLC
                ADC     #CD_TtyOff
                TAY
                PLA                             ; tty offset back
                INC                             ; stored as offset+1
                STA     [_cdTablePtr],Y
                RTS

; _Chardev_TtyOff - A = chardev idx -> is this chardev a tty line, and which?
;
; Out: C=1 + A = its _ttyTable byte offset; C=0 if it is not a tty.
; MX %00.  Clobbers Y.
;
; THE CARRY IS THE ANSWER, not a magic value in A.  Returning "0 means not a
; tty" cannot describe tty[0], whose offset is 0 -- see _Chardev_SetTtyOff.
_Chardev_TtyOff ENT
                MX      %00
                JSR     _Cd_EntryOff
                CLC
                ADC     #CD_TtyOff
                TAY
                LDA     [_cdTablePtr],Y
                BEQ     @cto_notTty             ; nothing recorded
                DEC                             ; stored as offset+1
                SEC
                RTS
@cto_notTty     CLC
                RTS

; _Chardev_IsRecord - A = chardev idx -> C=1 if this device answers a read with
; one WHOLE RECORD, C=0 if it is per-byte.  MX %00.  Clobbers A, Y.
;
; THE DEVICE ANSWERS THIS, NOT THE DESCRIPTOR, and that is the point of the
; routine.  _Sys_Read used to read FCB_FL_RECORD off the FCB, which the driver
; had set through [_fcbPtr] at open -- an FCB its signature never mentions, and
; on the /dev route the wrong one, because the namei walk lies between
; _Fcb_Alloc and the driver's open (apple/fgx#198).  Reno keeps the same fact in
; pt_ioctl[minor(dev)], keyed by the device, and its ptcopen ignores the flag
; argument it is handed.
;
; NOT BOUNDS-CHECKED, like its neighbours here: the caller has an index that
; came out of the registry in the first place.
;
; THE READ IS 8-BIT ON PURPOSE.  CD_Flags is the LAST byte of a record, so a
; 16-bit load at the last slot reads one byte past the table.
_Chardev_IsRecord ENT
                MX      %00
                JSR     _Cd_EntryOff
                CLC
                ADC     #CD_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_cdTablePtr],Y
                AND     #CDF_RECORD
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @cir_no
                SEC
                RTS
@cir_no         CLC
                RTS

; _Cd_EntryOff - A = chardev idx -> A = idx * CD_REC_STRIDE.  MX %00.
_Cd_EntryOff    MX      %00
                AND     #$00FF
                ASL     A
                ASL     A
                ASL     A
                STA     _cdDispEntryOff
                ASL     A
                CLC
                ADC     _cdDispEntryOff         ; idx * 24
                RTS

; _Cd_CountPtr - Y = entry_off + CD_OpenCount for the chardev idx in A.
; Preserves A.  MX %00 in, MX %00 out (index regs 16-bit).
_Cd_CountPtr    MX      %00
                PHA
                JSR     _Cd_EntryOff
                CLC
                ADC     #CD_OpenCount
                TAY
                PLA
                RTS

;------------------------------------------------------------------------------
; _Chardev_TtyIdx - A.lo = chardev idx -> A = the TTY INDEX for that device.
;
; THIS IS FGX'S cdevsw[].d_ttys.  BSD finds a tty driver's `struct tty *' with
; `&cdevsw[major(dev)].d_ttys[minor(dev)]'; FGX has one major and a runtime
; registry, so the same fact lives in the registry entry.  apple/fgx#108's tty
; bank asks for it through _FarSh_CdTtyIdx.
;
; _Chardev_TtyOff above is the registry read and stays the authority on it;
; this adds the two things a cross-bank caller needs and it does not have.
;
; ONE: A BOUNDS CHECK.  _Chardev_TtyOff indexes the table from whatever it is
; given, so an index past the end reads plausible answers out of whatever
; follows.  Its callers are all in-kernel and pass indices they just looked up;
; a caller in another bank is exactly the one that might not.
;
; TWO: THE DIVISION, WHICH IS WHERE TTY_SIZE STAYS.  The caller is kernel C,
; which cannot include an assembly header, so handing it a byte offset would
; make it restate a stride that a DUM block computes -- a copy that goes wrong
; the first time a field is added to _ttyTable.
;
; In: A.lo = idx, MX %00.
; Out: C=1 + A = tty index 0..NTTY-1, or A = $FFFF for "not a tty";
;      C=0 + A = ENODEV when the index names no device at all.
;------------------------------------------------------------------------------
_Chardev_TtyIdx ENT
                MX      %00
                AND     #$00FF
                CMP     #CHARDEV_MAX
                BCS     @cti_bad
                JSR     _Chardev_TtyOff         ; C=1 + A = byte offset
                BCC     @cti_notty
                ; Offset -> index.  A COMPARE-AND-SUBTRACT LADDER, not a shift:
                ; TTY_SIZE is not a power of two, and with NTTY entries the
                ; ladder is both smaller than a divide routine and exact.
                LDX     #0
@cti_loop       CMP     #TTY_SIZE
                BCC     @cti_done
                SEC
                SBC     #TTY_SIZE
                INX
                CPX     #NTTY
                BCC     @cti_loop
                BRA     @cti_notty              ; past the end of _ttyTable
@cti_done       ; A = the remainder.  IT MUST BE ZERO: a CD_TtyOff that is not
                ; a whole number of entries is a registration that wrote
                ; something other than an entry base, and rounding it down
                ; would hand back a plausible tty.
                CMP     #0
                BNE     @cti_notty
                TXA
                SEC
                RTS
@cti_notty      LDA     #$FFFF
                SEC
                RTS
@cti_bad        LDA     #ENODEV
                CLC
                RTS

;==============================================================================
; _Chardev_Bulk - cdevsw's d_read / d_write, dispatched from ONE kernel arm.
;
; apple/fgx#108 T2.2b.  spec_vnops' VCHR arm is the caller: it has a uio, and a
; RECORD-MODE driver is exactly the one that can use a uio whole.  Its read
; fills a buffer and answers a COUNT, which the per-byte loop reads as one
; byte's VALUE -- apple/fgx#198's silent half.
;
; EVERYTHING HAPPENS ON THIS SIDE, and that is the correction to the first
; attempt.  That one exported a scraped shim and had the MODULE do the
; dispatch, on the belief that a uio pointer could not fit the register KSVC
; ABI.  It fits exactly: offset (16) + bank (8) + index (8) is A + Y, the way
; kc_rtcframe and kc_blkio already pack.  Doing it here means the bounds check,
; the absent-slot test and the dispatch are in ONE place, the module needs no
; scraped address, and -- the defect that actually killed the first attempt --
; the kernel DIRECT PAGE is already correct, because a KSVC arm runs with it.
; [_cdTablePtr] is a DP long pointer; the first attempt set DBR and not D, so
; the absent-slot test read fcc's register file and every slot looked live.
;
; In:  A = uio offset, Y = (uio bank << 8) | chardev idx, X = COPS_* offset.
;      MX %00, kernel DBR and kernel DP.
; Out: A = (status << 8) | value:
;        status 0  DO NOT LOOP; the low byte is the errno, 0 for success.
;                  Usually the op ran and this is its answer.  It is also the
;                  answer when a RECORD device has no d_read -- see the note at
;                  @cbk_perbyte, where the errno is EIO and no op ran.  The two
;                  are one status because the caller does the same thing with
;                  both, and a caller that could tell them apart would have
;                  nothing to do with the difference.
;        status 1  THIS DEVICE HAS NO BULK OP; the caller uses its own loop
;        status 2  bad device index; the low byte is ENODEV
;      C=1 always -- the status is in A, not the carry.
;
; THREE OUTCOMES AND ONE 16-BIT RETURN, which is kc_cdread's idiom for the same
; reason.  The first attempt used ENODEV as the "no bulk op" answer and that is
; NOT SAFE: tty_conf.c's nodev() returns ENODEV, and the line-discipline switch
; is precisely where T3 routes tty bulk reads -- a real ENODEV would have been
; read as "use your own loop".  A status byte cannot collide with an errno.
;
; THE OP'S FRAME, pushed here and dropped here.  EIGHT BYTES OF RETURN ADDRESS
; SIT ABOVE IT, so the op reads its arguments at ODD offsets:
;      9,S uio offset   11,S uio bank   13,S flag
; The eight are, from the op's own entry: the bank-0 gateway cell's JSL (3),
; _Chardev_Dispatch's JSL through that cell (3), and this routine's JSR into
; _Chardev_Dispatch (2).  COUNT THEM RATHER THAN ASSUMING TWO -- the frame
; reaches the op through three calls, not one, and a shim that guessed the
; depth is what the first cut of this got wrong.
;
; EXERCISED NOW, by klog.mod's d_read: klogprobe drains real bytes through it,
; which proves 9,S and 11,S name the uio, and its FIONBIO arm returns EAGAIN,
; which proves 13,S carries the flag.  The count was read off three call
; instructions before anything had watched an op fetch its argument; it has now.
;
; AND AN OP CANNOT CHECK THEM FOR ITSELF -- measured, not assumed.  A d_read is
; handed a READ uio by definition, so `refuse unless uio_rw reads as UIO_READ'
; looks like a frame check; it is not one.  A trial arm on /dev/null was given
; the offset deliberately wrong, by two, and STAYED GREEN: the pointer it built
; was wild, and the wild read returned zero, which is UIO_READ.  Validating a
; pointer by dereferencing it validates nothing.
;
; ONLY AN OP THAT MOVES DATA SOMEONE ELSE OBSERVES can settle these, and
; klogprobe is that probe: it reads the ring back through dmesg(2) and requires
; what /dev/klog handed over to be a prefix of it, so a wrong offset here cannot
; pass as a plausible pointer.  The pty master's d_read still has no such
; coverage of its own.
;
; Plus the dispatch's usual Y = minor.  `flag' is 0 today and reserved for
; IO_NDELAY, which is where a record-mode read must learn non-blocking from --
; NOT from [_fcbPtr], which is apple/fgx#198's other half.
;
; NOTHING IS HELD IN A STATIC ACROSS THE DISPATCH.  _cdBulkArg is written and
; read entirely before it, because the op can BLOCK -- _PtyM_Write sleeps on a
; full pty ring -- and apple/fgx#89 is what a kernel singleton costs when
; another task reaches it during that sleep.  The frame is on the stack for the
; same reason.
;==============================================================================
_Chardev_Bulk   ENT
                MX      %00
                STY     _cdBulkArg              ; (uio bank << 8) | idx | ioflag

                ; THE IOFLAG RIDES IN THE INDEX BYTE'S TOP BIT, CDIDX_NDELAY,
                ; which is not VFS_IO_NDELAY's own value -- see the EQU in
                ; include/chardev.s, and the ERR at the end of this routine,
                ; which pins the shift below to both constants.  There is no
                ; register left to carry it: A is the uio offset, Y's high byte
                ; is the uio bank and its low byte the index, and X is the
                ; service number the dispatcher compares in full.
                ;
                ; SPLIT IT OFF BEFORE ANYTHING READS THE INDEX, so every use
                ; below -- the bounds test, the slot lookup, the dispatch --
                ; sees exactly what it saw before this encoding existed.
                ;
                ; AFTER THE PUSHES, NOT BEFORE THEM.  A is the uio OFFSET on
                ; entry and the split needs A; doing it first destroyed the
                ; offset and the device was handed a uio at whatever address
                ; the mask left behind.  `echo > /dev/./console' wrote nothing
                ; and said so by printing nothing, which is the shape of it.
                PHX                             ; COPS_* offset, wanted after
                PHA                             ; uio offset, wanted after
                LDA     _cdBulkArg
                AND     #CDIDX_NDELAY
                LSR                             ; $80 -> $10.  The ERR below
                LSR                             ;   pins this shift to
                LSR                             ;   CDIDX_NDELAY/8 = VFS_IO_NDELAY
                STA     _cdBulkFlag
                LDA     _cdBulkArg
                AND     #$FF7F                  ; the uio bank in the high byte
                STA     _cdBulkArg              ;   is untouched
                AND     #$00FF
                JSR     _SyTty_Resolve          ; /dev/tty -> the caller's line
                SEP     #$20
                MX      %10
                STA     _cdBulkArg              ; the idx byte only
                REP     #$20
                MX      %00

                ; --- the index must name a real device -------------------
                ; _Chardev_Dispatch is documented "not bounds-checked", and an
                ; absent-slot test does not cover this: v_rdev is an ON-DISK
                ; value, so an out-of-range one indexes past the 384-byte heap
                ; table into bytes unlikely to be zero -- a wild JSL the slot
                ; test would wave through.
                ;
                ; IT IS THE SECOND LINE NOW, NOT THE FIRST.  With the ioflag
                ; sharing the byte, an index that reaches its bit arrives
                ; indistinguishable from a smaller one with NDELAY set, so this
                ; test cannot catch that band on its own.
                ; kc_chardev.s refuses anything >= CHARDEV_MAX before it
                ; encodes, which is strictly earlier and stricter than the < 256
                ; test it replaced; this remains as the guard against a module
                ; that does not.
                LDA     _cdBulkArg
                AND     #$00FF
                CMP     #CHARDEV_MAX
                BCC     @cbk_inrange
                PLA
                PLX
                LDA     #$0200+ENODEV           ; status 2
                SEC
                RTS

@cbk_inrange    ; --- is the slot filled? ---------------------------------
                ; BOTH HALVES ARE TESTED.  A slot whose lo16 is 0 but whose
                ; bank is not is a real routine at offset 0 of its bank, and
                ; vfs.mod's own symbols start at $0000 because it is first in
                ; its bank -- testing lo16 alone would call such an op absent
                ; forever.
                JSR     _Cd_OpsSlot             ; A.lo = idx, X = COPS_* ->
                                                ;   A = lo16, Y = bank
                STY     _cdBulkSlotBk
                ORA     _cdBulkSlotBk
                BNE     @cbk_have
                PLA                             ; uio offset -- nothing to
                PLX                             ;   dispatch, so both are spent

                ; --- A RECORD DEVICE WITH NO d_read IS REFUSED, NOT LOOPED ---
                ; Status 1 tells the caller "run your own per-byte loop", and
                ; for a record driver that instruction is apple/fgx#198's
                ; SILENT half: bpf_read fills a whole buffer from
                ; _Sys_RdBufOff / _Sys_RdMax / _Sys_CallerBank -- syscall-layer
                ; singletons no vnode caller sets -- and answers a COUNT, which
                ; the loop stores as one byte's VALUE.  On the /dev route those
                ; singletons name whatever the last read(2) named, so the copy
                ; lands in a stranger's buffer and the read reports success.
                ;
                ; UPSTREAM HAS NO SUCH FALLBACK TO GET WRONG.  Reno's VCHR arm
                ; is one unconditional call -- `error =
                ; (*cdevsw[major(vp->v_rdev)].d_read)(vp->v_rdev, uio, ioflag)'
                ; (4.3BSD-Reno kern/spec_vnops.c:178) -- so a driver with no
                ; read names enodev in its row and the caller gets an errno.
                ; FGX's status 1 is the addition, and this is the case it must
                ; not cover.  EIO is the answer _PtyS_Read already gives for
                ; the same situation (a driver that cannot serve this road).
                ;
                ; THE READ DIRECTION ONLY.  CDF_RECORD is a statement about
                ; read(2) -- one whole record per call -- and says nothing
                ; about writes: bpf_write is a one-line ENOTSUP and
                ; _PtyM_Write takes exactly one byte.  Refusing d_write here
                ; would break /dev writes to the pty master, which work.
                CPX     #COPS_DRead
                BNE     @cbk_perbyte
                LDA     _cdBulkArg
                AND     #$00FF
                JSR     _Chardev_IsRecord
                BCC     @cbk_perbyte
                LDA     #EIO                    ; status 0, value EIO
                SEC
                RTS
@cbk_perbyte    LDA     #$0100                  ; status 1: no bulk op
                SEC
                RTS

@cbk_have       PLA                             ; uio offset
                PLX                             ; COPS_* offset
                TAY                             ; park the offset in Y
                LDA     _cdBulkFlag             ; 8,S flag -- VFS_IO_NDELAY or 0.
                PHA                             ;   Reserved and hardcoded 0 until
                                                ;   apple/fgx#310 gave FNDELAY a
                                                ;   setter; the slot was always
                                                ;   here waiting for it.
                LDA     _cdBulkArg
                XBA
                AND     #$00FF
                PHA                             ; 6,S uio bank
                PHY                             ; 4,S uio offset
                LDA     _cdBulkArg
                AND     #$00FF                  ; A = idx, as every entry takes
                JSR     _Chardev_Dispatch

                ; --- the op's answer, then drop the frame ------------------
                ; The result moves to X FIRST so the carry is spent before TSC
                ; touches A: an errno is only meaningful while C=0, and TSC/TCS
                ; would clobber A with the stack pointer.
                BCS     @cbk_ok
                AND     #$00FF                  ; C=0: A = the op's errno
                BRA     @cbk_res
@cbk_ok         LDA     #0                      ; C=1: success
@cbk_res        TAX
                TSC
                CLC
                ADC     #6                      ; drop flag + bank + offset
                TCS
                TXA                             ; status 0, value in the low byte
                SEC
                RTS

; THE ENCODING'S TWO GUARDS.  The ioflag rides in CDIDX_NDELAY, a bit of the
; index byte, so two things must hold and neither is obvious from the code that
; depends on them.
;
;   1. AN INDEX MUST NOT REACH THE FLAG'S BIT.  Otherwise index 128 arrives as
;      "index 0, non-blocking" in a dispatch that would then call the wrong
;      driver -- which is exactly what raising CHARDEV_MAX past 16 did while
;      the flag sat in bit 4.  Integer division is the test: any CHARDEV_MAX
;      below the bit gives zero.
;
;   2. THE DECODE'S SHIFT MUST LAND ON VFS_IO_NDELAY.  _Chardev_Bulk shifts
;      CDIDX_NDELAY down by three to make the ioflag it passes on; move either
;      constant and the shift is silently the wrong distance.
;
; Merlin's ERR fires on a NON-ZERO expression.
                ERR     CHARDEV_MAX/CDIDX_NDELAY
                ERR     CDIDX_NDELAY/8-VFS_IO_NDELAY

;------------------------------------------------------------------------------
; _Cd_OpsSlot - A.lo = chardev idx, X = COPS_* offset -> A = the slot's lo16,
; Y = the slot's OWN third byte.
;
; Reads a vtable entry WITHOUT dispatching, so a caller can ask whether a device
; fills a slot.  Shares _cdTrampReadOp with the dispatcher rather than
; open-coding a second long load: one self-modifying cell, and therefore one
; place where the STA-versus-STAL trap that once cost every chardev open a wild
; jump can recur.
;
; Y IS THE SLOT'S THIRD BYTE, NOT THE VTABLE'S BANK, AND THE DIFFERENCE KILLED
; A BOOT.  A slot is three bytes -- `DFB <r,>r,^r' -- and an EMPTY one is
; `DFB 0,0,0', all three zero.  The record's CD_OpsBank is something else
; entirely: the LIVE bank the vtable was registered from, which is never zero.
; The first cut of this returned that, so the absent-slot test in _Chardev_Bulk
; ORed in a nonzero byte every time, called every empty slot filled, and JSLed
; to <live bank>:$0000 on the first bulk read -- before the console existed, so
; the machine went dark with no output at all.  Only kernel.ufsdevprobe saw it.
;
; The third byte is the BUILD-TIME bank (`^'), which _Chardev_Dispatch
; deliberately ignores when it JSLs, for the relocation reason its own comment
; gives.  It is read here for one question only: zero or not.
;
; CALLER MUST HOLD THE KERNEL DIRECT PAGE.  _cdTablePtr is a DP long pointer
; (include/dpmap.s), so a caller running on fcc's register file reads the table
; out of the compiler's scratch and gets plausible garbage.  That is exactly
; what broke T2.2b's first attempt.
;------------------------------------------------------------------------------
_Cd_OpsSlot     MX      %00
                AND     #$00FF
                PHX                             ; COPS_* offset
                JSR     _Cd_EntryOff            ; A = idx * CD_REC_STRIDE
                CLC
                ADC     #CD_OpsLo
                TAY
                LDA     [_cdTablePtr],Y         ; vtable base lo16
                STA     _cdDispOpsLo
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     [_cdTablePtr],Y         ; vtable bank
                STA     _cdDispOpsBank
                REP     #$30
                MX      %00
                PLA                             ; the COPS_* offset back
                CLC
                ADC     _cdDispOpsLo            ; A = the slot's own address
                TAX                             ; keep it; X is free again
                STA     |_cdTrampReadOp+1       ; STA |, NOT STAL -- see
                                                ;   _Chardev_Dispatch's note
                SEP     #$20
                MX      %10
                LDA     _cdDispOpsBank
                STA     |_cdTrampReadOp+3
                REP     #$30
                MX      %00
                JSR     _cdTrampReadOp          ; A = the slot's lo16
                PHA

                ; --- and the slot's third byte, two along from its address ---
                ; The trampoline's width follows the M flag at JSR time, which
                ; is what its header says and what makes a second cell
                ; unnecessary.  Only the operand's low word moves; the bank
                ; byte patched above still names the vtable's bank.
                TXA
                CLC
                ADC     #2
                STA     |_cdTrampReadOp+1
                SEP     #$20
                MX      %10
                JSR     _cdTrampReadOp          ; A.lo = the slot's ^ byte
                REP     #$30
                MX      %00
                AND     #$00FF
                TAY                             ; Y = that byte, zero-extended
                PLA                             ; A = the slot's lo16
                RTS

; _Chardev_Read / _Chardev_Write - the PER-BYTE primitives (cd_getc/cd_putc).
; The names keep their old spelling because every caller of them is a per-byte
; loop and renaming those call sites would be churn in code T3 deletes; the
; SLOTS are COPS_Getc/COPS_Putc, which is what they have always been.
_Chardev_Read   ENT
                LDX     #COPS_Getc
                JMP     _Chardev_Dispatch

_Chardev_Write  ENT
                LDX     #COPS_Putc
                JMP     _Chardev_Dispatch

; THERE IS NO _Chardev_DRead / _Chardev_DWrite.  T2.2a added a pair that JMPed
; straight at _Chardev_Dispatch, which would JSL through a slot that is ZERO on
; every per-byte device -- a jump to offset 0 of that device's bank, on every
; read.  _Chardev_Bulk above is the only way in, and it tests the slot first.

_Chardev_Ioctl  ENT
                LDX     #COPS_Ioctl
                JMP     _Chardev_Dispatch

_Chardev_Poll   ENT
                LDX     #COPS_Poll
                JMP     _Chardev_Dispatch

;------------------------------------------------------------------------------
; _Chardev_Stop - d_stop(dev, rw).  A.lo = idx, _cdArgFlag = rw.
;
; UNLIKE THE OPS ABOVE, THIS ONE TESTS ITS SLOT, and it must: an ABSENT d_stop
; is the NORMAL case rather than an error.  2.11BSD's own cdevsw gives the
; console, mem, lp and ht a `nulldev' here and only dz/dh/dhu a real body, so a
; zero slot means "this device has no output in flight to stop" -- an answer,
; not a failure.  Dispatching a zero slot would JSL offset 0 of the module's
; bank, which is apple/fgx#210's shape exactly.
;
; BOTH HALVES ARE TESTED, for the reason _Chardev_Bulk's note gives: a slot
; whose lo16 is 0 but whose bank is not is a real routine at offset 0 of its
; bank, and vfs.mod's own symbols start at $0000.
;
; Out: C=1 always.  There is nothing a caller does differently for a device
; that had nothing to stop -- upstream's callers ignore the return too.
;------------------------------------------------------------------------------
_Chardev_Stop   ENT
                MX      %00
                STA     _cdStopIdx
                AND     #$00FF
                CMP     #CHARDEV_MAX
                BCS     @cst_none               ; no such device
                LDA     _cdStopIdx
                LDX     #COPS_Stop
                JSR     _Cd_OpsSlot             ; A = lo16, Y = bank
                STY     _cdStopBank
                ORA     _cdStopBank
                BEQ     @cst_none               ; nulldev: nothing in flight
                LDA     _cdStopIdx
                LDX     #COPS_Stop
                JMP     _Chardev_Dispatch
@cst_none       SEC
                RTS

_cdStopIdx      DS      2
_cdStopBank     DS      2

;==============================================================================
; Built-in /dev/null chardev.  Registered at boot via _Chardev_InitBuiltins.
;
; Op semantics:
;   open    → C=1 (always ok)
;   close   → C=1
;   read    → A=0, C=0 (immediate EOF)
;   write   → C=1 (byte discarded)
;   ioctl   → C=0, A=ENOTTY (no ioctls supported)
;   poll    → A=POLLOUT, C=1 (always writable, never readable)
;
; These handlers live in the kernel image (assembled at $02, relocated).  The
; vtable's ^ bank bytes bake $02, but _Chardev_Dispatch ignores them and JSLs
; through _cdDispOpsBank — the live bank captured at registration via _BANKK —
; so the dispatch lands on the relocated handler, not the empty $02.
;==============================================================================

_Null_Open      MX %00
                SEC
                RTL

_Null_Close     MX %00
                SEC
                RTL

_Null_Read      MX %00
                LDA #0
                CLC
                RTL

_Null_Write     MX %00
                SEC
                RTL


_Null_Ioctl     MX %00
                LDA #ENOTTY
                CLC
                RTL

_Null_Poll      MX %00
                LDA #POLLOUT
                SEC
                RTL

;------------------------------------------------------------------------------
; _NullChardev_Ops - CharDev_Ops vtable for /dev/null.  Order MUST match
; COPS_* offsets in include/chardev.s.
;------------------------------------------------------------------------------
_NullChardev_Ops    ENT
                DFB     <_Null_Open,>_Null_Open,^_Null_Open
                DFB     <_Null_Close,>_Null_Close,^_Null_Close
                DFB     <_Null_Read,>_Null_Read,^_Null_Read
                DFB     <_Null_Write,>_Null_Write,^_Null_Write
                DFB     <_Null_Ioctl,>_Null_Ioctl,^_Null_Ioctl
                DFB     <_Null_Poll,>_Null_Poll,^_Null_Poll
                DFB     0,0,0                                   ; d_read:  none -- per-byte
                DFB     0,0,0                                   ; d_write: none -- per-byte
                DFB     0,0,0                                   ; d_stop:  nothing in flight

_NullChardev_Name   ASC     'null',00

;------------------------------------------------------------------------------
; _Chardev_InitBuiltins - register built-in chardevs at boot.  Called once
; from FGX_Entry's init sequence, after _KMem_ClearGlobals (which has
; already zeroed _chardev_count etc.).
;------------------------------------------------------------------------------
_Chardev_InitBuiltins ENT
                MX %00
                ; --- Allocate the chardev registry table as a soft-global ---
                ; (Kmalloc'd heap block reached via the DP long-ptr _cdTablePtr;
                ; must precede the first _Chardev_RegisterInternal below.)
                LDA     #CDTAB_BLK_SIZE
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @cib_allocOk            ; slice D grew this routine past
                BRL     @cib_allocFail          ;   BCC range -- invert + BRL
@cib_allocOk    LDA     _kmallocResult
                STA     _cdTablePtr
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2
                STA     _cdTablePtr+2
                REP     #$20
                MX      %00
                JSR     _SoftGlob_ValidatePtr   ; always-on: panic if not in heap
                ; Zero the table so empty slots read CD_NameLen = 0.
                LDY     #0
                SEP     #$20
                MX      %10
                LDA     #0
@cib_zL         STA     [_cdTablePtr],Y
                INY
                CPY     #CDTAB_BLK_SIZE
                BCC     @cib_zL
                REP     #$20
                MX      %00
                ; --- Register built-in /dev/null ---
                LDX     #_NullChardev_Name
                LDA     #_NullChardev_Ops
                LDY     #0                      ; minor = 0
                JSR     _Chardev_RegisterInternal
                ; Every tty line starts with NO node (apple/fgx#151).  This has
                ; to precede the registrations below: _KMem_ClearGlobals leaves
                ; the table zeroed, and zero is /dev/null's own index.
                JSR     _SyTty_InitLines
                ; --- pty pairs (pty P2): minor = pair*2 + side(0=m,1=s).
                ; Master idxs are recorded for `_Io_CdThenTty's winsize and
                ; flush routes (init to $FFFF first so a failed registration
                ; can never alias chardev idx 0).
                LDA     #$FFFF
                STA     _ptyMasterIdx0
                STA     _ptyMasterIdx1
                LDX     #_PtyName_M0
                LDA     #_PtyMChardev_Ops
                LDY     #CDF_RECORD*256+0       ; minor 0, and RECORD MODE: the
                                                ;   master answers a read with a
                                                ;   whole record.  This used to
                                                ;   be a write through [_fcbPtr]
                                                ;   at open (apple/fgx#198).
                JSR     _Chardev_RegisterInternal
                BCC     @cib_m0Done             ; #150: remember the MASTER idx
                AND     #$00FF                  ;   so _Io_CdThenTty can route
                STA     _ptyMasterIdx0          ;   the winsize pair to tty[1]
@cib_m0Done     LDX     #_PtyName_S0
                LDA     #_PtySChardev_Ops
                LDY     #1
                JSR     _Chardev_RegisterInternal
                BCC     @cib_ptyDone
                AND     #$00FF
                LDX     #1                      ; #151: /dev/tty resolves here
                JSR     _SyTty_NoteLine         ;   for a session on ttyp0
                LDY     #TTY_SIZE*1             ; ttyp0's slave IS tty[1] (#74)
                JSR     _Chardev_SetTtyOff
@cib_ptyDone    LDX     #_PtyName_M1
                LDA     #_PtyMChardev_Ops
                LDY     #CDF_RECORD*256+2       ; minor 2, record mode -- as M0
                JSR     _Chardev_RegisterInternal
                BCC     @cib_m1Done             ; #150: ditto for tty[2]
                AND     #$00FF
                STA     _ptyMasterIdx1
@cib_m1Done     LDX     #_PtyName_S1
                LDA     #_PtySChardev_Ops
                LDY     #3
                JSR     _Chardev_RegisterInternal
                BCC     @cib_ptyDone2
                AND     #$00FF
                LDX     #2
                JSR     _SyTty_NoteLine
                LDY     #TTY_SIZE*2             ; ttyp1's slave IS tty[2]
                JSR     _Chardev_SetTtyOff
@cib_ptyDone2   ; --- virtual consoles (slice D): /dev/ttyv1, /dev/ttyv2.
                ; Same $FFFF-first discipline so a failed registration cannot
                ; alias chardev 0.
                LDA     #$FFFF
                STA     _ttyvIdx0
                STA     _ttyvIdx1
                LDX     #_TtyvName_1
                LDA     #_TtyvChardev_Ops
                LDY     #0                      ; minor = VC number - 1
                JSR     _Chardev_RegisterInternal
                BCC     @cib_ttyvDone
                AND     #$00FF
                STA     _ttyvIdx0
                LDX     #3
                JSR     _SyTty_NoteLine
                LDY     #TTY_SIZE*3             ; ttyv1 IS tty[3] -- apple/fgx#74
                JSR     _Chardev_SetTtyOff      ;   (A still = the chardev idx)
@cib_ttyvDone   LDX     #_TtyvName_2
                LDA     #_TtyvChardev_Ops
                LDY     #1
                JSR     _Chardev_RegisterInternal
                BCC     @cib_ttyvDone2
                AND     #$00FF
                STA     _ttyvIdx1
                LDX     #4
                JSR     _SyTty_NoteLine
                LDY     #TTY_SIZE*4             ; ttyv2 IS tty[4]
                JSR     _Chardev_SetTtyOff
@cib_ttyvDone2  ; --- /dev/console (apple/fgx#121): tty[0], the physical console.
                ; LAST, for the reason the ttyv block above records: these
                ; indices are captured into variables and every read/ioctl
                ; detour selects by comparing against them, so a node inserted
                ; EARLIER shifts the ones already captured.  Appending cannot.
                ;
                ; Without this node init had nowhere to put the console line's
                ; open, so it reproduced ttyopen()'s process-group half from the
                ; parent and the controlling-terminal half went missing.
                LDA     #$FFFF
                STA     _conIdx
                LDX     #_ConName
                LDA     #_ConChardev_Ops
                LDY     #0                      ; minor 0: there is one console
                JSR     _Chardev_RegisterInternal
                BCC     @cib_conDone
                AND     #$00FF
                STA     _conIdx
                LDX     #0                      ; #151: tty[0] is the line a scan
                JSR     _SyTty_NoteLine         ;   of CD_TtyOff cannot find --
                LDY     #0                      ;   the console IS tty[0], and 0
                JSR     _Chardev_SetTtyOff      ;   is also SetTtyOff's "not a
                                                ;   tty" sentinel
@cib_conDone    ; --- /dev/tty (apple/fgx#151): the indirect driver for the
                ; controlling terminal, 2.11BSD tty_tty.c.  LAST for the reason
                ; the two blocks above record -- every earlier node's index is
                ; captured into a variable that a dispatch compares against, so
                ; only appending is safe.  It needs no CD_TtyOff of its own: it
                ; is not a line, it is a pointer to whichever line the caller
                ; has, resolved per op by _SyTty_Resolve.
                LDA     #$FFFF
                STA     _syttyIdx
                LDX     #_SyTtyName
                LDA     #_SyTtyChardev_Ops
                LDY     #0                      ; minor 0: one indirection
                JSR     _Chardev_RegisterInternal
                BCC     @cib_syttyDone
                AND     #$00FF
                STA     _syttyIdx
@cib_syttyDone  ; THE RAW DISKS FOLLOW, registered by _RawDisk_Register from
                ; the boot sequence immediately after this routine returns
                ; (main.s).  They are built in like everything above, and the
                ; only reason they are not in this list is that they walk the
                ; device table for the units that are online rather than
                ; naming a fixed set.  So the numbering is 0..9 here, 10..17
                ; raw disks, and whatever /sbin/modload registers after that.
                ; --- /dev/ttyv3 (VC_CARD): the third virtual console, tty[6],
                ; the one a Second Sight card displays.  Last of the built-ins
                ; so console and tty keep their indices; the raw disks count
                ; from 10 (tools/ninja/gen.py RAW_DISK_NODES).
                LDA     #$FFFF
                STA     _ttyvIdx2
                LDX     #_TtyvName_3
                LDA     #_TtyvChardev_Ops
                LDY     #2                      ; minor 2 = VC 3
                JSR     _Chardev_RegisterInternal
                BCC     @cib_ttyv3Done
                AND     #$00FF
                STA     _ttyvIdx2
                LDX     #6
                JSR     _SyTty_NoteLine
                LDY     #TTY_SIZE*6             ; ttyv3 IS tty[6]
                JSR     _Chardev_SetTtyOff
@cib_ttyv3Done  RTS
@cib_allocFail  MX      %00
                LDA     #_cdAllocFailMsg
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
_cdAllocFailMsg ASC     'PANIC: cannot alloc chardev table',00

;==============================================================================
; END chardev.s
;==============================================================================
