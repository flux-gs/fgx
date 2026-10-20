;==============================================================================
; loader.s - FGX1 binary loader.
;
; Public:
;   Load_Binary  X = path ptr (16-bit, kernel-bank offset).
;                Reads <path>, validates FGX1 header, copies text to
;                load_addr, zero-fills bss after, returns entry point in
;                _ldEntry (24-bit) and load bank in _ldUserBank.
;                C=1 on success.  C=0 + A=errno on failure
;                (ENOENT, ENOEXEC, EIO, EINVAL).
;
; Internals: see slice-1 plan tasks T2-T5.
;==============================================================================

;------------------------------------------------------------------------------
; Module-local state (bank-$02 static, one Load_Binary call lifetime).
;------------------------------------------------------------------------------
_ldFd           DS      2               ; open fd from Fs_Open
_ldSugidWant    DS      2               ; _Ld_ExecSugid's selector
_ldIsVnode      DS      2               ; UFS 2.4: this fd's ops are in THIS
                                        ;   bank, so the read stays here
_ldRdFd         DS      2               ; _Ld_VnodeRead's marshalling cells
_ldRdOff        DS      2
_ldRdLen        DS      2
_ldRdBank       DS      1
_ldSegTable     DS      FGX2_MAX_SEGS*FGX2_SEGTAB_ENTRY_SZ ; 64 B: up to 8 segs
_ldTextBytes    DS      2               ; remaining bytes to copy
_ldBssBytes     DS      2               ; remaining bytes to zero
_ldSegIdxSave   DS      2               ; seg index saved at load entry (BSD sbrk seed)
_ldEndOff       DS      2               ; this seg's `end` offset (text+bss); seeds
                                        ; the break cursor for the DATA segment
_ldDstLo        DS      2               ; running dst offset (low 16 bits)
_ldDstBank      DS      1               ; dst bank (= _ldUserBank, after override)
_ldOverrideBank DS      1               ; caller-supplied bank override (0=honor header)
_ldNSegs        DS      1               ; FGX2 n_segments (1..8); valid post-magic
_ldDataSegIdx   DS      2               ; FGX2 n_data_segment (0..n-1); slice 4.5
                                        ; replaces the v1 pinned-to-zero policy.
                                        ; Spawn/StageArgs reads this to decide
                                        ; which bank to push as DBR at entry.
                                        ; 2 bytes so 16-bit-Y can read it with
                                        ; a defined zero high byte.
_ldCurSeg       DS      1               ; FGX2 segment-load loop iterator (1..n-1)

_ldRelocCount   DS      2               ; entries in the CURRENT reloc batch
                                        ; (<= FGX2_RELOC_BATCH).
_ldRelocRemain  DS      2               ; total reloc entries still unprocessed
                                        ; (header count, decremented per batch).
_ldRelocBuf     DS      FGX2_RELOC_BATCH*FGX2_RELOC_ENTRY_SZ ; 256 B: ONE batch.
                                        ; The reloc table is STREAMED through
                                        ; this small buffer (read a batch via
                                        ; Fs_ReadN, apply, repeat) so reloc_count
                                        ; is bounded only by the 16-bit header
                                        ; field — no large buffer, no cap.
_ldRelocIter    DS      2               ; per-batch iterator (0..batch-1)

