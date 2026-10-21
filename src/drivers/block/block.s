;==============================================================================
; block.s - SmartPort block driver.
;
; Public:
;   Blk_Init   Patch internal JSL trampoline from $02BF01..$02BF06 handoff.
;
;   Blk_Read   Read one 512-byte block.
;              Input:  _fsCurDevIdx (byte) = device index (0-based into _devTable)
;                      _blkNum (word) = block number
;                      _blkBuf (word) = dest pointer in bank $02
;              Output: C=1 ok, C=0 + A=EIO on error.
;
;   Blk_Status Issue SmartPort STATUS for current device.
;              Input:  _fsCurDevIdx (byte) = device index
;                      _blkNum (word) = status code (low byte)
;              Output: C=1 ok, C=0 + A=EIO on error; result at $00:BLK_STAGE.
;
; DP contract:
;   _fsCurDevIdx (DP)       - device index (caller fills; Blk_* computes _devPtr)
;   _devPtr (DP, 3B)        - long ptr to device record (filled by Blk_Read shim)
;   _blkNum ($10, word)     - block number (caller fills before Blk_Read)
;   _blkBuf ($12, word)     - dest buffer in bank $02 (caller fills)
;   _blkTrampPtr ($F0, 3B)  - long pointer to BlkTrampParams in bank $00
;                             (filled by Blk_Init, read-only thereafter)
;
; SmartPort is called via a bank-$00 trampoline (BlkTramp in loader.s).
; The trampoline uses JSR + inline bytes as firmware expects, then RTLs
; back to bank $02.  Kernel JSLs _blkSmartJump which JSLs the trampoline.
;
; Before the JSL, Blk_Read writes buffer and block number to BlkTrampParams
; in bank $00 via STA [_blkTrampPtr],Y.  Count and unit are preset by the
; loader and never written here.
;
; BlkTrampParams layout (offsets from _blkTrampPtr base):
;   +0  param count ($03, preset)
;   +1  unit        ($01, preset)
;   +2  buffer low   <- Blk_Read writes
;   +3  buffer high  <- Blk_Read writes
;   +4  block low    <- Blk_Read writes
;   +5  block mid    <- Blk_Read writes
;   +6  block high   <- Blk_Read writes ($00 always)
;==============================================================================

                MX      %00

