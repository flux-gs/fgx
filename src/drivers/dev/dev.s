;==============================================================================
; dev.s - FGX device layer.
;
; Public entry points:
;   Dev_Init           Called by kernel boot after Blk_Init.  _busTable[0]
;                      and _devTable[0] / _diskStates[0] were already
;                      populated by Blk_Init from the loader handoff.
;                      Dev_Init probes slots 1..7 (skipping the boot slot)
;                      for additional SmartPort controllers and enumerates
;                      their local units 1..SP_UNIT_MAX.
;
; DP scratch used (all caller-saved; no Con_* calls inside Dev_Init so
; no aliasing risk with console scratch at $D0-$EF):
;   _fsTmp0 lo = next-free bus idx  (0..FS_MAX_BUSES-1; starts at 1)
;   _fsTmp0 hi = current slot being probed (1..7)
;   _fsTmp1 lo = next-free dev idx  (0..FS_MAX_DEVICES-1; starts at 1)
;   _fsTmp1 hi = bus idx of bus just registered (for enumerateUnits)
;   _fsTmp2    = 16-bit scratch (bus table offset; state address)
;   _blkNum lo = local unit counter inside enumerateUnits (1..SP_UNIT_MAX)
;   _blkBuf lo = entry_lo scratch inside registerBus
;   _blkBuf hi = entry_hi scratch inside registerBus
;
; DBR: kernel-bank throughout ($02 = assembly ORG only).
;==============================================================================

                MX      %00

; BLK_CMD_OFFSET: byte offset of the SmartPort command byte within the
; bank-$00 trampoline, measured from the trampoline entry address.
; Mirrors the constant of the same name in block.s (kept local to avoid
; cross-segment EQU dependency).
BLK_CMD_OFFSET_D EQU    $0B             ; PHP PHB PHK PLB SEP#$30 SEC XCE JSR = 11 bytes

;==============================================================================
; Dev_Init - scan slots 1..7 for SmartPort controllers, enumerate units.
;==============================================================================
Dev_Init        ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10

                ; _busTable[0] already holds the boot bus (Blk_Init).  Start
                ; registering any other SmartPort controllers at idx 1.
                LDA     #1
                STA     _fsTmp0                 ; next-free bus idx
                LDA     #1
                STA     _fsTmp0+1               ; slot counter 1..7

@di_L           MX      %10
                LDA     _fsTmp0+1
                CMP     #8
                BCS     @di_done

                ; Skip the boot slot — already registered.
                LDA    |_busTable+BS_Slot
                CMP     _fsTmp0+1
                BEQ     @di_next

                ; Probe this slot for the SmartPort signature.
                JSR     _dev_probeSlot
                BCC     @di_next

                ; Bus table full?
                LDA     _fsTmp0
                CMP     #FS_MAX_BUSES
                BCS     @di_next

                JSR     _dev_registerBus

@di_next        SEP     #$20
                MX      %10
                INC     _fsTmp0+1
                BRA     @di_L

@di_done
                ; After all buses are registered, enumerate units on each.
                ; _fsTmp0 = total bus count.  Walk bus idx 0.._fsTmp0-1.
                ; For each bus: patch BlkTramp JSR target, then STATUS-probe
                ; each unit and allocate a _devTable entry per real device.
                SEP     #$20
                MX      %10
                LDA     #1
                STA     _fsTmp1                 ; next-free dev idx
                                                ; (_devTable[0] = boot disk, set by Blk_Init)
                LDA     #0
                STA     _fsTmp1+1               ; current bus idx

@di_busL        MX      %10
                LDA     _fsTmp1+1
                CMP     _fsTmp0                 ; bus count
                BCS     @di_enumDone

                JSR     _dev_patchBlkTramp

                ; Starting unit: 2 for bus 0 (skip known boot unit); 1 else.
                LDA     _fsTmp1+1
                BNE     @di_u1
                LDA     #2
                BRA     @di_uSet
@di_u1          LDA     #1
@di_uSet        STA     _blkNum

                JSR     _dev_enumBus

                INC     _fsTmp1+1
                BRA     @di_busL

@di_enumDone    PLP
                RTS

