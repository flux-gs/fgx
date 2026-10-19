;==============================================================================
; modload.s - FGXM module loader.
;
; Public:
;   Mod_Load     X = path ptr (16-bit, kernel-bank; $02 = assembly ORG).
;                A.lo = bank_override (0 = call Bank_Alloc; non-zero = use this).
;                Reads <path>, validates 'FGXM' magic and the kernel build
;                identity, claims its byte range in the SHARED module bank,
;                copies text to (bank):load_addr+FGXM_HEADER_SZ, zero-fills
;                bss after, walks
;                vtdir until VT_END (Phase 2a does not store entries),
;                JSLs (bank):entry_offset.  Module init must return C=1.
;                C=1 on success.  C=0 + A=errno on failure
;                (ENOENT, ENOEXEC, EIO, EINVAL, ENOMEM).
;
;   Mod_LoadConf Read /etc/modload.conf, Mod_Load each named module.
;                Skip blanks + comments (lines whose first non-WS char is '#').
;                On any per-line failure: kern-log + yellow border + continue.
;                C=1 always (overall failure is non-fatal at boot).
;
; Internals: parallels src/kernel/loader.s.  Each Mod_Load call uses the
; kernel-bank static block below; calls are NOT re-entrant.
;==============================================================================

;------------------------------------------------------------------------------
; Module-local state (kernel-bank static, one Mod_Load call lifetime).
;------------------------------------------------------------------------------
_mlFd           DS      2               ; open fd from Fs_Open
_mlHeader       DS      FGXM_HEADER_SZ  ; cached 40-byte header (v2; it was 16
                                        ;   when this comment was written)
_mlEntry        DS      3               ; 24-bit entry address (output)
_mlBank         DS      1               ; load bank (output)
_mlTextBytes    DS      2               ; remaining bytes to copy
_mlBssBytes     DS      2               ; remaining bytes to zero
_mlVtdirOff     DS      2               ; vtdir byte offset within text
_mlOverrideBank DS      1               ; caller-supplied bank override (0=alloc)
_mlPlaceAny     DS      1               ; 0 = the caller MVN'd the image to
                                        ;   offset 0 and cannot do otherwise
                                        ;   (stage 2); non-zero = the caller
                                        ;   honoured the header's placement
                                        ;   offset, so any is fine.  Set by the
                                        ;   SYS_MODLOAD streaming path, which
                                        ;   CAN place, and which every module
                                        ;   in modload.conf needs: they are
                                        ;   placed, not pre-staged (SERIAL
                                        ;   off=$4800, HELLO off=$5C00).
_mlHdrBank      DS      1               ; where the 40-byte header is READ FROM.
_mlHdrOff       DS      2               ;   The pre-stage's image begins at
                                        ;   <bank>:$0000 and this is set to it;
                                        ;   a STREAMED module's header is still
                                        ;   in the CALLER's buffer, because
                                        ;   nothing may be written into a module
                                        ;   bank until the header has been
                                        ;   validated and its range claimed.
_mlBankFresh    DS      1               ; non-zero if THIS load allocated the
                                        ;   bank, so an abort knows whether it
                                        ;   may hand it back.  A module joining
                                        ;   an ordinal already in use must not.
_mlLoadOff      DS      2               ; header load_addr, low 16 bits: WHERE IN
                                        ; THE BANK this module was assembled to
                                        ; live (src/modules/<m>/modplace.s)
_mlTextBase     DS      2               ; _mlLoadOff + FGXM_HEADER_SZ = first
                                        ; text byte's bank-relative offset
_mlVtdirAbsLo   DS      2               ; vtdir absolute offset = load + vtdir_off
_mlVtdirAbsBank DS      1               ; bank of vtdir (= _mlBank)
_mlWalkVType    DS      2               ; current entry's vtype (during walk)
_mlWalkVOffset  DS      2               ; current entry's voffset (during walk)
_mlWalkTmp      DS      4               ; scratch for entry-offset math.  FOUR
                                        ; bytes, not two: Mod_FindVtable uses
                                        ; both _mlWalkTmp and _mlWalkTmp+2, and
                                        ; at DS 2 that second slot WAS _mlcFd
                                        ; (the next static), i.e. an
                                        ; out-of-bounds write into Mod_LoadConf's
                                        ; live conf fd.

;------------------------------------------------------------------------------
; Mod_LoadConf state.  Separate from Mod_Load's _ml* slots so Mod_LoadConf
; can keep its conf fd open across a nested Mod_Load call.
;------------------------------------------------------------------------------
_MLC_PFX_LEN    EQU     13              ; length of "/lib/modules/" (no NUL)
_MLC_PATH_MAX   EQU     64              ; full path buffer size

_mlcFd          DS      2               ; conf fd
_mlcChar        DS      2               ; current Fs_Read byte (high byte 0)
_mlcState       DS      2               ; parse state (16-bit cell): 0/1/2/3
_mlcHaveErr     DS      2               ; sticky "saw a Mod_Load failure" flag
_mlcWriteIdx    DS      2               ; write position within _mlcPathBuf
_mlcPathBuf     DS      _MLC_PATH_MAX   ; "/lib/modules/<name>",NUL

;------------------------------------------------------------------------------
; THE SHARED MODULE BANK.  Every module lives in this one bank, at the fixed
; offset its FGXM header carries (src/modules/<m>/modplace.s, generated).  One
; bank per module was
; costing a 64 KB bank for a 2 KB driver -- 17 KB of module code spread over
; four banks.
;
; Latched from whichever module lands first: the pre-staged one if the boot
; loader staged any (Mod_RegisterPreLoaded), otherwise the first Bank_Alloc
; Mod_Load does.  $00 = not yet claimed.
;
; NOTE it is never freed.  A module whose init fails used to hand its bank
; back; it cannot now, because the bank is not its to hand back -- its
; neighbours are in it.  The slot stays idle instead, which costs nothing: the
; slot is statically assigned to that module and nothing else would use it.
;------------------------------------------------------------------------------
; ONE REAL BANK PER ORDINAL.  A module's FGXM load-address HIGH BYTE is a bank
; ORDINAL, not a bank: $05 means "the shared bank", $06 "the second", and so on
; (tools/gen_modplace.py OWN_BANK).  A module cannot name a real bank -- it does
; not know which one it will get -- so it names a chain, and this table maps the
; chain to the bank actually allocated for it.  0 = not allocated yet.
;
; ORDINAL 0 IS THE SHARED BANK and keeps its old name, because that is what the
; DBR-restore path and hellofail's fixture comment refer to.
; SEVEN: the shared bank, vfs, ufs, ufsprobe, ufsdir, prodos and prodosw.  The
; parse below bounds-checks against this, so raising it is the whole change --
; but note the table GROWS, which moves every kernel static after it, and the
; MAME harness resolves _modBankTab by address (the probe-address-rot class).
MOD_BANK_MAX    EQU     7
_modBankTab     DS      MOD_BANK_MAX
_modSharedBank  EQU     _modBankTab
_mlBankOrd      DS      2               ; this load's ordinal, parsed from the
                                        ;   header's load-address high byte

;------------------------------------------------------------------------------
; WHICH BYTE RANGES OF THE SHARED BANK ARE OCCUPIED.
;
; The one fact about the shared bank that module images cannot be trusted for.
; Mod_Load places each image at the offset ITS OWN HEADER carries, so an image
; built against a different LAYOUT lands on top of a neighbour that is already
; loaded and RUNNING -- and the build identity cannot catch that, because it
; samples KERNEL addresses and a module-only change leaves the kernel (and so
; the id) identical.  Under one-bank-per-module the blast radius of a bad
; image was the module itself; now it is every module.
;
; 16 entries: thirteen modules load today, across every chain.  Overflow
; REFUSES rather than skipping the check, and the refusal names the module.
;------------------------------------------------------------------------------
MOD_EXT_MAX     EQU     16
_modExtCount    DS      2               ; entries in use
_modExtLo       DS      MOD_EXT_MAX*2   ; start offset, inclusive
_modExtHi       DS      MOD_EXT_MAX*2   ; end offset, exclusive
; ...AND WHICH BANK EACH RANGE IS IN.  Without this the check is wrong in the
; direction that matters once there is a second bank: two modules at the same
; offset in DIFFERENT banks do not overlap, and reporting them as a collision
; would refuse a perfectly good image.  An offset alone stopped being an
; identity the moment a second chain existed.
; Sized *2 and indexed by the SAME byte index the offset arrays use, rather
; than by entry number.  Half of it is unused; that costs 12 bytes of kernel
; data and saves an index division inside the scan loop, which is the kind of
; arithmetic that goes wrong quietly.
_modExtBank     DS      MOD_EXT_MAX*2
_mceEnd         DS      2               ; scratch: this module's end offset
_mlSaveExtCount DS      2               ; load-failure rollback (5.3a): _modExtCount
                                        ;   and _modRegCount as they were when this
                                        ;   Mod_Load began.  Both tables are
                                        ;   append-only and nothing else appends
                                        ;   between, so truncating back to these is
                                        ;   a complete undo.