; Equates this segment depends on (read-only; declared locally because
; block.s is assembled as link-file segment #2 — its own assembly unit).
                PUT     ../../../include/config.s  ; CFG_ layout EQUs
                                                   ;   fs.s BLK_STAGE reads
                PUT     ../../../include/errno.s
                PUT     ../../../include/fs.s
                PUT     ../../../include/kernel.s  ; FGX_DATA (memmap base)
                PUT     ../../../include/memmap.s  ; BlkTramp handoff labels
                PUT     ../../../include/dpmap.s   ; _blkNum, _blkBuf, _blkTrampPtr

; RAM-disk block I/O lives in the kernel main segment (src/drivers/ramdisk).
_RAM_ReadBlock  EXT
_RAM_WriteBlock EXT
; The boot drive's inventory line is built in pieces -- text, then the size,
; which dev.s's Dev_LogSize prints for every attach line -- so it needs more
; than the whole-string entry blkcache.s already declares for this segment.
Kern_LogStrNoEOL EXT
Dev_LogSize     EXT
Dev_Reprobe     EXT

;------------------------------------------------------------------------------
; Blk_Init - initialize driver from loader handoff data.
;
; Reads the trampoline entry and params addresses from the bank-$02 handoff
; area written by the loader:
;   $02BF01/$02BF02/$02BF03  = BlkTramp lo/hi/bank  -> _blkSmartJump+1..+3
;   $02BF04/$02BF05/$02BF06  = BlkTrampParams lo/hi/bank -> _blkTrampPtr
;------------------------------------------------------------------------------
Blk_Init        ENT
                MX      %00
                PHP
                SEP     #$20
                MX      %10
                ; Patch the _blkSmartJump JSL operand with trampoline entry
                ; addr.  The JSL is at _blkSmartCall (not _blkSmartJump+0) —
                ; the entry now runs a page-1 stack-bounce preamble first.
                LDA    |_BlkTramp_EntryLo
                STA     |_blkSmartCall+1        ; DBR-rel (2A.1): patch the LIVE dynamic-bank
                LDA    |_BlkTramp_EntryHi       ; _blkSmartCall JSL cell.  _blkSmartJump now runs
                STA     |_blkSmartCall+2        ; from the relocated copy (called via JSR), so a
                LDA    |_BlkTramp_EntryBank     ; baked-$02 STAL here would patch only the dead
                STA     |_blkSmartCall+3        ; $02 copy -> the live cell would JSL $00:0000.
                ; Store trampoline entry as long ptr in DP (for cmd-byte patching).
                LDA    |_BlkTramp_EntryLo
                STA     _blkEntryPtr
                LDA    |_BlkTramp_EntryHi
                STA     _blkEntryPtr+1
                LDA    |_BlkTramp_EntryBank
                STA     _blkEntryPtr+2
                ; Store trampoline params long pointer in DP.
                LDA    |_BlkTramp_ParamsLo
                STA     _blkTrampPtr
                LDA    |_BlkTramp_ParamsHi
                STA     _blkTrampPtr+1
                LDA    |_BlkTramp_ParamsBank
                STA     _blkTrampPtr+2
                ; Default device index = 0 (boot device, _devTable[0]).
                LDA     #$00
                STA     _fsCurDevIdx
                ; Populate _busTable[0] = boot bus.
                ; BS_Entry* holds the SmartPort firmware entry ($Cn00 + [$CnFF] + 3),
                ; NOT BlkTramp.  The loader wrote the firmware entry to
                ; BlkTramp+9/+10 (the inline `JSR $Cn00` target); recover it
                ; from there via [_blkEntryPtr],Y.  _blkSmartJump stays pointed
                ; at BlkTramp forever; per-bus switching re-patches the JSR
                ; target inside BlkTramp at offsets 9/10.
                ;
                ; Slot number = low nibble of the firmware entry HIGH byte
                ; ($Cn → slot n).
                LDY     #9
                LDA     [_blkEntryPtr],Y        ; firmware entry lo (from BlkTramp+9)
                STA    |_busTable+BS_EntryLo
                INY                             ; Y=10
                LDA     [_blkEntryPtr],Y        ; firmware entry hi (from BlkTramp+10)
                STA    |_busTable+BS_EntryHi
                AND     #$0F                    ; slot = low nibble of $Cn
                STA    |_busTable+BS_Slot
                LDA     #$00                    ; firmware is in bank $00
                STA    |_busTable+BS_EntryBank
                LDA     #0
                STA    |_busTable+BS_UnitCount  ; Dev_Init fills in phase 5
                LDA     #$01
                STA    |_busTable+BS_Flags      ; bit 0 = boot bus

                ;--- Populate _devTable[0] = boot disk (sNd1) ---
                ; _devPtr = dev_table_ptr (entry [0] = base of table).
                ; main.s _AllocDevTable ran before us and already populated
                ; dev_table_ptr.  Set lo+hi as 16-bit, then bank as 8-bit.
                REP     #$20
                MX      %00
                LDA     dev_table_ptr
                STA     _devPtr
                SEP     #$20
                MX      %10
                LDA     dev_table_ptr+2
                STA     _devPtr+2

                LDY     #DEV_Class
                LDA     #DEV_CLASS_DISK
                STA     [_devPtr],Y
                LDY     #DEV_Flags
                LDA     #DEV_FLAG_ONLINE
                STA     [_devPtr],Y

                ; Name: "s<slot>d1\0"
                LDY     #DEV_Name
                LDA     #'s'
                STA     [_devPtr],Y
                LDA    |_busTable+BS_Slot
                CLC
                ADC     #'0'
                LDY     #DEV_Name+1
                STA     [_devPtr],Y
                LDA     #'d'
                LDY     #DEV_Name+2
                STA     [_devPtr],Y
                LDA     #'1'
                LDY     #DEV_Name+3
                STA     [_devPtr],Y
                LDA     #0
                LDY     #DEV_Name+4
                STA     [_devPtr],Y
                LDY     #DEV_Name+5
                STA     [_devPtr],Y

                ; DEV_Ops: vestigial — never dispatched (the SmartPort path uses
                ; direct JSR _SP_ReadBlock / _blkSmartJump, not a vtable).  The
                ; _SmartPortDiskOps vtable + its baked-$02 ^ capture are removed;
                ; the DEV_Ops* struct slots are left as reserved pad (never read).

                ; State ptr = _diskStates[0]
                LDA     #<_diskStates
                LDY     #DEV_StateLo
                STA     [_devPtr],Y
                LDA     #>_diskStates
                LDY     #DEV_StateHi
                STA     [_devPtr],Y
                PHK                             ; DEV_StateBank := live kernel bank (where _diskStates
                PLA                             ;   lives), not the baked assembly ORG $02 — reloc-safe
                LDY     #DEV_StateBank
                STA     [_devPtr],Y

                ; Disk state: bus=0, unit=1, blkcount=0 (unknown yet)
                ; Reloc (Class L): _diskStates is read DBR-relative by _SP_ReadBlock
                ; ((_fsTmp0),Y) at DBR=kernel-bank (the FS path runs DBR=kernel-bank).
                ; But Blk_Init itself runs at DBR=$02, so a plain DBR-rel STA here
                ; would land in $02 — splitting the banks under relocation (read
                ; unit=0 -> SmartPort read fails).  Set DBR=kernel-bank (PHK/PLB) for
                ; these writes so they land in the relocated kernel bank, then restore.
                PHB
                PHK
                PLB                             ; DBR = kernel bank ($20 reloc / $02 native)
                LDA     #0
                STA     _diskStates+DSS_BusIdx
                LDA     #1
                STA     _diskStates+DSS_LocalUnit
                LDA     #0
                STA     _diskStates+DSS_BlkCount
                STA     _diskStates+DSS_BlkCount+1
                STA     _diskStates+DSS_BlkCount+2
                STA     _diskStates+DSS_BlkCount+3
                PLB                             ; restore DBR

                PLP
                RTS

;==============================================================================
; Blk_LogBootDev - announce the boot disk, in the shape Dev_Init uses for the
; rest of the bus.
;
; SEPARATE FROM Blk_Init SO THE CALLER CAN ORDER IT.  A BSD boot log names the
; CONTROLLER and then the units on it, and this line has to fall after
; _LogBlkCaps and before Dev_Init to read that way.  Blk_Init runs long before
; the console exists, so everything here reaches the ring and _BootScreen's
; replay puts it on screen in ring order -- which is exactly why the ordering
; is decided by the call site rather than by where the device is registered.
;==============================================================================
Blk_LogBootDev  ENT
                MX      %00
                PHP
                PHB
                PHK
                PLB                             ; DBR = this bank, for the string
                ; THE BOOT DISK WAS THE ONE DRIVE THE LOG NEVER MENTIONED.  It
                ; is registered HERE, as _devTable[0], before any enumeration
                ; runs -- so Dev_Init's loop, which prints every unit it finds,
                ; never sees it.  A storage inventory that omits the drive the
                ; machine booted from is the one line a reader most needs.
                ; It is always unit 1 of bus 0 and always /dev/sd0, so the
                ; bus's own line goes first, as Dev_Init prints one for every
                ; other bus.  THE SLOT DIGIT IS PATCHED INTO THE STRING.
                SEP     #$20
                MX      %10
                LDA    |_busTable+BS_Slot
                CLC
                ADC     #'0'
                STA    |_blkBootSlot
                REP     #$30
                MX      %00
                LDA     #_blkBootBus
                STA     _conStrPtr
                JSR     Kern_LogStr
                LDA     #_blkBootMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL

                ; ---- AND ITS SIZE, which 2.11BSD prints too (`ra0: RA82
                ; size=1954000') and which nothing here has ever reported.
                ;
                ; THE BOOT DRIVE'S BLOCK COUNT WAS PERMANENTLY ZERO.  Blk_Init
                ; zeroes DSS_BlkCount for _devTable[0] and nothing ever
                ; filled them: Dev_Init's scan writes the count for every unit
                ; it ENUMERATES, and the boot device is registered before that
                ; scan and so is never one of them.  The status call below is
                ; what the scan makes for the others, so the record is correct
                ; afterwards rather than only the log line.
                SEP     #$20
                MX      %10
                LDA     #$00
                STA     _fsCurDevIdx            ; the boot device
                REP     #$30
                MX      %00
                LDA     #$0000                  ; $00 = generic status
                STA     _blkNum
                JSR     Blk_Status
                BCC     @blb_nosize             ; no answer: say nothing rather
                SEP     #$20                    ;   than print a zero
                MX      %10
                ; ALL THREE BYTES the standard STATUS call returns, in the
                ; table and on the line (apple/fgx#407, apple/fgx#443).
                LDAL    BLK_STAGE+1
                STA     _diskStates+DSS_BlkCount
                LDAL    BLK_STAGE+2
                STA     _diskStates+DSS_BlkCount+1
                LDAL    BLK_STAGE+3
                STA     _diskStates+DSS_BlkCount+2
                LDA     #0
                STA     _diskStates+DSS_BlkCount+3
                REP     #$30
                MX      %00
                JSR     Dev_LogSize             ; the byte stores above left
                                                ;   BLK_STAGE untouched
                PLB
                PLP
                RTS
@blb_nosize     ; A status the drive did not answer ends the line without a
                ; figure rather than printing a zero.  Kern_LogStr appends the
                ; newline, so an empty string closes it -- Kern_LogEOL is not a
                ; cross-segment entry and exporting a third one to end a line
                ; is not worth it.
                REP     #$30
                MX      %00
                LDA     #_blkBootNone
                STA     _conStrPtr
                JSR     Kern_LogStr

                PLB
                PLP
                RTS

_blkBootBus     ASC     'sp0 at slot '
_blkBootSlot    ASC     '?',00
_blkBootMsg     ASC     'sd0 at sp0 unit 1: ',00
_blkBootNone    ASC     '',00

;------------------------------------------------------------------------------
; Blk_Read - read one block into caller's bank-$02 buffer.
;
; Thin shim: resolves _devPtr from _fsCurDevIdx, then JSRs _SP_ReadBlock
; which handles all SmartPort interaction and the bank-$00 staging/MVN.
;
; Input:  _fsCurDevIdx (byte) = device index (0-based into _devTable)
;         _blkNum (word) = block number
;         _blkBuf (word) = bank-$02 dest pointer (16-bit offset, bank fixed $02)
; Output: C=1 ok, C=0 + A=EIO on error.
; Clobbers: A, X, Y, DBR (MVN leaves DBR = the dst bank = live kernel bank;
;           $02 = assembly ORG); _libcTmp2 (RAM-class devices). Callers that
;           need X/Y must PHX/PHY before JSR Blk_Read.
; PRESERVES _fsTmp0/_fsTmp1 (2026-07-18): the disk paths clobber them
;           internally but Blk_Read saves/restores, so hit and miss are
;           behaviorally identical.  _fsTmp2 was already preserved: the
;           ProDOS free-block count needed it to survive a read, and the
;           guarantee outlived that caller, which was deleted with the bitmap.
;------------------------------------------------------------------------------
; BLK_STAGE is declared in include/fs.s (shared between block driver and
; fs driver's SmartPort enumeration).
BLK_CMD_OFFSET  EQU     $0B                 ; cmd byte offset from BlkTramp entry
                                            ; (PHP PHB PHK PLB SEP#$30 SEC XCE
                                            ; JSR $Cn00 = 8+3 bytes; cmd at +11)
BLK_EXTBANK_OFFSET EQU  $0E                 ; ^ParmList word for an EXTENDED
                                            ; ($4x) call: cmd(+11) DW parms
                                            ; (+12/+13), bank word at +14/+15.
                                            ; Reads NOP NOP for standard calls
                                            ; (loader.s BlkTrampExtBank).

Blk_Read        ENT
                MX      %00
                PHP
                ;--- Diagnostic: bump _kBlkReadCount (32-bit, byte carry chain).
                ; Cheap (~25 cycles) vs SmartPort I/O (~thousands).  Read by
                ; SYS_KSTAT for spotting block-read amplification.
                PHA
                ;--- 32-bit key latch (UFS deliverable 1.0).  Take the caller's
                ; high word and CLEAR the DP cell in the same breath, so the
                ; NEXT caller -- a 16-bit one for a long time yet -- cannot
                ; inherit it.  Everything downstream reads _blkCurHi. ---
                LDA     _blkNumHi
                STA    |_blkCurHi
                STZ     _blkNumHi
                ;--- Buffer BANK latch, same one-shot discipline (UFS 1.3c).
                ; 0 means the live kernel bank, which is what every legacy
                ; caller wants and never sets. ---
                LDA    |_blkBufBank
                STA    |_blkCurBufBank
                STZ    |_blkBufBank
                SEP     #$20
                MX      %10
                INC     _kBlkReadCount
                BNE     @bkr_brcDone
                INC     _kBlkReadCount+1
                BNE     @bkr_brcDone
                INC     _kBlkReadCount+2
                BNE     @bkr_brcDone
                INC     _kBlkReadCount+3
@bkr_brcDone    REP     #$20
                MX      %00
                ; Sequential?  _blkRaSeq is set when this request continues the
                ; previous one.  Read-ahead is worth doing ONLY for streaming;
                ; firing it on the index and directory blocks that interleave a
                ; file read turns every request into a 4 KB transfer.
                LDA     _blkNum
                SEC
                SBC    |_blkRaLast
                DEC                             ; ==0 iff blk == last+1
                STA    |_blkRaSeq
                LDA     _blkNum
                STA    |_blkRaLast
                PLA
                ;--- Compute _devPtr = dev_table_ptr + _fsCurDevIdx * DEV_SIZE ---
                SEP     #$20
                MX      %10
                LDA     _fsCurDevIdx
                REP     #$20
                MX      %00
                AND     #$00FF              ; zero-extend to 16-bit
                ASL                         ; * 16 (DEV_SIZE = 16)
                ASL
                ASL
                ASL
                CLC
                ADC     dev_table_ptr       ; heap base lo+hi (16-bit)
                STA     _devPtr
                SEP     #$20
                MX      %10
                LDA     dev_table_ptr+2
                ADC     #0                  ; +carry from 16-bit add
                STA     _devPtr+2
                ;--- A MEDIUM THAT MAY HAVE CHANGED IS PROBED BEFORE ANYTHING
                ; ELSE READS ITS RECORD: the sector size decides the read path
                ; below, and a stale size would read the wrong bytes (fs.s,
                ; DEV_FLAG_STALE). ---
                LDY     #DEV_Flags
                LDA     [_devPtr],Y
                AND     #DEV_FLAG_STALE
                BEQ     @bkr_fresh
                REP     #$30
                MX      %00
                JSR     Dev_Reprobe
                SEP     #$20
                MX      %10
@bkr_fresh
                ;--- Owned by vfs_bio?  Then the legacy cache never sees this
                ; device (UFS 1.3c).  Derived once here and read at four points
                ; below; see DEV_FLAG_VFSOWNED. ---
                LDY     #DEV_Flags
                LDA     [_devPtr],Y
                AND     #DEV_FLAG_VFSOWNED
                STA    |_blkNoCache
                ;--- F2-c: cache consult — a hit skips the device entirely
                ;    (pool -> _blkBuf MVN; DBR ends = live kernel bank, the
                ;    same exit state the disk path leaves). ---
                REP     #$30
                MX      %00
                LDA    |_blkNoCache
                AND     #$00FF
                BNE     @bkr_miss               ; vfs_bio owns it: straight to
                                                ;   the device, no consult
                JSR     _BlkCache_Fetch
                BCC     @bkr_miss
                PLP
                SEC
                RTS
@bkr_miss       ; _fsTmp0/1 preservation (2026-07-18): the DISK paths clobber
                ; them (_SP_* device-state scratch; _RamDisk_BlkAddr's shift
                ; math) while the cache-HIT path preserves them — so callers
                ; holding state in _fsTmp0/1 across Blk_Read worked by luck
                ; until F3 invalidate-on-write re-introduced misses on
                ; freshly-written blocks (the wild-free ls corruption class;
                ; bitmap.s and prodos.s @rd_freeLoop documented CONTRADICTORY
                ; survival contracts).  Save here / restore at every post-miss
                ; exit so hit and miss are behaviorally identical.
                LDA     _fsTmp0
                PHA
                LDA     _fsTmp1
                PHA
                SEP     #$20
                MX      %10
                ;--- Class dispatch: RAM devices use the in-kernel copy path
                ;    (no SmartPort).  DEV_Class is field offset 0; [_devPtr]
                ;    is DP-indirect-long so it reads the dev-table heap bank,
                ;    DBR-independent. ---
                LDY     #DEV_Class
                LDA     [_devPtr],Y             ; M=8: device class byte
                ;--- AN UNREGISTERED SLOT IS NOT A DEVICE, apple/fgx#220.
                ; _AllocDevTable zero-fills all FS_MAX_DEVICES slots so "empty
                ; slots read DEV_Class = 0" -- its words -- and DEV_CLASS_EMPTY
                ; is that zero, named in include/fs.s since the table existed.
                ; Nothing tested it here, so a request naming a slot nobody
                ; registered fell past the RAM arm into `_SP_ReadBlock' on a
                ; device whose bus, slot and unit are all zero.  SmartPort PIO
                ; SPINS (kc_sys.s says so where it explains why the block layer
                ; cannot sleep), so the machine did not fault -- it STOPPED.
                ;
                ; That is the /dev-absent boot hang: dev_mount scans units
                ; 0..DEV_MAXUNIT and stops at the first that answers, so with
                ; the volume attached the higher slots are never reached and
                ; with it missing the scan walks into them.  A real IIgs with
                ; one drive is that machine.
                CMP     #DEV_CLASS_EMPTY
                BEQ     @bkr_noDev
                CMP     #DEV_CLASS_RAM
                BEQ     @bkr_ram
                ;--- READ-AHEAD (extended buses): fill a whole aligned run of
                ; cache slots with ONE $48 call, then serve this block from the
                ; cache.  Cost is per CALL, not per byte, so K blocks per call
                ; divides the call count by K.  Bails to the single-block path
                ; whenever it cannot be done safely (not extended, cache not up,
                ; run wraps $FFFF, any slot pinned) -- so this is an
                ; optimisation with a full fallback, not a new requirement. ---
                REP     #$30
                MX      %00
                DO      BLKCACHE_RA_ON=1
                ; Read-ahead fills POOL slots, so a vfs-owned device must not
                ; enter it -- and would not want to: its strategy issues
                ; consecutive 512-byte pairs, which look like streaming to
                ; _blkRaSeq and would drive read-ahead across metadata.
                LDA    |_blkNoCache
                AND     #$00FF
                BNE     @bkr_noRa
                JSR     _BlkCache_ReadAhead
                BCC     @bkr_noRa
                JSR     _BlkCache_Fetch         ; now a hit; pool -> _blkBuf
                BCS     @bkr_raDone
                FIN
                ; Cannot happen: ReadAhead just validated this block's slot.
                ; If it ever does, fall through to the device rather than
                ; returning the caller a buffer nobody filled.
@bkr_noRa
                ;--- A 2048-BYTE UNIT HAS NO SINGLE-BLOCK PATH: its ReadBlock
                ;    returns the first 512 bytes of SECTOR b, not block b.  A
                ;    read the read-ahead could not do fails rather than return
                ;    the wrong quarter. ---
                SEP     #$20
                MX      %10
                LDY     #DEV_Flags
                LDA     [_devPtr],Y
                AND     #DEV_FLAG_SEC2K
                BEQ     @bkr_sp
                LDA     #EIO
                BRA     @bkr_err
@bkr_sp
                ;--- Dispatch to _SP_ReadBlock (callee PHP/PLP preserves M/X) ---
                REP     #$30
                MX      %00
                JSR     _SP_ReadBlock
                BCC     @bkr_err
                LDA    |_blkNoCache             ; vfs-owned: do not populate
                AND     #$00FF                  ;   (AND leaves carry alone)
                BNE     @bkr_raDone
                JSR     _BlkCache_WrOk          ; F2-c: read-miss populate
@bkr_raDone     PLA
                STA     _fsTmp1
                PLA
                STA     _fsTmp0
                PLP
                SEC
                RTS
@bkr_ram        REP     #$30
                MX      %00
                JSR     _RAM_ReadBlock
                BCC     @bkr_err
                LDA    |_blkNoCache             ; vfs-owned: do not populate
                AND     #$00FF
                BNE     @bkr_ramDone
                JSR     _BlkCache_WrOk          ; F2-c: read-miss populate
@bkr_ramDone    PLA
                STA     _fsTmp1
                PLA
                STA     _fsTmp0
                PLP
                SEC
                RTS
@bkr_noDev      MX      %10                     ; reached only from the
                                                ;   M=8 class read above
                ; EIO, WHICH IS AN errno AND NOT AN `ERR_' (apple/fgx#334).
                ; This value leaves the driver through kc_blkio, and
                ; bio_strategy puts whatever it gets straight into `b_error'
                ; for biowait to hand back as the caller's errno -- so an FGX
                ; ERR_ number arriving here is read by userland as the errno
                ; with the same value.  ERR_NODEV is $0A, and `mount /dev/sd3'
                ; on a unit with no drive printed "No child processes" (ECHILD,
                ; 10).  A message about the CALLER's children, for a drive that
                ; is not there.
                ;
                ; EIO AND NOT ENXIO, which is the other plausible answer: on
                ; 2.11BSD a node for an absent unit answers `mount /dev/ra5a
                ; /mnt: Input/output error', and the reason is structural
                ; rather than a choice -- ENXIO is what a driver's OPEN returns,
                ; and FGX's block layer has no open entry point at all
                ; (spec_open's VBLK arm says so; kc_blkio is stateless per
                ; call).  What fails here is a READ, and a read that cannot
                ; reach its device is EIO.  This file's other seven error arms
                ; already answer EIO, and Blk_Read's own header has said
                ; `C=0 + A=EIO on error' the whole time.
                LDA     #EIO                    ; M=8; @bkr_err widens it
                BRA     @bkr_err
@bkr_err        REP     #$30                    ; both BCC sources run MX %00;
                MX      %00                     ;   force it (tracker + machine)
                AND     #$00FF                  ; errno lo (callee loaded it M=8)
                TAY                             ; A survives the restore via Y
                PLA
                STA     _fsTmp1
                PLA
                STA     _fsTmp0
                TYA
                PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; Blk_Status - issue SmartPort STATUS and land the result at $00:BLK_STAGE.
;
; Thin shim: resolves _devPtr from _fsCurDevIdx, then JSRs _SP_Status.
;
; Input:  _fsCurDevIdx (byte) = device index (0-based into _devTable)
;         _blkNum  (word) = status code in low byte; high byte ignored
;                           ($00 = generic status, $03 = device info block)
; Output: C=1 ok, C=0 + A=EIO on error.
;         Result bytes written at $00:BLK_STAGE — caller reads via LDAL.
; Clobbers: A, X, Y, DBR.
;
; Shares the bank-$00 trampoline with Blk_Read (via _SP_Status); patches
; the cmd byte on the way in.
;------------------------------------------------------------------------------
Blk_Status      ENT
                MX      %00
                PHP
                ;--- Compute _devPtr = dev_table_ptr + _fsCurDevIdx * DEV_SIZE ---
                SEP     #$20
                MX      %10
                LDA     _fsCurDevIdx
                REP     #$20
                MX      %00
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     dev_table_ptr
                STA     _devPtr
                SEP     #$20
                MX      %10
                LDA     dev_table_ptr+2
                ADC     #0
                STA     _devPtr+2
                ;--- Class dispatch: RAM devices have no SmartPort bus/unit ---
                LDY     #DEV_Class
                LDA     [_devPtr],Y             ; M=8: device class byte
                ;--- AN UNREGISTERED SLOT IS NOT A DEVICE, apple/fgx#220.
                ; _AllocDevTable zero-fills all FS_MAX_DEVICES slots so "empty
                ; slots read DEV_Class = 0" -- its words -- and DEV_CLASS_EMPTY
                ; is that zero, named in include/fs.s since the table existed.
                ; Nothing tested it here, so a request naming a slot nobody
                ; registered fell past the RAM arm into `_SP_Status' on a
                ; device whose bus, slot and unit are all zero.  SmartPort PIO
                ; SPINS (kc_sys.s says so where it explains why the block layer
                ; cannot sleep), so the machine did not fault -- it STOPPED.
                ;
                ; That is the /dev-absent boot hang: dev_mount scans units
                ; 0..DEV_MAXUNIT and stops at the first that answers, so with
                ; the volume attached the higher slots are never reached and
                ; with it missing the scan walks into them.  A real IIgs with
                ; one drive is that machine.
                CMP     #DEV_CLASS_EMPTY
                BEQ     @bks_noDev
                CMP     #DEV_CLASS_RAM
                BEQ     @bks_ram
                ;--- Dispatch to _SP_Status ---
                REP     #$30
                MX      %00
                JSR     _SP_Status
                BCC     @bks_err
                PLP
                SEC
                RTS
@bks_ram        ; RAM device: no SmartPort bus/unit.  Nothing asks a RAM
                ; device for its size or free space through Blk_Status -- the
                ; ProDOS mount path read both from the volume header and the
                ; bitmap, and df goes through the VFS mount list now -- so a
                ; synthetic "online" (C=1) suffices; do NOT issue a (wild)
                ; SmartPort STATUS. (BLK_STAGE is left as-is; no RAM consumer
                ; reads status bytes today.)
                PLP
                SEC
                RTS
@bks_noDev      MX      %10                     ; reached only from the
                                                ;   M=8 class read above
                LDA     #EIO                    ; M=8, which is @bks_err's width
                                                ;   (an errno, not an ERR_ --
                                                ;   see @bkr_noDev above)
@bks_err        MX      %10
                PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; _blkSmartJump - JSL into bank-$00 trampoline.
;
; Operand ($000000) is patched by Blk_Init to BlkTramp's address in bank $00.
; The trampoline performs JSR + inline SmartPort bytes + RTL; that RTL lands
; here, and we RTS back to Blk_Read.  SmartPort leaves C=error, A=errno.
;
; STACK-PAGE-NEUTRAL (Phase 3c): BlkTramp does SEC/XCE to call the SmartPort
; firmware in emulation mode, and emulation mode forces the 65816 stack high
; byte to $01.  When a syscall handler runs on a per-task kernel stack
; (FGX_STK_KTASKS+(pid<<8), i.e. $E1xx..$ECxx in the language card -- NOT the
; $11xx this comment claimed until the region moved) that XCE would relocate the
; stack to $01xx and the handler's frame would be lost on return (→ ROM
; crash).  This was the real cause of the 3a/3b/3c-1/#3 "non-page-1 kernel
; stack crashes" — NOT the per-task region itself (native toolbox calls like
; NewHandle ran fine there).  Fix: before the firmware excursion, save the
; caller's S and move to the static $0100 stack (free during a syscall —
; abandoned after boot handoff); restore the caller's S afterward.  SmartPort
; I/O is synchronous (no yield inside) so $0100 is never contended across a
; cooperative switch.  See feedback_kernel_stack_must_be_page1_for_emul_firmware.
;
;------------------------------------------------------------------------------
; THE INVARIANT THIS RELIES ON, WRITTEN DOWN (apple/fgx#185).  Every caller:
;
;   A caller must not move S off page 1 while it still has a LIVE page-1 frame
;   it intends to return through.
;
; "Free during a syscall" above is a claim about ONE caller, and it was read as
; a property of page 1.  It is not.  The moment a caller leaves page 1 with
; frames still live there, page 1 stops being the caller's and becomes
; scratch -- and not only this routine's scratch:
;
;   - three other sites bounce here deliberately (clock.s:201, :293 for the
;     RTC, boot_console.s:112 for CoutTramp);
;   - and EVERY INTERRUPT lands there, because the ROM's handler "Switches to
;     emulation mode" going to the interrupt environment (Apple IIgs Firmware
;     Reference, ch.8, "Interrupt-Handler Firmware"), and emulation mode forces
;     the stack high byte to $01.  No operand in this tree can move that one.
;
; That last clause is why the obvious repair does NOT work.  Giving the
; firmware excursion a private page-1 window that is never a caller's stack
; would fix the three deliberate sites and leave the interrupt handler writing
; wherever it writes.  The rule has to hold at the CALLER.
;
; MEASURED, apple/fgx#183: _Probe_Drive moved S to $ECFF while Mod_LoadConf,
; Mod_Load and mod_init still had frames at $01EF..$01FF.  The frame was
; destroyed ONE VBL TICK later, and the byte at $01EF was written not by this
; routine but by the kernel's own heartbeat task, _HBTickTask's PHB at
; toolbox.s.  The probe then ran to completion, logged its pass, and returned
; into FGX_SYSVARS.
;
; _Probe_Drive is the only code in the tree that creates the situation today,
; and since #183 it honours the rule by PARKING its caller's live page-1 bytes
; and putting them back (src/modules/common/probe_dev.s).  Anything new that
; wants a deep kernel stack owes the same.
;------------------------------------------------------------------------------
_blkSmartJump   ENT
                MX      %10
                ; Decide which stack the firmware excursion runs on.  If the
                ; caller is ALREADY on a page-$01 stack (boot, or a _curTask==0
                ; syscall on the static $0100 stack), keep it — the firmware's
                ; XCE is harmless there, and bouncing would push the firmware
                ; frame OVER the caller's own live page-1 frames.  If the caller
                ; is on a per-task kernel stack ($E1xx, $E2xx, ...), bounce to
                ; the static $0100 stack so the XCE doesn't strand the per-task
                ; frame.  Single JSL site either way (Blk_Init patches
                ; _blkSmartCall+1..+3).
                ;
                ; PAGE 1 IS FREE HERE BECAUSE THE CALLER LEFT NOTHING LIVE IN
                ; IT -- the invariant in this routine's header, and NOT a
                ; property of page 1.  This comment used to read "free during a
                ; syscall", which is true of the caller it was written for and
                ; was then read as the latter (apple/fgx#185).
                REP     #$30
                MX      %00
                TSC
                STA    |_blkSavedS              ; full caller S
                XBA
                AND     #$00FF                  ; A = SH (caller stack high byte)
                CMP     #$0001
                BEQ     @bsj_call               ; SH==$01 → already firmware-safe
                LDA     #FGX_STK_KERNEL+$FF     ; $01FF (page-1, firmware-safe)
                TCS
@bsj_call       SEP     #$30
                MX      %10
_blkSmartCall   JSL     $000000             ; operand patched to BlkTramp addr
                ; BlkTramp returns C=error, A=errno (MX %10).  Restore the
                ; caller's S without disturbing C (the error flag) or A (errno):
                ; STAL/REP/SEP/TCS preserve C; LDAL clobbers A, so stash errno.
                ; On the page-1 path the restore is a harmless no-op (S unchanged).
                STA    |_blkRetA
                REP     #$30
                MX      %00
                LDA    |_blkSavedS
                TCS                         ; back on the caller's stack
                SEP     #$30
                MX      %11
                LDA    |_blkRetA            ; A = errno (C still = error)
                RTS                         ; called via JSR (2-byte stack, same-bank now) — must RTS

;==============================================================================
; (_SmartPortDiskOps vtable removed — Phase-3 cleanup.  It was wired into every
; disk device record's DEV_Ops slot but NEVER dispatched: the SmartPort path
; calls _SP_ReadBlock/_SP_WriteBlock/_SP_Status directly (via _blkSmartJump).
; Its `^_SP_*`/`^_SmartPortDiskOps` bytes were the last vestigial baked-$02
; captures.  _SP_ReadBlock etc. below are still live, called directly.)
;==============================================================================
; _blkFwCall - call the ROM SmartPort firmware trampoline (_blkSmartJump) with
; the caller's direct page protected from the firmware's inherited-D scratch.
;
; The Apple IIgs internal 3.5"/IWM SmartPort ROM driver (slot 5) does 6502/ZP-
; style direct-page scratch at whatever D it inherits -- i.e. straight into
; FGX's relocated kernel DP -- on EVERY SmartPort call (READ/WRITE/STATUS;
; observed it overwriting DP $48/$51-52/$58-59 etc.).  That clobbered
; _fd_table_ptr (DP $48) with a block number -> bogus EMFILE -> Con_Init font-
; load failure -> black-screen boot off the internal 3.5" drive.  Slot-7
; SmartPort *cards* use their own scratch, so HD/SmartPort boots never hit it.
;
; We CANNOT repoint D for the call: the firmware uses D for its own control flow
; and crashes to ROM if D is moved (tried D=$0000 and a dedicated page; both
; crashed every boot path).  So snapshot the WHOLE caller DP page (D+$00..$FF)
; to a free bank-0 page ($0F00-$0FFF, the dead loader IDX_BUF post-handoff),
; make the call, and restore.  D-relative -> protects whatever task DP the
; caller runs under; the 256-byte copy is negligible vs SmartPort I/O latency.
;
; ALL SmartPort firmware calls MUST go through here -- never JSR _blkSmartJump
; directly (_SP_ReadBlock/_SP_Status/_SP_WriteBlock, dev.s _dev_rawStatus).
;
; In/Out: transparent -- identical to _blkSmartJump (C = firmware result,
;         A/X/Y clobbered).  Caller M/X preserved.
;==============================================================================
_blkFwCall      ENT
                ; Standard ProDOS/GS-OS/GNO SmartPort convention: call the ROM
                ; firmware with D=$0000, so its 6502/ZP-style direct-page scratch
                ; lands in the real (free) zero page -- NOT FGX's relocated kernel
                ; DP ($B000).  The loader's own stage-1/2 SmartPort reads already
                ; run at D=$0000 and drive the internal IWM SmartPort on every
                ; floppy boot, so D=$0000 is correct for it too; the old whole-DP-
                ; page snapshot was a pre-stack-fix (pre-Phase-3c) workaround that
                ; also could NOT rescue the Apple II SCSI card -- that firmware
                ; READS zero page and HANGS forever with a non-zero inherited D
                ; (the snapshot/restore never runs because the call never returns).
                ; Callers enter MX %10; _blkSmartJump returns C=result, A=errno.
                REP     #$30
                MX      %00
                PHD                         ; save caller (kernel) direct page
                LDA     #$0000
                TCD                         ; D = $0000 (firmware-safe zero page)
                SEP     #$30
                MX      %11
                JSR     _blkSmartJump       ; C=result, A=errno (MX %11)
                PLD                         ; restore caller DP (16-bit pull; C+A intact)
                RTS

