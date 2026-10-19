;==============================================================================
; ramdisk.s - dispatch stubs for the /RAM5 RAM-disk driver.
;
; THE DRIVER ITSELF IS src/modules/ramdisk/ramdisk.s, an FGXM module.  It moved
; out of the core bank 2026-08-11, taking ~1 KB with it.  What stays here is
; only what the core bank genuinely owns: the two names block.s reaches by EXT
; linkage, which a module cannot satisfy, plus the _rd* statics (memmap.s) --
; leaving those here is what let the driver body move VERBATIM.
;
; HOW THE CALL CROSSES.  Not through a bank-0 trampoline.  The four existing
; ones are in bank 0 because `JML [abs]` takes its 24-bit vector from bank 0
; and nothing else -- but an INLINE self-modified JSL needs no vector at all.
; The three operand bytes are written DBR-relatively into our own bank and the
; JSL executes in place, so there is no baked $02 anywhere and no bank-0 space
; is spent.  (The tempting 5-byte hole at $03C7 is NOT free: $03C8 is the
; 3.5"/IWM ROM driver's stomp zone, which is why _mlEntryJSL was moved out.)
;
; The module's two entry points RTL for this reason; their bodies keep RTS and
; stay JSR-able from inside the module.
;
; WHEN THE MODULE IS ABSENT the stubs return C=0 + A=EIO rather than calling an
; unpatched address.  A boot with no ramdisk.mod is a boot with no /RAM5, which
; is what a NewHandle failure has always looked like -- non-fatal.
;==============================================================================

                MX      %00

; 0 until _Ram_LoadOpsPtr has patched both sites.  A whole byte rather than
; testing the operand, because $000000 is a legal-looking address and "not yet
; resolved" must not be a guess.
_ramOpsOK       DFB     $00

;==============================================================================
; _Ram_LoadOpsPtr - resolve ramdisk.mod's VT_BLOCKDEV vtable and patch the two
;                   call sites.  Called once from main.s after Mod_LoadConf and
;                   BEFORE Fs_EnumerateMounts, so the device the module
;                   registered is in the table when mounts are enumerated.
;
; In:  none.  MX %00.  DBR = kernel bank.
; Out: C=1 patched, C=0 no VT_BLOCKDEV module.  A/X/Y, _libcTmp2 clobbered.
;
; The vtable is two 16-BIT bank-relative offsets, not 24-bit pointers: we know
; the bank from the registry, so the module never self-patches its own table.
;==============================================================================
_Ram_LoadOpsPtr ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                LDA     #VT_BLOCKDEV
                JSR     Mod_FindVtable          ; C=1: A=voffset, X.lo=bank
                BCC     @rlo_none
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                TXA
                STA     _libcTmp2+2             ; module bank
                REP     #$30
                MX      %00
                LDY     #0
                LDA     [_libcTmp2],Y           ; entry 0: read op offset
                STA    |_ramRdSite+1
                LDY     #2
                LDA     [_libcTmp2],Y           ; entry 1: write op offset
                STA    |_ramWrSite+1
                SEP     #$20
                MX      %10
                LDA     _libcTmp2+2
                STA    |_ramRdSite+3            ; both live in the module bank
                STA    |_ramWrSite+3
                LDA     #$01
                STA    |_ramOpsOK
                REP     #$30
                MX      %00
                PLP
                SEC
                RTS
@rlo_none       PLP
                CLC
                RTS

;==============================================================================
; _RAM_ReadBlock / _RAM_WriteBlock - the names block.s links against.
; Contract unchanged: _blkNum / _blkBuf in, C=1 ok or C=0 + A=EIO.
;==============================================================================
_RAM_ReadBlock  ENT
                MX      %00
                LDA    |_ramOpsOK
                AND     #$00FF
                BEQ     @rrb_nodev
_ramRdSite      JSL     $000000                 ; operand patched above
                RTS
@rrb_nodev      LDA     #EIO
                CLC
                RTS

_RAM_WriteBlock ENT
                MX      %00
                LDA    |_ramOpsOK
                AND     #$00FF
                BEQ     @rwb_nodev
_ramWrSite      JSL     $000000                 ; operand patched above
                RTS
@rwb_nodev      LDA     #EIO
                CLC
                RTS