;==============================================================================
; _dev_probeSlot - check SmartPort signature at slot _fsTmp0+1.
;
; Checks: $Cn01=$20, $Cn03=$00, $Cn05=$03.
; Input:  _fsTmp0+1 = slot (1..7).  MX %10 on entry.
; Output: C=1 match, C=0 no match.
;==============================================================================
_dev_probeSlot  MX      %10
                LDX     #$01
                JSR     _dev_readSlotByte
                CMP     #$20
                BNE     @dps_no
                LDX     #$03
                JSR     _dev_readSlotByte
                CMP     #$00
                BNE     @dps_no
                LDX     #$05
                JSR     _dev_readSlotByte
                CMP     #$03
                BNE     @dps_no
                ; SmartPort distinguishes itself from Disk II via $CnFF:
                ;   $CnFF = $00  -> 5.25" Disk II (no SmartPort)
                ;   $CnFF != $00 -> SmartPort-capable
                ; Without this check we would accept slot 6's Disk II
                ; controller and then dispatch SmartPort commands into
                ; Disk II firmware, which hangs the CPU.
                LDX     #$FF
                JSR     _dev_readSlotByte
                CMP     #$00
                BEQ     @dps_no
                SEC
                RTS
@dps_no         CLC
                RTS

;==============================================================================
; _dev_readSlotByte - read byte from $00:Cn{X} for slot _fsTmp0+1.
;
; Self-modifying LDAL: `LDAL $000000,X` = $BF $00 $00 $00.
; Patch byte +2 (addr_hi) = $C0|slot; patch byte +3 (bank) = $00.
; Input:  _fsTmp0+1 = slot; X (8-bit) = page offset.
; Output: A (8-bit) = byte read.  X unchanged.
;==============================================================================
_dev_readSlotByte MX    %10
                LDA     _fsTmp0+1
                ORA     #$C0
                STA     @rdIns+2        ; patch addr_hi = $C0|slot
                LDA     #$00
                STA     @rdIns+3        ; patch bank = $00
@rdIns          LDAL    $000000,X       ; +2/+3 patched
                RTS

;==============================================================================
; _dev_registerBus - register a SmartPort bus in _busTable.
;
; Reads [$CnFF] to derive the firmware entry ($Cn00 + [$CnFF] + 3).
; Populates _busTable[_fsTmp0] with slot, entry, unit_count=0, flags=0.
; Increments _fsTmp0.  Logs "spN at slot M".
;
; Input (MX %10):
;   _fsTmp0   = next-free bus idx
;   _fsTmp0+1 = slot (1..7)
; Clobbers:  A, X, Y, _blkBuf, _blkBuf+1.
;==============================================================================
_dev_registerBus MX     %10
                PHP
                SEP     #$20
                MX      %10

                ; 1. Read firmware-entry offset from $CnFF.
                LDX     #$FF
                JSR     _dev_readSlotByte       ; A = [$CnFF]

                ; 2. Full entry: lo = [CnFF] + 3 (captures carry);
                ;                hi = ($C0 | slot) + carry.
                CLC
                ADC     #3
                STA     _blkBuf                 ; entry_lo
                LDA     _fsTmp0+1
                ORA     #$C0
                ADC     #0                      ; + carry
                STA     _blkBuf+1               ; entry_hi

                ; 3. bus_offset (16-bit X) = bus_idx * 8.
                REP     #$20
                MX      %00
                LDA     _fsTmp0
                AND     #$00FF
                ASL
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10

                ; 4. Populate _busTable[bus_offset].
                LDA     _fsTmp0+1
                STA    |_busTable+BS_Slot,X
                LDA     _blkBuf
                STA    |_busTable+BS_EntryLo,X
                LDA     _blkBuf+1
                STA    |_busTable+BS_EntryHi,X
                LDA     #0
                STA    |_busTable+BS_EntryBank,X    ; firmware in bank $00
                STA    |_busTable+BS_UnitCount,X
                STA    |_busTable+BS_Flags,X

                ; 5. Increment bus idx.
                INC     _fsTmp0

                ; 6. Log "spN at slot M", BSD's controller line: the bus
                ;    is named before the units on it are.
                REP     #$20
                MX      %00
                LDA     #@drb_pfx
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                SEP     #$20
                MX      %10
                LDA     _fsTmp0
                SEC
                SBC     #1                      ; bus idx just used
                CLC
                ADC     #'0'
                JSR     _kernLogPutByte

                REP     #$20
                MX      %00
                LDA     #@drb_mid
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                SEP     #$20
                MX      %10
                LDA     _fsTmp0+1
                CLC
                ADC     #'0'
                JSR     _kernLogPutByte
                JSR     Kern_LogEOL

                PLP
                RTS

