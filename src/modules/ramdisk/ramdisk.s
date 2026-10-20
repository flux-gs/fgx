;==============================================================================
; ramdisk.s - FGXM module: the /RAM5 RAM-disk driver.
;
; LIFTED OUT OF THE CORE KERNEL 2026-08-11 (was src/drivers/ramdisk/ramdisk.s,
; ~1 KB of a bank with under 200 bytes free).  The driver body is unchanged --
; see "why it moves verbatim" below.  What stayed behind is a pair of dispatch
; stubs in src/drivers/ramdisk/ramdisk.s so block.s's two EXT call sites still
; resolve, plus the _rd* statics.
;
; WHY IT COULD NOT MOVE BEFORE, and it was not the call sites: RamDisk_Init ran
; before Fs_EnumerateMounts, and modules do not register until Mod_LoadConf,
; which ran after it.  Moving the driver would have silently stopped /MNT/RAM5
; being mounted.  The enumeration now runs after the module tier (commit
; 7abaddc7b), which is what made this possible.
;
; WHY THE BODY MOVES VERBATIM.  mod_init is JSL'd by Mod_Load with DBR still
; the KERNEL bank, and every op below is entered the same way, so all the
; DBR-relative reads of kernel statics keep working exactly as they did
; in-kernel.  The DP soft-globals are direct-page offsets and so are
; bank-independent.  Only two things needed writing: the EQUs that replace the
; kernel's include tree, and the log path.
;
; THE LOG PATH is the one behavioural change, and it is not a loss.  The kernel
; composed "ramdisk: NNNN blocks @ bank $XX (adopted)" from four Kern_Log*
; calls; those have no gateway slot, and giving them one would spend scarce
; CORE-bank bytes to save module-bank bytes, which is backwards.  So the number
; formatting lives here (module bytes are free -- 47 KB spare in this bank) and
; the line goes out through SYS_MODLOG, which prepends "ramdisk: " from this
; module's own FGXM header name.  Byte-for-byte the same dmesg line.
;
; DBR DISCIPLINE: the body runs at DBR = kernel bank.  The ONLY places that
; need DBR = this module's bank are the SYS_MODLOG calls, because the impl
; reads the detail string DBR-relative from the caller's bank.  Those are
; wrapped PHB/PHK/PLB ... PLB.
;==============================================================================

                MX      %11
                ; WHERE THIS MODULE LIVES.  Modules stack into ONE shared bank;
                ; MODP_ORG is this module's build-time offset in it.
                PUT     modplace.s
                ORG     MODP_ORG

;------------------------------------------------------------------------------
; Jump-table slots (fixed bank-0 ABI; see include/modules.s).
;------------------------------------------------------------------------------
KFGX_ANCHOR     EQU     $00032C             ; loader-written live kernel
                                            ;   bank byte -- a module CANNOT
                                            ;   use PHK for this: PHK is the
                                            ;   MODULE's bank here
MOD_JT_BASE     EQU     $00032E
SYS_KCALL       EQU     MOD_JT_BASE+$12     ; multiplexed service slot;
                                            ;   X = service number
KSVC_LOGSTRNE   EQU     2                   ; A = bank-rel string ptr, no EOL
KSVC_LOGDEC16   EQU     3                   ; A = value, decimal
KSVC_LOGHEX8    EQU     4                   ; A.lo = byte, 2 hex digits
KSVC_LOGEOL     EQU     5                   ; end the line

;------------------------------------------------------------------------------
; KERNEL DIRECT-PAGE SOFT-GLOBALS.  DP offsets, so they are bank-independent
; and the body's uses need no change.  Hardcoded because DP labels never reach
; the bank-$02 build listing that the kernel_exports manifest scrapes -- the
; same reason bpf.s and serial.s hardcode theirs.
;
; TAKEN FROM include/dpmap.s'S LOCATION COUNTER, NOT ITS COMMENTS: that file
; warns in its own header that the per-line "$xx" comments in the $20-$4F block
; "run +4 vs the actual location counter" and that the listing is ground truth.
; Verified against the four it names (cur_font_data_ptr $24, _sigHndPtr $40,
; _bm_ptr $4C, _conStrPtr $E0) and the three bpf.s hardcodes ($54/$94/$F3).
;------------------------------------------------------------------------------
_blkNum         EQU     $10                 ; Blk_Read block number, low word
_blkBuf         EQU     $12                 ; dest buffer offset in kernel bank
_fsTmp0         EQU     $16                 ; fs scratch word
_fsTmp1         EQU     $18                 ; fs scratch word
_fsCurDevIdx    EQU     $20                 ; current device idx for block I/O
_devPtr         EQU     $21                 ; long ptr to current device record
dev_table_ptr   EQU     $2C                 ; long ptr to the heap _devTable
_libcTmp0       EQU     $50                 ; scratch word
_libcTmp2       EQU     $54                 ; long-ptr scratch (for [dp],Y)
_conStrPtr      EQU     $E0                 ; Kern_Log* string pointer