;==============================================================================
; _SP_ReadBlock - SmartPort disk-class read operation.
;
; Input:  _devPtr (DP long ptr) = device record address.
;         _blkNum                = word block number.
;         _blkBuf                = word bank-$02 dest buffer offset.
; Output: C=1 ok, C=0 + A=errno on error.
; Clobbers: A, X, Y, DBR (MVN leaves DBR = the dst bank = live kernel bank;
; $02 = assembly ORG).  Preserves caller M/X via PHP/PLP.
;
; Looks up bus + local unit from device state, patches the shared
; bank-$00 trampoline target + command byte, stages the SmartPort
; request in BlkTrampParams, JSLs, MVNs 512 B to caller buffer.
;==============================================================================
_SP_ReadBlock   ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00

                ;--- Load device state pointer into _fsTmp0 (bank-$02 offset) ---
                SEP     #$20
                MX      %10
                LDY     #DEV_StateLo
                LDA     [_devPtr],Y
                STA     _fsTmp0
                INY                             ; DEV_StateHi
                LDA     [_devPtr],Y
                STA     _fsTmp0+1
                ; DEV_StateBank skipped: _diskStates lives in the kernel bank and is
                ; read DBR-relative below ((_fsTmp0),Y), and we run at DBR=kernel-bank
                ; here (caller's DBR).  Reloc: writers store _diskStates DBR-relative
                ; too (block.s Blk_Init / dev.s _dev_allocDevEntry) so both banks agree.

                ;--- Read DSS_BusIdx + DSS_LocalUnit via DP indirect ---
                LDY     #DSS_BusIdx
                LDA     (_fsTmp0),Y
                STA     _fsTmp1                 ; bus idx (low byte)
                LDY     #DSS_LocalUnit
                LDA     (_fsTmp0),Y
                STA     _fsTmp1+1               ; local unit

                ;--- Patch BlkTramp's internal JSR target (+9/+10) with
                ;--- the bus's firmware entry.  _blkSmartJump stays pointed
                ;--- at BlkTramp; only the JSR target inside changes per-bus.
                REP     #$20
                MX      %00
                LDA     _fsTmp1
                AND     #$00FF                  ; bus idx (word, high = 0)
                ASL                             ; * 8 B per bus entry
                ASL
                ASL
                TAX                             ; X = bus offset
                SEP     #$20
                MX      %10
                LDY     #9
                LDA    |_busTable+BS_EntryLo,X
                STA     [_blkEntryPtr],Y
                INY                             ; Y=10
                LDA    |_busTable+BS_EntryHi,X
                STA     [_blkEntryPtr],Y

                ;--- Extended bus?  Then read STRAIGHT INTO the caller's buffer.
                ; The standard path can only name a bank-0 buffer, so it reads
                ; into BLK_STAGE and MVNs 512 B to the real destination -- 3,584
                ; cycles (~1.3 ms at 7 MHz) of pure copy per block.  An extended
                ; call's buffer pointer is a LONGWORD, so the firmware writes the
                ; caller's bank directly and that copy disappears.
                ; Gated, not blind: on a bus without $CnFB bit 7 a $4x call does
                ; not return AT ALL (measured on CFFA2 and A2retroNET). ---
                LDA    |_busTable+BS_Flags,X
                AND     #BS_FLAG_EXT
                BNE     @sprb_ext

                ;--- Patch SmartPort command byte ---
                LDY     #BLK_CMD_OFFSET
                LDA     #SP_READ_BLOCK
                STA     [_blkEntryPtr],Y

                ;--- Write param list at [_blkTrampPtr] ---
                LDY     #$01
                LDA     _fsTmp1+1               ; local unit
                STA     [_blkTrampPtr],Y
                LDY     #$02
                LDA     #<BLK_STAGE             ; $00
                STA     [_blkTrampPtr],Y
                INY
                LDA     #>BLK_STAGE             ; $20
                STA     [_blkTrampPtr],Y
                INY                             ; Y=4
                LDA     _blkNum
                STA     [_blkTrampPtr],Y
                INY
                LDA     _blkNum+1
                STA     [_blkTrampPtr],Y
                INY
                ; Block byte 2.  A STANDARD SmartPort call carries THREE block
                ; bytes, so this bus reaches 2^24 blocks (8 GB) and no further;
                ; bits 24-31 must be zero or the request is unrepresentable and
                ; would silently address the wrong block.  Refuse it instead.
                LDA    |_blkCurHi+1
                BEQ     @sprb_bhOK
                JMP     @sprb_err
@sprb_bhOK      LDA    |_blkCurHi
                STA     [_blkTrampPtr],Y

                ;--- Trampoline call.  Goes through _blkFwCall (NOT directly to
                ; _blkSmartJump) so the kernel DP is protected from the ROM
                ; driver's inherited-D scratch.  See _blkFwCall. ---
                JSR     _blkFwCall
                BCS     @sprb_err

                ;--- Success: MVN 512 B to caller buffer ---
                ; Relocation: the dst bank was baked $02 (kernel).  Patch it to the
                ; live kernel bank from the bank-0 anchor so the block lands in the
                ; relocated kernel's buffer, not the stale $02 copy.  Patch the copy
                ; we're executing (DBR=PB); the anchor value is always the live bank.
                PHK
                PLB                             ; DBR = executing copy's bank
                SEP     #$20
                MX      %10
                ; ...unless the caller named a bank of its own (UFS 1.3c): the
                ; vfs_bio arena cannot live in the core bank, so _blkCurBufBank
                ; overrides when nonzero.
                LDA    |_blkCurBufBank
                BNE     @sprb_dstSet
                LDAL    KFGX_ANCHOR             ; A.lo = live kernel bank
@sprb_dstSet    STA     @sprb_mvn+1             ; patch dst-bank (MVN encoding +1)
                REP     #$30
                MX      %00
                LDX     #BLK_STAGE              ; src offset ($1700 in bank 0)
                LDY     _blkBuf                 ; dst offset
                LDA     #511
@sprb_mvn       MVN     $00,$02                 ; dst-bank patched at runtime
                PLP
                SEC
                RTS

@sprb_err       MX      %10                     ; caller at M=0; BCS preserves P
                LDA     #EIO
                PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; EXTENDED read ($41).  Same trampoline, three differences: the command carries
; bit 6, the inline structure grows the ^ParmList word at +14/+15, and the
; parameter list's buffer and block fields are longwords.  No MVN afterwards --
; the firmware already wrote the caller's bank.
;------------------------------------------------------------------------------
@sprb_ext       MX      %10
                LDY     #BLK_CMD_OFFSET
                LDA     #SP_READ_BLOCK+$40      ; $41
                STA     [_blkEntryPtr],Y

                ; +14/+15 = ^ParmList.  BlkTrampParams lives in bank 0, so the
                ; bank word is $0000.  Without this the firmware reads its bank
                ; from the BCS opcode and never comes back.
                LDY     #BLK_EXTBANK_OFFSET
                LDA     #$00
                STA     [_blkEntryPtr],Y
                INY
                STA     [_blkEntryPtr],Y

                ; Param list: cnt($03, static) / unit / buffer LONG / block LONG.
                LDY     #$01
                LDA     _fsTmp1+1               ; local unit
                STA     [_blkTrampPtr],Y
                INY                             ; +2 buffer lo
                LDA     _blkBuf
                STA     [_blkTrampPtr],Y
                INY                             ; +3 buffer hi
                LDA     _blkBuf+1
                STA     [_blkTrampPtr],Y
                INY                             ; +4 buffer BANK -- the live
                LDA    |_blkCurBufBank          ; kernel bank, from the bank-0
                BNE     @sprb_extBank           ; anchor (the ORG is $02 but the
                LDAL    KFGX_ANCHOR             ; kernel runs relocated) -- or
@sprb_extBank   STA     [_blkTrampPtr],Y        ; the caller's own bank (1.3c).
                INY                             ; The FIRMWARE writes this one:
                                                ; there is no MVN on the
                                                ; extended path, so the bank
                                                ; here IS the landing bank.
                LDA     #$00                    ; +5 buffer bank hi
                STA     [_blkTrampPtr],Y
                INY                             ; +6 block lo
                LDA     _blkNum
                STA     [_blkTrampPtr],Y
                INY                             ; +7 block hi
                LDA     _blkNum+1
                STA     [_blkTrampPtr],Y
                ; +8/+9 carry the top HALF of the block number.  An EXTENDED
                ; ($4x) call's block field is a full longword, so this bus
                ; needs no range check -- it addresses the whole 32-bit space
                ; the 2.11BSD daddr_t names.
                INY                             ; +8 block bank
                LDA    |_blkCurHi
                STA     [_blkTrampPtr],Y
                INY                             ; +9 block bank hi
                LDA    |_blkCurHi+1
                STA     [_blkTrampPtr],Y

                JSR     _blkFwCall
                MX      %11                     ; TRUTH, not a claim: _blkSmartJump
                                                ; returns through SEP #$30, so A and
                                                ; X/Y are BOTH 8-bit here.  Leaving
                                                ; the directive at %10 makes Merlin
                                                ; emit a 3-byte LDY the CPU runs as
                                                ; 2, and the stray byte executes as
                                                ; BRK -- which looks exactly like a
                                                ; firmware hang and is not.
                STA    |_blkExtErr              ; errno NOW: the NOP restore below
                                                ; loads A, and $EA read afterwards
                                                ; is not the firmware's answer

                ; Put the NOPs back BEFORE anything branches: the very next
                ; STANDARD call through this trampoline executes +14/+15 on its
                ; way to the BCS, and a leftover bank word there is not code.
                ; Stores do not touch carry, so the call's result survives.
                LDY     #BLK_EXTBANK_OFFSET
                LDA     #$EA                    ; NOP
                STA     [_blkEntryPtr],Y
                INY
                STA     [_blkEntryPtr],Y
                BCS     @sprb_extErr

                PLP
                SEC
                RTS

                ; A FAILED $41 MEANS THE BUS DOES NOT DO EXTENDED READS, whatever
                ; the code -- latch it off and reissue the read on the standard
                ; path.  $CnFB said the INTERFACE understands extended calls, and
                ; on the IIgs's DB19 port the interface and the device are two
                ; different boxes: Apple's slot-5 firmware in front of a FloppyEmu
                ; or a FujiNet that speaks only the standard command set.
                ; apple/fgx#119.
                ;
                ; ANY error, and that is the whole lesson of the first cut of this
                ; fix.  It tested for BADCMD ($01) alone, on the reasoning that a
                ; medium error should stay an error rather than downgrade the bus.
                ; MEASURED ON HARDWARE 2026-08-15: the FujiNet booted -- it is a
                ; software SmartPort and returns BADCMD properly -- and the
                ; FloppyEmu did not.  A device that simply DOES NOT ANSWER an
                ; unknown command leaves the firmware to time out, and what comes
                ; back is a bus/IO error that says nothing about the command set.
                ; Predicting which code a standard-only device produces is the same
                ; mistake as trusting $CnFB: it is a guess about a box we cannot
                ; see, and the boot was riding on it.
                ;
                ; The cost of being wrong the other way is now bounded and small:
                ; a genuine medium error downgrades the bus for the rest of the
                ; boot, and the standard retry fails too, so the caller still gets
                ; its EIO.  The boot log names the path actually in use, so the
                ; downgrade is visible rather than silent.  _blkExtErr keeps the
                ; code that caused it.
                ;
                ; Not a try-and-fall-back on ANY bus: with $CnFB bit 7 CLEAR a $4x
                ; call does not return at all (measured on CFFA2 and A2retroNET),
                ; so there is nothing to recover to.  The interface gate above is
                ; what makes this second question safe to ask.
@sprb_extErr    MX      %11
                ; X is NOT the bus offset here -- the firmware returns its transfer
                ; count in X/Y and preserves neither (apple/fgx#111).  Recompute
                ; from _fsTmp1, which it cannot reach: it runs at D=$0000 and the
                ; kernel DP is elsewhere.
                LDA     _fsTmp1                 ; bus idx
                ASL
                ASL
                ASL                             ; * 8 B per bus entry
                TAX
                LDA    |_busTable+BS_Flags,X
                AND     #$FF-BS_FLAG_EXT-BS_FLAG_MB
                STA    |_busTable+BS_Flags,X

                ; Re-enter with the flag clear, which takes the standard arm.
                ; _blkNum/_blkBuf/_devPtr are untouched by the extended arm, and
                ; the recursion is one level deep by construction: the flag this
                ; path just cleared is what sent us here.
                PLP
                MX      %00                     ; PLP restored the caller's, which
                                                ; is what _SP_ReadBlock expects
                JMP     _SP_ReadBlock

;==============================================================================
; _Blk_DevIsExt - does THIS device's bus honour extended calls?
;
; Read-ahead must ask before it touches anything: on a bus without $CnFB bit 7
; a $4x call does not return at all, so "try it and fall back" is not available.
; Asking per DEVICE rather than assuming the boot bus keeps this honest when a
; second controller is present.
;
; In:  _devPtr = device record.   Out: C=1 extended, C=0 not.
; Clobbers A, X, Y, _fsTmp0/1 (all inside Blk_Read's save/restore window).
; MX:  caller %00; preserved.
;==============================================================================
_Blk_DevIsExt   MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                LDY     #DEV_StateLo
                LDA     [_devPtr],Y
                STA     _fsTmp0
                INY
                LDA     [_devPtr],Y
                STA     _fsTmp0+1
                LDY     #DSS_BusIdx
                LDA     (_fsTmp0),Y
                STA     _fsTmp1
                REP     #$20
                MX      %00
                LDA     _fsTmp1
                AND     #$00FF
                ASL
                ASL
                ASL
                TAX                             ; X = bus offset (8 B/entry)
                SEP     #$20
                MX      %10
                LDA    |_busTable+BS_Flags,X
                AND     #BS_FLAG_MB             ; multi-block, not merely extended
                BEQ     @bdie_no
                PLP
                SEC
                RTS
@bdie_no        PLP
                CLC
                RTS

;==============================================================================
; _SP_ReadBlockN - EXTENDED multi-block read ($48), the whole point of the
; extended bus.  One firmware call transfers _blkRaCount BYTES of consecutive
; disk blocks starting at _blkNum into the long destination _blkRaDstOff/Bank.
;
; This is the lever that matters: a read costs per CALL, not per byte (measured
; 2026-08-03 -- removing the per-block staging MVN bought only 2.4%, while the
; same workload swings 35% between cards on identical code).  Reading K blocks
; per call divides the call count by K.
;
; NO per-call ceiling from the card: the limit is the 2-byte byte-count field,
; i.e. 65,535 B = 127 whole blocks (swept and verified clean to $FFE0 on
; 2026-07-31).  The Firmware Reference's "may not be larger than 767 bytes"
; caveat is per-implementation and does not bind these cards.
;
; Input:  _devPtr = device record; _blkNum = FIRST block; _blkRaDstOff/Bank =
;         destination; _blkRaCount = byte count.
; Output: C=1 ok, C=0 + A=EIO.  Caller MX %00; preserved via PHP/PLP.
; CALLER MUST HAVE CHECKED BS_FLAG_EXT -- a $4x call on a standard bus does not
; return at all.
;==============================================================================
_SP_ReadBlockN  ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00

                ;--- Device state -> bus idx + local unit (as _SP_ReadBlock) ---
                SEP     #$20
                MX      %10
                LDY     #DEV_StateLo
                LDA     [_devPtr],Y
                STA     _fsTmp0
                INY
                LDA     [_devPtr],Y
                STA     _fsTmp0+1
                LDY     #DSS_BusIdx
                LDA     (_fsTmp0),Y
                STA     _fsTmp1
                LDY     #DSS_LocalUnit
                LDA     (_fsTmp0),Y
                STA     _fsTmp1+1

                ;--- Patch the trampoline's JSR target for this bus ---
                REP     #$20
                MX      %00
                LDA     _fsTmp1
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
                INY
                LDA    |_busTable+BS_EntryHi,X
                STA     [_blkEntryPtr],Y

                ;--- Command = extended Read ($08+$40) ---
                LDY     #BLK_CMD_OFFSET
                LDA     #SP_READ+$40            ; $48
                STA     [_blkEntryPtr],Y

                ;--- +14/+15 = ^ParmList ($0000: the list is in bank 0) ---
                LDY     #BLK_EXTBANK_OFFSET
                LDA     #$00
                STA     [_blkEntryPtr],Y
                INY
                STA     [_blkEntryPtr],Y

                ;--- Param list: cnt=4 / unit / buffer LONG / byteCount /
                ;    block LONG.  Read ($08) carries a byte count that
                ;    ReadBlock ($01) does not, so paramCount is 4, not 3 --
                ;    and the list is 12 B where ReadBlock's is 10. ---
                LDY     #$00
                LDA     #$04
                STA     [_blkTrampPtr],Y
                INY                             ; +1 unit
                LDA     _fsTmp1+1
                STA     [_blkTrampPtr],Y
                INY                             ; +2 buffer lo
                LDA    |_blkRaDstOff
                STA     [_blkTrampPtr],Y
                INY                             ; +3 buffer hi
                LDA    |_blkRaDstOff+1
                STA     [_blkTrampPtr],Y
                INY                             ; +4 buffer bank
                LDA    |_blkRaDstBank
                STA     [_blkTrampPtr],Y
                INY                             ; +5 buffer bank hi
                LDA     #$00
                STA     [_blkTrampPtr],Y
                INY                             ; +6 byte count lo
                LDA    |_blkRaCount
                STA     [_blkTrampPtr],Y
                INY                             ; +7 byte count hi
                LDA    |_blkRaCount+1
                STA     [_blkTrampPtr],Y
                INY                             ; +8 block lo
                LDA     _blkNum
                STA     [_blkTrampPtr],Y
                INY                             ; +9 block hi
                LDA     _blkNum+1
                STA     [_blkTrampPtr],Y
                INY                             ; +10 block bank
                LDA    |_blkCurHi               ; read-ahead is extended-only, so
                STA     [_blkTrampPtr],Y        ; the block field is a full
                INY                             ; +11 block bank hi
                LDA    |_blkCurHi+1
                STA     [_blkTrampPtr],Y        ; longword like $41's

                JSR     _blkFwCall
                MX      %11                     ; TRUTH: _blkSmartJump returns
                                                ; through SEP #$30 -- A and X/Y
                                                ; are both 8-bit here whatever
                                                ; the directive claims.
                STA    |_blkRaErr               ; errno NOW: the restores below
                                                ; load A, and reading it after
                                                ; them reports the last constant
                                                ; stored, not the firmware's code.

                ; Restore NOP NOP before branching (stores do not touch carry):
                ; the next STANDARD call executes +14/+15 on its way to the BCS.
                LDY     #BLK_EXTBANK_OFFSET
                LDA     #$EA
                STA     [_blkEntryPtr],Y
                INY
                STA     [_blkEntryPtr],Y

                ; paramCount back to $03 for the single-block callers, which
                ; write only +1.. and would otherwise inherit this $04.
                LDY     #$00
                LDA     #$03
                STA     [_blkTrampPtr],Y
                BCS     @sprbn_err

                PLP
                SEC
                RTS

                ; A $48 that errors means this bus does not implement the
                ; GENERIC Read, whatever $CnFB claimed about extended
                ; addressing.  Latch it off so we ask exactly once per boot
                ; instead of paying for a failed call on every miss.
                ; X IS NOT THE BUS OFFSET HERE.  It was one before _blkFwCall,
                ; and SmartPort firmware returns the transfer count in X/Y --
                ; nothing preserves it.  Recompute from _fsTmp1, which the
                ; firmware cannot reach: it runs at D=$0000 and the kernel DP is
                ; elsewhere.  Trusting X latched the flag into a byte up to 255
                ; past _busTable (i.e. into _diskStates) and left BS_FLAG_MB SET,
                ; so every later miss re-issued the failing $48 and scribbled
                ; again.  apple/fgx#111.
@sprbn_err      MX      %11                     ; both 8-bit: the firmware returned
                                                ; through SEP #$30 (see above)
                LDA     _fsTmp1                 ; bus idx
                ASL
                ASL
                ASL                             ; * 8 B per bus entry
                TAX
                LDA    |_busTable+BS_Flags,X
                AND     #$FF-BS_FLAG_MB
                STA    |_busTable+BS_Flags,X
                LDA     #EIO
                PLP
                CLC
                RTS

;==============================================================================
; _SP_Status - SmartPort disk-class status operation.
;
; Input:  _devPtr = device record.
;         _blkNum low byte = status code ($00=generic, $03=device info).
; Output: Result bytes at $00:BLK_STAGE; caller reads via LDAL.
;         C=1 ok, C=0 + A=EIO on error.
; Clobbers: A, X, Y, DBR.
;==============================================================================
_SP_Status      ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10

                ;--- Load device state ptr (same as _SP_ReadBlock) ---
                LDY     #DEV_StateLo
                LDA     [_devPtr],Y
                STA     _fsTmp0
                INY
                LDA     [_devPtr],Y
                STA     _fsTmp0+1

                LDY     #DSS_BusIdx
                LDA     (_fsTmp0),Y
                STA     _fsTmp1
                LDY     #DSS_LocalUnit
                LDA     (_fsTmp0),Y
                STA     _fsTmp1+1

                ;--- Patch BlkTramp's JSR target (+9/+10) with bus entry ---
                REP     #$20
                MX      %00
                LDA     _fsTmp1
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

                ;--- Patch command byte to SP_STATUS ---
                LDY     #BLK_CMD_OFFSET
                LDA     #SP_STATUS
                STA     [_blkEntryPtr],Y

                ;--- Params: unit, buffer=$00:BLK_STAGE, status_code (_blkNum lo) ---
                LDY     #$01
                LDA     _fsTmp1+1
                STA     [_blkTrampPtr],Y
                LDY     #$02
                LDA     #<BLK_STAGE
                STA     [_blkTrampPtr],Y
                INY
                LDA     #>BLK_STAGE
                STA     [_blkTrampPtr],Y
                INY                             ; Y=4
                LDA     _blkNum                 ; status code lo
                STA     [_blkTrampPtr],Y

                JSR     _blkFwCall              ; DP-protected (see _blkFwCall)
                BCS     @sps_err
                PLP
                SEC
                RTS

@sps_err        MX      %10
                LDA     #EIO
                PLP
                CLC
                RTS

;==============================================================================
; _SP_WriteBlock - SmartPort disk-class write operation.
;
; Mirror of _SP_ReadBlock but cmd=$02 and the MVN happens BEFORE the
; SmartPort call (caller's bank-$02 buffer → bank-$00 BLK_STAGE), since
; SmartPort WRITE reads source data from the staging buffer.
;
; Input:  _devPtr (DP long ptr) = device record.
;         _blkNum                = word block number.
;         _blkBuf                = word bank-$02 SOURCE buffer offset.
; Output: C=1 ok, C=0 + A=errno on error.
; Clobbers: A, X, Y, DBR.  Preserves caller M/X via PHP/PLP.
;==============================================================================
_SP_WriteBlock  ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00

                ;--- MVN 512 B from caller's buffer to $00:BLK_STAGE ---
                ; Relocation: patch MVN src-bank (was baked $02) to the live kernel
                ; bank from the bank-0 anchor (patch the executing copy via DBR=PB).
                ; P3.3-iii-B: _blkSrcPool=1 -> the source is a POOL entry, so the
                ; src bank is the F2 pool's heap bank instead of the kernel bank.
                PHK
                PLB                             ; DBR = executing copy's bank
                SEP     #$20
                MX      %10
                LDA    |_blkSrcPool             ; (DBR = live kernel bank)
                BEQ     @spwb_srcKern
                LDA    |_kBlkTabBase+2          ; pool source -> pool heap bank
                BRA     @spwb_srcSet
@spwb_srcKern   ; ...or the bank the caller named (UFS 1.3c).  Checked AFTER the
                ; pool arm: a pool source is the block layer's own doing and
                ; outranks a caller's buffer bank, which describes where the
                ; caller's buffer would have been had the pool not supplied it.
                LDA    |_blkCurBufBank
                BNE     @spwb_srcSet
                LDAL    KFGX_ANCHOR             ; A.lo = live kernel bank
@spwb_srcSet    STA     @spwb_mvn+2             ; patch src-bank (MVN encoding +2)
                REP     #$30
                MX      %00
                LDX     _blkBuf                 ; src offset in bank (kernel)
                LDY     #BLK_STAGE              ; dst offset in bank $00 ($1700)
                LDA     #511
@spwb_mvn       MVN     $02,$00
                ; MVN leaves DBR = $00 (dst bank).  Restore DBR = kernel bank.
                ; (block.s is segment #2 and PUTs no macros.s, so inline PHK/PLB
                ; rather than the _DBRK macro; K is always the live kernel bank.)
                PHK
                PLB
                REP     #$20
                MX      %00

                ;--- Load device state ptr ---
                SEP     #$20
                MX      %10
                LDY     #DEV_StateLo
                LDA     [_devPtr],Y
                STA     _fsTmp0
                INY
                LDA     [_devPtr],Y
                STA     _fsTmp0+1

                LDY     #DSS_BusIdx
                LDA     (_fsTmp0),Y
                STA     _fsTmp1
                LDY     #DSS_LocalUnit
                LDA     (_fsTmp0),Y
                STA     _fsTmp1+1

                ;--- Patch BlkTramp's JSR target with bus entry ---
                REP     #$20
                MX      %00
                LDA     _fsTmp1
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
                INY
                LDA    |_busTable+BS_EntryHi,X
                STA     [_blkEntryPtr],Y

                ;--- Patch SmartPort command to WRITE BLOCK ($02) ---
                LDY     #BLK_CMD_OFFSET
                LDA     #SP_WRITE_BLOCK
                STA     [_blkEntryPtr],Y

                ;--- Param list at [_blkTrampPtr]: unit, buf=BLK_STAGE, blk ---
                LDY     #$01
                LDA     _fsTmp1+1               ; local unit
                STA     [_blkTrampPtr],Y
                LDY     #$02
                LDA     #<BLK_STAGE
                STA     [_blkTrampPtr],Y
                INY
                LDA     #>BLK_STAGE
                STA     [_blkTrampPtr],Y
                INY                             ; Y=4
                LDA     _blkNum
                STA     [_blkTrampPtr],Y
                INY
                LDA     _blkNum+1
                STA     [_blkTrampPtr],Y
                INY
                ; Block byte 2.  The write path issues only STANDARD ($02)
                ; calls, so it carries three block bytes and stops at 2^24
                ; blocks; bits 24-31 must be zero.  See the read path.
                LDA    |_blkCurHi+1
                BEQ     @spwb_bhOK
                JMP     @spwb_err
@spwb_bhOK      LDA    |_blkCurHi
                STA     [_blkTrampPtr],Y

                ;--- Trampoline call (DP-protected; see _blkFwCall) ---
                JSR     _blkFwCall
                BCS     @spwb_err
                PLP
                SEC
                RTS
@spwb_err       MX      %10
                LDA     #EIO
                PLP
                CLC
                RTS

;==============================================================================
; Blk_Write - write one 512-byte block from caller's bank-$02 buffer.
;
; Thin shim that resolves _devPtr from _fsCurDevIdx, then calls
; _SP_WriteBlock.  Same calling pattern as Blk_Read.
;
; Input:  _fsCurDevIdx (byte)   = device index
;         _blkNum (word)        = block number
;         _blkBuf (word)        = bank-$02 SOURCE buffer offset
; Output: C=1 ok, C=0 + A=errno on error.
; Clobbers: A, X, Y, DBR; _libcTmp2 (RAM-class devices).
; PRESERVES _fsTmp0/_fsTmp1 (2026-07-18) — same contract as Blk_Read.
;==============================================================================
Blk_Write       ENT
                MX      %00
                PHP
                ; _fsTmp0/1 preservation (2026-07-18) — see Blk_Read @bkr_miss.
                ; Writes always hit the device, so save at entry.
                LDA     _fsTmp0
                PHA
                LDA     _fsTmp1
                PHA
                ;--- 32-bit key latch (UFS deliverable 1.0) -- see Blk_Read. ---
                LDA     _blkNumHi
                STA    |_blkCurHi
                STZ     _blkNumHi
                ;--- Buffer BANK latch (UFS 1.3c) -- see Blk_Read. ---
                LDA    |_blkBufBank
                STA    |_blkCurBufBank
                STZ    |_blkBufBank
                REP     #$30
                ;--- Compute _devPtr = dev_table_ptr + _fsCurDevIdx * DEV_SIZE ---
                SEP     #$20
                MX      %10
                LDA     _fsCurDevIdx
                REP     #$20
                MX      %00
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     dev_table_ptr
                STA     _devPtr
                SEP     #$20
                MX      %10
                LDA     dev_table_ptr+2
                ADC     #0
                STA     _devPtr+2
                ;--- Owned by vfs_bio?  See Blk_Read.  A bypassed device holds
                ; no pool entries, so there is nothing for WrInval to drop. ---
                LDY     #DEV_Flags
                LDA     [_devPtr],Y
                AND     #DEV_FLAG_VFSOWNED
                STA    |_blkNoCache
                ;--- Class dispatch: RAM devices use the in-kernel copy path
                ;    (no SmartPort).  DEV_Class is field offset 0; [_devPtr]
                ;    is DP-indirect-long so it reads the dev-table heap bank,
                ;    DBR-independent. ---
                LDY     #DEV_Class
                LDA     [_devPtr],Y             ; M=8: device class byte
                ;--- AN UNREGISTERED SLOT IS NOT A DEVICE, apple/fgx#220.
                ; _AllocDevTable zero-fills all FS_MAX_DEVICES slots so "empty
                ; slots read DEV_Class = 0" -- its words -- and DEV_CLASS_EMPTY
                ; is that zero, named in include/fs.s since the table existed.
                ; Nothing tested it here, so a request naming a slot nobody
                ; registered fell past the RAM arm into `_SP_WriteBlock' on a
                ; device whose bus, slot and unit are all zero.  SmartPort PIO
                ; SPINS (kc_sys.s says so where it explains why the block layer
                ; cannot sleep), so the machine did not fault -- it STOPPED.
                ;
                ; That is the /dev-absent boot hang: dev_mount scans units
                ; 0..DEV_MAXUNIT and stops at the first that answers, so with
                ; the volume attached the higher slots are never reached and
                ; with it missing the scan walks into them.  A real IIgs with
                ; one drive is that machine.
                CMP     #DEV_CLASS_EMPTY
                BEQ     @bkw_noDev
                CMP     #DEV_CLASS_RAM
                BEQ     @bkw_ram
                ;--- Dispatch ---
                REP     #$30
                MX      %00
                JSR     _SP_WriteBlock
                BCC     @bkw_err
                LDA    |_blkNoCache                ; vfs-owned: nothing cached,
                AND     #$00FF                     ;   nothing to invalidate
                BNE     @bkw_ok
                JSR     _BlkCache_WrInval          ; F3: invalidate-on-write (see blkcache.s)
                BRA     @bkw_ok
@bkw_ram        REP     #$30
                MX      %00
                JSR     _RAM_WriteBlock
                BCC     @bkw_err
                LDA    |_blkNoCache                ; vfs-owned: see above
                AND     #$00FF
                BNE     @bkw_ok
                JSR     _BlkCache_WrInval          ; F3: invalidate-on-write (see blkcache.s)
@bkw_ok         ; P3.3-iii-B: _blkSrcPool is per-call — consume it (AFTER the
                ; WrInval hook, which reads it to keep pool-source entries valid).
                SEP     #$20
                MX      %10
                LDA     #0
                STA    |_blkSrcPool
                REP     #$20
                MX      %00
                PLA
                STA     _fsTmp1
                PLA
                STA     _fsTmp0
                PLP
                SEC
                RTS
@bkw_noDev      MX      %10                     ; reached only from the
                                                ;   M=8 class read above
                LDA     #EIO                    ; M=8; @bkw_err widens it.  An
                                                ;   errno, not an ERR_ -- see
                                                ;   @bkr_noDev above.
                BRA     @bkw_err                ;   _BlkCache_WrFail below is a
                                                ;   no-op for a device that was
                                                ;   never written -- nothing is
                                                ;   pinned and no pool entry
                                                ;   names this slot -- so the
                                                ;   shared exit is taken whole
                                                ;   rather than half-copied.
@bkw_err        REP     #$30                    ; both BCC sources run MX %00;
                MX      %00                     ;   force it (tracker + machine)
                ; F2-b: failed write -> on-disk state indeterminate -> the
                ; cached copy must not survive (A = errno, preserved).  A
                ; pool-source entry goes STALE via InvalOne's BUSY arm — the
                ; pool copy holds INTENDED (not on-disk) content, so it must
                ; not outlive its pin.  Clear the per-call pool flag after.
                JSR     _BlkCache_WrFail
                TAY                             ; A (errno) survives via Y
                SEP     #$20
                MX      %10
                LDA     #0
                STA    |_blkSrcPool
                REP     #$20
                MX      %00
                TYA
                AND     #$00FF                  ; errno lo (callee loaded it M=8)
                TAY                             ; A survives the restore via Y
                PLA
                STA     _fsTmp1
                PLA
                STA     _fsTmp0
                TYA
                PLP
                CLC
                RTS

;==============================================================================
; Blk_DetectCaps - decide which read architecture each bus can use.
;
; Reads the SmartPort ID type byte at $CnFB for the bus's slot and sets
; BS_FLAG_EXT when bit 7 is on.  That bit means the firmware accepts EXTENDED
; ($4x) calls, whose buffer pointer is a LONGWORD: transfers land in any bank
; (no BLK_STAGE bounce, no 512-byte MVN) and the generic Read $48 is byte-count
; based, so one call can span up to 127 blocks.
;
; This is the gate Apple's own boot code uses -- GS.OS/Boot/ProBoot.src does
; `ldy #$FB / lda (devbuf),y / bpl not_sp` before it issues a $41.
;
; IT IS ONLY HALF THE QUESTION, and the half about the INTERFACE.  On a card the
; interface and the device are one box, so one byte answers both; on the IIgs's
; own DB19 port they are not, and a FloppyEmu behind Apple's extended-capable
; slot-5 firmware answered the first $41 with UNKNOWN CMD (apple/fgx#119).
;
; SO APPLE ASKS THE DEVICE TOO, via the DIB subtype byte's bit 7 (firmware_ref
; p.143), and so does FGX now, in _blk_bootDibExt below.  Both gates must pass.
;
; This was written, dropped, and put back, and the round trip is worth recording
; because the reasoning that dropped it was sound and still wrong.  The argument
; was: the subtype byte is the device's CLAIM, a failed $41 is its BEHAVIOUR, and
; the read depends on the behaviour -- so skip the claim and let the failure
; latch the bus down (which _SP_ReadBlock still does, and which is why a device
; that claims extended and then errors is still handled).
;
; What that argument misses is that OBSERVING the behaviour requires ISSUING the
; call, and issuing the call is the dangerous act.  Measured across two hardware
; rounds on 2026-08-15:
;
;   FujiNet    returns BADCMD  -> the latch fires, the machine boots
;   FloppyEmu  DOES NOT ANSWER -> no return, no error, no boot, black screen
;
; There is no error path for a call that never comes back.  The claim is the only
; thing that can be consulted without taking the risk, which is exactly why
; Apple consults it first.  A claim can be wrong -- the latch is still there for
; that -- but a claim that says "no" costs nothing to believe.
;
; MUST run after Blk_Init (which fills _busTable[0].BS_Slot).
;
; In:  nothing.   Out: _busTable[0].BS_Flags |= BS_FLAG_EXT when supported;
;      _blkDibSubtype = the boot device's DIB subtype byte, for the boot log.
; Clobbers: A, X, Y, DBR, _fsTmp0, BLK_STAGE.  Preserves caller M/X via PHP/PLP.
;==============================================================================
Blk_DetectCaps  ENT
                MX      %00
                PHP
                PHB
                PHK
                PLB                         ; DBR = live kernel bank: _busTable
                                            ; is read/written DBR-relative
                REP     #$30
                MX      %00

                ; $FF = "no device answered a DIB status".  Set here rather than
                ; left to the image's zero fill: an uninitialised $00 read as a
                ; device's answer once already, and a diagnostic whose did-not-run
                ; value is indistinguishable from a reading is not a measurement.
                SEP     #$20
                MX      %10
                LDA     #$FF
                STA    |_blkDibSubtype

                DO      CFG_KERNEL_SPEXT=0
                ; kernel.spext = 0: never issue an extended ($4x) call, whatever
                ; the interface and the device claim.  The last-resort switch for
                ; a machine where a $4x call hangs the bus and no gate below saw
                ; it coming -- FGX boots slower, and it boots.
                BRA     @bdc_done
                FIN

                ; X = slot*256 + $FB, i.e. the bank-0 offset of $CnFB.
                REP     #$20
                MX      %00
                LDA    |_busTable+BS_Slot   ; 1..7
                AND     #$00FF
                XBA                         ; slot<<8
                ORA     #$00FB
                TAX

                SEP     #$20
                MX      %10
                LDAL    $00C000,X           ; $CnFB, the SmartPort ID type byte
                AND     #$80                ; bit 7 = supports extended calls
                BEQ     @bdc_done           ; standard-only bus: leave flags alone

                JSR     _blk_bootDibExt     ; ...and does every device behind it
                BCC     @bdc_done           ; claim extended too?

                SEP     #$20
                MX      %10
                LDA    |_busTable+BS_Flags
                ORA     #BS_FLAG_EXT+BS_FLAG_MB ; MB is a GUESS, unlike EXT --
                STA    |_busTable+BS_Flags      ; cleared by the first $48 that
                                                ; fails (see _SP_ReadBlockN)

@bdc_done       PLB
                PLP
                RTS

;==============================================================================
; _blk_bootDibExt - does every DEVICE on the boot bus CLAIM extended calls?
;
; A STATUS call with statcode $03 returns the device information block, and the
; standard-call form of it is (firmware_ref p.142):
;
;   +0     device status byte
;   +1..3  block count (3 B standard; 4 B for an EXTENDED status call, which is
;          why this asks with a STANDARD one -- the offsets below only hold for
;          that form, and a standard STATUS is the one call every SmartPort
;          device must answer)
;   +4     ID string length
;   +5..20 ID string
;   +21    device type
;   +22    device subtype   <- bit 7 = supports extended SmartPort
;   +23,24 version
;
; Asked of every unit that answers, not just the boot unit: BS_FLAG_EXT is a
; property of the BUS, so one standard-only device on it has to veto the whole
; bus or _SP_ReadBlock would put a $41 to that device the first time anything
; read from it.  The scan ends at the first unit that does not answer STATUS,
; the same end-of-chain rule _dev_enumBus uses.
;
; A bus where NOTHING answered says no.  There is no evidence either way then,
; and the two outcomes are not symmetric: a wrong yes is an unbootable machine,
; a wrong no costs a few percent of read throughput.
;
; In:  DBR = live kernel bank (caller's).   MX %10.
; Out: C=1 every unit claims extended; C=0 otherwise.  MX %10.
;      _blkDibSubtype = the FIRST answering unit's subtype byte.
; Clobbers: A, X, Y, _fsTmp0, BLK_STAGE.  P is NOT restored -- carry is the
;      return value.
;==============================================================================
DIB_SUBTYPE_OFF EQU     22                  ; see the layout above
DIB_STATCODE    EQU     $03                 ; "return device information block"

_blk_bootDibExt MX      %10
                SEP     #$30
                MX      %11

                ; The trampoline's JSR target is whatever the last caller left;
                ; at boot that is the loader's, so point it at the boot bus.
                LDY     #9
                LDA    |_busTable+BS_EntryLo
                STA     [_blkEntryPtr],Y
                INY                             ; Y=10
                LDA    |_busTable+BS_EntryHi
                STA     [_blkEntryPtr],Y

                LDA     #$01
                STA     _fsTmp0                 ; unit under test
                STZ     _fsTmp0+1               ; units that answered

                ; The unit counter lives in DP because the firmware returns its
                ; transfer count in X and Y and preserves neither (apple/fgx#111);
                ; DP survives because _blkFwCall runs the firmware at D=$0000 and
                ; the kernel DP is elsewhere.
@bde_L          LDA     _fsTmp0
                CMP     #9                      ; units are 1..8
                BCS     @bde_end

                LDY     #BLK_CMD_OFFSET
                LDA     #SP_STATUS
                STA     [_blkEntryPtr],Y

                LDY     #$01                    ; +1 unit
                LDA     _fsTmp0
                STA     [_blkTrampPtr],Y
                INY                             ; +2 buffer lo
                LDA     #<BLK_STAGE
                STA     [_blkTrampPtr],Y
                INY                             ; +3 buffer hi
                LDA     #>BLK_STAGE
                STA     [_blkTrampPtr],Y
                INY                             ; +4 status code
                LDA     #DIB_STATCODE
                STA     [_blkTrampPtr],Y

                JSR     _blkFwCall
                MX      %11                     ; TRUTH: the firmware returns
                                                ; through SEP #$30
                BCS     @bde_end                ; no answer -> end of chain

                LDAL    BLK_STAGE+DIB_SUBTYPE_OFF
                LDY     _fsTmp0+1
                BNE     @bde_haveSub            ; keep the FIRST unit's byte: it
                STA    |_blkDibSubtype          ; is the boot device's
@bde_haveSub    AND     #$80
                BEQ     @bde_no                 ; this device is standard-only

                INC     _fsTmp0+1               ; answered, and claimed extended
                INC     _fsTmp0
                BRA     @bde_L

@bde_end        LDA     _fsTmp0+1
                BEQ     @bde_no                 ; nothing answered: no evidence
                REP     #$10
                MX      %10
                SEC
                RTS

@bde_no         REP     #$10
                MX      %10
                CLC
                RTS

;==============================================================================
; Blk_DibSubtype - read back the boot device's DIB subtype byte.
;
; Companion to Blk_CapsFlags, and there for the same reason: main.s cannot see
; block.s statics across the segment boundary.  $FF means no unit answered a DIB
; status -- or that the $CnFB gate refused before this ran, which is the same
; thing as far as the boot log is concerned: no device was ever consulted.
;
; Out: A.lo = subtype.  Caller at MX %10.
;==============================================================================
Blk_DibSubtype  ENT
                MX      %10
                PHB
                PHK
                PLB
                LDA    |_blkDibSubtype
                PLB
                RTS

;==============================================================================
; Blk_CapsFlags - read back _busTable[0].BS_Flags for the boot bus.
;
; Exists so main.s can log the capability line without needing _busTable's
; symbol across the segment boundary (block.s is link-file segment #2).
;
; Out: A.lo = BS_Flags.  Caller at MX %10.
;==============================================================================
Blk_CapsFlags   ENT
                MX      %10
                PHB
                PHK
                PLB
                LDA    |_busTable+BS_Flags
                PLB
                RTS

;------------------------------------------------------------------------------
; _blkSmartJump scratch (bank-$02 statics; accessed via STAL/LDAL so they are
; DBR-independent).  Not re-entrant — SmartPort I/O is synchronous and no IRQ
; path issues block I/O, so a single save slot suffices.
;------------------------------------------------------------------------------
_blkSavedS      DS      2               ; caller's (per-task) stack ptr across XCE
_blkRetA        DS      2               ; BlkTramp's A (errno) across the S restore

                PUT     blkcache.s      ; train-3 F2 block cache (same segment:
                                        ; its runtime callers are the Blk_* hooks)

;==============================================================================
; END block.s
;==============================================================================