@drb_pfx        ASC     'sp',00
@drb_mid        ASC     ' at slot ',00

;==============================================================================
; _dev_patchBlkTramp - patch BlkTramp's inline JSR target to a bus's firmware.
;
; Input (MX %10):  _fsTmp1+1 = target bus idx.
; Effects:         BlkTramp+9 = BS_EntryLo, BlkTramp+10 = BS_EntryHi.
;                  BlkTramp's JSR target (bank $00 16-bit) now dispatches
;                  to that bus's SmartPort firmware.
; Clobbers:        A, X, Y.
;==============================================================================
_dev_patchBlkTramp MX   %10
                PHP
                SEP     #$20
                MX      %10

                ; bus_offset (16-bit X) = _fsTmp1+1 * 8
                REP     #$20
                MX      %00
                LDA     _fsTmp1+1
                AND     #$00FF
                ASL
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10

                LDY     #9
                LDA    |_busTable+BS_EntryLo,X
                STA     [_blkEntryPtr],Y
                INY                             ; Y=10
                LDA    |_busTable+BS_EntryHi,X
                STA     [_blkEntryPtr],Y

                PLP
                RTS

;==============================================================================
; _dev_rawStatus - call SmartPort STATUS (code $00) for a unit, via BlkTramp.
;
; Input (MX %10):  _blkNum (low byte) = SmartPort unit to probe.
;                  BlkTramp+9/+10 already patched to target bus.
; Output:          C=1 + result bytes at $00:BLK_STAGE, or C=0 on error.
; Clobbers:        A, X, Y.
;==============================================================================
_dev_rawStatus  MX      %10
                PHP
                SEP     #$20
                MX      %10

                ; BlkTramp+11 = command byte (SP_STATUS = $00).
                LDY     #$0B
                LDA     #SP_STATUS
                STA     [_blkEntryPtr],Y

                ; Params at [_blkTrampPtr]: +1=unit, +2/+3=buf ptr, +4=status code.
                LDY     #$01
                LDA     _blkNum
                STA     [_blkTrampPtr],Y
                LDY     #$02
                LDA     #<BLK_STAGE             ; low byte; DERIVED, do not
                                                ;   pin a value in a comment --
                                                ;   BLK_STAGE moves with
                                                ;   kernel.nproc
                STA     [_blkTrampPtr],Y
                INY
                LDA     #>BLK_STAGE             ; high byte (the comment here
                                                ;   said $20; it has been $17
                                                ;   since 2026-08-06 and now
                                                ;   derives)
                STA     [_blkTrampPtr],Y
                INY                             ; Y=4
                LDA     #0                      ; generic status code
                STA     [_blkTrampPtr],Y

                JSR     _blkFwCall              ; DP-protected (block.s _blkFwCall)
                BCS     @drs_err
                PLP
                SEC
                RTS
@drs_err        MX      %10
                PLP
                CLC
                RTS