;------------------------------------------------------------------------------
; Device-table + volume-header layout.  THE HEADER ITSELF, not a copy of it:
; these offsets used to be seventeen private EQUs under a comment saying they
; MUST match include/fs.s, with nothing enforcing it -- and the day DSS grew a
; wider block count (apple/fgx#407) the copy would have written this module's
; idea of the struct into the kernel's, silently, at a stride two apart.  net.s
; states the rule where it PUTs the same file: a layout that drifted "would
; corrupt an FCB silently rather than failing the build".  It is DUM/EQU only
; and emits nothing.
;------------------------------------------------------------------------------
                PUT     ../../../include/fs.s

;------------------------------------------------------------------------------
; errno (include/errno.s) and the bank-$E1 RAM-disk rendezvous
; (include/ramdisk.s).  The $E1 addresses are fixed hardware/firmware
; locations, so long forms reach them from any bank.
;------------------------------------------------------------------------------
EIO             EQU     5
ENOMEM          EQU     12
RD_CurDiskSize  EQU     $E11642
RD_DiskHandles  EQU     $E11646
RD_FormatFlag   EQU     $E1164A
RD_BP_MIN       EQU     $0036
RD_BP_MAX       EQU     $0037
RD_DEFAULT_BYTES EQU    $00100000
RD_MAX_BYTES    EQU     $00200000

;------------------------------------------------------------------------------
; Kernel statics this module reads DBR-relatively (DBR = kernel bank
; throughout).  GENERATED from the kernel build listing every build, so they
; cannot drift: _rdBufPtr/_rdSizeBytes/_rdBlocks/_rdPresent stayed kernel-side
; because the dispatch stubs report on them, and _kFgxUserID / _fsDirBuf /
; _diskStates / _blkCurHi / _blkCurBufBank / _blkSrcPool / _kBlkTabBase are the
; kernel's own.
;------------------------------------------------------------------------------
                PUT     kernel_exports.s

;------------------------------------------------------------------------------
; FGXM header v2 (40 bytes).
;------------------------------------------------------------------------------
ramdisk_bss     EQU     0

ramdisk_hdr     ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi
                DFB     $02                             ; +7  header format v2
                DA      mod_init-$050000                ; +8  entry, bank-rel
                DA      ramdisk_end-ramdisk_text        ; +10 text bytes
                DA      ramdisk_bss                     ; +12 bss bytes
                DA      ramdisk_vtdir-ramdisk_text      ; +14 vtdir offset
ramdisk_modname ASC     'ramdisk'                       ; +16 module name
                DS      16-*+ramdisk_modname            ;     NUL-pad to 16
                DA      $0000                           ; +32 module version
                DA      KERN_BUILD_ID                   ; +34 kernel build id
                DS      4                               ; +36 reserved

ramdisk_text    EQU     *

;------------------------------------------------------------------------------
; VTDR: one VT_BLOCKDEV vtable.  The vtable is two 16-BIT bank-relative
; offsets, not 24-bit pointers: the kernel already knows this module's bank
; from the registry entry, so it supplies the bank itself and nothing here
; needs self-patching at load.
;------------------------------------------------------------------------------
VT_BLOCKDEV     EQU     $0005
VT_END          EQU     $0000

ramdisk_vtdir   ASC     'VTDR'
                DA      VT_BLOCKDEV
                DA      ramdisk_ops-ramdisk_text
                DA      VT_END

ramdisk_ops     DA      _RAM_ReadBlock-$050000          ; +0 read
                DA      _RAM_WriteBlock-$050000         ; +2 write

;==============================================================================
; mod_init - Mod_Load JSLs here with DBR = KERNEL bank and MX %00.
;
; Does what RamDisk_Init did, then returns C=1 so the load counts as a success.
; RamDisk_Init's own C was always don't-care (a missing RAM disk is non-fatal),
; and that stays true: the module loads even when NewHandle fails.
;==============================================================================
mod_init        MX      %00
                JSR     RamDisk_Init
                SEC
                RTL

                MX      %00

;==============================================================================
; RamDisk_Init - detect-or-create the /RAM5 buffer and log the outcome.
;
; Boot entry point (called from main.s right after Toolbox_GetOwnID, so
; _kFgxUserID is valid for RamDisk_Create's NewHandle).  Tries to adopt a
; pre-existing firmware/GS-OS RAM-disk buffer; if none, creates an FGX-owned
; one.  Emits a dmesg line:
;
;   ramdisk: NNNN blocks @ bank $XX (adopted)   - adopted a pre-existing buffer
;   ramdisk: NNNN blocks @ bank $XX (created)   - allocated our own buffer
;   ramdisk: none                                - NewHandle failed (non-fatal)
;
; where NNNN = _rdBlocks (decimal) and $XX = the buffer's bank byte
; (_rdBufPtr+2).  Non-fatal: always returns to the caller; its own C is
; don't-care (callers must not branch on it).
;
; Register/flag contract:
;   In:   none.  _kFgxUserID must be valid (precondition of RamDisk_Create).
;   Out:  P (incl. M/X widths) restored via PHP/PLP; A/X/Y clobbered;
;         _libcTmp0 clobbered (holds the suffix-label address for the log).
; Reference: _fs_logMount (src/drivers/fs/fs.s) - same Kern_Log* compose style.
;==============================================================================
RamDisk_Init
                MX      %00
                PHP
                REP     #$30                    ; M=16, X=16
                MX      %00

                JSR     RamDisk_DetectExisting
                BCC     @rdi_create             ; nothing to adopt -> create
                ; Adopted: suffix = " (adopted)".
                LDA     #@rdi_sfx_adopted
                STA     _libcTmp0
                BRA     @rdi_present

@rdi_create     JSR     RamDisk_Create
                BCC     @rdi_none               ; NewHandle failed -> "none"
                ; Created: suffix = " (created)".
                LDA     #@rdi_sfx_created
                STA     _libcTmp0
                ; fall through to the shared present-path log.

;--- Shared present-path: lay down a ProDOS volume (no-op if already
;    formatted, e.g. an adopted GS/OS disk), then log.  RamDisk_Format
;    early-returns on RD_FormatFlag==$FFFF, so calling it unconditionally on
;    the present path is safe; its C is don't-care here (a write failure just
;    leaves the buffer unmountable - still non-fatal for boot).  NOT reached
;    on the @rdi_none (allocation-failed) path.
@rdi_present    JSR     RamDisk_Format

                ;--- Register the RAM disk in _devTable so the block layer +
                ;    mount enumerator can see it (Task 4.1).  Non-fatal: if the
                ;    device table is full it simply isn't registered (its C is
                ;    don't-care).  NOT reached on the @rdi_none path. ---
                JSR     RamDisk_RegisterDev

            ;--- Emit the dmesg line.  Byte-for-byte what the in-kernel
            ; version printed; only the route changed.
            ;
            ; DBR DISCIPLINE, and it is the whole trick here: the body runs at
            ; DBR = KERNEL bank, but KSVC_LOGSTRNE reads its string from the
            ; CALLER's bank.  So read the two KERNEL-side values first, park
            ; them in DIRECT PAGE (bank-independent), then hand DBR to this
            ; module for the duration of the strings.
            LDA     _rdBlocks
            STA     _fsTmp0                 ; DP: survives the DBR switch
            LDA     _rdBufPtr+2             ; bank + adjacent byte at M=16
            AND     #$00FF                  ; keep only the bank byte
            STA     _fsTmp1                 ; DP
            PHB
            PHK
            PLB                             ; DBR = this module's bank

            LDA     #@rdi_pfx
            LDX     #KSVC_LOGSTRNE
            JSL     SYS_KCALL               ; "ramdisk: "
            LDA     _fsTmp0
            LDX     #KSVC_LOGDEC16
            JSL     SYS_KCALL               ; NNNN (decimal block count)
            LDA     #@rdi_mid
            LDX     #KSVC_LOGSTRNE
            JSL     SYS_KCALL               ; " blocks @ bank $"
            LDA     _fsTmp1
            LDX     #KSVC_LOGHEX8
            JSL     SYS_KCALL               ; XX (buffer bank, 2 hex digits)
            LDA     _libcTmp0               ; suffix stashed above (DP)
            LDX     #KSVC_LOGSTRNE
            JSL     SYS_KCALL               ; " (adopted)" / " (created)"
            LDX     #KSVC_LOGEOL
            JSL     SYS_KCALL
            PLB                             ; DBR = kernel bank again
            PLP
            RTS

;--- Allocation failed: "ramdisk: none" (non-fatal). ---
@rdi_none   PHB
            PHK
            PLB                             ; DBR = this module's bank
            LDA     #@rdi_nopfx
            LDX     #KSVC_LOGSTRNE
            JSL     SYS_KCALL               ; "ramdisk: none"
            LDX     #KSVC_LOGEOL
            JSL     SYS_KCALL
            PLB
            PLP
            RTS

@rdi_pfx         ASC    'ramdisk: ',00
@rdi_mid         ASC    ' blocks @ bank $',00
@rdi_sfx_adopted ASC    ' (adopted)',00
@rdi_sfx_created ASC    ' (created)',00
@rdi_nopfx       ASC    'ramdisk: none',00

;==============================================================================
; RamDisk_RegisterDev - inject the RAM disk into _devTable / _diskStates.
;
; Finds the first free _devTable slot (Dev_Init filled 0..N-1 with the boot bus
; + SmartPort units; N..31 are still DEV_CLASS_EMPTY) and populates it for the
; RAM disk so the block layer + mount enumerator can see it:
;
;   _devTable[idx]:  DEV_Class = DEV_CLASS_RAM
;                    DEV_Flags = DEV_FLAG_ONLINE
;                    DEV_Name  = "RAM5\0\0"
;                    DEV_Ops*  = untouched (vestigial; never dispatched)
;                    DEV_State = &_diskStates[idx], bank = live kernel bank
;                                (PHK) so it points at the relocated bank where
;                                _diskStates lives - reloc-safe, mirroring
;                                _dev_allocDevEntry.
;   _diskStates[idx]: DSS_BusIdx = 0 (no SmartPort bus)
;                     DSS_LocalUnit = 0 (no unit)
;                     DSS_BlkCount  = _rdBlocks
;
; Modelled on _dev_allocDevEntry (src/drivers/dev/dev.s) steps 1/2/3/5/6, MINUS
; the SmartPort bus/unit bits and the per-bus unit-count bump.
;
; Register/flag contract:
;   In:   _rdBlocks valid (the present path of RamDisk_Init guarantees this).
;   Out:  Non-fatal; C is don't-care.  If the device table is full (no
;         DEV_CLASS_EMPTY slot by idx 31) it simply returns without
;         registering.  P (incl. M/X widths) restored via PHP/PLP;
;         A/X/Y clobbered; _devPtr + _blkBuf/_fsTmp1 clobbered (NOT _fsTmp2,
;         which Blk_Read's contract preserves).
;
; THE SLOT-SCAN SCRATCH IS _fsTmp1 AND MUST NOT GO BACK TO _blkBuf+2
; (apple/fgx#91).  _blkBuf is $12, so _blkBuf+2 is $14 -- which is _blkNumHi,
; the block layer's 32-bit block-key HIGH word.  Leaving the winning slot index
; there meant the NEXT Blk_Read latched it into _blkCurHi and asked for block
; $0001_0002 instead of block 2, poisoning whichever read came next: with the
; driver in-kernel that was some unremarkable boot read, and as a module it was
; the mount enumeration, so /MNT/RAM5 silently stopped mounting.  $14 was
; genuinely spare padding when this was written (dpmap.s: "was _blkUnit
; (retired) + pad"); UFS 1.0 made it live.  _fsTmp1 is safe because it is
; documented caller-saved fs scratch that Blk_Read/Blk_Write preserve for their
; callers, and RamDisk_Format has already clobbered it via _RAM_WriteBlock.
; Reference: _dev_allocDevEntry (dev.s) - exact field-population style.
;==============================================================================
RamDisk_RegisterDev    
                MX      %10
                PHP
                SEP     #$20
                MX      %10                     ; M=8, X=16 (mirror _dev_alloc*)

                ;--- 1. Find the first free _devTable slot (idx 1..31).  For
                ;    each idx: _devPtr = dev_table_ptr + idx*DEV_SIZE, then read
                ;    DEV_Class via [_devPtr],Y (Y=0).  First class==EMPTY wins.
                ;    None free by 31 -> non-fatal: just return. ---
                LDA     #1
                STA     _fsTmp1                 ; idx (8-bit; chosen-slot scratch --
                                                ;   NOT _blkBuf+2, see the header)
@rrd_findL      MX      %10
                LDA     _fsTmp1
                CMP     #FS_MAX_DEVICES
                BCC     @rrd_chk
                ; No free slot -> don't register (non-fatal).
                PLP
                RTS
@rrd_chk        ; _devPtr = dev_table_ptr + idx*DEV_SIZE.
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
                ; DEV_Class == DEV_CLASS_EMPTY ?
                LDY     #DEV_Class
                LDA     [_devPtr],Y
                CMP     #DEV_CLASS_EMPTY
                BEQ     @rrd_found
                INC     _fsTmp1               ; next idx
                BRA     @rrd_findL

@rrd_found      ; _devPtr already points at the chosen slot; idx in _fsTmp1.

                ;--- 2. DEV_Class = RAM, DEV_Flags = ONLINE. ---
                LDY     #DEV_Class
                LDA     #DEV_CLASS_RAM
                STA     [_devPtr],Y
                LDY     #DEV_Flags
                LDA     #DEV_FLAG_ONLINE
                STA     [_devPtr],Y

                ;--- 3. DEV_Name = "RAM5\0\0". ---
                LDA     #'R'
                LDY     #DEV_Name+0
                STA     [_devPtr],Y
                LDA     #'A'
                LDY     #DEV_Name+1
                STA     [_devPtr],Y
                LDA     #'M'
                LDY     #DEV_Name+2
                STA     [_devPtr],Y
                LDA     #'5'
                LDY     #DEV_Name+3
                STA     [_devPtr],Y
                LDA     #0
                LDY     #DEV_Name+4
                STA     [_devPtr],Y
                LDY     #DEV_Name+5
                STA     [_devPtr],Y

                ;--- 4. DEV_Ops*: vestigial (never dispatched - RAM-class block
                ;       I/O routes through _RAM_ReadBlock/_RAM_WriteBlock).
                ;       Leave as-is.

                ;--- 5. DEV_State = &_diskStates[idx] (16-bit offset = _diskStates
                ;       + idx*DSS_SIZE; bank = live kernel bank via PHK so it
                ;       points at the relocated bank, mirroring _dev_alloc*). ---
                REP     #$20
                MX      %00
                LDA     _fsTmp1
                AND     #$00FF
                ASL
                ASL                             ; *4 (DSS_SIZE)
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
                LDAL    KFGX_ANCHOR             ; DEV_StateBank := live kernel bank
                                                ;   (where _diskStates lives).  NOT PHK:
                                                ;   in a module that is the module's
                                                ;   own bank.
                LDY     #DEV_StateBank
                STA     [_devPtr],Y

                ;--- 6. Populate _diskStates[idx] (X = idx*DSS_SIZE).  Set
                ;       DBR=kernel bank (PHB/PHK/PLB) for the writes so they land
                ;       in the relocated bank where _SP_ReadBlock reads them,
                ;       matching _dev_allocDevEntry.  No SmartPort bus/unit. ---
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
                PHB
                LDAL    KFGX_ANCHOR
                PHA
                PLB                             ; DBR = live kernel bank (not PHK --
                                                ;   see KFGX_ANCHOR above)
                LDA     #0
                STA     _diskStates+DSS_BusIdx,X      ; no SmartPort bus
                STA     _diskStates+DSS_LocalUnit,X   ; no unit
                ; DSS_BlkCount is four bytes now; a RAM disk needs two of
                ; them and the upper pair must still be written, or the raw
                ; device range-checks against whatever the last device left.
                REP     #$20
                MX      %00
                LDA     _rdBlocks
                SEP     #$20
                MX      %10
                STA     _diskStates+DSS_BlkCount,X
                XBA
                STA     _diskStates+DSS_BlkCount+1,X
                LDA     #0
                STA     _diskStates+DSS_BlkCount+2,X
                STA     _diskStates+DSS_BlkCount+3,X
                PLB                             ; restore DBR

                PLP
                RTS

;==============================================================================
; RamDisk_Format - lay down a minimal empty ProDOS volume on the RAM buffer.
;
; Synthesizes, block-by-block into _fsDirBuf and out via _RAM_WriteBlock:
;   block 0,1   boot blocks - all zeros (data volume; never executed, just
;               marked used in the bitmap).
;   block 2     volume directory KEY block: prev=0, next=3, then the volume
;               header entry (at block offset 4): storage_type $F | name_len 4,
;               name "RAM5", standard access $C3, entry_len $27, 13 entries/blk,
;               file_count 0, bitmap_ptr 6, total_blocks = _rdBlocks.
;   block 3,4,5 rest of the volume directory (empty entries), chained
;               2<-3<->4<->5->end (prev/next links only).
;   block 6     volume bitmap: 1 bit/block, 1=free 0=in-use, MSB of byte 0 =
;               block 0.  byte0 = $01 (blocks 0..6 used, block 7 free); bytes
;               1..(bitmap_bytes-1) = $FF (all higher blocks free); the rest of
;               the block stays 0 (non-existent blocks).  bitmap_bytes =
;               _rdBlocks>>3 (_rdBlocks is always a multiple of 64, so this is
;               exact and <=512 - one block).
; On all 7 writes succeeding, sets RD_FormatFlag ($E1164A) = $FFFF.
;
; Skips the whole job (returns C=1 immediately) when RD_FormatFlag is already
; $FFFF - e.g. an adopted GS/OS RAM disk that already carries a ProDOS dir.
;
; Register/flag contract:
;   In:   _rdBlocks / _rdBufPtr valid and _rdPresent=1 (the present path of
;         RamDisk_Init guarantees this).  M/X widths: don't-care (PHP/PLP).
;   Out:  C=1 formatted (or already-formatted);
;         C=0 and A=EIO if any _RAM_WriteBlock fails (non-fatal at the caller).
;         P (incl. M/X) restored via PHP/PLP; A/X/Y clobbered;
;         _fsTmp0/_fsTmp1/_libcTmp2 clobbered (via _RAM_WriteBlock); uses
;         _fsDirBuf as the block-build scratch.
; Reference: standard ProDOS volume directory + bitmap; FGX FST field offsets
;            in include/fs.s (VH_*); Bm_Sync's _fsDirBuf staging style.
;==============================================================================
RamDisk_Format    
                MX      %00
                PHP
                REP     #$30                    ; M=16, X=16
                MX      %00

                ;--- Already formatted (adopted GS/OS disk)?  Then nothing to
                ;    do - the disk already carries a valid ProDOS dir. ---
                LDAL    RD_FormatFlag
                CMP     #$FFFF
                BNE     @rf_doformat
                PLP
                SEC
                RTS

@rf_doformat
                ;--- Blocks 0 and 1: zero boot blocks. ---
                JSR     _RamDisk_ZeroDirBuf
                LDA     #0
                JSR     _RamDisk_WriteDirBuf    ; block 0
                BCS     @rf_w0
                BRL     @rf_eio                 ; long branch: @rf_eio is far
@rf_w0          JSR     _RamDisk_ZeroDirBuf
                LDA     #1
                JSR     _RamDisk_WriteDirBuf    ; block 1
                BCS     @rf_w1
                BRL     @rf_eio
@rf_w1

                ;--- Block 2: volume directory key block. ---
                JSR     _RamDisk_ZeroDirBuf
                ; Links: prev_block=0 (key block), next_block=3.
                LDA     #$0000
                STA     _fsDirBuf+0             ; prev_block
                LDA     #$0003
                STA     _fsDirBuf+2             ; next_block
                ; Volume header entry begins at BLOCK offset 4, so every VH_*
                ; field lands at (4 + VH_offset).
                ; VH_StorageName ($00): storage_type $F (vol dir) | name_len 4.
                SEP     #$20
                MX      %10                     ; M=8 for the single-byte pokes
                LDA     #$F4
                STA     _fsDirBuf+4+VH_StorageName
                ; VH_Name ($01, 15 B): "RAM5" (only name_len bytes; rest 0).
                LDA     #'R'
                STA     _fsDirBuf+4+VH_Name+0
                LDA     #'A'
                STA     _fsDirBuf+4+VH_Name+1
                LDA     #'M'
                STA     _fsDirBuf+4+VH_Name+2
                LDA     #'5'
                STA     _fsDirBuf+4+VH_Name+3
                ; VH_Access ($1E): destroy/rename/backup/write/read enabled.
                LDA     #$C3
                STA     _fsDirBuf+4+VH_Access
                ; VH_EntryLen ($1F) = 39.
                LDA     #$27
                STA     _fsDirBuf+4+VH_EntryLen
                ; VH_EntriesPerBlk ($20) = 13.
                LDA     #$0D
                STA     _fsDirBuf+4+VH_EntriesPerBlk
                REP     #$20
                MX      %00                     ; back to M=16 for the word pokes
                ; VH_FileCount ($21, 2 B) = 0.
                LDA     #$0000
                STA     _fsDirBuf+4+VH_FileCount
                ; VH_BitmapPtr ($23, 2 B) = 6.
                LDA     #$0006
                STA     _fsDirBuf+4+VH_BitmapPtr
                ; VH_TotalBlocks ($25, 2 B) = _rdBlocks.
                LDA     _rdBlocks
                STA     _fsDirBuf+4+VH_TotalBlocks
                ; (VH_Reserved / create date / version / min_version stay 0.)
                LDA     #2
                JSR     _RamDisk_WriteDirBuf    ; block 2
                BCS     @rf_w2
                BRL     @rf_eio
@rf_w2

                ;--- Block 3: prev=2, next=4. ---
                JSR     _RamDisk_ZeroDirBuf
                LDA     #$0002
                STA     _fsDirBuf+0
                LDA     #$0004
                STA     _fsDirBuf+2
                LDA     #3
                JSR     _RamDisk_WriteDirBuf    ; block 3
                BCS     @rf_w3
                BRL     @rf_eio
@rf_w3

                ;--- Block 4: prev=3, next=5. ---
                JSR     _RamDisk_ZeroDirBuf
                LDA     #$0003
                STA     _fsDirBuf+0
                LDA     #$0005
                STA     _fsDirBuf+2
                LDA     #4
                JSR     _RamDisk_WriteDirBuf    ; block 4
                BCS     @rf_w4
                BRL     @rf_eio
@rf_w4

                ;--- Block 5: prev=4, next=0 (end of the dir chain). ---
                JSR     _RamDisk_ZeroDirBuf
                LDA     #$0004
                STA     _fsDirBuf+0
                LDA     #$0000
                STA     _fsDirBuf+2
                LDA     #5
                JSR     _RamDisk_WriteDirBuf    ; block 5
                BCS     @rf_w5
                BRL     @rf_eio
@rf_w5

                ;--- Block 6: volume bitmap.  byte0 = $01 (blocks 0..6 in-use,
                ;    block 7 free); bytes 1..(bitmap_bytes-1) = $FF (free); the
                ;    rest of the block stays 0 (non-existent blocks).
                ;    bitmap_bytes = _rdBlocks >> 3. ---
                JSR     _RamDisk_ZeroDirBuf
                ; bitmap_bytes = _rdBlocks / 8 -> _fsTmp0 (16-bit; <=512).
                LDA     _rdBlocks
                LSR     A
                LSR     A
                LSR     A
                STA     _fsTmp0                 ; bitmap_bytes
                ; byte[0] = $01.
                SEP     #$20
                MX      %10                     ; M=8 for the bitmap byte writes
                LDA     #$01
                STA     _fsDirBuf+0
                ; bytes[1 .. bitmap_bytes-1] = $FF.  X = byte index, starting 1.
                LDX     #1
@rf_bmL         CPX     _fsTmp0                 ; X < bitmap_bytes ? (16-bit X)
                BCS     @rf_bmDone
                LDA     #$FF
                STA     _fsDirBuf,X
                INX
                BRA     @rf_bmL
@rf_bmDone      REP     #$20
                MX      %00
                LDA     #6
                JSR     _RamDisk_WriteDirBuf    ; block 6
                BCC     @rf_eio

                ;--- All 7 blocks written: mark the volume formatted. ---
                LDA     #$FFFF
                STAL    RD_FormatFlag
                PLP
                SEC
                RTS

@rf_eio         ; A _RAM_WriteBlock failed (it left A=EIO at M=8).  Leave
                ; RD_FormatFlag as-is so a later attempt can retry; propagate
                ; C=0 + A=EIO (non-fatal at the caller).
                SEP     #$20
                MX      %10
                LDA     #EIO
                PLP
                CLC
                RTS

;==============================================================================
; _RamDisk_ZeroDirBuf - zero-fill the 512-byte _fsDirBuf block-build scratch.
;   In/Out: MX %00 (M=16, X=16).  A/X clobbered.  DBR = kernel bank (so the
;           DBR-relative _fsDirBuf store hits the live buffer).
;==============================================================================
_RamDisk_ZeroDirBuf MX  %00
                LDX     #0
                LDA     #0
@rz_L           STA     _fsDirBuf,X
                INX
                INX
                CPX     #512
                BCC     @rz_L
                RTS

;==============================================================================
; _RamDisk_WriteDirBuf - write the staged _fsDirBuf to a RAM-disk block.
;   In:   A = block number (16-bit).  MX %00.
;   Out:  C=1 ok; C=0 + A=EIO on failure (from _RAM_WriteBlock).
;         _blkNum/_blkBuf set; A/X/Y, _fsTmp0/_fsTmp1, _libcTmp2 clobbered.
;==============================================================================
_RamDisk_WriteDirBuf MX %00
                STA     _blkNum                 ; block number
                LDA     #_fsDirBuf              ; source buffer OFFSET (kernel bank)
                STA     _blkBuf
                ;--- THE LATCHES Blk_Write WOULD HAVE SET, since this goes to
                ;    the body directly.  Blk_Read/Blk_Write leave the last
                ;    transfer's _blkCurHi and _blkCurBufBank latched, and the
                ;    body reads both: a UFS read before this module loaded left
                ;    the vfs_bio arena's bank there, and the directory went in
                ;    from that bank instead of _fsDirBuf (measured: block 2 all
                ;    zeros after a format that reported success).  A 16-bit
                ;    block in the kernel bank, not a pool entry. ---
                STZ    |_blkCurHi
                STZ    |_blkCurBufBank
                SEP     #$20
                MX      %10
                STZ    |_blkSrcPool
                REP     #$20
                MX      %00
                JSR     _RamWrBody              ; C / A=EIO propagate to caller
                                                ; (the BODY: _RAM_WriteBlock is
                                                ;  the RTL wrapper the kernel
                                                ;  JSLs, and JSR-ing that would
                                                ;  return through the wrong
                                                ;  return-address width)
                RTS

;==============================================================================
; RamDisk_DetectExisting - adopt a pre-existing firmware/GS-OS RAM-disk buffer.
;
; Reads the GS/OS RAM Disk Tool Set rendezvous in bank $E1:
;   RD_DiskHandles ($E11646)  MM handle to the buffer (0 = no buffer)
;   RD_CurDiskSize ($E11642)  buffer size in bytes (blocks = size/512)
;
; If a handle is present, dereferences it (handle -> master pointer = stable
; 24-bit buffer base, because the buffer is locked|fixed) and records:
;   _rdBufPtr    = 24-bit buffer base
;   _rdSizeBytes = 32-bit size in bytes
;   _rdBlocks    = _rdSizeBytes / 512 (16-bit; <=4096 for a 2 MB disk)
;   _rdPresent   = 1
;
; Register/flag contract:
;   In:   none (reads fixed rendezvous + writes kernel statics).
;   Out:  C=1 and statics populated when a buffer was adopted;
;         C=0 and statics untouched when no buffer exists.
;         P (incl. M/X widths) restored to the caller's entry state via PHP/PLP
;         on every return path; A/X/Y are clobbered.
; Reference: ram5.aii Startup/gotdisk path (handle present-check + deref).
;==============================================================================
RamDisk_DetectExisting    
                MX      %00
                PHP
                REP     #$30                    ; M=16, X=16
                MX      %00

                ;--- Present-check: OR both 16-bit halves of the handle. ---
                LDAL    RD_DiskHandles          ; handle lo16
                ORAL    RD_DiskHandles+2        ; | handle hi16
                BNE     @rde_present
                ; No buffer -> nothing to adopt.
                PLP
                CLC
                RTS

@rde_present
                ;--- Copy the handle's low 24 bits into _libcTmp2 (DP long
                ;    pointer) so we can deref it with [dp] / [dp],Y. ---
                LDAL    RD_DiskHandles          ; handle bits 0..15
                STA     _libcTmp2               ; _libcTmp2   = handle lo16
                LDAL    RD_DiskHandles+2        ; handle bits 16..31 (low byte = bank)
                SEP     #$20
                MX      %10                     ; M=8, X=16
                STA     _libcTmp2+2             ; _libcTmp2+2 = handle bank byte
                REP     #$20
                MX      %00

                JSR     _RamDisk_DerefHandle    ; [_libcTmp2] -> _rdBufPtr (24-bit base)

                ;--- Size in bytes (32-bit) from RD_CurDiskSize. ---
                LDAL    RD_CurDiskSize          ; size lo16
                STA     _rdSizeBytes
                LDAL    RD_CurDiskSize+2        ; size hi16
                STA     _rdSizeBytes+2

                ;--- _rdBlocks = _rdSizeBytes / 512  (>> 9 over the 32-bit
                ;    value; result fits 16 bits for sizes <= 2 MB). ---
                LDA     _rdSizeBytes+2          ; hi16 -> shift scratch
                STA     _libcTmp0
                LDA     _rdSizeBytes            ; lo16 in A
                LDX     #9                      ; 16-bit X (set by REP #$30)
@rde_shr        LSR     _libcTmp0               ; hi16 >> 1; bit0 -> C
                ROR     A                       ; C -> lo16 bit15
                DEX
                BNE     @rde_shr
                STA     _rdBlocks               ; quotient low 16 = block count

                ;--- Mark present. ---
                SEP     #$20
                MX      %10
                LDA     #1
                STA     _rdPresent

                PLP
                SEC
                RTS

;==============================================================================
; RamDisk_Create - allocate an FGX-owned RAM-disk buffer and record it.
;
; Sizes the buffer from the BRAM minimum RAM-disk-size graduation (ReadBParam
; $0C03, parm RD_BP_MIN), where each graduation = 32 KB (e.g. $20 -> 1024 KB),
; clamped to [RD_DEFAULT_BYTES .. RD_MAX_BYTES] (1..2 MB).  NewHandles a
; locked|fixed block (may span banks) under the kernel MM user ID, writes the
; handle + size to the bank-$E1 GS/OS RAM Disk Tool Set rendezvous
; (RD_DiskHandles/RD_CurDiskSize), dereferences the handle to the stable 24-bit
; buffer base, and records:
;   _rdBufPtr    = 24-bit buffer base (via _RamDisk_DerefHandle)
;   _rdSizeBytes = 32-bit clamped size in bytes
;   _rdBlocks    = _rdSizeBytes / 512
;   _rdPresent   = 1
;   RD_FormatFlag ($E1164A) = 0  (unformatted; Phase 3 builds the ProDOS dir)
;
; PRECONDITION: _kFgxUserID must already be valid (set by Toolbox_GetOwnID,
; main.s:239).  This routine does NOT call GetOwnID; Task 1.4 wires the
; RamDisk_Init call AFTER that point.  (Not yet called - Task 1.4.)
;
; Register/flag contract:
;   In:   none (reads BRAM + _kFgxUserID; writes rendezvous + kernel statics).
;   Out:  C=1 and all statics + rendezvous populated on success;
;         C=0 and A=ENOMEM if NewHandle fails (rendezvous + _rd* statics left
;         untouched - exactly as RamDisk_DetectExisting left them).
;         P (incl. M/X widths) restored to the caller's entry state via PHP/PLP
;         on every return path; A/X/Y are clobbered.
; Reference: ram5.aii buffer-allocate path; _Sys_MmAlloc NewHandle frame
;            (src/kernel/syscall.s).
;==============================================================================
RamDisk_Create    
                MX      %00
                PHP
                REP     #$30                    ; M=16, X=16
                MX      %00

                ;--- Read the BRAM minimum RAM-disk-size graduation. ---
                PEA     $0000                   ; result space (word)
                PEA     RD_BP_MIN               ; parm # = $0036
                LDX     #$0C03                  ; _ReadBParam (Misc Tool Set)
                JSL     $E10000
                PLA                             ; A = graduation (32K/unit)

                ;--- grad -> bytes (= grad << 15), 32-bit, decomposed:
                ;      hi16 = grad >> 1
                ;      lo16 = (grad bit0) ? $8000 : 0
                ;    Stage straight into _rdSizeBytes (its final home). ---
                AND     #$00FF                  ; keep grad in low byte (hi=0)
                LSR     A                       ; A = grad>>1 = bytes hi16; C = bit0
                STA     _rdSizeBytes+2          ; bytes hi16
                LDA     #0
                ROR     A                       ; A = C<<15 = bytes lo16 ($8000/$0000)
                STA     _rdSizeBytes            ; bytes lo16

                ;--- Clamp to [RD_DEFAULT_BYTES .. RD_MAX_BYTES] (32-bit; compare
                ;    hi16, then lo16).  Literal halves of the EQUs below:
                ;      RD_DEFAULT_BYTES $00100000 -> hi $0010, lo $0000
                ;      RD_MAX_BYTES     $00200000 -> hi $0020, lo $0000
                ;    Covers grad==0 (BRAM unreadable -> floor to default) and
                ;    oversize (-> ceiling). ---
                ; Low floor: bytes < RD_DEFAULT_BYTES ?
                LDA     _rdSizeBytes+2
                CMP     #$0010                  ; hi16 vs default hi
                BCC     @rdc_floor              ; hi < default hi -> too small
                BNE     @rdc_chkmax             ; hi > default hi -> not below floor
                LDA     _rdSizeBytes
                CMP     #$0000                  ; equal hi: compare lo16 vs default lo
                BCS     @rdc_chkmax             ; lo >= default lo -> at/above floor
@rdc_floor      LDA     #$0000                  ; -> RD_DEFAULT_BYTES ($00100000)
                STA     _rdSizeBytes
                LDA     #$0010
                STA     _rdSizeBytes+2
                BRA     @rdc_clamped            ; default is within [def..max]
@rdc_chkmax     ; High ceiling: bytes > RD_MAX_BYTES ?
                LDA     _rdSizeBytes+2
                CMP     #$0020                  ; hi16 vs max hi
                BCC     @rdc_clamped            ; hi < max hi -> within range
                BNE     @rdc_ceil               ; hi > max hi -> too big
                LDA     _rdSizeBytes
                CMP     #$0000                  ; equal hi: compare lo16 vs max lo
                BEQ     @rdc_clamped            ; lo == max lo -> exactly max, ok
                BCC     @rdc_clamped            ; lo < max lo -> within range
@rdc_ceil       LDA     #$0000                  ; -> RD_MAX_BYTES ($00200000)
                STA     _rdSizeBytes
                LDA     #$0020
                STA     _rdSizeBytes+2
@rdc_clamped

                ;--- NewHandle the clamped size (mirror _Sys_MmAlloc frame).
                ;    blockSize pushed HI word then LO word (Toolbox arg order). ---
                PEA     $0000                   ; +2 result handle lo placeholder
                PEA     $0000                   ; +2 result handle hi placeholder
                LDA     _rdSizeBytes+2
                PHA                             ; +2 blockSize hi
                LDA     _rdSizeBytes
                PHA                             ; +2 blockSize lo
                LDA     _kFgxUserID
                PHA                             ; +2 userID
                PEA     $C008                   ; +2 attr = locked|fixed|noSpec;
                                                ;   NO noCross -> may span banks
                PEA     $0000                   ; +2 locationPtr hi (ignored)
                PEA     $0000                   ; +2 locationPtr lo (ignored)
                LDX     #$0902                  ; _NewHandle
                JSL     $E10000
                BCS     @rdc_fail
                ; Success: Toolbox popped the 12 input bytes; 4-byte handle on
                ; top: 1,S = handle lo (offset), 3,S = handle hi (bank in lo byte).

                ;--- Write the handle to the bank-$E1 rendezvous (long stores). ---
                LDA     1,S                     ; handle lo16 (offset)
                STAL    RD_DiskHandles
                STA     _libcTmp2               ; stash lo16 for the deref
                LDA     3,S                     ; handle hi16 (bank in low byte)
                STAL    RD_DiskHandles+2
                PLX                             ; pop handle lo
                PLX                             ; pop handle hi
                ;    A still = handle hi16; set the DP long-ptr bank byte.
                SEP     #$20
                MX      %10                     ; M=8, X=16
                STA     _libcTmp2+2             ; _libcTmp2+2 = handle bank byte
                REP     #$20
                MX      %00

                ;--- Write the size to the rendezvous (long stores). ---
                LDA     _rdSizeBytes
                STAL    RD_CurDiskSize          ; size lo16
                LDA     _rdSizeBytes+2
                STAL    RD_CurDiskSize+2        ; size hi16

                ;--- Deref the handle -> _rdBufPtr (24-bit base). ---
                JSR     _RamDisk_DerefHandle    ; [_libcTmp2] -> _rdBufPtr

                ;--- _rdBlocks = _rdSizeBytes / 512 (>>9 over the 32-bit value;
                ;    result fits 16 bits for sizes <= 2 MB).  Divide the CLAMPED
                ;    size so the count is correct post-clamp. ---
                LDA     _rdSizeBytes+2          ; hi16 -> shift scratch
                STA     _libcTmp0
                LDA     _rdSizeBytes            ; lo16 in A
                LDX     #9                      ; 16-bit X (set by REP #$30)
@rdc_shr        LSR     _libcTmp0               ; hi16 >> 1; bit0 -> C
                ROR     A                       ; C -> lo16 bit15
                DEX
                BNE     @rdc_shr
                STA     _rdBlocks               ; quotient low 16 = block count

                ;--- RD_FormatFlag = 0 (needs a ProDOS dir; Phase 3 sets $FFFF). ---
                LDA     #0
                STAL    RD_FormatFlag

                ;--- Mark present. ---
                SEP     #$20
                MX      %10
                LDA     #1
                STA     _rdPresent

                PLP
                SEC
                RTS

@rdc_fail       MX      %00                     ; reached via BCS from the JSL
                                                ; (toolbox returns M=16, X=16)
                ; _NewHandle left the (null) result space on the stack; pop it.
                PLX
                PLX
                ; _rdSizeBytes was staged with the attempted size BEFORE the
                ; NewHandle call; re-zero it so the rendezvous + ALL _rd* statics
                ; are left exactly as RamDisk_DetectExisting did - no partial
                ; state leaks for a later reader.  M=16 here, so two 16-bit STAs
                ; clear all 4 bytes.
                LDA     #0
                STA     _rdSizeBytes
                STA     _rdSizeBytes+2
                LDA     #ENOMEM
                PLP
                CLC
                RTS

;==============================================================================
; _RamDisk_DerefHandle - dereference an MM handle to its 24-bit buffer base.
;
; An MM handle is a 4-byte pointer to a master pointer; for a locked|fixed
; block the master pointer is stable and IS the buffer's 24-bit base (see the
; _Sys_MmAlloc convention in src/kernel/syscall.s).  Factored out so Task 1.3
; (RamDisk_Create) can reuse the same deref on a freshly-allocated handle.
;
;   In:   _libcTmp2 = the handle's low 24 bits (DP long pointer).  MX %00.
;   Out:  _rdBufPtr = the 24-bit master pointer (buffer base).
;         MX %00 preserved.  A/Y clobbered.
;==============================================================================
_RamDisk_DerefHandle MX %00
                ; Master pointer lo16 (= buffer base lo16).
                LDA     [_libcTmp2]
                STA     _rdBufPtr
                ; Master pointer bits 16..31; low byte = buffer base bank.
                LDY     #2
                LDA     [_libcTmp2],Y
                SEP     #$20
                MX      %10
                STA     _rdBufPtr+2
                REP     #$20
                MX      %00
                RTS

;==============================================================================
; _RamDisk_BlkAddr - bounds-check a block number and build its 24-bit buffer
;                    address in the DP long-ptr scratch _libcTmp2.
;
; Shared by _RAM_ReadBlock / _RAM_WriteBlock (DRY): both need the identical
; range check + src/dst address computation, only the copy direction differs.
;
;   In:   _blkNum (word) = block number.  MX %00.  DBR = kernel bank (so the
;         _rd* statics read DBR-relative).
;   Out:  C=1 and _libcTmp2 (3 B) = _rdBufPtr + _blkNum*512 (24-bit) when in
;             range; MX %00.
;         C=0 and A=EIO (M=8 on this path) when _blkNum >= _rdBlocks.
;   Clobbers: A, X, Y, _fsTmp0, _fsTmp1, _libcTmp2.  Does NOT touch _fsTmp2
;             (see Blk_Read's clobber set, which preserves it).
;
; The buffer base (_rdBufPtr) may sit in any bank >=$20 and is NOT bank-
; aligned, so a block can straddle a bank boundary; callers therefore copy
; via [_libcTmp2],Y (the index carries into the bank byte).  The 24-bit add
; is done as {bank : 16-bit-offset}: lo16 = base lo16 + offset lo16 (carry
; out), bank = base bank + offset hi-byte + carry.
;==============================================================================
_RamDisk_BlkAddr MX     %00
                ;--- bounds: _blkNum < _rdBlocks ? (16-bit unsigned) ---
                ; The high word must be checked FIRST and separately.  A RAM
                ; disk is never more than a few thousand blocks, so any block
                ; at or above 2^16 is out of range -- but the comparison below
                ; only sees the low word, and would happily accept block
                ; $0001_0007 as block 7 and hand back the wrong bytes.
                LDA    |_blkCurHi
                BNE     @rba_eio
                LDA     _blkNum
                CMP     _rdBlocks
                BCS     @rba_eio                ; blkNum >= count -> out of range

                ;--- offset = _blkNum * 512 = _blkNum << 9.  32-bit value in
                ;    {hi=_fsTmp1 : lo=_fsTmp0}; <=21 bits for <=4096 blocks
                ;    (so _fsTmp1 holds at most $001F). ---
                LDA     _blkNum
                STA     _fsTmp0                 ; offset lo16 = _blkNum
                LDA     #0
                STA     _fsTmp1                 ; offset hi16 = 0
                LDX     #9
@rba_shl        ASL     _fsTmp0                 ; {_fsTmp1:_fsTmp0} <<= 1
                ROL     _fsTmp1
                DEX
                BNE     @rba_shl

                ;--- srcptr (24-bit) = _rdBufPtr + offset, as {bank:offset16}. ---
                ; lo16 = base lo16 + offset lo16 (carry -> bank add)
                LDA     _rdBufPtr               ; base lo16 (lo+mid bytes)
                CLC
                ADC     _fsTmp0                 ; + offset lo16
                STA     _libcTmp2               ; result lo16; C = carry into bank
                ; bank = base bank + offset hi low-byte + carry  (8-bit; C kept)
                SEP     #$20
                MX      %10                     ; M=8 (SEP leaves C intact)
                LDA     _rdBufPtr+2             ; base bank byte
                ADC     _fsTmp1                 ; + offset hi low-byte (+ carry)
                STA     _libcTmp2+2             ; result bank byte
                REP     #$20
                MX      %00
                SEC
                RTS
@rba_eio        SEP     #$20
                MX      %10                     ; EIO is small; M=8 here
                LDA     #EIO
                CLC
                RTS

;==============================================================================
; _RAM_ReadBlock - copy one 512-byte block from the RAM-disk buffer into a
;                  block buffer in the live kernel bank.
;
; Mirrors the _SP_ReadBlock register/DP contract (block.s) so Task 2.2 can
; dispatch RAM-class block reads through the same path as SmartPort ones:
;
;   In:   _devPtr  (DP long ptr) = device record.  UNUSED here - the RAM disk
;             has no SmartPort DIB; its data lives entirely in the _rd*
;             statics.  Accepted for call-site symmetry; never read.
;         _blkNum  (word) = block number.
;         _blkBuf  (word) = dest buffer OFFSET in the live kernel bank.
;   Out:  C=1 ok; C=0 + A=EIO on out-of-range block (_blkNum >= _rdBlocks).
;   Clobbers: A, X, Y, _fsTmp0, _fsTmp1, _libcTmp2.  Does NOT touch _fsTmp2
;             (see Blk_Read's clobber set).  Restores DBR (PHB/PLB)
;             and P (PHP/PLP).
;
; Copy is a DP-indirect-long-indexed loop: LDA [_libcTmp2],Y forms the 24-bit
; effective address as the pointer PLUS Y with carry INTO the bank byte, so a
; block that straddles a bank boundary copies correctly.  MVN can't do this -
; its bank operands are fixed per instruction and the 1 MB buffer spans 16
; banks (not bank-aligned).  (A future fast path could MVN block-at-a-time when
; a block is known not to cross a bank; not built - the loop is always correct.)
;==============================================================================
; The kernel JSLs these two through a patched call site, so they RTL; the
; bodies below keep their RTS exits and stay JSR-able from inside.
_RAM_ReadBlock  MX      %00
                JSR     _RamRdBody
                RTL
_RamRdBody      MX      %00
                MX      %00
                PHP
                PHB
                SEP     #$20
                MX      %10
                LDAL    KFGX_ANCHOR             ; NOT PHK: that is the MODULE's bank
                PHA
                PLB
                REP     #$20
                MX      %00                     ; DBR = live kernel bank: makes the
                                                ;   DBR-relative _rd* reads + the
                                                ;   (_blkBuf),Y dest hit the live
                                                ;   kernel bank regardless of the
                                                ;   caller's DBR.
                REP     #$30
                MX      %00

                JSR     _RamDisk_BlkAddr        ; bounds + _libcTmp2 = src addr
                BCC     @rrb_eio                ; C=0/A=EIO -> out of range
                MX      %00                     ; helper returns C=1 at M=16

                ;--- copy 512 bytes: buffer[_libcTmp2] -> destbank[_blkBuf] ---
                ; DBR moves to the caller's buffer bank HERE and not at entry
                ; (UFS 1.3c).  It has to stay on the kernel bank above, because
                ; _RamDisk_BlkAddr reads the _rd* statics DBR-relative; only
                ; the (_blkBuf),Y store below takes its bank from DBR.
                ; [_libcTmp2],Y is indirect LONG and carries its own bank, so
                ; the source side is unaffected.
                SEP     #$20
                MX      %10
                LDA    |_blkCurBufBank
                BEQ     @rrb_dstK
                PHA
                PLB                             ; DBR = caller's buffer bank
@rrb_dstK       REP     #$30
                MX      %00
                LDY     #0
@rrb_cp         LDA     [_libcTmp2],Y           ; word from RAM buffer (bank-cross safe)
                STA     (_blkBuf),Y             ; word to the dest bank (DBR)
                INY
                INY
                CPY     #512
                BCC     @rrb_cp

                PLB
                PLP
                SEC
                RTS
@rrb_eio        ; helper left A=EIO at M=8.
                PLB
                PLP
                CLC
                RTS

;==============================================================================
; _RAM_WriteBlock - copy one 512-byte block from a block buffer in the live
;                   kernel bank into the RAM-disk buffer.  Exact reverse of
;                   _RAM_ReadBlock (same contract, same bounds/addr helper);
;                   only the copy direction is flipped.
;
;   In:   _devPtr  (DP long ptr) = device record.  UNUSED (see _RAM_ReadBlock).
;         _blkNum  (word) = block number.
;         _blkBuf  (word) = source buffer OFFSET in the live kernel bank.
;   Out:  C=1 ok; C=0 + A=EIO on out-of-range block.
;   Clobbers / preserves: identical to _RAM_ReadBlock (A,X,Y,_fsTmp0,_fsTmp1,
;             _libcTmp2 clobbered; _fsTmp2, DBR, P preserved).
;==============================================================================
_RAM_WriteBlock MX      %00
                JSR     _RamWrBody
                RTL
_RamWrBody      MX      %00
                PHP
                PHB
                SEP     #$20
                MX      %10
                LDAL    KFGX_ANCHOR             ; NOT PHK (see above)
                PHA
                PLB
                REP     #$20
                MX      %00                     ; DBR = live kernel bank
                REP     #$30
                MX      %00

                JSR     _RamDisk_BlkAddr        ; bounds + _libcTmp2 = dst addr
                BCC     @rwb_eio
                MX      %00                     ; helper returns C=1 at M=16

                ;--- copy 512 bytes: srcbank[_blkBuf] -> buffer[_libcTmp2].
                ;    P3.3-iii-B: source bank = kernel bank, or the F2 pool's
                ;    heap bank when _blkSrcPool is set (Blk_Write clears it).
                ;    _fsTmp0/+1/+2 build the long src ptr — free here: Blk_Write
                ;    saved the caller's _fsTmp0/1 at entry. ---
                LDA     _blkBuf
                STA     _fsTmp0                 ; src offset (lo word)
                SEP     #$20
                MX      %10
                LDA    |_blkSrcPool
                BEQ     @rwb_srcKern
                LDA    |_kBlkTabBase+2          ; pool bank
                BRA     @rwb_srcSet
@rwb_srcKern    ; ...or the bank the caller named (UFS 1.3c).  After the pool
                ; arm, for the reason given at @spwb_srcKern in block.s: a pool
                ; source is the block layer's own substitution and outranks it.
                LDA    |_blkCurBufBank
                BNE     @rwb_srcSet
                PHB                             ; DBR = kernel bank (set above)
                PLA
@rwb_srcSet     STA     _fsTmp0+2               ; src bank
                REP     #$20
                MX      %00
                LDY     #0
@rwb_cp         LDA     [_fsTmp0],Y             ; word from src bank (long)
                STA     [_libcTmp2],Y           ; word to RAM buffer (bank-cross safe)
                INY
                INY
                CPY     #512
                BCC     @rwb_cp

                PLB
                PLP
                SEC
                RTS
@rwb_eio        ; helper left A=EIO at M=8.
                PLB
                PLP
                CLC
                RTS

;==============================================================================
; END ramdisk.s
;==============================================================================
ramdisk_end     EQU     *

; Placement guards (tools/gen_modplace.py writes MODP_* into modplace.s).
                ERR     ramdisk_hdr-MODP_ORG
                ERR     ramdisk_end-MODP_ORG+ramdisk_bss/MODP_LIMIT