; --- Slice-3 stack-laid argv/envp staging ----------------------------------
LSARGV_MAX      EQU     16              ; max argc OR max envc per spawn
; Per-string scan ceiling.  NOT a truncation point -- a string that reaches it
; makes the frame measure as "does not fit", and the pre-write floor gate below
; answers E2BIG, which is what 2.11BSD does for an over-long arg list
; (`nc >= NCARGS-1' -> E2BIG, usr/sys/sys/kern_exec.c:237-240).  It exists only
; so the scan terminates on an unterminated string, and so that T stays inside
; 16 bits: max T = 10 + 2*LSARGV_MAX*(LSARG_STRMAX+3) = 32,874.  It is well
; above anything that can actually fit -- the child's stack caps the whole
; frame near 8 KB -- so the ceiling never decides an outcome the gate would
; not have decided anyway.
LSARG_STRMAX    EQU     1024
_ldChildTCB     DS      2               ; _ps_childTCB, cached once per
                                        ;   _Loader_StageArgs call.  It is a
                                        ;   CORE static and the four reads of it
                                        ;   below are all LDX -- for which the
                                        ;   65816 has no long form -- so the one
                                        ;   long read happens here and the rest
                                        ;   are ordinary far-bank absolutes.
                                        ;   Caching is safe because process.s
                                        ;   sets it before the call and nothing
                                        ;   changes it during one.
_la_argvPtr     DS      2               ; caller-bank offset of argv array (input; 0 = none)
_la_envpPtr     DS      2               ; caller-bank offset of envp array (input; 0 = empty)
_la_walk        DS      2               ; current caller-bank offset under inspection
_la_walkBank    DS      1               ; bank of the VECTOR being walked right
                                        ;   now -- reselected per array, because
                                        ;   argv and envp are separate far
                                        ;   pointers and need not share a bank.
_la_argvBank    DS      1               ; bank holding the argv vector
_la_envpBank    DS      1               ; bank holding the envp vector
_la_argBlk      DS      2               ; caller's arg-block offset ...
_la_argBlkBank  DS      2               ;   ... and its bank.  TWO bytes: the
                                        ;   seam hands it over in Y, and STY is
                                        ;   16-bit here, so a 1-byte cell would
                                        ;   write Y's high half into the next.
_la_strSrc      DS      2               ; caller-bank offset of a NUL-term string
_la_strBank     DS      1               ; bank holding the STRING under inspection,
                                        ;   read out of the vector ENTRY by
                                        ;   _la_readVecEntry.  Independent of
                                        ;   _la_walkBank: the vector sits in one
                                        ;   bank, the strings it names may sit in
                                        ;   any, which is the point of the widening.
_la_curAddr     DS      2               ; running write cursor (bank-0 stack address)
_la_startAddr   DS      2               ; first-char addr of the most-recent string
_la_childBank   DS      1               ; child's PB (cached from TCB_CodeBank)
_la_dataBank    DS      1               ; child's DBR at entry (slice 4.5:
                                        ; bank of FGX2 n_data_segment; for
                                        ; FGX1 / n_data_segment=0 binaries this
                                        ; equals _la_childBank — same as before).
_la_argc        DS      2
_la_envc        DS      2
_la_strLen      DS      2               ; running strlen scratch
_la_strOvf      DS      2               ; 1 = a string hit LSARG_STRMAX (#438)
_la_frameT      DS      2               ; #45: argv/envp frame size T (pre-walk)
_la_byteScratch DS      2               ; per-byte transfer slot (low byte used)
_la_argStrAddrs DS      2*LSARGV_MAX    ; bank-0 addr of argv[i]'s first byte
_la_envStrAddrs DS      2*LSARGV_MAX    ; bank-0 addr of envp[j]'s first byte

;==============================================================================
; Load_Binary - load and validate an FGX1 binary.
;
; Input:  X = ptr to null-terminated path string in bank $02.  MX %00.
;         A = target bank override (low byte).  If A=0, the loader honors
;             the bank in the FGX1 header.  Otherwise the load is forced
;             into the given bank — used by posix_spawn to load a child
;             into a freshly-allocated bank, regardless of what the binary
;             was assembled at.  (User binaries are bank-agnostic: every
;             absolute reference resolves through DBR which they set
;             themselves at entry via PHK/PLB.)
; Output: C=1 ok, _ldEntry/_ldUserBank populated.
;         C=0, A = errno (ENOENT / ENOEXEC / EIO / EMFILE / ENOMEM).
;==============================================================================
;==============================================================================
; _Ld_VnodeRead - read through the descriptor's own ops, WITHOUT LEAVING THIS
; BANK.  UFS campaign 2.4.
;
; A DROP-IN FOR _FarSh_Fs_ReadN, deliberately: same inputs, same outputs, same
; side effect on _frnDstOff.  That is what keeps the call sites to a branch and
; a JSR, and it is why the cursor is advanced here rather than at them --
; @lb_copyDone reads _frnDstOff as the address of the first BSS byte, and it
; must not be able to tell which reader ran.
;
; In:  A = fd (16-bit), X = count.  _frnDstBank/_frnDstOff = destination.
; Out: C=1 + Y = bytes moved (0 at EOF); C=0 + A = errno.
;
; MX:  %00 in and out.  Clobbers A, X, Y and the _ldRd* cells.
;==============================================================================
LD_VNREAD_MAX   EQU     $7F00           ; 32512: the largest count vfs_read
                                        ; will look at without seeing a
                                        ; negative one.  See _Ld_VnodeRead.
_Ld_VnodeRead   MX      %00
                STA     _ldRdFd
                ; vfs_read's `len' IS A SIGNED 16-BIT int, and rwcommon refuses
                ; a negative one with EINVAL before it reads a byte.  Fs_ReadN's
                ; count is UNSIGNED, and an FGX2 segment of more than 32767
                ; bytes -- which /sbin/init has -- arrives here as a negative
                ; int and is rejected rather than read.  MEASURED: this is what
                ; turned the boot's errno from EBADF into EINVAL once the reads
                ; started working.
                ;
                ; CLAMPING AND RETURNING SHORT IS SAFE AT EVERY CALL SITE, and
                ; not by luck: Fs_ReadN itself moves at most 512 bytes per call
                ; and its callers have always looped on a short count, so the
                ; contract this routine is a drop-in for already required it.
                ; The three sites that demand an EXACT count ask for 16 bytes,
                ; n_segs*8, and one 256-byte reloc batch.
                CPX     #LD_VNREAD_MAX
                BCC     @lvr_lenOK
                LDX     #LD_VNREAD_MAX
@lvr_lenOK      STX     _ldRdLen
_cfp470         LDAL    _frnDstOff
                STA     _ldRdOff
                SEP     #$20
                MX      %10
_cfp471         LDAL    _frnDstBank
                STA     _ldRdBank
                REP     #$30
                MX      %00
                ; KERNEL C WANTS ITS OWN PAGE, and only that half of KC_ENTER:
                ; that macro derives the far bank as the live kernel bank PLUS
                ; ONE, which is right for a caller in the core and would land
                ; on the TTY bank from here.  DBR is already this bank.
                PHD
                LDA     #FGX_DP_KERNELC
                TCD
                ; ld_read(fd, buf, len): fcc reads right to left, so len goes
                ; down first and fd ends nearest the return.  The buffer is a
                ; four-byte fcc pointer -- pad, bank, offset -- because the
                ; offset is the lowest address in it and the stack grows down.
                LDA     _ldRdLen
                PHA                             ; len
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; buf: pad
                LDA     _ldRdBank
                PHA                             ;      bank
                REP     #$30
                MX      %00
                LDA     _ldRdOff
                PHA                             ;      offset
                LDA     _ldRdFd
                PHA                             ; fd
                ; THE FRAME IS BUILT BY HAND AND ENTERED WITH JMP, not with
                ; the PHK/PEA/PHK/PEA/RTL pile call fcc emits.  The callee sees
                ; exactly what a JSL leaves either way and returns with RTL, so
                ; the contract is identical -- but an RTL anywhere in a far-bank
                ; routine's body makes check_far_rtl_calls call the whole
                ; routine RTL-terminated, deliberately and conservatively, and
                ; this one is JSR'd.  A same-bank JMP carries its bank in PBR,
                ; so it survives relocation exactly as the pile call does.
                PHK
                PEA     @lvr_ret-1
                JMP     ld_read
@lvr_ret        TAY                             ; park the answer; TSC needs A
                TSC
                CLC
                ADC     #8                      ; drop the copy -- caller cleans
                TCS
                PLD
                TYA
                BMI     @lvr_err                ; NEGATIVE IS -errno, which is
                                                ;   ld_read's contract and every
                                                ;   other far entry's
                ; A = bytes moved.  Advance the shared cursor exactly as
                ; Fs_ReadN does; see the header.
                PHA
                CLC
                ADC     _ldRdOff
_cfp472         STAL    _frnDstOff
                PLA
                TAY                             ; Y IS THE ANSWER
                SEC
                RTS
@lvr_err        EOR     #$FFFF                  ; -errno -> errno
                INC
                CLC
                RTS

;==============================================================================
; _Ld_FdIsVnode - does this fd dispatch through THIS bank's vnops?
; In:  A = fd (16-bit).  Out: A = 0 or non-zero.  MX %00.
;==============================================================================
_Ld_FdIsVnode   MX      %00
                STA     _ldRdFd                 ; the fd arrives in A, so it is
                PHD                             ;   stashed BEFORE the page moves
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     _ldRdFd
                PHA                             ; fd
                PHK                             ; see _Ld_VnodeRead on the
                PEA     @lfv_ret-1              ;   frame and the JMP
                JMP     ld_fd_is_vnode
@lfv_ret        TAY
                PLX                             ; drop the argument copy
                PLD
                TYA
                RTS

;==============================================================================
; _Ld_ExecCheck - may the file behind this descriptor be executed?
; In:  A = fd (16-bit).  Out: A = 0, or the errno that refuses it.  MX %00.
;
; The frame is _Ld_FdIsVnode's above and for the same reasons: the callee is
; compiled into THIS bank, so PHK + PEA builds the RTL frame a JSL would have
; left and the JMP costs no crossing.
;==============================================================================
_Ld_ExecCheck   MX      %00
                STA     _ldRdFd
                PHD
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     _ldRdFd
                PHA                             ; fd
                PHK
                PEA     @lec_ret-1
                JMP     ld_exec_check
@lec_ret        TAY
                PLX                             ; drop the argument copy
                PLD
                TYA
                RTS

;==============================================================================
; _Ld_ExecSugid - the id a set-id image adopts, or $FFFF for "unchanged".
; In:  A = fd (16-bit), X = 0 for the uid / 1 for the gid.
; Out: A = the id, or $FFFF.  MX %00.
;
; ld_exec_sugid(fd, want): fcc reads right to left, so `want' goes down first
; and `fd' ends nearest the return -- _Ld_VnodeRead's note above says the same.
;==============================================================================
_Ld_ExecSugid   MX      %00
                STA     _ldRdFd
                STX     _ldSugidWant
                PHD
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     _ldSugidWant
                PHA                             ; want
                LDA     _ldRdFd
                PHA                             ; fd
                PHK
                PEA     @les_ret-1
                JMP     ld_exec_sugid
@les_ret        TAY
                PLX                             ; drop the two argument copies
                PLX
                PLD
                TYA
                RTS

;==============================================================================
; _Ld_TextKey - this file's shared-text key into _ldTextKey.
; In:  _ldFd, a VNODE descriptor (root_fstat panics on a legacy one).
; Out: C=1 keyed, C=0 not (fstat failed).  MX %00.
;
; THE KEY IS fstat(2)'s ANSWER: st_dev, st_ino and st_ctime, which vn_stat
; fills from VOP_GETATTR as Reno's does (kern/vfs_vnops.c).  ctime moves on
; every write, truncate, chmod and link change, so a file rewritten or
; replaced never matches the text loaded from it before.  root_fstat writes
; its 52 bytes into _ldSegTable, which nothing has read yet on this load;
; the eight the key needs are copied out before the segment table lands.
; root_fstat(pid, fd, sb) takes `sb' as an fcc pointer (offset, bank, pad),
; pushed high word first; the frame is _Ld_ExecCheck's.
;==============================================================================
_Ld_TextKey     MX      %00
                PHD
                LDA     #FGX_DP_KERNELC
                TCD
                PHK
                PEA     @ltk_pid-1
                JMP     kc_curpid
@ltk_pid        TAX                             ; pid
                PEA     0                       ; sb: pad and bank...
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     1,S                     ; ...bank = this one
                REP     #$20
                MX      %00
                PEA     _ldSegTable             ; sb: offset
                LDA     _ldFd
                AND     #$00FF
                PHA                             ; fd
                PHX                             ; pid
                PHK
                PEA     @ltk_ret-1
                JMP     root_fstat
@ltk_ret        TAY
                TSC
                CLC
                ADC     #8                      ; drop the argument copies
                TCS
                PLD
                CPY     #0
                BNE     @ltk_no
                LDA     _ldSegTable+STX_dev
                STA     _ldTextKey
                LDA     _ldSegTable+STX_ino
                STA     _ldTextKey+2
                LDA     _ldSegTable+STX_ctime
                STA     _ldTextKey+4
                LDA     _ldSegTable+STX_ctime+2
                STA     _ldTextKey+6
                SEC
                RTS
@ltk_no         CLC
                RTS

Load_Binary     ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00

                ;--- Stash override bank (low byte; 0 = honor header). ---
                ; _ldOverrideBank is 1 byte — must store as M=8 or the high
                ; byte of A clobbers the next byte in memory (which here is
                ; the first opcode of Load_Binary itself!).
                SEP     #$20
                MX      %10
                STA     _ldOverrideBank
                ; The per-load bank lists start empty, so no load inherits
                ; a bank from the one before it: spawn and exec copy
                ; _ldExtraBanks into TCB_BankList.  X is the path.
                PHX
                LDX     #FGX2_MAX_SEGS-1
@lb_zero        STZ     _ldExtraBanks,X
                STZ     _ldTextList,X           ; banks, pages, page counts
                STZ     _ldTextList+8,X
                STZ     _ldTextList+16,X
                STZ     _ldSegPage,X
                DEX
                BPL     @lb_zero
                PLX
                STZ     _ldTextIdx
                STZ     _ldTextNew
                ; Slice 4.5: zero _ldDataSegIdx (2 bytes) so FGX1 binaries
                ; (which never run the FGX2-header parser) default to "data
                ; is in seg 0" — TCB_BankList[0] = code bank = same DBR as
                ; the old PB-was-also-DBR convention.
                STZ     _ldDataSegIdx
                STZ     _ldDataSegIdx+1
                REP     #$20
                MX      %00

                ;--- Step 1: open the file. ---
                ; X already = path ptr (caller's contract).
                ; Fs_Open(X = path) -> C=1 + A=fd, C=0 + A=errno.
_cfp405         JSL     _FarSh_Fs_OpenCore
                BCS     @lb_opened
                JMP     @lb_passErr
@lb_opened
                ; A = fd (low byte).  Save it.
                AND     #$00FF
                STA     _ldFd
                ; WHICH READER THIS DESCRIPTOR WANTS, asked ONCE -- UFS 2.4.
                ; A descriptor opened against the mounted root dispatches
                ; through vnops, which is compiled into THIS bank, so its reads
                ; never need to leave it.  A ProDOS descriptor's ops are in the
                ; core and the shim is still the only way to reach them.
                JSR     _Ld_FdIsVnode
                STA     _ldIsVnode

                ;--- Step 1a: is this file executable at all? ---
                ; BOTH UPSTREAMS ASK BEFORE READING A BYTE -- 4.3BSD-Reno
                ; kern/kern_exec.c:129-138 and 2.11BSD usr/sys/sys/kern_exec.c
                ; :74-93 -- and the mode question has to come first for the
                ; same reason: an image that may not run is not one to spend a
                ; bank allocation and six segment reads on.
                ;
                ; @lb_eioClose IS THE CLOSE-AND-REPORT-A ARM.  Its `A == 0
                ; means EOF, report EIO' mapping cannot fire from here, because
                ; this only branches away when A is non-zero.
                LDA     _ldFd
                AND     #$00FF
                JSR     _Ld_ExecCheck
                BEQ     @lb_execOK
                JMP     @lb_eioClose
@lb_execOK
                ;--- Step 1b: whose credentials does it run with? ---
                ; Reno reads the set-id bits here, between the getattr and the
                ; access tests (kern/kern_exec.c:123-127); 2.11BSD's
                ; usr/sys/sys/kern_exec.c:79-84 is the same block.  The ANSWER
                ; is only acted on at the exec COMMIT, which is upstream's
                ; arrangement too -- Reno sets the credential at :648, past
                ; every failure path -- because a load that fails must leave
                ; the caller exactly as privileged as it was.
                ;
                ; ASKED FOR EVERY LOAD, INCLUDING THE KERNEL'S OWN.  /sbin/init
                ; carries neither bit and answers $FFFF twice; making the
                ; question conditional would need a second flag saying which
                ; caller this is, and the cells have to be written on every
                ; path anyway or a later load would inherit an earlier one's
                ; answer.
                LDA     _ldFd
                AND     #$00FF
                LDX     #0
                JSR     _Ld_ExecSugid
                STA     _ldSetUid
                LDA     _ldFd
                AND     #$00FF
                LDX     #1
                JSR     _Ld_ExecSugid
                STA     _ldSetGid
                ;--- Step 1c: the file's identity, for the shared-text table. ---
                ; Written on every load, so no load inherits another's key.  A
                ; legacy descriptor has no vnode and is never cached.
                STZ     _ldTextKeyOk
                LDA     _ldIsVnode
                BEQ     @lb_tkDone
                JSR     _Ld_TextKey
                BCC     @lb_tkDone
                INC     _ldTextKeyOk
@lb_tkDone

                ;--- Step 2: read 16-byte header into _ldHeader via bulk read. ---
                ; RELOC: dst bank = _BANKK (the LIVE kernel bank), so the magic/
                ; field reads below MUST be DBR-relative (LDA |_ldHeader), NOT
                ; LDAL: the baked-$02 copy is stale and would mis-parse the
                ; binary -> spurious ENOEXEC for /sbin/init under relocation.
                SEP     #$20
                MX      %10
                _BANKK
_cfp406         STAL    _frnDstBank
                REP     #$20
                MX      %00
                LDA     #_ldHeader              ; low 16 bits of (kernel bank):_ldHeader
_cfp407         STAL    _frnDstOff
                LDA     _ldFd
                AND     #$00FF
                LDX     #FGX1_HEADER_SZ
                LDY     _ldIsVnode
                BEQ     @lb_hdrLegacy
                JSR     _Ld_VnodeRead                   ; same contract, no seam
                BRA     @lb_hdrJoin
@lb_hdrLegacy
_cfp408         JSL     _FarSh_Fs_ReadN                 ; C=1 + Y=bytes; C=0 + A=errno
@lb_hdrJoin     BCS     @lb_hdrGot
                JMP     @lb_eioClose
@lb_hdrGot      ; Y = bytes read.  Must equal FGX1_HEADER_SZ.
                CPY     #FGX1_HEADER_SZ
                BEQ     @lb_hdrFull
                ; Short read: header truncated.  Treat as EIO.
                LDA     #$0000
                JMP     @lb_eioClose
@lb_hdrFull

                ;--- Step 3: validate magic + dispatch FGX1 vs FGX2 vs FGX3. ---
                ; All formats share a 4-byte 'FGX' prefix; the 4th byte
                ; selects the version.  FGX1 = $31 ('1'), FGX2 = $32 ('2'),
                ; FGX3 = $33 ('3').
                LDA    |_ldHeader+0
                CMP     #$4746                  ; "FG"
                BEQ     @lb_magicHi
                JMP     @lb_enoexec
@lb_magicHi     LDA    |_ldHeader+2
                CMP     #$3158                  ; "X1" (FGX1)
                BEQ     @lb_magicOK
                CMP     #$3258                  ; "X2" (FGX2 — slice 2.2)
                BEQ     @lb_fgx2
                CMP     #$3358                  ; "X3" (FGX3 — P3-5 I1)
                BEQ     @lb_fgx3
                JMP     @lb_enoexec
@lb_fgx3        ; FGX3 = FGX2 layout + a MANDATORY ABI stamp at header byte 13
                ; (FGX3_OFF_ABI).  Validate the stamp, then share the FGX2
                ; code path wholesale.  A stale/absent stamp is the clean-
                ; break case (pre-P3 binary shape on a post-P3 kernel) —
                ; reject LOUDLY with ENOEXEC, never run it.
                LDA    |_ldHeader+FGX3_OFF_ABI-1 ; hi byte = abi stamp (13);
                AND     #$FF00                   ; lo byte (12) = reloc_count
                                                 ; hi — varies, mask it off
                CMP     #FGX_ABI_CURRENT*$100
                BEQ     @lb_fgx2                 ; stamp OK → FGX2 path
                JMP     @lb_enoexec
@lb_fgx2        JSR     _LoadFGX2               ; C=1 + _ldEntry/_ldUserBank
                                                ; populated; C=0 + A=errno.
                                                ; Closes fd internally either way.
                BCS     @lb_fgx2_ok
                JMP     @lb_passErr             ; A=errno → unified errno return
@lb_fgx2_ok     PLP
                SEC
                RTS
@lb_magicOK

                ;--- Step 4: parse header fields. ---
                ; load address (3 bytes at +4..+6).  Note: the file layout is
                ; [16-byte header][text bytes].  The source ORGs at LOAD_ADDR,
                ; so the header logically lives at LOAD_ADDR..LOAD_ADDR+15
                ; and code starts at LOAD_ADDR+16.  text_size in the header is
                ; "bytes after the header to copy", so we place them at
                ; LOAD_ADDR + 16.  The bytes at LOAD_ADDR..LOAD_ADDR+15 are
                ; uninitialized — entry_offset must be >= 16 for any reachable
                ; code (typically = 16).
                LDA    |_ldHeader+FGX1_OFF_LOAD          ; 16-bit: lo word
                CLC
                ADC     #FGX1_HEADER_SZ                   ; skip header gap
                STA     _ldDstLo
                SEP     #$20
                MX      %10
                ; Pick destination bank: override (if non-zero) else header.
                LDA     _ldOverrideBank
                BNE     @lb_haveBank
                LDA    |_ldHeader+FGX1_OFF_LOAD+2        ; bank byte from header
@lb_haveBank    STA     _ldDstBank
                STA     _ldUserBank
                STA     _ldExtraBanks           ; segment 0's, the process's
                REP     #$20
                MX      %00
                ; entry = load + entry_offset (24-bit add, relative to LOAD).
                LDA    |_ldHeader+FGX1_OFF_LOAD          ; reload load lo word
                CLC
                ADC     _ldHeader+FGX1_OFF_ENTRY
                STA     _ldEntry                          ; lo+mid bytes
                LDA     _ldUserBank
                AND     #$00FF
                ADC     #0                                ; carry from above
                SEP     #$20
                MX      %10
                STA     _ldEntry+2                        ; bank
                REP     #$20
                MX      %00
                ; text size into _ldTextBytes.
                LDA    |_ldHeader+FGX1_OFF_TEXT
                STA     _ldTextBytes
                ; bss size into _ldBssBytes.
                LDA    |_ldHeader+FGX1_OFF_BSS
                STA     _ldBssBytes

                ;--- Step 5: bulk-copy `_ldTextBytes` bytes from fd into user bank. ---
                ; Fs_ReadN MVNs ≤512 B per call from _fsDataBuf into
                ; (_ldDstBank:_ldDstLo).  We loop until either the requested
                ; count is satisfied OR Fs_ReadN reports a short read.
                ;
                ; Fs_ReadN's count register is 16 bits, but text size in the
                ; FGX1 header is also 16 bits — one call typically suffices.
                ; We still loop defensively in case future headers grow.
                SEP     #$20
                MX      %10
                LDA     _ldDstBank
_cfp409         STAL    _frnDstBank
                REP     #$20
                MX      %00
                LDA     _ldDstLo
_cfp410         STAL    _frnDstOff
                LDA     _ldTextBytes
                BEQ     @lb_copyDone
@lb_copyChunk   LDA     _ldFd
                AND     #$00FF
                LDX     _ldTextBytes
                LDY     _ldIsVnode
                BEQ     @lb_copyLegacy
                JSR     _Ld_VnodeRead                   ; advances _frnDstOff too
                BRA     @lb_copyJoin
@lb_copyLegacy
_cfp411         JSL     _FarSh_Fs_ReadN                 ; C=1 + Y=copied; C=0 + A=errno
@lb_copyJoin    BCS     @lb_copyOK
                JMP     @lb_eioClose
@lb_copyOK      ; Y = bytes copied this call (0 = EOF before satisfying count).
                CPY     #0
                BNE     @lb_copyAdv
                ; Short EOF: text truncated.  Report EIO.
                LDA     #$0000
                JMP     @lb_eioClose
@lb_copyAdv     ; Subtract Y from _ldTextBytes.  Y holds copied count.
                TYA
                EOR     #$FFFF
                SEC
                ADC     _ldTextBytes            ; A = _ldTextBytes - Y
                STA     _ldTextBytes
                BEQ     @lb_copyDone
                ; More to read — _frnDstOff already advanced by Fs_ReadN.
                BRA     @lb_copyChunk

@lb_copyDone    ;--- Step 6: zero `_ldBssBytes` bytes after text. ---
                ; BSS starts at _ldDstLo + (original text_bytes), but we have
                ; been incrementing _frnDstOff inside Fs_ReadN — its current
                ; value points exactly at first BSS byte.  Use it.
                LDA     _ldBssBytes
                BEQ     @lb_bssDone

                ; Switch DBR to user bank once, run a tight STZ loop, restore.
                ; THE COUNT RIDES THE STACK ACROSS THE BANK SWITCH.  It was
                ; re-read after the PLB, which made it an absolute -- so
                ; DBR-relative -- read of <DESTINATION bank>:_ldBssBytes rather
                ; than ours, and the loop then zeroed whatever that word said:
                ; nothing at all when it read zero, leaving BSS uninitialised,
                ; or up to 64 KB over the segment's own text when it did not.
                ; apple/fgx#211.
                PHA                             ; [count]
_cfp403         LDAL    _frnDstOff              ; core static; bank byte patched
                TAX                             ; X = first BSS byte's offset
                SEP     #$20
                MX      %10
                LDA     _ldDstBank
                PHA
                PLB                             ; DBR = dst bank
                REP     #$20
                MX      %00
                PLA                             ; A = count, read from OUR bank
                ; Word loop while ≥2 bytes remain.
@lb_bss_wL      CMP     #2
                BCC     @lb_bss_tail
                STZ:    $0000,X                 ; clear 16-bit word at DBR:X
                INX
                INX
                DEC
                DEC
                BRA     @lb_bss_wL
@lb_bss_tail    CMP     #0
                BEQ     @lb_bss_restore
                ; Single trailing byte.
                SEP     #$20
                MX      %10
                STZ:    $0000,X                 ; clear 1 byte at DBR:X
                REP     #$20
                MX      %00
@lb_bss_restore SEP     #$20
                MX      %10
                _DBRK
                REP     #$20
                MX      %00
@lb_bssDone

                ;--- Step 7: close file + return success. ---
                SEP     #$20
                MX      %10
                LDA     _ldFd
                REP     #$20
                MX      %00
                AND     #$00FF
_cfp412         JSL     _FarSh_Fs_Close
                ; _ldEntry / _ldUserBank are populated.
                PLP
                SEC
                RTS

@lb_enoexec     ; Magic mismatch — close + return ENOEXEC.
                LDA     _ldFd
                AND     #$00FF
_cfp413         JSL     _FarSh_Fs_Close
                LDA     #ENOEXEC
                JMP     @lb_errA8

@lb_eioClose    ; Header read failed mid-way.  A holds 0 (EOF) or errno.
                ; ON THE STACK, NOT IN _shTmp0, for the reason the FGX2 tails
                ; below already carry: Fs_Close reaches _Fcb_LookupPtr, which
                ; uses _shTmp0 as its fd*3 byte-offset scratch on EVERY call,
                ; and fcb.s:628 names this caller's exact mistake.  So the
                ; reload after the close returned Fs_Close's OWN errno and this
                ; arm reported EBADF for every failure that reached it.  The
                ; FGX2 tails were fixed at apple/fgx#14 and this one was not.
                PHA
                LDA     _ldFd
                AND     #$00FF
_cfp414         JSL     _FarSh_Fs_Close
                ; If A was 0 (EOF / short read), report EIO.
                PLA
                AND     #$00FF
                BNE     @lb_eio_passthrough
                LDA     #EIO
                JMP     @lb_errA8
@lb_eio_passthrough
                JMP     @lb_passErr

@lb_passErr     ; A holds errno (16-bit) from inner call.
                STA     _errno
                AND     #$00FF
                PLP
                CLC
                RTS

@lb_errA8       MX      %10
                STA     _errno
                REP     #$20
                MX      %00
                AND     #$00FF
                PLP
                CLC
                RTS

;==============================================================================
; _LoadFGX2 - the FGX2/FGX3 multi-bank binary loader.
;
; Called from Load_Binary after the magic dispatch.  fd is open and the
; 16-byte header has been read into _ldHeader.
;   1. Validate n_segments in [1, 8] and n_data_segment < n_segments.
;   2. Read n*8 bytes of segment-table entries into _ldSegTable.
;   3. Look the file up in the shared-text table (_ldTextKey); on a hit the
;      text's banks land in _ldTextList and a reference is taken.
;   4. For each segment: a kind past RODATA fails the load with ENOEXEC; the
;      DATA segment loads into _ldOverrideBank, the bank spawn or exec
;      allocated; a loaded text's CODE segment is skipped; anything else gets
;      a Bank_Alloc'd bank.
;      _ldExtraBanks[seg] records each bank this process owns.
;   5. Apply the relocations, except a loaded text's own.
;   6. A text just loaded is recorded in the table (its banks leave
;      _ldExtraBanks); _ldTextIdx is the text this load holds.
;   7. _ldEntry = segment 0's bank : header.entry_offset.  Close fd.
;
; Output: C=1 + _ldEntry / _ldUserBank / _ldExtraBanks / _ldTextIdx;
;         C=0 + A = errno on failure (ENOEXEC / EINVAL / ENOMEM / EIO), with
;         this load's banks freed and its text reference dropped.
;         fd is always closed.  Caller MX %00; PHP/PLP live in Load_Binary.
;==============================================================================
_LoadFGX2       MX      %00
                ; --- Step F1: validate n_segments in [1, FGX2_MAX_SEGS]. ---
                SEP     #$20
                MX      %10
                LDA    |_ldHeader+FGX2_OFF_NSEGS
                STA     _ldNSegs                 ; RELOC: write DBR-rel to match the
                                                 ; reads (F2 CMP / F5 LDA / F7 CMP).
                                                 ; STAL baked $02 here while reads
                                                 ; were DBR-rel -> under reloc the
                                                 ; $20 copy stayed 0, so F2's
                                                 ; "n_data_segment >= n_segs" saw 0
                                                 ; and rejected EVERY FGX2 binary.
                CMP     #1
                BCC     @lf2_nsegBad             ; n == 0
                CMP     #FGX2_MAX_SEGS+1
                BCC     @lf2_nsegOK_M8
@lf2_nsegBad    REP     #$20
                MX      %00
                LDA     #ENOEXEC
                JMP     @lf2_errClose
@lf2_nsegOK_M8  REP     #$20
                MX      %00
                ; A shared library (fgx_ld's header flags bit 1, shared libc
                ; SP3) is not a program: it has no entry, and its imports are
                ; unbound until ld.mod's registry places it.
                SEP     #$20
                MX      %10
                LDA    |_ldHeader+FGX2_OFF_FLAGS
                AND     #FGX2_FLAG_LIB
                REP     #$20
                MX      %00
                BEQ     @lf2_notLib
                LDA     #ENOEXEC
                JMP     @lf2_errClose
@lf2_notLib

                ; --- Step F2: stash n_data_segment (slice 4.5: was pinned
                ; to 0 in v1; now any 0..n-1 is accepted).  The value is
                ; consumed by _Loader_StageArgs to decide which bank to
                ; push as DBR at child entry. ---
                SEP     #$20
                MX      %10
                LDA    |_ldHeader+FGX2_OFF_NDATASEG
                STA     _ldDataSegIdx            ; RELOC: write DBR-rel to match the
                                                 ; zero at Load_Binary top + the
                                                 ; DBR-rel read in _Loader_StageArgs
                                                 ; (entry DBR for n_data_segment).
                CMP     _ldNSegs                 ; reject n_data_segment >= n_segs
                REP     #$20
                MX      %00
                BCC     @lf2_dataSegOK
                LDA     #EINVAL
                JMP     @lf2_errClose

@lf2_dataSegOK  ; --- Step F3: validate override bank present. ---
                SEP     #$20
                MX      %10
                LDA     _ldOverrideBank
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @lf2_haveBank
                LDA     #EINVAL                  ; FGX2 requires override
                JMP     @lf2_errClose
@lf2_haveBank

                ; --- Step F5: read n_segs * 8 bytes of segment table. ---
                ; n_segs is in _ldNSegs (1..8); n_segs*8 = ASL ASL ASL.
                SEP     #$20
                MX      %10
                _BANKK
_cfp415         STAL    _frnDstBank
                REP     #$20
                MX      %00
                LDA     #_ldSegTable
_cfp416         STAL    _frnDstOff
                LDA     _ldNSegs
                AND     #$00FF
                ASL
                ASL
                ASL                              ; A = n_segs * 8
                STA     _ldTextBytes             ; reuse as "segtable bytes left"
                LDA     _ldFd
                AND     #$00FF
                LDX     _ldTextBytes
                LDY     _ldIsVnode              ; UFS 2.4: a root fd
                BEQ     @sgt_legacy              ;   reads in this bank
                JSR     _Ld_VnodeRead
                BRA     @sgt_join
@sgt_legacy
_cfp417         JSL     _FarSh_Fs_ReadN
@sgt_join
                BCS     @lf2_segtabGot
                JMP     @lf2_errCloseEIO
@lf2_segtabGot  CPY     _ldTextBytes
                BEQ     @lf2_segtabFull
                LDA     #0
                JMP     @lf2_errCloseEIO
@lf2_segtabFull

                ; --- Step F6: is this file's text already loaded? ---
                ; 2.11BSD xalloc: a text with this identity is shared and
                ; counted; its code segments are not read again.  The
                ; reference is taken now, before any Bank_Alloc below can
                ; reclaim the very text this load is about to use.  On a
                ; miss the entry is claimed now, with no segments, so what
                ; this load places belongs to it from the start
                ; (_ldTextNew); it is filled at F7.6.
                LDA     _ldTextKeyOk
                BEQ     @lf2_noFind
                LDA     #_ldTextKey
                PHK
                PHK
                PLX                              ; X = this bank, the key's
                LDY     #_ldTextList
_cfp999         JSL     _FarSh_TextFind
                BCS     @lf2_hit
                LDA     #_ldTextKey
                PHK
                PHK
                PLX
_cfp1003        JSL     _FarSh_TextClaim
                BCC     @lf2_noFind              ; no entry: banks of its own
                SEP     #$20
                MX      %10
                INC     _ldTextNew
                BRA     @lf2_idx
@lf2_hit        SEP     #$20
                MX      %10
                PHA                              ; the index
                LDX     #FGX2_MAX_SEGS-1         ; the text's pages: where its
@lf2_hitPg      LDA     _ldTextList+8,X          ;   segments sit, which its
                STA     _ldSegPage,X             ;   offset relocations add
                DEX
                BPL     @lf2_hitPg
                PLA
@lf2_idx        STA     _ldTextIdx
@lf2_noFind     SEP     #$20
                MX      %10

                ; --- Step F7: loop over segments 0..n-1. ---
                STZ     _ldCurSeg
@lf2_loopTop    LDA     _ldCurSeg
                CMP     _ldNSegs
                BCC     @lf2_moreSegs            ; cur < n_segs → next segment
                BRL     @lf2_loopDone
@lf2_moreSegs
                ASL
                ASL
                ASL                              ; A(8) = cur*8 (cur<=7, no clip)
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX                              ; X = segtab entry base (B-safe)
                SEP     #$20
                MX      %10
                ; A kind past RODATA is no format this loader knows: 2.11BSD
                ; exec answers a magic it does not know with ENOEXEC.
                LDA     _ldSegTable+FGX2_SEG_KIND,X
                CMP     #SEG_KIND_RODATA+1
                BCC     @lf2_kindOK
                REP     #$20
                MX      %00
                LDA     #ENOEXEC
                JMP     @lf2_errCloseExtras
                MX      %10
                ; A loaded text's code segment: step over its file bytes,
                ; Fs_Lseek(fd, SEEK_CUR, size).  X = the segtab entry.
@lf2_skipBytes  LDA     #SEEK_CUR
_cfp418         STAL    _fsLsWhence
                REP     #$20
                MX      %00
                LDA     _ldSegTable+FGX2_SEG_SIZE,X
                TAX                              ; X = offset lo16
                LDY     #0                       ; offset hi8 = 0
                LDA     _ldFd
                AND     #$00FF
_cfp419         JSL     _FarSh_Fs_Lseek
                BCS     @lf2_skipOK
                JMP     @lf2_errCloseExtras
@lf2_skipOK     SEP     #$20
                MX      %10
                INC     _ldCurSeg
                BRL     @lf2_loopTop
@lf2_kindOK     ; X = the segtab entry.  THE DATA SEGMENT GOES IN THE CALLER'S
                ; BANK, the one spawn and exec allocated, which the process
                ; owns whatever its text; a loaded text's code segments are
                ; skipped; anything else gets a bank of its own.
                LDA     _ldCurSeg
                CMP     _ldDataSegIdx
                BNE     @lf2_notData
                LDA     _ldOverrideBank
                BRA     @lf2_haveExtra
@lf2_notData    LDA     _ldSegTable+FGX2_SEG_KIND,X
                BNE     @lf2_alloc               ; not CODE
                LDA     _ldTextIdx
                BEQ     @lf2_alloc               ; no text: load it
                LDA     _ldTextNew
                BNE     @lf2_alloc               ; a text being loaded: load it
                BRL     @lf2_skipBytes
@lf2_alloc      ; A code segment of a text this load claimed, flagged as
                ; placeable, takes the pages its bytes need from the pool's
                ; map and shares a bank with other texts; anything else, or
                ; one the map has no room for, gets a whole bank.
                LDA     _ldTextNew
                BEQ     @lf2_whole
                LDA     _ldSegTable+FGX2_SEG_KIND,X
                BNE     @lf2_whole
                LDA     _ldSegTable+FGX2_SEG_FLAGS,X
                AND     #FGX2_SEGF_PLACE
                BEQ     @lf2_whole
                REP     #$20
                MX      %00
                LDA     _ldSegTable+FGX2_SEG_SIZE,X
                CLC
                ADC     _ldSegTable+FGX2_SEG_BSS,X
                BCS     @lf2_whole16
                CLC
                ADC     #255
                BCS     @lf2_whole16             ; a full bank's worth
                XBA
                AND     #$00FF                   ; pages = ceil(bytes / 256)
                BEQ     @lf2_whole16
                STA     _ldPlaceN
_cfp1004        JSL     _FarSh_Core_Alloc
                BCC     @lf2_whole16
                STA     _ldPlace
                LDA     _ldCurSeg
                AND     #$00FF
                TAY
                SEP     #$20
                MX      %10
                LDA     _ldPlace                 ; its page...
                STA     _ldSegPage,Y
                LDA     _ldPlaceN                ; ...its page count (FILL's)...
                STA     _ldTextList+16,Y
                LDA     _ldPlace+1               ; ...and its bank
                BRA     @lf2_haveExtra
@lf2_whole16    SEP     #$20
                MX      %10
@lf2_whole      REP     #$20
                MX      %00
_cfp420         JSL     _FarSh_Bank_Alloc
                BCS     @lf2_haveExtra
                LDA     #ENOMEM
                JMP     @lf2_errCloseExtras
@lf2_haveExtra  ; A.lo = the bank.  Record in _ldExtraBanks[curSeg].
                SEP     #$20
                MX      %10
                STA     _ldDstBank               ; dst for _LoadOneSegment
                PHA                              ; save bank across X compute
                LDA     _ldCurSeg
                REP     #$20
                MX      %00
                AND     #$00FF                   ; clear stale B: TAX is 16-bit here
                TAX
                SEP     #$20
                MX      %10
                PLA
                STA     _ldExtraBanks,X

                ; Y = curSeg (the helper computes Y*8 internally).
                LDA     _ldCurSeg
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY
                JSR     _LoadOneSegment
                BCS     @lf2_segOK
                JMP     @lf2_errCloseExtras
@lf2_segOK      SEP     #$20
                MX      %10
                INC     _ldCurSeg
                BRL     @lf2_loopTop

@lf2_loopDone   REP     #$20
                MX      %00

                ; --- Step F7.5 (Phase 3.1): process reloc table (STREAMED). ---
                ; reloc_count from header.  0 = legacy FGX2 (no cross-bank
                ; calls); skip immediately so single-segment binaries
                ; built before slice 3.1 still work.
                ;
                ; The table is applied in FGX2_RELOC_BATCH-entry chunks through
                ; the small _ldRelocBuf: read a batch via Fs_ReadN (which advances
                ; the fd, so the next read picks up where this one stopped), walk
                ; it, repeat until _ldRelocRemain hits 0.  reloc_count is thus
                ; bounded only by its 16-bit header field — no cap, no big buffer.
                LDA     _ldHeader+FGX2_OFF_RELOCS
                STA     _ldRelocRemain
                ; BRANCH INVERTED AROUND A JMP: the reloc walk between here and
                ; @lf2_relocDone is past a BEQ's reach.
                BNE     @lf2_relocGo
                JMP     @lf2_relocDone
@lf2_relocGo    ANOP

@lf2_relocBatch ; batch = min(_ldRelocRemain, FGX2_RELOC_BATCH)
                LDA     _ldRelocRemain
                CMP     #FGX2_RELOC_BATCH+1
                BCC     @lf2_haveBatch
                LDA     #FGX2_RELOC_BATCH
@lf2_haveBatch  STA     _ldRelocCount            ; entries in THIS batch

                ; Read batch * FGX2_RELOC_ENTRY_SZ bytes from fd into _ldRelocBuf.
                ; Entry size is 4 → ASL twice.  Each batch overwrites the buffer;
                ; the fd advances across calls so we stream the whole table.
                ASL
                ASL
                STA     _ldTextBytes             ; bytes to read this batch
                SEP     #$20
                MX      %10
                _BANKK
_cfp421         STAL    _frnDstBank
                REP     #$20
                MX      %00
                LDA     #_ldRelocBuf
_cfp422         STAL    _frnDstOff
                LDA     _ldFd
                AND     #$00FF
                LDX     _ldTextBytes
                LDY     _ldIsVnode              ; UFS 2.4: a root fd
                BEQ     @bch_legacy              ;   reads in this bank
                JSR     _Ld_VnodeRead
                BRA     @bch_join
@bch_legacy
_cfp423         JSL     _FarSh_Fs_ReadN
@bch_join
                BCS     @lf2_batchGot
                JMP     @lf2_errCloseExtras
@lf2_batchGot   CPY     _ldTextBytes
                BEQ     @lf2_batchFull
                LDA     #EIO                     ; short read
                JMP     @lf2_errCloseExtras
@lf2_batchFull

                ; Walk _ldRelocBuf[0..batch-1].  For each entry:
                ;   src_bank = _BankForSeg(src_seg)
                ;   tgt_bank = _BankForSeg(tgt_seg)
                ;   write 1 byte (tgt_bank) at (src_bank : offset)
                ; using STAL via _libcTmp2 long pointer.
                STZ     _ldRelocIter
@lf2_relocL     LDA     _ldRelocIter
                CMP     _ldRelocCount
                BCS     @lf2_batchDone

                ; X = iter * 4 = byte offset into _ldRelocBuf for this entry.
                ASL
                ASL
                TAX

                ; Resolve src_seg → src_bank.
                SEP     #$20
                MX      %10
                ; A segment number the image does not have is a malformed
                ; image (apple/fgx#522): _BankForSeg would answer bank 0 for
                ; it and the patch would land there.  2.11BSD exec answers a
                ; malformed image with ENOEXEC.
                ; A loaded text's own patches are already in its banks.
                LDA     _ldRelocBuf+FGX2_RELOC_SRC_SEG,X
                CMP     _ldNSegs
                BCS     @lf2_relocBad
                TAY                              ; MX-B-OK: B is iter*4's high byte, 0 (a batch is 64)
                LDA     _ldTextList,Y
                BNE     @lf2_relocNext
                TYA
                JSR     _BankForSeg              ; A.lo in / A.lo out
                STA     _libcTmp2+2              ; long-ptr bank = src_bank
                REP     #$20
                MX      %00

                ; lo+mid bytes of long-ptr = the patch address: the offset
                ; within the src segment, from where that segment sits in
                ; its bank (its page; 0 unless it was placed).
                LDA     _ldRelocBuf+FGX2_RELOC_SRC_SEG,X
                AND     #$00FF
                TAY
                LDA     _ldSegPage,Y
                AND     #$00FF
                XBA
                CLC
                ADC     _ldRelocBuf+FGX2_RELOC_OFFSET,X
                STA     _libcTmp2

                ; Resolve tgt_seg → tgt_bank → 1 byte at (src_bank:offset).
                SEP     #$20
                MX      %10
                LDA     _ldRelocBuf+FGX2_RELOC_TGT_SEG,X
                BMI     @lf2_relocOff            ; FGX2_RELOC_ADDOFF
                CMP     _ldNSegs
                BCS     @lf2_relocBad
                JSR     _BankForSeg
                LDY     #0
                STA     [_libcTmp2],Y            ; patch single byte
@lf2_relocNext  REP     #$20
                MX      %00

                INC     _ldRelocIter
                BRA     @lf2_relocL
@lf2_relocBad   REP     #$20                     ; arrives M8
                MX      %00
                LDA     #ENOEXEC
                JMP     @lf2_errCloseExtras
                ; An offset relocation: add the target segment's page to the
                ; high byte of the word at src:offset, so the word gains the
                ; segment's load offset (page << 8).  A segment at $0000 of
                ; its bank adds nothing.
@lf2_relocOff   MX      %10
                AND     #$7F
                CMP     _ldNSegs
                BCS     @lf2_relocBad
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY
                SEP     #$20
                MX      %10
                LDA     _ldSegPage,Y
                BEQ     @lf2_relocNext
                LDY     #1
                CLC
                ADC     [_libcTmp2],Y
                STA     [_libcTmp2],Y
                BRA     @lf2_relocNext

@lf2_batchDone  ; _ldRelocRemain -= batch; another batch if any remain.
                ; (STA leaves the SBC's Z flag intact, so BNE tests the result.)
                LDA     _ldRelocRemain
                SEC
                SBC     _ldRelocCount
                STA     _ldRelocRemain
                ; BEQ+JMP AND NOT BNE: the reloc batch loop is now further away
                ; than a branch reaches, because the vnode arm at @bch_legacy
                ; grew the block between them.  Inverting and jumping is this
                ; tree's answer to a branch that outgrows its range.
                BEQ     @lf2_relocDone
                JMP     @lf2_relocBatch
@lf2_relocDone

                ; --- Step F7.6: a text just loaded fills its claimed entry. ---
                ; Its CODE segments other than the data segment go to the
                ; table: bank, first page, pages (0 = the whole bank).  The
                ; banks are then the text's, and leave this process's list.
                SEP     #$20
                MX      %10
                LDA     _ldTextNew
                BEQ     @lf2_txNoReg               ; a hit, or no entry
                LDX     #0
                LDY     #0                       ; Y = X*8, the segtab entry
@lf2_regL       LDA     _ldSegTable+FGX2_SEG_KIND,Y
                CMP     #SEG_KIND_CODE
                BNE     @lf2_regNext
                TXA
                CMP     _ldDataSegIdx
                BEQ     @lf2_regNext
                LDA     _ldExtraBanks,X
                STA     _ldTextList,X
                LDA     _ldSegPage,X
                STA     _ldTextList+8,X
@lf2_regNext    INY
                INY
                INY
                INY
                INY
                INY
                INY
                INY
                INX
                TXA
                CMP     _ldNSegs
                BCC     @lf2_regL
                REP     #$20
                MX      %00
                LDA     _ldTextIdx
                AND     #$00FF
                PHK
                PHK
                PLX
                LDY     #_ldTextList
_cfp1001        JSL     _FarSh_TextFill
                SEP     #$20
                MX      %10
                LDX     #FGX2_MAX_SEGS-1
@lf2_regOwn     LDA     _ldTextList,X
                BEQ     @lf2_regOwnN
                STZ     _ldExtraBanks,X
@lf2_regOwnN    DEX
                BPL     @lf2_regOwn
@lf2_txNoReg

                ; --- Step F8: entry = segment 0's bank : entry_offset. ---
                LDA     #0
                JSR     _BankForSeg
                STA     _ldUserBank
                STA     _ldEntry+2
                REP     #$20
                MX      %00
                LDA     _ldSegPage               ; segment 0's page
                AND     #$00FF
                XBA
                CLC
                ADC     _ldHeader+FGX2_OFF_ENTRY
                STA     _ldEntry                 ; low+mid bytes

                ; --- Step F9: close fd + success. ---
                LDA     _ldFd
                AND     #$00FF
_cfp424         JSL     _FarSh_Fs_Close
                SEC
                RTS

;------------------------------------------------------------------------------
; FGX2 error tails — all close the fd and free any extras before
; returning C=0 + A=errno.
;
; The errno is held on the STACK, not in _shTmp0.  fs.s says outright that
; "Fs_Close uses _shTmp0 internally for byte-offset scratch" -- so stashing the
; errno there and reloading it after the close returned whatever Fs_Close last
; left in that cell.  Every failure out of these tails reported a LIE, and the
; lie was consistently EBADF, which is Fs_Close's own error: apple/fgx#14 spent
; its whole investigation on fd handling because of it, when the real errno was
; EINVAL from the override-bank check.  A wrong errno is worse than no errno --
; it is a signpost pointing away from the fault.
;------------------------------------------------------------------------------
@lf2_errClose   ; A = errno (16-bit).  No extras allocated at this entry point.
                PHA
                LDA     _ldFd
                AND     #$00FF
_cfp425         JSL     _FarSh_Fs_Close
                PLA
                CLC
                RTS

@lf2_errCloseEIO ; A = raw value from inner call (0 = short read; non-0 =
                ; passthrough errno).  Map 0 → EIO.  No extras alloc'd
                ; yet either — F5 is before the segment loop.
                PHA
                LDA     _ldFd
                AND     #$00FF
_cfp426         JSL     _FarSh_Fs_Close
                PLA
                AND     #$00FF
                BNE     @lf2_errCloseEIO_pass
                LDA     #EIO
@lf2_errCloseEIO_pass
                CLC
                RTS

@lf2_errCloseExtras ; A = errno.  Free any banks in _ldExtraBanks before
                ; returning (override bank stays — spawn handles that).
                PHA
                JSR     _FreeExtras
                LDA     _ldFd
                AND     #$00FF
_cfp427         JSL     _FarSh_Fs_Close
                PLA
                CLC
                RTS

;==============================================================================
; _LoadOneSegment - bulk-copy one FGX2 segment from the open fd into a
; bank, then zero its BSS.
;
; Inputs: _ldDstBank = pre-set dst bank byte.
;         Y         = segment index (0..n-1).  Helper computes Y*8 to
;                     index _ldSegTable.
;         File pointer must be positioned at the segment's first byte.
;
; Outputs: C=1 on success.  C=0 + A=errno on failure.
;          File pointer advances past the segment's text bytes.
;          BSS bytes get zeroed at (_ldDstBank:after_text).
;==============================================================================
_LoadOneSegment MX      %00
                PHP
                REP     #$30
                MX      %00

                ; Compute segtable offset = Y * 8.
                TYA
                ASL
                ASL
                ASL
                TAX                              ; X = segIdx * 8
                LDA     _ldSegTable+FGX2_SEG_SIZE,X
                STA     _ldTextBytes
                LDA     _ldSegTable+FGX2_SEG_BSS,X
                STA     _ldBssBytes
                ; BSD sbrk seed: remember this segment's index and its `end`
                ; offset (text+bss) BEFORE the copy/BSS loops consume them, so
                ; if this is the DATA segment we seed the break cursor after the
                ; load (see @los_done).  end = text + bss = the data-bank offset
                ; the linker's `end` symbol equals.
                TYA
                STA     _ldSegIdxSave
                LDA     _ldTextBytes
                CLC
                ADC     _ldBssBytes
                STA     _ldEndOff

                ; Configure dst: the bank, at the segment's page (0 unless
                ; it was placed).  Y = the segment index still.
                SEP     #$20
                MX      %10
                LDA     _ldDstBank
_cfp428         STAL    _frnDstBank
                REP     #$20
                MX      %00
                LDA     _ldSegPage,Y
                AND     #$00FF
                XBA
_cfp429         STAL    _frnDstOff

                ; Bulk-copy seg.size bytes via Fs_ReadN loop.
                LDA     _ldTextBytes
                BEQ     @los_textDone
@los_copyL      LDA     _ldFd
                AND     #$00FF
                LDX     _ldTextBytes
                LDY     _ldIsVnode              ; UFS 2.4: a root fd
                BEQ     @los_legacy              ;   reads in this bank
                JSR     _Ld_VnodeRead
                BRA     @los_join
@los_legacy
_cfp430         JSL     _FarSh_Fs_ReadN
@los_join
                BCS     @los_copyOK
                ; A = errno from Fs_ReadN.
                PLP
                CLC
                RTS
@los_copyOK     CPY     #0
                BNE     @los_copyAdv
                LDA     #EIO                     ; short EOF
                PLP
                CLC
                RTS
@los_copyAdv    TYA
                EOR     #$FFFF
                SEC
                ADC     _ldTextBytes
                STA     _ldTextBytes
                BEQ     @los_textDone
                BRA     @los_copyL

@los_textDone   ; Zero seg.bss bytes after text.  _frnDstOff points at
                ; the first BSS byte already (Fs_ReadN bumped it).
                LDA     _ldBssBytes
                BEQ     @los_done
                ; THE COUNT RIDES THE STACK ACROSS THE BANK SWITCH.  It was
                ; re-read after the PLB, which made it an absolute -- so
                ; DBR-relative -- read of <DESTINATION bank>:_ldBssBytes rather
                ; than ours, and the loop then zeroed whatever that word said:
                ; nothing at all when it read zero, leaving BSS uninitialised,
                ; or up to 64 KB over the segment's own text when it did not.
                ; apple/fgx#211.
                PHA                             ; [count]
_cfp404         LDAL    _frnDstOff              ; core static; bank byte patched
                TAX
                SEP     #$20
                MX      %10
                LDA     _ldDstBank
                PHA
                PLB                              ; DBR = dst bank
                REP     #$20
                MX      %00
                PLA                             ; A = count, read from OUR bank
@los_bss_wL     CMP     #2
                BCC     @los_bss_tail
                STZ:    $0000,X
                INX
                INX
                DEC
                DEC
                BRA     @los_bss_wL
@los_bss_tail   CMP     #0
                BEQ     @los_bss_restore
                SEP     #$20
                MX      %10
                STZ:    $0000,X
                REP     #$20
                MX      %00
@los_bss_restore SEP    #$20
                MX      %10
                _DBRK
                REP     #$20
                MX      %00
@los_done       ; BSD sbrk seed: if this segment is the process's DATA segment,
                ; write the HEAP DESCRIPTOR at the top of the bank -- four words
                ; that make the heap self-describing, so the kernel can answer
                ; "how much has this task used" without keeping per-task state:
                ;
                ;   (dataBank:$FFF8) HEAP_LIM  = $FFF8, the heap's ceiling
                ;   (dataBank:$FFFA) HEAP_BASE = `end` (data+bss), fixed
                ;   (dataBank:$FFFC) HEAP_HWM  = highest break ever reached
                ;   (dataBank:$FFFE) HEAP_BRK  = the live break cursor
                ;
                ; BASE, HWM and BRK start at `end`.  _Sys_Brk reads them via
                ; TCB_DataBank and grows the heap [end, HEAP_LIM) -- the BSD
                ; contiguous data+bss+heap model the sh/tcsh blok.c arena
                ; assumes.  Seeded every spawn (8 bytes, harmless for the
                ; SYS_MALLOC-only tools that never call sbrk).  fgx_ld refuses
                ; a data segment that would end past $FFF8.
                ;
                ; HEAP_BASE and HEAP_HWM were added 2026-08-06 for apple/fgx#42.
                ; The break ALONE cannot answer the question that matters: a
                ; process that peaks during startup and frees looks idle
                ; afterwards, which is exactly how tcsh's login path reads and
                ; exactly the current-vs-high-water trap the bank-0 stack
                ; campaign already hit once (see Task_StkHwm).
                LDA     _ldSegIdxSave
                CMP     _ldDataSegIdx
                BNE     @los_noSeed
                ; Read `end` (a KERNEL-bank var) into A NOW, while DBR still points
                ; at the kernel bank -- then carry it across the DBR switch on the
                ; stack.  Reading _ldEndOff AFTER `PLB` to the data bank would
                ; fetch (dataBank:_ldEndOff) = garbage; that DBR mismatch was the
                ; bug that made the seed read $0000.
                LDA     _ldEndOff                ; A = end (this seg's text+bss)
                PHA                              ; carry across the DBR switch
                SEP     #$20
                MX      %10
                LDA     _ldDstBank
                PHA
                PLB                              ; DBR = data bank
                REP     #$20
                MX      %00
                PLA                              ; A = end (restored)
                STA:    $FFFE                    ; HEAP_BRK  = end
                STA:    $FFFC                    ; HEAP_HWM  = end (nothing used)
                STA:    $FFFA                    ; HEAP_BASE = end (fixed)
                LDA     #$FFF8
                STA:    $FFF8                    ; HEAP_LIM  = its seed: no region
                                                 ; above the heap
                SEP     #$20
                MX      %10
                _DBRK
                REP     #$20
                MX      %00
@los_noSeed     PLP
                SEC
                RTS

;==============================================================================
; _BankForSeg - look up a segment's bank byte by index.
;
; Input:  A.lo = segment index 0..7.  MX %10 (caller must SEP first).
; Output: A.lo = bank byte.  Bogus index returns 0.  X is preserved
; (PHX/PLX), so callers can keep iter*4 in X across the JSR.
;
; A segment the process owns is in _ldExtraBanks (the data segment's is the
; override); a loaded text's is in _ldTextList.
;
; Note: TAX with M=8/X=16 pulls hidden A.hi into X.hi.  Switch to M=16
; and AND #$00FF before TAX so X.hi is guaranteed zero.
;==============================================================================
_BankForSeg     MX      %10
                PHX                              ; preserve caller's X
                CMP     #FGX2_MAX_SEGS
                BCS     @bfs_bogus
                REP     #$20
                MX      %00
                AND     #$00FF                   ; kill hidden B for TAX
                TAX
                SEP     #$20
                MX      %10
                LDA     _ldExtraBanks,X
                BNE     @bfs_out
                LDA     _ldTextList,X
@bfs_out        PLX
                RTS
@bfs_bogus      LDA     #0
                PLX
                RTS

;==============================================================================
; _FreeExtras - undo a failed FGX2 load: free every bank _ldExtraBanks lists
; except the caller's override, drop a loaded text's reference, and zero the
; list.  Caller MX %00.
;==============================================================================
_FreeExtras     MX      %00
                PHP
                REP     #$30
                MX      %00

                ; The override, at the data segment, is the caller's to free;
                ; a loaded text's banks were never listed, and its reference
                ; goes back.
                SEP     #$20
                MX      %10
                LDX     _ldDataSegIdx            ; idx hi byte = 0
                STZ     _ldExtraBanks,X
                LDA     _ldTextIdx
                BEQ     @fe_noText
                STZ     _ldTextIdx
                REP     #$20
                MX      %00
                AND     #$00FF
_cfp1002        JSL     _FarSh_TextUnref
@fe_noText      REP     #$20
                MX      %00
                LDX     #FGX2_MAX_SEGS-1
@fe_free        LDA     _ldExtraBanks,X
                AND     #$00FF
                BEQ     @fe_next
                LDA     _ldTextList+16,X         ; placed: its pages go back
                AND     #$00FF
                BEQ     @fe_bank
                PHX
                PHA                              ; the page count
                SEP     #$20
                MX      %10
                LDA     _ldExtraBanks,X
                XBA
                LDA     _ldSegPage,X             ; C = bank << 8 | page
                REP     #$20
                MX      %00
                TAX
                PLA
_cfp1005        JSL     _FarSh_Core_Free
                PLX
                BRA     @fe_next
@fe_bank        LDA     _ldExtraBanks,X
                AND     #$00FF
_cfp432         JSL     _FarSh_Bank_Free         ; preserves X
@fe_next        DEX
                BPL     @fe_free
@fe_done        ; Zero entries 0-7 (4 words).
                LDA     #0
                STA     _ldExtraBanks+0
                STA     _ldExtraBanks+2
                STA     _ldExtraBanks+4
                STA     _ldExtraBanks+6
                PLP
                RTS

;==============================================================================
; _Loader_MeasureArgs - compute the exact size T of the argv/envp frame
; _Loader_StageArgs will lay, WITHOUT writing anything.  Same layout + same
; per-string cap (via _la_measureStr) => T matches the laid frame byte-for-byte.
; #45: (a) posix_spawn sizes the child stack to hold the frame ON TOP of the
; linker-sized C stack; (b) StageArgs gates on the floor BEFORE any write.
; Seeding is the CALLERS' job now (_Loader_StageArgs / _Loader_ArgsExtraPages
; each call _la_SeedFromBlk); this routine is reached only through them.
;
; Input  (MX %00): _la_argvPtr / _la_envpPtr and their banks, unpacked from the
;                  caller's arg-block by _la_SeedFromBlk (0 offset = empty).
; Output: _la_frameT = 4(resume) + 2(argc) + 2(argv NULL) + 2(envp NULL)
;                      + SUM(min(strlen,128)+1 +2 ptr slot).  Bounded LSARGV_MAX
;                      per array.  Matches _Loader_StageArgs's laid frame exactly.
;         Clobbers A/X/Y, _libcTmp2, _la_walk, _la_strSrc, _la_strLen,
;         _la_argc, _la_envc.
;==============================================================================
_Loader_MeasureArgs MX %00
                STZ     _la_strOvf              ; cleared per pass (#438)
                LDA     #4+2+2+2                ; resume + argc + argv/envp NULLs
                STA     _la_frameT
                STZ     _la_argc
                LDA     _la_argvPtr
                BEQ     @lma_env
                STA     _la_walk
                JSR     _la_UseArgvBank
@lma_argL       LDA     _la_argc
                CMP     #LSARGV_MAX
                BCS     @lma_env
                LDA     _la_walk
                JSR     _la_readVecEntry
                BEQ     @lma_env                ; NULL terminates
                STA     _la_strSrc
                JSR     _lma_addStr
                INC     _la_argc
                LDA     _la_walk
                CLC
                ADC     #4
                STA     _la_walk
                BRA     @lma_argL
@lma_env        STZ     _la_envc
                LDA     _la_envpPtr
                BEQ     @lma_done
                STA     _la_walk
                JSR     _la_UseEnvpBank
@lma_envL       LDA     _la_envc
                CMP     #LSARGV_MAX
                BCS     @lma_done
                LDA     _la_walk
                JSR     _la_readVecEntry
                BEQ     @lma_done
                STA     _la_strSrc
                JSR     _lma_addStr
                INC     _la_envc
                LDA     _la_walk
                CLC
                ADC     #4
                STA     _la_walk
                BRA     @lma_envL
@lma_done       RTS

; _lma_addStr - _la_frameT += strlen + 1 (NUL) + 2 (ptr slot).  A string that
; hit the scan ceiling pins T at $FFFF, which no stack can satisfy, so the
; floor gate returns E2BIG rather than anything being truncated.
_lma_addStr     MX      %00
                JSR     _la_measureStr
                LDA     _la_strOvf
                BEQ     @lma_as_fits
                LDA     #$FFFF
                STA     _la_frameT
                RTS
@lma_as_fits    LDA     _la_strLen
                CLC
                ADC     #1+2
                CLC
                ADC     _la_frameT
                STA     _la_frameT
                RTS

;==============================================================================
; _Loader_ArgsExtraPages - extra bank-0 stack pages the argv/envp frame needs,
; so posix_spawn can hold the frame ON TOP of the linker-sized C stack (#45).
; Input (MX %00): X = arg-block offset, Y = its bank.  Output: A = ceil(T/256).
; Clobbers per _Loader_MeasureArgs.
;==============================================================================
_Loader_ArgsExtraPages MX %00
                STX     _la_argBlk
                STY     _la_argBlkBank
                JSR     _la_SeedFromBlk
                JSR     _Loader_MeasureArgs     ; _la_frameT = T
                LDA     _la_frameT
                CLC
                ADC     #255
                XBA                             ; A >> 8 = ceil(T/256)
                AND     #$00FF
                RTS

;==============================================================================
; _Loader_StageArgs - lay out a BSD-shaped argv/envp frame on the child's
; stack page, then write the dispatcher resume frame below it.
;
; Inputs (caller MX %00):
;   X  = arg-block offset (BSD's `struct execa' less the path: argv then envp,
;        a far pointer each -- {offset16, bank, pad}; a 0 offset = empty)
;   Y  = the arg-block's own bank
;   _ps_childTCB     = child's TCB byte offset (caller-set in process.s)
;   _ldEntry         = child's 24-bit entry address (set by Load_Binary)
;
;   Each entry in the argv/envp arrays is a FAR pointer to a NUL-terminated
;   string (8-bit chars): {offset16, bank, pad}, fcc's layout.  An entry whose
;   offset is $0000 ends the array.  A string may live in ANY bank.
;
; Output:
;   C=1 + A = saved_S (16-bit) — caller stores in TCB_SavedS.  After PLB+RTL,
;             the child's S = saved_S+4 = byte just below argc.  Userland
;             reads argc as `LDA LSARGV_ARGC,S` (= LDA 1,S).
;   C=0 + A = errno (E2BIG if the layout would overflow the stack page, or if
;             argc/envc exceeds LSARGV_MAX -- BSD answers E2BIG for an
;             over-long arg list, `nc >= NCARGS-1' at Reno kern_exec.c:373).
;
; Bank-0 stack page = TCB_StackBase..TCB_StackBase+TCB_StackSize-1.
; Layout grows top-down:
;
;   <strings region: argv[0..argc-1] then envp[0..envc-1], NUL-term each>
;   envp NULL-terminator  (16-bit, low at lower addr)
;   envp[envc-1] ptr  ...  envp[0] ptr
;   argv NULL-terminator
;   argv[argc-1] ptr  ...  argv[0] ptr
;   argc                  (16-bit)
;   PB                    (resume frame; popped LAST by RTL)
;   PCH
;   PCL
;   DBR                   (popped FIRST by PLB)
;   <-- saved_S (= PB_addr - 4)
;
;==============================================================================
_Loader_StageArgs ENT
                MX      %00
                STX     _la_argBlk
                STY     _la_argBlkBank
                JSR     _la_SeedFromBlk
                ; The child's TCB offset, read across the bank boundary ONCE.
                ; A is free here; X and Y are the arguments and have just been
                ; parked, and LDAL touches neither.
_cfp442         LDAL    _ps_childTCB
                STA     _ldChildTCB

                ; Cache child bank from TCB.  _la_childBank = entry-bank
                ; PB; _la_dataBank = bank-of-n_data_segment for DBR-at-entry.
                ; For FGX1 / n_data_segment=0 binaries the two are identical.
                ; M=00 entering; X=16.
                LDX     _ldChildTCB
                SEP     #$20
                MX      %10
                ; THE TCB IS A CORE-BANK STRUCTURE, and every read of it here
                ; was `LDA: TCB_x,X' -- absolute, so DBR-relative.  That was
                ; right while this file ran in the core bank and is wrong now:
                ; DBR is the far bank for the whole of loader.s, so each of
                ; these was reading far-bank bytes at a core-bank offset.  It
                ; presented as init failing to load with E2BIG, because the
                ; first one the boot reaches is the stack-size gate and a
                ; garbage size fails that.
_cfp459       LDAL    TCB_CodeBank,X
                STA     _la_childBank
                ; Compute _la_dataBank = TCB_BankList[_ldDataSegIdx] without
                ; clobbering X (TCB offset can exceed $00FF for high task slots,
                ; so an 8-bit TXA round-trip would silently lose X.hi).  Use a
                ; 16-bit Y to widen the index and bridge into TCB_BankList,X
                ; via a temporary.
                REP     #$20
                MX      %00
                TXA                              ; A = TCB offset (16-bit)
                CLC
                ADC     _ldDataSegIdx            ; 16-bit add; idx hi byte = 0
                TAX                              ; X = TCB offset + idx
                SEP     #$20
                MX      %10
_cfp460       LDAL    TCB_BankList,X
                STA     _la_dataBank
                LDX     _ldChildTCB             ; restore original X for the
                                                 ; TCB_StackBase reads that follow
_cfp461       STAL    TCB_DataBank,X                    ; persist the REAL data bank into
                                                 ; the TCB (A still = the data-bank
                                                 ; byte; MX %10 here).  = seg1's bank
                                                 ; for FGX2 (n_data_segment>0); ==
                                                 ; CodeBank for FGX1.  Read back by
                                                 ; _waitpid_WriteStatus for the
                                                 ; cross-bank status store — spawn
                                                 ; only set TCB_DataBank = CodeBank.
                REP     #$20
                MX      %00

                ; Initial cursor = stack_top byte = base + size - 1.
_cfp462       LDAL    TCB_StackBase,X
                CLC
_cfp463       ADCL    TCB_StackSize,X
                DEC
                STA     _la_curAddr

                ; --- #45 PRE-WRITE floor gate.  Measure the frame size T and
                ;     require it to leave >= FCC_STK_FLOOR_MARGIN below saved_S
                ;     (saved_S = base+size-T; need saved_S >= base+MARGIN, i.e.
                ;     T <= size-MARGIN) BEFORE laying a single byte.  The old
                ;     tail check (below) ran AFTER the frame was already written,
                ;     so an oversized frame had already scribbled below StackBase
                ;     into the neighbouring task's arena.  posix_spawn sizes the
                ;     stack for the frame (ArgsExtraPages), so this only bites the
                ;     32-page clamp -> a clean E2BIG (POSIX "arg list too long").
                ;     FAIL-CLOSED / currently UNREACHABLE: max T = 10 +
                ;     2*LSARGV_MAX*(128+1+2) = 4202 B < (32 pages - MARGIN) = 8064,
                ;     and any request <=32 pages yields size >= T+256 by
                ;     construction — so no input trips this today.  It goes live
                ;     only if LSARGV_MAX or the per-string 128 cap ever grows;
                ;     keep it as the structural guard, not testable dead code.
                JSR     _Loader_MeasureArgs             ; _la_frameT = T
                LDX     _ldChildTCB
_cfp464       LDAL    TCB_StackSize,X
                SEC
                SBC     #FCC_STK_FLOOR_MARGIN
                CMP     _la_frameT                      ; (size-MARGIN) - T
                BCS     @lsa_roomOK                     ; size-MARGIN >= T
                LDA     #E2BIG
                CLC
                RTS
@lsa_roomOK

                ; --- Pass 1: walk caller's argv array, copy each string
                ;     down onto the child's stack page, remember its start
                ;     address. ---
                STZ     _la_argc
                LDA     _la_argvPtr
                BEQ     @lsa_argDone
                STA     _la_walk
                JSR     _la_UseArgvBank
@lsa_argL       ; Read 16-bit ptr at caller_bank[_la_walk]; NULL terminates.
                LDA     _la_walk
                JSR     _la_readVecEntry
                CMP     #0
                BEQ     @lsa_argDone
                STA     _la_strSrc
                ; Bounds check argc.
                LDA     _la_argc
                CMP     #LSARGV_MAX
                BCC     @lsa_argRoom
                LDA     #E2BIG
                CLC
                RTS
@lsa_argRoom    ; Copy this string onto the child's stack page (top-down).
                JSR     _la_copyStringDown      ; sets _la_startAddr = first-char addr
                ; Record start in argStrAddrs[argc].
                LDX     _la_argc
                TXA
                ASL
                TAX
                LDA     _la_startAddr
                STA     _la_argStrAddrs,X
                ; Bump argc.
                INC     _la_argc
                ; Advance walk by 2 (next ptr).
                LDA     _la_walk
                CLC
                ADC     #4
                STA     _la_walk
                BRA     @lsa_argL
@lsa_argDone

                ; --- Pass 2: same for envp. ---
                STZ     _la_envc
                LDA     _la_envpPtr
                BEQ     @lsa_envDone
                STA     _la_walk
                JSR     _la_UseEnvpBank
@lsa_envL       LDA     _la_walk
                JSR     _la_readVecEntry
                CMP     #0
                BEQ     @lsa_envDone
                STA     _la_strSrc
                LDA     _la_envc
                CMP     #LSARGV_MAX
                BCC     @lsa_envRoom
                LDA     #E2BIG
                CLC
                RTS
@lsa_envRoom    JSR     _la_copyStringDown
                LDX     _la_envc
                TXA
                ASL
                TAX
                LDA     _la_startAddr
                STA     _la_envStrAddrs,X
                INC     _la_envc
                LDA     _la_walk
                CLC
                ADC     #4
                STA     _la_walk
                BRA     @lsa_envL
@lsa_envDone

                ; --- Pass 3: emit envp NULL terminator + envp ptr table
                ;     (highest index first since we go down). ---
                LDA     #0
                JSR     _la_writeWordDown       ; envp[envc] = NULL
                LDA     _la_envc
                BEQ     @lsa_envPtrsDone
                LDX     _la_envc
                DEX
@lsa_envPtrL    PHX                             ; save loop index
                TXA
                ASL
                TAX
                LDA     _la_envStrAddrs,X
                JSR     _la_writeWordDown
                PLX
                DEX
                BPL     @lsa_envPtrL
@lsa_envPtrsDone

                ; --- argv NULL terminator + argv ptr table. ---
                LDA     #0
                JSR     _la_writeWordDown       ; argv[argc] = NULL
                LDA     _la_argc
                BEQ     @lsa_argPtrsDone
                LDX     _la_argc
                DEX
@lsa_argPtrL    PHX
                TXA
                ASL
                TAX
                LDA     _la_argStrAddrs,X
                JSR     _la_writeWordDown
                PLX
                DEX
                BPL     @lsa_argPtrL
@lsa_argPtrsDone

                ; --- argc word. ---
                LDA     _la_argc
                JSR     _la_writeWordDown

                ; --- Resume frame: PB, PCH, PCL, DBR (top to bottom of the
                ;     4 bytes; cur cursor is currently the address ABOVE PB).
                ;     We want PB at addr X, PCH at X-1, PCL at X-2, DBR at X-3.
                ;     _la_writeByteDown writes at _la_curAddr then decrements,
                ;     so emit in order PB → PCH → PCL → DBR.
                SEP     #$20
                MX      %10
                LDA     _la_childBank
                JSR     _la_writeByteDown       ; PB
                REP     #$20
                MX      %00
                LDA     _ldEntry                ; entry low word
                DEC                              ; entry-1 (RTL adds 1)
                XBA                              ; A.lo = high byte
                SEP     #$20
                MX      %10
                JSR     _la_writeByteDown       ; PCH
                REP     #$20
                MX      %00
                LDA     _ldEntry
                DEC
                SEP     #$20
                MX      %10
                JSR     _la_writeByteDown       ; PCL (A still holds low byte)
                LDA     _la_dataBank
                JSR     _la_writeByteDown       ; DBR (slice 4.5: may differ
                                                ; from PB when n_data_segment>0)
                REP     #$20
                MX      %00

                ; --- Final guard (now a defensive ASSERTION; the #45 pre-write
                ;     floor gate above already proved T <= size-MARGIN, so
                ;     saved_S >= base+MARGIN > base and this cannot fire unless
                ;     _Loader_MeasureArgs and the laid frame ever diverge).
                ;     cur_addr now points one byte below DBR; saved_S equals
                ;     cur_addr.  Return error if cur_addr < StackBase. ---
                LDX     _ldChildTCB
_cfp465       LDAL    TCB_StackBase,X
                CMP     _la_curAddr
                BEQ     @lsa_atBase
                BCS     @lsa_overflow
@lsa_atBase
                ; saved_S = _la_curAddr.
                LDA     _la_curAddr
                SEC
                RTS

@lsa_overflow   LDA     #E2BIG
                CLC
                RTS

;------------------------------------------------------------------------------
; _la_readVecEntry — read the 4-byte far pointer entry at _la_walkBank[A].
; Out: A = the string's 16-bit offset (0 ends the array), _la_strBank = its
; bank.  Entries are fcc far pointers, {offset16, bank, pad} -- see
; toolchain/src/cc/parse_expr.c:14 and crt0.s:163.  Caller MX %00; clobbers Y.
; Uses _libcTmp2 as a long pointer.
;------------------------------------------------------------------------------
; _la_SeedFromBlk - unpack the caller's arg-block into the four staging cells.
; The block is BSD's `struct execa' without the path: two far pointers, argv
; then envp, each {offset16, bank, pad}.  Reading it here is this tree's fuword
; -- the kernel walks an address the caller handed over instead of rebuilding
; one from a bank it recorded at trap time, which is why _Sys_CallerBank is no
; longer read on this path at all.
; In: _la_argBlk / _la_argBlkBank.  Caller MX %00.  Clobbers A/Y, _libcTmp2.
_la_SeedFromBlk MX      %00
                LDA     _la_argBlk
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _la_argBlkBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDY     #0
                LDA     [_libcTmp2],Y           ; +0 argv offset
                STA     _la_argvPtr
                LDY     #4
                LDA     [_libcTmp2],Y           ; +4 envp offset
                STA     _la_envpPtr
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_libcTmp2],Y           ; +2 argv bank
                STA     _la_argvBank
                LDY     #6
                LDA     [_libcTmp2],Y           ; +6 envp bank
                STA     _la_envpBank
                REP     #$20
                MX      %00
                RTS

; _la_UseArgvBank / _la_UseEnvpBank - point the vector walk at one array's
; bank.  The STRING bank is not set here; _la_readVecEntry takes it per entry.
; Called at the head of each of the four walks rather than once per staging
; call: _Loader_StageArgs runs _Loader_MeasureArgs first,
; which leaves the envp bank selected, so pass 1 must reselect argv's.
; Caller MX %00.  Clobbers A.
_la_UseArgvBank MX      %00
                SEP     #$20
                MX      %10
                LDA     _la_argvBank
                STA     _la_walkBank
                REP     #$20
                MX      %00
                RTS

_la_UseEnvpBank MX      %00
                SEP     #$20
                MX      %10
                LDA     _la_envpBank
                STA     _la_walkBank
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
_la_readVecEntry MX    %00
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _la_walkBank
                STA     _libcTmp2+2
                LDY     #2
                LDA     [_libcTmp2],Y           ; entry+2 = the string's BANK
                STA     _la_strBank
                REP     #$20
                MX      %00
                LDA     [_libcTmp2]             ; entry+0 = the string's offset
                RTS

;------------------------------------------------------------------------------
; _la_copyStringDown — copy a NUL-terminated string from caller_bank[_la_strSrc]
; onto the child's stack page, "growing DOWN" (highest dst byte goes first).
;
; Layout effect (curAddr is "next free byte going down"):
;   IN:  _la_curAddr = X   (the NUL goes here)
;   OUT: _la_curAddr = X - strLen - 1
;        bank0[X] = 0                     (NUL terminator)
;        bank0[X - strLen + 0] = src[0]   (first char of the string)
;        ...
;        bank0[X - 1] = src[strLen-1]
;        _la_startAddr = X - strLen       (first-char address; recorded by caller)
;
; Caller MX %00.  Clobbers A/X/Y, _libcTmp2, _la_strLen, _la_startAddr.
;------------------------------------------------------------------------------
; _la_measureStr - _la_strLen = strlen(caller_bank[_la_strSrc]), bounded by
; LSARG_STRMAX, and LEAVE _libcTmp2 = caller_bank:strSrc set (so
; _la_copyStringDown reuses it for the copy).  The SAME routine is called by
; _Loader_MeasureArgs so the pre-alloc page estimate cannot drift from what
; gets laid down here (#45).  Caller + exit MX %00.
;
; IT NO LONGER TRUNCATES (apple/fgx#438).  The bound was 128 and a longer
; string was silently shortened, so a program was handed an argument that was
; not the one its caller passed -- the same silent-truncation shape as
; apple/fgx#436, one layer up.  Reaching the ceiling sets `_la_strOvf' now, and
; _lma_addStr turns that into a frame size nothing can satisfy, so the
; pre-write floor gate answers E2BIG.
_la_measureStr  MX      %00
                LDA     _la_strSrc
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _la_strBank
                STA     _libcTmp2+2
                LDY     #0
@lms_L          LDA     [_libcTmp2],Y
                BEQ     @lms_done
                INY
                CPY     #LSARG_STRMAX           ; scan ceiling, not a cap
                BCC     @lms_L
                ; No NUL inside the ceiling: record it and let the gate refuse.
                REP     #$20
                MX      %00
                STY     _la_strLen
                LDA     #1
                STA     _la_strOvf
                RTS
@lms_done       REP     #$20
                MX      %00
                STY     _la_strLen              ; = strlen; hi byte 0
                RTS

_la_copyStringDown MX  %00
                JSR     _la_measureStr          ; _la_strLen + _libcTmp2 = src

                ; firstChar_addr = curAddr - strLen.
                LDA     _la_curAddr
                SEC
                SBC     _la_strLen
                STA     _la_startAddr

                ; Write NUL at curAddr.
                SEP     #$20
                MX      %10
                LDX     _la_curAddr
                LDA     #0
_la_stal1      STAL    $000000,X

                ; Copy strLen bytes from caller[strSrc + Y] to
                ; bank0[startAddr + Y] for Y = 0..strLen-1.
                REP     #$20
                MX      %00
                LDY     _la_strLen
                BEQ     @lcs_finish
@lcs_copyL      DEY                             ; Y goes strLen-1 .. 0
                SEP     #$20
                MX      %10
                LDA     [_libcTmp2],Y           ; read source byte
                STA     _la_byteScratch         ; park it in M=1
                REP     #$20
                MX      %00
                ; Compute dst = startAddr + Y.
                TYA
                CLC
                ADC     _la_startAddr
                TAX
                SEP     #$20
                MX      %10
                LDA     _la_byteScratch
_la_stal2      STAL    $000000,X
                REP     #$20
                MX      %00
                ; Loop until Y = 0 (after this iteration).
                CPY     #0
                BNE     @lcs_copyL

@lcs_finish     ; cur_addr = startAddr - 1.
                LDA     _la_startAddr
                DEC
                STA     _la_curAddr
                RTS

;------------------------------------------------------------------------------
; _la_writeWordDown — write 16-bit value in A at bank0[curAddr-1..curAddr]
; (high byte at curAddr, low at curAddr-1).  Decrement curAddr by 2.
; Caller MX %00.  Clobbers X/_la_byteScratch.  Preserves A.
;------------------------------------------------------------------------------
_la_writeWordDown MX   %00
                STA     _la_byteScratch
                ; High byte at curAddr.
                LDX     _la_curAddr
                SEP     #$20
                MX      %10
                LDA     _la_byteScratch+1
_la_stal3      STAL    $000000,X
                ; Low byte at curAddr-1.
                REP     #$20
                MX      %00
                LDA     _la_curAddr
                DEC
                TAX
                SEP     #$20
                MX      %10
                LDA     _la_byteScratch
_la_stal4      STAL    $000000,X
                REP     #$20
                MX      %00
                ; cur_addr -= 2.
                LDA     _la_curAddr
                DEC
                DEC
                STA     _la_curAddr
                LDA     _la_byteScratch
                RTS

;------------------------------------------------------------------------------
; _la_writeByteDown — write low byte of A at bank0[curAddr], decrement curAddr.
; Caller MX %10 (M=1, X=0).  Clobbers X.  Preserves A.
;------------------------------------------------------------------------------
_la_writeByteDown MX   %10
                STA     _la_byteScratch
                REP     #$20
                MX      %00
                LDX     _la_curAddr
                SEP     #$20
                MX      %10
                LDA     _la_byteScratch
_la_stal5      STAL    $000000,X
                REP     #$20
                MX      %00
                LDA     _la_curAddr
                DEC
                STA     _la_curAddr
                SEP     #$20
                MX      %10
                LDA     _la_byteScratch
                RTS

;==============================================================================
; END loader.s
;==============================================================================


;------------------------------------------------------------------------------
; _La_SetStageBase - point every StageArgs stack write at the 24-bit base A:Y.
;
; The five stores are `STAL base,X` with X a bank-0 stack address, and the
; base is $000000 for an ordinary carve.  A range placed while somebody pinned
; still holds it is built in the task's HOME instead (task.s _Uimg_StageAt):
; then the base is the 24-bit difference between the home copy and the range,
; and the frame's absolute bank-0 pointers are just data that become correct
; the moment the scheduler copies the image in.
;
; In: A = base bytes 0-1, Y = byte 2 (the bank).  MX %00.  Clobbers A.
;------------------------------------------------------------------------------
_La_SetStageBase ENT
                MX      %00
                STA     _la_stal1+1
                STA     _la_stal2+1
                STA     _la_stal3+1
                STA     _la_stal4+1
                STA     _la_stal5+1
                PHP
                SEP     #$20
                MX      %10
                TYA
                STA     _la_stal1+3
                STA     _la_stal2+3
                STA     _la_stal3+3
                STA     _la_stal4+3
                STA     _la_stal5+3
                PLP
                RTS