_mlSaveRegCount DS      2
_mlSaveValid    DS      1               ; the two counters above hold a snapshot
                                        ;   for the load IN PROGRESS.  Without
                                        ;   it an abort restores whatever the
                                        ;   last completed load left there --
                                        ;   SYS_MODLOAD's `begin' can be
                                        ;   followed by `abort' with no header
                                        ;   chunk between, and modload(8) does
                                        ;   exactly that on a short read.

;==============================================================================
; Mod_Load - load and validate an FGXM module binary.
;
; Input:  X = ptr to NUL-term path string in kernel-bank ($02 = ORG).  MX %00.
;         A.lo = bank_override.  0 = Bank_Alloc a fresh bank.  Non-zero =
;                load into that exact bank (used by Phase 2b's bootstrap
;                path so prodos.mod lands in FGX_BANK_KMOD_FIRST, currently
;                $05; see include/kernel.s).
; Output: C=1 + _mlEntry / _mlBank populated; module's mod_init ran and
;                returned C=1.
;         C=0 + A = errno (ENOENT/ENOEXEC/EIO/EMFILE/ENOMEM/EINVAL).
;==============================================================================
Mod_Load        ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00

                ;--- Stash override bank (low byte; 0 = use Bank_Alloc) ---
                SEP     #$20
                MX      %10
                STA     _mlOverrideBank
                REP     #$20
                MX      %00

                ;--- Load-failure rollback (5.3a): remember what the extent
                ; and vtable-registry tables looked like before this load, so
                ; any failure below can put them back.  Taken here rather than
                ; at each append so there is ONE place to keep right.
                LDA     _modExtCount
                STA     _mlSaveExtCount
                LDA     _modRegCount
                STA     _mlSaveRegCount
                SEP     #$20
                MX      %10
                LDA     #1
                STA     _mlSaveValid
                REP     #$20
                MX      %00

                ;--- Step 1: Fs_Open(X = path) -> C=1+A=fd, C=0+A=errno ---
                JSR     Fs_Open
                BCS     @ml_opened
                JMP     @ml_passErr
@ml_opened      AND     #$00FF
                STA     _mlFd

                ;--- Step 2: Read 16-byte header into _mlHeader ---
                SEP     #$20
                MX      %10
                _BANKK
                STA     _frnDstBank
                REP     #$20
                MX      %00
                LDA     #_mlHeader
                STA     _frnDstOff
                LDA     _mlFd
                AND     #$00FF
                LDX     #FGXM_HEADER_SZ
                JSR     Fs_ReadN                ; C=1+Y=bytes; C=0+A=errno
                BCS     @ml_hdrGot
                JMP     @ml_eioClose
@ml_hdrGot      CPY     #FGXM_HEADER_SZ
                BEQ     @ml_hdrFull
                LDA     #$0000                  ; short read -> EIO
                JMP     @ml_eioClose
@ml_hdrFull
                ;--- Step 3: Validate magic 'FGXM' = $46 $47 $58 $4D ---
                ; RELOC: Step 2 Fs_ReadN'd the header into the LIVE kernel bank
                ; (_frnDstBank=_BANKK) and its _DBRK left DBR=kernel bank, so
                ; read the header DBR-relative (|abs) — NOT LDAL.  The $02 copy
                ; of _mlHeader holds a STALE header (prodos's, written there by
                ; Mod_RegisterPreLoaded's STAL); LDAL would parse every module
                ; with prodos's text size, truncating the text copy.
                LDA    |_mlHeader+0
                CMP     #$4746                  ; "FG"
                BEQ     @ml_magicHi
                JMP     @ml_enoexec
@ml_magicHi     LDA    |_mlHeader+2
                CMP     #$4D58                  ; "XM"
                BEQ     @ml_magicOK
                JMP     @ml_enoexec
@ml_magicOK
                ;--- Step 3a: Name + build identity (see _Mod_CheckBuild) ---
                JSR     _Mod_CheckBuild
                BCS     @ml_buildOK
                JMP     @ml_enoexec             ; refused; closes the fd
@ml_buildOK

                ;--- Step 4: Parse fields ---
                ; text size into _mlTextBytes
                LDA    |_mlHeader+FGXM_OFF_TEXT
                STA     _mlTextBytes
                ; bss size into _mlBssBytes
                LDA    |_mlHeader+FGXM_OFF_BSS
                STA     _mlBssBytes
                ; vtdir offset within text into _mlVtdirOff
                LDA    |_mlHeader+FGXM_OFF_VTDIR
                STA     _mlVtdirOff
                ; load_addr's LOW 16 BITS = where in the bank this module was
                ; assembled to live (include/modplace.s via the generated
                ; modplace.s).  This field was "informational only, ignored"
                ; while every module owned a whole bank and sat at offset 0;
                ; now it is the placement, and getting it wrong puts every
                ; absolute reference in the image out by the difference.
                LDA    |_mlHeader+FGXM_OFF_LOAD
                STA     _mlLoadOff
                CLC
                ADC     #FGXM_HEADER_SZ
                STA     _mlTextBase             ; first text byte in the bank
                ; load_addr's HIGH BYTE is the BANK ORDINAL, not a bank: the
                ; assembly convention $05 is ordinal 0 (the shared bank), $06 is
                ; ordinal 1, and so on.  It was ignored while there was only one
                ; bank.  A module names a CHAIN here because it cannot name a
                ; bank -- it does not know which one it will be given.
                SEP     #$20
                MX      %10
                LDA    |_mlHeader+FGXM_OFF_LOAD+2
                SEC
                SBC     #FGX_MOD_ORG_BANK       ; $05 -> 0
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     _mlBankOrd
                CMP     #MOD_BANK_MAX
                BCC     @ml_ordOK
                ; An ordinal past the table is a module built against a layout
                ; this kernel does not have.  Refuse rather than index off the
                ; end -- the read would be some other static and the module
                ; would load into whatever bank that byte happened to hold.
                LDA     #ENOEXEC
                JMP     @ml_errA
@ml_ordOK       ANOP

                ;--- Step 4a: claim the byte range, before anything is written ---
                JSR     _Mod_ClaimExtent
                BCS     @ml_extentOK
                JMP     @ml_enoexec             ; refused; closes the fd
@ml_extentOK

                ;--- Step 5: Pick destination bank ---
                ; Override (if non-zero), else THE SHARED MODULE BANK: claimed
                ; once and reused, because every module has its own offset
                ; inside it (Step 4's _mlLoadOff).  One bank per module was
                ; spending 64 KB on a 2 KB driver.
                ; The ordinal selects WHICH chain's bank; within a chain the
                ; first module to load claims it and every later one joins.
                SEP     #$20
                MX      %10
                LDA     _mlOverrideBank
                BNE     @ml_useOverride
                LDX     _mlBankOrd
                LDA     _modBankTab,X
                BNE     @ml_useShared
                REP     #$20
                MX      %00
                JSR     Bank_Alloc              ; C=1+A=bank, C=0+A=ENOMEM
                BCS     @ml_bankFresh
                ; ENOMEM: close + propagate.  THE ERRNO RIDES THE STACK:
                ; Fs_Close reaches _Fcb_LookupPtr, whose scratch cell IS
                ; _shTmp0 (fcb.s:628 warns this caller by name), so the reload
                ; used to hand back Fs_Close's errno instead of Bank_Alloc's.
                PHA
                LDA     _mlFd
                AND     #$00FF
                JSR     Fs_Close
                PLA
                AND     #$00FF
                JMP     @ml_errA
                ; First module to load in THIS ORDINAL's chain: the bank it
                ; gets becomes that chain's bank, and every later module with
                ; the same ordinal joins it.
@ml_bankFresh   SEP     #$20
                MX      %10
                LDX     _mlBankOrd
                STA     _modBankTab,X
                REP     #$20
                MX      %00
                BRA     @ml_bankOK
@ml_useShared   REP     #$20
                MX      %00
                AND     #$00FF
                BRA     @ml_bankOK
@ml_useOverride REP     #$20
                MX      %00
                LDA     _mlOverrideBank
                AND     #$00FF
@ml_bankOK      SEP     #$20
                MX      %10
                STA     _mlBank
                REP     #$20
                MX      %00

                ;--- Step 6: Set up dst for text copy ---
                ; dst = (bank):_mlTextBase, i.e. this module's own offset in the
                ; shared bank plus the header gap.
                SEP     #$20
                MX      %10
                LDA     _mlBank
                STA     _frnDstBank
                REP     #$20
                MX      %00
                LDA     _mlTextBase
                STA     _frnDstOff

                ;--- Step 7: Bulk-copy _mlTextBytes from fd into (bank) ---
                LDA     _mlTextBytes
                BEQ     @ml_copyDone
@ml_copyChunk   LDA     _mlFd
                AND     #$00FF
                LDX     _mlTextBytes
                JSR     Fs_ReadN                ; C=1+Y=copied, C=0+A=errno
                BCS     @ml_copyOK
                JMP     @ml_eioClose
@ml_copyOK      CPY     #0
                BNE     @ml_copyAdv
                LDA     #$0000                  ; short EOF -> EIO
                JMP     @ml_eioClose
@ml_copyAdv     TYA
                EOR     #$FFFF
                SEC
                ADC     _mlTextBytes
                STA     _mlTextBytes
                BEQ     @ml_copyDone
                BRA     @ml_copyChunk
@ml_copyDone
                ;--- Step 8: Zero _mlBssBytes bytes after text ---
                ; _frnDstOff currently points at first BSS byte (Fs_ReadN
                ; left it advanced past the copied text).
                LDA     _mlBssBytes
                BEQ     @ml_bssDone

                LDX     _frnDstOff
                SEP     #$20
                MX      %10
                LDA     _mlBank
                PHA
                PLB                             ; DBR = module bank
                REP     #$20
                MX      %00
                LDA     _mlBssBytes
@ml_bss_wL      CMP     #2
                BCC     @ml_bss_tail
                STZ:    $0000,X                 ; clear 16-bit word at DBR:X
                INX
                INX
                DEC
                DEC
                BRA     @ml_bss_wL
@ml_bss_tail    CMP     #0
                BEQ     @ml_bss_restore
                SEP     #$20
                MX      %10
                STZ:    $0000,X                 ; clear final byte
                REP     #$20
                MX      %00
@ml_bss_restore SEP     #$20
                MX      %10
                _DBRK
                REP     #$20
                MX      %00
@ml_bssDone
                ;--- Step 9: Validate VTDR magic + walk until VT_END ---
                ; vtdir offset within (bank) = _mlTextBase + _mlVtdirOff
                ; (vtdir_off is "within text", and text starts at this module's
                ;  placement offset plus the header gap).
                LDA     _mlVtdirOff
                CLC
                ADC     _mlTextBase
                STA     _mlVtdirAbsLo           ; stored in kernel-bank
                SEP     #$20
                MX      %10
                LDA     _mlBank
                STA     _mlVtdirAbsBank
                REP     #$20
                MX      %00

                ; IMPORTANT: load X from kernel-bank statics BEFORE switching
                ; DBR.  Once DBR = module bank, reads from _mlVtdir* would
                ; pull garbage from the module's bank instead of kernel data.
                LDX     _mlVtdirAbsLo           ; X = vtdir (under DBR=kernel-bank)

                ; The walk converts each TEXT-relative voffset to BANK-relative
                ; by adding _mlTextBase -- but it runs with DBR = module bank,
                ; where a kernel static cannot be read DBR-relative and an
                ; absolute-long read would need a new Wave-E patch site.  Park
                ; the base on the stack instead and add it with `ADC 1,S`.
                ; Popped at BOTH exits (@ml_vtdr_bad and @ml_vtdr_done).
                LDA     _mlTextBase
                PHA

                ; Switch DBR to module bank for VTDR reads.
                SEP     #$20
                MX      %10
                LDA     _mlVtdirAbsBank
                PHA
                PLB
                REP     #$20
                MX      %00

                ; Read 4-byte VTDR magic at (DBR=mod_bank):X
                LDA:    $0000,X                 ; low word "VT" = $5456
                CMP     #VTDR_MAGIC_LO
                BEQ     @ml_vtdrHi
                JMP     @ml_vtdr_bad
@ml_vtdrHi      LDA:    $0002,X
                CMP     #VTDR_MAGIC_HI
                BEQ     @ml_vtdrOK
                JMP     @ml_vtdr_bad
@ml_vtdrOK
                ; Walk (vtype, voffset) tuples until VT_END.
                ; cursor (X) = current dir offset; starts at vtdirAbsLo+4
                ; (past 'VTDR' magic).  We keep DBR = module bank and only
                ; use X to track position; no reads from kernel-bank statics.
                TXA
                CLC
                ADC     #4
                TAX                             ; X = vtdirAbsLo + 4
@ml_vtdr_loop   LDA:    $0000,X                 ; vtype (DBR = mod_bank)
                CMP     #VT_END
                BEQ     @ml_vtdr_done
                ; Stash (vtype, voffset) for the registry append.
                ; STAL uses absolute long so DBR=mod_bank doesn't matter.
_we002          STAL    _mlWalkVType
                LDA:    $0002,X
                ; voffset in the VTDR entry is TEXT-relative (offset from
                ; module_text == load_addr + FGXM_HEADER_SZ).  Convert to
                ; BANK-relative so dispatchers can form [bank:voffset]
                ; directly without remembering the header gap OR this module's
                ; placement offset.  The base is on the stack (see above); this
                ; was `ADC #FGXM_HEADER_SZ` while every module sat at offset 0.
                CLC
                ADC     1,S
