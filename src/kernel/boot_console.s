;==============================================================================
; boot_console.s - Pre-module boot console via firmware COUT.
;
; Public:
;   _BootCon_Init       Patch the JSL operand inside _BootCon_PutChar from
;                       the CoutTramp handoff written by the loader.  Call
;                       once from FGX_Entry before any boot-console use.
;                       MX %00.  A clobbered.  No error return.
;
;   _BootCon_PutChar    Emit one ASCII char via firmware COUT.
;                       In:  A = ASCII char (low byte).  MX %00.
;                       Out: A clobbered by *this wrapper* (CoutTramp ORs
;                            $80 into A's low byte before the JSR; the ROM
;                            COUT itself preserves A per the IIgs Firmware
;                            Reference, but the wrapper does not).
;                            X/Y high-byte clobbered by the wrapper's
;                            SEP #$30 transit (CPU zero-extends on the
;                            X-flag flip; the ROM itself preserves X/Y).
;                            DBR/DP/MX/I preserved (CoutTramp PHP/PHB/PLB/PLP,
;                            plus this wrapper's own PHP/PHB).
;                            NOT REENTRANT: it parks the caller's S, the char
;                            and the language-card state in three static cells,
;                            and it runs with interrupts off, so nothing can
;                            reach it while one call is in flight.
;
; Architecture: kernel PBR=$02 can't directly JSR firmware ROM at $00:FDED
; (the JSR would read $02:FDED RAM).  We use the bank-$00 `CoutTramp`
; thunk in src/boot/loader.s, which does PHK/PLB → SEC/XCE → ORA #$80
; → JSR $FDED → CLC/XCE → restore.  Entered via JSL.  Operand patched at
; boot from `_CoutTramp_EntryLo`/`_CoutTramp_EntryHi` (handoff at
; $02FF07/08; bank implicit $00).  Pattern mirrors `Blk_Init` patching
; `_blkSmartJump`.
;
; Verified COUT ABI: see iigs-mcp `get_firmware_entry name=COUT`.
;
; Out of scope: scroll, color, cursor, escape codes.  Leaf primitive.
; A `_BootCon_PutString` helper was dropped from Phase 0 to fit the
; 45056 B kernel-image cap; reintroduce in Phase 1+ when the modules
; loader has shifted FGX_DATA.
;==============================================================================

;------------------------------------------------------------------------------
; _BootCon_Init - copy CoutTramp lo/hi (handoff at $02FF07/08) into the JSL
; operand bytes inside _BootCon_PutChar.  Bank byte is implicitly $00, already
; assembled as part of the JSL $000000 placeholder.  Single 16-bit LDAL/STAL
; pair: the two handoff bytes are contiguous, so MX %00 reads/writes both in
; one instruction each.
;------------------------------------------------------------------------------
_BootCon_Init   MX  %00
                ; RELOC: read the handoff + patch the live JSL cell DBR-relative
                ; (DBR = kernel bank), NOT $02-baked LDAL/STAL — else we read a
                ; stale $02 handoff and patch the dead $02 image (mirrors Blk_Init).
                LDA     |_CoutTramp_EntryLo
                STA     |_bcPutSmartJmp+1
                RTS

;------------------------------------------------------------------------------
; _BootCon_PutChar - emit one ASCII char.  See header for ABI.
; CoutTramp handles emulation-mode transit and the COUT $80 high-bit OR.
;------------------------------------------------------------------------------
_BootCon_PutChar    MX  %00
                AND     #$00FF                  ; clear A's high byte (defensive
                                                ; in case caller had garbage)
                ORA     #$0080                  ; set bit 7 for COUT high-ASCII;
                                                ; moved here from CoutTramp at
                                                ; multipass-merge time to free
                                                ; 2 B of loader budget.

                ; INTERRUPTS OFF FOR THE WHOLE EXCURSION.  Two reasons, and the
                ; second is the one that bites: the emulation window below runs
                ; on a stack that is not the caller's, and the ROM window below
                ; makes $00:E000-$00:F9FF -- every per-task kernel stack -- read
                ; as ROM and swallow its writes.  An interrupt taken inside
                ; either window and dispatched onto a task stack would read the
                ; wrong bytes and write into nothing.  clock.s SEIs around its
                ; own firmware excursion for the neighbouring reason (the ROM's
                ; interrupted-context save area is a global singleton).
                PHP
                SEI

                ; DBR IS NOT OURS ON THE PANIC PATH.  kc_panic reaches SYS_PANIC
                ; with DBR = the calling MODULE's bank, deliberately (kc_sys.s:
                ; the message pointer is a module literal), and _Sys_PanicImpl
                ; preserves it.  The cells below are kernel data, so take the
                ; bank from PHK -- this routine is in the kernel bank and is only
                ; ever entered by a same-bank JSR.  Without this the saved S and
                ; the char land in whatever module panicked.
                PHB
                PHK
                PLB
                STA    |_bcChar                 ; the bounce below clobbers A

                ;--- 1. PAGE-$01 BOUNCE (apple/fgx#176) ------------------------
                ; Same shape and same reason as block.s _blkSmartJump and
                ; clock.s _RtcFwRead/_RtcFwWrite.  CoutTramp does SEC/XCE to
                ; reach firmware COUT, and emulation mode forces the stack HIGH
                ; byte to $01.  Called on a stack outside page 1 -- the per-task
                ; kernel stacks are at FGX_STK_KTASKS ($E000) -- CoutTramp's
                ; PHP/PHB/PHD land at $E0xx while the post-XCE PLD/PLB/PLP read
                ; PAGE 1, so D, B and P come back as whatever page 1 held and the
                ; RTL returns through a garbage frame.
                ;
                ; If the caller is already on a page-$01 stack, keep it: the XCE
                ; is harmless there, and bouncing would push the firmware frame
                ; OVER the caller's own live page-1 frames.
                TSC
                STA    |_bcSavedS
                XBA
                AND     #$00FF                  ; A = caller stack high byte
                CMP     #$0001
                BEQ     @bc_rom                 ; SH==$01 -> already firmware-safe
                LDA     #FGX_STK_KERNEL+$FF     ; $01FF (page-1, firmware-safe)
                TCS

                ;--- 2. ROM BACK OVER $00:D000-$FFFF FOR THE CALL (apple/fgx#177)
                ; THE BOUNCE ALONE IS NOT ENOUGH, and this is the half that was
                ; actually killing the machine.  _LC_MapRam (main.s) maps bank-0
                ; language-card RAM over $00:D000-$FFFF at boot and LEAVES it
                ; mapped for the lifetime of the system, because the per-task
                ; kernel stacks live in the flat 8 KB above $E000.  $00:FDED is
                ; inside that window -- so from _LC_MapRam onward CoutTramp's
                ; `JSR $FDED` has not reached firmware COUT at all.  It has been
                ; jumping into language-card RAM.
                ;
                ; Measured, one variable at a time: SYS_PANIC replaced by a bare
                ; RTL -> probe survives; the five PutChars restored, page-1 bounce
                ; in place -> machine gone; the same plus this ROM window ->
                ; probe survives.  So the bounce is necessary and this is too.
                ;
                ; RESTORE WHAT WAS THERE, don't assume.  Far_Init's fatal-halt
                ; path emits through here BEFORE _LC_MapRam has run, and mapping
                ; LC RAM in behind _DetectHardware's back is exactly the class of
                ; thing this routine is being fixed for.  STATEREG bit 3 is the
                ; documented way to ask: "Bit 3 = RDROM status (read only RAM/ROM
                ; (0/1))" -- IIgs Firmware Reference, Appendix E, STATEREG.  Read
                ; only; the write-enable flip-flop is NOT in STATEREG ("The only
                ; way that you can find out whether or not the language-card RAM
                ; is write-enabled is by trying to write some data to the card's
                ; RAM space" -- IIgs Hardware Reference, ch.3, "Reading bank
                ; switches"), which is why the restore re-runs _LC_MapRam's own
                ; double read rather than writing a saved STATEREG back.
@bc_rom         SEP     #$20
                MX      %10
                LDAL    $E0C068                 ; STATEREG
                AND     #$08                    ; bit 3: 0 = LC RAM read-enabled
                STA    |_bcLcRom
                LDAL    $E0C082                 ; read ROM, write-protect LC
                REP     #$20
                MX      %00

                LDA    |_bcChar
_bcPutSmartJmp  JSL     $000000                 ; operand patched by _BootCon_Init

                SEP     #$20
                MX      %10
                LDA    |_bcLcRom
                BNE     @bc_lcdone              ; ROM was in on entry: leave it
                LDAL    $E0C08B                 ; read RAM, write-enable, bank 1
                LDAL    $E0C08B                 ;   ...twice: the write-enable
                                                ;   flip-flop needs two reads
                                                ;   (main.s _LC_MapRam)
@bc_lcdone      REP     #$20
                MX      %00

                LDA    |_bcSavedS
                TCS                             ; back on the caller's stack (a
                                                ;   no-op on the page-1 path)
                PLB                             ; caller's DBR, off the caller's
                                                ;   stack -- restored AFTER S
                PLP                             ; caller's I
                RTS

_bcSavedS       DS      2                       ; caller's S across the XCE
_bcChar         DS      2                       ; the char, across the bounce
_bcLcRom        DS      1                       ; STATEREG bit 3 on entry
