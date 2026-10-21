;==============================================================================
; fs.s - Filesystem equates: DP layout, buffers, struct stat, ProDOS.
;==============================================================================

;------------------------------------------------------------------------------
; Direct-page allocations (_blkNum, _blkBuf, _fsTmp0..2, _blkTrampPtr)
; now live in include/dpmap.s under a single authoritative DUM block.
; No more cross-module aliasing with console scratch.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Bank $02 fs buffers: addresses owned by include/memmap.s.  Sizes (for
; reference, enforced there):
;   _fsDirBuf       512 B     one ProDOS dir block
;   _fsDataBuf      512 B     one ProDOS data block
;   _fsIndexBuf     512 B     one ProDOS index block
;   _fsFileState    64 B      FST_* fields
;   _fsDirState     64 B      DST_* fields
;   _fsStatBuf      16 B      stat result
;   _fsCwd          80 B      current path
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; File state layout (_fsFileState) — computed via DUM/DEND so adding or
; reordering fields updates all offsets automatically.
;------------------------------------------------------------------------------
                DUM     0
FST_InUse       DS      1
FST_StorageType DS      1               ; high nibble ($10=seed, $20=sapl, $30=tree)
FST_EofLo       DS      1
FST_EofMid      DS      1
FST_EofHi       DS      1
FST_PosLo       DS      1
FST_PosMid      DS      1
FST_PosHi       DS      1
FST_CurBlkLo    DS      1
FST_CurBlkHi    DS      1
FST_KeyBlkLo    DS      1
FST_KeyBlkHi    DS      1
FST_DevIdx      DS      1               ; index into _devTable (0..FS_MAX_DEVICES-1)
; Tree-file ($30) block-resolution caches (Phase A).  Pure caches — never
; persisted per-FCB; _Fs_SwitchToFCB invalidates them to $FFFF so the
; resolver reloads from disk.  For tree, key_block == master block.
FST_CurMasterLo DS      1               ; master block currently in _fsMasterBuf
FST_CurMasterHi DS      1               ;   ($FFFF = invalid / not loaded)
FST_CurIdxLo    DS      1               ; sub-index block currently in _fsIndexBuf
FST_CurIdxHi    DS      1               ;   ($FFFF = invalid / not loaded)
FST_SIZE        EQU     *
                DEND
                ERR     FST_SIZE-1/$40  ; must fit in 64 B reserved in memmap.s

;------------------------------------------------------------------------------
; Directory state layout (_fsDirState) — same DUM/DEND pattern.
;------------------------------------------------------------------------------
                DUM     0
DST_InUse       DS      1
DST_CurBlkLo    DS      1
DST_CurBlkHi    DS      1
DST_EntryIdx    DS      1
DST_EntriesLeft DS      2               ; word
DST_DevIdx      DS      1               ; index into _devTable of dir's volume
DST_SIZE        EQU     *
                DEND
                ERR     DST_SIZE-1/$40  ; must fit in 64 B reserved in memmap.s