_we003          STAL    _mlWalkVOffset
                ; Append to registry.  Helper uses _mlWalk* + _mlBank.
                PHX
                JSR     _Mod_RegistryAppend
                PLX
                INX
                INX
                INX
                INX                             ; advance past (vtype, voffset)
                BRA     @ml_vtdr_loop

@ml_vtdr_bad    ; VTDR magic mismatch — drop the parked text base, restore DBR,
                ; close fd, return ENOEXEC.
                PLA
                SEP     #$20
                MX      %10
                _DBRK
                REP     #$20
                MX      %00
                JMP     @ml_enoexec

@ml_vtdr_done   ; Drop the parked text base, restore DBR.
                PLA
                SEP     #$20
                MX      %10
                _DBRK
                REP     #$20
                MX      %00

                ;--- Step 10: Compute 24-bit entry, close fd, JSL mod_init ---
                ; entry low word = entry_offset (bank-relative, ALREADY
                ; includes both this module's placement offset and the
                ; FGXM_HEADER_SZ gap, because the source computes it as
                ; mod_init-$050000 -- from the BANK BASE, not from MODP_ORG).
                ; RELOC: read DBR-rel from the live kernel bank (DBR=kernel
                ; bank here via @ml_vtdr_done's _DBRK), not stale $02.
                LDA    |_mlHeader+FGXM_OFF_ENTRY
                STA     _mlEntry                ; lo+mid bytes
                SEP     #$20
                MX      %10
                LDA     _mlBank
                STA     _mlEntry+2              ; bank byte
                REP     #$20
                MX      %00

                ; (_curModName was copied at @ml_magicOK, so the build-identity
                ; refusal could name the module.  It feeds SYS_MODLOG during
                ; mod_init and the announce at @ml_initOK.)

                ; Close fd before JSL — mod_init may Fs_Open freely.
                SEP     #$20
                MX      %10
                LDA     _mlFd
                REP     #$20
                MX      %00
                AND     #$00FF
                JSR     Fs_Close

                ; Patch the 3-byte target into _mlEntryJSL (JSL imm24 cell).
                SEP     #$20
                MX      %10
                LDA     _mlEntry+0
                STAL    _mlEntryJSL+1
                LDA     _mlEntry+1
                STAL    _mlEntryJSL+2
                LDA     _mlEntry+2
                STAL    _mlEntryJSL+3
                REP     #$20
                MX      %00

                JSL     _mlEntryJSL             ; runs JSL imm24 / RTL

                ; mod_init returned.  Check carry.  C=1 ok; C=0 = init failed.
                BCS     @ml_initOK
                ; RESTORE DBR FIRST.  mod_init's PHK/PLB left it on the MODULE
                ; bank, and every read below -- _mlOverrideBank, _mlBank,
                ; _modSharedBank -- is plain absolute, i.e. DBR-relative.  Read
                ; at the module's DBR they are whatever that bank happens to
                ; hold, so the "is this bank ours to free?" decision was made on
                ; another bank's bytes and could hand Bank_Free an arbitrary
                ; number.  @ml_initOK does this restore and says why; the
                ; failure arm was simply missed.  It also has to happen before
                ; the RTS: without it Mod_Load returns to its caller -- the
                ; Mod_LoadConf line loop -- with DBR still on the module.
                SEP     #$20
                MX      %10
                _DBRK
                REP     #$20
                MX      %00
                ; Init failed.  Free the bank ONLY if it is ours alone to free
                ; -- not a caller-supplied override, and not the shared module
                ; bank, whose other occupants are still running in it.  A
                ; failed module simply leaves its slot idle, which costs
                ; nothing: the slot is statically assigned to that module and
                ; nothing else would ever use it.
                SEP     #$20
                MX      %10
                LDA     _mlOverrideBank
                BNE     @ml_init_skipFree
                LDA     _mlBank
                CMP     _modSharedBank
                BEQ     @ml_init_skipFree
                LDA     _mlBank
                REP     #$20
                MX      %00
                AND     #$00FF
                JSR     Bank_Free
                SEP     #$20
                MX      %10
@ml_init_skipFree
                REP     #$20
                MX      %00
                LDA     #ENOEXEC                ; opaque init failure
                JMP     @ml_errA
@ml_initOK
                ; mod_init returned C=1.  Module is live.
                ; mod_init's PHK/PLB left DBR = module bank; restore DBR=kernel-bank
                ; ($02 = ORG) so the caller's static accesses resolve correctly.
                SEP     #$20
                MX      %10
                _DBRK
                REP     #$20
                MX      %00
                ; Kernel-owned announce: 'mod: <name> loaded' (name in _curModName).
                LDA     #_modLoadPfx
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     #_curModName
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     #_modLoadSfx
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                JSR     Kern_LogEOL
                PLP
                SEC
                RTS

_modLoadPfx     ASC     'module: ',$00
_modLoadSfx     ASC     ' loaded',$00
; Refusal, not a crash: the module was built against a different kernel, so
; every kernel address it baked is wrong.  Logged with the module name in
; front of it (see _Mod_CheckBuild).
_modBuildErr    ASC     ': kernel build mismatch, not loaded',$00
; A pre-staged module placed anywhere but offset 0.  THE LIMITATION IS STAGE
; 2'S, not the registrar's: the boot loader MVNs an image to offset 0 and
; cannot honour a placement offset, so this is a build-configuration error --
; /etc/preload.conf named a module that gen_modplace.py did not place first.
; A caller that CAN place sets _mlPlaceAny and is not refused; SYS_MODLOAD's
; streaming path does, because every module in modload.conf is a placed one.
_modPreStageOff ASC     'mod: pre-staged module is not at offset 0',$00
; One message for all three placement refusals -- overlap, past the bank end,
; and extent table full.  They are the same fact from the module's point of
; view: this image and the running layout disagree about where it goes.
_modPlaceErr    ASC     ': cannot place in the module bank',$00

;==============================================================================
; _Mod_ClaimExtent - reserve this module's byte range in the SHARED bank.
;
; Refuses an image that would overlap something already loaded, that would run
; past the top of the bank, or that arrives when the extent table is full.  A
; refusal, not a crash: the module does not load and the log names it, which is
; the same shape as the build-identity check and exists for the same reason --
; the alternative is overwriting a RUNNING module and failing arbitrarily far
; from the cause.  See the _modExt* block above for why the images cannot be
; trusted to be disjoint on their own.
;
; In:  _mlLoadOff / _mlTextBytes / _mlBssBytes as parsed from the header, and
;      BEFORE the copy loop consumes _mlTextBytes.  _curModName set (the
;      refusal names the module).  MX %00.  DBR = kernel bank.
; Out: C=1 claimed; C=0 refused and logged.  A/X/Y clobbered.
;==============================================================================
_Mod_ClaimExtent MX     %00
                ; end = load + header + text + bss.  A 16-bit carry out of any
                ; step means the image claims to run past the top of the bank.
                LDA     _mlLoadOff
                CLC
                ADC     #FGXM_HEADER_SZ
                BCS     @mce_refuse
                CLC
                ADC     _mlTextBytes
                BCS     @mce_refuse
                CLC
                ADC     _mlBssBytes
                BCS     @mce_refuse
                STA     _mceEnd

                ; Two ranges overlap iff  start < hi[i]  AND  lo[i] < end.
                LDX     #$0000
                LDY     _modExtCount
                BEQ     @mce_claim
                ; A range only collides with a range IN THE SAME BANK.  Two
                ; modules at the same offset in different chains are both
                ; correct, and testing offsets alone would refuse the second.
@mce_scan       SEP     #$20
                MX      %10
                LDA     _modExtBank,X
                CMP     _mlBankOrd              ; low byte; ordinals are < MOD_BANK_MAX
                REP     #$20
                MX      %00
                BNE     @mce_next               ; other chain: cannot overlap
                LDA     _mlLoadOff
                CMP     _modExtHi,X
                BCS     @mce_next               ; start >= hi[i]: disjoint
                LDA     _modExtLo,X
                CMP     _mceEnd
                BCC     @mce_refuse             ; lo[i] < end: overlap
@mce_next       INX
                INX
                DEY
                BNE     @mce_scan

@mce_claim      LDA     _modExtCount
                CMP     #MOD_EXT_MAX
                BCS     @mce_refuse             ; table full
                ASL                             ; entry index -> byte index
                TAX
                LDA     _mlLoadOff
                STA     _modExtLo,X
                LDA     _mceEnd
                STA     _modExtHi,X
                SEP     #$20
                MX      %10
                LDA     _mlBankOrd
                STA     _modExtBank,X
                REP     #$20
                MX      %00
                INC     _modExtCount
                SEC
                RTS

@mce_refuse     LDA     #_curModName
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     #_modPlaceErr
                STA     _conStrPtr
                JSR     Kern_LogStr
                CLC
                RTS

;==============================================================================
; _Mod_CheckBuild - copy the module name out of the header, then verify the
; image was built against THIS kernel.
;
; A module bakes kernel ADDRESSES (its generated kernel_exports.s).  Loaded
; against a different kernel build, every one of them points at the wrong
; byte -- and nothing downstream would say so; it would simply misbehave,
; arbitrarily far from here.  This is the only place that can still tell.
;
; The name is copied FIRST because a refusal that cannot name the module it
; refused is half a diagnostic; the later paths reuse _curModName as before
; (SYS_MODLOG, and the 'mod: <name> loaded' announce).
;
; Compares against the word the kernel PUBLISHED at MOD_JT_CORE_BUILD, not
; against _kernBuildId directly, so a kernel whose _JT_Init never ran fails
; here too.  A header id of $0000 means NOT BUILD-LOCKED -- the module bakes
; no kernel addresses (hello.mod, which has no kernel_exports.s) -- and loads
; against any kernel.
;
; In:  _mlHeader holds the 40-byte FGXM header, magic already validated.
;      MX %00.  DBR = kernel bank (so |abs reaches the LIVE _mlHeader, not
;      the stale $02 assembly-ORG copy -- see Mod_Load step 3).
; Out: C=1 module may load.  C=0 refused, reason already logged.
;      _curModName populated either way.  A/X clobbered.
;==============================================================================
_Mod_CheckBuild MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                LDX     #0
@mcb_nameCopy   LDA:    _mlHeader+FGXM_OFF_NAME,X
                STA:    _curModName,X
                INX
                CPX     #FGXM_NAME_LEN
                BCC     @mcb_nameCopy
                REP     #$20
                MX      %00
                LDA    |_mlHeader+FGXM_OFF_COREBUILD
                BEQ     @mcb_ok                 ; not build-locked
                CMPL    MOD_JT_CORE_BUILD
                BEQ     @mcb_ok
                LDA     #_curModName
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     #_modBuildErr
                STA     _conStrPtr
                JSR     Kern_LogStr
                PLP
                CLC
                RTS
@mcb_ok         PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _mlEntryJSL - 5-byte self-modifying trampoline.  Bytes 1..3 patched by
; Mod_Load to the 24-bit mod_init address.  Caller invokes via JSL (3-byte
; return push); cell does JSL <target> (another 3-byte return push to
; mod_init); mod_init RTLs back to the cell's RTL; cell RTLs back to
; Mod_Load.
;------------------------------------------------------------------------------
; _mlEntryJSL is now a bank-0 FGX_INTVEC gateway cell (include/memmap.s): the
; `JSL _mlEntryJSL` + STAL patches target a fixed bank-0 address that survives
; kernel relocation; its $22/$6B opcodes are written once by _JT_Init.

;------------------------------------------------------------------------------
; Error tails — populated incrementally.  Final shape lands in T9.
;------------------------------------------------------------------------------
@ml_eioClose    ; A holds 0 (short read) or the errno.  ON THE STACK, never
                ; in _shTmp0 -- Fs_Close reaches _Fcb_LookupPtr and that is its
                ; scratch cell (fcb.s:628).  Reloading it after the close
                ; reported Fs_Close's own EBADF for every module that failed
                ; to load, which is the shape apple/fgx#14 cost a whole
                ; investigation.
                PHA
                LDA     _mlFd
                AND     #$00FF
                JSR     Fs_Close
                PLA
                AND     #$00FF
                BNE     @ml_eio_pass
                LDA     #EIO
                JMP     @ml_errA
@ml_eio_pass    JMP     @ml_passErr

@ml_passErr     BRA     @ml_errA        ; identical tail; one rollback site

@ml_errA        STA     _errno
                ; LOAD-FAILURE ROLLBACK (5.3a).  Give back the extent claim
                ; and any vtable-registry entries this load appended.  Both
                ; tables are append-only and nothing else appends during a
                ; Mod_Load, so restoring the counters is a complete undo.
                ;
                ; The registry half is the one that matters.  VTDR entries go
                ; in at step 6 and mod_init does not run until step 10, so a
                ; module whose init FAILS was leaving live entries behind --
                ; and Mod_FindVtable hands those out, so the kernel would
                ; resolve a call site into a module that never initialised.
                ; That is how _Ram_LoadOpsPtr patches the block stubs, and how
                ; the console's chardev ops will be reached once pty migrates.
                ; The extent half is smaller: a refused module kept its byte
                ; range reserved for the life of the boot, and MOD_EXT_MAX is
                ; 12 against a dozen expected modules.
                ;
                ; A is the errno and must survive; PHA/PLA rather than a
                ; scratch cell because this runs at most once per load.
                PHA
                LDA     _mlSaveExtCount
                STA     _modExtCount
                LDA     _mlSaveRegCount
                STA     _modRegCount
                SEP     #$20
                MX      %10
                STZ     _mlSaveValid            ; spent; a later abort must not
                STZ     _mlBankFresh            ;   restore it a second time
                REP     #$20
                MX      %00
                PLA
                AND     #$00FF
                PLP
                CLC
                RTS

@ml_enoexec     LDA     _mlFd
                AND     #$00FF
                JSR     Fs_Close
                LDA     #ENOEXEC
                JMP     @ml_errA

;==============================================================================
; Mod_RegisterPreLoaded - register a module the boot loader already MVN'd
; into a bank (slice 5n-1's pre-stage of prodos.mod at bank from $02FF08
; handoff).  Validates the FGXM header at bank:$0000, marks the bank
; allocated in the pool's map (loader bypassed Bank_Alloc), zeros BSS, walks
; VTDR + appends each entry to the registry, and JSLs mod_init.
;
; In:  A.lo = bank.  MX %00.  DBR=kernel-bank ($02 = ORG).
; Out: C=1 on success.  C=0 + A=errno on failure (ENOEXEC).
;
; Re-uses Mod_Load's _ml* scratch slots; not re-entrant with Mod_Load.
;==============================================================================
;==============================================================================
; Mod_RegisterPreLoaded - the pre-stage's whole registration, unchanged: the
; header half and then the tail, back to back.
;
; SPLIT FOR SYS_MODLOAD (apple/fgx#308).  A streaming caller cannot run these
; two halves together, because everything the FIRST half decides -- which bank
; the ordinal maps to, and which byte range the module claims -- has to be
; known BEFORE the text arrives, not after.  So the halves became callable
; separately and this is what the boot loader's path calls.
;
; In:  A.lo = bank.  MX %00.  DBR = kernel bank ($02 = ORG).
; Out: C=1, or C=0 + A = errno, exactly as before.
;==============================================================================
Mod_RegisterPreLoaded   ENT
                        MX  %00
                        ; MARK IT: this routine TAIL-CALLS
                        ; Mod_RegisterStreamed, so a pre-staged bank and a
                        ; userland `modload' reach the same announce.  INC on
                        ; an absolute never touches A, which is the BANK
                        ; ARGUMENT here -- loading the flag into A instead took
                        ; the whole boot down (`init load failed', `vfs: SEAM
                        ; BAD'), and the PHA/PLA that would fix that is stack
                        ; this path cannot spare.
                        SEP #$20
                        MX  %10
                        INC |_modPreStaged
                        REP #$30
                        MX  %00
                        JSR Mod_RegisterHeader
                        BCC @mrpl_out
                        JMP Mod_RegisterStreamed        ; tail call; its RTS is
@mrpl_out               RTS                             ;   this routine's

;==============================================================================
; Mod_RegisterHeader - validate a module's header, decide where it goes, and
; claim the range.  Steps 1 to 4a of what was one routine.
;
; NOTHING IS WRITTEN INTO THE BANK HERE.  That is the point of the split: the
; extent claim has to precede the bytes, and for a streamed module the bytes
; arrive in chunks after this returns.
;
; In:  A.lo = bank, or 0 to take the ordinal's bank (allocating if the chain is
;      empty).  _mlHdrBank/_mlHdrOff say where the 40-byte header is to be read
;      from.  MX %00.  DBR = kernel bank ($02 = ORG).
; Out: C=1 and _mlBank / _mlLoadOff / _mlTextBase / _mlTextBytes / _mlBssBytes
;      / _mlVtdirOff / _mlBankOrd all set.  C=0 + A = errno.
;==============================================================================
Mod_RegisterHeader      ENT
                        MX  %00
                        PHP
                        REP #$30
                        MX  %00

                        ;--- Step 1: the bank argument, which selects the
                        ; whole shape of this routine.
                        ;
                        ; NON-ZERO is the PRE-STAGE: the loader chose the bank,
                        ; the image begins at <bank>:$0000, and Bank_Alloc was
                        ; bypassed so the bank has to be marked used.  That is
                        ; what this routine used to assume for every caller.
                        ;
                        ; ZERO is a STREAMED load: the bank comes from the
                        ; ordinal (step 3c below), and the header is still in
                        ; the caller's own buffer, which _mlHdrBank/_mlHdrOff
                        ; already point at.
                        ;
                        ; EIGHT BITS THROUGHOUT -- _mlOverrideBank is a DS 1
                        ; with _mlPlaceAny as the next static.
                        SEP #$20
                        MX  %10
                        AND #$FF
                        STA _mlOverrideBank
                        STZ _mlBankFresh
                        BEQ @mrh_srcSet
                        STA _mlHdrBank
                        STZ _mlHdrOff
                        STZ _mlHdrOff+1
@mrh_srcSet             REP #$20
                        MX  %00

                        ;--- Load-failure rollback (5.3a), which this path
                        ; did not have.  Mod_Load takes this snapshot and undoes
                        ; both tables at @ml_errA; the registrar appended to the
                        ; same two tables and undid neither, so a refusal here
                        ; kept its extent for the life of the boot and a FAILED
                        ; mod_init left live registry entries pointing into a
                        ; module that never initialised.  Mod_FindVtable hands
                        ; those out.
                        ;
                        ; It matters more now than it did: this is the tail of a
                        ; repeatable SYSCALL rather than of a once-per-boot
                        ; pre-stage, and MOD_EXT_MAX is 12 against the seven
                        ; extents a boot already uses -- five failed `modload'
                        ; runs and every later load is refused.
                        ;
                        ; AFTER STEP 1, NOT BEFORE IT: A HOLDS THE BANK on
                        ; entry to this routine, and taking the snapshot in
                        ; front of `AND #$FF / STA _mlBank' overwrites it.  The
                        ; module then registers into bank _modExtCount -- 0 on
                        ; the first load -- and the machine boots to a blank
                        ; screen.  Measured, not reasoned: six manifests went
                        ; red together.
                        LDA _modExtCount
                        STA _mlSaveExtCount
                        LDA _modRegCount
                        STA _mlSaveRegCount
                        SEP #$20
                        MX  %10
                        LDA #1
                        STA _mlSaveValid
                        REP #$20
                        MX  %00

                        ;--- Step 2: copy the 40-byte FGXM header from
                        ; {_mlHdrBank, _mlHdrOff} into _mlHeader.
                        ;
                        ; MVN RATHER THAN THE OLD LOOP, because the source
                        ; offset is a variable now.  `STAL abs,X' is the only
                        ; absolute-long indexed form the 65816 has, so a loop
                        ; needs X for the DESTINATION and has nothing left to
                        ; walk a variable source with.  MVN takes both.
                        ;
                        ; NO DBR RESTORE AFTERWARDS: MVN leaves DBR = the
                        ; DESTINATION bank, and the destination is the live
                        ; kernel bank, which is what everything below wants.
                        ; The far bank's own MVN records the same property.
                        SEP #$20
                        MX  %10
                        LDA _mlHdrBank
                        STA @mrh_mvn+2          ; source bank
                        _BANKK
                        STA @mrh_mvn+1          ; dest bank = the LIVE kernel one
                        REP #$20
                        MX  %00
                        LDX _mlHdrOff
                        LDY #_mlHeader
                        LDA #FGXM_HEADER_SZ-1   ; MVN moves A+1 bytes
@mrh_mvn                MVN $00,$00             ; banks patched just above

                        ;--- Step 3: validate magic ---
_we005          LDAL _mlHeader+0
                        CMP #$4746              ; "FG"
                        BEQ *+5
                        JMP @mrp_enoexec
_we006          LDAL _mlHeader+2
                        CMP #$4D58              ; "XM"
                        BEQ *+5
                        JMP @mrp_enoexec

                        ;--- Step 3a: name + build identity ---
                        ; Same check, same helper, as Mod_Load.  This module
                        ; came from the BOOT LOADER rather than modload.conf,
                        ; so a stale one here is the boot-brick case exactly.
                        JSR _Mod_CheckBuild
                        BCS @mrp_buildOK
                        JMP @mrp_enoexec
@mrp_buildOK
                        ;--- Step 3b: placement, THEN the bank latch ---
                        ; A pre-staged module MUST be placed at offset 0: the
                        ; boot loader MVNs to <bank>:$0000 and knows nothing
                        ; about placement offsets (stage2.s, "Dst = bank cursor
                        ; : $0000").  Refuse rather than run a module whose
                        ; every absolute reference is out by its offset -- if a
                        ; second module is ever pre-staged, stage2 has to learn
                        ; offsets first, and this is the line that will say so.
                        LDA |_mlHeader+FGXM_OFF_LOAD
                        BEQ @mrp_placeOK
                        ; EIGHT BITS, because `_mlPlaceAny' is a DS 1 and
                        ; `_mlLoadOff' is the very next static -- a 16-bit read
                        ; here takes _mlLoadOff's low byte as its high byte.
                        ; That was harmless only while this path forced
                        ; _mlLoadOff to zero, which it no longer does.
                        SEP #$20
                        MX  %10
                        LDA |_mlPlaceAny        ; a caller that CAN place is
                        REP #$20                ;   not subject to stage 2's limit
                        MX  %00
                        AND #$00FF
                        BNE @mrp_placeOK
                        LDA #_modPreStageOff
                        STA _conStrPtr
                        JSR Kern_LogStr
                        JMP @mrp_enoexec
@mrp_placeOK
                        ; ONLY NOW does this bank become THE MODULE BANK.  The
                        ; latch used to happen before the check above, which
                        ; meant a REFUSED module still claimed the bank -- and
                        ; with two pre-staged modules, the second (refused) one
                        ; overwrote the latch, so every conf-loaded module
                        ; stacked into the refused module's bank while the
                        ; accepted one sat alone in another.  Latch what was
                        ; ACCEPTED, not what was merely seen.
                        ; ...AND ITS ORDINAL COMES FROM THE HEADER, which is
                        ; the line that stopped this path being one-module-only.
                        ; It used to force ordinal 0 -- "the pre-staged module is
                        ; in the shared bank by construction" -- and that was
                        ; true of the FST and of nothing else.  vfs, ufs,
                        ; ufsdir, prodos and prodosw each declare a chain of their OWN
                        ; (tools/gen_modplace.py OWN_BANK, MOD_BANK_MAX), so
                        ; calling them ordinal 0 made every one of them claim
                        ; [0, size) in the SHARED bank's extent table.  The FST
                        ; claimed it first and the rest were refused with
                        ; `cannot place in the module bank' -- measured
                        ; 2026-09-01, on the boot that campaign 2.4 needs.
                        ;
                        ; PLAIN ABSOLUTE, as Mod_Load's own parse of the same
                        ; byte is: DBR is the kernel bank again by here (step 2
                        ; restores it), which is what makes the `|' form right
                        ; and a _we patch marker unnecessary.
                        SEP #$20
                        MX  %10
                        LDA |_mlHeader+FGXM_OFF_LOAD+2
                        SEC
                        SBC #FGX_MOD_ORG_BANK       ; $05 -> 0
                        REP #$20
                        MX  %00
                        AND #$00FF
                        STA _mlBankOrd
                        ; An ordinal past the table is a module built against a
                        ; layout this kernel does not have.  Mod_Load refuses it
                        ; rather than index off the end; so does this.
                        CMP #MOD_BANK_MAX
                        BCC @mrp_ordOK
                        JMP @mrp_enoexec
@mrp_ordOK
                        ;--- Step 3c: WHICH BANK, which used to be "the one the
                        ; caller handed us" and could only ever be that.
                        ;
                        ; OVERRIDE (the pre-stage) keeps that: the loader chose
                        ; the bank and bypassed Bank_Alloc, so it is marked used
                        ; here as it always was.
                        ;
                        ; OTHERWISE THE ORDINAL DECIDES, and a chain already in
                        ; use is JOINED rather than replaced.  Ordinal 0 holds
                        ; prodos, net, serial, bpf, ramdisk, hello and pty at
                        ; seven different offsets, so only the FIRST module in a
                        ; chain allocates.  A streamed module that allocated for
                        ; itself would get a fresh empty bank and land nowhere
                        ; near the neighbours its extent was just checked
                        ; against -- the check would pass and mean nothing.
                        ;
                        ; ONLY NOW does the bank become the ordinal's.
                        ; _modSharedBank IS _modBankTab[0], so the FST still
                        ; latches exactly what it always did.
                        SEP #$20
                        MX  %10
                        LDA _mlOverrideBank
                        BNE @mrh_bankOvr
                        LDX _mlBankOrd
                        LDA _modBankTab,X
                        BNE @mrh_bankJoin
                        REP #$20
                        MX  %00
                        JSR Bank_Alloc          ; C=1+A=bank / C=0+A=ENOMEM
                        BCS @mrh_bankFresh
                        JMP @ml_errA
@mrh_bankFresh          SEP #$20
                        MX  %10
                        STA _mlBank
                        LDA #1
                        STA _mlBankFresh        ; this load owns it, so an abort
                        BRA @mrh_bankLatch      ;   may hand it back
@mrh_bankOvr            STA _mlBank
                        REP #$20
                        MX  %00
                        LDA _mlBank
                        AND #$00FF
                        JSR Bank_MarkUsed
                        SEP #$20
                        MX  %10
                        BRA @mrh_bankLatch
@mrh_bankJoin           STA _mlBank
@mrh_bankLatch          LDX _mlBankOrd
                        LDA _mlBank
                        STA _modBankTab,X
                        REP #$20
                        MX  %00

                        ;--- Step 4: parse fields ---
_we007          LDAL _mlHeader+FGXM_OFF_TEXT
                        STA  _mlTextBytes
_we008          LDAL _mlHeader+FGXM_OFF_BSS
                        STA  _mlBssBytes
_we009          LDAL _mlHeader+FGXM_OFF_VTDIR
                        STA  _mlVtdirOff

                        ;--- Step 4a: claim the byte range ---
                        ; PARSED, NOT ASSUMED.  This used to store a literal
                        ; zero -- "this path never parses it" -- which was true
                        ; of a pre-staged image and of nothing else.  A caller
                        ; that sets _mlPlaceAny reaches step 3b with a NON-zero
                        ; offset, and every later step here derived its bank
                        ; address from the header gap alone: the extent claim
                        ; below, the BSS base at step 5, the VTDR base at step
                        ; 6 and the voffset conversion inside the walk.  All
                        ; four were the offset-0 form of what Mod_Load computes
                        ; from _mlTextBase, and all four are corrected here.
                        ;
                        ; A pre-staged module is unaffected: step 3b has
                        ; already refused any non-zero offset for it, so this
                        ; parse yields exactly the zero the store wrote.
                        ; The bytes are ALREADY in the bank (the boot loader
                        ; MVN'd them, or the streaming path did), so this
                        ; cannot prevent a bad image from having overwritten
                        ; something; what it does is record the occupied range
                        ; so the modules loaded AFTER it are checked against it.
                        LDA |_mlHeader+FGXM_OFF_LOAD
                        STA _mlLoadOff
                        CLC
                        ADC #FGXM_HEADER_SZ
                        STA _mlTextBase         ; first text byte in the bank
                        ; _mlBankOrd is ALREADY SET, from the header, above.
                        ; It used to be forced to 0 here on the argument that a
                        ; pre-staged module is in the shared bank by
                        ; construction -- see there for why that was only ever
                        ; true of the FST.
                        JSR _Mod_ClaimExtent
                        BCS @mrp_extentOK
                        JMP @mrp_enoexec
@mrp_extentOK
                        ; --- the header half ends here.  Everything above
                        ; decided WHERE; everything below acts on the bytes,
                        ; which for a streamed module are not there yet. ---
                        PLP
                        SEC
                        RTS

;==============================================================================
; Mod_RegisterStreamed - finish a module whose bytes are already in the bank.
; Steps 5 to 7 of what was one routine.
;
; Mod_RegisterHeader must have run for THIS module and succeeded; it leaves
; every static this needs.  The pre-stage calls the two back to back;
; SYS_MODLOAD calls this one at `end', after its chunks have been MVN'd in.
;
; In:  the _ml* block as Mod_RegisterHeader left it.  MX %00.  DBR = kernel
;      bank ($02 = ORG).
; Out: C=1 and mod_init has run and returned C=1.  C=0 + A = errno, with the
;      extent and registry tables rolled back to where the header half found
;      them.
;==============================================================================
Mod_RegisterStreamed    ENT
                        MX  %00
                        PHP
                        REP #$30
                        MX  %00

                        ;--- Step 5: zero BSS (text bytes already MVN'd by
                        ;             the loader; BSS region is uninitialized) ---
                        LDA _mlBssBytes
                        BEQ @mrp_bssDone
                        ; First BSS offset = _mlTextBase + text_size, which is
                        ; where Mod_Load's Fs_ReadN leaves _frnDstOff.  This was
                        ; `ADC #FGXM_HEADER_SZ' -- the offset-0 form -- and for
                        ; a placed module in a SHARED ordinal it zeroed bytes
                        ; inside a neighbour's running text.
                        LDA _mlTextBytes
                        CLC
                        ADC _mlTextBase
                        TAX                     ; X = first BSS byte offset
                        SEP #$20
                        MX  %10
                        LDA _mlBank
                        PHA
                        PLB                     ; DBR = module bank
                        REP #$20
                        MX  %00
                        LDA _mlBssBytes
@mrp_bssL               CMP #2
                        BCC @mrp_bssTail
                        STZ: $0000,X
                        INX
                        INX
                        DEC
                        DEC
                        BRA @mrp_bssL
@mrp_bssTail            CMP #0
                        BEQ @mrp_bssRestore
                        SEP #$20
                        MX  %10
                        STZ: $0000,X
                        REP #$20
                        MX  %00
@mrp_bssRestore         SEP #$20
                        MX  %10
                        _DBRK
                        REP #$20
                        MX  %00
@mrp_bssDone

                        ;--- Step 6: walk VTDR + append each entry ---
                        ; vtdir_off is "within text", so the bank offset is
                        ; _mlTextBase + it, exactly as Mod_Load step 9 computes.
                        ; This was `ADC #FGXM_HEADER_SZ', which for a placed
                        ; module read the magic at $0028 -- and in ordinal 0
                        ; that is prodos's own `VTDR', four bytes past
                        ; prodos_text.  The check PASSED and the walk
                        ; re-registered prodos's entries: silent success.
                        LDA _mlVtdirOff
                        CLC
                        ADC _mlTextBase
                        STA _mlVtdirAbsLo
                        SEP #$20
                        MX  %10
                        LDA _mlBank
                        STA _mlVtdirAbsBank
                        REP #$20
                        MX  %00

                        LDX _mlVtdirAbsLo

                        ; The walk converts each TEXT-relative voffset to
                        ; BANK-relative, and it runs with DBR = module bank
                        ; where a kernel static cannot be read DBR-relative.
                        ; Park the base on the stack and add it with `ADC 1,S',
                        ; which is what Mod_Load step 9 does and for the same
                        ; reason.  Popped at BOTH exits below.
                        LDA _mlTextBase
                        PHA

                        SEP #$20
                        MX  %10
                        LDA _mlVtdirAbsBank
                        PHA
                        PLB                     ; DBR = module bank
                        REP #$20
                        MX  %00

                        ; Validate VTDR magic at (DBR=bank):X
                        LDA: $0000,X
                        CMP #VTDR_MAGIC_LO
                        BNE @mrp_vtdrBad
                        LDA: $0002,X
                        CMP #VTDR_MAGIC_HI
                        BNE @mrp_vtdrBad

                        TXA
                        CLC
                        ADC #4
                        TAX                     ; cursor past 'VTDR' magic
@mrp_vtdrL              LDA: $0000,X
                        CMP #VT_END
                        BEQ @mrp_vtdrEnd
_we010          STAL _mlWalkVType
                        LDA: $0002,X
                        ; BANK-relative = text base + text-relative.  This was
                        ; `ADC #FGXM_HEADER_SZ' while every module this path
                        ; saw sat at offset 0.
                        CLC
                        ADC 1,S
_we011          STAL _mlWalkVOffset
                        PHX
                        JSR _Mod_RegistryAppend
                        PLX
                        INX
                        INX
                        INX
                        INX
                        BRA @mrp_vtdrL

@mrp_vtdrBad            ; drop the parked text base, restore DBR, ENOEXEC
                        PLA
                        SEP #$20
                        MX  %10
                        _DBRK
                        REP #$20
                        MX  %00
                        JMP @mrp_enoexec        ; the announce below grew past a
                                                ;   branch's reach

@mrp_vtdrEnd            ; drop the parked text base, restore DBR
                        PLA
                        SEP #$20
                        MX  %10
                        _DBRK
                        REP #$20
                        MX  %00

                        ;--- Step 7: compute entry, JSL mod_init ---
_we012          LDAL _mlHeader+FGXM_OFF_ENTRY
                        STA  _mlEntry
                        SEP #$20
                        MX  %10
                        LDA _mlBank
                        STA _mlEntry+2
                        LDA _mlEntry+0
                        STAL _mlEntryJSL+1
                        LDA _mlEntry+1
                        STAL _mlEntryJSL+2
                        LDA _mlEntry+2
                        STAL _mlEntryJSL+3
                        REP #$20
                        MX  %00

                        ; (_curModName was copied at Step 3a, so the build
                        ; refusal could name the module.  It feeds SYS_MODLOG
                        ; and the announce at @mrp_initOK.)

                        ; ANNOUNCED BEFORE mod_init, NOT AFTER IT.  A module
                        ; prints its OWN lines from mod_init -- `bpf:
                        ; /dev/bpf0 registered', `serial: tty01 SCC ch.B
                        ; 9600' -- so an announce that waited for the call to
                        ; return came out UNDER the messages it introduces.
                        ; This is 2.11BSD's order: `attaching de0 csr 174510'
                        ; and then `de0: DELUA addr 08:00:2b:b7:ea:e6'.
                        ;
                        ; The image IS loaded by this point: placed, relocated
                        ; and its registry entries appended.  What has not
                        ; happened is the module bringing ITSELF up, and a
                        ; mod_init that fails says so on the line after -- the
                        ; same shape upstream has when an attach fails.
                        ;
                        ; A PRE-STAGED BANK SAYS NOTHING.  vfs, ufs and
                        ; ufsdir are the base OS in banks of their own -- the
                        ; boot loader MVN'd them into place before this kernel
                        ; ran -- so announcing them tells a user about the
                        ; kernel's internal layout.  A module somebody actually
                        ; loaded is exactly what a boot log is for.
                        ;
                        ; A BRANCH, NOT A BRACKET.  The first cut kept the
                        ; message and muted it behind a flag the log tested;
                        ; that block cost 8 bytes on the CALLING TASK's kernel
                        ; stack -- a userland `modload' reaches here through
                        ; SYS_MODLOAD -- and took kstkhwm_check from 52 spare
                        ; to 44 against its ratchet of 48.  Skipping the calls
                        ; outright costs nothing.
                        SEP #$20
                        MX  %10
                        LDA |_modPreStaged
                        STZ |_modPreStaged      ; read once; never leak it on
                        REP #$30
                        MX  %00
                        AND #$00FF
                        BNE @mrp_quiet
                        LDA #_modLoadPfx
                        STA _conStrPtr
                        JSR Kern_LogStrNoEOL
                        LDA #_curModName
                        STA _conStrPtr
                        JSR Kern_LogStrNoEOL
                        LDA #_modLoadSfx
                        STA _conStrPtr
                        JSR Kern_LogStrNoEOL
                        JSR Kern_LogEOL
@mrp_quiet              ANOP

                        JSL _mlEntryJSL

                        BCS @mrp_initOK
                        ; RESTORE DBR FIRST.  mod_init's own PHK/PLB left it on
                        ; the MODULE bank -- @mrp_initOK below says so and undoes
                        ; it -- and this arm did not, so every store in the tail
                        ; landed in the module's bank instead of the kernel's:
                        ; _errno, and then the two rollback counters, written
                        ; over whatever the module bank holds at those offsets.
                        ; In a SHARED ordinal that is prodos's running text, so
                        ; the machine stopped answering after the first failed
                        ; load rather than reporting one.
                        ;
                        ; It was unreachable until now: no shipped module's
                        ; mod_init returns C=0, and hellofail reached this arm
                        ; only through Mod_Load.  A streamed load ends here.
                        ;
                        ; NOT COVERED BY modloadundo, AND THE FIXTURE IS WHY.
                        ; Deleting this restore leaves that test GREEN, because
                        ; hellofail's last act before CLC is `JSL SYS_MODLOG'
                        ; and the syscall return path puts DBR back on the
                        ; kernel bank -- so the one module that reaches this arm
                        ; is the one module that does not need the restore.  A
                        ; module failing init without a trailing syscall would.
                        ; Kept on the symmetry argument rather than a red test:
                        ; @mrp_initOK does exactly this, for exactly this
                        ; reason, four instructions below.
                        SEP #$20
                        MX  %10
                        _DBRK
                        REP #$20
                        MX  %00
                        ; init failed; do NOT Bank_Free (caller bypassed
                        ; Bank_Alloc — the bank is owned by the pre-staged
                        ; load contract).  ENOEXEC through Mod_Load's tail,
                        ; which rolls the extent and registry tables back.
                        LDA #ENOEXEC
                        JMP @ml_errA

@mrp_initOK             ; mod_init's PHK/PLB left DBR = module bank.
                        SEP #$20
                        MX  %10
                        _DBRK
                        ; THE SNAPSHOT AND THE BANK CLAIM ARE SPENT.  Leaving
                        ; _mlBankFresh set here is what let the NEXT session's
                        ; abort free a chain this load had brought up.
                        STZ _mlSaveValid
                        STZ _mlBankFresh
                        REP #$20
                        MX  %00
                        PLP
                        SEC
                        RTS

                        ; SHARED WITH Mod_Load, whose error tail is this one
                        ; plus the rollback: STA _errno, restore both counters,
                        ; AND #$00FF, PLP, CLC, RTS.  The PLP matches the PHP
                        ; this routine pushed at entry, and there is no fd on
                        ; this path for it to want closed.  Jumping there costs
                        ; six bytes less than the tail it replaces, which is
                        ; what pays for the snapshot above.
@mrp_enoexec            SEP #$20
                        MX  %10
                        STZ |_modPreStaged      ; a refusal must not leave the
                        REP #$30                ;   next module marked
                        MX  %00
                        LDA #ENOEXEC
                        JMP @ml_errA

;==============================================================================
; Mod_LoadConf - parse /etc/modload.conf, Mod_Load each named module.
;
; Format:
;   - One name per line ("hello").
;   - Blank lines OK.
;   - First non-WS char '#' → comment, line skipped.
;   - Name = first non-WS run; trailing WS + content ignored.
;
; In:  none.  MX %00.  DBR=kernel-bank ($02 = ORG).  Fs subsystem alive + per-task fd table set.
; Out: C=1 always.  Per-line failures kern-logged + yellow border + continue.
;==============================================================================
Mod_LoadConf    ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00

                STZ     _mlcHaveErr

                ; Open conf file.  Missing conf is not an error.
                LDX     #_mlc_confPath
                JSR     Fs_Open
                BCS     @mlc_opened
                ; No conf — nothing to do.
                PLP
                SEC
                RTS
@mlc_opened     AND     #$00FF
                STA     _mlcFd

                ; Preload _mlcPathBuf[0..12] with "/lib/modules/".
                LDX     #0
@mlc_pfxL       LDA:    _mlc_pathPrefix,X
                STA:    _mlcPathBuf,X
                INX
                CPX     #_MLC_PFX_LEN
                BCC     @mlc_pfxL

                ; Outer loop: per line.
@mlc_lineStart
                STZ     _mlcState               ; state 0 = skip leading WS
                LDA     #_MLC_PFX_LEN
                STA     _mlcWriteIdx

                ; Inner loop: per byte.
@mlc_charL      LDA     _mlcFd
                AND     #$00FF
                JSR     Fs_Read                 ; C=1+A=byte; C=0+A=0 EOF; C=0+A=errno
                BCS     @mlc_readOK
                JMP     @mlc_eofOrErr
@mlc_readOK
                AND     #$00FF
                STA     _mlcChar

                CMP     #$000A                  ; newline?
                BEQ     @mlc_eol
                CMP     #$000D                  ; CR?
                BEQ     @mlc_eol

                ; Branch on parse state.
                LDA     _mlcState
                CMP     #$0001
                BEQ     @mlc_st1_copying
                CMP     #$0000
                BEQ     @mlc_st0_leading
                ; State 2 (skip rest of line) or 3 (comment): drop char.
                BRA     @mlc_charL

@mlc_st0_leading
                LDA     _mlcChar
                CMP     #'#'
                BEQ     @mlc_toComment
                CMP     #' '
                BEQ     @mlc_charL
                CMP     #$09                    ; tab
                BEQ     @mlc_charL
                ; First name char.  Switch to state 1 (copying).
                LDA     #$0001
                STA     _mlcState
                BRA     @mlc_st1_appendChar

@mlc_st1_copying
                LDA     _mlcChar
                CMP     #' '
                BEQ     @mlc_endName
                CMP     #$09
                BEQ     @mlc_endName
@mlc_st1_appendChar
                ; Append _mlcChar at _mlcPathBuf[_mlcWriteIdx] if room.
                LDA     _mlcWriteIdx
                CMP     #_MLC_PATH_MAX-1
                BCS     @mlc_charL              ; buf full; drop excess
                LDX     _mlcWriteIdx
                LDA     _mlcChar
                STA:    _mlcPathBuf,X
                LDA     _mlcWriteIdx
                INC
                STA     _mlcWriteIdx
                BRA     @mlc_charL

@mlc_endName    LDA     #$0002                  ; skip rest of line
                STA     _mlcState
                BRA     @mlc_charL

@mlc_toComment  LDA     #$0003
                STA     _mlcState
                BRA     @mlc_charL

@mlc_eol        ; End of line.  If we copied any chars (state 1 or 2),
                ; NUL-terminate + Mod_Load.
                LDA     _mlcState
                CMP     #$0001
                BEQ     @mlc_doLoad
                CMP     #$0002
                BEQ     @mlc_doLoad
                ; Empty / comment-only line.  Next line.
                JMP     @mlc_lineStart

@mlc_doLoad     ; NUL-terminate at _mlcWriteIdx.
                LDX     _mlcWriteIdx
                LDA     #$0000
                STA:    _mlcPathBuf,X
                ; Mod_Load(_mlcPathBuf, override=0).
                LDX     #_mlcPathBuf
                LDA     #$0000
                JSR     Mod_Load
                BCS     @mlc_loadOK
                ; Failure: log + remember.
                LDA     #_mlc_msgLoadFail
                STA     _conStrPtr
                JSR     Kern_LogStr
                LDA     #$0001
                STA     _mlcHaveErr
@mlc_loadOK     JMP     @mlc_lineStart

@mlc_eofOrErr   ; EOF or read error.  Close fd, set yellow if errors, return.
                LDA     _mlcFd
                AND     #$00FF
                JSR     Fs_Close
                ; (Removed 2026-07-26: a yellow-border error indicator wrote
                ; $E0C034 BLIND.  That register is border colour in the low
                ; nibble and CLOCK CONTROL in the high nibble, so the write also
                ; zeroed the clock-chip control bits -- and the failure it
                ; signalled is already reported by Kern_LogStr above, on a
                ; console that exists by then.  Errors still propagate via
                ; _mlcHaveErr; only the register poke is gone.)
@mlc_doneOK     PLP
                SEC
                RTS

_mlc_confPath   ASC     '/etc/modload.conf',00
_mlc_pathPrefix ASC     '/lib/modules/'         ; 13 bytes, NO trailing NUL
_mlc_msgLoadFail ASC    'modload.conf: load failed',00

;==============================================================================
; _Mod_RegistryAppend - append (_mlWalkVType, _mlWalkVOffset, _mlBank) to the
; module vtable registry.  Internal helper; called from Mod_Load's VTDR walk.
;
; In:  _mlWalkVType (2 B), _mlWalkVOffset (2 B), _mlBank (1 B) all set.
;      MX %00.  DBR may be the module bank (we use STAL throughout).
; Out: _modRegCount incremented (silently dropped if at MOD_REG_MAX).
; Preserves: nothing important; clobbers A, X.
;==============================================================================
_Mod_RegistryAppend MX  %00
                PHP
                REP     #$30
                MX      %00
_we013          LDAL    _modRegCount
                CMP     #MOD_REG_MAX
                BCS     @mra_full
                ; entry_off = count * MOD_REG_E_SIZE (=6) = count*2 + count*4.
                ;
                ; REGISTER/STACK ONLY -- no absolute (DBR-relative) memory here.
                ; This routine runs mid-VTDR-walk with DBR = the MODULE's bank,
                ; which the header above already states and which the _mlBank
                ; read below already works around.  The previous version stashed
                ; the multiplicands in `_mlWalkTmp` / `_mlWalkTmp+2` with plain
                ; STA/LDA, so both stores landed in the freshly loaded MODULE
                ; image at its own offsets $1AD2..$1AD5 instead of in kernel
                ; scratch.  prodos.mod is the only module long enough for that
                ; window to be CODE: it fell inside _fop_rename's @rn_sback,
                ; turning `BMI @rn_exdevJ` + `LDA _fsPathScratch,X` into four
                ; $00 bytes (BRK), so every rename(2) call died there.  See
                ; apple/fgx#29.  n,S is bank-independent, so the scratch is not
                ; needed at all.
                ;
                ; count < MOD_REG_MAX (16) here, so count*6 < 96: the two ASLs
                ; cannot overflow 16 bits.  MX %00 throughout, so PHA/ADC 1,S/PLX
                ; are all 16-bit.  The @mra_full exit branches out BEFORE the
                ; PHA, so the stack stays balanced on that path.
                ASL                              ; A = count*2
                PHA
                ASL                              ; A = count*4
                CLC
                ADC     1,S                      ; + count*2 -> count*6
                PLX                              ; drop the pushed count*2
                                                 ; (X is documented as clobbered)
                TAY                              ; Y = entry byte offset (+VTYPE=0)
                ; Write vtype (2 B) at entry_off + MOD_REG_E_VTYPE.
_we014          LDAL    _mlWalkVType
                STA     [_modRegPtr],Y           ; -> heap registry
                ; Write voffset (2 B) at entry_off + MOD_REG_E_VOFFSET (+2).
                INY
                INY
_we015          LDAL    _mlWalkVOffset
                STA     [_modRegPtr],Y
                ; Write bank (1 B) at entry_off + MOD_REG_E_BANK (+4).
                INY
                INY
                SEP     #$20
                MX      %10
                ; _mlBank was written DBR-relative (Step 5, DBR=kernel bank), but
                ; we run here with DBR=module bank (called mid-VTDR-walk).  LDAL
                ; would read the stale $02 copy under relocation -> entry bank $00.
                ; Read it from the live kernel bank (K) explicitly.
                PHB
                PHK
                PLB                             ; DBR = kernel bank
                LDA     _mlBank
                PLB                             ; DBR = module bank (restored)
                STA     [_modRegPtr],Y
                REP     #$20
                MX      %00
                ; Bump count.
_we016          LDAL    _modRegCount
                INC
_we017          STAL    _modRegCount
@mra_full       PLP
                RTS

;==============================================================================
; Mod_FindVtable - look up a vtable by type tag.
;
; In:  A = vtype.  MX %00.  NO DBR REQUIREMENT.
; Out: C=1 + A = voffset (16-bit), X.lo = bank (low byte).
;      C=0 if no entry found.
;
; BANK-INDEPENDENT BY CONSTRUCTION, which is the whole point of the shape below
; (apple/fgx#32).  It used to route the walk's vtype, its X*6 arithmetic, the
; matched voffset and the matched bank through DBR-relative scratch, and to
; require `DBR = kernel bank` of its callers in exchange.
;
; That is the exact arrangement that failed in the sibling _Mod_RegistryAppend
; (apple/fgx#29): its header documented the DBR situation too, and the
; arithmetic still ran mid-VTDR-walk with DBR = the MODULE's bank, so two
; 16-bit stores landed inside the freshly loaded image and turned four bytes of
; _fop_rename into BRKs.  It presented as "rename(2) is broken" -- not a symptom
; anyone traces back to module loading, and it cost a long investigation past
; two wrong diagnoses.
;
; Every caller here does hold DBR = kernel bank, so this was CORRECT.  Correct
; by caller convention is the property that failed; the registry pointer is
; already a long indirect, so nothing else in the routine needed a bank at all.
; The stack costs one byte more than the scratch cells and cannot be aimed at a
; module image.
;==============================================================================
Mod_FindVtable  ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                PHA                              ; the vtype we are looking for,
                                                 ;   parked where the walk can
                                                 ;   reach it without a bank
                LDX     #0                       ; loop index
@mfv_L
_we018          LDAL    _modRegCount
                PHA                              ; count
                TXA
                CMP     1,S                      ; X - count (PLA below leaves C)
                PLA
                BCS     @mfv_notFound
                ; Byte offset = X * 6.  `ADC 1,S` is bank-independent by
                ; construction; the three-store scratch form it replaces was
                ; bank-independent only while the caller behaved.
                TXA
                ASL                              ; *2
                PHA
                ASL                              ; *4
                CLC
                ADC     1,S                      ; *4 + *2 = *6
                TAY                              ; Y = byte offset within registry
                PLA                              ; drop the saved *2 (A is dead)
                LDA     [_modRegPtr],Y           ; entry's MOD_REG_E_VTYPE (+0)
                CMP     1,S                      ; ...against the wanted vtype
                BEQ     @mfv_found
                INX
                BRA     @mfv_L
@mfv_notFound   PLA                              ; drop the vtype
                PLP
                CLC
                RTS
@mfv_found      ; Y = matched entry offset.  voffset at +VOFFSET (+2), bank at +BANK (+4).
                PLA                              ; drop the vtype
                INY
                INY
                LDA     [_modRegPtr],Y           ; MOD_REG_E_VOFFSET
                PHA                              ; ...held on the stack, not in
                                                 ;   _mlWalkVOffset
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     [_modRegPtr],Y           ; MOD_REG_E_BANK (one byte; the
                                                 ;   high half of A is still the
                                                 ;   voffset's, hence the AND)
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX                              ; X = bank (high zero)
                PLA                              ; A = voffset
                PLP
                SEC
                RTS