;==============================================================================
; _dev_enumBus - enumerate STATUS-responding units on the current bus,
; allocating a _devTable + _diskStates entry for each.
;
; Input (MX %10):  _blkNum = starting unit (1 for non-boot bus, 2 for boot).
;                  _fsTmp1 = next-free dev idx.
;                  _fsTmp1+1 = current bus idx.
;                  BlkTramp already patched by _dev_patchBlkTramp.
; Effects:         Asks unit 0 how many devices the port has, then for each
;                  real unit (STATUS ok + blk_count > 0) calls
;                  _dev_allocDevEntry which populates tables + logs + bumps
;                  _fsTmp1.  0-block units are skipped (not end-of-chain);
;                  stops at the port's own device count, a STATUS failure, or
;                  the device-table cap.  Clobbers _devUnitLimit.
;==============================================================================
_dev_enumBus    MX      %10
                PHP
                SEP     #$20
                MX      %10

                ;--- THE ROLL CALL, BEFORE WALKING ANYTHING ---------------
                ; SmartPort says how many devices it has, and asking is the
                ; protocol's own answer to "how far do I scan":
                ;
                ;   "A STATUS call to unit 0 with status code $00 returns the
                ;    number of devices on the bus in the first payload byte.
                ;    Walk the units from 1 upward..."
                ;       -- Programming the FujiNet for the Apple II, p.9
                ;
                ; WHY THIS MATTERS AND A BARE CEILING DOES NOT.  The walk below
                ; ends on a STATUS failure, which is real -- $28 NODRIVE, "no
                ; such unit on the bus" -- but it only arrives AFTER the unit
                ; has been asked for.  With the ceiling at SP_UNIT_MAX that is
                ; up to 126 speculative calls into a card that never claimed to
                ; have that many devices, on every slot, at every boot.  A card
                ; is entitled to be unamused by a question about unit 90.
                ; Asking first means FGX only ever addresses units the port has
                ; said exist.
                ;
                ; A PORT THAT DOES NOT ANSWER KEEPS THE OLD BEHAVIOUR rather
                ; than being assumed empty: the limit falls back to
                ; SP_UNIT_MAX+1 and the STATUS-failure exit does the work, which
                ; is exactly what this loop did before the roll call existed.
                ; Deciding "no answer means no devices" would silently drop
                ; every device on a card whose unit 0 is unimplemented.
                LDA     _blkNum                 ; the caller's starting unit
                PHA
                STZ     _blkNum                 ; unit 0 = the port itself
                JSR     _dev_rawStatus
                BCC     @deu_noroll
                LDAL    BLK_STAGE               ; first payload byte = count
                BEQ     @deu_noroll             ; a zero count says nothing
                CMP     #SP_UNIT_MAX
                BCC     @deu_clamped
                LDA     #SP_UNIT_MAX            ; never past the protocol max
@deu_clamped    INC     A                       ; limit = count + 1
                STA    |_devUnitLimit
                BRA     @deu_rolled
@deu_noroll     LDA     #SP_UNIT_MAX+1
                STA    |_devUnitLimit
@deu_rolled     PLA
                STA     _blkNum                 ; restore the starting unit