;------------------------------------------------------------------------------
; THE LEGACY 15-BYTE ST_ IMAGE IS GONE (2026-09-05).  It was ProDOS's directory
; entry with a Unix name on it: a MODE BYTE whose whole vocabulary was
; $80/$40/$20, a 3-byte size, a raw ProDOS bit-packed date and time, and no
; uid, gid, nlink, rdev or epoch anywhere.  libc unpacked that into the POSIX
; struct on every stat(2) -- including calendar arithmetic to turn ProDOS's
; packed date into a Unix epoch.
;
; The kernel writes the BSD struct itself now, so `_fsStatBuf' IS a struct
; stat and libc copies it.  The STX_ block further down is the layout, and
; tools/check_stat_layout.py holds it against toolchain/include/sys/stat.h.
;
; MODE_DIR / MODE_FILE / MODE_OTHER WENT WITH IT.  They were that mode byte's
; three values and nothing else used them as types; the FS layer speaks S_IF*
; now.  The PRODOS MODULE keeps its own copies (src/modules/prodos/prodos.s:163,
; which already said `matches include/fs.s' rather than including it) and is
; frozen until `mount -t prodos' -- at which point its stat fill has to produce
; this layout too, and its copies are where that starts.
;------------------------------------------------------------------------------


; FS_MAX_MOUNTS -- how many volumes may be mounted at once.
;
; THE COMMENT HERE SAID "ProDOS 8 DEVLST cap" AND THAT RATIONALE IS RETIRED.
; ProDOS's DEVLST does hold 14 entries -- 7 slots x 2 drives, Beneath Apple
; ProDOS p.8-6, $BF32-$BF3F -- but FGX never builds one, talks SmartPort
; directly, and an HFS partition is not assigned a slot/drive pair at all.  A
; limit justified by a mechanism this kernel does not have is a number nobody
; can reason about later.
;
; IT STAYS 14 AS A BUDGET, not as an inherited constant: a mount costs a
; `struct mount' (130 B) plus a ufsmount, and VFS_NMOUNT in fsparam.h is the
; same number for the same reason.  SP_UNIT_MAX is what governs how many
; DEVICES may be found (126, SmartPort's own), and FS_MAX_DEVICES bounds the
; device table at 32; this bounds only how many of them may be mounted.
FS_MAX_MOUNTS   EQU     14

;==============================================================================
; Bus record - one per discovered SmartPort controller.
; Allocated in _busTable[] in memmap.s.
;==============================================================================
                DUM     0
BS_Slot         DS      1                   ; 1..7
BS_EntryLo      DS      1
BS_EntryHi      DS      1
BS_EntryBank    DS      1                   ; 3-byte long ptr to $Cn00 + [$CnFF] + 3
BS_UnitCount    DS      1                   ; local units 1..N discovered
BS_Flags        DS      1                   ; bit 0 = boot bus
                                            ; bit 1 = BS_FLAG_EXT (below)
BS_SIZE         EQU     *                   ; 6 bytes
                DEND
                ERR     BS_SIZE-1/$08       ; must fit in 8 B per-entry reservation

FS_MAX_BUSES    EQU     8

; BS_Flags bits.
BS_FLAG_BOOT    EQU     $01                 ; this is the boot bus
BS_FLAG_MB      EQU     $04                 ; bus answers the GENERIC Read ($48),
                                            ; i.e. many blocks per call.
                                            ; MEASURED 2026-08-03 and NOT implied
                                            ; by BS_FLAG_EXT: the MicroDrive sets
                                            ; $CnFB bit 7 and serves extended
                                            ; ReadBlock ($41) perfectly, yet fails
                                            ; every $48 -- 1,488 failures in one
                                            ; boot.  $CnFB advertises the extended
                                            ; ADDRESSING, not the command set, so
                                            ; the only way to know is to try one
                                            ; and latch the answer.
BS_FLAG_EXT     EQU     $02                 ; bus honours EXTENDED SmartPort
                                            ; ($4x): longword buffer pointers,
                                            ; so transfers land in ANY bank and
                                            ; the generic Read ($48) can span
                                            ; many blocks per call.  Set from
                                            ; $CnFB bit 7 -- the SmartPort ID
                                            ; type byte -- which is the same
                                            ; gate Apple's own boot code uses
                                            ; (GS.OS/Boot/ProBoot.src:
                                            ; ldy #$FB / lda (devbuf),y / bpl).
                                            ; MEASURED: MicroDrive/Turbo $80,
                                            ; Apple II SCSI $82 and HS SCSI $82
                                            ; set it; A2retroNET, CFFA2, Focus,
                                            ; AppleIISD and Booti all read $00
                                            ; and do NOT.
                                            ; NEVER blind-issue a $4x call on a
                                            ; bus without this bit: on CFFA2 and
                                            ; A2retroNET the call does not even
                                            ; return.

;==============================================================================
; Device record - class-agnostic, 16 B.
; Allocated in _devTable[] in memmap.s.
; Note: prefix DEV_ used (not DE_) to avoid collision with ProDOS dir-entry
; offsets (DE_Name, DE_SIZE, etc.) declared earlier in this file.
;==============================================================================
                DUM     0
DEV_Class       DS      1                   ; 0=empty, 1=disk, 2=serial(future), 3=net(future), 4=ram
DEV_Flags       DS      1                   ; bit 0 = online
DEV_Name        DS      6                   ; "sNdM\0\0" null-terminated
DEV_OpsLo       DS      1
DEV_OpsHi       DS      1
DEV_OpsBank     DS      1                   ; long ptr to ops vtable
DEV_StateLo     DS      1
DEV_StateHi     DS      1
DEV_StateBank   DS      1                   ; long ptr to per-device state
DEV_Pad         DS      1
DEV_SIZE        EQU     *                   ; 16 bytes
                DEND
                ERR     DEV_SIZE-1/$10

FS_MAX_DEVICES  EQU     32

; THE BLOCK DRIVERS' SLICES OF THE DEVICE TABLE.  A block dev_t is a major and
; a minor (src/kernel/vfs/fsparam.h), and each driver's strategy in
; src/kernel/vfs/bio_strategy.c turns its own unit into a row here, by these
; same numbers -- the C copy is there, equal by hand.  SmartPort disks take
; rows from BDEV_SD_ROW0 in the order the scan finds them, at most BDEV_NSD,
; one per /dev/sd node; the RAM disk is BDEV_RAM_ROW, past them; and a
; SmartPort unit whose DIB says CD-ROM takes a cd row instead of an sd one,
; from BDEV_CD_ROW0, at most BDEV_NCD.  All below row 29 (flux-gs/fgx#4).
BDEV_SD_ROW0    EQU     0
BDEV_NSD        EQU     8
BDEV_RAM_ROW    EQU     8
BDEV_CD_ROW0    EQU     9
BDEV_NCD        EQU     4

; SP_UNIT_MAX -- the highest SmartPort unit number a slot may be asked about.
;
; SMARTPORT'S OWN CEILING, not ProDOS's.  Apple IIGS Firmware Reference p.122,
; the Status call's Unit number parameter: "1-byte value in the range $00, $01
; to $7E.  Each device has a unique number assigned to it at initialization
; time.  The numbers are assigned according to the device's position in the
; chain.  A Status call with a unit number of $00 specifies a call for the
; overall SmartPort status."  p.157 agrees from the bus side: "Although the
; software supports up to 127 bus residents, power requirements usually limit
; the maximum number of residents to 4."
;
; SO $7E, AND THE FOUR IS A POWER LIMIT ON THE PHYSICAL DAISY CHAIN rather than
; a protocol one -- irrelevant to a slot card presenting partitions of its own
; medium as units, which is how a MicroDrive or CFFA behaves and how FGX
; actually meets multiple volumes.
;
; THIS WAS 8, AND 8 WAS FGX's OWN NUMBER.  A 16-partition MicroDrive medium was
; measured presenting units past that and the scan simply stopped -- so
; partitions 9..16 existed, were addressable by the card, and were invisible.
; The cap was briefly believed to be ProDOS's DEVLST limit of 14 (7 slots x 2
; drives, Beneath Apple ProDOS p.8-6, DEVLST at $BF32-$BF3F).  It is not: FGX
; talks SmartPort directly and never builds a DEVLST, and an HFS partition is
; not assigned a slot/drive pair at all.
;
; THE SCAN IS NOT BOUNDED BY THIS IN PRACTICE.  _dev_enumBus exits on the first
; STATUS failure -- end of chain -- and is bounded by the port's own device
; count, so a card with three units costs three STATUS calls and a fourth
; that fails.  This constant
; only decides how far a card that KEEPS ANSWERING is followed.
SP_UNIT_MAX     EQU     $7E                 ; 126; $00 is the port itself

DEV_CLASS_EMPTY  EQU    0
DEV_CLASS_DISK   EQU    1
DEV_CLASS_SERIAL EQU    2
DEV_CLASS_NET    EQU    3
DEV_CLASS_RAM    EQU    4
DEV_CLASS_CD     EQU    5               ; read-only; offline when empty

DEV_FLAG_ONLINE  EQU    $01
; DEV_FLAG_VFSOWNED - this device is cached by vfs_bio, so the LEGACY block
; cache must not touch it (UFS 1.3c).
;
; The rule it enforces is vfs_bio.c's: a device is cached by exactly one stack,
; never both.  That was prose, and prose cannot be checked.  Without it the
; rule is broken the moment bio_strategy calls Blk_Read, because the legacy
; cache is not BESIDE the block layer, it is INSIDE it -- Blk_Read consults
; _BlkCache_Fetch on entry and fills on every miss.  Every UFS block would then
; sit in two caches at once.
;
; Nothing diverges TODAY, only because Blk_Write drops the entry it wrote, so
; the legacy cache never holds post-write stale bytes.  That is three
; unenforced links deep, and the last of them -- "no other reader of this
; device" -- is exactly what a second filesystem on the same spindle removes.
;
; The costs do not wait for divergence.  The legacy pool is scan-bound rather
; than capacity-bound, so UFS traffic evicts the ProDOS root's working set;
; every transfer pays a second 512-byte copy through the pool; and
; bio_strategy's block pairs are always consecutive, which trips _blkRaSeq and
; drives read-ahead over metadata -- the case the comment there warns against.
;
; PER DEVICE rather than per request, because that is what the rule says, and
; because it makes the rule testable: a vfs_bio-owned device must hold zero
; entries in the legacy pool, which a probe can assert.
DEV_FLAG_VFSOWNED EQU   $02

;==============================================================================
; Disk-state struct (pointed to by DEV_State for class=disk devices).
;==============================================================================
; THE BLOCK COUNT IS FOUR BYTES, AND IT USED TO BE TWO.  SmartPort's STATUS
; call ($03, the device information block) returns it least significant byte
; first and the Firmware Reference says how wide: "If the device is a block
; device, the next field indicates the number of blocks in the device.  This is
; a 3-byte field for standard calls or a 4-byte field for extended calls"
; (Apple IIgs Firmware Reference p.123).  Blk_Status issues the STANDARD call,
; so three bytes arrive and the fourth is zeroed; the room is here so the
; extended call needs no layout change.
;
; TWO BYTES MADE A LARGE VOLUME READ AS EMPTY rather than as too big, because
; the dropped byte is the HIGH one: a 131,072-sector spindle is $020000, whose
; low sixteen bits are zero, so it attached as `0 blocks (0KB)'.  Nothing
; noticed because the block path range-checks nothing -- Blk_Read issues
; whatever block number it is given -- so only the raw device, which does check
; (rawdisk.s _Rsd_Rw, against Reno's `sizes[part].nblocks'), could not read it.
; 32 MB is ProDOS's own limit at 65,535 blocks and never SmartPort's, which
; reaches 8 GB on the standard call.  apple/fgx#407.
;
; DSS_SIZE IS 8 AND NOT 6 so the per-unit index stays `ASL ASL ASL': the
; callers compute idx*DSS_SIZE with shifts, and six would cost a multiply for
; two bytes a side.
                DUM     0
DSS_BusIdx      DS      1                   ; 0..FS_MAX_BUSES-1
DSS_LocalUnit   DS      1                   ; SmartPort unit on that bus, 1..N
DSS_BlkCount    DS      4                   ; from Blk_Status, LSB first
                DS      2                   ; pad: keep the index a shift
DSS_SIZE        EQU     *                   ; 8 bytes
                DEND
                ERR     DSS_SIZE-1/$08

;==============================================================================
; Disk ops vtable layout.
;==============================================================================
                DUM     0
DOP_ReadBlock   DS      3                   ; long ptr
DOP_WriteBlock  DS      3                   ; long ptr
DOP_Status      DS      3                   ; long ptr
DOP_SIZE        EQU     *                   ; 9
                DEND

;------------------------------------------------------------------------------
; SmartPort command bytes (for Blk_Read / Blk_Status).
;------------------------------------------------------------------------------
SP_STATUS       EQU     $00             ; SmartPort STATUS
SP_READ_BLOCK   EQU     $01             ; SmartPort READ BLOCK
SP_WRITE_BLOCK  EQU     $02             ; SmartPort WRITE BLOCK
SP_READ         EQU     $08             ; SmartPort generic READ -- byte
                                        ; count, so MANY blocks per call.
                                        ; Only ever issued EXTENDED ($48):
                                        ; the 2026-07-21 attempt at plain
                                        ; $08 read as 'the card rejects
                                        ; multi-block' when the request was
                                        ; simply malformed.

;------------------------------------------------------------------------------
; SmartPort STATUS status-code values (param+4).
;------------------------------------------------------------------------------
SP_STAT_DEVICE  EQU     $00             ; device status (count if unit=0)
SP_STAT_DIB     EQU     $03             ; device information block
; The STANDARD call's DIB (Apple IIGS Firmware Reference p.123): +0 the
; general status byte, +1..3 the block count, +4 the ID string's length,
; +5..20 the string, +21 the device type, +22 the subtype, +23..24 the version.
; Code $00's reply is the DIB's first four bytes, so +0..3 read the same
; whichever call filled the stage.
DIB_Type        EQU     21
SP_GS_ONLINE    EQU     $10             ; status byte: "Device online or disk
                                        ;   in drive" (p.122)
SP_DEVTYPE_CDROM EQU    $05             ; "SCSI CD-ROM", SmartPort Technical
                                        ;   Note #4

;------------------------------------------------------------------------------
; SmartPort staging buffer: firmware-mandated bank-$00 address where READ
; BLOCK / STATUS write their result bytes.  After the call, Blk_Read
; MVNs the 512-byte payload from here into the caller's bank-$02 _blkBuf;
; Blk_Status leaves the status bytes here for the caller to LDAL directly.
;------------------------------------------------------------------------------
BLK_STAGE       EQU     CFG_BLK_STAGE   ; fixed (BLK_STAGE_FIXED in
                                        ; tools/ninja/genconfig.py); the user
                                        ; stack arena starts above it.
                                        ; MOVED $2000 -> $1700 2026-08-06 (bank-0
                                        ; compaction).  Only the BANK is mandated;
                                        ; the address is FGX's to choose, and at
                                        ; $2000 it was the last thing standing
                                        ; between the kernel stacks and the arena.
                                        ; $1700-$18FF, immediately above
                                        ; FGX_STK_KTASKS and below FGX_STK_ARENA.

;------------------------------------------------------------------------------
; ProDOS storage type nibble values (high nibble of entry byte 0).
;------------------------------------------------------------------------------
PRO_DELETED     EQU     $0
PRO_SEEDLING    EQU     $1
PRO_SAPLING     EQU     $2
PRO_TREE        EQU     $3
PRO_EXTENDED    EQU     $5
PRO_DIR         EQU     $D
PRO_DIR_HDR     EQU     $E
PRO_VOL_HDR     EQU     $F

;------------------------------------------------------------------------------
; ProDOS directory entry offsets (39 bytes per entry).
;------------------------------------------------------------------------------
DE_StorageName  EQU     $00             ; storage_type(hi) | name_len(lo)
DE_Name         EQU     $01             ; 15 bytes
DE_FileType     EQU     $10
DE_KeyPointer   EQU     $11             ; 2 bytes
DE_BlocksUsed   EQU     $13             ; 2 bytes
DE_EofLo        EQU     $15
DE_EofMid       EQU     $16
DE_EofHi        EQU     $17
DE_CreateDate   EQU     $18             ; 4 bytes
DE_Version      EQU     $1C
DE_MinVersion   EQU     $1D
DE_Access       EQU     $1E
DE_AuxType      EQU     $1F             ; 2 bytes
DE_ModDate      EQU     $21             ; 4 bytes
DE_HeaderPtr    EQU     $25             ; 2 bytes
DE_SIZE         EQU     39              ; $27

DE_PerBlock     EQU     13

;------------------------------------------------------------------------------
; Directory block header (first 4 bytes of every directory block).
;------------------------------------------------------------------------------
DBH_PrevBlock   EQU     $00             ; 2 bytes
DBH_NextBlock   EQU     $02             ; 2 bytes

;------------------------------------------------------------------------------
; Volume directory header fields.
;------------------------------------------------------------------------------
VH_StorageName  EQU     $00
VH_Name         EQU     $01             ; 15 bytes
VH_Reserved     EQU     $10             ; 8 bytes
VH_CreateDate   EQU     $18             ; 4 bytes
VH_Version      EQU     $1C
VH_MinVersion   EQU     $1D
VH_Access       EQU     $1E
VH_EntryLen     EQU     $1F             ; 39
VH_EntriesPerBlk EQU    $20             ; 13
VH_FileCount    EQU     $21             ; 2 bytes
VH_BitmapPtr    EQU     $23             ; 2 bytes
VH_TotalBlocks  EQU     $25             ; 2 bytes

;------------------------------------------------------------------------------
; Limits.
;------------------------------------------------------------------------------
; No FS_PATH_MAX here.  The path limit is MAXPATHLEN, and the two places that
; hold it are SYS_PATHBUF_MAX/SYS_PATH_MAX (syscall.s, the core-bank staging
; buffers) and FS_FARPATH_MAX (memmap.s, the far bank's).  A third constant
; lived here at 64 and was referenced by nothing, which is how it stayed 64
; through every widening -- and reading it as the system's answer is how the
; core-bank buffer came to be the narrowest point (apple/fgx#436).
FS_NAME_MAX     EQU     15
FS_DEPTH_MAX    EQU     16

;==============================================================================
; New (T1, fs-write-tree): int-fd model + POSIX-shaped surface
;==============================================================================

;------------------------------------------------------------------------------
; fd table
;------------------------------------------------------------------------------
FS_MAX_FDS       EQU     30             ; = 2.11BSD NOFILE (param.h: max open files
                                        ; per process).  The Bourne sh moves
                                        ; std{in,out} to INIO=10 / OTIO=11 (defs.h)
                                        ; so redirections never clobber them -- the
                                        ; fd table must reach those, or dup2(x,11)
                                        ; EBADFs and every write(output=11,..) (the
                                        ; prompt) is lost.  Table is Kmalloc'd
                                        ; FS_MAX_FDS*3 (=90 B) per task.
FS_FIRST_USER_FD EQU     3              ; 0/1/2 reserved for std{in,out,err}

;------------------------------------------------------------------------------
; FCB layout (per-fd state, heap-allocated, M_FS).  FCB_SIZE bytes (38).
; Each fd_table[i] is a 3-byte long pointer to one of these (or zero=closed).
;------------------------------------------------------------------------------
                DUM     0
FCB_Flags       DS      1               ; bit0=write, bit1=dirty-data,
                                        ; bit2=dir
FCB_StorageType DS      1               ; ProDOS storage type nibble (1/2/3/D);
                                        ; legacy field - ProDOS FST uses it,
                                        ; other FSTs leave 0
FCB_DevIdx      DS      1               ; DEVICE-TABLE index (0-based into
                                        ; _devTable; the value _fsCurDevIdx
                                        ; takes for this fd's block I/O).  NOT a
                                        ; mount-slot index — it flows path-walk
                                        ; -> _fsCurDevIdx -> _fsFS/DS_DevIdx ->
                                        ; here and back (save/load state).
FCB_FstIdx      DS      1               ; index into _FstTable (FST_IDX_*) -
                                        ; selects the FST that owns this FCB
FCB_DirBlock    DS      2               ; dir block holding our entry (common)
FCB_DirEntryIdx DS      1               ; 0..12 entry slot in dir block (common)
FCB_Eof         DS      3               ; 24-bit EOF (common)
FCB_Pos         DS      3               ; 24-bit current pos (common)
FCB_FstPriv     DS      19              ; FST-private overlay region. Each FST
                                        ; defines its own structure on these
                                        ; 19 bytes (see ProDOS overlay below).
FCB_RefCount    DS      1               ; open-file-description refcount (BSD
                                        ; struct file f_count): # of fd-table
                                        ; slots referencing this FCB.  Set 1 at
                                        ; _Fcb_Alloc; +1 per spawn-inherit
                                        ; (_Fcb_InheritRefs); _Fcb_Free
                                        ; decrements and Kfrees only at 0.  A
                                        ; COMMON field (not in FstPriv); console
                                        ; FCBs ignore it (never freed).  1 byte
                                        ; (max 255 refs) is ample for NPROC tasks.
                                        ; _Fcb_Alloc sets NONE ($FF, NOT 0 — 0 is
                                        ; a valid slot); Fs_Open/Fs_Create attach
                                        ; via _Fs_InodeAttach (regular files
                                        ; only); _Fcb_Free iputs once per FCB
                                        ; lifetime.  Consumers treat NONE as
                                        ; "fall back to the dir-entry path".
FCB_ErrLatch    DS      1               ; deferred write-error latch (train-3
                                        ; F4): errno from a FAILED best-effort
                                        ; switch-away flush (previously
                                        ; swallowed silently).  0 = clean
                                        ; (zero-fill at _Fcb_Alloc).  Reported
                                        ; ONCE at the next write/fsync/close of
                                        ; this fd, then cleared.
                                        ; (bit values: WD_DATA/WD_IDX/WD_MASTER
                                        ;  EQUs below the DUM.)
FCB_WDirty      DS      1               ; P3.3-iii-B pool-block dirty bits:
                                        ; bit0 = data-frontier pin dirty,
                                        ; bit1 = (sub-)index pin dirty,
                                        ; bit2 = master pin dirty.  A set bit
                                        ; means the PINNED pool copy has bytes
                                        ; not yet Blk_Written.  COMMON (only
                                        ; the ProDOS FST uses it today).
FCB_WBlkIdx     DS      2               ; P3.3-iii-B: 16-bit logical data-block
                                        ; index (Pos>>9) of the pinned write
                                        ; frontier; $FFFF = none resident.
                                        ; (Replaces the _fwDataBlkIdx single-
                                        ; ton.)  Open/Create set $FFFF — pins
                                        ; are LAZY, taken on first write.
FCB_SIZE        EQU     *               ; 38 bytes (common 13 + FstPriv 19 + ref 1
                                        ;           + inode 1 + errlatch 1
                                        ;           + wdirty 1 + wblkidx 2)
                DEND
                ERR     FCB_SIZE-1/$28   ; soft cap 40 (room for FstPriv growth)

; FCB_WDirty bit values (P3.3-iii-B).
WD_DATA         EQU     $01             ; data-frontier pool copy dirty
WD_IDX          EQU     $02             ; (sub-)index pool copy dirty
WD_MASTER       EQU     $04             ; master pool copy dirty

; train-3 F0.5 write-state completeness self-test (boot-time, prints
; FSPROBE: PASS/FAIL).  Set 0 to remove from production builds.  See
; _Fs_Probe in src/drivers/fs/fs.s and the call after Fs_Init in main.s.
FSPROBE         EQU     1


;------------------------------------------------------------------------------
; Block cache (train-3 F2) — transparent (dev,blk) -> 512 B copy cache UNDER
; Blk_Read/Blk_Write (src/drivers/block/blkcache.s).  INVARIANT (current, post
; 2026-07-18): a VALID entry holds the bytes last READ from disk for (dev, blk);
; a successful write DROPS the entry rather than refreshing it, a failed write
; drops it too, and unmount/mount/rescan invalidate all.  Shares the block
; table's heap allocation at +BLKCACHE_OFF (KGlobals is at its $02FE00 ceiling,
; so there is no room for a second base static).  The key is (dev, 32-bit
; block) as of UFS deliverable 1.0.
;------------------------------------------------------------------------------
BLKPROBE        EQU     1               ; boot self-test (dmesg BLKPROBE: PASS/FAIL)
LATPROBE        EQU     0               ; preemption-P0 syscall-latency survey
                                        ; (dispatcher entry/exit taps; worst
                                        ; CPU-bound syscall in ticks + its
                                        ; number, kbank-dump readable).
                                        ; Survey done — stripped (P1 review
                                        ; finding: release blocker while 1).
BLKCACHE_NBUF   EQU     24              ; 16 streaming window + 8 LRU.  P3.3
                                        ; had raised this 16->32; measurement
                                        ; took 8 back, because the cache is
                                        ; SCAN-bound and those slots cost more
                                        ; than they returned: ~3 frames per LRU
                                        ; slot on the tcsh workload, while the
                                        ; FS's request count did not move at all
                                        ; across an 8x range of pool sizes --
                                        ; a streaming read's misses are
                                        ; compulsory, so capacity bought
                                        ; nothing.  NBUF need not be a power of
                                        ; two; only the window must be (the run
                                        ; map is a mask).
                                        ;
                                        ; The floor here is CORRECTNESS, not
                                        ; speed: AllocLRU may only evict the LRU
                                        ; half, and FS_MAX_FDS (30) write pins
                                        ; could in principle occupy all of it.
                                        ; Since #15 that is a refusal rather than
                                        ; a wild claim, so a too-small half
                                        ; degrades (uncached reads, EIO on a pin)
                                        ; instead of corrupting -- but it still
                                        ; degrades.  Do not shrink it further
                                        ; without bounding the live pin count.
                                        ;
                                        ; GROWING it is a measured regression, so
                                        ; the number above is a ceiling as well
                                        ; as a floor.  Same workload, frames for
                                        ; a2scsi (batches $48) and retronet
                                        ; (never does):
                                        ;
                                        ;  NBUF win LRU  K | a2scsi retronet
                                        ;   24  16   8  16 |   468     588  <- us
                                        ;   32  16  16  16 |   480     612
                                        ;   32   8  24   8 |   516     636
                                        ;   32   4  28   4 |    --     648
                                        ;   64  32  32  32 |   492     672
                                        ;   64  16  48  16 |   516     732
                                        ;
                                        ; retronet is the clean signal: monotonic
                                        ; in LRU size and it never issues a $48,
                                        ; so every slot added costs it time and
                                        ; buys it nothing.  a2scsi at NBUF=64/
                                        ; K=32 drove its request count DOWN to
                                        ; 206 (vs 300 here) and was still slower
                                        ; -- fewer device calls, more wall time,
                                        ; which is only possible if the cost is
                                        ; not in the calls.  It is in the scans,
                                        ; and the next real lever is an INDEXED
                                        ; lookup, not more slots.
                                        ;
                                        ; The pool also backs pinned FS buffers.
                DUM     0
BCH_Flags       DS      1               ; bit0 = VALID.  Offset 0: the scan
                                        ; reads one byte at the slot base.
BCH_Dev         DS      1               ; device index
BCH_BlkLo       DS      1               ; block number LOW word; 16-bit read here
BCH_BlkLoHi     DS      1
BCH_BlkHi       DS      1               ; block number HIGH word; 16-bit read here
BCH_BlkHiHi     DS      1
BCH_LruLo       DS      1               ; _kSystemTicks low word at last touch
BCH_LruHi       DS      1
BCH_PinCount    DS      1               ; P3.3: pin refcount (two fds may pin
                                        ;   the same block); BUSY mirrors >0
BCH_Pad         DS      7
BCH_SIZE        EQU     *               ; 16 bytes/header
                DEND
; The header went 8 -> 16 bytes for the 32-bit key (UFS deliverable 1.0).  The
; two spare bytes in the old layout could not hold a second block word, and
; every alternative was a trick: packing the device index into the flag byte's
; high nibble, or narrowing the LRU stamp to one byte (which wraps every ~4 s
; and would silently degrade eviction).  A power-of-two stride keeps the index
; math a shift -- idx*16 is four ASLs, as idx*8 was three -- and keeps the low
; bits of a header offset clear, which is what lets AllocLRU reach BCH_LruLo
; with ORA rather than an add.  Cost is 192 bytes of the Kmalloc'd block, and
; the SCAN cost is unchanged: still BLKCACHE_NBUF iterations, just a wider
; stride, which matters because this cache is scan-bound and not capacity-bound.
BCH_FL_VALID    EQU     $01
BCH_FL_BUSY     EQU     $02             ; P3.3: pinned — a live pointer into
                                        ;   this buffer exists; AllocLRU must
                                        ;   not evict it
BCH_FL_STALE    EQU     $04             ; P3.3: invalidated while pinned —
                                        ;   drop (clear VALID) at unpin
BLKCACHE_HDRBYTES EQU   BLKCACHE_NBUF*BCH_SIZE   ; 384 (24 slots x 16 B)

; READ-AHEAD (extended buses only).  A miss on an extended bus reads a whole
; ALIGNED RUN of BLKCACHE_RA_K consecutive DISK blocks in ONE $48 call, straight
; into BLKCACHE_RA_K adjacent pool buffers -- adjacent slots are adjacent memory
; (BUFOFF + idx*512), which is what makes one transfer possible.
;
; WHY: measured 2026-08-03, the cost of a read is per-CALL, not per-byte.
; Removing the 512 B staging MVN ($41) bought 2.4%; the same workload swings 35%
; between cards on identical code.  So the lever is call count, and this divides
; it by BLKCACHE_RA_K.
;
; The run is DIRECT-MAPPED from the block number -- run = (blk / K) mod NRUNS --
; so there is no cursor to keep, the transfer is naturally aligned, and
; sequential streaming walks the runs in order.  Correctness does NOT depend on
; file layout: these are consecutive DISK blocks cached under their own block
; numbers, so a fragmented file just wastes the read-ahead rather than
; corrupting anything.
;
; K must DIVIDE BLKCACHE_NBUF (the runs tile the pool exactly).
BLKCACHE_RA_K   EQU     16              ; blocks per read-ahead call (8 KB).
                                        ; SWEPT 2026-08-04 on a2scsi, the only
                                        ; bus here that answers $48 -- frames for
                                        ; the tcsh workload, and the FS's own
                                        ; request count:
                                        ;   K=4   600 frames, 824 requests
                                        ;   K=8   516 frames, 473 requests
                                        ;   K=16  480 frames, 296 requests
                                        ; Monotonic, and the spread is 10x the
                                        ; ~12-frame cross-binary noise, which is
                                        ; the per-CALL cost showing up exactly
                                        ; where the $41-vs-$48 result said it
                                        ; would.  The ceiling here is OURS, not
                                        ; the card's: K may not exceed
                                        ; BLKCACHE_RA_SLOTS, while the firmware
                                        ; would take 127 blocks in one call.
                                        ; Going past 16 means growing the window,
                                        ; which comes out of the LRU half that
                                        ; keeps metadata cached -- and starving
                                        ; that is what made read-ahead 75% SLOWER
                                        ; the first time.  Measure that trade, do
                                        ; not assume it.
; Read-ahead gets its OWN slots and may not touch the rest.  MEASURED
; 2026-08-03: letting it map over the whole 32-slot pool turned a win into a
; 75% LOSS (480 -> 840 frames) and more than DOUBLED the request count
; (1,534 -> 3,451) -- streaming a 1,100-block file cycled every run and evicted
; the index and directory blocks that the FS re-reads for the very next data
; block.  The batching was never the problem; owning the whole cache was.
; So: the top BLKCACHE_RA_SLOTS are the streaming window, the bottom
; BLKCACHE_LRU_NBUF stay a plain LRU cache for metadata, and AllocLRU is
; confined to the latter.  Lookup still scans all of them -- a read-ahead entry
; must be findable, it just must not be evictable by ordinary traffic.
BLKCACHE_RA_ON  EQU     1               ; 0 = split the pool exactly as
                                        ; below but never issue a $48, so a
                                        ; measurement can separate the
                                        ; BATCHING from the smaller LRU scan
                                        ; the split brings with it.  Both
                                        ; moved the number; only a matched
                                        ; control tells you which did what.
BLKCACHE_RA_SLOTS EQU   16
BLKCACHE_LRU_NBUF EQU   BLKCACHE_NBUF-BLKCACHE_RA_SLOTS
BLKCACHE_RA_MASK EQU    BLKCACHE_RA_SLOTS-1
BLKCACHE_RA_RUNS EQU    BLKCACHE_RA_SLOTS/BLKCACHE_RA_K
BLKCACHE_RA_TILE EQU    BLKCACHE_RA_RUNS*BLKCACHE_RA_K
                ERR     BLKCACHE_RA_SLOTS-BLKCACHE_RA_TILE ; K must DIVIDE the
                                        ; read-ahead window:
                                        ; the runs have to tile the pool exactly
                                        ; or the direct map aliases two runs onto
                                        ; the same slots.  (Merlin32 cannot
                                        ; evaluate a parenthesised ERR, hence the
                                        ; named intermediate.)
BLKCACHE_RA_BYTES EQU   BLKCACHE_RA_K*512
BLKCACHE_RA_KM1 EQU     BLKCACHE_RA_K-1
BLKCACHE_NBUF_M1 EQU    BLKCACHE_NBUF-1
BLKCACHE_RA_ALIGN EQU   $FFFF-BLKCACHE_RA_KM1   ; blk & this = run base
                                        ; (Merlin32 has no operator
                                        ; precedence and no parens in an
                                        ; operand, so every compound
                                        ; constant gets a name.)
BLKTAB_ROWS     EQU     64              ; arena block-table rows: the boot
                                        ; claim, kernel-arena growth, dedicated
                                        ; big blocks and the user-grant banks
                                        ; Bank_Alloc claims once the bitmap
                                        ; pool is dry -- one row a bank, so
                                        ; enough for NPROC processes of two
                                        ; banks past the pool.  The walkers
                                        ; index with a 16-bit Y (8 x row) and
                                        ; _kBlkCount is a byte: at most 255.
BLKCACHE_OFF    EQU     BLKTAB_ROWS*8   ; heap-base offset: past the block table
; Cursor-relative region map (cursor = heap base + BLKCACHE_OFF after
; BLKCACHE_USE): headers 0..383, cache-private scratch 384..391, buffers
; 392..12679.  The scratch cells exist because Blk_* callers concede only
; A/X/Y/_libcTmp2 (the _fsTmp survival contracts are contradictory across
; callers — see blkcache.s header), so AllocLRU's scan state lives here.
BCS_BestLru     EQU     BLKCACHE_HDRBYTES+0      ; 2 B — min-LRU scan best value
BCS_BestIdx     EQU     BLKCACHE_HDRBYTES+2      ; 2 B — min-LRU scan best slot
BCS_HitCount    EQU     BLKCACHE_HDRBYTES+4      ; 4 B — read hits served from
                                                 ;   the pool (probe/kstat metric;
                                                 ;   disk reads = _kBlkReadCount
                                                 ;   minus this)
BLKCACHE_BUFOFF EQU     BLKCACHE_HDRBYTES+8      ; 392: buffer 0
BLKCACHE_TOTAL  EQU     BLKCACHE_BUFOFF+BLKCACHE_NBUF*512  ; 12680

;------------------------------------------------------------------------------
; ProDOS FST overlay of FCB_FstPriv. Existing field names preserved via
; EQU so all ProDOS code keeps working without changes. Other FSTs
; (FAT32 in Phase 2) define their own overlay of the same 19 bytes.
;
; Resulting in-FCB byte offsets (post-Task-3 reorder):
;   FCB_Flags         = 0
;   FCB_StorageType   = 1
;   FCB_DevIdx        = 2
;   FCB_FstIdx        = 3
;   FCB_DirBlock      = 4..5
;   FCB_DirEntryIdx   = 6
;   FCB_Eof           = 7..9
;   FCB_Pos           = 10..12
;   FCB_FstPriv       = 13..31
;     FCB_KeyPtr          = 13..14   (FstPriv+0)
;     FCB_DataBlk         = 15..16   (FstPriv+2)
;     FCB_DataBuf         = 17..19   (FstPriv+4)
;     FCB_IdxBlk          = 20..21   (FstPriv+7)
;     FCB_IdxBuf          = 22..24   (FstPriv+9)
;     FCB_MasterBuf       = 25..27   (FstPriv+12)
;     FCB_BlocksUsed      = 28..29   (FstPriv+15)
;     FCB_FwDirEntryOff   = 30..31   (FstPriv+17)
;   FCB_RefCount      = 32           (common; appended after FstPriv)
;
; Pre-Task-3 layout had FCB_KeyPtr at offset 6 (between Flags/StorageType/
; DevIdx/DirBlock/DirEntryIdx and Eof/Pos). The reorder is invisible to
; existing code because every access goes through these EQU names.
;------------------------------------------------------------------------------
FCB_KeyPtr          EQU FCB_FstPriv+0    ; data blk (seed) | idx blk (sap) | master (tree)
FCB_DataBlk         EQU FCB_FstPriv+2    ; cached data-blk number (0=none)
FCB_DataBuf         EQU FCB_FstPriv+4    ; long ptr to 512 B data buffer
FCB_IdxBlk          EQU FCB_FstPriv+7    ; cached (sub-)index block number
FCB_IdxBuf          EQU FCB_FstPriv+9    ; long ptr to 512 B index buffer
FCB_MasterBuf       EQU FCB_FstPriv+12   ; long ptr to 512 B master buffer (tree)
FCB_BlocksUsed      EQU FCB_FstPriv+15   ; ProDOS blocks_used field
FCB_FwDirEntryOff   EQU FCB_FstPriv+17   ; saved _fwDirEntryOff per-FCB

; P3.3-iii-B: the three Buf fields become PIN RECORDS into the F2 pool:
;   +0/+1 = 16-bit in-bank buffer offset (0 = no pin held)
;   +2    = pool slot index (for _BlkCache_Unpin)
; The pool BANK is global (byte 2 of _kBlkTabBase) — not stored per record.
                                         ; (write-path: byte offset of this
                                         ; file's dir entry within its dir
                                         ; block; full 16 bits because slot
                                         ; <= 12 * 39 + 4 = 472)

; Dir-fd overlay of FCB_FstPriv (P3.2d — dir FCBs don't use the ProDOS file
; overlay; enumeration state lives here + the common fields: FCB_DataBlk =
; current dir block, FCB_DirEntryIdx = slot 0..12, FCB_DevIdx = volume).
FCB_DirEntsLeft EQU     FCB_FstPriv+0   ; synthetic-/MNT/ one-shot counter (2 B)

; Socket-fd overlay of FCB_FstPriv (mutually exclusive with the ProDOS overlay —
; a socket fd is never a file).  Holds the socket-descriptor BYTE OFFSET
; (0/8/16/24) into the kernel socket table (src/kernel/socket.s), like a chardev
; fd stores its chardev idx at FstPriv[0].
FCB_SockIdx     EQU FCB_FstPriv+0

; Pipe-fd overlay of FCB_FstPriv (mutually exclusive with the ProDOS/socket
; overlays).  Holds the pipe-descriptor index (0..NPIPE-1) into _pipeTablePtr
; (src/kernel/pipe.s).  Read end and write end are distinct FCBs sharing the idx;
; FCB_FL_WRITE distinguishes the write end.
FCB_PipeIdx     EQU FCB_FstPriv+0

; Chardev-fd overlay of FCB_FstPriv (mutually exclusive with the ProDOS/socket/
; pipe overlays).  +1 is per-fd chardev flags — FCB_Flags itself is a full byte (all 8 bits assigned),
; so chardev-only state lives here.  Pty subsystem plan 2026-07-20.
FCB_CdFlags     EQU FCB_FstPriv+1       ; per-fd chardev flag byte
FCB_CDF_NONBLK  EQU $01                 ; FIONBIO: read/write return EWOULDBLOCK
                                        ; instead of sleeping (pty ops honor it;
                                        ; sockets keep their own SOCK_NB)

; FCB_Flags bits
FCB_FL_WRITE    EQU     $01             ; opened for writing
FCB_FL_DIRTY    EQU     $02             ; file written since open — Fs_Close
                                        ; must FOP_Flush (dir entry + pins).
                                        ; P3.3-iii-B: set by every write path;
                                        ; pool-block dirt is FCB_WDirty.
FCB_FL_DIR      EQU     $04             ; opendir-created (Fs_Readdir consumer)
                                        ; $08 is free
FCB_FL_SOCKET   EQU     $10             ; socket fd (FCB_SockIdx = descriptor off);
                                        ; close routes to _Sock_Teardown.
FCB_FL_PIPE     EQU     $20             ; pipe fd (FCB_PipeIdx = descriptor idx);
                                        ; close routes to _Pipe_Teardown.  Read/
                                        ; write route to _Pipe_Read/_Pipe_Write.
                                        ; $40 is free
                                        ; $80 is free

;------------------------------------------------------------------------------
; DESCRIPTOR TYPE (UFS 1.2) -- BSD's `f_type`, the thing an fd IS.
;
; TODAY THIS IS DERIVED, NOT STORED.  _Fcb_ClassifyFlags maps the FCB_FL_* bits
; above to one of these, and it is the single place that mapping exists.  A
; stored FCB_Type is the next step and is deliberately not this one: a field
; means every FCB-creating site must remember to set it, across six link units,
; and a site that forgot would produce an fd that dispatches as a plain file.
; Deriving first makes the classification reviewable on its own, and turns
; storing it into an optimisation rather than a correctness question.
;
; THE NUMBERS ARE BSD'S, from two different BSDs on purpose:
;   vendor/4.3BSD-Reno/sys/file.h:33     DTYPE_VNODE 1, DTYPE_SOCKET 2
;   vendor/2.11BSD/usr/sys/h/file.h:74   DTYPE_PIPE 3
; Reno has no DTYPE_PIPE because it makes pipe(2) a socketpair.  The campaign
; rejected that (see the plan's RESOLVED section: FGX's own pipe table behind
; an ops vector is where 4.4BSD itself ended up), so the pipe slot comes from
; 2.11BSD, which numbered it 3.
;
; A character device is a vnode, as in BSD -- DTYPE_VNODE with a VCHR type and
; specfs operations -- with no descriptor type of its own.  4 and 5 were FGX's
; console and chardev-switch pseudo-descriptors, both retired.
DTYPE_VNODE     EQU     1               ; a file (or directory) -- BSD
DTYPE_SOCKET    EQU     2               ; communications endpoint -- BSD
DTYPE_PIPE      EQU     3               ; pipe -- 2.11BSD

;------------------------------------------------------------------------------
; Open flags (2.11BSD layout)
;------------------------------------------------------------------------------
O_RDONLY        EQU     $0000
O_WRONLY        EQU     $0001
O_RDWR          EQU     $0002
O_NONBLOCK      EQU     $0004           ; Reno value: FNDELAY
O_APPEND        EQU     $0008           ; 2.11BSD value: writes seek-to-EOF first
O_CREAT         EQU     $0200
O_TRUNC         EQU     $0400
O_EXCL          EQU     $0800

;------------------------------------------------------------------------------
; File flags (Reno's f_flag / vn_open's `fmode'), for the assembly that
; marshals an open across the seam.
;
; THESE ARE THE O_ FLAGS ABOVE PLUS ONE, and that is upstream's arithmetic
; rather than a local convention: 4.3BSD-Reno kern/vfs_syscalls.c:559 is
; `fmode = uap->mode - FOPEN;' with sys/file.h:54 defining `#define FOPEN
; (-1)'.  It turns O_RDONLY (0) into FREAD (1) and O_WRONLY (1) into FWRITE
; (2); every higher bit already carries Reno's own value, which is why
; O_CREAT and FS_FCREAT are the same $0200 here and 01000 there.
;
; PREFIXED FS_ BECAUSE THE BARE NAMES ARE TAKEN.  include/ktty.s and
; include/pty.s each define their own FREAD/FWRITE at 1 and 2 for their own
; ABIs, and a bare `FREAD' here would collide on the next include that
; changed order.  The C side spells them FREAD/FWRITE/FCREAT in
; src/kernel/vfs/file.h and these must track it.
FS_FREAD        EQU     $0001           ; file.h:110  FREAD
FS_FWRITE       EQU     $0002           ; file.h:111  FWRITE
FS_FCREAT       EQU     $0200           ; file.h:120  FCREAT  (== O_CREAT)
FS_FTRUNC       EQU     $0400           ; file.h:121  FTRUNC  (== O_TRUNC)
FS_FEXCL        EQU     $0800           ; file.h:122  FEXCL   (== O_EXCL)

;------------------------------------------------------------------------------
; Whence values for lseek
;------------------------------------------------------------------------------
SEEK_SET        EQU     0
SEEK_CUR        EQU     1
SEEK_END        EQU     2

;------------------------------------------------------------------------------
; struct stat - subset, BSD layout (32 bytes).  Replaces the 16-byte
; legacy ST_* layout above; T12 deletes the legacy version once the
; new Fs_Stat lands.
;------------------------------------------------------------------------------
                DUM     0
STX_dev         DS      2
STX_ino         DS      2
STX_mode        DS      2               ; type bits (S_IF*) | access (S_I*USR)
STX_nlink       DS      2
STX_uid         DS      2
STX_gid         DS      2
STX_rdev        DS      2               ; the device a special file names; NODEV
                                        ;   otherwise
STX_size        DS      4
STX_atime       DS      4
STX_spare1      DS      2
STX_mtime       DS      4
STX_spare2      DS      2
STX_ctime       DS      4
STX_spare3      DS      2
STX_blksize     DS      4
STX_blocks      DS      4
STX_flags       DS      2               ; st_flags: uappnd, uchg, schg...  FGX
                                        ;   sets none and ls -o prints them all
                                        ;   as `-'; the FIELD is here because
                                        ;   its POSITION is.
STX_spare4      DS      6               ; u_short st_spare4[3]
STAT_SIZE       EQU     *               ; 52 bytes
                DEND
                ERR     STAT_SIZE-1/$34

;------------------------------------------------------------------------------
; Mode bits (subset of POSIX st_mode)
;------------------------------------------------------------------------------
S_IFMT          EQU     $F000           ; type-field mask (top nibble)
S_IFREG         EQU     $8000           ; regular file
S_IFDIR         EQU     $4000           ; directory
S_IFCHR         EQU     $2000           ; character device -- A TYPE A DEVICE
                                        ; NODE COULD NOT HAVE before the
                                        ; cutover: the legacy image's mode byte
                                        ; had three values and none of them
                                        ; said `device'.
; THE PERMISSION BITS, IN HEX AND NOT OCTAL, and that is not a style choice:
; Merlin32 reads a leading zero as nothing at all, so `0666' assembles as
; DECIMAL 666 ($029A).  Written that way a chardev's synthesised mode came out
; $229A and `ls -l /dev' printed `c-w--wx-wT'.  Spell the bits.
S_IRUSR         EQU     $0100           ; 0400 read by owner
S_IWUSR         EQU     $0080           ; 0200 write by owner
S_IXUSR         EQU     $0040           ; 0100 execute by owner
S_IRGRP         EQU     $0020           ; 0040 read by group
S_IWGRP         EQU     $0010           ; 0020 write by group
S_IXGRP         EQU     $0008           ; 0010 execute by group
S_IROTH         EQU     $0004           ; 0004 read by other
S_IWOTH         EQU     $0002           ; 0002 write by other
S_IXOTH         EQU     $0001           ; 0001 execute by other
S_IRWALL        EQU     $01B6           ; 0666 -- read+write for all three

;==============================================================================
; PUBLIC ENTRY POINTS
;
; Declared as labels in src/drivers/fs/*.s. This section documents the ABI
; contract for filesystem and block driver calls.
;==============================================================================

;------------------------------------------------------------------------------
; Fs_Init - read volume directory header, initialize filesystem state.
;
; In:   (none)                    Out: C=1 ok, C=0 + A=errno (EIO)
; DP:   writes _fsCwd, _fsVolHeader (via Blk_Read)
; Mem:  reads/writes _fsDirBuf (block 2)
;------------------------------------------------------------------------------
; Fs_Getcwd - return pointer to canonical CWD string.
;
; In:   (none)                    Out: X = ptr to null-term path (bank $02)
; DP:   (none)
; Mem:  reads _fsCwd
;------------------------------------------------------------------------------
; Fs_Stat - lookup file/dir, return stat info.
;
; In:   X = ptr to path string (bank $02)  Out: C=1 ok, C=0 + A=errno
;       _fsStatBuf = output buffer
; DP:   reads/writes _fsTmp0/_fsTmp1/_fsTmp2 (scratch)
; Mem:  reads/writes _fsDirBuf, _fsPathScratch, _fsNameBuf
;------------------------------------------------------------------------------
; Fs_Open - open file for reading.
;
; In:   X = ptr to path (bank $02)   Out: C=1 ok + A=fd, C=0 + A=errno
; DP:   reads/writes _fsTmp* (scratch); reads _fsFileState
; Mem:  reads/writes _fsPathScratch, _fsDirBuf, _fsFileState, _fsIndexBuf
;------------------------------------------------------------------------------
; Fs_Read - read bytes from open file.
;
; In:   A = file descriptor (0..2)      Out: C=1 ok + X=bytes read,
;       X = ptr to output buffer (bank $02)        C=0 + A=errno
;       _blkNum/_blkBuf set for current block
; DP:   reads/writes _fsTmp*, _fsFileState, _blkNum/_blkBuf (scratch)
; Mem:  reads/writes _fsFileState, _fsIndexBuf, block device
;------------------------------------------------------------------------------
; Fs_Close - close file descriptor.
;
; In:   A = file descriptor (0..2)   Out: C=1 ok, C=0 + A=errno
; DP:   writes _fsFileState
; Mem:  writes _fsFileState
;------------------------------------------------------------------------------
; Fs_Chdir - change working directory.
;
; In:   X = ptr to path (bank $02)   Out: C=1 ok, C=0 + A=errno
; DP:   reads/writes _fsTmp*, _fsCwd (scratch)
; Mem:  reads/writes _fsPathScratch, _fsDirBuf, _fsCwd
;------------------------------------------------------------------------------
; Path_Resolve - convert input path to canonical form.
;
; In:   X = ptr to path (bank $02)     Out: C=1 ok (_fsPathScratch = canonical),
;       _fsPathScratch = output buffer       C=0 + A=errno (EINVAL/ENAMETOOLONG)
; DP:   reads/writes _fsTmp*, _fsCwd, _fsTmp0h, _fsTmpSrcIdx (scratch)
; Mem:  reads/writes _fsPathScratch, _fsPathStaging, _fsNameBuf
;------------------------------------------------------------------------------
; Blk_Init - initialize block driver (set SmartPort entry point).
;
; In:   (none)                    Out: C=1 ok, C=0 + A=errno
; DP:   writes _blkTrampPtr (once, never clobbered by Con_* calls)
; Mem:  (none)
;------------------------------------------------------------------------------
; Blk_Read - read 512-byte block via SmartPort.
;
; In:   _blkNum = block number, LOW word  Out: C=1 ok, C=0 + A=errno (EIO)
;       _blkNumHi = block number, HIGH word -- OPTIONAL.  It self-clears at every
;       Blk_* entry, so a 16-bit caller may ignore it entirely and still address
;       block 0..65535 correctly.  A caller reaching past 32 MB stores it
;       IMMEDIATELY before the call; see include/dpmap.s for why that window is
;       the only place it is ever nonzero.
;       _blkBuf = 16-bit ptr to output buffer (bank $00)
; DP:   writes _blkNum, _blkNumHi, _blkBuf (caller-saved, not preserved)
; Mem:  writes to buffer at _blkBuf
;------------------------------------------------------------------------------

;==============================================================================
; END fs.s
;==============================================================================
