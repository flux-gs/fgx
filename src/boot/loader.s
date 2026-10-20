;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     loader.s     (stage 1 of the two-stage loader)
; Purpose:  Boot block 0 loader (512 bytes, ONE sector)
;
; This loader is loaded by IIgs ROM to $0800 and executed in emulation mode.
; It reads stage 2 from a BAKED-IN block range -- start block and block count,
; patched into this sector by tools/bake_stage2.py once the image is built --
; loads it to $00:2000, stashes the boot-device slot at $00:1FFE, and jumps to
; stage 2.  Stage 2 then finds the kernel + any pre-staged modules by name.
;
; STAGE 1 OWNS SECTOR 0 AND NOTHING ELSE.  2.11BSD's h/disklabel.h:53 puts the
; disklabel at LABELSECTOR 1, LABELOFFSET 0 -- the sector this loader used to
; self-load as its second half -- so the boot area available to code is 512
; bytes, and a name lookup does not fit in it.
;
; WHY A BAKED BLOCK RANGE RATHER THAN A LOOKUP.  2.11BSD's own boot blocks DO
; walk the filesystem in 512 bytes: examples/2.11BSD/usr/sys/mdec/rauboot.s
; iget()s ROOTINO, scans the root directory for `boot' by name, and reads the
; four direct addresses of the inode it finds -- and its own header says the
; cost, "all options of reading an alternate name or echoing to the keyboard
; had to be removed to make room for the code which understands the new
; directory structure on disc".  That is a PDP-11 512 bytes.  65816 code runs
; ~2.5-3x the size for the same work (docs/ROADMAP.md), so the same walk does
; not fit here, and the campaign plan drops it by decision:
; docs/history/plans/2026-08-09-ufs-migration-campaign.md, deliverable 2.2.
;
; STAGE 2 IS STILL A REAL FILE, not a reserved block range.  Blocks that are
; neither on the free list nor owned by an inode are exactly what fsck
; classifies as missing and salvages back into the free list -- so a reserved
; range would be reclaimed and then overwritten, by our own on-target fsck or
; by a real 2.11BSD system fscking an FGX volume.  The baker resolves the file
; through the filesystem and REQUIRES its data blocks to be contiguous.
;
; Memory layout during stage-1 execution:
;   $0800-$09FF  This loader (stage 1, one sector)
;   $1FFE        Boot-slot byte (this loader writes; stage 2 reads)
;   $2000-       Stage 2 binary (loaded directly here)
;
; This loader keeps BlkTramp / CoutTramp / HandoffData live for the kernel:
; after stage 2 + the kernel take over, the kernel JSLs into these bank-0
; trampolines via the $001FE0 handoff block.  Stage 1's code at $0800-$09FF
; persists in RAM for the lifetime of the system because nothing else loads
; there.
;
; History: pre-slice-2 this file loaded /FGX/KERNEL into $1000 then
; multipass-MVN'd it to $02:2000.  Slice 2 moved kernel loading to stage 2
; (/BOOT); the multipass MVN logic moved with it.  UFS 2.2 removed the ProDOS
; directory scan, the sapling index walk and the block-1 self-load along with
; it.  See docs/superpowers/specs/2026-05-17-stage2-loader-plan.md.
;==============================================================================

;==============================================================================
; CONSTANTS
;==============================================================================

LOAD_ADDR       EQU     $0800           ; Where ROM loads us
SECTOR_SIZE     EQU     $0200           ; ...and all of it we get
STAGE2_DEST     EQU     $2000           ; stage 2 loads to $00:2000
SLOT_BYTE       EQU     $1FFE           ; stash for stage 2
; 24-byte loader->kernel handoff staging in BANK 0 (transient, below SLOT_BYTE
; in the not-yet-active kernel-stack page).  Stage 1 writes the BlkTramp/CoutTramp
; descriptor here; stage 2 appends the pre-staged-banks array (+8) and MVNs the
; whole block to the kernel bank's :FF00.  Was $02FF00 -- moved off bank $02 so a
; MicroDrive Turbo owning $02 is never touched (the relocation's final $02 step).
HANDOFF_STAGE   EQU     $001FE0

; THE TRAMPOLINE BLOB'S RUNTIME HOME.  BlkTramp/BlkTrampParams/CoutTramp are
; assembled at $0800 and COPIED there at LoadDone, over this loader's own
; entry code -- the ROM entry and the slot scan, which have both finished by
; then and are never re-entered.
;
; WHY: only ~70 bytes of this loader are live after boot, but they sat at the
; TOP of $0B00 purely by assembly order, which reserved the whole $0800-$0BFF
; kilobyte forever.  Landing them at the bottom instead makes $0900-$17FF one
; contiguous run for the per-pid kernel direct pages.
;
; The kernel needs no change: it reads these addresses from the handoff block
; (block.s, boot_console.s) rather than baking them, which is the whole reason
; the blob can move at all.
TRAMP_HOME      EQU     $0800

; SmartPort command
SP_READ_BLOCK   EQU     $01

; HOW MANY BLOCKS STAGE 1 WILL CHASE.  Sixteen 512-byte device blocks is 8 KB.
;
; UPSTREAM'S OWN BOUND IS HALF THIS AND DOES NOT BIND HERE.  mdec/rauboot.s
; reads `NDIRIN = 4.' direct addresses and no indirect at all, so a 2.11BSD
; boot block cannot reach past 4 KB.  This one does not walk the inode: the
; block numbers are baked by tools/bake_stage2.py, which reads the whole inode
; through fgxfs, indirect blocks included.  So the only real bound is the room
; the list takes in sector 0 -- 1 + 3*S2MAX bytes -- and 8 KB leaves the
; loader well inside its sector.
;
; It was 8 for one commit, on the NDADDR argument, and stage 2 reached exactly
; 8 blocks the day the UFS reader landed.  A bound that a deliverable hits on
; arrival is a bound that was chosen for its story rather than its cost.
S2MAX           EQU     16

