;==============================================================================
; rawdisk.s - /dev/rsd0 .. /dev/rsd7: the BLOCK DRIVER'S CHARACTER FACE.
; apple/fgx#330.
;
; THIS IS NOT A SECOND DRIVER.  In BSD a raw disk is the SAME driver entered
; through the other switch.  4.3BSD-Reno's hp300 conf.c gives `sd' one row in
; each: bdevsw[4] is `sdopen, nulldev, sdstrategy, sdioctl, sddump, sdsize' and
; cdevsw[8] is `sdopen, nulldev, sdread, sdwrite, sdioctl, ..., seltrue, nodev,
; sdstrategy' -- same open, same ioctl, same strategy, and `struct cdevsw'
; (sys/conf.h:47) carries d_strategy as a member so the character entry can
; name the block one.  2.11BSD's pdp/conf.c is the same arrangement with the
; generic `rawrw' in place of a per-driver read.  Both are compiled into the
; kernel by config(8) from conf/files; neither tree has a loadable driver.
;
; So this file sits beside block.s, in the core bank, and its units are
; registered by the boot sequence right after _Chardev_InitBuiltins -- with
; /dev/null and the console, not from modload.conf, which docs/modules.md
; defines as "everything else, loaded from disk at runtime once the FS is up".
; A disk driver cannot be loaded from disk.
;
; WHAT THE RAW FACE IS FOR.  fsck(8) stats /dev/rsd<n> before it will check
; /dev/sd<n> (blockcheck, fsck.c:334) and reads through it for every filesystem
; that is not the root; for the root it takes the BLOCK device back
; (`raw = unrawname(name)') so its transfers share the buffer cache the kernel
; is writing through.  The bypass is the point of the character face: a raw
; read goes to the platter, not to a cache another writer owns.
;
;------------------------------------------------------------------------------
; THE TRANSFER, which is Reno's `physio' with FGX's two differences.
;
; Reno: rawread/rawwrite -> physio (kern/vm_swp.c:196) sets
; `bp->b_blkno = btodb(uio->uio_offset)', clamps with minphys, and calls the
; driver's strategy with B_PHYS|B_RAW so nothing files the buffer in the cache.
; Here: the offset becomes a block number the same way, Blk_Read/Blk_Write move
; the block, and uiomove moves the bytes.  Blk_* never consults the vfs_bio
; cache for a VFSOWNED device and drops what it writes, so the bypass holds.
;
; ONE STAGING SECTOR, NOT ONE PER UNIT, and the difference is not thrift.
; Reno hands physio `&sdbuf[unit]' rather than NULL (sd.c:677) because physio
; SLEEPS waiting for B_DONE (vm_swp.c:249-250), and B_BUSY/B_WANTED on that
; per-unit buffer is what keeps a second raw transfer out of it across the
; sleep.  FGX has no such window: bio_strategy performs the transfer and calls
; biodone BEFORE RETURNING, kc_blkio is sleep-free, and uiomove is a banked
; copy with no fault path -- so nothing can run between this routine's blocks.
; That is the same invariant the legacy FS layer's shared singletons rest on,
; and this file is listed in check_fs_sleep_invariant.py's FS_LAYER so the day
; Blk_* learns to block the gate says so here.
;
; THE CLAMP IS THE TYPE.  Reno's minphys cuts a transfer to MAXPHYS, 64 KB on
; hp300 (machparam.h:56).  uio_resid is `unsigned short', so no request can
; exceed 65535 bytes and there is nothing to clamp.
;
;------------------------------------------------------------------------------
; PARTIAL BLOCKS: READS YES, WRITES NO -- AND THAT IS A PROPERTY OF THE BLOCK
; LAYER, NOT OF THIS FILE.
;
; A read at any offset and any length works, because a whole 512-byte sector is
; staged anyway and uiomove takes the bytes the uio asked for.
;
; A WRITE whose offset or length is not a multiple of 512 answers EINVAL.
; Reno's `sd' would instead route it to sdlblkstrat, a read-modify-write -- but
; that exists for a DEVICE-GEOMETRY mismatch, `sc_blksize != DEV_BSIZE'
; (sd.c:488), where the drive's own sector is bigger than 512.  FGX has no
; mismatch to bridge: every spindle is reached through SmartPort firmware,
; which presents 512-byte blocks whatever the drive is, and the disk state
; (DSS_*, include/fs.s) carries no block size for that reason.  sdlblkstrat
; also allocates with M_WAITOK and therefore sleeps, which is the invariant
; above.
;
; Nothing in the tree can reach the refusal: fsck is the only raw-device
; writer, and its own DEV_BSIZE is FS_BLKSIZE = 1024 (fsck/ufsdisk.h:58-65), so
; every bwrite is 1024-aligned and a multiple of 1024.  EINVAL is also the
; right failure rather than a rounded write, whose corruption would land in the
; 512 bytes beside the one fsck is repairing.
;
; apple/fgx#397 records what changes when a driver that reads capacity itself
; ever reports something other than 512.
;
;------------------------------------------------------------------------------
; NO d_strategy SLOT IN CharDev_Ops, deliberately.  Reno reads
; cdevsw[].d_strategy in exactly two places -- rawread and rawwrite,
; kern/vm_swp.c:334,342 -- and exactly one hp300 row uses those: the swap
; device, which has no driver of its own to write a wrapper in.  Every disk
; names its strategy directly in C.  FGX has ONE block driver reached by device
; index, so this file names Blk_Read/Blk_Write outright and a lookup slot would
; be locked ABI with no consumer.  If a second raw device ever wants a shared
; generic routine, that is the moment the slot earns its place.
;==============================================================================

RSD_UNITS       EQU     8               ; one per ROOT_BLKUNITS node
RSD_SECSIZE     EQU     512
RSD_SECMASK     EQU     511

;------------------------------------------------------------------------------
; _Rsd_UnitOk - is this minor a disk that answers?
;
; THE NODE NAMES AN ADDRESS ON THE BUS and is not a claim that something is
; there -- gen.py's ROOT_BLKUNITS comment makes the same point for the block
; nodes, quoting 2.11BSD's MAKEDEV, and upstream answers EIO rather than ENOENT
; for a unit with nothing behind it.  So does this.
;
; THE POINTER IS `_devPtr', THE BLOCK LAYER`S OWN.  `[dp],Y' is the only way
; to reach a record in another bank, and it needs the pointer in the DIRECT
; PAGE -- a bank-$02 static cannot serve, which is what the first cut of this
; file tried ("Operand address `[_devPtr],Y' is located outside of the
; Direct Page").  _devPtr is "long ptr to current device record" (dpmap.s:94)
; and Blk_Read recomputes it from _fsCurDevIdx on every call, so it is scratch
; to both of us and there is no third cell to justify.
;
; In:  Y = unit.  MX %00.   Out: C=1 and _devPtr resolved, or C=0.
;      Y preserved.  A, X clobbered.
;------------------------------------------------------------------------------
_Rsd_UnitOk     MX      %00
                CPY     #RSD_UNITS
                BCS     @ruo_no
                TYA
                ASL                             ; * DEV_SIZE (16)
                ASL
                ASL
                ASL
                CLC
                ADC     dev_table_ptr
                STA     _devPtr
                SEP     #$20
                MX      %10
                LDA     dev_table_ptr+2
                ADC     #0                      ; + carry from the 16-bit add
                STA     _devPtr+2
                PHY
                LDY     #DEV_Class
                LDA     [_devPtr],Y
                CMP     #DEV_CLASS_DISK
                BNE     @ruo_noPop
                LDY     #DEV_Flags
                LDA     [_devPtr],Y
                AND     #DEV_FLAG_ONLINE
                BEQ     @ruo_noPop
                PLY
                REP     #$30
                MX      %00
                SEC
                RTS
@ruo_noPop      PLY
                REP     #$30
                MX      %00
@ruo_no         CLC
                RTS

;------------------------------------------------------------------------------
; _Rsd_Size - the unit's block count into _rsdNBlk (32-bit).
;
; Reno's `sizes[part].nblocks', which its strategy range-checks against.  FGX's
; is DSS_BlkCount, filled from Blk_Status at attach.
;
; In:  _devPtr resolved.  MX %00.  Out: _rsdNBlk.  A, X, Y clobbered.
;------------------------------------------------------------------------------
_Rsd_Size       MX      %00
                LDY     #DEV_StateLo
                LDA     [_devPtr],Y
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDY     #DEV_StateBank
                LDA     [_devPtr],Y
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                ; DSS_BlkCount IS FOUR BYTES, least significant first, so two
                ; 16-bit loads take the whole of it.  It used to be two, and the
                ; dropped byte is the reason this driver could not read a large
                ; spindle: SmartPort's standard STATUS returns three
                ; (Firmware Reference p.123), so a 131,072-sector volume stored
                ; its low sixteen bits -- zero -- and _Rsd_Rw range-checked every
                ; request against an empty device.  apple/fgx#407.
                LDY     #DSS_BlkCount
                LDA     [_libcTmp2],Y
                STA    |_rsdNBlk
                LDY     #DSS_BlkCount+2
                LDA     [_libcTmp2],Y
                STA    |_rsdNBlk+2
                RTS

;------------------------------------------------------------------------------
; _Rsd_Split - the CURRENT uio offset into a block number and a byte offset
; inside it.  Reno's `bp->b_blkno = btodb(uio->uio_offset)', plus the remainder
; it has no use for because physio hands whole iovecs to a strategy that moves
; bytes; this one stages a sector and has to know where in it to start.
;
; In:  _libcTmp2 = far ptr at the uio.  MX %00.
; Out: _rsdBn (32-bit), _rsdBoff.  A, X, Y clobbered.
;------------------------------------------------------------------------------
_Rsd_Split      MX      %00
                LDY     #UIO_OFFSET
                LDA     [_libcTmp2],Y
                STA    |_rsdBn
                AND     #RSD_SECMASK
                STA    |_rsdBoff
                LDY     #UIO_OFFSET+2
                LDA     [_libcTmp2],Y
                STA    |_rsdBn+2
                LDX     #9                      ; >> 9 == / RSD_SECSIZE
@rsp_sh         LSR    |_rsdBn+2
                ROR    |_rsdBn
                DEX
                BNE     @rsp_sh
                RTS

;------------------------------------------------------------------------------
; _Rsd_Uio - one uiomove(cp, n, uio) out of this bank.
;
; The frame is ten bytes -- cp (4) + n (2) + uio (4) -- pushed LAST argument
; first so they land arg1-lowest the way fcc reads them, exactly as pty.mod`s
; `_Pty_Uio1' builds the same call.  _FarSh_Uiomove forwards it to vfs.mod,
; which is where uiomove lives; there is no address to bake because that bank
; is loadable, and the core resolved the entry once at boot
; (`_Tty_LoadVfsPtr', far_shims.s).
;
; THE SHIM IS REACHED BY A PILE CALL AND NOT BY `JSL', even though it sits in
; this very bank.  The assembler bakes its own ORG bank ($02) into a long
; operand, and the kernel runs relocated -- there is no relocation pass over
; core-bank code, which is why the only other long calls here name bank zero`s
; gateway cells or the toolbox.  `PHK' supplies the LIVE bank.  KTTY_STUB2
; (include/kernelc.s) states the same rule for the tty bank, and the pile call
; leaves a three-byte return address exactly as the JSL would, so the shim`s
; own frame arithmetic is unchanged.
;
; D BECOMES FGX_DP_KERNELC FOR THE CALL, and only AFTER the arguments are
; pushed: `_rsdUio` is read through absolute addressing but `_libcTmp2` is not,
; and uiomove is fcc code that wants its own register file.  The shim does not
; switch D -- kc_uiomove`s header says so in as many words -- so this end does.
;
; THE CALLER DROPS THE FRAME.  The shim drops only the ten bytes IT re-pushed;
; kc_uiomove (tty/kc_sys.s:190) does the same `ADC #10' afterwards for the same
; reason.
;
; In:  A = cp offset in THIS bank, Y = n, _rsdUio = the uio far pointer.
; Out: A = uiomove`s errno, 0 on success.  X, Y clobbered.
;------------------------------------------------------------------------------
_Rsd_Uio        MX      %00
                STA    |_rsdTmp2               ; cp offset
                STY    |_rsdCount              ; n
                PHD                             ; the kernel page, for the exit
                LDA    |_rsdUio+2
                AND     #$00FF
                PHA                             ; uio bank
                LDA    |_rsdUio
                PHA                             ; uio offset
                LDA    |_rsdCount
                PHA                             ; n
                SEP     #$20
                MX      %10
                PHB
                PLA                             ; A.lo = this bank, where cp is
                REP     #$30
                MX      %00
                AND     #$00FF
                PHA                             ; cp bank
                LDA    |_rsdTmp2
                PHA                             ; cp offset
                LDA     #FGX_DP_KERNELC
                TCD
                PHK                             ; @rsd_uioRet is in THIS bank
                PEA     @rsd_uioRet-1
                PHK                             ; ...and so is the shim
                PEA     _FarSh_Uiomove-1
                RTL                             ; PILECALL
@rsd_uioRet     TAY                             ; park the errno
                TSC
                CLC
                ADC     #10                     ; drop the frame we built
                TCS
                PLD                             ; the kernel page back
                TYA
                RTS

;------------------------------------------------------------------------------
; _Rsd_LoadUio - `_libcTmp2' back to the uio, from the copy `_rsdUio' holds.
;
; EVERY ROUTINE THIS DRIVER CALLS TAKES `_libcTmp2' AWAY.  _Rsd_Size uses it
; for the device-state pointer, and Blk_Read and Blk_Write do not name it in
; their clobber set either, so the far pointer is reloaded before each use
; rather than carried across a call.
;
; MX %00 in and out.  A clobbered.
;------------------------------------------------------------------------------
_Rsd_LoadUio    MX      %00
                LDA    |_rsdUio
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA    |_rsdUio+2
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Rsd_Rw - the transfer.  FGX`s `physio'.
;
; In:  Y = unit, _libcTmp2 = far ptr at the uio, _rsdRw = UIO_READ/UIO_WRITE.
; Out: A = errno, 0 on success.
;------------------------------------------------------------------------------
_Rsd_Rw         MX      %00
                ; PARK THE uio FIRST.  It is the only copy: `_libcTmp2' is
                ; taken away by the first call below, and _Rsd_LoadUio is what
                ; every later use of the far pointer goes through.
                LDA     _libcTmp2
                STA    |_rsdUio
                SEP     #$20
                MX      %10
                LDA     _libcTmp2+2
                STA    |_rsdUio+2
                REP     #$30
                MX      %00
                JSR     _Rsd_UnitOk
                BCS     @rw_have
                LDA     #EIO                    ; the node names a bus address;
                RTS                             ;   nothing answers there
@rw_have        STY    |_rsdUnit
                JSR     _Rsd_Size
                JSR     _Rsd_LoadUio
                LDY     #UIO_RESID
                LDA     [_libcTmp2],Y
                STA    |_rsdResid
                BNE     @rw_range
                LDA     #0                      ; nothing asked for
                RTS

                ; --- THE RANGE CHECK IS ON THE WHOLE REQUEST, ONCE, which is
                ; where Reno makes it: physio hands a strategy one clamped
                ; chunk and rdstrategy tests `bn + sz > nblocks' against it
                ; (rd.c:588).  uio_resid is 16-bit so there is only ever one
                ; chunk here. ---
@rw_range       JSR     _Rsd_Split
                ; sz = howmany(boff + resid, RSD_SECSIZE), computed 32-bit:
                ; boff + resid + 511 reaches 66557 and does not fit a word.
                LDA    |_rsdBoff
                CLC
                ADC    |_rsdResid
                STA    |_rsdTmp
                LDA     #0
                ADC     #0
                STA    |_rsdTmp+2
                LDA    |_rsdTmp
                CLC
                ADC     #RSD_SECMASK
                STA    |_rsdTmp
                LDA    |_rsdTmp+2
                ADC     #0
                STA    |_rsdTmp+2
                LDX     #9
@rw_shs         LSR    |_rsdTmp+2
                ROR    |_rsdTmp
                DEX
                BNE     @rw_shs
                ; end = bn + sz
                LDA    |_rsdBn
                CLC
                ADC    |_rsdTmp
                STA    |_rsdEnd
                LDA    |_rsdBn+2
                ADC     #0
                STA    |_rsdEnd+2
                ; end > nblocks ?
                LDA    |_rsdEnd+2
                CMP    |_rsdNBlk+2
                BCC     @rw_inRange
                BNE     @rw_past
                LDA    |_rsdEnd
                CMP    |_rsdNBlk
                BCC     @rw_inRange
                BEQ     @rw_inRange
@rw_past        ; OUT OF RANGE.  Reno answers EOF only when the transfer STARTS
                ; exactly at the end of the device -- `if (bn == nblocks) {
                ; bp->b_resid = bp->b_bcount; goto done; }' -- and EINVAL for
                ; everything else, including a request that merely runs off the
                ; end (rd.c:588-594, sd.c the same).  A short read is not
                ; offered, and that is upstream`s contract rather than an
                ; omission here.
                LDA    |_rsdBn+2
                CMP    |_rsdNBlk+2
                BNE     @rw_einval
                LDA    |_rsdBn
                CMP    |_rsdNBlk
                BNE     @rw_einval
                LDA     #0                      ; end of device: zero bytes,
                RTS                             ;   success.  That IS EOF.
@rw_einval      LDA     #EINVAL
                RTS

@rw_inRange     ; --- A WRITE MUST BE WHOLE BLOCKS.  See the head of this file:
                ; the block layer is 512-granular through SmartPort, so there is
                ; no native sector to bridge to and nothing that can reach this
                ; refusal.  apple/fgx#397 is what changes it. ---
                LDA    |_rsdRw
                CMP     #UIO_WRITE
                BNE     @rw_loop
                LDA    |_rsdBoff
                BNE     @rw_einval
                LDA    |_rsdResid
                AND     #RSD_SECMASK
                BNE     @rw_einval

@rw_loop        JSR     _Rsd_LoadUio
                LDY     #UIO_RESID
                LDA     [_libcTmp2],Y
                BNE     @rw_more
                LDA     #0                      ; uiomove drained it: done
                RTS
@rw_more        STA    |_rsdResid
                JSR     _Rsd_Split              ; uiomove advanced the cursor
                ; n = MIN(RSD_SECSIZE - boff, resid)
                LDA     #RSD_SECSIZE
                SEC
                SBC    |_rsdBoff
                CMP    |_rsdResid
                BCC     @rw_haveN
                LDA    |_rsdResid
@rw_haveN       STA    |_rsdN
                LDA    |_rsdRw
                CMP     #UIO_WRITE
                BEQ     @rw_write

                ; --- READ: the sector, then the bytes out of it -------------
                JSR     _Rsd_Setup
                JSR     Blk_Read
                BCC     @rw_ioerr
                LDA     #_rsdSector
                CLC
                ADC    |_rsdBoff
                LDY    |_rsdN
                JSR     _Rsd_Uio
                CMP     #0
                BNE     @rw_uioerr
                BRA     @rw_loop

                ; --- WRITE: the bytes into the sector, then the sector.  The
                ; block parameters are set AFTER the uiomove, which crosses
                ; into another bank and is not asked to preserve them. -------
@rw_write       LDA     #_rsdSector
                LDY    |_rsdN
                JSR     _Rsd_Uio
                CMP     #0
                BNE     @rw_uioerr
                JSR     _Rsd_Setup
                JSR     Blk_Write
                BCC     @rw_ioerr
                BRA     @rw_loop

@rw_ioerr       AND     #$00FF                  ; Blk_* left its errno in A
                RTS
@rw_uioerr      RTS                             ; uiomove`s errno, already in A

;------------------------------------------------------------------------------
; _Rsd_Setup - the block layer`s parameters for one sector.
;
; `_blkBufBank' is left alone: zero means the live kernel bank, which is where
; `_rsdSector' is, and the cell self-clears at every Blk_* entry so nothing can
; inherit a stale one (block.s:363-368).
;
; In:  _rsdBn, _rsdUnit.  MX %00.  Out: DP set for Blk_Read/Blk_Write.
;------------------------------------------------------------------------------
_Rsd_Setup      MX      %00
                LDA    |_rsdBn
                STA     _blkNum
                LDA    |_rsdBn+2
                STA     _blkNumHi
                LDA     #_rsdSector
                STA     _blkBuf
                SEP     #$20
                MX      %10
                LDA    |_rsdUnit
                STA     _fsCurDevIdx
                REP     #$30
                MX      %00
                RTS

;==============================================================================
; The CharDev_Ops entry points.  Conventions: MX %00 in and out, DBR = this
; bank (the FOP thunk wraps the cross-bank call), C=1 ok / C=0 + A = errno.
;==============================================================================

;------------------------------------------------------------------------------
; _Rsd_Open / _Rsd_Close - Reno gives the character row the BLOCK driver`s own
; open and close (`sdopen, nulldev' in both switches).  FGX`s block open is the
; device table`s online test, so that is what this is; close has nothing to
; undo, which is Reno`s `nulldev'.
;------------------------------------------------------------------------------
_Rsd_Open       MX      %00
                JSR     _Rsd_UnitOk
                BCS     @rop_ok
                LDA     #EIO
                CLC
                RTL
@rop_ok         SEC
                RTL

_Rsd_Close      MX      %00
                SEC
                RTL

;------------------------------------------------------------------------------
; _Rsd_Getc / _Rsd_Putc - FGX`s per-byte primitive, which a raw disk does not
; have.  Upstream has none either: cdevsw`s read and write for a disk are
; rawread/rawwrite or the driver`s own physio wrapper, and there is no
; byte-at-a-time entry anywhere in the chain.  The bulk slots below are filled,
; so spec_chread never falls through to these; a caller on the registry road
; gets EIO rather than a sector taken apart one byte at a time.
;------------------------------------------------------------------------------
_Rsd_Getc       MX      %00
                LDA     #EIO
                CLC
                RTL

_Rsd_Putc       MX      %00
                LDA     #EIO
                CLC
                RTL

;------------------------------------------------------------------------------
; _Rsd_Ioctl - EINVAL, which is what Reno`s disk ioctl answers on the raw row
; (`rdioctl' returns EINVAL, rd.c:985).  The character row carries the BLOCK
; driver`s ioctl upstream; FGX has no block ioctl at all, so there is one
; answer rather than two.
;------------------------------------------------------------------------------
_Rsd_Ioctl      MX      %00
                LDA     #EINVAL
                CLC
                RTL

;------------------------------------------------------------------------------
; _Rsd_Poll - always ready, both ways.  Reno`s `seltrue' in the d_select
; column of every disk row.
;------------------------------------------------------------------------------
_Rsd_Poll       MX      %00
                LDA     #POLLIN+POLLOUT
                SEC
                RTL

;------------------------------------------------------------------------------
; _Rsd_DRead / _Rsd_DWrite - cdevsw`s d_read and d_write.  Reno`s sdread and
; sdwrite are one line each, `physio(sdstrategy, &sdbuf[unit], dev, B_READ,
; minphys, uio)'; these are the same line with FGX`s transfer behind it.
;
; In:  Y = minor.  Frame: 9,S uio offset, 11,S uio bank, 13,S flag.
; Out: C=1 success, or C=0 + A = errno.
;------------------------------------------------------------------------------
_Rsd_DRead      MX      %00
                LDX     #UIO_READ
                JSR     @rsd_stage
                BCC     @rsd_err
                JSR     _Rsd_Rw
                BRA     @rsd_done

_Rsd_DWrite     MX      %00
                LDX     #UIO_WRITE
                JSR     @rsd_stage
                BCC     @rsd_err
                JSR     _Rsd_Rw
@rsd_done       CMP     #0
                BNE     @rsd_err
                SEC
                RTL
@rsd_err        CLC
                RTL

;------------------------------------------------------------------------------
; @rsd_stage - the uio far pointer out of the frame, and the direction asserted
; against it.  ttyv.s`s `@tv_stage' is the same routine for the same reason and
; the offsets are its: this is entered by JSR and pushes Y, so the frame`s three
; words sit two deeper than the op saw them.
;
; THE DIRECTION IS ASSERTED, NOT ASSUMED.  Get the offsets wrong and
; `_libcTmp2' is a wild pointer, which is unlikely to read as the value X names
; -- and X carrying UIO_WRITE on the write op is what makes the test
; discriminate, UIO_READ being zero.
;
; In:  X = UIO_READ or UIO_WRITE, Y = minor.  MX %00.
; Out: C=1 staged, Y preserved.  C=0 + A = EINVAL otherwise.
;------------------------------------------------------------------------------
@rsd_stage      PHY
                STX    |_rsdRw
                LDA     13,S                    ; uio offset
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     15,S                    ; uio bank
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                LDY     #UIO_RW
                TXA
                CMP     [_libcTmp2],Y
                BNE     @rsds_bad
                PLY
                SEC
                RTS
@rsds_bad       PLY
                LDA     #EINVAL
                CLC
                RTS

;------------------------------------------------------------------------------
; _RawDiskChardev_Ops - the vtable.  Order MUST match COPS_* in
; include/chardev.s.
;
; THE BULK SLOTS ARE FILLED AND THE PER-BYTE PAIR REFUSES, which is this
; driver`s declaration of what it is: a device that moves sectors, and has no
; meaningful answer to "give me one byte".
;------------------------------------------------------------------------------
_RawDiskChardev_Ops ENT
                DFB     <_Rsd_Open,>_Rsd_Open,^_Rsd_Open
                DFB     <_Rsd_Close,>_Rsd_Close,^_Rsd_Close
                DFB     <_Rsd_Getc,>_Rsd_Getc,^_Rsd_Getc
                DFB     <_Rsd_Putc,>_Rsd_Putc,^_Rsd_Putc
                DFB     <_Rsd_Ioctl,>_Rsd_Ioctl,^_Rsd_Ioctl
                DFB     <_Rsd_Poll,>_Rsd_Poll,^_Rsd_Poll
                DFB     <_Rsd_DRead,>_Rsd_DRead,^_Rsd_DRead     ; d_read
                DFB     <_Rsd_DWrite,>_Rsd_DWrite,^_Rsd_DWrite  ; d_write
                DFB     0,0,0                                   ; d_stop: nothing
                                                                ;   in flight

; The name, with its unit digit patched per registration.  One buffer rather
; than eight strings: _Chardev_RegisterInternal copies the name into the
; table`s own record, so the buffer is dead the moment it returns.
_RsdName        ASC     'rsd0',00

;------------------------------------------------------------------------------
; _RawDisk_Register - /dev/rsd0 .. /dev/rsd<RSD_UNITS-1>.
;
; ONE NODE PER UNIT THE BUS CAN CARRY, ATTACHED OR NOT, which is MAKEDEV`s
; model and the same rule gen.py states for the block nodes: the node names an
; address, not a claim that something answers there.  So registration does not
; consult the device table -- open does, and answers EIO.
;
; A refused registration (the table is full) is not fatal and not logged: the
; node it would have served then behaves exactly as a node for an absent unit
; does, which is the case above.
;
; In:  called from the boot sequence with DBR = this bank.  MX %00.
;------------------------------------------------------------------------------
_RawDisk_Register ENT
                MX      %00
                STZ    |_rsdRegU
@rdr_loop       LDA    |_rsdRegU
                CLC
                ADC     #'0'
                SEP     #$20
                MX      %10
                STA    |_RsdName+3
                REP     #$30
                MX      %00
                LDX     #_RsdName
                LDA     #_RawDiskChardev_Ops
                LDY    |_rsdRegU
                JSR     _Chardev_RegisterInternal
                LDA    |_rsdRegU
                INC
                STA    |_rsdRegU
                CMP     #RSD_UNITS
                BCC     @rdr_loop
                RTS
