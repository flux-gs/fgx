;==============================================================================
; probe_dev.s (shared) - find a disk that is SAFE TO WRITE TO, run the
; including module's on-disk probe against it, and report the verdict.
;
; SHARED BY vfs.mod AND ufs.mod, and shared for the same reason kc_sys.s is:
; when UFS moved into a module of its own (apple/fgx#169) both sides needed
; this identical ~200 lines, and two copies of a device scan with this much
; history in it would be two copies to fix.
;
; The scan is the part with the history.  Reading it as boilerplate is the
; mistake: index 0 is the boot disk and writing there destroys the running
; system; a class byte alone is not proof a device exists, and an earlier
; version matched a stray one in unallocated memory and did I/O to a slot that
; was not there.
;
;------------------------------------------------------------------------------
; THE INCLUDING MODULE SUPPLIES ITS OWN IDENTITY, as three symbols it must EQU
; or define BEFORE the PUT:
;
;   PROBE_ENTRY    the C entry point, `int probe(dev, fsblk)`, returning 0 for
;                  pass and a distinct nonzero code per failing property
;   PROBE_MSGOK    the pass string
;   PROBE_MSGBAD   the failure prefix; the case number is printed after it
;   PROBE_MSGSKIP  what to say when no scratch volume is attached at all
;
; Parameterised this way rather than with a `DO VFSPROBE` inside, because the
; two gates are alternatives only by BANK PRESSURE and not by construction.  A
; conditional here would silently compile vfs.mod against ufs.mod's C entry
; point the day both fit at once.
;==============================================================================


;------------------------------------------------------------------------------
; _Probe_Drive - drive whichever on-disk probe is gated in.
;
; At VFSPROBE it proves the buffer cache is WIRED, not merely present.  At
; UFSPROBE it proves the filesystem reader and the allocators agree with
; tools/fgxfs.py about the volume.  Everything down to the JMP is shared: both
; need a device that is SAFE TO WRITE TO, and finding one is the part with the
; history.
;
; Three things landed with no on-target coverage: the block layer's 24-bit
; buffer address, the per-device cache bypass, and bio_strategy's split of one
; filesystem block into two device transfers.  Each fails silently -- bytes in
; the wrong bank, in two caches, or in the wrong order, and the machine still
; boots.  vfs_probe drives all three from bread() down to a device block and
; back up through a RAW read, so the oracle is the layer below rather than the
; cache's own flags.
;
; IT WRITES, which is why it has a build gate of its own: the blocks it writes
; are somebody's, and it belongs to a development kernel rather than a shipping
; one.  The target is identified by its 2.11BSD SUPERBLOCK before anything is
; written, never by its device index -- the emulator's numbering is not a
; promise about which image answers where.
;
; THE DEVICE TABLE IS REACHABLE FROM A MODULE, and that is the whole reason
; this could move here rather than stay behind in the core bank.  `dev_table_ptr`
; and `_devPtr` are DIRECT PAGE cells, so the scan below needs the kernel's
; direct page and NOT its data bank -- and the kernel's direct page is exactly
; what mod_init captured.  Had either been a core-bank static instead, this
; routine would have had to bake a kernel address and the module could not have
; carried it.
;------------------------------------------------------------------------------
_probeDev    DS      2       ; MODBANK-OK: mod_init only (DBR=ours).  Which
                                ;   device the probe chose.
_probeCand   DS      2       ; MODBANK-OK: mod_init only (DBR=ours).  How many
                                ;   ONLINE disks it examined.
; The painted window used to MEASURE how far down FGX_STK_KTASKS the probe's
; chain reaches (apple/fgx#172).
;
; IT MUST SIT BELOW BOOT'S OWN LIVE FRAMES.  Since main.s moved boot off page 1,
; this routine runs ON that stack rather than switching to it -- boot enters
; here around $EC9F, having used about 96 bytes -- so a window running to the
; top of the region would paint over the frames this routine returns through.
; Three pages ending at $EBFF leave 160 bytes of clearance and still cover the
; 437 bytes the chain measured, which reaches about $EAEA.
;
; The region holds no task at Mod_LoadConf time, and Task_AllocKernStack
; repaints and re-canaries every slice at spawn, so this window's paint cannot
; outlive boot.  main.s now paints the WHOLE arena on the way in, which measures
; the same chain in every config rather than only where ufsprobe.mod is built
; in; this narrower window stays because it reports from inside the probe.
VFP_PAINT       EQU     768
VFP_PAINTBASE   EQU     FGX_STK_KTASKS+{{CFG_KERNEL_NPROC+1}*FGX_KSTK_SIZE}-256-VFP_PAINT

_probeMark   DS      2       ; MODBANK-OK: mod_init only (DBR=ours).

_Probe_Drive      MX      %00
                PHP
                REP     #$30
                MX      %00

                ;--- THE PROBE GETS ITS OWN STACK, and it is not a workaround
                ; for apple/fgx#172 so much as an admission of what a probe is.
                ;
                ; mod_init runs on FGX_STK_KERNEL, the 256-byte static boot
                ; stack, and UFS 1.11a's chain -- ufs_probe -> ufs_root -> iget
                ; -> the cross-module getnewvnode shim -> getnewvnode -> bread
                ; -> bio_strategy -- fits it with under 32 bytes to spare
                ; (measured: ufs_probe frame 40 passes, 72 hangs).  Section
                ; 10c's extra call level took it over, and overflowing page 1
                ; walks into page ZERO -- fcc's register file and the kernel
                ; direct page -- so the machine wanders instead of failing.
                ;
                ; THE SHIPPING STACK IS DELIBERATELY NOT TOUCHED.  Four sites
                ; (block.s, clock.s x2, boot_console.s) set S to $01FF and call
                ; it "firmware-safe" -- and _blkSmartJump's header now states
                ; the invariant all four rely on, which this routine is the one
                ; caller in the tree that has to honour explicitly
                ; (apple/fgx#185).  So how big FGX_STK_KERNEL may be is a
                ; firmware-ABI question and not this file's to answer.  What IS
                ; this file's: a self-test gated off in every shipping kernel
                ; has no business being the thing that decides it.
                ;
                ; FGX_STK_KTASKS holds no task at Mod_LoadConf time -- there is
                ; no task at all yet -- so its top is free for exactly as long
                ; as the probe runs.  Restored at every exit below.
                ;--- NO STACK SWITCH, AND NO PARK (apple/fgx#185) ------------
                ; Both used to be here and both are gone, because the reason
                ; for them was removed rather than worked around.
                ;
                ; This routine used to move S to the top of FGX_STK_KTASKS so
                ; the probe would not overflow the 256-byte boot stack -- and
                ; that switch is what armed apple/fgx#183, because
                ; Mod_LoadConf, Mod_Load and mod_init still had live frames in
                ; page 1, which belongs to the firmware and the interrupt
                ; handler.  It then had to PARK those frames and put them back.
                ;
                ; main.s now leaves page 1 once, right after _LC_MapRam, so
                ; boot arrives here already on a deep stack with nothing of its
                ; own in page 1.  The park had nothing left to protect and the
                ; switch had nothing left to do.
                ;
                ; The measurement instrument below stays: what the chain COSTS
                ; is the open question in apple/fgx#172, and it is reported
                ; rather than inferred.
                ;
                ; PAINT THE WINDOW BELOW S.  Each byte carries its own low
                ; address -- a constant fill mis-reports the mark upward
                ; whenever the stack stores that constant, which is the
                ; reassuring direction.  Long-indexed addressing is ,X ONLY on
                ; this processor; there is no `STAL abs,Y`.
                PHA
                PHX
                SEP     #$20
                MX      %10
                LDX     #VFP_PAINT-1
@vfp_paintL     TXA
                STAL    $000000+VFP_PAINTBASE,X
                DEX
                BPL     @vfp_paintL
                REP     #$30
                MX      %00
                PLX
                PLA

                ENTERK                  ; D = the kernel's page, for the
                                        ;   device-table DP cells below

                ;--- Find a disk that is SAFE TO WRITE TO: the first
                ; DEV_CLASS_DISK at index 1 or above.
                ;
                ; INDEX 0 IS THE BOOT DISK and is never a candidate -- Blk_Init
                ; populates _devTable[0] with it, and a probe that scribbles
                ; there destroys the running system.  The scratch spindle is a
                ; 2.11BSD volume attached as a second SmartPort drive, which
                ; the ProDOS layer cannot mount and therefore never touches.
                ;
                ; The ONLINE test is not belt-and-braces: a class byte alone is
                ; not proof a device exists, and an earlier version of this
                ; scan ran before the device table was initialised, matched a
                ; stray class byte in unallocated memory, and did I/O to a slot
                ; that was not there.  Running at Mod_LoadConf time is late
                ; enough that Blk_Init has populated it. ---
                STZ    |_probeCand
                LDX     #1
@vfp_findL      CPX     #FS_MAX_DEVICES
                BCC     @vfp_scan
                BRL     @vfp_none       ; no scratch disk: skip, loudly
@vfp_scan       TXA
                ASL
                ASL
                ASL
                ASL                     ; *DEV_SIZE
                CLC
                ADC     dev_table_ptr
                STA     _devPtr
                SEP     #$20
                MX      %10
                LDA     dev_table_ptr+2
                ADC     #0
                STA     _devPtr+2
                LDY     #DEV_Class
                LDA     [_devPtr],Y
                CMP     #DEV_CLASS_DISK
                BNE     @vfp_next
                LDY     #DEV_Flags
                LDA     [_devPtr],Y
                AND     #DEV_FLAG_ONLINE
                BNE     @vfp_found
@vfp_next       MX      %10
                REP     #$30
                MX      %00
                INX
                BRA     @vfp_findL

@vfp_found      MX      %10             ; reached by BEQ from the M=8 class
                                        ;   compare, not by the M=16
                                        ;   fall-through above
                ; _devPtr = the candidate, X = its index.  Claim it for vfs_bio.
                LDY     #DEV_Flags
                LDA     [_devPtr],Y
                ORA     #DEV_FLAG_VFSOWNED
                STA     [_devPtr],Y
                REP     #$30
                MX      %00
                INC    |_probeCand   ; candidates examined
                STX    |_probeDev    ; which device it chose
                PHX                     ; keep the index for the unmark

                ; A filesystem block well past the scratch volume's metadata.
                ; fgxfs mkfs lays down a superblock and a 64-block i-list at
                ; the front and marks the rest free, so block 1000 of a 4096
                ; block volume is data nobody owns.  Fixed rather than derived:
                ; deriving it from a device whose size this code has not read
                ; is how an earlier attempt ended up addressing past the end.
                LDA     #1000
                PHA                     ; save fsblk for the call

                MOD_KC_ENTER            ; DBR = our bank, D = kernel-C page
                ; Stack from S at this point, and the arithmetic is worth
                ; spelling out because getting it wrong costs a boot:
                ;   1,S-2,S  D   (the bracket's PHD, pushed second)
                ;   3,S      B   (the bracket's PHB, pushed first)
                ;   4,S-5,S  fsblk, saved before the bracket
                ;   6,S-7,S  device index, saved before that
                ; Each PHA below shifts all of it by two.  MOD_KC_ENTER pushes
                ; the same three bytes KC_ENTER did, so these offsets are the
                ; kernel-side ones unchanged.
                LDA     #0
                PHA                     ; fsblk HIGH word (daddr_t)
                LDA     6,S             ; fsblk (was 4,S; +2)
                PHA
                LDA     10,S            ; device index (was 6,S; +4)
                AND     #$00FF
                PHA                     ; ...pushed LAST, so it lands at 4,S
                                        ;   as argument one
                PHK
                PEA     @vfp_ret-1
                JMP     PROBE_ENTRY     ; 0 = pass.  The including module
                                        ;   EQUs this to its own C entry point.
@vfp_ret        TAY                     ; stash before the PLAs eat A
                PLA                     ; caller pops its own arguments
                PLA
                PLA
                MOD_KC_LEAVE

                PLA                     ; drop the saved fsblk
                PLX                     ; the device index back
                PHY                     ; THE VERDICT GOES ON THE STACK.  The
                                        ;   unmark below needs Y for DEV_Flags,
                                        ;   and holding the verdict in Y across
                                        ;   it read the flag OFFSET back as the
                                        ;   result -- a probe that reported its
                                        ;   own bug as the subject's.
                ; Unmark, whatever the verdict: the flag is not this probe's to
                ; leave behind.
                TXA
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
                LDY     #DEV_Flags
                LDA     [_devPtr],Y
                AND     #$FF-DEV_FLAG_VFSOWNED
                STA     [_devPtr],Y
                REP     #$30
                MX      %00

                PLY                     ; the verdict back
                ; 61 = "this is not the scratch volume, nothing was written".
                ; Keep looking: the emulator's device numbering is not a
                ; promise about which image answers where, so the volume is
                ; found by its SUPERBLOCK, not by its slot.
                CPY     #61
                BNE     @vfp_verdict
                INX                     ; next candidate
                BRL     @vfp_findL
@vfp_verdict    CPY     #0
                BNE     @vfp_bad
                LDA     #PROBE_MSGOK
                BRL     @vfp_emit
@vfp_bad        ; Name the failing case.  vfs_probe returns a distinct code per
                ; property, so a red says WHICH invariant broke rather than
                ; leaving the next person to bisect for it.
                PHY
                LDA     #PROBE_MSGBAD
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                PLA                     ; the code, PRINTED WHOLE.  An
                                        ;   AND #$00FF here truncated 348 to 92
                                        ;   and sent a diagnostic hunting the
                                        ;   wrong failure entirely.
                LDX     #KSVC_LOGDEC16
                JSL     SYS_KCALL
                LDA     #@vfp_msgDev
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDA    |_probeDev
                LDX     #KSVC_LOGDEC16
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                BRL     @vfp_exit
@vfp_emit       LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                BRL     @vfp_exit

@vfp_none       REP     #$30
                MX      %00
                LDA     #PROBE_MSGSKIP
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                ; How many ONLINE disks it actually looked at.  1 means only
                ; the boot disk is registered, so the second spindle never
                ; reached the device table; 2 or more means it is there and the
                ; superblock check is what rejected it.  Those have completely
                ; different causes.
                LDA     #@vfp_msgCand
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDA    |_probeCand
                LDX     #KSVC_LOGDEC16
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                BRL     @vfp_exit

;--- THE ONE EXIT, and it UNPARKS ---------------------------------------------
; All three verdict paths come here.  The restore must be atomic against the
; excursions described at the park: between putting the frame back and the TCS
; that returns to it, S is still off page 1, so an interrupt in that window
; would land on the bytes just restored.  PLP puts the caller's I flag back.
                ;--- REPORT HOW DEEP IT WENT (apple/fgx#172) -----------------
                ; The lowest byte of the painted page that still holds its own
                ; low address bounds the chain's depth from below: the probe's
                ; stack top is that page's top, so a mark of N means the whole
                ; chain fitted in 256-N bytes... as long as it did not run off
                ; the page entirely, which a mark of 0 says it did.
@vfp_exit       SEP     #$20
                MX      %10
                LDX     #0
@vfp_scanL      TXA
                CMPL    $000000+VFP_PAINTBASE,X
                BNE     @vfp_reach
                INX
                CPX     #VFP_PAINT
                BNE     @vfp_scanL
@vfp_reach      REP     #$30
                MX      %00
                ; AN ABSOLUTE OFFSET FROM THE BOTTOM OF THE REGION, which is the
                ; number anyone sizing these stacks can use without knowing
                ; where boot's S happened to be.  Small means the chain came
                ; close to running out of FGX_STK_KTASKS entirely; a value equal
                ; to the whole window means it never reached the paint, so the
                ; chain is shallower than the clearance above it.
                STX    |_probeMark      ; X is 16-bit here and counted in 16
                LDA    |_probeMark
                CLC
                ADC     #VFP_PAINTBASE-FGX_STK_KTASKS
                PHA
                LDA     #@vfp_msgStk
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                PLA
                LDX     #KSVC_LOGDEC16
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL

                LEAVEK
                PLP
                RTS

@vfp_msgStk     ASC     'probe: stack reached ktasks+',$00
@vfp_msgDev     ASC     ' dev ',$00
@vfp_msgCand    ASC     ' candidates ',$00