@deu_L          MX      %10
                LDA     _blkNum
                CMP    |_devUnitLimit           ; what the PORT said it has
                BCS     @deu_done
                LDA     _fsTmp1
                CMP     #BDEV_SD_ROW0+BDEV_NSD
                BCS     @deu_done               ; every sd unit is taken

                JSR     _dev_rawStatus
                BCC     @deu_done               ; STATUS failed -> end of chain

                ; A STATUS-ok unit reporting 0 blocks (e.g. an EMPTY 3.5 drive
                ; at slot-5 unit 1) is NOT end-of-chain.  SKIP it and keep
                ; scanning so a later unit (e.g. the Control-Panel RAM disk) is
                ; still found.  The scan stays bounded by the port's own device
                ; count, the BDEV_NSD check and the STATUS-fail exit.
                ; ALL THREE BYTES of the count: a volume of an exact multiple
                ; of 65,536 blocks has zeroes in the low two (apple/fgx#443).
                LDAL    BLK_STAGE+1
                BNE     @deu_real
                LDAL    BLK_STAGE+2
                BNE     @deu_real
                LDAL    BLK_STAGE+3
                BNE     @deu_real
                BRA     @deu_next

@deu_real       JSR     _dev_allocDevEntry      ; populates + logs + bumps _fsTmp1

@deu_next       INC     _blkNum
                BRA     @deu_L

@deu_done       PLP
                RTS

;==============================================================================
; _dev_allocDevEntry - populate _devTable[_fsTmp1] and _diskStates[_fsTmp1]
; for the unit currently probed, bump the bus's unit count, log the line,
; then increment _fsTmp1.
;
; Input (MX %10):
;   _fsTmp1   = dev idx to allocate
;   _fsTmp1+1 = current bus idx
;   _blkNum   = local unit
;   BLK_STAGE+1/+2 = block count lo/hi (STATUS response)
; Effects:
;   _devTable[_fsTmp1] fully populated (class, flags, name, ops, state ptr).
;   _diskStates[_fsTmp1] fully populated (bus_idx, local_unit, blk_count).
;   _busTable[_fsTmp1+1].BS_UnitCount += 1.
;   _fsTmp1 incremented.
; Clobbers:  A, X, Y, _blkBuf, _blkBuf+1, _devAllocSlot.
;
; It used to clobber _blkBuf+2 as well and not say so -- and _blkBuf+2 is
; _blkNumHi, the block layer's block-key high word (apple/fgx#81).  The slot
; scratch now lives in _devAllocSlot, a byte this layer owns.
;==============================================================================
_dev_allocDevEntry MX   %10
                PHP
                SEP     #$20
                MX      %10

                ;--- 1. Compute _devPtr = dev_table_ptr + _fsTmp1 * DEV_SIZE.
                REP     #$20
                MX      %00
                LDA     _fsTmp1
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL                             ; *16
                CLC
                ADC     dev_table_ptr
                STA     _devPtr
                SEP     #$20
                MX      %10
                LDA     dev_table_ptr+2
                ADC     #0                      ; +carry from 16-bit add
                STA     _devPtr+2

                ;--- 2. DEV_Class + DEV_Flags via [_devPtr],Y.
                LDY     #DEV_Class
                LDA     #DEV_CLASS_DISK
                STA     [_devPtr],Y
                LDY     #DEV_Flags
                LDA     #DEV_FLAG_ONLINE
                STA     [_devPtr],Y

                ;--- 3. DEV_Name = "sNdM\0\0" ---
                LDY     #DEV_Name
                LDA     #'s'
                STA     [_devPtr],Y

                ; Slot digit — look up _busTable[_fsTmp1+1].BS_Slot.
                REP     #$20
                MX      %00
                LDA     _fsTmp1+1
                AND     #$00FF
                ASL
                ASL
                ASL                             ; *8 (bus entry size)
                TAX
                SEP     #$20
                MX      %10
                LDA    |_busTable+BS_Slot,X
                STA    |_devAllocSlot           ; stash slot (NOT _blkBuf+2 --
                                                ;   that is _blkNumHi; #81)

                LDA    |_devAllocSlot
                CLC
                ADC     #'0'
                LDY     #DEV_Name+1
                STA     [_devPtr],Y
                LDA     #'d'
                LDY     #DEV_Name+2
                STA     [_devPtr],Y
                LDA     _blkNum
                CLC
                ADC     #'0'
                LDY     #DEV_Name+3
                STA     [_devPtr],Y
                LDA     #0
                LDY     #DEV_Name+4
                STA     [_devPtr],Y
                LDY     #DEV_Name+5
                STA     [_devPtr],Y

                ;--- 4. DEV_Ops: vestigial (never dispatched — SmartPort uses
                ;       direct JSR _SP_ReadBlock / _blkSmartJump).  The
                ;       _SmartPortDiskOps vtable + its baked-$02 ^ capture are
                ;       removed; DEV_Ops* slots are reserved pad (never read).

                ;--- 5. DEV_State = &_diskStates[_fsTmp1] ---
                ; 16-bit state address into _blkBuf (scratch).
                REP     #$20
                MX      %00
                LDA     _fsTmp1
                AND     #$00FF
                ASL
                ASL
                ASL                             ; *8 (DSS_SIZE)
                CLC
                ADC     #_diskStates
                STA     _blkBuf                 ; 16-bit state addr
                SEP     #$20
                MX      %10
                LDA     _blkBuf
                LDY     #DEV_StateLo
                STA     [_devPtr],Y
                LDA     _blkBuf+1
                LDY     #DEV_StateHi
                STA     [_devPtr],Y
                PHK                             ; DEV_StateBank := live kernel bank (where _diskStates
                PLA                             ;   lives), not the baked assembly ORG $02 — reloc-safe
                LDY     #DEV_StateBank
                STA     [_devPtr],Y

                ;--- 6. Populate _diskStates[_fsTmp1] (16-bit X = _fsTmp1 *
                ;       DSS_SIZE).  THE SAME STRIDE AS STEP 5, which computed
                ;       the DEV_State pointer: the two must agree or the record
                ;       points at one entry and the bytes land in another.
                REP     #$20
                MX      %00
                LDA     _fsTmp1
                AND     #$00FF
                ASL
                ASL
                ASL                             ; *8 (DSS_SIZE)
                TAX
                SEP     #$20
                MX      %10
                ; Reloc (Class L): _diskStates is read DBR-relative by _SP_ReadBlock at
                ; DBR=kernel-bank.  Set DBR=kernel-bank (PHK/PLB) for the writes so they
                ; land in the relocated kernel bank, matching the read; a plain
                ; assembled STA/STAL would bake the $02 assembly ORG and split the banks.
                ; (BLK_STAGE reads stay LDAL — they target the bank-$00 SmartPort status
                ; staging.)
                PHB
                PHK
                PLB                             ; DBR = kernel bank ($20 reloc / $02 native)
                LDA     _fsTmp1+1
                STA     _diskStates+DSS_BusIdx,X
                LDA     _blkNum
                STA     _diskStates+DSS_LocalUnit,X
                ; THREE BYTES, LSB FIRST, and a zero fourth: the standard
                ; STATUS call returns a 3-byte count (Firmware Reference p.123)
                ; and the dropped high byte is what made a 131,072-sector
                ; volume attach as empty.  apple/fgx#407.
                LDAL    BLK_STAGE+1
                STA     _diskStates+DSS_BlkCount,X
                LDAL    BLK_STAGE+2
                STA     _diskStates+DSS_BlkCount+1,X
                LDAL    BLK_STAGE+3
                STA     _diskStates+DSS_BlkCount+2,X
                LDA     #0
                STA     _diskStates+DSS_BlkCount+3,X
                PLB                             ; restore DBR

                ;--- 7. Bump _busTable[_fsTmp1+1].BS_UnitCount ---
                REP     #$20
                MX      %00
                LDA     _fsTmp1+1
                AND     #$00FF
                ASL
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA    |_busTable+BS_UnitCount,X
                CLC
                ADC     #1
                STA    |_busTable+BS_UnitCount,X

                ;--- 8. Log "sdN at spB unit U: <size>", NetBSD's attach line
                ;    (sys/scsi/cd.c: "cd%d at %s%d targ %d lun %d: %s") -- the
                ;    device, where it was found, then what it is.  The row is
                ;    the sd unit (include/fs.s, BDEV_SD_ROW0).
                REP     #$20
                MX      %00
                LDA     #@dae_pfx
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _fsTmp1
                AND     #$00FF
                SEC
                SBC     #BDEV_SD_ROW0
                JSR     Kern_LogDec16
                LDA     #@dae_mid
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _fsTmp1+1               ; bus idx
                AND     #$00FF
                JSR     Kern_LogDec16
                LDA     #@dae_unit
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _blkNum                 ; SmartPort unit on that bus
                AND     #$00FF
                JSR     Kern_LogDec16
                LDA     #@dae_colon
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                ; ---- AND ITS SIZE.  2.11BSD prints one (`ra0: RA82
                ; size=1954000').  BLK_STAGE still holds the status result
                ; this routine stored into the disk state a few lines up.
                JSR     Dev_LogSize
                SEP     #$20
                MX      %10

                ;--- 9. Increment dev idx ---
                INC     _fsTmp1

                PLP
                RTS

@dae_pfx        ASC     'sd',00
@dae_mid        ASC     ' at sp',00
@dae_unit       ASC     ' unit ',00
@dae_colon      ASC     ': ',00

;==============================================================================
; Dev_LogSize - end the attach line with the size in BLK_STAGE+1..3:
; "<blocks> blocks (<KB>KB)" and the newline.  Shared with block.s's boot-drive
; line.
;
; ALL THREE BYTES.  The standard STATUS count is three bytes (Firmware
; Reference p.123), so a 64 MB volume is 131,072 blocks; printed as sixteen
; bits it attached as "0 blocks (0KB)" (apple/fgx#443).  A device block is 512
; bytes, so KB is the 24-bit count shifted right once.
;
; Caller MX %00, DBR = kernel bank.  Clobbers A, X, Y.
;==============================================================================
Dev_LogSize     ENT
                MX      %00
                LDAL    BLK_STAGE+3
                AND     #$00FF
                TAX
                LDAL    BLK_STAGE+1
                JSR     Kern_LogDec32
                LDA     #@dls_blks
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDAL    BLK_STAGE+3
                AND     #$00FF
                LSR     A                       ; bit 16 -> C
                TAX
                LDAL    BLK_STAGE+1
                ROR     A                       ; ...into bit 15
                JSR     Kern_LogDec32
                LDA     #@dls_kb
                STA     _conStrPtr
                JMP     Kern_LogStr

@dls_blks       ASC     ' blocks (',00
@dls_kb         ASC     'KB)',00

;==============================================================================
; END dev.s
;==============================================================================