; Zero page scratch (safe during boot, won't conflict with ROM)
ZP_SLOT         EQU     $42             ; Slot number * 16
ZP_SLOT_HI      EQU     $43             ; $Cn high byte for slot firmware
ZP_PTR_LO       EQU     $44             ; scratch pointer lo (slot firmware read)
ZP_PTR_HI       EQU     $45             ; scratch pointer hi
ZP_BLKCNT       EQU     $46             ; stage-2 blocks still to read
ZP_BLKIDX       EQU     $47             ; byte offset into S2Blks (3 per entry)

; Hardware
BORDER_COLOR    EQU     $C034
TBCOLOR         EQU     $C022

;==============================================================================
; Entry point at $0800
;==============================================================================

                ORG     LOAD_ADDR

BootEntry
                DFB     $01             ; ProDOS boot signature
                BRA     BootStart
                DFB     $00,$00

BootStart
                SEI
                CLD
                STX     ZP_SLOT

                ; FGX color scheme: blue border (matches the kernel
                ; console default at console_init.s -- border color $02)
                ; + white-on-blue text, for a seamless transition into
                ; the SHR console's blue field.
                LDA     #$02
                STA     BORDER_COLOR
                LDA     #$F2
                STA     TBCOLOR

                ; Clear text screen $0400-$07FF in both main and aux banks.
                ; 80-col mode interleaves the two banks; if we only clear main
                ; the aux half still shows the ROM's copyright splash. With
                ; 80STORE on (ROM default), PAGE2 ($C055) -- not RAMWRT --
                ; redirects text-page writes to the aux bank.
                LDA     #$A0
                LDX     #$00
@clr            STA     $0400,X
                STA     $0500,X
                STA     $0600,X
                STA     $0700,X
                INX
                BNE     @clr
                STA     $C055           ; PAGE2 -- text-page writes -> aux
                LDX     #$00
@clrAux         STA     $0400,X
                STA     $0500,X
                STA     $0600,X
                STA     $0700,X
                INX
                BNE     @clrAux
                STA     $C054           ; PAGE1 -- writes -> main again

                ; Compute $Cn page for this slot
                LDA     ZP_SLOT
                LSR     A
                LSR     A
                LSR     A
                LSR     A
                ORA     #$C0
                STA     ZP_SLOT_HI      ; save $Cn

                ; SmartPort entry = $Cn00 + [$CnFF] + 3.  Patch it into both
                ; call sites HERE: unlike the two-sector loader, the whole of
                ; this file is already in RAM, so there is no second half to
                ; land on top of the patch afterwards.
                ;
                ; BlkTramp is assembled at TRAMP_HOME but still sits at its
                ; LOAD address -- the copy happens at LoadDone -- so the
                ; operand patch must target TrampSrc, not BlkTramp.  Patching
                ; BlkTramp+9 would write $0809, which is still this code and
                ; would be overwritten by the copy anyway.
                LDA     #$00
                STA     ZP_PTR_LO
                LDA     ZP_SLOT_HI
                STA     ZP_PTR_HI
                LDY     #$FF
                LDA     (ZP_PTR_LO),Y   ; Read [$CnFF]
                CLC
                ADC     #$03
                STA     SPEntry+1
                STA     TrampSrc+9
                LDA     ZP_SLOT_HI
                ADC     #$00
                STA     SPEntry+2
                STA     TrampSrc+10

;------------------------------------------------------------------------------
; Read stage 2: S2Cnt device blocks, named one by one in S2Blks, into
; STAGE2_DEST upward.
;
; A LIST AND NOT A START-PLUS-COUNT.  The first cut of this baked an extent,
; on the campaign plan's sentence that stage 2 is "a REAL FILE whose blocks
; mkfs guarantees contiguous".  It does not: mkfs builds the free list with a
; rotational interleave -- 2.11BSD mkfs.c:214 defaults `f_m = 3' when there is
; no disklabel to read a step from, and fgxfs uses 2 -- so blocks come off the
; list every f_m'th and a fresh file is systematically NOT consecutive.
; MEASURED on a volume fgxfs made: /boot got filesystem blocks 70, 72, 74.
; That is also why upstream's own boot block reads the inode's four direct
; addresses one at a time rather than a run (mdec/rauboot.s).
;
; A ZERO COUNT MEANS THE IMAGE WAS NEVER BAKED.  The descriptor ships as
; zeros, so an unbaked image would otherwise read block 0 -- this loader
; itself -- into $2000 and jump into it.  Catch it and hang instead.
;------------------------------------------------------------------------------

                LDA     S2Cnt
                BNE     @rdSetup
                JMP     LoadError       ; never baked
@rdSetup        STA     ZP_BLKCNT

                LDA     #$00
                STA     ZP_BLKIDX
                LDA     #<STAGE2_DEST
                STA     SPBuf
                LDA     #>STAGE2_DEST
                STA     SPBuf+1

@rdLoop         LDX     ZP_BLKIDX       ; SmartPort may clobber X, so it is
                LDA     S2Blks,X        ; re-read from zero page each time
                STA     SPBlk
                LDA     S2Blks+1,X
                STA     SPBlk+1
                LDA     S2Blks+2,X
                STA     SPBlk+2
                ORA     SPBlk
                ORA     SPBlk+1
                BEQ     @rdHole
                JSR     BlkRead
                BCC     @rdNext
                JMP     LoadError

;------------------------------------------------------------------------------
; A ZERO ENTRY IS A HOLE, AND SKIPPING IT IS NOT THE SAME AS ZEROING IT.
;
; Both filesystems omit an all-zero block -- ProDOS leaves a zero in the index
; and 2.11BSD leaves a zero in di_addr -- and cadius does exactly that when it
; stages stage 2, whose tail is a 64-byte DS and padding.  The destination
; still has to BE zero: this is the same fault apple/fgx#225 found in stage
; 2's own loop, where a skipped hole carried the PREVIOUS image's bytes.
;
; SPBuf's low byte is $00 for the whole loop -- the destination starts at
; $2000 and only the high byte ever moves -- which is what lets the fill run
; through a pointer built from SPBuf+1 alone.
;------------------------------------------------------------------------------
@rdHole         LDA     #$00
                STA     ZP_PTR_LO
                LDA     SPBuf+1
                STA     ZP_PTR_HI
                LDY     #$00
                TYA                     ; A = 0, and STA/INY both preserve it
@rdHole_p0      STA     (ZP_PTR_LO),Y
                INY
                BNE     @rdHole_p0
                INC     ZP_PTR_HI
@rdHole_p1      STA     (ZP_PTR_LO),Y
                INY
                BNE     @rdHole_p1

@rdNext         LDA     ZP_BLKIDX
                CLC
                ADC     #$03
                STA     ZP_BLKIDX
                INC     SPBuf+1
                INC     SPBuf+1         ; advance the buffer by 512 bytes
                DEC     ZP_BLKCNT
                BNE     @rdLoop

;------------------------------------------------------------------------------
; Hand off to stage 2
;------------------------------------------------------------------------------

LoadDone        CLC
                XCE

                REP     #$30
                MX      %00

                LDA     #$0000
                TCD
                LDA     #$01FF
                TCS

                SEP     #$20
                MX      %10

                ; Move the trampoline blob to TRAMP_HOME.  LAST safe moment:
                ; the ROM entry, the slot scan and the read loop are all
                ; finished and are never re-entered, and the SmartPort entry
                ; they derived lives in the patched operands, which travel
                ; with the copy.  The ERR at the foot of this file is what
                ; keeps LoadDone itself above the blob's destination.
                LDX     #0
@trampCopy      LDA     TrampSrc,X
                STA     TRAMP_HOME,X
                INX
                CPX     #TrampEnd-TRAMP_HOME
                BCC     @trampCopy

                ; Kernel-handoff trampoline pointers -> bank-0 staging
                ; (HANDOFF_STAGE); stage 2 MVNs them to the kernel bank's :FF00.
                ; Kernel JSLs back into BlkTramp + CoutTramp (below in this file)
                ; via these addresses; stage-1 code persists in RAM for the
                ; lifetime of the system.
                LDX     #0
@handoffLoop    LDA     HandoffData,X
                STAL    HANDOFF_STAGE,X
                INX
                CPX     #8
                BCC     @handoffLoop

                ; Stash boot slot (x16) at $1FFE so stage 2 can re-derive
                ; SmartPort entry without rescanning.
                LDA     ZP_SLOT
                STA     SLOT_BYTE

                ; Hand off to stage 2 -- already native, M=X=0, DBR=$00,
                ; D=$0000, S=$01FF.
                REP     #$30
                MX      %00
                JML     STAGE2_DEST

;------------------------------------------------------------------------------
; Error
;------------------------------------------------------------------------------

LoadError       MX      %10                 ; reached from emulation-mode code
                ; Unrecoverable load failure -- hang.
@hang           BRA     @hang

;==============================================================================
; BlkRead: call SmartPort READ BLOCK with current SPParams.
; Returns: C=0 success, C=1 error.
;==============================================================================

BlkRead
SPEntry         JSR     $C500           ; Patched at runtime
                DFB     SP_READ_BLOCK
                DW      SPParams
                RTS

;==============================================================================
; SmartPort parameter list
;==============================================================================

SPParams
SPParamCnt      DFB     $03
SPUnit          DFB     $01
SPBuf           DW      STAGE2_DEST             ; walked by the read loop
SPBlk           DFB     $00                     ; seeded from S2Blk
                DFB     $00
                DFB     $00

;==============================================================================
; THE STAGE-2 DESCRIPTOR.  tools/bake_stage2.py finds S2Magic in sector 0 and
; writes what follows: a count, then that many 24-bit little-endian DEVICE
; block numbers.  It ships as zeros, and a zero count is refused above -- an
; image whose baking step did not run hangs in the loader instead of executing
; whatever block 0 happens to hold.
;
; The magic is here so the baker does not have to agree with this file about
; an offset.  It must stay unique within the sector; the baker checks that.
;==============================================================================
S2Magic         ASC     'FGXSTG2!'
S2Cnt           DFB     $00                     ; blocks to read, 1..S2MAX
S2Blks          DS      S2MAX*3                 ; device blocks, 24-bit LE;
                                                ;   a zero entry is a HOLE

;==============================================================================
; HandoffData - bytes copied to HANDOFF_STAGE+1.. at LoadDone.
; Layout matches the labels declared in include/memmap.s.  8 entries:
; 6 for BlkTramp (entry + params, lo/hi/bank each) + 2 for CoutTramp
; (entry lo/hi; bank implicit $00).
;==============================================================================
HandoffData     DFB     <BlkTramp               ; $02FF01 _BlkTramp_EntryLo
                DFB     >BlkTramp               ; $02FF02 _BlkTramp_EntryHi
                DFB     $00                     ; $02FF03 _BlkTramp_EntryBank
                DFB     <BlkTrampParams         ; $02FF04 _BlkTramp_ParamsLo
                DFB     >BlkTrampParams         ; $02FF05 _BlkTramp_ParamsHi
                DFB     $00                     ; $02FF06 _BlkTramp_ParamsBank
                DFB     <CoutTramp              ; $02FF07 _CoutTramp_EntryLo
                DFB     >CoutTramp              ; $02FF08 _CoutTramp_EntryHi

;==============================================================================
; THE RELOCATED BLOB.  Everything below is assembled at TRAMP_HOME and copied
; there at LoadDone; it is emitted into the file at TrampSrc, packed after
; HandoffData (Merlin32 emits real bytes only and does not pad between ORGs).
;
; NOTHING MAY BE ADDED AFTER THIS POINT that is read at its load address --
; every label from here on resolves to $0800, so a `LDA Foo,X` against one
; would read block-0 code until the copy lands, and this loader's own code
; afterwards.  HandoffData is above for exactly that reason.
;==============================================================================
TrampSrc        EQU     *               ; where the blob is LOADED
                ORG     TRAMP_HOME      ; ...and where it RUNS

;==============================================================================
; SmartPort trampoline for kernel use after boot
;==============================================================================

BlkTramp        PHP
                PHB
                PHK
                PLB
                SEP     #$30
                SEC
                XCE
                JSR     $C500           ; Patched at runtime
                DFB     SP_READ_BLOCK
                DW      BlkTrampParams
;
; EXTENDED-CALL SLOT (+14/+15).  A SmartPort call's inline structure is THREE
; bytes for a standard call but FIVE for an extended ($4x) one -- Apple's own
; slot-5 firmware source spells it out (GSFirmware/SmartPort/C5XXcode.aii):
;
;   standard:  jsr SPentry / dfb Command      / dw ParmList /              bcs error
;   extended:  jsr SPentry / dfb Command+$40  / dw ParmList / dw ^ParmList / bcs error
;
; The firmware returns AFTER the structure, so a standard call resumes at +14
; and an extended one at +16.  Before this slot existed, an extended call read
; its pointer's bank word out of the `BCS` opcode ($B0 xx) and parsed a
; parameter list from bank $B0 -- both the Apple II SCSI card and the IIgs
; internal SmartPort hung there, identically, forever.
;
; Two bytes serve both forms.  They default to NOP NOP, which is what a
; STANDARD call executes on its way to the BCS below (NOP preserves carry, so
; the error test is unaffected).  An extended caller overwrites them with
; ^ParmList and never executes them, because its return lands at the BCS.
; Restore them to $EA/$EA afterwards or the next standard call runs a BRK.
;
BlkTrampExtBank NOP                     ; +14  ^ParmList lo (extended) / NOP
                NOP                     ; +15  ^ParmList hi (extended) / NOP
                BCS     @bt_err         ; +16
                CLC
                XCE
                PLB
                PLP
                CLC
                RTL

@bt_err         CLC
                XCE
                PLB
                PLP
                SEC
                RTL

; Sized for the LARGEST list (12 B), not the standard one (7 B).  A standard
; ReadBlock is cnt/unit/buf(2)/blk(3); extended ReadBlock ($41) widens buffer
; and block to longwords (10 B); extended Read ($48) adds a byte count between
; them (12 B, paramCount 4).  Holding all three here is what
; lets an extended call reuse the trampoline's own inline DW pointer at +12/+13
; -- staging the longer list somewhere else would mean patching that pointer per
; call and putting it back.  The three tail bytes are untouched by standard
; calls.  paramCount is $03 for both forms.
;
; DO NOT let this run into CoutTramp below: a 9-byte list written into the
; 7-byte version overran into CoutTramp's code, which is half of why the
; 2026-07-21 multi-block attempt "proved" the hardware could not do it.
BlkTrampParams
                DFB     $03
BlkTrampUnit    DFB     $01
BlkTrampBufLo   DFB     $00
BlkTrampBufHi   DFB     $00
BlkTrampBlkLo   DFB     $00                 ; extended: buffer bank
BlkTrampBlkMid  DFB     $00                 ; extended: buffer bank hi ($00)
BlkTrampBlkHi   DFB     $00                 ; extended: block lo
                DFB     $00                 ; extended: block hi
                DFB     $00                 ; extended: block bank
                DFB     $00                 ; extended: block bank hi ($00)
                DFB     $00                 ; extended READ ($48) only: the byte
                DFB     $00                 ; count pushes its list to 12 B

;==============================================================================
; CoutTramp - boot-console trampoline to firmware COUT ($00FDED).
;
; Called from kernel bank-$02 native-mode code via JSL to this bank-$00 entry
; (operand patched at boot from _CoutTramp_EntryLo/Hi handoff at $02FF07/08).
;
; In:  caller MX %00.  A's low byte = char | $80 (high-ASCII printable).
;      High byte of 16-bit A may be anything; we don't read it.
; Out: caller A clobbered (kernel-side wrapper PHA/PLA's around the JSL to
;      preserve caller A).  X/Y narrow to 8 bits during emulation transit;
;      kernel wrapper PHX/PHY-restores them.  DBR/DP/P preserved here.
;
; Pattern mirrors BlkTramp: PHK/PLB sets DBR=$00, SEC/XCE enters emulation
; for the firmware JSR, CLC/XCE returns to native, RTL pops the JSL frame.
;
; AND IT MIRRORS BlkTramp IN WHAT IT DOES *NOT* DO, WHICH THE CALLER MUST.
; Two preconditions, both of them the caller's to meet, exactly as
; _blkSmartJump meets them for BlkTramp -- see _BootCon_PutChar, the only
; caller, and apple/fgx#176 / #177:
;   1. ENTER ON A PAGE-$01 STACK.  The SEC/XCE below forces the stack high byte
;      to $01, so the PHP/PHB/PHD above it and the PLD/PLB/PLP below it read
;      different pages unless SH is already $01.
;   2. HAVE ROM SWITCHED IN OVER $00:D000-$FFFF.  _LC_MapRam maps language-card
;      RAM there and leaves it mapped, and $FDED is inside that window, so
;      without the switch this JSR does not reach COUT at all.
;
; DP RESET (same class as the SmartPort fix; see block.s _blkFwCall): we reset
; D=$0000 around the firmware JSR so ROM COUT does its scratch in the real (free)
; zero page, not the kernel's relocated DP ($B000).  The 40-column COUT1 path
; uses zero-page $20-$2F (WNDxx/CH/CV/BASL/GBASL); with the inherited D=$B000
; that would land on cur_font_data_ptr ($24) / cur_font_long_ptr ($28) /
; dev_table_ptr ($2C) and brick the console + block layer.  Was previously "safe
; only via the 80-col path"; now resolved unconditionally by the D=$0000 reset,
; matching how ProDOS/GS-OS/GNO call the firmware (and the loader's own
; D=$0000 SmartPort reads).
;==============================================================================

CoutTramp       PHP
                PHB
                PHK
                PLB                     ; DBR = PBR = $00
                REP     #$30            ; widen for PHD/TCD (caller enters MX %00)
                MX      %00
                PHD                     ; save caller direct page
                LDA     #$0000
                TCD                     ; D=$0000 -> ROM COUT scratch hits real zero
                                        ; page, not the kernel DP ($B000)
                SEP     #$30
                MX      %11
                SEC
                XCE                     ; emulation: XCE forces M=1, X=1
                JSR     $FDED           ; firmware COUT (caller pre-OR'd $80)
                CLC
                XCE                     ; back to native
                REP     #$30            ; widen for PLD
                MX      %00
                PLD                     ; restore caller direct page
                SEP     #$30
                MX      %11
                PLB                     ; restore caller DBR
                PLP                     ; restore caller P (MX %00)
                RTL

;==============================================================================
; END - the build pads this to 512 bytes, ONE sector
;==============================================================================

TrampEnd        EQU     *               ; blob length = TrampEnd - TRAMP_HOME

; THE BLOB MUST STAY INSIDE ITS OWN PAGE.  $0900 upward is claimed as free
; bank-0 RAM on the strength of this file ending below it; a blob that grew
; past $08FF would take a page back without anything saying so.  The division
; is 0 while TrampEnd < $0900 and nonzero the moment it is not.
                ERR     TrampEnd/$0900

; THE COPY MUST NOT LAND ON THE CODE DOING IT.  The blob's destination is
; TRAMP_HOME..TrampEnd-1, and everything from LoadDone on -- the copy loop,
; the handoff loop, the slot stash, the JML, and HandoffData which the loop
; reads -- runs or is read AFTER the first byte lands.  In the two-sector
; loader that was free: LoadDone lived in block 1 at $0Bxx.  In one sector it
; is a real constraint, so it is asserted rather than observed.  0 while
; LoadDone > TrampEnd.
                ERR     TrampEnd/LoadDone

; AND THE WHOLE FILE MUST FIT SECTOR 0.  2.11BSD's disklabel owns sector 1
; (h/disklabel.h:53, LABELSECTOR 1), so there is no second block to grow into
; and no self-load to reach it.  The last byte emitted is at
; TrampSrc + (TrampEnd - TRAMP_HOME) - 1; the division is 0 while that is
; below LOAD_ADDR+SECTOR_SIZE.  The ninja `loaderpad` rule checks the same
; bound on the finished file, which catches a size change this expression
; cannot see.
LoaderEnd       EQU     TrampSrc+TrampEnd-TRAMP_HOME-1
SectorEnd       EQU     LOAD_ADDR+SECTOR_SIZE
                ERR     LoaderEnd/SectorEnd
