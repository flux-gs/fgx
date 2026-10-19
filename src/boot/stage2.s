;==============================================================================
; stage2.s - FGX stage-2 bootloader.
;
; Loaded by stage 1 (boot sector 0, which reads /BOOT from a baked block range)
; into $00:2000.  Stage 1 entered us in NATIVE mode with M=X=0 and DBR=$00,
; and left the boot-device slot number byte at $00:1FFE.
;
; Responsibilities:
;   1. Re-derive SmartPort entry from $1FFE.
;   2. Walk the boot volume for /fgxunix, read its segment table, and
;      multipass-MVN each segment into the bank the table names.
;   3. JMP the kernel's entry.
;
; ONE IMAGE, AS 2.11BSD SHIPS ONE.  The kernel banks and the modules the root
; filesystem needs (vfs, ufs, ufsdir) are segments of /fgxunix, as 2.11BSD
; ships a single /unix whose overlays live inside it, sized by `ov_siz[NOVL]'
; in `struct ovlhdr' (usr/sys/h/exec.h:25-29) and read by the boot program
; (usr/sys/pdpstand/boot.c:258-260, in the full distribution under examples/).  A module that lives in the kernel image
; is read through nothing, so the filesystem can be one of them.
;
; The loadable modules (serial, bpf, net, ramdisk, pty, ...) are not here:
; /sbin/modload loads them from /etc/rc, post-boot, off the mounted root.
;
; Stage 2 writes the zero-terminated pre-staged bank list at
; $02:_PreStaged_Banks, and main.s walks it: where those bytes came
; from was always invisible to the kernel.
;
; Memory layout in bank 0 during stage-2 execution:
;   $0800-$0BFF  stage 1 code (dead but holding BlkTramp + CoutTramp).
;   $0C00-$0DFF  DIR_BUF
;   $0E00-$0FFF  IDX_BUF
;   $1000-$11FF  SEGTAB_BUF (/fgxunix's segment table)
;   $1200-$121F  PATH_BUF (built "/LIB/MODULES/NAME" path strings)
;   $1800-$1BFF  UIND2_BUF (the double indirect block, UFS reader)
;   $1FFE        boot slot byte (set by stage 1)
;   $2000-       stage 2 code
;   $3000-$BFFF  KERNEL_BUFFER (72-block multipass staging)
;
; See plan doc docs/superpowers/specs/2026-05-17-stage2-loader-plan.md.
;==============================================================================

;==============================================================================
; CONSTANTS
;==============================================================================

KERNEL_BUFFER   EQU     $3000
KERNEL_DEST     EQU     $021000         ; FGX_CODE: the page above the task table
                                        ; (32 TCBs x 64 B from $0800); lockstep
                                        ; with include/kernel.s and fgx.link.s ORG
KERNEL_DEST_LO  EQU     $1000
KFGX_ANCHOR     EQU     $00032C         ; memmap.s KFGX_ANCHOR — live kernel bank byte
KFGX_ANCHOR_MAG EQU     $00032D         ; memmap.s KFGX_ANCHOR_MAG — magic $4B = valid
KFGX_REST_ANCHOR EQU    $0003CC         ; memmap.s KFGX_REST_ANCHOR — rest-of-OS base bank
KFGX_REST_ANCHOR_MAG EQU $0003CD        ; memmap.s KFGX_REST_ANCHOR_MAG — magic $4B = valid
KFGX_REST_COUNT EQU     $000305         ; memmap.s KFGX_REST_COUNT — CLAIMED bank count (M-3;
                                        ;   $0305 beside _mlEntryJSL — $03CE was stomped by
                                        ;   the 3.5" ROM driver on floppy boots)
KFGX_REST_HANDLE EQU    $000306         ; memmap.s KFGX_REST_HANDLE — REST claim's MM handle
                                        ;   (4 B, loader-written; block-table row 0)
; ---- Relocatable kernel (MicroDrive Turbo $02:0000 campaign) ----
; The kernel always relocates off fixed bank $02 to an MM-assigned bank and runs
; the two-handle MM model.  The FGX_RELOC dual-build switch was removed 2026-06-13;
; the loader's relocation path below is unconditional.

DIR_BUF         EQU     $0C00
IDX_BUF         EQU     $0E00
; THE UFS BLOCK BUFFER ALIASES THE TWO PRODOS ONES.  A 2.11BSD filesystem
; block is 1024 bytes -- two device blocks -- and DIR_BUF+IDX_BUF are exactly
; that pair of pages.  Only one reader runs on any given volume, so the space
; is shared rather than doubled; UBLK_BUF2 names the second half because a
; directory entry never straddles a DIRBLKSIZ boundary (h/dir.h:33-42), so the
; two 512-byte halves are scanned independently.
UBLK_BUF        EQU     DIR_BUF         ; 1024 B: inode block / dir / indirect
UBLK_BUF2       EQU     DIR_BUF+512
; THE DOUBLE INDIRECT BLOCK GETS A BUFFER OF ITS OWN, which is upstream's own
; shape: `sbmap' keeps one buffer per level in `b[j]', tagged by block number
; in `blknos[j]' (examples/2.11BSD/usr/sys/pdpstand/sys.c:198-204).  Sharing
; UBLK_BUF would evict the SINGLE indirect block that the next 255 lbns all
; want -- see ufs_bmap.  Page-aligned, because ufs_bread addresses a buffer by
; its page alone.
UIND2_BUF       EQU     $1800           ; 1024 B: the double indirect block
SEGTAB_BUF      EQU     $1000           ; /fgxunix's segment table (block 0).
PATH_BUF        EQU     $1200           ; built path "/LIB/MODULES/NAME"
BOOT_CONF_BUF   EQU     $1400           ; boot.conf payload (≤512 B)
K_PATH_BUF      EQU     $1600           ; kernel path from boot.conf (≤64 B)
SLOT_BYTE       EQU     $1FFE

; Loader->kernel handoff staging in BANK 0 (must match loader.s HANDOFF_STAGE).
; The 8-byte BlkTramp/CoutTramp descriptor occupies +0..+7; the pre-staged-banks
; array starts at +8.  LoaderRelocateKernel MVNs the 24-byte block to the kernel
; bank's :FF00.  Was $02FF00/$02FF08 — moved off bank $02 (relocation final step).
HANDOFF_STAGE   EQU     $001FE0
PRESTAGED_ABS   EQU     HANDOFF_STAGE+8 ; _PreStaged_Banks zero-term array (bank 0)
MAX_PRESTAGED   EQU     16              ; matches DS 16 in memmap.s

PASS_BLKS       EQU     72              ; 72 × 512 = 36 KB / pass
PASS_PAGES      EQU     PASS_BLKS*2

DIR_ENTRIES     EQU     13
DIR_FIRST_OFF   EQU     43              ; offset of slot 1 in a dir block
DIR_ENTRY_LEN   EQU     39

STOR_SEEDLING   EQU     $10
STOR_SAPLING    EQU     $20
STOR_TREE       EQU     $30
STOR_SUBDIR     EQU     $D0
SP_READ_BLOCK   EQU     $01

; The bank-0 layout, for the kernel's direct page below.
;
; Stage 2 assembles STANDALONE and cannot include kernel.s, so these used to be
; hand-copied numbers -- and every one of them had rotted, leaving a claim table
; that described a machine which no longer existed (and which vmstat then
; reported to the user).  Drift here is invisible: stage 2 runs before any
; console exists, so a bad value is a black screen with no diagnostic.
;
; It CAN include the generated config, which is where the layout is DERIVED from
; kernel.nproc (tools/ninja/genconfig.py).  So these are aliases now, not
; copies, and there is nothing left to keep in sync by hand.
; tools/check_bank0_geometry.py enforces that they stay aliases.
                PUT     ../../include/config.s
; ...and the far bank's ABI, for KFAR_BOOT_FONT.  Pure EQUs, so this
; emits nothing; the alternative was a hand-copied $F900 in a file that
; runs before any console exists to report it being wrong.
                PUT     ../../include/kfar.s

; The two Memory Manager claims, aliased from the same generated config
; (kernel.banks and rest.* in cfg/system.cfg, derived by genconfig.py) that
; include/kernel.s aliases, so the loader and the kernel cannot disagree.
KERNEL_BANKS        EQU CFG_KERNEL_BANKS        ; kernel handle: core, far, tty
RESTOFOS_BANKS      EQU CFG_RESTOFOS_BANKS      ; rest-of-OS claim
RESTOFOS_MIN_BANKS  EQU CFG_RESTOFOS_MIN_BANKS  ; floor below which it halts
REST_KMOD_FIRST_OFF EQU CFG_REST_KMOD_FIRST_OFF ; module window offset

FGX_DP_KKERN        EQU CFG_DP_KKERN    ; kernel.s FGX_DP_KKERN -- the kernel's
                                        ;   own direct page, which the kernel
                                        ;   is handed off on
FGX_DP_KERNELC      EQU CFG_DP_KERNELC  ; kernel.s FGX_DP_KERNELC -- the page
                                        ;   below the I/O space that kernel C
                                        ;   runs on

; Zero-page scratch — stage 2 owns $50-$5F while running.
ZP_SLOT_HI      EQU     $50             ; $Cn for slot firmware
ZP_ENT_LO       EQU     $51             ; current dir-entry ptr (in DIR_BUF)
ZP_ENT_HI       EQU     $52
; THE FILE SIZE IS TWENTY-FOUR BITS, and was sixteen.  /fgxunix is 314,880
; bytes; the walkers refused or truncated anything past 65,535, which is a
; ceiling the loader no longer has anywhere else -- LoadCommon counts blocks
; and ufs_bmap maps two indirect levels.  ZP_STOR takes the byte the old
; 8-bit block index left, so the three size bytes stay contiguous.
ZP_STOR         EQU     $53
ZP_EOF_LO       EQU     $54
ZP_EOF_MID      EQU     $55
ZP_EOF_HI       EQU     $56
ZP_SPCNT        EQU     $57             ; vol-dir entry counter 1..13
ZP_PASSBLK      EQU     $58
ZP_PASSDEST     EQU     $59             ; 2 B lo/hi for bank-$02 dest

ZP_PATH_LO      EQU     $5B             ; walker: current path string ptr
ZP_PATH_HI      EQU     $5C
ZP_NAME_LEN     EQU     $5D             ; length of current path component
ZP_DIR_BLK_LO   EQU     $5E             ; block # of current dir being scanned
ZP_DIR_BLK_HI   EQU     $5F

; Conf parser scratch (re-uses post-walker ZP).  STILL HERE AFTER
; /etc/preload.conf: bc_init_cursor points these at BOOT_CONF_BUF and
; boot.conf's parser runs on the same skip_ws_comments / conf_atend helpers.
ZP_CONF_LO      EQU     $60             ; pointer into the conf buffer
ZP_CONF_HI      EQU     $61
ZP_CONF_END_LO  EQU     $62             ; buffer + EOF (end-of-content)
ZP_CONF_END_HI  EQU     $63
ZP_PS_IDX       EQU     $65             ; index into _PreStaged_Banks
ZP_ZFILL_LO     EQU     $66             ; sparse-block zero fill: buffer ptr
ZP_ZFILL_HI     EQU     $67             ;   (apple/fgx#225 -- see @sapHole)

; THE UFS READER'S TWO POINTERS, AND NOTHING ELSE IN ZERO PAGE.  SmartPort
; firmware clobbers zero page (walk_path already stashes ZP_PATH_LO/HI around
; every BlkRead for that reason), so every value the UFS reader has to KEEP
; lives in absolute storage below and only these two transients are here.
; Neither is live across a BlkRead.
ZP_UPTR_LO      EQU     $68             ; into UBLK_BUF: dinode slot, indirect
ZP_UPTR_HI      EQU     $69             ;   entry, directory scan cursor

BORDER_COLOR    EQU     $C034
TBCOLOR         EQU     $C022

;==============================================================================
; Entry — stage 1 hands off in native mode; we switch to emulation for
; SmartPort firmware calls, back to native only for the MVN.
;==============================================================================

                ORG     $002000

Stage2_Entry
                SEC
                XCE                             ; → emulation; HW forces MX=11
                MX      %11

                ; FGX color scheme: blue border + white-on-blue text
                ; (matches stage 1 and the kernel console default).
                LDA     #$02
                STA     BORDER_COLOR
                LDA     #$F2
                STA     TBCOLOR

                ; Derive SmartPort entry from $1FFE.
                LDA     SLOT_BYTE
                LSR
                LSR
                LSR
                LSR
                ORA     #$C0
                STA     ZP_SLOT_HI              ; $Cn

                ; SP entry = $Cn00 + [$CnFF] + 3.
                LDA     #$FF
                STA     ZP_ENT_LO
                LDA     ZP_SLOT_HI
                STA     ZP_ENT_HI
                LDY     #0
                LDA     (ZP_ENT_LO),Y           ; [$CnFF]
                CLC
                ADC     #$03
                STA     SPEntry+1
                LDA     ZP_SLOT_HI
                ADC     #$00
                STA     SPEntry+2

                ; --- Which filesystem is this? (campaign 2.3) ---------
                ; ONCE, before the first walk, from the volume itself.  Every
                ; walk_path and LoadDispatch below is unchanged and picks its
                ; reader off UfsFmt.
                JSR     ufs_probe

                ; --- Try to load /etc/boot.conf (optional) -------------
                ; If present, parse for kernel path (kernel/k line) and
                ; remember claim section for KernelHandoff to execute.
                ; If absent, _BootConfPresent stays 0 and we use defaults
                ; (PathKernel).
                LDA     #0
                STA     _BootConfPresent
                LDX     #0                          ; boot.conf
                JSR     SelPath
                JSR     walk_path
                BCC     @kn_bcSkip                  ; not found → use defaults
                ; Found.  Load to BOOT_CONF_BUF (cap at 512 B like preload).
                LDA     #$00
                STA     LoadDstBank
                STA     _DoPass_MVN_op+1
                LDA     #>BOOT_CONF_BUF
                STA     LoadDstOffHi
                JSR     LoadDispatch
                BCC     @kn_bcSkip                  ; load fail → use defaults
                ; Stash end pointer for parser.
                CLC
                LDA     ZP_EOF_LO
                ADC     #<BOOT_CONF_BUF
                STA     _BootConfEndLo
                LDA     ZP_EOF_MID
                ADC     #>BOOT_CONF_BUF
                STA     _BootConfEndHi
                LDA     #1
                STA     _BootConfPresent
                ; Pre-parse for kernel filename (sets K_PATH_BUF if found).
                JSR     ParseKernelPath
@kn_bcSkip

                ; --- Phase 1b.2: native-mode excursion ------------------
                ; Bring up the Tool Locator, get our MM user ID, and claim the
                ; kernel's bank NOW, so /KERNEL loads straight into the handle
                ; (no $02 staging copy).  TLStartUp + GetNewID +
                ; LoaderAllocKernelBank were moved here from KernelHandoff;
                ; MTStartUp stays late (heartbeat armed only after all NewHandles).
                CLC
                XCE                             ; → native
                REP     #$30
                MX      %00
                LDX     #$0201                  ; TLStartUp ($0201) — no args
                JSL     $E10000
                BCS     @kn_kbTBFail
                PHA                             ; GetNewID result placeholder
                PEA     $1000                   ; class $1000
                LDX     #$2003                  ; GetNewID ($2003) -> user ID in A
                JSL     $E10000
                BCS     @kn_kbTBFailID
                PLA                             ; A = userID
                STAL    _LoaderUserID
                JSR     LoaderAllocKernelBank   ; -> _LoaderKernBank (dynbank, never $02)
                BCC     @kn_kbHalt
                ; Claim the rest-of-OS handle NOW too (moved here from KernelHandoff)
                ; so _LoaderRestBase is known before the module prestage can target
                ; it.  attrNoSpec places it high, disjoint from the low boot.conf
                ; fixed claims, so claiming it before ExecuteBootConfClaims no longer
                ; risks the TN#78 purge that the old fixed-address loader hit.
                JSR     LoaderAllocRestBank     ; -> _LoaderRestBase (attrNoSpec, MM-placed)
                BCC     @kn_kbHalt
                BRL     @kn_kbOK                ; long: the failure messages
                                                ; below sit between here and there
@kn_kbTBFailID  PLA                             ; pop userID placeholder
@kn_kbTBFail    SEC
                XCE                             ; → emulation (HW forces MX=11)
                MX      %11
                LDA     #<MsgTBFail
                LDY     #>MsgTBFail
                BRA     BootFail
@kn_kbHalt      ; The RAM cases land here: LoaderAllocKernelBank could not claim
                ; a bank for the kernel, or LoaderAllocRestBank could not claim
                ; the rest-of-OS handle.  On a 1 MB machine there is simply no
                ; free bank, and this used to be `BRA @kn_kbHalt` -- a silent
                ; spin, which is the blue screen with no text.  Stage 2 had NO
                ; text output at all, so every failure in here looked identical
                ; and looked like a crash.
                SEC
                XCE                             ; → emulation (HW forces MX=11)
                MX      %11
                LDA     #<MsgNoMem
                LDY     #>MsgNoMem
                ; fall through

;-----------------------------------------------------------------------------
; BootFail - print a reason on the text screen, then stop.
;
; Stage 2 already painted this screen blue (BORDER_COLOR/TBCOLOR at entry), so
; COUT lands somewhere the user is looking.  There is no console and no kernel
; yet -- the ROM's $FDED is the only output that exists this early.
;
; In: A = message ptr low, Y = high (bank 0), emulation mode, MX %11.
; Does not return.  Reuses the path-walker's zero page: nothing runs after this.
;-----------------------------------------------------------------------------
BootFail        MX      %11
                PHK
                PLB                             ; DBR = $00 for the string read
                STA     ZP_PATH_LO
                STY     ZP_PATH_HI
                LDY     #0
@bf_L           LDA     (ZP_PATH_LO),Y
                BEQ     @bf_stop
                ORA     #$80                    ; COUT wants high ASCII
                JSR     $FDED
                INY
                BNE     @bf_L
@bf_stop        BRA     @bf_stop

MsgNoMem        ASC     0D,'FGX: not enough memory to start.',0D
                ASC     'FGX needs at least 3 MB of RAM.',0D,00
MsgTBFail       ASC     0D,'FGX: Toolbox/Memory Manager init failed.',0D,00
; A FILE THAT IS NOT THE KERNEL IMAGE, said out loud.  The loader has just
; read one block and has not touched a kernel bank yet, so this is reachable
; and the alternative -- MVNing an arbitrary file into six banks and jumping
; into it -- is a reset with a blank screen.
MsgBadUnix      ASC     0D,'FGX: /fgxunix is not a kernel image.',0D,00
MsgNoUnix       ASC     0D,'FGX: no /fgxunix on the boot volume.',0D,00
@kn_kbOK        SEC
                XCE                             ; → emulation (HW forces MX=11)
                MX      %11
                PHK
                PLB                             ; DBR = loader bank ($00) for the loads

                ; --- Load /fgxunix, ONE image, segment by segment -------
                ; Path from boot.conf K_PATH_BUF if _BootConfPresent and
                ; ParseKernelPath set it; else /fgxunix in its volume's case.
                LDA     _BootConfHasKPath
                BEQ     @kn_useDefault
                LDA     #<K_PATH_BUF
                STA     ZP_PATH_LO
                LDA     #>K_PATH_BUF
                STA     ZP_PATH_HI
                BRA     @kn_walk
@kn_useDefault  LDX     #2                          ; /fgxunix
                JSR     SelPath
@kn_walk        JSR     walk_path
                BCS     *+5
                JMP     @kn_noUnix

                ; --- The segment table, which is block 0 ----------------
                ; ONE BLOCK, TO BANK 0.  Everything the loader needs to place
                ; the other 614 is in it, so it is read before any bank is
                ; touched and a bad image is a message rather than an MVN into
                ; somewhere nobody claimed.
                LDA     #$00
                STA     LoadDstBank
                STA     _DoPass_MVN_op+1            ; patch MVN dst-bank = $00
                LDA     #>SEGTAB_BUF
                STA     LoadDstOffHi
                LDA     #$00
                STA     LoadBlkIdx
                STA     LoadBlkIdx+1
                STA     LoadNblk+1
                LDA     #$01
                STA     LoadNblk
                JSR     LoadRange
                BCS     *+5
                JMP     @kn_err

                LDX     #$00
@kn_magic       LDA     SEGTAB_BUF,X
                CMP     UnixMagic,X
                BEQ     @kn_magicOK
                JMP     @kn_badMag
@kn_magicOK     INX
                CPX     #8
                BNE     @kn_magic

                ; --- The segments -------------------------------------
                ; SIZES ONLY IN THE TABLE, OFFSETS BY SUMMING THEM, which is
                ; how 2.11BSD's own boot program places overlays: copyunix
                ; derives each segoff by adding up the ov_siz[] before it
                ; (pdpstand/boot.c:416-421) rather than storing an offset that
                ; could disagree with a size.  Here the running total needs no
                ; adding at all -- LoadBlkIdx is the file block the loop is on,
                ; and LoadCommon leaves it one past the segment it just moved,
                ; which IS the next segment's first block.  It is set here
                ; anyway rather than inherited, so the two routines are not
                ; coupled through a side effect.
                LDA     #$01                        ; block 0 was the table
                STA     LoadBlkIdx
                LDA     #$00
                STA     LoadBlkIdx+1
                STA     SegIdx
                STA     ZP_PS_IDX

@sg_loop        LDA     SegIdx
                CMP     SEGTAB_BUF+8                ; nseg
                BCS     @sg_done
                ; X = the entry: SEGTAB_BUF + 10 + idx*5.  Merlin32 has no
                ; operator precedence, so the *5 is built by shifts and an add
                ; rather than written as one expression.
                STA     UTmp
                ASL
                ASL                                 ; idx*4
                CLC
                ADC     UTmp                        ; idx*5
                CLC
                ADC     #10
                TAX
                ; COPIED OUT BEFORE THE LOAD, not indexed across it: the MVN
                ; runs in native mode with X and Y as its own counters, so no
                ; register survives LoadRange.
                LDA     SEGTAB_BUF,X                ; sel: 0 kernel, 1 kmod
                STA     SegSel
                LDA     SEGTAB_BUF+2,X              ; destination offset, hi
                STA     LoadDstOffHi
                LDA     SEGTAB_BUF+3,X              ; blocks of payload
                STA     LoadNblk
                LDA     SEGTAB_BUF+4,X
                STA     LoadNblk+1
                LDA     SEGTAB_BUF+1,X              ; banks past the base
                STA     SegBankOfs

                ; Destination bank = base + bankofs.  Neither base is known
                ; until the Memory Manager has answered, which is why the
                ; table names a base rather than a bank.
                LDA     SegSel
                BEQ     @sg_kern
                LDAL    _LoaderRestBase             ; (8-bit A in emulation)
                CLC
                ADC     #REST_KMOD_FIRST_OFF
                BRA     @sg_bank
@sg_kern        LDAL    _LoaderKernBank
@sg_bank        CLC
                ADC     SegBankOfs
                STA     LoadDstBank
                STA     _DoPass_MVN_op+1            ; patch MVN dst-bank
                JSR     LoadRange
                BCS     *+5
                JMP     @kn_err

                ; A kmod segment is one the kernel must be TOLD about, and the
                ; table's order is what /etc/preload.conf's line order used to
                ; be: ufs.mod resolves vfs.mod's VT_VFSCORE in its own
                ; mod_init and refuses to run without it, ufsdir.mod resolves
                ; both.  main.s walks this list and calls Mod_RegisterPreLoaded
                ; down it, so the order arrives intact.
                LDA     SegSel
                BEQ     @sg_next
                LDX     ZP_PS_IDX
                LDA     LoadDstBank
                STAL    PRESTAGED_ABS,X
                INC     ZP_PS_IDX
                LDA     ZP_PS_IDX
                CMP     #MAX_PRESTAGED-1            ; leave room for terminator
                BCS     @sg_done

@sg_next        INC     SegIdx
                BRA     @sg_loop

@sg_done        ; Write zero terminator at _PreStaged_Banks[ZP_PS_IDX].
                LDX     ZP_PS_IDX
                LDA     #$00
                STAL    PRESTAGED_ABS,X

                ; --- Stage the console font into (dynbank+1):KFAR_BOOT_FONT ---
                ; THE CONSOLE CANNOT FETCH ITS OWN GLYPHS.  Con_Init runs before
                ; any module is loaded, so it has no filesystem but the one the
                ; legacy reader knows -- and that read is what a kernel booted
                ; from a 2.11BSD root died on.  The boot program has both readers
                ; and has the far bank open; the font is a second load into it.
                ; include/kfar.s carries the rationale beside KFAR_BOOT_FONT.
                ;
                ; SelPath BECAUSE THE NAME IS CASED.  `/lib/fonts/default.fnt'
                ; is a userland path and 2.11BSD names are bytes, so it needs
                ; the pair -- as /fgxunix itself does.
                ;
                ; THE MAGIC IS CLEARED FIRST, and that is not belt and braces:
                ; this bank is NOT zeroed at load, so on real hardware $F900 holds
                ; whatever a cold power-on left there.  Writing one byte of the
                ; magic makes "no font on the volume" DETERMINATE -- Con_Init
                ; refuses and says so -- instead of a validation against garbage.
                ;
                ; A MISSING FONT IS NOT FATAL HERE, though a missing /fgxunix
                ; now is: halting for a font trades a diagnosis for a dead
                ; machine, and Con_Init reports it on the boot console.  There
                ; is nothing to report an absent kernel WITH.
                LDAL    _LoaderKernBank             ; (8-bit A in emulation mode)
                INC                                 ; far bank = base + 1
                STA     LoadDstBank
                STA     _DoPass_MVN_op+1            ; patch MVN dst-bank
                STA     _FontZapOp+3                ; ...and the zap's bank byte
                LDA     #$00
_FontZapOp      STAL    KFAR_BOOT_FONT              ; bank byte patched above
                LDX     #4                          ; the font
                JSR     SelPath
                JSR     walk_path
                BCC     @fn_done                    ; not on the disk -> skip
                LDA     #>KFAR_BOOT_FONT            ; $F9: page-aligned by design
                STA     LoadDstOffHi
                JSR     LoadDispatch                ; C=0 -> Con_Init will catch it
@fn_done
                ; --- Hand off to the kernel.  KernelHandoff resets SP and
                ; JMLs into bank $02 at the kernel entry.
                JMP     KernelHandoff

@kn_badMag      LDA     #<MsgBadUnix
                LDY     #>MsgBadUnix
                JMP     BootFail

; NO KERNEL ON THE VOLUME, said rather than hung.  Every other load failure
; still ends in LoadError's silent BRA, which is right for them: they happen
; deep in a block loop with no clean way back.  This one is a walk that
; returned, and it is the FIRST thing a wrong volume hits -- a ProDOS disk has
; no /fgxunix, and a black screen is what that used to look like.
@kn_noUnix      LDA     #<MsgNoUnix
                LDY     #>MsgNoUnix
                JMP     BootFail

@kn_err         JMP     LoadError

;==============================================================================
; LoadDispatch - load the WHOLE walked file: block 0, for as many blocks as
; its EOF needs.  LoadRange loads a chosen span instead, which is what a
; /fgxunix segment is.
;
; Given walker output (ZP_STOR / SPBlk / ZP_EOF*), dispatch to Seedling or
; Sapling.  The chosen loader runs the BlkRead loop + multipass MVN into
; LoadDstBank:LoadDstOffHi (set by caller before JSR).  Both Seedling and
; Sapling JMP LoadDone, which now RTSes here instead of JMLing the kernel.
; C=1 success; C=0 unknown storage type.
;==============================================================================
LoadDispatch    MX      %11
                LDA     #$00
                STA     LoadBlkIdx
                STA     LoadBlkIdx+1
                ; nblk = (EOF + 511) >> 9.  Formed as (EOF + 511) >> 8 in
                ; seventeen bits -- the low byte contributes only its carry --
                ; and then halved, so nothing overflows on the way.
                LDA     ZP_EOF_LO
                CLC
                ADC     #$FF
                LDA     ZP_EOF_MID
                ADC     #$01
                STA     LoadNblk
                LDA     ZP_EOF_HI
                ADC     #$00
                STA     LoadNblk+1
                ; The carry out of that last add is the seventeenth bit, and
                ; the shift right is what puts it where it belongs.
                ROR     LoadNblk+1
                ROR     LoadNblk

LoadRange       MX      %11
                LDA     UfsFmt
                BEQ     @ld_prodos
                JMP     UfsLoad
@ld_prodos      LDA     ZP_STOR
                CMP     #STOR_SEEDLING
                BNE     @ld_chkSap
                JMP     Seedling
@ld_chkSap      CMP     #STOR_SAPLING
                BNE     @ld_unk
                JMP     Sapling
@ld_unk         CLC
                RTS

;==============================================================================
; walk_path - walk a /-separated ProDOS path and populate file metadata.
;
; Input:  ZP_PATH_LO/HI = pointer to NUL-terminated path string.  Leading /
;         optional and consumed.  Each component matches a ProDOS entry
;         name case-sensitively (so use uppercase, matching ProDOS-on-disk
;         names).  Max 15 chars per component (ProDOS limit).
; Output: C=1 success → SPBlk[0..2] = file's key_block (24-bit; bank=0),
;                       ZP_EOF_LO/MID = file size low 16 bits,
;                       ZP_STOR = storage type (high nibble).
;         C=0 failure → path malformed, component not found, intermediate
;                       not a subdir, or I/O error.
;
; Algorithm:
;   1. Set current dir block = 2 (vol dir).
;   2. Loop:
;        a. Read current dir block into DIR_BUF (via SmartPort).
;        b. Skip any '/' in path; if path is now empty, fail (no leaf).
;        c. Measure next path component length (until '/' or NUL).
;        d. Find component in DIR_BUF.  If not found → fail.
;        e. If at end of path: extract file metadata, return C=1.
;        f. Else: entry must be a subdir.  Set current dir block = entry's
;           key_ptr.  Continue loop.
;
; Single-block dirs only in this slice — subdirs that span multiple blocks
; (>13 entries) would need next_block chasing.  None of our boot-time
; dirs are anywhere near 13 entries.
;==============================================================================
walk_path       MX      %11
                LDA     UfsFmt
                BEQ     pd_walk_path
                JMP     ufs_walk_path

;------------------------------------------------------------------------------
; pd_walk_path -- the ProDOS reader.  Contract as documented above; UFS's half
; is ufs_walk_path, and both return C=1 with ZP_EOF_LO/MID and ZP_STOR set.
;------------------------------------------------------------------------------
pd_walk_path
                ; Start at vol dir (block 2).
                LDA     #2
                STA     ZP_DIR_BLK_LO
                LDA     #0
                STA     ZP_DIR_BLK_HI

@wp_compLoop
                ; Read current dir block into DIR_BUF.
                LDA     #<DIR_BUF
                STA     SPBuf
                LDA     #>DIR_BUF
                STA     SPBuf+1
                LDA     ZP_DIR_BLK_LO
                STA     SPBlk
                LDA     ZP_DIR_BLK_HI
                STA     SPBlk+1
                LDA     #0
                STA     SPBlk+2
                ; SmartPort firmware clobbers ZP $5B/$5C (ZP_PATH_LO/HI);
                ; stash to abs storage and restore after the call.
                LDA     ZP_PATH_LO
                STA     _path_save_lo
                LDA     ZP_PATH_HI
                STA     _path_save_hi
                JSR     BlkRead
                PHP                             ; preserve C across restore
                LDA     _path_save_lo
                STA     ZP_PATH_LO
                LDA     _path_save_hi
                STA     ZP_PATH_HI
                PLP
                BCC     @wp_dirOK
                CLC                             ; I/O error → C=0
                RTS
@wp_dirOK
                ; Skip leading '/' chars in path.
@wp_skipSlash   LDY     #0
                LDA     (ZP_PATH_LO),Y
                CMP     #'/'
                BNE     @wp_haveComp
                INC     ZP_PATH_LO
                BNE     @wp_skipSlash
                INC     ZP_PATH_HI
                BRA     @wp_skipSlash
@wp_haveComp
                ; If at NUL, no leaf name — bad path.
                LDA     (ZP_PATH_LO),Y
                BNE     @wp_hc_ok
                JMP     @wp_badPath
@wp_hc_ok

                ; Measure component length (chars until '/' or NUL).  Y
                ; ends as the count.
                LDY     #0
@wp_measL       LDA     (ZP_PATH_LO),Y
                BEQ     @wp_measDone
                CMP     #'/'
                BEQ     @wp_measDone
                INY
                CPY     #16
                BCC     @wp_measL
                ; Component too long (>15) — bad path.
                JMP     @wp_badPath
@wp_measDone    STY     ZP_NAME_LEN
                ; Y == 0 case: empty component between // — bad path.
                ; STY doesn't set flags, so TYA forces N/Z from Y before BNE.
                TYA
                BNE     @wp_md_ok
                JMP     @wp_badPath
@wp_md_ok

                ; Find component in DIR_BUF.  ZP_NAME_LEN set; component
                ; chars at (ZP_PATH_LO),0..ZP_NAME_LEN-1.
                ;
                ; The directory may span several blocks.  Scan the key block's
                ; 12 slots, then chase next_block for as long as the chain
                ; holds, scanning 13 slots per continuation block.  Real ProDOS
                ; chases this chain (Beneath Apple ProDOS p.25); stage 2 used
                ; not to, which put /etc one file away from unbootable.
                LDA     #DIR_FIRST_OFF          ; key block: slot 1 at $0C2B
                STA     ZP_ENT_LO
                LDA     #>DIR_BUF
                STA     ZP_ENT_HI
                LDA     #1
                STA     ZP_SPCNT
                LDA     #16                     ; hop cap (see next_dir_block)
                STA     _fid_hops
@wp_scan        JSR     find_in_dir
                BCS     @wp_found
                JSR     next_dir_block          ; C=1: successor in DIR_BUF
                BCS     @wp_scan
                CLC                             ; chain exhausted -> not found
                RTS

@wp_found
                ; ZP_ENT_LO/HI points to matching entry.  Decide:
                ; if path-position+ZP_NAME_LEN reaches end (NUL), this is
                ; the leaf — extract file metadata; else, it must be a
                ; subdir — descend.

                ; Advance path past the component.
                CLC
                LDA     ZP_PATH_LO
                ADC     ZP_NAME_LEN
                STA     ZP_PATH_LO
                LDA     ZP_PATH_HI
                ADC     #0
                STA     ZP_PATH_HI

                ; Peek at next char.
                LDY     #0
                LDA     (ZP_PATH_LO),Y
                BEQ     @wp_leaf                ; NUL: this is the leaf
                CMP     #'/'
                BEQ     @wp_descend             ; '/': descend through entry
                ; Anything else after a name is unexpected.
                BRA     @wp_badPath

@wp_descend
                ; Entry must be a subdir to descend through.
                LDY     #0
                LDA     (ZP_ENT_LO),Y
                AND     #$F0
                CMP     #STOR_SUBDIR
                BNE     @wp_badPath
                ; Read entry's key_ptr as new current dir block.
                LDY     #$11
                LDA     (ZP_ENT_LO),Y
                STA     ZP_DIR_BLK_LO
                INY
                LDA     (ZP_ENT_LO),Y
                STA     ZP_DIR_BLK_HI
                JMP     @wp_compLoop            ; descend + scan again

@wp_leaf
                ; Leaf entry — extract storage type, key_ptr, eof.
                LDY     #0
                LDA     (ZP_ENT_LO),Y
                AND     #$F0
                STA     ZP_STOR
                LDY     #$11
                LDA     (ZP_ENT_LO),Y
                STA     SPBlk
                INY
                LDA     (ZP_ENT_LO),Y
                STA     SPBlk+1
                LDA     #0
                STA     SPBlk+2
                LDY     #$15
                LDA     (ZP_ENT_LO),Y
                STA     ZP_EOF_LO
                INY
                LDA     (ZP_ENT_LO),Y
                STA     ZP_EOF_MID
                ; THE THIRD SIZE BYTE IS ZEROED AND NOT READ, and that keeps
                ; this walker doing exactly what it did.  A ProDOS entry has
                ; three EOF bytes and this reads two; reading the third would
                ; be a change to the ProDOS reader, which is frozen until
                ; there is an FST to mount one with.  Zeroing is what stops
                ; the byte carrying a size left over from an earlier walk.
                LDA     #$00
                STA     ZP_EOF_HI
                SEC
                RTS

@wp_badPath     CLC
                RTS

;==============================================================================
; find_in_dir - scan DIR_BUF entries for a name match.
;
; Input:  DIR_BUF populated with a dir block.
;         ZP_PATH_LO/HI = pointer to name string (does NOT need to be
;                          NUL-terminated; ZP_NAME_LEN governs).
;         ZP_NAME_LEN  = name length 1..15.
;         ZP_ENT_LO/HI = first entry to test (the caller's scan window).
;         ZP_SPCNT     = that entry's slot number.
; Output: C=1 + ZP_ENT_LO/HI points at matching entry within DIR_BUF.
;         C=0 if no match in this block's remaining slots.
;
; The scan window is the CALLER's to set, because the two kinds of directory
; block differ: a KEY block spends slot 0 on the vol/subdir header, so it
; starts at slot 1 / DIR_FIRST_OFF and yields 12 entries; a CONTINUATION block
; has no header, so it starts at slot 0 / offset 4 and yields all 13.  See
; walk_path's @wp_scan loop and next_dir_block.
;==============================================================================
find_in_dir

@fid_slotL      LDA     ZP_SPCNT
                CMP     #DIR_ENTRIES
                BCC     @fid_trySlot
                CLC                             ; out of slots → not found
                RTS

@fid_trySlot    ; Entry stortype/namelen at offset 0.  Empty/deleted = 0.
                LDY     #0
                LDA     (ZP_ENT_LO),Y
                BEQ     @fid_nextSlot
                ; Match namelen exactly.
                AND     #$0F
                CMP     ZP_NAME_LEN
                BNE     @fid_nextSlot
                ; Compare bytes 1..ZP_NAME_LEN against (ZP_PATH_LO).
                LDY     #1                      ; entry byte index
                LDX     #0                      ; path char index
@fid_charL      LDA     (ZP_ENT_LO),Y
                STA     _fid_entChar            ; stash for compare
                PHY                             ; save entry idx
                TXA
                TAY                             ; path idx for ind-Y
                LDA     (ZP_PATH_LO),Y          ; path char in A
                PLY                             ; restore entry idx (clobbers NZ — must precede CMP)
                CMP     _fid_entChar
                BNE     @fid_nextSlot
                INY
                INX
                CPX     ZP_NAME_LEN
                BCC     @fid_charL
                ; All ZP_NAME_LEN chars matched.
                SEC
                RTS

@fid_nextSlot   CLC
                LDA     ZP_ENT_LO
                ADC     #DIR_ENTRY_LEN
                STA     ZP_ENT_LO
                LDA     ZP_ENT_HI
                ADC     #0
                STA     ZP_ENT_HI
                INC     ZP_SPCNT
                JMP     @fid_slotL

;==============================================================================
; next_dir_block - follow the current directory's next_block link and read the
; successor into DIR_BUF, leaving find_in_dir's scan window set for a
; CONTINUATION block (no header entry: slot 0 at offset 4, 13 usable slots).
;
; Input:  DIR_BUF holds the block just scanned.
;         ZP_DIR_BLK_LO/HI = its block number.
;         _fid_hops = remaining hops (decremented here).
; Output: C=1 + DIR_BUF holds the next block, ZP_DIR_BLK_LO/HI updated,
;              ZP_ENT_LO/HI + ZP_SPCNT set to the continuation window.
;         C=0 = chain exhausted, hop cap reached, I/O error, or the successor
;              failed back-pointer validation.  Caller treats as not-found.
;
; VALIDATION: a probe during the reverted 2026-07-26 attempt showed DIR_BUF can
; hold non-directory bytes on some scan-failure path, so the successor must
; point BACK at the block we came from before we trust its entries.  The hop cap
; is belt-and-braces: a corrupt pair of mutually-referencing blocks would
; otherwise satisfy the back-pointer check forever.
;
; Saves/restores ZP_PATH_LO/HI across BlkRead exactly as @wp_compLoop does --
; SmartPort firmware clobbers $5B/$5C, and find_in_dir compares against them.
; ZP_DIR_BLK is safe to use as the scan cursor: @wp_descend overwrites it from
; the entry's key_ptr, and @wp_leaf never reads it.
; MX %11 in/out.
;==============================================================================
next_dir_block  MX      %11
                ; --- Hop cap.
                DEC     _fid_hops
                BNE     @ndb_hopsOK
                CLC
                RTS
@ndb_hopsOK
                ; --- next_block == 0 means end of chain.
                LDA     DIR_BUF+2
                STA     _fid_nextLo
                LDA     DIR_BUF+3
                STA     _fid_nextHi
                ORA     _fid_nextLo
                BNE     @ndb_haveNext
                CLC
                RTS
@ndb_haveNext
                ; --- Remember the block we came from, for validation.
                LDA     ZP_DIR_BLK_LO
                STA     _fid_fromLo
                LDA     ZP_DIR_BLK_HI
                STA     _fid_fromHi

                ; --- Read the successor into DIR_BUF.
                LDA     _fid_nextLo
                STA     ZP_DIR_BLK_LO
                STA     SPBlk
                LDA     _fid_nextHi
                STA     ZP_DIR_BLK_HI
                STA     SPBlk+1
                LDA     #0
                STA     SPBlk+2
                LDA     #<DIR_BUF
                STA     SPBuf
                LDA     #>DIR_BUF
                STA     SPBuf+1
                LDA     ZP_PATH_LO
                STA     _path_save_lo
                LDA     ZP_PATH_HI
                STA     _path_save_hi
                JSR     BlkRead
                PHP                             ; preserve C across the restore
                LDA     _path_save_lo
                STA     ZP_PATH_LO
                LDA     _path_save_hi
                STA     ZP_PATH_HI
                PLP
                BCC     @ndb_readOK
                CLC                             ; I/O error -> not found
                RTS
@ndb_readOK
                ; --- Validate: successor's prev_block must be where we came from.
                LDA     DIR_BUF+0
                CMP     _fid_fromLo
                BNE     @ndb_bad
                LDA     DIR_BUF+1
                CMP     _fid_fromHi
                BNE     @ndb_bad

                ; --- Continuation window: slot 0 at DIR_BUF+4, all 13 usable.
                LDA     #4
                STA     ZP_ENT_LO
                LDA     #>DIR_BUF
                STA     ZP_ENT_HI
                LDA     #0
                STA     ZP_SPCNT
                SEC
                RTS
@ndb_bad        CLC
                RTS

_fid_entChar    DFB     $00                     ; 1-byte stash for compare
_fid_hops       DFB     $00                     ; remaining next_block hops
_fid_nextLo     DFB     $00                     ; successor block number
_fid_nextHi     DFB     $00
_fid_fromLo     DFB     $00                     ; block we came from (validation)
_fid_fromHi     DFB     $00
_path_save_lo   DFB     $00                     ; ZP_PATH_LO/HI save across BlkRead
_path_save_hi   DFB     $00
_BootConfPresent DFB    $00                     ; 0=no boot.conf (use defaults)
_BootConfHasKPath DFB   $00                     ; 0=use /fgxunix default
_BootConfEndLo  DFB     $00                     ; BOOT_CONF_BUF + size (lo)
_BootConfEndHi  DFB     $00                     ; BOOT_CONF_BUF + size (hi)
_bcParseLo      DFB     $00                     ; transient parse cursor (lo)
_bcParseHi      DFB     $00                     ; transient parse cursor (hi)
UnixMagic       ASC     'FGXUNIX1'              ; block 0's first eight bytes
; THE BLOCK LOOP'S COUNTERS ARE ABSOLUTE AND SIXTEEN BITS.  Sixteen because
; one image is 615 device blocks, so neither the file block nor the count
; fits a byte any more; absolute because both are live across a BlkRead and
; SmartPort firmware clobbers zero page -- the same reason the UFS reader
; keeps its state down here.  Nothing indexes through them, so zero page
; bought them nothing to begin with.
LoadBlkIdx      DW      $0000                   ; file block being read
LoadNblk        DW      $0000                   ; blocks still to move
SegIdx          DFB     $00                     ; segment being placed
SegSel          DFB     $00                     ; 0 kernel handle, 1 kmod region
SegBankOfs      DFB     $00                     ; banks past that base
LoadDstBank     DFB     $00                     ; target bank for current load
                                                ; (also patched into MVN op)
LoadDstOffHi    DFB     $00                     ; target offset hi byte
                                                ; (ZP_PASSDEST+1 init for the
                                                ; pass loop)

;==============================================================================
; skip_ws_comments - advance ZP_CONF_LO past whitespace + comment lines.
; Returns C=0 + cursor on first non-whitespace byte, or C=1 if cursor
; reached ZP_CONF_END_*.  Whitespace = space/tab/CR/LF.  Comment starts
; with '#' and runs to end-of-line.
;==============================================================================
skip_ws_comments        MX  %11
@sw_loop        JSR     conf_atend
                BCS     @sw_eof
                LDY     #0
                LDA     (ZP_CONF_LO),Y
                CMP     #$20                    ; space
                BEQ     @sw_advance
                CMP     #$09                    ; tab
                BEQ     @sw_advance
                CMP     #$0A                    ; LF
                BEQ     @sw_advance
                CMP     #$0D                    ; CR
                BEQ     @sw_advance
                CMP     #'#'
                BEQ     @sw_comment
                CLC                             ; got content
                RTS
@sw_advance     INC     ZP_CONF_LO
                BNE     @sw_loop
                INC     ZP_CONF_HI
                JMP     @sw_loop
@sw_comment     ; Inside a comment — skip to LF.
                INC     ZP_CONF_LO
                BNE     @sw_cChkEnd
                INC     ZP_CONF_HI
@sw_cChkEnd     JSR     conf_atend
                BCS     @sw_eof
                LDY     #0
                LDA     (ZP_CONF_LO),Y
                CMP     #$0A
                BNE     @sw_comment
                ; Hit LF — consume + resume outer skip.
                INC     ZP_CONF_LO
                BNE     @sw_loop
                INC     ZP_CONF_HI
                JMP     @sw_loop
@sw_eof         SEC
                RTS

;==============================================================================
; conf_atend - C=1 if ZP_CONF_LO/HI >= ZP_CONF_END_LO/HI, else C=0.  Standard
; 8-bit hi-then-lo unsigned compare.  Uses A.
;==============================================================================
conf_atend      MX  %11
                LDA     ZP_CONF_HI
                CMP     ZP_CONF_END_HI
                BCC     @ce_below
                BNE     @ce_atOrPast
                LDA     ZP_CONF_LO
                CMP     ZP_CONF_END_LO
                BCC     @ce_below
@ce_atOrPast    SEC
                RTS
@ce_below       CLC
                RTS

;==============================================================================
; bc_init_cursor - point ZP_CONF_LO/HI at BOOT_CONF_BUF and ZP_CONF_END_*
; at the stashed end-of-buffer pointer.  Both ParseKernelPath and
; ExecuteBootConfClaims call this so the existing skip_ws_comments /
; conf_atend helpers Just Work against boot.conf instead of preload.conf.
;==============================================================================
bc_init_cursor  MX      %11
                LDA     #<BOOT_CONF_BUF
                STA     ZP_CONF_LO
                LDA     #>BOOT_CONF_BUF
                STA     ZP_CONF_HI
                LDA     _BootConfEndLo
                STA     ZP_CONF_END_LO
                LDA     _BootConfEndHi
                STA     ZP_CONF_END_HI
                RTS

;==============================================================================
; bc_skip_keyword - advance ZP_CONF_LO past letters + hyphens (the keyword).
; Called after skip_ws_comments has placed cursor on the keyword's first
; char.  Used to position cursor at the keyword's argument.  Inline-WS
; (space/tab) after the keyword must be skipped separately by caller.
;==============================================================================
bc_skip_keyword MX      %11
@sk_loop        JSR     conf_atend
                BCS     @sk_done
                LDY     #0
                LDA     (ZP_CONF_LO),Y
                CMP     #'a'                    ; letter (lowercase)?
                BCC     @sk_chkUpper
                CMP     #'z'+1
                BCC     @sk_advance
@sk_chkUpper    CMP     #'A'
                BCC     @sk_chkHyphen
                CMP     #'Z'+1
                BCC     @sk_advance
@sk_chkHyphen   CMP     #'-'
                BNE     @sk_done
@sk_advance     INC     ZP_CONF_LO
                BNE     @sk_loop
                INC     ZP_CONF_HI
                BRA     @sk_loop
@sk_done        RTS

;==============================================================================
; bc_skip_inline_ws - advance ZP_CONF_LO past space/tab (NOT CR/LF).
; Cursor stops at first non-WS byte, EOL, or end-of-buffer.
;==============================================================================
bc_skip_inline_ws MX    %11
@siw_loop       JSR     conf_atend
                BCS     @siw_done
                LDY     #0
                LDA     (ZP_CONF_LO),Y
                CMP     #' '
                BEQ     @siw_advance
                CMP     #$09                    ; tab
                BNE     @siw_done
@siw_advance    INC     ZP_CONF_LO
                BNE     @siw_loop
                INC     ZP_CONF_HI
                BRA     @siw_loop
@siw_done       RTS

;==============================================================================
; bc_skip_to_eol - advance ZP_CONF_LO past everything until CR/LF, then
; past the CR/LF terminator(s) (CR-LF treated as one).
;==============================================================================
bc_skip_to_eol  MX      %11
@ste_loop       JSR     conf_atend
                BCS     @ste_done
                LDY     #0
                LDA     (ZP_CONF_LO),Y
                INC     ZP_CONF_LO
                BNE     @ste_inc1ok
                INC     ZP_CONF_HI
@ste_inc1ok     CMP     #$0D                    ; CR
                BEQ     @ste_eatLF
                CMP     #$0A                    ; LF
                BEQ     @ste_done
                BRA     @ste_loop
@ste_eatLF      ; If next is LF, consume it too (CR-LF).
                JSR     conf_atend
                BCS     @ste_done
                LDY     #0
                LDA     (ZP_CONF_LO),Y
                CMP     #$0A
                BNE     @ste_done
                INC     ZP_CONF_LO
                BNE     @ste_done
                INC     ZP_CONF_HI
@ste_done       RTS

;==============================================================================
; bc_parse_hex_nibble - read one hex digit at (ZP_CONF_LO,Y=0).
; Returns A.lo = 0..15, C=1 success / C=0 invalid (non-hex char).
; Cursor unchanged on failure; advanced by 1 on success.
; Accepts 0-9, A-F, a-f.
;==============================================================================
bc_parse_hex_nibble MX  %11
                JSR     conf_atend
                BCS     @ph_fail
                LDY     #0
                LDA     (ZP_CONF_LO),Y
                CMP     #'0'
                BCC     @ph_fail
                CMP     #'9'+1
                BCS     @ph_chkAF
                SEC
                SBC     #'0'                    ; 0..9
                BRA     @ph_ok
@ph_chkAF       CMP     #'A'
                BCC     @ph_fail
                CMP     #'F'+1
                BCS     @ph_chkaf
                SEC
                SBC     #'A'-10                 ; 10..15
                BRA     @ph_ok
@ph_chkaf       CMP     #'a'
                BCC     @ph_fail
                CMP     #'f'+1
                BCS     @ph_fail
                SEC
                SBC     #'a'-10
@ph_ok          PHA
                INC     ZP_CONF_LO
                BNE     @ph_okC
                INC     ZP_CONF_HI
@ph_okC         PLA
                SEC
                RTS
@ph_fail        CLC
                RTS

;==============================================================================
; bc_parse_hex_byte - read 2 hex digits → byte in A.  C=1 success.
;==============================================================================
bc_parse_hex_byte MX    %11
                JSR     bc_parse_hex_nibble
                BCC     @phb_fail
                ASL
                ASL
                ASL
                ASL
                STA     _bcParseLo              ; reuse as scratch (4-bit high)
                JSR     bc_parse_hex_nibble
                BCC     @phb_fail
                ORA     _bcParseLo
                SEC
                RTS
@phb_fail       CLC
                RTS

;==============================================================================
; bc_parse_hex_word - read 4 hex digits → 16-bit word in
; (_bcParseLo, _bcParseHi).  C=1 success.  (Caller reads result from
; the scratch slots since A is only 8-bit in our stage2 emulation mode.)
;==============================================================================
bc_parse_hex_word MX    %11
                JSR     bc_parse_hex_byte       ; high byte
                BCC     @phw_fail
                STA     _bcParseHi
                JSR     bc_parse_hex_byte       ; low byte
                BCC     @phw_fail
                STA     _bcParseLo
                SEC
                RTS
@phw_fail       CLC
                RTS

;==============================================================================
; ParseKernelPath - first pass over boot.conf.  Find the first line whose
; first non-WS char is 'k' (kernel directive); copy its argument
; (NUL-terminated path) into K_PATH_BUF; set _BootConfHasKPath = 1.
; If no 'k' line found, _BootConfHasKPath stays 0 → loader uses PathKernel.
;==============================================================================
ParseKernelPath MX      %11
                LDA     #0
                STA     _BootConfHasKPath
                JSR     bc_init_cursor
@pk_loop        JSR     skip_ws_comments
                BCS     @pk_done                ; end of buffer
                LDY     #0
                LDA     (ZP_CONF_LO),Y
                CMP     #'k'
                BEQ     @pk_found
                CMP     #'K'
                BEQ     @pk_found
                ; Not the kernel line — skip rest of line and continue.
                JSR     bc_skip_to_eol
                BRA     @pk_loop
@pk_found       JSR     bc_skip_keyword         ; past "kernel"
                JSR     bc_skip_inline_ws
                ; Copy path bytes until WS/EOL/EOF, capped at 63 chars + NUL.
                LDX     #0
@pk_copyL       CPX     #63
                BCS     @pk_copyDone
                JSR     conf_atend
                BCS     @pk_copyDone
                LDY     #0
                LDA     (ZP_CONF_LO),Y
                CMP     #' '
                BEQ     @pk_copyDone
                CMP     #$09
                BEQ     @pk_copyDone
                CMP     #$0D
                BEQ     @pk_copyDone
                CMP     #$0A
                BEQ     @pk_copyDone
                ; Skip leading '/' so walk_path's @wp_skipSlash works.
                CPX     #0
                BNE     @pk_storeChar
                CMP     #'/'
                BEQ     @pk_advance
@pk_storeChar   STA     K_PATH_BUF,X
                INX
@pk_advance     INC     ZP_CONF_LO
                BNE     @pk_copyL
                INC     ZP_CONF_HI
                BRA     @pk_copyL
@pk_copyDone    LDA     #$00
                STA     K_PATH_BUF,X
                CPX     #1                      ; at least 1 char?
                BCC     @pk_done                ; no path → use default
                LDA     #1
                STA     _BootConfHasKPath
@pk_done        RTS

;==============================================================================
; Path strings.  Uppercase to match ProDOS on-disk names.  NUL-terminated.
;==============================================================================
; Single-quoted ASC produces low-ASCII (bit 7 clear), matching ProDOS
; on-disk filename bytes.  Double-quoted ASC would set bit 7 and the
; compare against dir entries would never match.  See
; feedback_merlin32_asm.md.
                                                ; Not 'KERNELF' -- a name that is a
                                                ; strict prefix of another entry is
                                                ; needless risk in a directory walk.
PathUnix        ASC     'FGXUNIX',00
PathBootConf    ASC     'ETC/BOOT.CONF',00
PathFont        ASC     'LIB/FONTS/DEFAULT.FNT',00

;------------------------------------------------------------------------------
; THE SAME THREE PATHS IN THEIR 2.11BSD SPELLING (campaign 2.4).
;
; This is the one place the two filesystems genuinely disagree.  ProDOS stores
; a directory name in UPPERCASE and carries the display case in the version
; bytes, so a lowercase userland path matches case-INSENSITIVELY underneath and
; the walker compares uppercase.  2.11BSD names are BYTES: `etc' is not `ETC'.
; The UFS volume therefore stages disk_src verbatim, in its real case, which is
; what makes /bin/sh and /etc/rc work -- and costs stage 2 this second set.
;
; The three kernel banks are NOT here.  They keep their ProDOS names on both
; volumes because /etc/boot.conf names /KERNEL, and renaming them is a change
; to that file as well for no gain while the ProDOS image still exists.
;
; BOTH SETS GO WHEN THE PRODOS ROOT DOES.  Deleting the ProDOS half is then one
; hunk, which is why this is a second table rather than a case-folding trick on
; the first.
;------------------------------------------------------------------------------
UPathUnix       ASC     'fgxunix',00
UPathBootConf   ASC     'etc/boot.conf',00
UPathFont       ASC     'lib/fonts/default.fnt',00

PdPathTbl       DW      PathBootConf            ; X = 0
                DW      PathUnix                ; X = 2
                DW      PathFont                ; X = 4
UfsPathTbl      DW      UPathBootConf
                DW      UPathUnix
                DW      UPathFont

;------------------------------------------------------------------------------
; SelPath -- X selects the path (0 boot.conf, 2 /fgxunix, 4 font); UfsFmt
; the spelling.  Out: ZP_PATH_LO/HI.  MX %11 in and out.
;------------------------------------------------------------------------------
SelPath         MX      %11
                LDA     UfsFmt
                BEQ     @sp_pd
                LDA     UfsPathTbl,X
                STA     ZP_PATH_LO
                LDA     UfsPathTbl+1,X
                STA     ZP_PATH_HI
                RTS
@sp_pd          LDA     PdPathTbl,X
                STA     ZP_PATH_LO
                LDA     PdPathTbl+1,X
                STA     ZP_PATH_HI
                RTS

;------------------------------------------------------------------------------
; Seedling: one data block at SPBlk.  Read directly into KERNEL_BUFFER,
; bump ZP_PASSBLK so the final partial MVN at LoadDone copies it.
;------------------------------------------------------------------------------
Seedling
                LDA     #<KERNEL_BUFFER
                STA     SPBuf
                LDA     #>KERNEL_BUFFER
                STA     SPBuf+1
                JSR     BlkRead
                BCS     @seed_err
                LDA     #0
                STA     ZP_PASSBLK              ; init in case multipass init missed
                INC     ZP_PASSBLK
                STA     ZP_PASSDEST
                LDA     LoadDstOffHi
                STA     ZP_PASSDEST+1
                JMP     LoadDone
@seed_err       JMP     LoadError

;------------------------------------------------------------------------------
; Sapling: key_ptr is an index block.  Low bytes of data block #s at
; [0..255], high bytes at [256..511].  Walk data blocks; multipass-MVN out
; whenever ZP_PASSBLK hits PASS_BLKS.
;------------------------------------------------------------------------------
Sapling
                LDA     #<IDX_BUF
                STA     SPBuf
                LDA     #>IDX_BUF
                STA     SPBuf+1
                JSR     BlkRead
                BCC     @idxOK
                JMP     LoadError

@idxOK          JMP     LoadCommon

;------------------------------------------------------------------------------
; UfsLoad -- the UFS entry to the SAME loop.  There is no index block to read:
; ufs_walk_path already left the dinode in UDinode, and get_blkno maps each
; 512-byte block through it.
;------------------------------------------------------------------------------
UfsLoad         MX      %11
                JMP     LoadCommon

;------------------------------------------------------------------------------
; get_blkno -- 512-byte block LoadBlkIdx of the file being loaded -> SPBlk.
; C=1 is a hard failure; SPBlk zero is a HOLE and the loop fills it.
;
; ONE LOOP AND NOT TWO.  Everything below this line -- the end-of-file guard
; that apple/fgx#218 bought, the sparse-block zero fill that apple/fgx#225
; bought, and the multipass MVN -- is the same code for both filesystems.  A
; second copy for UFS would have been the shorter diff and would have left two
; places for those two fixes to rot in.
;------------------------------------------------------------------------------
get_blkno       MX      %11
                LDA     UfsFmt
                BEQ     @gb_prodos
                JMP     ufs_blkno
@gb_prodos      LDA     LoadBlkIdx+1
                BNE     @gb_tree        ; block 256 and past: a ProDOS TREE,
                                        ;   and a sapling's ONE index block is
                                        ;   all this reader has.  Refused
                                        ;   rather than wrapped to entry 0,
                                        ;   which would read some other part
                                        ;   of the volume and load it as code.
                LDY     LoadBlkIdx
                LDA     IDX_BUF,Y
                STA     SPBlk
                LDA     IDX_BUF+$100,Y
                STA     SPBlk+1
                LDA     #0
                STA     SPBlk+2
                CLC
                RTS
@gb_tree        SEC
                RTS

;------------------------------------------------------------------------------
; LoadCommon -- the block loop both readers run.
;------------------------------------------------------------------------------
LoadCommon      MX      %11
                LDA     #0
                STA     ZP_PASSBLK
                STA     ZP_PASSDEST             ; dest lo = $00
                LDA     LoadDstOffHi            ; dest hi (per-target)
                STA     ZP_PASSDEST+1

; A BLOCK COUNT AND NOT AN END-OF-FILE COMPARE (2026-09-05).  The loop used to
; ask whether blkidx*512 had reached ZP_EOF, and carried an explicit guard
; (apple/fgx#218) for the case where that product wrapped its sixteen bits --
; a 128-block file hung the boot with a blank screen.  A /fgxunix segment is
; up to a FULL bank, whose length is 65536 and whose EOF is therefore zero in
; sixteen bits, so the compare could not express the common case any more.
; Counting down is what the caller already knows and it deletes the wrap: the
; product that overflowed is simply never formed.
@sapLoop        LDA     LoadNblk
                ORA     LoadNblk+1
                BEQ     @sapDone

                LDA     ZP_PASSBLK
                CMP     #PASS_BLKS
                BCC     @doLoad_one
                JSR     @doInterPass

@doLoad_one     JSR     get_blkno
                BCS     @gb_err
                LDA     SPBlk
                ORA     SPBlk+1
                ORA     SPBlk+2
                BEQ     @sapHole

                LDA     #$00
                STA     SPBuf
                LDA     ZP_PASSBLK
                ASL
                CLC
                ADC     #>KERNEL_BUFFER
                STA     SPBuf+1
                JSR     BlkRead
                BCC     @sapNext
                JMP     LoadError

;------------------------------------------------------------------------------
; A PRODOS SPARSE BLOCK -- a zero index entry (apple/fgx#225).
;
; ProDOS omits a block whose contents are entirely zero, and `cadius ADDFILE`
; does exactly that when it stages the kernel images: a 512-byte window of
; zeroes in a linked image costs no block on disk.  There is nothing to READ
; for such a block -- but the destination still has to BE zero.
;
; SKIPPING THE READ IS NOT THE SAME AS WRITING ZEROES, and that was the bug.
; The old code branched straight to @sapNext, which still bumps ZP_PASSBLK, so
; the buffer slot for that block was never touched and the pass MVN carried
; whatever the PREVIOUS image had left in KERNEL_BUFFER to the destination.
; The kernel images all contain such windows today -- measured on the shipping
; disk: /FGX/KERNEL has two (blocks 92-93), /FGX/KERNELFAR five, /FGX/KERNELTTY
; one -- so every boot was loading stale bytes into regions the linker had
; emitted as zero.
;
; WHY IT PRESENTED AS A LAYOUT LOTTERY: whether any given 512-byte window is
; all-zero shifts with ANY change to any of the three images, so the SET of
; holes moves unpredictably as code is added.  A hole landing on scratch is
; harmless; one landing on a table that is read before it is written hangs the
; boot with a blank screen.  That is why adding inert padding to one bank could
; break a build, and why a three-byte change to a DIFFERENT bank could fix it.
;
; The fill is 512 bytes through a ZP pointer because SPBuf is a SmartPort
; parameter field rather than a pointer this code can store through.
;------------------------------------------------------------------------------
@sapHole        LDA     #$00
                STA     ZP_ZFILL_LO
                LDA     ZP_PASSBLK
                ASL                             ; *2 pages, as the read path does
                CLC
                ADC     #>KERNEL_BUFFER
                STA     ZP_ZFILL_HI
                LDY     #$00
                TYA                             ; A = 0, and STA/INY preserve it
@sapHole_p0     STA     (ZP_ZFILL_LO),Y
                INY
                BNE     @sapHole_p0
                INC     ZP_ZFILL_HI             ; second page of the block
@sapHole_p1     STA     (ZP_ZFILL_LO),Y
                INY
                BNE     @sapHole_p1

@sapNext        INC     LoadBlkIdx       ; the file block, 16-bit: it runs on
                BNE     @sapNextN       ;   across segments, so the next one
                INC     LoadBlkIdx+1     ;   starts where this ended
@sapNextN       LDA     LoadNblk         ; ...and the count down to zero
                BNE     @sapNextL
                DEC     LoadNblk+1
@sapNextL       DEC     LoadNblk
                INC     ZP_PASSBLK
                JMP     @sapLoop

@sapDone        JMP     LoadDone
@gb_err         JMP     LoadError

;==============================================================================
; @doInterPass - full pass MVN when ZP_PASSBLK hits PASS_BLKS.
;==============================================================================
@doInterPass    CLC
                XCE
                REP     #$30
                MX      %00
                LDA     #$0000
                TCD
                LDY     ZP_PASSDEST
                LDA     #PASS_PAGES
                JSR     _DoPassMVN
                STY     ZP_PASSDEST
                SEC
                XCE
                MX      %11
                PHK
                PLB
                STZ     ZP_PASSBLK
                RTS

;==============================================================================
; LoadDone - final partial MVN, then JMP kernel.
;==============================================================================
LoadDone        CLC
                XCE
                REP     #$30
                MX      %00
                LDA     #$0000
                TCD                             ; native DP = 0 (MVN needs it)

                SEP     #$20
                MX      %10
                LDA     ZP_PASSBLK
                BEQ     @ld_no_final
                ASL
                STA     ZP_PASSBLK
                REP     #$20
                MX      %00
                LDY     ZP_PASSDEST
                LDA     ZP_PASSBLK
                JSR     _DoPassMVN
@ld_no_final    REP     #$30
                MX      %00

                ; Back to emulation so the caller (LoadDispatch's JSR
                ; from emulation) gets a matched return.  No TCS — the
                ; caller's stack pointer must survive.
                SEC
                XCE
                MX      %11
                PHK
                PLB
                SEC                             ; C=1 success
                RTS

;------------------------------------------------------------------------------
; KernelHandoff - final transition from stage 2 to the kernel.  Reset DP +
; SP to known boot values and JML into bank $02 at the kernel's entry.
; Called after every load has completed (kernel + pre-staged modules).
;
; Before the JML, bring up the Toolbox (TLStartUp/MTStartUp/GetNewID) and
; claim every FGX-owned bank via _NewHandle attr=$C003.  Doing this in the
; loader (rather than the kernel) means MM is already up and every bank
; we own is registered with MM by the time the kernel's first instruction
; runs.  Per Tech Note #78, MM treats a fixed-address claim that conflicts
; with an existing allocation by purging all level-1/2/3 handles before
; returning $0201; claiming as early as possible (loader, before MM has
; allocated anything else) minimises the chance of that conflict.
;
; Brings up the minimum Toolbox state (TL/MT/GetNewID), claims every
; FGX-owned bank, allocates the kernel's bank-0 DP page, then JMLs into
; the kernel.  Halts on any Toolbox/PreClaim failure.
;------------------------------------------------------------------------------
KernelHandoff   MX      %11
                CLC
                XCE                             ; → native
                REP     #$30
                MX      %00

                ; ---- TLStartUp + GetNewID + LoaderAllocKernelBank were moved to
                ; Stage2_Entry (Phase 1b.2) so /KERNEL loads straight into the
                ; kernel handle.  _LoaderUserID + _LoaderKernBank are already set.
                ; MTStartUp stays LAST (below) — heartbeat after every NewHandle.

                ; ---- Claim every FGX-owned bank.  Halts on failure. ----
                ; If boot.conf is present, execute its claim directives;
                ; else fall back to the hardcoded LoaderPreClaim table.
                LDAL    _BootConfPresent
                BEQ     @kh_useDefault
                JSR     ExecuteBootConfClaims
                BCC     @kh_halt
                BRA     @kh_claimDone
@kh_useDefault  JSR     LoaderPreClaim
                BCC     @kh_halt
@kh_claimDone

                ; ---- TN#27 (ProDOS-8 hybrid) direct-boot memory reservation. ----
                ; Reserve the low 128K + $E0/$E1 that GS/OS would protect, so the
                ; MM (and any CDEV/tool/INIT) can't hand out memory FGX uses.  Runs
                ; for both builds (bank-0 + SHR are not relocated).  Must precede
                ; LoaderAllocKernelDP (the kernel DP page lives in the $00/0800
                ; claim) and MTStartUp.
                JSR     LoaderClaimTN27
                BCC     @kh_halt

                ; ---- Copy the loader handoff page into the kernel bank. ----
                ; The kernel CODE already loaded straight into the MM-assigned
                ; bank (_LoaderKernBank, claimed in Stage2_Entry); only the 24-byte
                ; BlkTramp/CoutTramp/_PreStaged handoff, staged in BANK 0
                ; (HANDOFF_STAGE), still needs the MVN to dynbank:FF00.  Bank $02
                ; is never touched.  KFGX_ANCHOR + the entry JML's bank byte are
                ; patched from _LoaderKernBank just before the handoff.
                JSR     LoaderRelocateKernel
                ; (LoaderAllocRestBank moved to Stage2_Entry so _LoaderRestBase is
                ; known before the module prestage; _LoaderRestBase is already set
                ; here — the KFGX_REST_ANCHOR write below reads it.)

                ; ---- Allocate kernel's bank-0 DP page via NewHandle. ----
                ;   attr=$8015 = locked|page|bank|nocross, locationPtr.bank=$00.
                ;   MM picks any free page-aligned bank-0 page.  Loader stashes
                ;   the page address into _LoaderKernelDP and sets D to it
                ;   before JML, so the kernel runs with D pre-set and its very
                ;   first instruction can use DP-relative addressing into the
                ;   MM-tracked page.  Eliminates the prior copy-then-TCD dance.
                JSR     LoaderAllocKernelDP
                BCC     @kh_halt

                ; ---- MTStartUp ($0203) — LAST: arm the heartbeat interrupt only
                ; after every bank/DP NewHandle is done. ----
                LDX     #$0203
                JSL     $E10000
                BCS     @kh_halt

                ; ---- Phase 1a: bring up Text Tools + Desk Manager.  Done in a
                ; subroutine (_LoaderStartTools, after @kh_spin) to keep this hot
                ; path short — inlining it pushed @kh_halt out of BCS range.
                JSR     _LoaderStartTools

                ; ---- Record the live kernel bank in the bank-0 anchor (Phase 1).
                ; Kernel-internal entry installs (syscall tramp / JT / IRQ) derive
                ; their bank from PHK; this is the canonical loader-written record
                ; for diagnostics/probes + any future cross-bank consumer.  Bank =
                ; ^KERNEL_DEST ($02 today; becomes the dynamic NewHandle bank in
                ; Phase 5). ----
                SEP     #$20
                MX      %10
                LDA     _LoaderKernBank         ; the MM-assigned kernel bank
                STAL    KFGX_ANCHOR
                STAL    _KernEntryJML+3         ; patch the entry JML's bank byte
                LDA     #$4B                    ; 'K' magic = anchor valid
                STAL    KFGX_ANCHOR_MAG
                ; Two-handle MM model: the rest-of-OS handle's base bank.
                LDA     _LoaderRestBase         ; MM-assigned bank LoaderAllocRestBank claimed
                STAL    KFGX_REST_ANCHOR
                LDA     #$4B
                STAL    KFGX_REST_ANCHOR_MAG
                LDAL    _LoaderRestBanks        ; CLAIMED count (post small-RAM clamp)
                STAL    KFGX_REST_COUNT         ; → Bank_Init pool bound + block-table
                                                ;   row 0 count (M-3)
                REP     #$20
                MX      %00
                ; REST-claim MM HANDLE handoff (M-4 accounting): the kernel's
                ; block table row 0 records the real NewHandle backing the
                ; boot claim (vmstat -m renders it; future DisposeHandle).
                LDAL    _LoaderRestHandle
                STAL    KFGX_REST_HANDLE
                LDAL    _LoaderRestHandle+2
                STAL    KFGX_REST_HANDLE+2

                LDAL    _LoaderKernelDP
                TCD                             ; D = MM-allocated kernel DP page
                LDA     #$01FF
                TCS                             ; SP = $01FF (kernel re-sets)
_KernEntryJML   JML     KERNEL_DEST             ; bank byte ($02) patched -> dynbank above

@kh_halt        ; Unrecoverable Toolbox/PreClaim failure — hang.
@kh_spin        BRA     @kh_spin

;------------------------------------------------------------------------------
; _LoaderStartTools - Phase 1a: bring up Text Tools ($020C) + Desk Manager ($0205)
; in the loader.  TL ($0201) + Misc ($0203) are already up; the MM is ROM-started.
; Both exercise the dynamic allocator post-claims (a live smoke test) and
; future-proof toolbox use.  Non-critical: no carry check (mirrors the kernel's
; prior DeskStartUp).  Called from KernelHandoff after MTStartUp.
;------------------------------------------------------------------------------
_LoaderStartTools MX %00
                REP     #$30
                MX      %00
                LDX     #$020C                  ; TextStartUp (Text Tool Set)
                JSL     $E10000
                LDX     #$0205                  ; DeskStartUp (Desk Manager)
                JSL     $E10000
                RTS

;------------------------------------------------------------------------------
; LoaderPreClaim - FALLBACK (boot.conf absent/unreadable only).  Mirrors the
; shipped present-path (ExecuteBootConfClaims), which post-Phase-2B fixed-claims
; NOTHING: the kernel + rest-of-OS handles are MM-placed via attrNoSpec (done in
; Stage2_Entry), bank-$00/$01/$E0/$E1 is reserved by LoaderClaimTN27 (called right
; after us), and EVERY region (fonts/KMOD/Kmem/user/console-$03) is now dynamic in
; the rest handle.  So there is no fixed bank left to claim.  Claiming $02..$1F here
; would DOUBLE-CLAIM the rest handle -> $0201 TN#78 purge -> halt; we also do NOT
; walk a fixed-claim table: there is none left.
;
; Entry: M=0, X=0, native.  Exit: C=1 (always — nothing to claim, nothing fails).
;------------------------------------------------------------------------------
LoaderPreClaim  MX      %00
                SEC                             ; nothing fixed to claim (all dynamic)
                RTS

;------------------------------------------------------------------------------
; LoaderClaimRegion - claim arbitrary bank:offset:size via _NewHandle.
; Entry: M=0, X=0, native.
;        _bcParseBank  = bank byte
;        _bcParseOffLo = offset low byte
;        _bcParseOffHi = offset high byte
;        _bcParseSzLo  = size low byte
;        _bcParseSzHi  = size high byte
; Exit:  C=1 success, C=0 fail.
;------------------------------------------------------------------------------
LoaderClaimRegion MX    %00
                PHA                             ; result hi placeholder
                PHA                             ; result lo placeholder
                PEA     $0000                   ; size hi-word (always 0 — we
                                                ; support ≤64K = 16-bit size)
                ; size lo-word from (_bcParseSzLo, _bcParseSzHi).
                SEP     #$20
                MX      %10
                LDAL    _bcParseSzHi
                PHA
                LDAL    _bcParseSzLo
                PHA
                REP     #$20
                MX      %00
                LDAL    _LoaderUserID
                PHA
                PEA     $C003                   ; attr locked|fixed|addr|bank
                ; locationPtr hi-word = (pad=0, bank).
                SEP     #$20
                MX      %10
                LDA     #$00
                PHA                             ; pad
                LDAL    _bcParseBank
                PHA                             ; bank
                ; locationPtr lo-word = (offHi, offLo).
                LDAL    _bcParseOffHi
                PHA
                LDAL    _bcParseOffLo
                PHA
                REP     #$20
                MX      %00
                LDX     #$0902                  ; _NewHandle
                JSL     $E10000
                BCS     @lcr_fail
                PLA                             ; discard handle lo
                PLA                             ; discard handle hi
                SEC
                RTS
@lcr_fail       PLA                             ; discard result placeholder lo (NewHandle-fail stack balance)
                PLA                             ; discard result placeholder hi
                CLC
                RTS

;------------------------------------------------------------------------------
; LoaderClaimTN27 - ProDOS-8 Technical Note #27 ("Hybrid Applications")
; direct-boot memory reservation.  OS_BOOT ($E100BD) == 0 means the boot OS was
; ProDOS 8: nothing is MM-allocated, so FGX must reserve the memory GS/OS would
; normally protect BEFORE MMStartUp -- otherwise any CDEV / tool / INIT that
; NewHandles could be handed memory FGX is already using (bank-0 working RAM,
; the SHR framebuffer at $E1:2000 / its $01 shadow, ...).  Four handles:
;   $00/0800 $B800   main bank-0 working RAM (stacks, BLK_STAGE, DP pages)
;   $01/0800 $B800   aux bank-1 (SHR shadow-write window at $01:2000)
;   $E0/2000 $4000   bank $E0 shadow region
;   $E1/2000 $8000   SHR display: pixels $E1:2000 + SCB $E19D00 + palettes
; GetNewID already used type $1000; MTStartUp runs last (and is now called from
; allocated memory -- the loader at $00:2000 sits inside the $00/0800 claim).
; If OS_BOOT != 0 we were launched by GS/OS and the low 128K is already ours.
; Entry: M=0, X=0, native, _LoaderUserID set.  Exit: C=1 ok / C=0 first fail.
;------------------------------------------------------------------------------
OS_BOOT         EQU     $E100BD
LoaderClaimTN27 MX      %00
                PHK
                PLB                             ; DBR = $00 for the table reads
                SEP     #$20
                MX      %10
                LDAL    OS_BOOT
                BEQ     @ct27_doit              ; 0 -> ProDOS-8 boot: claim
                REP     #$30
                MX      %00
                SEC                             ; GS/OS launched: already reserved
                RTS
@ct27_doit      REP     #$30
                MX      %00
                LDX     #0                      ; row byte-offset (0,5,10,15)
@ct27_loop      SEP     #$20
                MX      %10
                LDA     @ct27_tbl+0,X
                STAL    _bcParseBank
                LDA     @ct27_tbl+1,X
                STAL    _bcParseOffLo
                LDA     @ct27_tbl+2,X
                STAL    _bcParseOffHi
                LDA     @ct27_tbl+3,X
                STAL    _bcParseSzLo
                LDA     @ct27_tbl+4,X
                STAL    _bcParseSzHi
                REP     #$30
                MX      %00
                PHX
                JSR     LoaderClaimRegion
                PLX
                BCC     @ct27_fail
                TXA
                CLC
                ADC     #5
                TAX
                CPX     #20                     ; 4 rows x 5 bytes
                BCC     @ct27_loop
                SEC
                RTS
@ct27_fail      CLC
                RTS
                ; rows: bank, offLo, offHi, szLo, szHi (LoaderClaimRegion args)
@ct27_tbl       DFB     $00,$00,$08,$00,$B8     ; $00:0800 size $B800
                DFB     $01,$00,$08,$00,$B8     ; $01:0800 size $B800
                DFB     $E0,$00,$20,$00,$40     ; $E0:2000 size $4000
                DFB     $E1,$00,$20,$00,$80     ; $E1:2000 size $8000

;------------------------------------------------------------------------------
; ExecuteBootConfClaims - walk BOOT_CONF_BUF; for each line dispatch on
; first char: 'r' = region (3 hex args), 'b' = whole bank (1 hex arg),
; 'u' = user-banks ($0A..$1F).  Other directives ('k' kernel etc.)
; ignored here — handled in earlier passes.
;
; Entry: M=0, X=0, native, _BootConfPresent=1.
; Exit:  C=1 all claims succeeded, C=0 first failed claim.
;------------------------------------------------------------------------------
ExecuteBootConfClaims MX %00
                SEP     #$30                    ; M=1 X=1 (bc_* expect MX %11)
                MX      %11
                JSR     bc_init_cursor
@ebc_loop       JSR     skip_ws_comments
                BCC     @ebc_haveTok
                JMP     @ebc_done
@ebc_haveTok
                LDY     #0
                LDA     (ZP_CONF_LO),Y
                ; Cache first char (lowercased to match either case).
                CMP     #'A'
                BCC     @ebc_dispatch
                CMP     #'Z'+1
                BCS     @ebc_dispatch
                CLC
                ADC     #$20                    ; uppercase → lowercase
@ebc_dispatch   CMP     #'r'
                BEQ     @ebc_region
                CMP     #'b'
                BEQ     @ebc_bank
                ; Unknown / other directive (e.g. `kernel`, or a now-removed
                ; `user-banks` line) — skip it.  user-banks are GONE: the user pool
                ; lives in the MM-placed rest-of-OS handle, not fixed $0A..$1F.
                ; Skipping (rather than claiming) keeps an old boot.conf carrying a
                ; `user-banks` line bootable instead of double-claiming the rest
                ; handle -> $0201 TN#78 purge.
                JSR     bc_skip_to_eol
                BRL     @ebc_loop

@ebc_region     JSR     bc_skip_keyword
                JSR     bc_skip_inline_ws
                JSR     bc_parse_hex_byte
                BCC     @ebc_fail
                STA     _bcParseBank
                JSR     bc_skip_inline_ws
                JSR     bc_parse_hex_word
                BCC     @ebc_fail
                LDA     _bcParseLo
                STA     _bcParseOffLo
                LDA     _bcParseHi
                STA     _bcParseOffHi
                JSR     bc_skip_inline_ws
                JSR     bc_parse_hex_word
                BCC     @ebc_fail
                LDA     _bcParseLo
                STA     _bcParseSzLo
                LDA     _bcParseHi
                STA     _bcParseSzHi
                ; Execute the claim (need M=0 X=0 for NewHandle stack
                ; frame; bc_* are M=1 X=1 — transition cleanly).
                REP     #$30
                MX      %00
                JSR     LoaderClaimRegion
                SEP     #$30
                MX      %11
                BCC     @ebc_fail
                JSR     bc_skip_to_eol
                BRL     @ebc_loop

@ebc_bank       JSR     bc_skip_keyword
                JSR     bc_skip_inline_ws
                JSR     bc_parse_hex_byte
                BCC     @ebc_fail
                ; Claim 64K at A:$0000.
                REP     #$30
                MX      %00
                JSR     LoaderClaim64KBank
                SEP     #$30
                MX      %11
                BCC     @ebc_fail
                JSR     bc_skip_to_eol
                BRL     @ebc_loop

@ebc_done       REP     #$30
                MX      %00
                SEC
                RTS
@ebc_fail       REP     #$30
                MX      %00
                CLC
                RTS

_bcParseBank    DA      0
_bcParseOffLo   DA      0
_bcParseOffHi   DA      0
_bcParseSzLo    DA      0
_bcParseSzHi    DA      0

;------------------------------------------------------------------------------
; LoaderClaim64KBank - claim 64 KB at bank A:$0000 via _NewHandle attr=$C003.
; Entry: A.lo = bank byte (high byte cleared).
; Exit:  C=1 success, C=0 fail.
;------------------------------------------------------------------------------
LoaderClaim64KBank MX %00
                AND     #$00FF
                STAL    _LoaderTmp              ; cache bank
                PHA                             ; result hi placeholder
                PHA                             ; result lo placeholder
                PEA     $0001                   ; size hi ($00010000 = 64K)
                PEA     $0000                   ; size lo
                LDAL    _LoaderUserID
                PHA
                PEA     $C003                   ; attr
                LDAL    _LoaderTmp              ; bank (low byte) in A.lo
                PHA                             ; addr hi word (bank in lo byte)
                PEA     $0000                   ; addr lo word
                LDX     #$0902                  ; _NewHandle
                JSL     $E10000
                BCS     @lc64_fail
                PLA                             ; discard handle lo
                PLA                             ; discard handle hi
                SEC
                RTS
@lc64_fail      PLA                             ; discard result placeholder lo (NewHandle-fail stack balance)
                PLA                             ; discard result placeholder hi
                CLC
                RTS

;------------------------------------------------------------------------------
; LoaderAllocKernelBank - claim KERNEL_BANKS contiguous, bank-aligned banks for the
; kernel's relocated home, the MM picking the bank (no candidate iteration).
;
;   attrNoSpec ($0008) keeps the block OUT of special memory (banks $00/$01/video)
;   so the MM never hands back bank $00.  The MM allocates PAGE-aligned, NOT
;   bank-aligned (probed 2026-06-14: base came back $NN:FD00), so the span is found
;   inside an N+1-bank block and then claimed exactly (_LoaderExactClaim).
;
; Entry: M=0, X=0, native, DP=0, _LoaderUserID set.  Exit: C=1 + _LoaderKernBank =
; aligned base bank byte (+ _LoaderKernHandle = the handle); C=0 on NewHandle failure.
;------------------------------------------------------------------------------
LoaderAllocKernelBank MX %00
                LDA     #KERNEL_BANKS
                JSR     _LoaderExactClaim       ; $E8/$EA = handle, A.lo = bank
                BCC     @lakb_fail
                STAL    _LoaderKernBank
                LDA     $00E8
                STAL    _LoaderKernHandle
                LDA     $00EA
                STAL    _LoaderKernHandle+2
                SEC
@lakb_fail      RTS

;------------------------------------------------------------------------------
; LoaderClaimNBanks - claim _LoaderRestBanks contiguous bank-aligned banks for the
; rest-of-OS, claimed exactly as LoaderAllocKernelBank claims its span
; (_LoaderExactClaim).
; Entry: MX %00, DP=0, _LoaderRestBanks/_LoaderUserID set.  Exit: C=1 + _LoaderRestBase
; (aligned base bank) + _LoaderRestHandle set; C=0 on NewHandle failure.
;------------------------------------------------------------------------------
LoaderClaimNBanks MX %00
                LDAL    _LoaderRestBanks
                AND     #$00FF
                JSR     _LoaderExactClaim       ; $E8/$EA = handle, A.lo = bank
                BCC     @lcnb_fail
                STAL    _LoaderRestBase
                LDA     $00E8
                STAL    _LoaderRestHandle
                LDA     $00EA
                STAL    _LoaderRestHandle+2
                SEC
@lcnb_fail      RTS

;------------------------------------------------------------------------------
; _LoaderExactClaim - A = N: claim N contiguous banks, bank-aligned, as one
; locked attrNoSpec handle, and no more.  The MM allocates PAGE-aligned, not
; bank-aligned, so a block of N+1 banks is taken first to find where an aligned
; N-bank span fits; it is disposed of and the span claimed exactly there with
; attrAddr.  Were that refused, the N+1-bank block is taken again and the span
; rounded up inside it, as before -- a bank of slack, but a boot.
; In:  A = N (16-bit), MX %00, DP=0, _LoaderUserID set.
; Out: C=1, A.lo = aligned base bank, $00E8 = handle lo word, $00EA = hi word;
;      C=0 when no N+1-bank block exists.  Clobbers X, Y, $00EC, $00EE.
;------------------------------------------------------------------------------
_LoaderExactClaim MX %00
                STA     $00EC                   ; N
                JSR     _LoaderClaimSlack       ; N+1 banks -> $E8/$EA, A = bank
                BCC     @lec_fail
                STA     $00EE                   ; the aligned base it shows
                LDA     $00EA
                PHA
                LDA     $00E8
                PHA
                LDX     #$1002                  ; _DisposeHandle
                JSL     $E10000
                PHA                             ; result space hi
                PHA                             ; result space lo
                LDA     $00EC
                PHA                             ; size hi word = N*$10000 bytes
                PEA     $0000                   ; size lo word
                LDAL    _LoaderUserID
                PHA
                PEA     $800A                   ; attrLocked|attrNoSpec|attrAddr
                LDA     $00EE
                AND     #$00FF
                PHA                             ; location hi word = the bank
                PEA     $0000                   ; location lo word
                LDX     #$0902                  ; _NewHandle
                JSL     $E10000
                BCS     @lec_slack
                PLA
                STA     $00E8
                PLA
                STA     $00EA
                LDA     $00EE
                AND     #$00FF
                SEC
                RTS
@lec_slack      PLA                             ; discard result space
                PLA
                LDA     $00EC
                JSR     _LoaderClaimSlack       ; refused: the slack way
@lec_fail       RTS

;------------------------------------------------------------------------------
; _LoaderClaimSlack - A = N: NewHandle of N+1 banks, locked, attrNoSpec, the
; bank picked by the MM; the aligned base is rounded up inside it.
; Out: C=1, A.lo = aligned base bank, $00E8/$00EA = handle; C=0 refused.
;------------------------------------------------------------------------------
_LoaderClaimSlack MX %00
                PHA                             ; N, under the result space
                PHA                             ; result space hi
                PHA                             ; result space lo
                LDA     5,S
                INC                             ; +1 bank of alignment slack
                AND     #$00FF
                PHA                             ; size hi word = (N+1)*$10000 bytes
                PEA     $0000                   ; size lo word
                LDAL    _LoaderUserID
                PHA
                PEA     $8008                   ; attrLocked|attrNoSpec (MM picks bank)
                PEA     $0000                   ; locationPtr hi (ignored)
                PEA     $0000                   ; locationPtr lo (ignored)
                LDX     #$0902                  ; _NewHandle
                JSL     $E10000
                BCS     @lcs_fail
                PLA                             ; handle lo word
                STA     $00E8
                PLA                             ; handle hi word
                STA     $00EA
                PLA                             ; drop N
                JSR     _LoaderDerefAlignedBank ; A.lo = bank-aligned base bank
                SEC
                RTS
@lcs_fail       PLA                             ; discard result space
                PLA
                PLA                             ; drop N
                CLC
                RTS

;------------------------------------------------------------------------------
; LoaderAllocRestBank - claim the rest-of-OS handle via attrNoSpec (LoaderClaimNBanks).
; The MM picks the bank; NO candidate-address iteration.  Keeps the clamp-on-fail: if
; the MM can't satisfy RESTOFOS_BANKS (+1) contiguous banks, clamp the usable count
; down by one and retry (graceful degradation on small machines); fails below
; RESTOFOS_MIN_BANKS.  Entry: MX %00, DP=0.  Exit: C=1 + _LoaderRestBase/_LoaderRestHandle
; set (by LoaderClaimNBanks); C=0 → KernelHandoff halts.
;   NOTE: the user-facing "OS pool clamped, add RAM" howl is deferred — the loader
;   runs before any console; record/howl belongs in the kernel once logging is up
;   (follow-up).  An 8 MB machine never clamps.
;------------------------------------------------------------------------------
LoaderAllocRestBank MX %00
                LDA     #RESTOFOS_BANKS
                STAL    _LoaderRestBanks
@lar_try        JSR     LoaderClaimNBanks
                BCS     @lar_got
                LDAL    _LoaderRestBanks
                AND     #$00FF
                DEC                             ; clamp the usable count down by one
                STAL    _LoaderRestBanks
                CMP     #RESTOFOS_MIN_BANKS
                BCC     @lar_floor              ; below the floor → give up
                BRA     @lar_try                ; retry the smaller size
@lar_floor      CLC                             ; signal failure → halt
                RTS
@lar_got        SEC
                RTS

;------------------------------------------------------------------------------
; _LoaderDerefAlignedBank - deref an MM handle to its block base and return the
; bank-ALIGNED base bank.  The MM allocates page-aligned (NOT bank-aligned), so we
; round UP: aligned = base_bank + (base_lo16 != 0 ? 1 : 0).  Callers over-allocate one
; extra bank so the rounded-up N-bank span fits inside the handle.  See §9.3.
; In:  $00E8/$00E9 = handle lo word, $00EA = handle bank (caller-set; DP=0, MX %00).
; Out: A (low byte) = aligned base bank.  Clobbers X, Y.
;------------------------------------------------------------------------------
_LoaderDerefAlignedBank MX %00
                LDY     #$0000
                LDA     [$E8],Y                 ; block base lo16 (handle → master ptr)
                TAX                             ; X = base lo16
                LDY     #$0002
                LDA     [$E8],Y                 ; block base bank (low byte) + hi byte
                AND     #$00FF
                CPX     #$0000                  ; base already bank-aligned?
                BEQ     @ldab_done
                INC                             ; round up to next bank boundary
@ldab_done      RTS

;------------------------------------------------------------------------------
; LoaderRelocateKernel - MVN the 24-byte loader handoff block from the BANK-0
; staging area (HANDOFF_STAGE) to the MM-assigned kernel bank's :FF00:
;   * handoff $00:HANDOFF_STAGE.. (24 B BlkTramp/CoutTramp/_PreStaged) -> :FF00
; Bank $02 is NEVER touched now — the kernel code loads straight into the kernel
; bank (Phase 1b.2) and the handoff stages in bank 0 (not $02:FF00), so a
; MicroDrive Turbo owning $02 is fully clear of FGX.  The kernel reads this block
; DBR-relative from its own bank (block.s/boot_console.s/main.s).
; Entry: M=0, X=0, native, _LoaderKernBank set.  Exit: DBR restored to the
; loader bank ($00).  Clobbers A/X/Y.
;------------------------------------------------------------------------------
LoaderRelocateKernel MX %00
                ; patch the handoff MVN dst-bank operand byte (+1) = _LoaderKernBank
                SEP     #$20
                MX      %10
                ; PROBE (temp): stamp dynbank + magic to the bank-0 anchor BEFORE
                ; the MVN, so a crash in the relocate still leaves it readable at
                ; $00:032C (page 3 survives an MVN that targets $xx:FF00).
                LDAL    _LoaderKernBank
                STAL    $00032C
                LDA     #$4B
                STAL    $00032D
                LDAL    _LoaderKernBank
                STAL    _RelocHandMVN+1
                REP     #$30
                MX      %00
                ; copy: handoff bank-0 HANDOFF_STAGE -> dynbank:FF00 (24 bytes)
                LDX     #HANDOFF_STAGE          ; src offset (bank 0)
                LDY     #$FF00                  ; dst offset (kernel bank)
                LDA     #$0018-1
_RelocHandMVN   MVN     $00,$02                 ; src=$00 (bank-0 staging); dst (+1) patched -> dynbank
                ; MVN leaves DBR=dynbank; restore DBR = loader bank ($00).
                PHK
                PLB
                RTS

;==============================================================================
; LoaderToolbox state - tiny pad in bank-0 below stage 2's load area.
;==============================================================================
_LoaderUserID   DA      0                       ; GetNewID result
_LoaderClaimIdx DA      0                       ; PreClaim loop index
_LoaderTmp      DA      0                       ; PreClaim scratch (hi/lo reorder)
_LoaderKernelDP DA      0                       ; bank-0 lo word of kernel DP page
_LoaderKDPHandle DS     4                       ; 4-byte MM handle for kernel DP
_LoaderKernBank DA      0                       ; relocated kernel bank (LoaderAllocKernelBank)
_LoaderKernHandle DS    4                       ; 4-byte MM handle for the kernel's 64K bank
_LoaderRestBase DA      0                       ; rest-of-OS base bank (candidate / result)
_LoaderRestBanks DA     0                       ; rest-of-OS bank count (clamps down on no-fit)
_LoaderRestHandle DS    4                       ; 4-byte MM handle for the rest-of-OS block

;------------------------------------------------------------------------------
; LoaderAllocKernelDP - allocate 256-byte bank-0 page for kernel's direct
; page via _NewHandle.  Stores the page address in _LoaderKernelDP and
; the handle in _LoaderKDPHandle.  Caller (KernelHandoff) then TCDs and
; JMLs into the kernel; kernel runs with D = _LoaderKernelDP from the
; very first instruction (no migration needed).
;
; Entry: M=0, X=0, native, _LoaderUserID populated.
; Exit:  C=1 success (page addr in _LoaderKernelDP), C=0 fail.
;------------------------------------------------------------------------------
LoaderAllocKernelDP MX %00
                ; The kernel's own direct page, FGX_DP_KKERN ($0900): fixed,
                ; no MM NewHandle -- a full $00/0800 TN#27 claim leaves the MM
                ; no free bank-0 page, so a direct page can't be NewHandle'd.
                ; The kernel runs with D = this page from the handoff TCD, and
                ; zeroes it again itself before it becomes the template every
                ; task's kernel page is copied from (main.s).
                LDA     #FGX_DP_KKERN
                STAL    _LoaderKernelDP
                LDA     #0                      ; no MM handle for a fixed page
                STAL    _LoaderKDPHandle
                STAL    _LoaderKDPHandle+2
                ; Zero the page so kernel DP scratch starts clean.  Long-
                ; indirect via $E8 so this is DBR-independent, matching the
                ; loader's other bank-0 access.
                LDA     #FGX_DP_KKERN
                STA     $00E8                   ; ptr lo word = page addr
                SEP     #$20
                MX      %10
                STZ     $00EA                   ; ptr bank = $00
                REP     #$30
                MX      %00
                LDA     #0
                LDY     #254                    ; 256 bytes / 2 = 128 stores
@lkdp_zL        STA     [$E8],Y
                DEY
                DEY
                BPL     @lkdp_zL
                SEC
                RTS

;==============================================================================
; _DoPassMVN - MVN A pages from $00:KERNEL_BUFFER → $02:Y.
;==============================================================================
_DoPassMVN      MX      %00
                STA     $00
                LDX     #KERNEL_BUFFER
@dpm_loop       LDA     #$00FF
_DoPass_MVN_op  MVN     $00,$02                 ; +1 = dst bank, patched per
                                                ; load target (kernel=$02,
                                                ; prodos=$05).
                DEC     $00
                BNE     @dpm_loop
                RTS

;==============================================================================
; BlkRead - SmartPort READ BLOCK using SPParams.  C=0 ok, C=1 fail.
; Called from emulation mode only; reset Merlin's MX tracker since the
; preceding LoadDone / _DoPassMVN sections leave it at %00.
;==============================================================================
BlkRead         MX      %11
SPEntry         JSR     $C500                   ; patched
                DFB     SP_READ_BLOCK
                DW      SPParams
                RTS

SPParams
SPParamCnt      DFB     $03
SPUnit          DFB     $01
SPBuf           DW      DIR_BUF                 ; overwritten per call
SPBlk           DFB     $02
                DFB     $00
                DFB     $00

;------------------------------------------------------------------------------
; LoadError - unrecoverable stage-2 load failure; hang.
;------------------------------------------------------------------------------
LoadError       MX      %11                     ; reached from emulation code
@hang           BRA     @hang

;==============================================================================
; THE UFS READER (campaign 2.3).  Stage 2 reads the kernel banks, /ETC's two
; config files and the preloaded modules BY PATH -- and from 2.3 it can do
; that on a 2.11BSD filesystem as well as on ProDOS.  `walk_path' and
; `LoadDispatch' pick between the two on UfsFmt, which `ufs_probe' sets once
; from the volume itself, so every caller above is unchanged.
;
; EVERY CONSTANT AND OFFSET HERE CAME OFF THE VENDORED HEADERS, NOT MEMORY:
;
;   h/fs.h:27-28   SUPERB 1, ROOTINO 2
;   h/fs.h:87-88   itoo(x) = ((x) + 2*INOPB - 1) % INOPB
;                  itod(x) = ((x) + 2*INOPB - 1) / INOPB      with INOPB 16,
;                  so slot = (ino+31) & 15 and block = (ino+31) >> 4.
;                  Check it on the root: ino 2 -> block 2, slot 1.
;   h/inode.h:74-102  dinode: di_mode 0, di_nlink 2, di_uid 4, di_gid 6,
;                  di_size 8 (4 B), di_addr[7] 12 (4 B each -- and 12 is the
;                  ADDROFF mdec/rauboot.s bakes), di_flags 50.  64 bytes.
;   h/dir.h:25-30  direct: d_ino 0, d_reclen 2, d_namlen 4, d_name 6.
;   h/dir.h:16     DIRBLKSIZ 512, and :33-42 that an entry never straddles one.
;
; BYTE ORDER.  16-bit fields overlay a 65816 directly.  32-bit fields are
; stored HIGH WORD FIRST, little-endian within each word (measured on the real
; 11/70, 2026-08-09), so a daddr_t at +0 has its LOW word at +2/+3 and its
; HIGH word at +0/+1.  Every volume this loader can address is under 65536
; filesystem blocks, so the high word must be ZERO and a nonzero one is
; refused rather than truncated.
;==============================================================================

UFS_ROOTINO     EQU     2
UFS_NDADDR      EQU     4               ; direct addresses in a dinode
UFS_DIRBLKSIZ   EQU     512
UFS_DI_SIZE     EQU     8               ; dinode: off_t di_size
UFS_DI_ADDR     EQU     12              ; dinode: daddr_t di_addr[7]
; di_addr[NDADDR], the single indirect.  SPELLED OUT, because Merlin32
; evaluates strictly LEFT TO RIGHT with no operator precedence:
; `UFS_DI_ADDR+4*UFS_NDADDR' is (12+4)*4 = 64, which reads past the end of a
; 64-byte dinode.  It assembled, it read zero, and a zero indirect address is
; a legal HOLE -- so the kernel loaded its four direct blocks and then
; zero-filled the other 54, and the machine reset into ROM with nothing on
; screen to say why.  Measured with a two-line fixture: `LDY #12+4*4' emits 64.
UFS_DI_IND1     EQU     28
UFS_DI_IND2     EQU     32              ; di_addr[NDADDR+1], the double
                                        ;   indirect.  SPELLED OUT for the
                                        ;   reason the line above is.
UFS_IFMT        EQU     $F0             ; high byte of the mode's type field
UFS_IFDIR       EQU     $40             ; ...IFDIR 040000 >> 8

;==============================================================================
; ufs_probe - which filesystem is on the boot volume?
;
; Device block 2 is the ProDOS VOLUME DIRECTORY and also the first half of the
; 2.11BSD SUPERBLOCK (filesystem block 1, and fsbtodb(1) == 2), so one read
; answers it.  The test is a POSITIVE ProDOS one: a volume directory's first
; block has a zero prev-block pointer and a first entry whose storage-type
; nibble is $F.  A superblock's first word is fs_isize, which is the i-list
; size in blocks and is never zero on a volume mkfs made, so the two cannot be
; confused.  Anything that is not ProDOS is treated as UFS and will fail in
; the walk if it is neither -- which is the same failure an unreadable ProDOS
; volume already gives.
;==============================================================================
ufs_probe       MX      %11
                LDA     #$00
                STA     UfsFmt
                LDA     #<UBLK_BUF
                STA     SPBuf
                LDA     #>UBLK_BUF
                STA     SPBuf+1
                LDA     #$02
                STA     SPBlk
                LDA     #$00
                STA     SPBlk+1
                STA     SPBlk+2
                JSR     BlkRead
                BCS     @pr_done        ; unreadable: leave it ProDOS and let
                                        ;   the walk report it as before
                LDA     UBLK_BUF        ; prev_block == 0 ?
                ORA     UBLK_BUF+1
                BNE     @pr_ufs
                LDA     UBLK_BUF+4      ; storage type nibble == $F ?
                AND     #$F0
                CMP     #$F0
                BEQ     @pr_done
@pr_ufs         LDA     #$01
                STA     UfsFmt
@pr_done        RTS

;==============================================================================
; ufs_bread - read filesystem block UBlkNo (16-bit) into UBLK_BUF.
;
; fsbtodb(b) == b << 1: a 1024-byte filesystem block is two device blocks.
; C=0 on success.  ALWAYS invalidates the indirect-block cache, because it is
; about to overwrite the buffer that cache describes.
;==============================================================================
ufs_bread       MX      %11
                LDA     #$FF
                STA     UIndCache
                STA     UIndCache+1
                LDA     #>UBLK_BUF
                BRA     ufs_breadGo

;==============================================================================
; ufs_bread2 - the same read, into the DOUBLE indirect block's own buffer.
;
; A SECOND ENTRY AND NOT A PARAMETER AT THE CALL SITE, because the tag and the
; buffer have to move together: whichever buffer is overwritten is the one
; whose cached block number just became a lie.
;==============================================================================
ufs_bread2      MX      %11
                LDA     #$FF
                STA     UInd2Cache
                STA     UInd2Cache+1
                LDA     #>UIND2_BUF

ufs_breadGo     STA     UBufPg
                LDA     UBlkNo
                ASL
                STA     SPBlk
                LDA     UBlkNo+1
                ROL
                STA     SPBlk+1
                LDA     #$00
                ROL                     ; bit 16 of the doubled block number
                STA     SPBlk+2
                LDA     #$00            ; both buffers are page-aligned, so a
                STA     SPBuf           ;   page byte names one on its own
                LDA     UBufPg
                STA     SPBuf+1
                JSR     BlkRead
                BCS     @br_done
                INC     SPBlk
                BNE     @br_hi
                INC     SPBlk+1
                BNE     @br_hi
                INC     SPBlk+2
@br_hi          LDA     UBufPg
                CLC
                ADC     #$02            ; the block's second 512-byte half
                STA     SPBuf+1
                JSR     BlkRead
@br_done        RTS

;==============================================================================
; ufs_ginode - fetch dinode UIno into UDinode.
;
; itod/itoo, h/fs.h:87-88, with INOPB 16.  C=0 on success.
;==============================================================================
ufs_ginode      MX      %11
                LDA     UIno
                CLC
                ADC     #31             ; + 2*INOPB - 1
                STA     UBlkNo
                LDA     UIno+1
                ADC     #$00
                STA     UBlkNo+1
                LDA     UBlkNo
                AND     #$0F            ; itoo: the low nibble, BEFORE shifting
                STA     UISlot
                LDX     #4              ; itod: >> 4
@gi_sh          LSR     UBlkNo+1
                ROR     UBlkNo
                DEX
                BNE     @gi_sh
                JSR     ufs_bread
                BCS     @gi_err
                ; UBLK_BUF + slot*64, built as (slot << 8) >> 2
                LDA     #$00
                STA     ZP_UPTR_LO
                LDA     UISlot
                STA     ZP_UPTR_HI
                LSR     ZP_UPTR_HI
                ROR     ZP_UPTR_LO
                LSR     ZP_UPTR_HI
                ROR     ZP_UPTR_LO
                LDA     ZP_UPTR_HI
                CLC
                ADC     #>UBLK_BUF
                STA     ZP_UPTR_HI
                LDY     #63
@gi_copy        LDA     (ZP_UPTR_LO),Y
                STA     UDinode,Y
                DEY
                BPL     @gi_copy
                CLC
                RTS
@gi_err         SEC
                RTS

;==============================================================================
; ufs_daddr - read the daddr_t at (ZP_UPTR_LO),Y+0..3 into UBlkNo.
;
; HIGH WORD FIRST: +0/+1 is the high half and must be zero here, +2/+3 is the
; low half.  C=1 refuses a block past 65535 rather than truncating it into a
; read of some other part of the volume.  A 65535-block volume is 64 MB, twice
; what the 16-bit SmartPort block count can address anyway.
;==============================================================================
ufs_daddr       MX      %11
                LDA     (ZP_UPTR_LO),Y
                INY
                ORA     (ZP_UPTR_LO),Y
                BNE     @da_big
                INY
                LDA     (ZP_UPTR_LO),Y
                STA     UBlkNo
                INY
                LDA     (ZP_UPTR_LO),Y
                STA     UBlkNo+1
                CLC
                RTS
@da_big         SEC
                RTS

;==============================================================================
; ufs_bmap - filesystem block ULbn (16-bit) of the file in UDinode -> UBlkNo.
;
; FOUR DIRECT AND TWO INDIRECT LEVELS, and the second level is what /fgxunix
; bought.  It used to be one, sized against "a 58 KB kernel bank": one level
; covers 4 + 256 = 260 filesystem blocks, and one image carrying core, far,
; tty and the three boot modules is 308 -- so the load ran out of map 48
; blocks from the end.
;
; THERE IS NO THIRD LEVEL AND THERE CANNOT BE ONE HERE.  Upstream's own
; standalone reader walks all three: `sbmap' picks the level by shifting a
; running bound,
;
;    sh = 0; nb = 1; bn -= NADDR-3;
;    for (j=3; j>0; j--) { sh += NSHIFT; nb <<= NSHIFT;
;                          if (bn < nb) break; bn -= nb; }
;
; and then indexes each level with `i = (bn>>sh) & NMASK'
; (examples/2.11BSD/usr/sys/pdpstand/sys.c:161-208, NSHIFT 8 and NMASK 0377
; from h/fs.h:117-118).  Stopping at two is not a shortcut off that: ULbn is
; SIXTEEN BITS, and 4 + 256 + 65536 already exceeds every value it can hold,
; so no lbn this loader can express reaches the triple.  A file that needed it
; would be refused by ULbn's own width before arriving here.
;
; EACH LEVEL HAS ITS OWN BUFFER, WHICH IS ALSO UPSTREAM'S SHAPE -- `b[j]',
; tagged by block number in `blknos[j]' (sys.c:198-204).  One shared buffer
; would defeat the cache entirely on a two-level walk: reading the DOUBLE
; indirect block evicts the SINGLE indirect block that the next 255 lbns all
; want, so every data block would pay four extra device reads instead of the
; two that the whole 256-block span pays now.  A block-number tag also needs
; no invalidating when the file changes, which an index-keyed cache would.
;
; C=0 and UBlkNo set on success.  UBlkNo zero is a HOLE at ANY level, not an
; error -- `sbmap' returns 0 the same way, at its `bnvoid' -- and the caller
; zero-fills, exactly as the ProDOS path does for a sparse block.
;==============================================================================
ufs_bmap        MX      %11
                LDA     ULbn+1
                BNE     @bm_ind         ; >= 256, so certainly indirect
                LDA     ULbn
                CMP     #UFS_NDADDR
                BCS     @bm_ind
                ; direct: di_addr[lbn], four bytes each
                LDA     #<UDinode
                STA     ZP_UPTR_LO
                LDA     #>UDinode
                STA     ZP_UPTR_HI
                LDA     ULbn
                ASL
                ASL                     ; lbn * 4
                CLC
                ADC     #UFS_DI_ADDR
                TAY
                JMP     ufs_daddr

@bm_ind         ; rem = lbn - NDADDR.  A rem under 256 is the single indirect
                ; block's own range; everything above it is the double's,
                ; indexed by rem - 256.  That is `bn -= nb' with nb = NINDIR,
                ; one turn of sbmap's level loop.
                LDA     ULbn
                SEC
                SBC     #UFS_NDADDR
                STA     URem
                LDA     ULbn+1
                SBC     #$00
                STA     URem+1
                BEQ     @bm_one         ; high byte zero -> one level

                ; --- Double indirect ------------------------------------
                ; The low byte indexes the SINGLE block this one names, the
                ; high byte (less the 256 the single level covered) indexes
                ; the DOUBLE block -- `(bn>>sh) & NMASK' at sh = 8 and sh = 0.
                ; rem >= 256 here, so the subtract cannot borrow.
                LDA     URem
                STA     UTmp
                LDA     URem+1
                SEC
                SBC     #$01
                STA     UInd2Ix
                LDA     #<UDinode
                STA     ZP_UPTR_LO
                LDA     #>UDinode
                STA     ZP_UPTR_HI
                LDY     #UFS_DI_IND2
                JSR     ufs_daddr
                BCS     @bm_err
                LDA     UBlkNo
                ORA     UBlkNo+1
                BEQ     @bm_hole        ; no double indirect block at all
                LDA     UBlkNo
                CMP     UInd2Cache
                BNE     @bm_read2
                LDA     UBlkNo+1
                CMP     UInd2Cache+1
                BEQ     @bm_have2
@bm_read2       LDA     UBlkNo          ; ufs_bread2 clears the tag, so the
                STA     UInd2Sav        ;   number is kept here and written
                LDA     UBlkNo+1        ;   back only once the read succeeded
                STA     UInd2Sav+1
                JSR     ufs_bread2
                BCS     @bm_err
                LDA     UInd2Sav
                STA     UInd2Cache
                LDA     UInd2Sav+1
                STA     UInd2Cache+1
@bm_have2       LDA     #>UIND2_BUF
                STA     UIdxPg
                LDA     UInd2Ix
                JSR     ufs_idx4
                JSR     ufs_daddr       ; -> the SINGLE indirect block
                BCS     @bm_err
                BRA     @bm_single

; THE TWO EXITS SIT BETWEEN THE LEVELS, and that placement is load-bearing
; rather than tidy: both halves reach them with an ordinary relative branch
; only from here.  At the bottom, where they were, the double-indirect half's
; branches were out of range and merlin32 refused the file.
@bm_hole        LDA     #$00
                STA     UBlkNo
                STA     UBlkNo+1
                CLC
                RTS
@bm_err         SEC
                RTS

@bm_one         ; Single indirect: di_addr[NDADDR] names the block and the
                ; entry wanted is rem, which is under 256 on this road.
                LDA     URem
                STA     UTmp
                LDA     #<UDinode
                STA     ZP_UPTR_LO
                LDA     #>UDinode
                STA     ZP_UPTR_HI
                LDY     #UFS_DI_IND1
                JSR     ufs_daddr
                BCS     @bm_err

@bm_single      ; UBlkNo names a single indirect block, from either road, and
                ; UTmp is the entry wanted in it.
                LDA     UBlkNo
                ORA     UBlkNo+1
                BEQ     @bm_hole        ; no indirect block at all, so every
                                        ;   block it would cover is a hole
                ; Already in UBLK_BUF?  The data blocks go to KERNEL_BUFFER,
                ; so nothing else in the load loop disturbs it, and caching it
                ; turns one indirect read per 512-byte block into one per 256.
                LDA     UBlkNo
                CMP     UIndCache
                BNE     @bm_read
                LDA     UBlkNo+1
                CMP     UIndCache+1
                BEQ     @bm_have
@bm_read        LDA     UBlkNo          ; ufs_bread clears the tag, so the
                STA     UTmp2           ;   number is kept here and written
                LDA     UBlkNo+1        ;   back only once the read succeeded
                STA     UTmp2+1
                JSR     ufs_bread
                BCS     @bm_err
                LDA     UTmp2
                STA     UIndCache
                LDA     UTmp2+1
                STA     UIndCache+1
@bm_have        LDA     #>UBLK_BUF
                STA     UIdxPg
                LDA     UTmp
                JSR     ufs_idx4
                JMP     ufs_daddr

;==============================================================================
; ufs_idx4 - point ZP_UPTR at entry A of a 256-entry daddr_t block, Y = 0.
;
; ZP_UPTR = UIdxPg:0000 + A*4.  Both indirect buffers are page-aligned, so the
; base contributes nothing to the low byte and only its page adds in.  One
; copy rather than two because the double and single levels index identically
; -- `bap[i]' is the same expression at every level of sbmap's walk.
;==============================================================================
ufs_idx4        MX      %11
                PHA
                ASL
                ASL
                STA     ZP_UPTR_LO
                PLA
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR                     ; (index*4) >> 8
                CLC
                ADC     UIdxPg
                STA     ZP_UPTR_HI
                LDY     #$00
                RTS

;==============================================================================
; ufs_dirlook - find the UNameLen bytes at (ZP_PATH_LO) in the directory whose
; dinode is in UDinode.  On success UIno holds d_ino and C=0.
;
; Entries are variable length and never straddle a DIRBLKSIZ boundary
; (h/dir.h:33-42), so a 1024-byte filesystem block is simply two 512-byte runs
; of them and one cursor walks both.  A zero d_reclen is refused rather than
; skipped: it is the one corruption that would make this loop never end.
;==============================================================================
ufs_dirlook     MX      %11
                BRA     @dl_start
@dl_fail        SEC                     ; the exit for the block-level branches
                RTS                     ;   below; @dl_failB serves the scan
@dl_save        LDA     ZP_PATH_LO
                STA     _path_save_lo
                LDA     ZP_PATH_HI
                STA     _path_save_hi
                RTS
@dl_restore     LDA     _path_save_lo
                STA     ZP_PATH_LO
                LDA     _path_save_hi
                STA     ZP_PATH_HI
                RTS
@dl_start       LDA     #$00
                STA     ULbn
                STA     ULbn+1
@dl_blk         ; done when lblkno(offset) has passed the directory's size
                LDA     ULbn+1
                BNE     @dl_fail        ; a 256+ block directory: not at boot
                LDA     ULbn
                ASL                     ; * 1024, as a HIGH byte (>> 8)
                ASL
                BCS     @dl_fail
                CMP     UDinode+UFS_DI_SIZE+3   ; the size's low word, high byte
                BCC     @dl_read
                BNE     @dl_fail
                LDA     UDinode+UFS_DI_SIZE+2   ; ...and its low byte
                BEQ     @dl_fail
@dl_read        ; SmartPort firmware clobbers zero page, so the path pointer
                ; is saved across BOTH calls below.  ufs_bmap is not exempt:
                ; it reads an indirect block for anything past the fourth.
                JSR     @dl_save
                JSR     ufs_bmap
                JSR     @dl_restore
                BCS     @dl_fail
                LDA     UBlkNo
                ORA     UBlkNo+1
                BNE     @dl_have
                JMP     @dl_next        ; a hole in a directory holds no names
@dl_have        JSR     @dl_save
                JSR     ufs_bread
                PHP
                JSR     @dl_restore
                PLP
                BCS     @dl_fail

                LDA     #$00
                STA     UOff
                STA     UOff+1
@dl_ent         ; ZP_UPTR = UBLK_BUF + UOff.  UBLK_BUF is page aligned, which
                ; is what lets the offset's low byte be the pointer's outright.
                LDA     UOff
                STA     ZP_UPTR_LO
                LDA     UOff+1
                CLC
                ADC     #>UBLK_BUF
                STA     ZP_UPTR_HI

                LDY     #$00
                LDA     (ZP_UPTR_LO),Y
                STA     UEntIno         ; d_ino, kept because the compare below
                INY                     ;   moves ZP_UPTR off the record head
                LDA     (ZP_UPTR_LO),Y
                STA     UEntIno+1
                INY
                LDA     (ZP_UPTR_LO),Y
                STA     UEntLen         ; d_reclen
                INY
                LDA     (ZP_UPTR_LO),Y
                STA     UEntLen+1
                ORA     UEntLen
                BEQ     @dl_failB       ; zero d_reclen: the scan would not end

                LDA     UEntIno
                ORA     UEntIno+1
                BEQ     @dl_skip        ; a free slot
                LDY     #$05
                LDA     (ZP_UPTR_LO),Y  ; d_namlen hi -- MAXNAMLEN is 63
                BNE     @dl_skip
                DEY
                LDA     (ZP_UPTR_LO),Y  ; d_namlen lo
                CMP     UNameLen
                BNE     @dl_skip

                ; Same length; compare the bytes.  Case SENSITIVE, which is
                ; the difference from ProDOS this reader exists to honour.
                LDA     ZP_UPTR_LO
                CLC
                ADC     #$06            ; d_name
                STA     ZP_UPTR_LO
                LDA     ZP_UPTR_HI
                ADC     #$00
                STA     ZP_UPTR_HI
                LDY     UNameLen
                DEY
@dl_cmp         LDA     (ZP_UPTR_LO),Y
                CMP     (ZP_PATH_LO),Y
                BNE     @dl_skip        ; UOff never moved, so the skip below
                DEY                     ;   is still correct after the +6
                BPL     @dl_cmp

                LDA     UEntIno
                STA     UIno
                LDA     UEntIno+1
                STA     UIno+1
                CLC
                RTS

@dl_skip        LDA     UOff
                CLC
                ADC     UEntLen
                STA     UOff
                LDA     UOff+1
                ADC     UEntLen+1
                STA     UOff+1
                CMP     #$04            ; offset >= 1024: block exhausted
                BCS     @dl_next
                JMP     @dl_ent
@dl_next        INC     ULbn
                BNE     @dl_b2
                INC     ULbn+1
@dl_b2          JMP     @dl_blk
@dl_failB       SEC
                RTS

;==============================================================================
; ufs_walk_path - the UFS half of walk_path.
;
; In:  ZP_PATH_LO/HI -> NUL-terminated path.  Leading and repeated '/' are
;      consumed, so 'KERNEL' and '/KERNEL' are the same request.
; Out: C=1 success, with UDinode holding the leaf's dinode and
;      ZP_EOF_LO/MID its size.  C=0 on any failure, matching the ProDOS
;      walker's convention rather than the carry-as-error one used inside
;      this reader.
;
; A FILE OVER 65535 BYTES IS REFUSED HERE.  ZP_EOF is sixteen bits and the
; shared load loop compares against it, which is the same limit the ProDOS
; path documents at apple/fgx#218 -- there a 128-block file ran the loop away
; and hung the boot with a blank screen.  Refusing at the walk means the same
; file fails where it can be attributed instead.
;==============================================================================
ufs_walk_path   MX      %11
                LDA     #<UFS_ROOTINO
                STA     UIno
                LDA     #$00
                STA     UIno+1
                JSR     ufs_ginode
                BCS     @wu_bad

@wu_comp        LDY     #$00
@wu_slash       LDA     (ZP_PATH_LO),Y
                CMP     #'/'
                BNE     @wu_have
                INC     ZP_PATH_LO
                BNE     @wu_slash
                INC     ZP_PATH_HI
                BRA     @wu_slash
@wu_have        LDA     (ZP_PATH_LO),Y
                BEQ     @wu_bad         ; no leaf name

                ; The component runs to the next '/' or the NUL.
                LDY     #$00
@wu_len         LDA     (ZP_PATH_LO),Y
                BEQ     @wu_gotlen
                CMP     #'/'
                BEQ     @wu_gotlen
                INY
                BNE     @wu_len
@wu_gotlen      STY     UNameLen

                ; The parent has to BE a directory, or a name would be looked
                ; up in file data.  IFDIR is 040000, so the mode's high byte
                ; masked with IFMT is $40.
                LDA     UDinode+1
                AND     #UFS_IFMT
                CMP     #UFS_IFDIR
                BNE     @wu_bad

                JSR     ufs_dirlook
                BCS     @wu_bad
                JSR     ufs_ginode
                BCS     @wu_bad

                ; Step the path over the component just consumed.
                LDA     ZP_PATH_LO
                CLC
                ADC     UNameLen
                STA     ZP_PATH_LO
                LDA     ZP_PATH_HI
                ADC     #$00
                STA     ZP_PATH_HI

                LDY     #$00
                LDA     (ZP_PATH_LO),Y
                BEQ     @wu_leaf
                JMP     @wu_comp

@wu_leaf        ; di_size is HIGH WORD FIRST: +0/+1 is the high half and
                ; +2/+3 the low, little-endian within each.  So the size's
                ; three carried bytes are +2, +3 and +0, and +1 is the only
                ; one that must be zero -- a file at or past 16 MB, which no
                ; block number this loader forms could reach anyway.
                ;
                ; IT USED TO REFUSE ON +0 AS WELL, capping a boot file at
                ; 65,535 bytes, and that was the last of the three ceilings
                ; /fgxunix had to clear: a 314,880-byte image walked, was
                ; refused HERE, and hung in LoadError with a blank screen.
                LDA     UDinode+UFS_DI_SIZE+1
                BNE     @wu_bad
                LDA     UDinode+UFS_DI_SIZE+2
                STA     ZP_EOF_LO
                LDA     UDinode+UFS_DI_SIZE+3
                STA     ZP_EOF_MID
                LDA     UDinode+UFS_DI_SIZE
                STA     ZP_EOF_HI
                LDA     #STOR_SAPLING   ; the shared load loop's shape; the
                STA     ZP_STOR         ;   UFS branch is taken on UfsFmt
                SEC
                RTS
@wu_bad         CLC
                RTS

;==============================================================================
; ufs_blkno - the UFS half of get_blkno: 512-byte block LoadBlkIdx of the file
; in UDinode -> SPBlk.  Zero means a hole, which the caller zero-fills.
;
; The loop counts DEVICE blocks so that one loop, one end-of-file guard and
; one hole-fill serve both readers.  A filesystem block is two of them, so the
; logical block is LoadBlkIdx >> 1 and the half is its low bit.
;==============================================================================
ufs_blkno       MX      %11
                LDA     LoadBlkIdx+1     ; blkidx >> 1, over sixteen bits: one
                LSR                     ;   image is 615 device blocks, so the
                STA     ULbn+1          ;   index no longer fits a byte
                LDA     LoadBlkIdx
                ROR
                STA     ULbn
                LDA     #$00
                ROL                     ; the bit shifted out: which half
                STA     UHalf           ; NOT UTmp: ufs_bmap uses that for the
                JSR     ufs_bmap        ;   indirect entry index
                BCS     @ub_err
                LDA     UBlkNo
                ORA     UBlkNo+1
                BEQ     @ub_hole
                LDA     UBlkNo          ; fsbtodb: << 1, then + the half
                ASL
                STA     SPBlk
                LDA     UBlkNo+1
                ROL
                STA     SPBlk+1
                LDA     #$00
                ROL
                STA     SPBlk+2
                LDA     SPBlk
                CLC
                ADC     UHalf
                STA     SPBlk
                BCC     @ub_ok
                INC     SPBlk+1
                BNE     @ub_ok
                INC     SPBlk+2
@ub_ok          CLC
                RTS
@ub_hole        STA     SPBlk           ; A is zero here
                STA     SPBlk+1
                STA     SPBlk+2
                CLC
                RTS
@ub_err         SEC
                RTS

;==============================================================================
; UFS reader storage.  ABSOLUTE and not zero page: SmartPort firmware clobbers
; zero page, and everything here has to survive a BlkRead.
;==============================================================================
UfsFmt          DFB     $00             ; 0 = ProDOS, 1 = 2.11BSD
UIno            DW      $0000           ; current inode number
UBlkNo          DW      $0000           ; a FILESYSTEM block number
ULbn            DW      $0000           ; a logical block within a file
UOff            DW      $0000           ; cursor within a directory block
UEntIno         DW      $0000           ; the entry under the cursor
UEntLen         DW      $0000
UIndCache       DW      $FFFF           ; which indirect block UBLK_BUF holds
UInd2Cache      DW      $FFFF           ; ...and which one UIND2_BUF holds
UInd2Sav        DW      $0000           ; its number, across the read that
                                        ;   invalidates the tag
UInd2Ix         DFB     $00             ; the double block's entry index
URem            DW      $0000           ; lbn - NDADDR, before the level split
UBufPg          DFB     $00             ; which buffer ufs_breadGo is filling
UIdxPg          DFB     $00             ; which buffer ufs_idx4 is indexing
UTmp            DFB     $00
UHalf           DFB     $00             ; which 512-byte half of a fs block
UTmp2           DW      $0000
UISlot          DFB     $00             ; itoo(): the inode's slot in its block
UNameLen        DFB     $00             ; the path component being looked up
UDinode         DS      64              ; the working dinode, 2.11BSD's 64 bytes
