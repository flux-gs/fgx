;==============================================================================
; jumptable.s - Core jump table at $00:032E bank-0 JT gateway (was $02FE00;
; relocatable kernel) — runtime-built at boot.
;
; Public:
;   _JT_Init        Walk _JT_Targets, write 4-byte JML cells into $00:0334+;
;                   write ABI version word + core build word + reserved at
;                   $00:032E..$000333.  Call once from FGX_Entry.
;                   MX %00 entry; A/X/Y clobbered.
;
; Impl wrappers (Phase 1 wires three; remaining slots route to a stub):
;   _Sys_ConPutCharImpl  $00:0350 target — JSRs _BootCon_PutChar, RTLs
;   _Sys_KernLogImpl     $00:0374 target — JSRs Kern_LogStr, RTLs
;   _Sys_PanicImpl       $00:0378 target — emits "PANIC" then halts
;   _Phase1_StubHalt     shared target for the 15 unwired slots; red border
;                        + busy-loop on any accidental call
;
; Architecture: runtime-built table.  See docs/superpowers/plans/2026-05-
; 14-phase1-jumptable.md decision log for why-not-link-time.
;
; NOTE: slots are 4 bytes apart (JML = 1-byte opcode + 24-bit target), not
; 3 as the original spec stated.  See note in include/modules.s.
;==============================================================================

;------------------------------------------------------------------------------
; _JT_Init - emit the jump table into RAM at $00:032E (bank-0 JT gateway;
; was $02FE00).
;
; Walks the 32-entry _JT_Targets table (3 bytes per entry: lo/mid/bank of
; the impl target — _JT_Targets has 32 entries, slots 0..31).  For each:
; writes JML opcode ($5C) at $00:0334+4*i,
; then the 3-byte target address.  Also writes the 6-byte header
; (ABI version + core build word + reserved) at $00:032E..$000333.
;
; Called once from FGX_Entry.  Idempotent (safe to call again, though we
; only do once).
;
; In:  none.  MX %00.  DBR = kernel-bank (set by FGX_Entry's PHK/PLB;
;      $02 = assembly ORG).
; Out: A/X/Y clobbered.  No error return (no failure modes).
;------------------------------------------------------------------------------
_JT_Init        MX  %00
                PHP
                ; --- Header: ABI version word + core build word + reserved ---
                LDA     #MOD_ABI_VERSION
                STAL    MOD_JT_ABI_VER          ; $00:032E := $0001 (16-bit store)
                ; Core build identity — the sum of every kernel address the
                ; module manifests export, computed at ASSEMBLY time from the
                ; labels themselves (kernel_build_id.s, generated).  Modules
                ; carry the same word in their FGXM header; Mod_Load compares
                ; the two and refuses a module built against another kernel,
                ; whose baked addresses would all point at the wrong byte.
                LDA    |_kernBuildId
                STAL    MOD_JT_CORE_BUILD       ; $00:0330 := this build's id
                LDA     #$0000
                STAL    MOD_JT_RESERVED         ; $00:0332 := $0000

                ; --- Slot cells: 32 × (1 B JML opcode + 3 B target) ---
                ; X = byte offset within table cells past header (0, 4, ..., 80)
                ; Y = byte offset within _JT_Targets (0, 3, ..., 60)
                LDX     #$0000
                LDY     #$0000
@jt_loop
                SEP     #$20
                MX      %10
                ; JML opcode at $00:0334 + X
                LDA     #$5C                    ; JML opcode
                STAL    SYS_BLKPIN,X            ; SYS_BLKPIN = $00:0334; first slot base

                ; 3-byte target from _JT_Targets+Y to $00:0335+X
                LDA:    _JT_Targets,Y
                STAL    SYS_BLKPIN+1,X
                INY
                LDA:    _JT_Targets,Y
                STAL    SYS_BLKPIN+2,X
                INY
                ; bank byte = our own running kernel bank (PHK), not the table's
                ; DFB $00.  Makes every JT cell's JML follow the kernel to whatever
                ; bank the loader places it in (relocatable).  The DFB $00 bytes in
                ; _JT_Targets are now dead padding kept only for the 3-byte stride.
                PHK
                PLA
                STAL    SYS_BLKPIN+3,X
                INY                             ; consume the (now-dead) DFB $00 byte

                REP     #$20
                MX      %00

                ; Advance X by 4 (next slot)
                INX
                INX
                INX
                INX
                CPX     #128                    ; 32 slots × 4 bytes
                BCC     @jt_loop

                ; --- init the 3 bank-0 JSL-trampoline cells (chardev / net /
                ;     modload dispatch): write the $22 (JSL) opcode at +0 and the
                ;     $6B (RTL) at +4; the 24-bit target (+1/+2/+3) is patched per
                ;     dispatch.  Relocated from the kernel bank so `JSL <cell>` is
                ;     relocation-invariant (see include/memmap.s). ---
                SEP     #$20
                MX      %10
                LDA     #$22                    ; JSL opcode
                STAL    _cdTrampJSL
                STAL    _netTrampJSL
                STAL    _mlEntryJSL
                LDA     #$6B                    ; RTL
                STAL    _cdTrampJSL+4
                STAL    _netTrampJSL+4
                STAL    _mlEntryJSL+4
                REP     #$30
                MX      %00

                PLP
                RTS

;------------------------------------------------------------------------------
; _JT_Targets - 32 × (lo / mid / bank) = 96 bytes of impl target addresses.
;
; Entry layout: 3 bytes in little-endian order per entry: low byte, mid
; byte, bank byte.  Merlin32's `DA` emits the low + mid bytes (2 bytes)
; for a label; we follow with a separate `DFB $00` for the bank byte.
; The bank byte is now dead padding ($00): _JT_Init fills each cell's
; runtime bank from PHK (the live kernel bank), so impl labels following
; the kernel to its MM-assigned bank ($02 = assembly ORG only).
;------------------------------------------------------------------------------
_JT_Targets
                DA      _Sys_BlkPinImpl         ; slot 0  SYS_BLKPIN (P3.3;
                DFB     $00                     ;   reused SYS_KMALLOC stub)
                DA      _Sys_BlkUnpinImpl       ; slot 1  SYS_BLKUNPIN (P3.3;
                DFB     $00                     ;   reused SYS_KFREE stub)
                DA      _Sys_BlkPinZImpl        ; slot 2  SYS_BLKPINZ (P3.3-iii-B;
                DFB     $00                     ;   reused SYS_BANKALLOC stub)
                DA      _Sys_KCallImpl          ; slot 3  SYS_KCALL (reused the
                DFB     $00                     ;   never-wired SYS_BANKFREE)
                DA      _Sys_BlkReadImpl        ; slot 4  SYS_BLKREAD
                DFB     $00
                DA      _Sys_BlkWriteImpl       ; slot 5  SYS_BLKWRITE
                DFB     $00
                DA      _Sys_BlkStatusImpl      ; slot 6  SYS_BLKSTATUS
                DFB     $00
                DA      _Sys_ConPutCharImpl     ; slot 7  SYS_CONPUTCHAR
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 8  SYS_CONWRITEROW
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 9  SYS_PATHRESOLVE, retired
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 10 SYS_FCBALLOC, retired
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 11 SYS_FCBFREE, retired
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 12 MOD_REGISTERFST
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 13 MOD_REGISTERCONSOLE
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 14 MOD_REGISTERINPUT
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 15 MOD_REGISTERSOUND
                DFB     $00
                DA      _Sys_KernLogImpl        ; slot 16 SYS_KERNLOG
                DFB     $00
                DA      _Sys_PanicImpl          ; slot 17 SYS_PANIC
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 18 SYS_BMENSUREVOL, retired
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 19 SYS_FSDIRENTRY2STAT, retired
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 20 SYS_FSFILLMOUNTSLOT, retired
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 21 SYS_BMFREE, retired
                DFB     $00
                DA      _Phase1_StubHalt        ; slot 22 SYS_BMALLOC, retired
                DFB     $00
                DA      _Mod_RegisterCharDevImpl ; slot 23 MOD_REGISTERCHARDEV
                DFB     $00
                DA      _Mod_LogImpl            ; slot 24 SYS_MODLOG (reused retired SYS_INSTALL_SCC_IRQ)
                DFB     $00
                DA      _Sys_SimInstallImpl     ; slot 25 SYS_SIM_INSTALL
                DFB     $00
                DA      _Sys_SimRemoveImpl      ; slot 26 SYS_SIM_REMOVE
                DFB     $00
                ; slots 27-31: net.mod direct kernel-call wrappers, relocated
                ; from net's baked-$02 `JSL _Net_KCall_*` to bank-0 JT slots so
                ; they follow the kernel.  Targets are RTL wrappers in
                ; net_dispatch.s; the DFB $00 is dead padding (_JT_Init fills the
                ; cell bank from PHK).
                DA      _Net_KCall_W5WriteIp    ; slot 27 SYS_NETKC_W5WRITEIP
                DFB     $00
                DA      _Net_KCall_FcbAlloc     ; slot 28 SYS_NETKC_FCBALLOC
                DFB     $00
                DA      _Net_KCall_SockFdToDesc ; slot 29 SYS_NETKC_SOCKFDTODESC
                DFB     $00
                DA      _Net_KCall_ConPollKey   ; slot 30 SYS_NETKC_CONPOLLKEY
                DFB     $00
                DA      _Net_KCall_Sleep        ; slot 31 SYS_NETKC_SLEEP
                DFB     $00

;------------------------------------------------------------------------------
; _Phase1_StubHalt - shared target for unwired slots.  Sets red border
; ($E0C034 := $01) and busy-loops.  Any accidental call into an unwired
; slot from a Phase 2+ module manifests as a red border and a wedged
; kernel — clearly visible failure mode.
;
; Reached via JML from a jump-table slot.  Module doesn't get a return.
;------------------------------------------------------------------------------
_Phase1_StubHalt    MX  %00
                SEP     #$20
                LDA     #$01
                STAL    $E0C034                 ; border = red
@hl             BRA     @hl

;------------------------------------------------------------------------------
; _Sys_Stub_Removed - tombstone for retired jumptable slots.  Returns
; C=0 + A=ESIM_GONE so any orphaned caller fails loudly with a known
; errno rather than misrouting.  Currently used by slot 24
; SYS_INSTALL_SCC_IRQ (deprecated by SYS_SIM_INSTALL).
;------------------------------------------------------------------------------
_Sys_Stub_Removed MX %00
                LDA     #ESIM_GONE
                CLC
                RTL

;------------------------------------------------------------------------------
; _Sys_ConPutCharImpl - SYS_CONPUTCHAR slot ($00:0350) target.
;
; Routes to _BootCon_PutChar (Phase 0).  When Phase 4 console.mod
; registers, _Mod_RegisterConsole re-patches $00:0350+1/+2/+3 to point at
; the module's PutChar entry, replacing this impl.
;
; In:  A = ASCII char (low byte).  MX %00.
; Out: A/X-hi/Y-hi clobbered (per _BootCon_PutChar's ABI).  DBR/DP/MX
;      preserved.
;
; Reached via JML from $00:0350 (caller's JSL pushed PBR+PC; JML doesn't
; change stack).  Returns via RTL.
;------------------------------------------------------------------------------
_Sys_ConPutCharImpl MX  %00
                JSR     _BootCon_PutChar
                RTL

;------------------------------------------------------------------------------
; _Sys_KernLogImpl - SYS_KERNLOG slot ($00:0374) target.
;
; Routes to Kern_LogStr.  Modules call `JSL SYS_KERNLOG` with X = msg ptr
; (kernel-bank for now; cross-bank deferred to Phase 2 when modules become
; real).  Kern_LogStr reads from _conStrPtr (DP word) so the impl shims
; X into that slot before the JSR.
;
; In:  X = ptr to null-terminated string in the kernel bank.  MX %00.
; Out: A/Y clobbered.  X/MX/DBR/DP preserved (PHP/PLP wraps).
;------------------------------------------------------------------------------
_Sys_KernLogImpl    MX  %00
                PHP
                REP     #$30
                MX      %00
                STX     _conStrPtr
                JSR     Kern_LogStr
                PLP
                RTL

;------------------------------------------------------------------------------
; _Mod_LogImpl - SYS_MODLOG slot ($00:0394, reused retired slot 24) target.
;
; device_printf-style detail logger: emits "<_curModName>: <detail>\n".  The
; kernel owns the "<name>: " prefix (_curModName, set by modload.s for the
; module currently in mod_init); the module passes only the detail text.
;
; In:  X = bank-relative ptr to a NUL-terminated detail string in the CALLER's
;      (module's) bank.  MX %00.  Caller DBR = caller bank.
; Out: A/Y clobbered.  X/MX/DBR/DP preserved (PHP/PLP + PHX/PLX + PHB/PLB).
;
; _curModName is a kernel-bank string, so log it with DBR = kernel bank
; (PHK/PLB), then restore the caller's DBR to read the detail DBR-relative
; (mirroring _Sys_KernLogImpl's module-bank string read).
;------------------------------------------------------------------------------
_Mod_LogImpl        MX  %00
                PHP
                REP     #$30
                MX      %00
                PHX                             ; save detail offset (caller bank)
                PHB                             ; save caller DBR
                PHK
                PLB                             ; DBR = kernel bank
                LDA     #_curModName            ; "<name>" (kernel-bank string)
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     #_modLogSep             ; ": "
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                PLB                             ; DBR = caller (module) bank
                PLX                             ; restore detail offset
                STX     _conStrPtr
                JSR     Kern_LogStrNoEOL        ; "<detail>" (caller-bank string)
                JSR     Kern_LogEOL
                PLP
                RTL

_modLogSep          ASC     ': ',$00

;------------------------------------------------------------------------------
; _Sys_KCallImpl - SYS_KCALL slot 3 ($00:0340) target.  THE MULTIPLEXED
; SERVICE ENTRY: X selects the service, A/Y carry its arguments.
;
; Why a selector instead of one slot per service: the 32-cell gateway lives in
; 134 bytes of the firmware-free bank-0 window and cannot grow, so services
; that are not hot must share a cell.  See the SYS_KCALL block in
; include/modules.s for the rest of that argument.
;
; KSVC_KMALLOC and KSVC_KFREE are the first two, and they close a real hole:
; until now a module could not allocate kernel heap AT ALL.  Slots 0 and 1
; were once named SYS_KMALLOC/SYS_KFREE, were never wired, and were later
; reused for the block-cache pin bridge -- so a module that called them got a
; red border and a wedged machine.  src/modules/bpf/bpf.s says so in its own
; header, and works around it by having the KERNEL allocate its capture block.
;
; Register marshalling is the point of this routine.  Kmalloc/Kfree pass their
; 24-bit pointer through _kmallocResult, a kernel-bank static; a module cannot
; reach that without baking a kernel address, which is precisely what we are
; trying not to make it do.  So the pointer crosses the gateway in registers.
;
; No PHP/PLP: the carry IS the return value.  M/X are set explicitly and left
; at %00, which is the documented entry and exit state.
;
; In:  X = service number.  A/Y = service arguments.  MX %00.
;      Caller's DBR = anything (saved and restored).
; Out: C=1 + service results, or C=0 + A = errno.  X clobbered unless the
;      service documents otherwise.  DBR restored.
;------------------------------------------------------------------------------
_Sys_KCallImpl      MX  %00
                PHB                             ; caller's DBR
                PHK
                PLB                             ; DBR = kernel bank
                ; The two oldest arms are now the FARTHEST away -- the service
                ; list has grown past an 8-bit branch.  BNE-over-BRL rather
                ; than reordering the arms, because the arm order is
                ; append-only ABI and reordering it to suit a branch range is
                ; how a renumber sneaks in.
                CPX     #KSVC_KMALLOC
                BNE     @kc_n0
                BRL     @kc_malloc
@kc_n0          CPX     #KSVC_KFREE
                BNE     @kc_n1
                BRL     @kc_free
@kc_n1          ANOP
                CPX     #KSVC_LOGSTRNE
                BNE     @kc_s1
                BRL     @kc_logstr
@kc_s1         ANOP
                CPX     #KSVC_LOGDEC16
                BNE     @kc_s2
                BRL     @kc_logdec
@kc_s2         ANOP
                CPX     #KSVC_LOGHEX8
                BNE     @kc_s3
                BRL     @kc_loghex
@kc_s3         ANOP
                CPX     #KSVC_LOGEOL
                BNE     @kc_s4
                BRL     @kc_logeol
@kc_s4         ANOP
                CPX     #KSVC_SLEEP
                BNE     @kc_s5
                BRL     @kc_sleep
@kc_s5         ANOP
                CPX     #KSVC_WAKEUP
                BNE     @kc_s6
                BRL     @kc_wakeup
@kc_s6         ANOP
                CPX     #KSVC_TTYDELIVERSIG
                BNE     @kc_s7
                BRL     @kc_ttysig
@kc_s7         ANOP
                CPX     #KSVC_TTYOPEN
                BNE     @kc_s8
                BRL     @kc_ttyopen
@kc_s8         ANOP
                CPX     #KSVC_TTYCOOKEDDEF
                BNE     @kc_s9
                BRL     @kc_ttycooked
@kc_s9         ANOP
                CPX     #KSVC_TASKLOOKUP
                BNE     @kc_s10
                BRL     @kc_tasklookup
@kc_s10        ANOP
                CPX     #KSVC_FCBFREE
                BNE     @kc_s11
                BRL     @kc_fcbfree
@kc_s11        ANOP
                CPX     #KSVC_FCBLOOKUPPTR
                BNE     @kc_s12
                BRL     @kc_fcblookup
@kc_s12        ANOP
                CPX     #KSVC_SIGRAISE
                BNE     @kc_s13
                BRL     @kc_sigraise
@kc_s13        ANOP
                CPX     #KSVC_BLKIO
                BNE     @kc_s14
                BRL     @kc_blkio
@kc_s14        ANOP
                CPX     #KSVC_BLKREADS
                BNE     @kc_s15
                BRL     @kc_blkreads
@kc_s15        ANOP
                CPX     #KSVC_SLEEPUN
                BNE     @kc_s16
                BRL     @kc_sleepun
@kc_s16        ANOP
                CPX     #KSVC_CURPID
                BNE     @kc_s17
                BRL     @kc_curpid
@kc_s17        ANOP
                CPX     #KSVC_FINDVTABLE
                BNE     @kc_s18
                BRL     @kc_findvtable
@kc_s18        ANOP
@kc_s19        ANOP
                CPX     #KSVC_TICKS
                BNE     @kc_s20
                BRL     @kc_ticks
@kc_s20        ANOP
                CPX     #KSVC_CDLOOKUP
                BNE     @kc_s21
                BRL     @kc_cdlookup
@kc_s21        ANOP
                CPX     #KSVC_CDOPEN
                BNE     @kc_s22
                BRL     @kc_cdopen
@kc_s22        ANOP
                CPX     #KSVC_CDCLOSE
                BNE     @kc_s23
                BRL     @kc_cdclose
@kc_s23        ANOP
                CPX     #KSVC_CDREAD
                BNE     @kc_s24
                BRL     @kc_cdread
@kc_s24        ANOP
                CPX     #KSVC_CDWRITE
                BNE     @kc_s25
                BRL     @kc_cdwrite
@kc_s25        ANOP
                CPX     #KSVC_CDDREAD
                BNE     @kc_s26
                BRL     @kc_cddread
@kc_s26        ANOP
                CPX     #KSVC_CDDWRITE
                BNE     @kc_s27
                BRL     @kc_cddwrite
@kc_s27        ANOP
                CPX     #KSVC_TTYPGRP
                BNE     @kc_s28
                BRL     @kc_ttypgrp
@kc_s28        ANOP
                CPX     #KSVC_TTYSETPGRP
                BNE     @kc_s29
                BRL     @kc_ttysetpgrp
@kc_s29        ANOP
                CPX     #KSVC_TTYINTRQUIT
                BNE     @kc_s30
                BRL     @kc_ttyintrquit
@kc_s30        ANOP
                CPX     #KSVC_TTYWINSZ
                BNE     @kc_s31
                BRL     @kc_ttywinsz
@kc_s31        ANOP
                CPX     #KSVC_TTYLOPEN
                BNE     @kc_s32
                BRL     @kc_ttylopen
@kc_s32        ANOP
                CPX     #KSVC_TTYMODEM
                BNE     @kc_s33
                BRL     @kc_ttymodem
@kc_s33        ANOP
                CPX     #KSVC_TTYLCLOSE
                BNE     @kc_s34
                BRL     @kc_ttylclose
@kc_s34        ANOP
                CPX     #KSVC_TTYPTYOPROC
                BNE     @kc_s35
                BRL     @kc_ttyptyoproc
@kc_s35        ANOP
                CPX     #KSVC_TTYOUTQUIO
                BNE     @kc_s37
                BRL     @kc_ttyoutquio
@kc_s37        ANOP
                CPX     #KSVC_TTYOUTQAVAIL
                BNE     @kc_s38
                BRL     @kc_ttyoutqavail
@kc_s38        ANOP
                CPX     #KSVC_TTYSTOPPED
                BNE     @kc_s39
                BRL     @kc_ttystopped
@kc_s39        ANOP
                CPX     #KSVC_TTYSELECT
                BNE     @kc_s41
                BRL     @kc_ttyselect
@kc_s41        CPX     #KSVC_TTYPTCINPUT
                BNE     @kc_s42
                BRL     @kc_ttptcinput
@kc_s42        CPX     #KSVC_TTYPTCWRITABLE
                BNE     @kc_s43
                BRL     @kc_ttptcwritable
@kc_s43        CPX     #KSVC_TTYREAD
                BNE     @kc_s44
                BRL     @kc_ttyread
@kc_s44        CPX     #KSVC_TTYWRITE
                BNE     @kc_s45
                BRL     @kc_ttywrite
@kc_s45        CPX     #KSVC_CDSETTTYIDX
                BNE     @kc_s46
                BRL     @kc_cdsetttyidx
@kc_s46        CPX     #KSVC_TTYIRQINPUT
                BNE     @kc_s47
                BRL     @kc_ttyirqinput
@kc_s47        CPX     #KSVC_TTYCARRIER
                BNE     @kc_s48
                BRL     @kc_ttycarrier
@kc_s48        CPX     #KSVC_CDIOCTL
                BNE     @kc_s49
                BRL     @kc_cdioctl
@kc_s49        CPX     #KSVC_CDPOLL
                BNE     @kc_s50
                BRL     @kc_cdpoll
@kc_s50        ANOP
                CPX     #KSVC_CURUID
                BNE     @kc_s51
                BRL     @kc_curuid
@kc_s51        ANOP
                CPX     #KSVC_CURGID
                BNE     @kc_s52
                BRL     @kc_curgid
@kc_s52        ANOP
                CPX     #KSVC_CONBACKEND
                BNE     @kc_s40
                BRL     @kc_conbackend
@kc_s40        ANOP
                CPX     #KSVC_UNPNAME
                BNE     @kc_s54
                BRL     @kc_unpname
@kc_s54        ANOP
                CPX     #KSVC_TIME
                BNE     @kc_s55
                BRL     @kc_time
@kc_s55        ANOP
                CPX     #KSVC_BANKGRANT
                BNE     @kc_s56
                BRL     @kc_bankgrant
@kc_s56        ANOP
                CPX     #KSVC_BANKFREE
                BNE     @kc_s57
                BRL     @kc_bankfree
@kc_s57        ANOP
                CPX     #KSVC_BLKSTALE
                BNE     @kc_s58
                BRL     @kc_blkstale
@kc_s58        ANOP
                CPX     #KSVC_BLKIOCTL
                BNE     @kc_s59
                BRL     @kc_blkioctl
@kc_s59        ANOP
                ; Unknown service.  A module built against a NEWER kernel can
                ; ask for one that does not exist here; say so instead of
                ; halting.  (Two services do not earn a jump table -- a
                ; compare chain is smaller.  Convert when the list grows.)
                PLB
                LDA     #ENOSYS
                CLC
                RTL

                ; --- KSVC_KMALLOC: A = bytes, Y = M_* type ---
@kc_malloc      CPY     #M_LAST
                BCS     @kc_badtype
                CPY     #M_FREE+1               ; M_FREE is not an allocation
                BCC     @kc_badtype
                PHY
                PLX                             ; X = type, as Kmalloc wants
                JSR     Kmalloc                 ; C=0 -> A = errno
                BCC     @kc_out
                ; C=1: _kmallocResult holds lo/hi/bank.  Return offset in A,
                ; bank in X -- the module has no way to read a kernel static.
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX                             ; X = bank
                LDA     _kmallocResult          ; A = 16-bit offset
                SEC
@kc_out         PLB
                RTL

@kc_badtype     PLB
                LDA     #EINVAL
                CLC
                RTL

                ; --- Log helpers.  Kern_Log* are DBR-safe (SYS_KERNLOG has
                ; relied on that since Phase 1), so the string arm hands the
                ; CALLER's bank back first and lets Kern_LogStrNoEOL read the
                ; string DBR-relative from there.  _conStrPtr is direct page,
                ; so it is bank-independent either way. ---
@kc_logstr      PLB                             ; DBR = caller's bank
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                SEC
                RTL
@kc_logdec      JSR     Kern_LogDec16
                PLB
                SEC
                RTL
@kc_loghex      JSR     Kern_LogHex8
                PLB
                SEC
                RTL
@kc_logeol      JSR     Kern_LogEOL
                PLB
                SEC
                RTL

                ; --- KSVC_KFREE: A = offset, Y = bank ---
@kc_free        STA     _kmallocResult
                SEP     #$20
                MX      %10
                TYA
                STA     _kmallocResult+2
                REP     #$20
                MX      %00
                JSR     Kfree                   ; silent on NULL; no error path
                PLB
                SEC
                RTL

                ; --- pty.mod's scheduler + tty callbacks.  Y carries any
                ; argument the kernel routine wants in X, because X is the
                ; service selector here (see include/modules.s). ---
                ; THE VERDICT COMES BACK IN A, NOT IN THE CARRY, and that is
                ; the whole of apple/fgx#28's kernel half.  This arm used to
                ; `SEC` unconditionally like every other one, because in the
                ; KCALL contract the carry means "service dispatched" (C=0 + A
                ; = ENOSYS is how an unknown service answers).  So the sleep's
                ; own C=1 "you were interrupted" was overwritten before it
                ; could reach the module, and pty.mod -- which had by then
                ; moved out of the core bank -- could not learn it had been
                ; interrupted at all.
                ;
                ; Propagating the carry instead would have collided with that
                ; contract: C=0 would then mean BOTH "slept normally" and
                ; "this kernel has no such service", which a module built
                ; against a newer kernel cannot tell apart.  A is free (_sleep
                ; reports only in C), so the verdict travels there and the
                ; carry keeps meaning what it means everywhere else.
@kc_sleep       JSR     _sleep                  ; A = chan; MAY SWITCH TASKS --
                                                ;   the caller's return address
                                                ;   into the module bank rides
                                                ;   the task's kernel stack
                ; Branch rather than `LDA #0 / ADC #0`: the add would carry a
                ; silent dependency on the decimal flag being clear, which is
                ; true here and is exactly the kind of thing that stops being
                ; true without anyone noticing.
                LDA     #0                      ; (LDA does not touch carry)
                BCC     @kc_slp_ok
                LDA     #1                      ; interrupted: signal pending
@kc_slp_ok      PLB
                SEC                             ; service dispatched, as always
                RTL

                ; --- KSVC_SLEEPUN: A = chan.  The UNINTERRUPTIBLE one ---
                ;
                ; A DIFFERENT ROUTINE, not a mode of the arm above.  _sleep
                ; returns C=1 without blocking when an actionable signal is
                ; pending; _sleepUn always blocks and always returns C=0,
                ; because its callers have no error path to take.  Routing both
                ; services at one arm would need a flag, and sched.s explains
                ; at length why that distinction lives in the program counter.
                ;
                ; The SEC below is the SERVICE's "call succeeded", not the
                ; sleep's verdict -- _sleepUn has no verdict to report, and it
                ; must not start pretending it has one.  The note that used to
                ; sit here said the interruptible arm above set SEC
                ; unconditionally too, so a module could not learn that
                ; KSVC_SLEEP returned early, and that "the day something does,
                ; that arm needs to propagate the carry".  apple/fgx#28 was
                ; that day: pty.mod's three waits ask.  It answers in A rather
                ; than in the carry, for the reason given up there -- so this
                ; arm is unchanged, and A here is still whatever _sleepUn left.
@kc_sleepun     JSR     _sleepUn                ; A = chan; MAY SWITCH TASKS
                PLB
                SEC
                RTL
                ; ABSOLUTE, NOT THE DIRECT PAGE, and that is apple/fgx#311's
                ; panic.  `_curTask' became a PER-PAGE IDENTITY when the kernel
                ; direct page went per-task, and memmap.s says _kCurPid exists
                ; for "the two places that must ask [who is running] from
                ; outside a page".  A MODULE IS A THIRD, and an arm reached
                ; from one has no claim on the page its caller left in D:
                ; reading the absolute costs nothing and cannot be wrong.
                ;
                ; It reads as a lock bug because ufs_lock stamps i_lockholder
                ; with it and panics when the holder is the caller: two
                ; different tasks both answer 0, so the FIRST contended inode
                ; lock in a module panics `lockself' with nothing wrong.
                ; ufs_ihashget's `igetself' and vfs_subr's ndget have the same
                ; dependency.
@kc_curpid      LDA    |_kCurPid                ; who is RUNNING, page-independent
                PLB
                SEC
                RTL
                ; --- KSVC_CURUID / KSVC_CURGID: the caller's EFFECTIVE ids ---
                ;
                ; UFS campaign 2.6.  `ufs_access' runs in a module bank and the
                ; credentials live in the u-area in bank 0, so this is the seam
                ; between them.  Reno passes a `struct ucred *' down every vnode
                ; op; there is none here (file.h's f_cred is always 0), so the
                ; port reads the ids at the point of the check instead -- the
                ; divergence is stated at ufs_access itself.
                ;
                ; `_Uarea_Cur' reads `_curTask' from the DIRECT PAGE, which is
                ; why the kc_sys.s shims bracket with ENTERK.  That is exactly
                ; the trap @kc_curpid above documents: without the bracket this
                ; would read a slot in fcc's register file and answer with a
                ; compiler temporary that looks like a plausible uid -- and for
                ; a permission check a plausible-looking wrong answer is the
                ; worst possible failure, because 0 is root.
                ;
                ; NO U-AREA MEANS ROOT, matching `_Sys_GetUid's @gu_root arm for
                ; the same boot-context case: pid 0 is the kernel bringing
                ; itself up, and it is not subject to its own mode bits.
                ; THE DIRECT PAGE IS THIS ARM'S OWN PROBLEM, and assuming
                ; otherwise made the whole check vacuous.  `_Uarea_Cur' reads
                ; `_curTask', `_schedTblPtr' and `_u' -- all DIRECT PAGE -- and
                ; the kernel's page is PER-TASK: the running task's SLOT page,
                ; published by the scheduler in the bank-0 cell KFGX_CUR_KDP
                ; (`_FarSh_KernDP', far_shims.s, reads the same cell).  On any
                ; other page `_curTask' reads 0, `_Uarea_Cur' answers "boot
                ; context", and kc_curuid returns 0 -- ROOT -- for every caller.
                ; A permission check that always sees root allows everything
                ; while looking exactly like one that works, so this arm builds
                ; the page from the absolute rather than trusting the D it was
                ; entered with.
                ;
                ; MEASURED, not deduced: with the arm returning 200 + _curTask,
                ; `ls -l' reported 200 on every file, so the DP read was 0 while
                ; a real task was running.  `@kc_curpid' above sidesteps the
                ; same trap by reading the absolute mirror instead; these need
                ; the u-area, so they build the page rather than borrow it.
@kc_curuid      LDA    |_kCurPid                ; absolute, like @kc_curpid
                AND     #$00FF
                BEQ     @kc_cruRoot              ; pid 0 = boot: root
                LDAL   KFGX_CUR_KDP             ; the task's slot page (task.s)
                PHD
                TCD                              ; D = THIS task's kernel page
                JSR     _Uarea_Cur
                BCC     @kc_cruNone
                LDY     #U_Uid
                LDA     [_u],Y
                PLD
                PLB
                SEC
                RTL
@kc_cruNone     PLD
@kc_cruRoot     LDA     #0
                PLB
                SEC
                RTL
                ; --- KSVC_CONBACKEND: A = table offset, Y = table bank.  The
                ; console lives in the far bank; the registration does too. ---
@kc_conbackend  ANOP
_kfp999         JSL     KFAR_CON_SETBACKEND
                LDA     #VC_CARD+1
                STA     _kVcCard                ; Option-4 is the keys alone now
                ; The card's console may already hold a session, when the
                ; module is loaded by hand: paint its ring onto the card
                ; through the bracket a write to it opens, which is also what
                ; draws the cursor there.  A console with no bank has never
                ; been written; its first write will paint.
                LDA     _kVcBank+{VC_CARD*2}
                AND     #$00FF
                BEQ     @kc_cbDone
                LDA     _ttyvIdx2
                JSR     _Vc_WriteEnter
                BCC     @kc_cbDone
_kfp993         JSL     KFAR_CON_RENDERALL
                SEC
                JSR     _Vc_WriteLeave
@kc_cbDone      PLB
                SEC
                RTL
@kc_curgid      LDA    |_kCurPid
                AND     #$00FF
                BEQ     @kc_crgRoot
                LDAL   KFGX_CUR_KDP
                PHD
                TCD
                JSR     _Uarea_Cur
                BCC     @kc_crgNone
                LDY     #U_Gid
                LDA     [_u],Y
                PLD
                PLB
                SEC
                RTL
@kc_crgNone     PLD
@kc_crgRoot     LDA     #0
                PLB
                SEC
                RTL
@kc_wakeup      JSR     _wakeup                 ; A = chan
                PLB
                SEC
                RTL
@kc_ttysig      TYX                             ; Y -> X = signal (A = tty index)
                JSR     _Tty_DeliverSig
                PLB
                SEC
                RTL
@kc_ttyopen     TYX                             ; Y -> X = tty byte offset
                JSR     _Se_TtyOpen
                PLB
                SEC
                RTL
@kc_ttycooked   TYX                             ; Y -> X = tty byte offset
                JSR     _Tty_CookedDefaults
                PLB
                SEC
                RTL

                ; --- net.mod's four, after net_loop.s + pipe.s moved into it.
                ; EVERY ARM IS ENTERED AT MX %00 WITH THE ARGUMENT ZERO-EXTENDED
                ; IN A, and sets whatever width its callee wants.  The callees
                ; disagree -- _Fcb_Free and _Fcb_LookupPtr want M=8, the other
                ; two want %00 -- and normalising here rather than at each of
                ; the module's call sites keeps the width bookkeeping in ONE
                ; place.  Getting it wrong loads or stores the wrong number of
                ; bytes and nothing says so. ---
@kc_tasklookup  JSR     Task_Lookup             ; A = pid -> C=1 + X = TCB off
                PLB                             ; X IS THE RESULT here, not the
                RTL                             ;   selector; carry is the answer
@kc_fcbfree     SEP     #$20
                MX      %10
                JSR     _Fcb_Free               ; A.lo = fd; restores M itself
                REP     #$30
                MX      %00
                PLB
                SEC
                RTL
@kc_fcblookup   SEP     #$20
                MX      %10
                JSR     _Fcb_LookupPtr          ; A.lo = fd -> C=1 + _fcbPtr
                REP     #$30
                MX      %00
                PLB                             ; carry is the answer; A = EBADF
                RTL                             ;   on C=0
@kc_sigraise    JSR     _Sig_Raise              ; A = signum, posted to _curTask
                PLB
                SEC
                RTL

                ; --- KSVC_BLKIO: A = buffer BANK, Y = nonzero to READ ---
                ;
                ; The module-side twin of _FarSh_BlkIo (src/kernel/far_shims.s),
                ; and deliberately byte-for-byte the same work: the far bank and
                ; a module differ in how they REACH the kernel, never in what
                ; the kernel then does.  See that shim for why the buffer bank
                ; travels in a register instead of being written by the caller.
                ;
                ; _blkNum, _blkNumHi, _blkBuf and _fsCurDevIdx are direct page,
                ; so kc_blkio has already written them -- it needs only the
                ; kernel's D for that, which it has, and no DBR at all.
@kc_blkio       STA    |_blkBufBank             ; one-shot; the Blk_* entry
                                                ;   latch consumes and zeroes it
                ; A pool source is never what the VFS means.  _blkSrcPool says
                ; "the bytes are in a cache pool entry, not the caller's
                ; buffer", and Blk_Write consults it BEFORE the buffer bank --
                ; so a stale one left by an errored write would move the wrong
                ; 512 bytes out of the pool's bank.  State it rather than
                ; inherit whoever ran last.
                SEP     #$20                    ; ONE byte: a 16-bit store here
                MX      %10                     ;   reaches into _ulSapRec
                LDA     #0
                STA    |_blkSrcPool
                REP     #$30
                MX      %00
                CPY     #0
                BEQ     @kc_bio_wr
                JSR     Blk_Read
                PLB
                RTL
@kc_bio_wr      JSR     Blk_Write
                PLB
                RTL

                ; --- KSVC_BLKREADS: -> A = the device read count, low word ---
                ;
                ; Existing observability, not new: block.s bumps _kBlkReadCount
                ; on every Blk_Read.  The VFS probe reads it to prove a cache
                ; HIT never reached the device -- a claim the cache's own flags
                ; cannot settle, since they are what is under test.
@kc_blkreads    LDA    |_kBlkReadCount          ; DBR is the kernel bank here
                PLB                             ; sets N/Z only; A survives
                SEC
                RTL

                ; --- KSVC_TIME: Y = 0 UTC / 1 local -> A = low, X = high ---
                ;
                ; The kernel clock's seconds, for kernel C in a module (ufs.mod
                ; and prodos.mod's kern_time.c): 2.11BSD's `time.tv_sec', a
                ; memory load there and a slot call into the tty bank here,
                ; whose stub sets its own DBR and D and hands the long back in
                ; A and X.  Nothing here touches direct page.
@kc_time
_ktp105         JSL     KTTY_TOD_NOW
                PLB
                SEC
                RTL

                ; --- KSVC_BANKGRANT / KSVC_BANKFREE (DBR = kernel, set by the
                ; head): ld.mod's library banks, held by no task. ---
@kc_bankgrant   JSR     Bank_Alloc              ; C=1 + A = bank, or ENOMEM
                PLB
                RTL
@kc_bankfree    JSR     Bank_Free               ; A = bank; preserves X/Y
                PLB
                SEC
                RTL

                ; --- KSVC_BLKSTALE / KSVC_BLKIOCTL: A = block dev_t (dev.s) ---
@kc_blkstale    JSR     Dev_BlkStale
                PLB
                RTL
@kc_blkioctl    JSR     Dev_BlkIoctl            ; C=0 -> A = errno
                PLB
                RTL

                ; --- KSVC_TICKS: -> A = _kSystemTicks, LOW WORD ---
                ;
                ; apple/fgx#182.  The counter `_HBTickTask` maintains, read the
                ; way KSVC_BLKREADS reads `_kBlkReadCount` -- no direct-page
                ; switch, no excursion, four instructions.  That shape is the
                ; point: it exists so `kern_time` can stop paying 3.6 ms of ROM
                ; per call (MEASURED, src/userland/rtcbench) for a number BSD
                ; gets from a memory load.
                ;
                ; PHP/SEI, FOR THE SAME REASON `_Sys_Ticks` HAS IT: the two
                ; halves are two loads, and the heartbeat incrementing between
                ; them can carry into the high word -- so an unbracketed read
                ; can return a count that never existed, once every 18 minutes,
                ; and be wrong by 65536 ticks when it does.
                ;
                ; The PLP goes BEFORE the SEC because this dispatcher's carry
                ; IS the return value and PLP would restore the caller's.
                ;
                ; X CARRIES A RESULT HERE, where the dispatcher's contract says
                ; X is clobbered unless a service documents otherwise.  This is
                ; that documentation, on KSVC_FINDVTABLE's precedent.
@kc_ticks       PHP
                SEI
                LDX    |_kSystemTicks+2         ; high word; DBR is the kernel
                LDA    |_kSystemTicks           ;   bank here
                PLP
                PLB
                SEC
                RTL

                ;==============================================================
                ; THE CHARACTER DEVICE SWITCH (UFS 1.13b).
                ;
                ; Five arms onto src/kernel/chardev.s, which is in THIS bank --
                ; so each is a JSR and the registry's own C/A convention is
                ; already this dispatcher's.  What every one of them has to do
                ; is PLB before returning, because the dispatcher pushed the
                ; caller's DBR and the chardev routines run on ours.
                ;==============================================================

                ; --- KSVC_CDLOOKUP: A = name offset, Y = name bank ---
                ;
                ; A NAME IN THE MODULE'S BANK, WHICH IS WHY THIS ARM COPIES.
                ; _Chardev_LookupSuffix takes a KERNEL-bank pointer and an
                ; explicit length; a module has neither to give.  So the name
                ; is read with a long pointer -- the only way to reach another
                ; bank without changing DBR out from under the registry -- into
                ; a kernel-bank buffer, and its length is measured on the way.
                ;
                ; BOUNDED BY THE REGISTRY'S OWN LIMIT.  CD_Name holds fifteen
                ; characters, so a name longer than that cannot match anything
                ; and the copy stops rather than running off the buffer.  A
                ; caller passing an unterminated string gets ENOENT, not a
                ; wander through its own bank.
                ; THE BODY MOVED TO _Chardev_LookupBank (chardev.s) AT UFS
                ; 1.7d I3, when the far kernel bank needed the same thing: it
                ; has no SYS_KCALL, so its kc_cdlookup goes through a _FarSh_
                ; shim, and leaving this loop here would have made that a
                ; second copy of it.  The head note that stood here -- why it
                ; copies, and why fifteen characters is the bound -- moved with
                ; the code rather than being left behind to rot.
@kc_cdlookup    JSR     _Chardev_LookupBank
                PLB
                RTL

                ; --- KSVC_CDDREAD / KSVC_CDDWRITE: cdevsw's bulk ops ---
                ;
                ; A = uio offset, Y = (uio bank << 8) | idx on entry.  The arm
                ; does the whole job -- bounds check, absent-slot test, frame
                ; and dispatch -- so that all three live in one place and the
                ; caller needs no scraped address.  See _Chardev_Bulk.
                ;
                ; THE KERNEL DIRECT PAGE IS WHY THIS IS AN ARM AND NOT A SHIM.
                ; The registry is reached through [_cdTablePtr], a DP long
                ; pointer, and a KSVC arm already runs on the kernel's page.
                ; The first cut of this had the MODULE dispatch, on its own D,
                ; and read the table out of fcc's register file.
                ; --- KSVC_UNPNAME: an AF_UNIX socket's NAME ---
                ;
                ; A = the sockaddr's offset in the CALLER's bank.  _unpNameOp says
                ; bind or lookup; _unpSlot carries the descriptor slot, in for a
                ; bind and out for a lookup.
                ;
                ; THE PATH IS COPIED FIRST, and the carry off that copy must be
                ; tested -- _Sys_CopyPathToBuf reports C=1 for a path over
                ; SYS_PATH_MAX, and a caller that ignores it looks up a DIFFERENT,
                ; SHORTER name (apple/fgx#436).  The sockaddr's path begins at
                ; SIN_PORT, which is offset 2: sa_family is the two bytes before
                ; it, exactly as sockaddr_un lays out sun_path.
                ;
                ; THEN ONE FAR CALL, because namei is in vfs.mod and the C that
                ; calls it is in the far bank.  This arm is the only place the two
                ; can be reached from a module.
@kc_unpname     MX      %00
                ; UNBIND CARRIES A SLOT AND NO PATH, so it skips the copy: A is
                ; not a sockaddr on that call, and copying from it would read a
                ; stray offset out of the caller's bank and answer
                ; ENAMETOOLONG for a close that has nothing to name.
                ;
                ; THE TEST IS A LOAD AND A BRANCH BECAUSE UNP_OP_UNBIND IS ZERO,
                ; which include/socket.s records as a byte budget rather than a
                ; taste: a CPX against a non-zero op is three bytes more, and
                ; this bank had four to spare.  X is free -- _Sys_KCallImpl
                ; documents it clobbered unless a service says otherwise, and
                ; the selector is dead once an arm is reached.
                LDX     _unpNameOp
                BEQ     @kc_unpPathOk
                ; A ARRIVES AS &sun_path ALREADY, added module-side in
                ; _Unp_NameCall: the offset costs the same two bytes either way
                ; and net.mod has room where this bank has none.
                ; SEP #$30, NOT #$20: THE INDEX REGISTERS HAVE TO NARROW TOO.
                ; With only M set, Y stays 16 bits and `STY' writes TWO bytes
                ; into a DS 1 cell -- _Sys_PathBank's byte and then
                ; _Sys_BlkTmp's low byte, which is the very scratch
                ; _Sys_PathBlkArg returns through.
                SEP     #$30
                MX      %11
                LDY     _Sys_CallerBank
                STY     _Sys_PathBank           ; the copy's source bank
                REP     #$30
                MX      %00
                JSR     _Sys_CopyPathToBuf
                BCC     @kc_unpPathOk
                PLB
                LDA     #ENAMETOOLONG
                CLC
                RTL
@kc_unpPathOk   ; unp_nameop(pid, op, path, slotp), fcc right to left: slotp goes
                ; down first.  Both pointers are FOUR bytes -- pad, bank, offset --
                ; and the bank is THIS one, pushed with PHK rather than a `^'
                ; literal so relocation cannot bake the assembly bank.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; slotp: pad
                PHK                             ;        bank
                REP     #$30
                MX      %00
                PEA     _unpSlot                ;        offset (PEA: 3 bytes
                                                ;        where LDA #imm+PHA is 4)
                SEP     #$20
                MX      %10
                ; NO RELOAD: A's low byte is still the 0 pushed above.  REP and
                ; PEA leave A alone, and only the low byte reaches the stack in
                ; 8-bit mode, so the pad byte is already in hand.
                PHA                             ; path:  pad
                PHK                             ;        bank
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;        offset
                LDA     _unpNameOp
                PHA                             ; op
                LDA    |_kCurPid                ; who is RUNNING, page-independent
                PHA                             ; pid
_kfp904         JSL     KFAR_VFS_UNPNAME        ; bank byte patched by Far_Init
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #12                     ; drop the copy -- caller cleans
                TCS
                PLB
                ; TYA SETS Z FROM THE ERRNO, so the compare is the move: 0 is
                ; success and A is already the value both arms return.
                TYA
                BNE     @kc_unpErr
                SEC
                RTL
@kc_unpErr      CLC
                RTL

@kc_cddread     LDX     #COPS_DRead
                JSR     _Chardev_Bulk
                PLB
                RTL

@kc_cddwrite    LDX     #COPS_DWrite
                JSR     _Chardev_Bulk
                PLB
                RTL

                ; --- KSVC_TTYPGRP / KSVC_TTYSETPGRP: a line's foreground
                ; process group, which lives in the TTY BANK since T3 stage 1c.
                ; A = the tty's BYTE OFFSET; the group is in Y for the setter,
                ; because X is the service number.  See include/modules.s.
@kc_ttypgrp     JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                JSR     _Tty_PgrpOf             ; A = the group (0 if no line)
                PLB
                SEC
                RTL

@kc_ttysetpgrp  PHY                             ; the group, while A is converted
                JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                PLX                             ; X = the group
                JSR     _Tty_SetPgrp
                PLB
                SEC
                RTL

                ; KSVC_TTYINTRQUIT: A = tty byte offset -> A = t_intrc,
                ; Y = t_quitc, X = sg_flags.  The MODE WORD joined at stage 2d
                ; because pty.mod's per-byte path tests RAW before it tests
                ; either character, and a second crossing there is paid per
                ; character.  The slot answers intrc/quitc/flags in A/X/Y; the
                ; two that travel back swap registers on the way out, because X
                ; is the service number on the way IN and a module has no reason
                ; to care which register the bank used.
@kc_ttyintrquit JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                JSR     _Tty_IntrQuitOf         ; A=intrc, X=quitc, Y=sg_flags
                PHY                             ; flags -> X, quitc -> Y, and
                PHX                             ;   neither may pass through the
                PLY                             ;   other's register on the way
                PLX
                PLB
                SEC
                RTL

                ; KSVC_TTYWINSZ: A = tty byte offset, Y = ws_col << 8 | ws_row.
                ; The slot next door takes the two in X and Y, so the unpacking
                ; is done HERE rather than in the module -- one copy of it, on
                ; the side of the crossing that already owns the conversion.
                ; _Se_TtyOffToIdx preserves Y (it counts in X), so the packed
                ; word survives the index conversion untouched.
@kc_ttywinsz    JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                PHA                             ; ...while Y is taken apart
                TYA
                AND     #$00FF
                TAX                             ; X = ws_row, the low byte
                TYA
                XBA
                AND     #$00FF
                TAY                             ; Y = ws_col, the high byte
                PLA                             ; A = the index again
                JSR     _Tty_SetWinSz
                PLB
                SEC
                RTL

                ; KSVC_TTYLOPEN / KSVC_TTYMODEM: the discipline's l_open and
                ; l_modem, which T4 increment 2 gives the pty driver.  A is the
                ; tty byte offset as in the four services above; the flag rides
                ; in Y for KSVC_TTYMODEM because X is the service number.
                ;
                ; A DRIVER IN A MODULE HAS NO OTHER ROUTE.  linesw[] lives in
                ; the tty bank and the slot addresses are that bank's, so a JSL
                ; from a module would carry the assembly-time bank -- the trap
                ; KSVC_TTYSETPGRP's note records.
@kc_ttylopen    JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                ; STRAIGHT AT THE SLOT -- apple/fgx#268, _KTty_PtcWritable's
                ; shape.  `_Tty_LineOpen' was the seam bracket and nothing
                ; else, and slot 22 is its own entry stub now.  The
                ; offset-to-index conversion STAYS here: `_Se_TtyOffToIdx' is
                ; core-bank code.
_ktp071         JSL     KTTY_KC_TTOPEN          ; A = errno, 0 = opened
                PLB
                SEC
                RTL

@kc_ttymodem    PHY                             ; the flag, while A is converted
                JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                PLX                             ; X = the flag
                ; STRAIGHT AT THE SLOT, as KSVC_TTYLOPEN above.
_ktp074         JSL     KTTY_KC_TTMODEM         ; A = 0 -> turn the line off
                PLB
                SEC
                RTL

@kc_ttylclose   PHY                             ; the flag, while A is converted
                JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                PLX                             ; X = the flag
                ; STRAIGHT AT THE SLOT, as KSVC_TTYLOPEN above.
_ktp075         JSL     KTTY_KC_TTCLOSE         ; A = errno
                PLB
                SEC
                RTL

                ; KSVC_TTYPTYOPROC: T4 increment 4.  Same
                ; A-is-the-offset convention as the five above; the second
                ; argument rides in Y because X is the service number.
                ; STRAIGHT AT THE SLOT, as KSVC_TTYLOPEN above: apple/fgx#268
                ; moved the bracket into the tty bank as `_KTty_PtyOproc'.
@kc_ttyptyoproc PHY                             ; `on', while A is converted
                JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                PLX                             ; X = on
_ktp040         JSL     KTTY_KC_PTYOPROC        ; slot 25; A = errno
                PLB
                SEC
                RTL

                ; KSVC_TTYOUTQREAD HAD AN ARM HERE and never had a caller.
                ; It carried `_Tty_OutqRead', the MVN loop that delivered to
                ; `_Sys_CallerBank:_Sys_RdBufOff' -- and the BSD route made it
                ; unnecessary before anything used it: a uio is a cursor, so one
                ; door serves the record path and the vnode path both.  The
                ; SERVICE NUMBER stays declared in include/modules.s, which is
                ; append only.

                ; KSVC_TTYOUTQUIO: A = uio offset, Y = (uio bank << 8) | tty
                ; INDEX -- the one tty service taking an index rather than a
                ; byte offset, because three values do not fit two registers and
                ; 0..4 fits a spare byte where a TTY_SIZE-scaled offset does
                ; not.  include/modules.s states it at the service.
                ; KSVC_TTYOUTQAVAIL: `ptcread's wait condition as a query.
@kc_ttyoutqavail JSR    _Se_TtyOffToIdx         ; A = offset -> tty index
                ; STRAIGHT AT THE SLOT, as KSVC_TTYLOPEN above.
_ktp072         JSL     KTTY_KC_TTOUTQRUN       ; A = bytes available, 0 = none
                PLB
                SEC
                RTL

                ; KSVC_TTYSTOPPED: the OTHER half of `ptsstart's packet arm --
                ; TS_TTSTOP, which the driver cannot see and the tty bank can.
@kc_ttystopped  JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                ; STRAIGHT AT THE SLOT, as KSVC_TTYLOPEN above.
_ktp073         JSL     KTTY_KC_TTSTOPPED       ; A = 1 stopped / 0 running
                PLB
                SEC
                RTL

                ; KSVC_TTYCARRIER: TS_CARR_ON, which the driver cannot see
                ; and the tty bank can.  `ptcread' decides EOF on the carrier
                ; and not on whether a slave is open this instant
                ; (vendor/2.11BSD/usr/sys/sys/tty_pty.c:268) -- apple/fgx#266.
@kc_ttycarrier  JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                ; STRAIGHT AT THE SLOT -- apple/fgx#268.  `_Tty_Carrier' stood
                ; here and did nothing but the seam bracket; it is slot 41's
                ; own entry stub now, on the side of the seam that can derive
                ; its bank with a PHK.
_ktp061         JSL     KTTY_KC_TTCARRIER       ; A = 1 carrier up / 0 down
                PLB
                SEC
                RTL

                ; KSVC_TTYSELECT: `ttyselect(tp, rw)'.  Y carries rw, which
                ; the slot wants in X -- the swap is here rather than in the
                ; driver because the KSVC convention owns Y and the stub's
                ; signature owns X.  STRAIGHT AT THE SLOT: apple/fgx#268 moved
                ; the bracket into the tty bank as `_KTty_Select'.
@kc_ttyselect   JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                PHY
                PLX                             ; X = rw
_ktp047         JSL     KTTY_KC_TTSELECT        ; slot 32; A = 1 ready / 0 not
                PLB
                SEC
                RTL

                ; KSVC_TTYPTCINPUT: `ptcwrite(c, tp)'.  Y carries the byte,
                ; which _Tty_PtcInput wants in X -- the same swap
                ; KSVC_TTYSELECT does, and for the same reason: the KSVC
                ; convention owns Y and the wrapper's signature owns X.
                ; THE CONVERSION MOVED OUT HERE with apple/fgx#268, exactly
                ; as KSVC_TTYSELECT's did: `_Se_TtyOffToIdx' is CORE code and a
                ; stub running in the tty bank cannot reach it.  It clobbers X
                ; and preserves Y, so the byte is safe across it and the swap
                ; follows rather than precedes.
@kc_ttptcinput  JSR     _Se_TtyOffToIdx         ; A = offset -> tty index
                PHY
                PLX                             ; X = the byte
_ktp051         JSL     KTTY_KC_PTCINPUT        ; slot 35; A = 1 / 0 / -1
                PLB
                SEC
                RTL

                ; KSVC_TTYPTCWRITABLE: `ptcselect(FWRITE)'.  A = the tty
                ; byte offset; no second argument, so no Y/X swap.
@kc_ttptcwritable JSR  _Se_TtyOffToIdx         ; A = offset -> tty index
                ; STRAIGHT AT THE SLOT -- apple/fgx#268, the carrier's
                ; shape one family over: `_Tty_PtcWritable' was the seam
                ; bracket and nothing else, and it is slot 37's own entry
                ; stub now.  The offset-to-index conversion STAYS here --
                ; `_Se_TtyOffToIdx' is core-bank code.
_ktp062         JSL     KTTY_KC_PTCWRITABLE     ; A = 1 / 0
                PLB
                SEC
                RTL

                ; KSVC_TTYREAD / KSVC_TTYWRITE: `ptsread'/`ptswrite's one line,
                ; for a driver that lives in a module.  A = uio offset,
                ; Y = (uio bank << 8) | (IO_NDELAY ? $80 : 0) | tty INDEX;
                ; include/modules.s states the packing at the service.
                ;
                ; THE TWO CELLS ARE SET HERE AND NOT BY THE MODULE.
                ; `_Tty_Read'/`_Tty_Write' take the uio in `_libcTmp2' and the
                ; flag in `_Sys_CdFlag', both of which are the CORE's direct
                ; page -- which a KSVC arm already runs on, and a module does
                ; not.  It is also the safe side of apple/fgx#89: both are read
                ; onto the caller's stack by the staging block at the top of
                ; `_Tty_Read' before `ttread' can sleep.
@kc_ttyread     JSR     @kc_ttyrwArgs           ; A = the tty index
                JSR     _Tty_Read               ; A = errno, 0 = success
                PLB
                SEC
                RTL

@kc_ttywrite    JSR     @kc_ttyrwArgs
                JSR     _Tty_Write
                PLB
                SEC
                RTL

@kc_ttyrwArgs   STA     _libcTmp2               ; the uio's offset
                TYA
                XBA
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     _libcTmp2+2             ; the uio's bank.  8-BIT: the
                REP     #$30                    ;   cell is THREE bytes
                MX      %00                     ;   ($54..$56), so a 16-bit
                                                ;   store runs into the next
                                                ;   one -- memmap.s:158.
                STZ     _Sys_CdFlag
                TYA
                AND     #$0080                  ; the packed IO_NDELAY bit
                BEQ     @kc_ttyrwIdx
                LDA     #VFS_IO_NDELAY
                STA     _Sys_CdFlag
@kc_ttyrwIdx    TYA
                AND     #$007F                  ; ...and the tty index under it.
                RTS                             ;   `kc_ttread' bounds-checks it

                ; KSVC_CDSETTTYIDX: "this chardev IS tty[n]", for a driver
                ; that lives in a MODULE.  A = chardev index, Y = tty index.
                ;
                ; THE MULTIPLY IS HERE BECAUSE TTY_SIZE IS, and that is the
                ; same reason `_Chardev_TtyIdx' keeps the DIVISION on this side
                ; -- the stride comes out of a DUM block, so a caller that
                ; restates it goes wrong the first time a field is added.  A
                ; module cannot include an assembly header at all.
                ;
                ; A LADDER, NOT A SHIFT: TTY_SIZE is not a power of two, and
                ; over NTTY entries repeated addition is both smaller than a
                ; divide routine and exact -- the shape `_Chardev_TtyIdx'
                ; already uses going the other way.
@kc_cdsetttyidx PHA                             ; the chardev idx: the multiply
                TYA                             ;   below needs A for itself
                AND     #$00FF
                CMP     #NTTY                   ; BOUNDS FIRST: SetTtyOff stores
                BCS     @kc_cdstBad             ;   whatever it is handed, and an
                TAX                             ;   offset past the table reads
                LDA     #0                      ;   plausible answers out of
                CPX     #0                      ;   whatever follows it
                BEQ     @kc_cdstHave            ; tty[0] is offset 0
@kc_cdstMul     CLC
                ADC     #TTY_SIZE
                DEX
                BNE     @kc_cdstMul
@kc_cdstHave    TAX                             ; X was 0 after the loop
                TAY                             ; Y = the _ttyTable byte offset
                PLA                             ; A = the chardev idx again
                PHX                             ; ...and KEEP the offset, which
                                                ;   _Chardev_SetTtyOff clobbers
                JSR     _Chardev_SetTtyOff
                PLA                             ; A = the byte offset, ANSWERED.
                                                ;   The module's poll op needs it
                                                ;   for KSVC_TTYSELECT and must
                                                ;   not compute it: TTY_SIZE is a
                                                ;   DUM-block stride, which is the
                                                ;   whole reason this service
                                                ;   takes an index (apple/fgx#108
                                                ;   T7 step 3)
                ; AND BIND THE LINE NOW THAT THERE IS SOMETHING TO BIND IT TO.
                ; tty_devinit runs ONCE, from main.s, and binds every device
                ; the registry can already name a tty for.  Every line except
                ; this one is registered by the kernel before that; a driver in
                ; a MODULE arrives afterwards -- /etc/rc is userland -- so the
                ; serial line's tty_bound entry stayed 0, tty_byidx answered
                ; NULL, and the receive interrupt had nothing to hand a
                ; character to.
                ;
                ; HERE AND NOT IN _thunk_ModLoad, WHICH WAS TRIED AND MEASURED
                ; NOT TO WORK: the module's mod_init is what issues this
                ; service, and it has not run by the time the SYS_MODLOAD
                ; thunk's post-step does.  This IS the moment the registry
                ; learns the index, so it is the only place a bind can see it.
                ;
                ; Only the BINDING half is called: tty_devinit's first loop
                ; zeroes tty_bound and resets t_line/t_dev/t_oproc on every
                ; line, which would take a live console's discipline out from
                ; under it.  tty_devbind skips lines already bound, so this
                ; costs a registry scan and nothing else.
                PHA                             ; the answer, across the call
                JSR     _TtyDevBind             ; BRACKETED -- see the routine
                PLA
                PLB
                SEC
                RTL
@kc_cdstBad     PLA                             ; discard the stacked chardev idx
                LDA     #EINVAL
                PLB
                CLC
                RTL

                ; KSVC_TTYIRQINPUT: a driver's receive interrupt, into the
                ; discipline.  Y is already packed the way `_Tty_IrqInput' wants
                ; it, so this arm is the bank-0 gateway and nothing else -- which
                ; is the entire point of it being a service rather than an
                ; exported address (see include/modules.s).
                ;
                ; SAFE FROM AN INTERRUPT because `_Sys_KCallImpl' above is:
                ; PHB/PHK/PLB and a compare chain, no shared direct-page
                ; scratch and no language card.  The language card IS touched,
                ; by `KTTY_KC_ENTER_IRQ' inside the callee, which banks it in
                ; and hands back what it found (apple/fgx#242).
@kc_ttyirqinput JSR     _Tty_IrqInput
                PLB
                SEC
                RTL

@kc_ttyoutquio  PHA                             ; the uio's offset
                TYA
                XBA
                AND     #$00FF
                TAX                             ; X = the uio's bank, for now
                TYA
                AND     #$00FF                  ; A = the tty index
                PLY                             ; Y = the uio's offset
                PHX                             ; ...and the two swap places:
                PHY                             ;   _Tty_OutqUio wants X = offset
                PLX                             ;   and Y = bank
                PLY
                JSR     _Tty_OutqUio            ; A = errno
                PLB
                SEC
                RTL

                ; --- KSVC_CDOPEN: A.lo = chardev idx ---
@kc_cdopen      AND     #$00FF
                JSR     _Chardev_Open
                PLB
                RTL

                ; --- KSVC_CDCLOSE: A.lo = chardev idx ---
                ;
                ; The registry's Close runs the DRIVER's teardown only on the
                ; last open; earlier closes return success without dispatching.
                ; That counting is _Chardev_Close's and is not repeated here --
                ; spec_close has a vcount test of its own, which answers a
                ; different question (how many VNODES name this device) and
                ; must not be confused with this one (how many OPENS it has).
@kc_cdclose     AND     #$00FF
                JSR     _Chardev_Close
                PLB
                RTL

                ; --- KSVC_CDREAD: A.lo = idx -> A.lo = byte ---
                ;
                ; C=0 WITH A=0 IS END OF FILE, not a failure, and the shim
                ; separates them because zero is not a valid errno.  /dev/null
                ; is the case that proves it exists: its Read is `LDA #0; CLC`.
                ; THE IOFLAG RIDES IN CDIDX_NDELAY, the index byte's top bit,
                ; as it does on the bulk arms -- chardev.s carries the encoding
                ; and its two ERR guards.
                ; This used to STZ the flag, and the comment called that "the
                ; right answer rather than a placeholder" because FNDELAY had no
                ; setter.  apple/fgx#310 gave it one.
@kc_cdread      PHA
                AND     #CDIDX_NDELAY
                LSR                             ; back down to VFS_IO_NDELAY --
                LSR                             ;   chardev.s's ERR pins the
                LSR                             ;   distance
                STA     |_cdArgFlag
                PLA
                AND     #CDIDX_MASK             ; the flag off, not a
                                                ;   power-of-two mask
                JSR     _SyTty_Resolve          ; /dev/tty -> the caller's line
                JSR     _Chardev_Read
                PLB
                RTL

                ; --- KSVC_CDWRITE: A.lo = idx, Y.lo = byte ---
                ;
                ; THE BYTE GOES THROUGH _cdArgByte, which is where
                ; _Chardev_Dispatch sources it (chardev.s:387).  It rides in Y from the
                ; module because X selects the service and A carries the index.
@kc_cdwrite     PHA
                TYA
                AND     #$00FF
                STA     |_cdArgByte
                PLA
                AND     #$00FF
                ; AND THE INDEX, BECAUSE AT LEAST ONE DRIVER READS IT.
                ; _Ttyv_Write asks _Sys_WrCdIdx which line it is writing to
                ; (ttyv.s:159) rather than taking it from the dispatch, so a
                ; caller that leaves it alone writes to whatever line the last
                ; write(2) was for.  /dev/null does not care and every tty
                ; does; setting it here is what makes this arm a caller the
                ; existing drivers can serve, instead of one that happens to
                ; work for the device it was tested against.
                PHA
                AND     #CDIDX_NDELAY           ; the ioflag -- see @kc_cdread
                LSR
                LSR
                LSR
                STA     |_cdArgFlag
                PLA
                AND     #CDIDX_MASK             ; the flag off, not a
                                                ;   power-of-two mask
                JSR     _SyTty_Resolve          ; before the line is staged
                STA     |_Sys_WrCdIdx
                JSR     _Chardev_Write
                PLB
                RTL

                ; --- KSVC_CDIOCTL: A.lo = idx -> C=1 / C=0 + A = errno ---
                ;
                ; cmd AND arg ARE NOT ARGUMENTS, and modules.s says at length
                ; why: _Chardev_Dispatch passes the op only Y, so the pair
                ; travels in _Sys_IoctlCmd/_Sys_IoctlArgLo/_Sys_IoctlArgBank,
                ; which _Sys_Ioctl stages before it dispatches the descriptor.
                ;
                ; NOTHING IS SAVED AND RESTORED HERE, where _FarSh_CdIoctl
                ; saves all three.  That shim has a caller which stages the
                ; singletons ITSELF (ttyblock's cmd is the shim's own
                ; argument), so it must not clobber an ioctl in flight.  This
                ; arm writes none of them -- it is reached FROM inside the
                ; ioctl whose values those are -- so there is nothing to
                ; protect.  Staging anything here would be the bug, not the
                ; guard: it would overwrite the caller's own cmd with a copy
                ; that had crossed two banks to say the same thing.
@kc_cdioctl     AND     #$00FF
                ; THE DEVICE, THEN THE DISCIPLINE -- apple/fgx#267.  This arm
                ; is where a /dev node enters the switch, and it used to stop
                ; at the driver: `_PtyS_Ioctl' answers ENOTTY to TIOCGETP
                ; because the syscall layer routes the sgtty family before the
                ; chardev dispatch, so the whole family was missing on the
                ; vnode road.  `_Io_CdThenTty' is the sequence upstream's
                ; `ptyioctl' performs, in the one place both roads pass.
                JSR     _Io_CdThenTty
                PLB
                RTL

                ; --- KSVC_CDPOLL: A.lo = idx -> C=1 + A = POLL* mask ---
                ;
                ; THE INDEX IS STAGED, because at least one op reads it rather
                ; than taking it from the dispatch: _Ttyv_Poll asks _selCdIdx
                ; which line it is polling (ttyv.s:455).  @kc_cdwrite stages
                ; _Sys_WrCdIdx for the same reason -- an op not told which
                ; device it serves answers for whichever the last caller named,
                ; which on a poll means reporting a stranger's line readable.
                ;
                ; _selCdIdx IS NOT SAVED for the reason above it: this arm
                ; stores it in the instruction before its own dispatch and
                ; nothing sleeps in between, so there is no in-flight value.
@kc_cdpoll      AND     #$00FF
                JSR     _SyTty_Resolve          ; before the line is staged
                STA     |_selCdIdx
                JSR     _Chardev_Poll
                PLB
                RTL

                ; --- KSVC_FINDVTABLE: A = VT_* tag ---
                ;
                ; -> C=1 + A = voffset, X.lo = bank.  C=0 + A = ENOENT when the
                ; exporting module is not loaded, which is a MODULE ORDERING
                ; problem and not a kernel one: /etc/modload.conf must list the
                ; exporter first.  Reported rather than halted so the importer
                ; can say so in its own words.
                ;
                ; X CARRIES A RESULT HERE, where the dispatcher's contract says
                ; X is clobbered unless a service documents otherwise.  This is
                ; that documentation: X.lo is the bank and the caller needs it,
                ; since a voffset without one is not an address.
                ;
                ; No PHD/TCD.  Mod_FindVtable touches no direct page cell -- it
                ; walks the registry through [_modRegPtr],Y and keeps its
                ; working values on the STACK, which is the shape apple/fgx#32
                ; gave it.  kc_curpid needed the bracket because _curTask is a
                ; DP cell; this does not, and adding one would be cargo.
@kc_findvtable  JSR     Mod_FindVtable
                BCC     @kc_fv_miss
                PLB                             ; leaves A and X alone
                SEC
                RTL
@kc_fv_miss     PLB
                LDA     #ENOENT
                CLC
                RTL

;------------------------------------------------------------------------------
; _Sys_BlkReadImpl - SYS_BLKREAD slot ($00:0344) target.
;
; Thin wrapper around Blk_Read.  Modules populate the kernel-bank inputs
; (_fsCurDevIdx, _blkNum, _blkBuf) directly via DBR=kernel-bank stores, then
; JSL SYS_BLKREAD.  Blk_Read returns C=1 ok / C=0 + A=EIO.
;
; In:  _fsCurDevIdx, _blkNum, _blkBuf populated.  MX %00.
; Out: C/A per Blk_Read.  Blk_Read clobbers A/X/Y and sets DBR=kernel-bank
;      (MVN side effect; $02 = assembly ORG); module callers should
;      re-establish their DBR after.
;------------------------------------------------------------------------------
_Sys_BlkReadImpl    MX  %00
                JSR     Blk_Read
                RTL

;------------------------------------------------------------------------------
; _Sys_BlkPinImpl / _Sys_BlkUnpinImpl - SYS_BLKPIN/SYS_BLKUNPIN targets
; (P3.3).  Thin wrappers around the block-cache pin API; same register
; convention as _BlkCache_PinGet/_BlkCache_Unpin.
;------------------------------------------------------------------------------
_Sys_BlkPinImpl     MX  %00
                JSR     _BlkCache_PinGet
                RTL

_Sys_BlkUnpinImpl   MX  %00
                JSR     _BlkCache_Unpin
                RTL

_Sys_BlkPinZImpl    MX  %00
                JSR     _BlkCache_PinAllocZ
                RTL

;------------------------------------------------------------------------------
; _Sys_BlkWriteImpl - SYS_BLKWRITE slot ($00:0348) target.
; Thin wrapper around Blk_Write.  Same calling convention as Blk_Read.
;------------------------------------------------------------------------------
_Sys_BlkWriteImpl   MX  %00
                JSR     Blk_Write
                RTL

;------------------------------------------------------------------------------
; _Sys_BlkStatusImpl - SYS_BLKSTATUS slot ($00:034C) target.
; Thin wrapper around Blk_Status.  In: _fsCurDevIdx + _blkNum (status code
; in low byte).  Out: C=1/0 + A=errno; result bytes at $00:BLK_STAGE.
;------------------------------------------------------------------------------
_Sys_BlkStatusImpl  MX  %00
                JSR     Blk_Status
                RTL

;------------------------------------------------------------------------------
; _Sys_PanicImpl - SYS_PANIC slot ($00:0378) target.
;
; Emits "PANIC" via _BootCon_PutChar then halts forever.  Spec section
; 3.5 also says "Clear $C029 SHR-enable bit so firmware text page becomes
; visible" — Phase 1 skips that step (Toolbox state at panic time may
; not allow clean SHR-off; deferred to Phase 2+ when the panic path
; gets a proper test harness and a defined caller).
;
; In:  X = ptr to message (currently ignored — Phase 1 just emits PANIC).
;      MX %00.
; Out: never returns.
;------------------------------------------------------------------------------
_Sys_PanicImpl      MX  %00
                ;--- THE MARKER GOES WHERE THE MESSAGES GO (apple/fgx#179) ----
                ;
                ; The five letters below reach firmware COUT and land on the
                ; 40-column text page.  That is correct BEFORE console.mod
                ; loads -- the case the boot console exists for -- and invisible
                ; after it, because console.mod owns the display and nobody is
                ; looking at that page.  So a panic raised by anything that is
                ; not kc_panic, or a kc_panic with no message, halted in total
                ; silence.
                ;
                ; apple/fgx#179 framed this as a choice between logging the
                ; marker and leaving it, on the grounds that logging would make
                ; the panic handler depend on the console driver -- which is one
                ; of the things a panic might be about.  THAT COST IS
                ; OVERSTATED: _kernLogPutByte writes the RING FIRST, a plain
                ; [_kLogBufPtr],Y store with no driver anywhere in it, and only
                ; then mirrors to the console, and only when _kernLogMirror is
                ; set.  The marker is therefore durable before any console risk
                ; is taken, which is the ordering that makes this safe rather
                ; than the flag.
                ;
                ; THE REAL HAZARD IS THE DIRECT PAGE, and the issue does not
                ; name it.  SYS_PANIC is a jump-table slot -- a bare JML, no
                ; dispatcher -- so the CALLER's D is still live, and a module's
                ; is not the kernel's.  Kern_LogStr reads _conStrPtr and the
                ; ring reads _kLogBufPtr and _kernLogHead, all DP cells, so
                ; logging on a module's page would follow a garbage pointer and
                ; scribble the panic into whatever it addressed -- a panic
                ; handler corrupting memory on its way out.
                ;
                ; _kFgxDPKernel is the answer that already exists: FGX_Entry
                ; caches its DP choice there because it differs between the
                ; relocating and legacy builds, and far_shims.s records what
                ; assuming $0000 instead cost last time.  DBR comes from PHK,
                ; so nothing here needs a direct page to establish one.
                ;
                ; Nothing is restored.  The next instruction after the letters
                ; is a halt.
                PHK
                PLB                             ; DBR = kernel bank; DP-free
                LDA    |_kFgxDPKernel
                TCD                             ; ...and now DP cells resolve
                LDA     #@panic_msg
                STA     _conStrPtr
                JSR     Kern_LogStr             ; ring first, mirror second

                ; ...and still to the boot console, which is the visible path
                ; before console.mod exists and is where this has always been
                ; correct.
                LDA     #'P'
                JSR     _BootCon_PutChar
                LDA     #'A'
                JSR     _BootCon_PutChar
                LDA     #'N'
                JSR     _BootCon_PutChar
                LDA     #'I'
                JSR     _BootCon_PutChar
                LDA     #'C'
                JSR     _BootCon_PutChar
@panic_hang     BRA     @panic_hang
@panic_msg      ASC     'PANIC',$00

; EIGHT FILESYSTEM SLOTS ARE RETIRED, and they all point at _Phase1_StubHalt so
; that a stale caller surfaces as a red border rather than as silent breakage.
; Slot 18's wrapper went first, in slice 4f (2026-05-16), when Q1B's
; module-local _prodos_walkPath replaced _Sys_FsWalkPathImpl; the slot was then
; reused for SYS_BMENSUREVOL.  The other seven -- SYS_PATHRESOLVE, SYS_FCBALLOC,
; SYS_FCBFREE, SYS_FSDIRENTRY2STAT, SYS_FSFILLMOUNTSLOT, SYS_BMFREE, SYS_BMALLOC
; -- and SYS_BMENSUREVOL with them followed prodos.mod out (apple/fgx#344).  Each
; was a thin JSR into the ProDOS driver behind a JSL boundary, and the module
; that made the boundary necessary was the only caller of any of them.
;
; THE NUMBERS STAY.  A slot is a fixed address a module JSLs, so retiring one
; means pointing it at the halt stub, never closing the gap.

;------------------------------------------------------------------------------
; _Mod_RegisterCharDevImpl - MOD_REGISTERCHARDEV slot ($00:0390) target.
;
; Cross-bank chardev registration for FGXM modules.  Module side:
;
;   JSL convention: caller's PB pushed by JSL; caller's DBR is the
;   module's bank (set via PHK/PLB in mod_init).
;
;   In:  A = bank-rel ptr to NUL-terminated name (≤15 chars)
;        X = bank-rel ptr to CharDev_Ops vtable
;        Y.lo = minor byte (opaque, passed back to ops on each call)
;        Y.hi = CD_Flags (CDF_*).  Zero for every caller that predates it.
;   Out: C=1 + A = chardev idx (0..CHARDEV_MAX-1)
;        C=0 + A = ENOSPC if registry full
;
; Both ptrs (name + ops) are read out of the caller's bank via a self-
; modifying LDAL cell.
;------------------------------------------------------------------------------
_Mod_RegisterCharDevImpl MX %00
                ; Caller's DBR is the module bank, so abs writes to kernel-bank
                ; statics don't land where we want.  Stash args on the stack
                ; (which is bank-0, DBR-independent), switch DBR to the kernel
                ; bank, then read the args back via stack-relative addressing.
                PHA                                     ; SP+1..2: A (name offset)
                PHX                                     ; SP+3..4: X (ops offset)
                PHY                                     ; SP+5..6: Y (minor lo)

                PHB                                     ; SP+7: caller's DBR
                PHK
                PLB                                     ; DBR = kernel-bank ($02 = ORG)

                ; Stack layout now (relative to current S):
                ;   SP+1: PHB byte (caller's DBR — pop at end to restore)
                ;   SP+2..3: Y word
                ;   SP+4..5: X word
                ;   SP+6..7: A word
                ;   SP+8..9: JSL return PC
                ;   SP+10:   JSL return PB (caller bank)

                ; Read args + caller bank.
                SEP     #$20
                MX      %10
                LDA     10,S                            ; caller PB
                STA     _cdRegCallerBank
                LDA     2,S                             ; minor.lo
                STA     _cdRegArgMinor
                LDA     3,S                             ; ...and minor.hi, which
                STA     _cdRegArgFlags                  ;   is CD_Flags
                REP     #$30
                MX      %00
                LDA     6,S                             ; A (name offset, 16-bit)
                STA     _cdRegArgNameLo
                LDA     4,S                             ; X (ops offset, 16-bit)
                STA     _cdRegArgOpsLoX

                ; --- Registry-full check ---
                SEP     #$20
                MX      %10
                ; A FIXED NUMBER, OR THE NEXT FREE ONE.  A module that names
                ; its number (CDF_FIXED, include/chardev.s) takes that slot if
                ; it is empty -- CD_NameLen is 0 there, the table being zeroed
                ; at boot -- and the count is raised over it; a module that
                ; names none takes the first empty slot at or past the count,
                ; which skips any fixed slot already taken above it.
                LDA     _cdRegArgFlags
                BIT     #CDF_FIXED
                BEQ     @mrc_nextFree
                LSR     A
                LSR     A                               ; A = the named index
                CMP     #CHARDEV_MAX
                BCS     @mrc_noSlot
                STA     _cdRegIdx
                REP     #$20
                MX      %00
                LDA     _cdRegIdx
                AND     #$00FF
                JSR     @mrc_entryOff                   ; Y = entry_off + CD_NameLen
                SEP     #$20
                MX      %10
                LDA     [_cdTablePtr],Y
                BNE     @mrc_noSlot                     ; taken: two drivers, one number
                LDA     _cdRegArgFlags
                AND     #CDF_RECORD                     ; only the real flags are kept
                STA     _cdRegArgFlags
                BRA     @mrc_haveSlot
@mrc_nextFree   LDA     _chardev_count
                STA     _cdRegIdx
@mrc_scanFree   LDA     _cdRegIdx
                CMP     #CHARDEV_MAX
                BCS     @mrc_noSlot
                REP     #$20
                MX      %00
                LDA     _cdRegIdx
                AND     #$00FF
                JSR     @mrc_entryOff
                SEP     #$20
                MX      %10
                LDA     [_cdTablePtr],Y
                BEQ     @mrc_haveSlot                   ; empty: take it
                INC     _cdRegIdx
                BRA     @mrc_scanFree
@mrc_noSlot     REP     #$30
                MX      %00
                PLB                                     ; restore caller DBR
                PLY                                     ; balance PHY
                PLX                                     ; balance PHX
                PLA                                     ; balance PHA
                LDA     #ENOSPC
                CLC
                RTL
                ; @mrc_entryOff - A = index (16-bit, high byte clear) ->
                ; Y = index*24, the entry's CD_NameLen byte.  MX %00 in and out.
@mrc_entryOff   MX      %00
                ASL     A
                ASL     A
                ASL     A
                STA     _cdRegEntryOff
                ASL     A
                CLC
                ADC     _cdRegEntryOff
                TAY
                RTS
@mrc_haveSlot   MX      %10
                REP     #$30
                MX      %00

                ; --- entry_off = idx * 24 ---
                LDA     _cdRegIdx
                AND     #$00FF
                ASL     A                               ; *2
                ASL     A                               ; *4
                ASL     A                               ; *8
                STA     _cdRegEntryOff
                ASL     A                               ; *16
                CLC
                ADC     _cdRegEntryOff                  ; *24
                STA     _cdRegEntryOff

                ; --- Copy name from (caller_bank:_cdRegArgNameLo) into
                ;     _chardev_table[entry_off+CD_Name] ---
                ; Patch _cdRegLDAL cell's operand to (caller_bank:nameLo).
                ; STA | (abs, DBR-relative) — NOT STAL: under FGX_RELOC the kernel
                ; runs from bank $20, but STAL bakes the assembled bank ($02), so
                ; the patch landed on a dead $02 cell while `JSR _cdRegLDAL` ran the
                ; un-patched $20 cell (LDAL $000000) -> read $00 -> empty name ->
                ; /dev resolution missed every module chardev (the "/dev/bpf0
                ; cannot open" + /dev/tty01 wedge).  DBR=$20 here (PHK/PLB above),
                ; so STA | hits the live cell.
                LDA     _cdRegArgNameLo
                STA     |_cdRegLDAL+1
                SEP     #$20
                MX      %10
                LDA     _cdRegCallerBank
                STA     |_cdRegLDAL+3
                REP     #$30                            ; clear BOTH M and X
                                                       ; (REP #$10 alone leaves
                                                       ; M=8 → MX mismatch trap
                                                       ; per feedback_merlin_
                                                       ; imm_in_m8_mode)
                MX      %00
                ; Loop: JSR _cdRegLDAL → A = byte from caller bank.
                ; Y = dst index within _chardev_table (entry+CD_Name+i).
                LDY     _cdRegEntryOff
                INY                                     ; +CD_Name (=1)
@mrc_nameLp     JSR     _cdRegLDAL                      ; A = caller byte
                AND     #$00FF
                BEQ     @mrc_nameDone
                SEP     #$20
                MX      %10
                STA     [_cdTablePtr],Y                 ; -> heap table (D=$BF00
                                                       ; kernel DP preserved by
                                                       ; the JSL into this impl)
                REP     #$20
                MX      %00
                INY
                ; Advance LDAL operand by 1.
                SEP     #$20
                MX      %10
                LDA     _cdRegLDAL+1
                INC
                STA     _cdRegLDAL+1
                BNE     @mrc_nameNoCy
                LDA     _cdRegLDAL+2
                INC
                STA     _cdRegLDAL+2
@mrc_nameNoCy   REP     #$20
                MX      %00
                ; Cap at 15 chars.
                TYA
                SEC
                SBC     _cdRegEntryOff
                CMP     #16                             ; CD_Name+max_len
                BCC     @mrc_nameLp
@mrc_nameDone
                ; CD_NameLen = (Y - entry_off - 1)
                TYA
                SEC
                SBC     _cdRegEntryOff
                SEC
                SBC     #1
                SEP     #$20
                MX      %10
                LDY     _cdRegEntryOff
                STA     [_cdTablePtr],Y                 ; CD_NameLen byte 0
                REP     #$20
                MX      %00

                ; --- Store ops triple (CD_OpsLo/Hi/Bank) ---
                LDA     _cdRegEntryOff
                CLC
                ADC     #CD_OpsLo
                TAY                                     ; Y = entry_off + CD_OpsLo
                LDA     _cdRegArgOpsLoX
                STA     [_cdTablePtr],Y                 ; 16-bit ops lo
                INY
                INY                                     ; Y = entry_off + CD_OpsBank
                SEP     #$20
                MX      %10
                LDA     _cdRegCallerBank
                STA     [_cdTablePtr],Y
                INY                                     ; Y = entry_off + CD_Minor
                LDA     _cdRegArgMinor
                STA     [_cdTablePtr],Y

                ; --- and CD_Flags, which is NOT adjacent: CD_OpenCount and
                ;     CD_TtyOff lie between.  Recomputed rather than walked, so
                ;     the code does not read as a claim that they neighbour. ---
                REP     #$20
                MX      %00
                LDA     _cdRegEntryOff
                CLC
                ADC     #CD_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     _cdRegArgFlags
                STA     [_cdTablePtr],Y

                ; THE COUNT IS ONE PAST THE HIGHEST SLOT IN USE, which the name
                ; lookup walks; a fixed number may sit past the old count.
                LDA     _cdRegIdx
                INC
                CMP     _chardev_count
                BCC     @mrc_countOk
                STA     _chardev_count
@mrc_countOk

                ; --- Clean exit: balance on-entry pushes + restore DBR + return ---
                ; Stack right now (DBR still = kernel-bank):
                ;   SP+1: PHB byte (caller's DBR)
                ;   SP+2..3: Y word
                ;   SP+4..5: X word
                ;   SP+6..7: A word
                ;   SP+8+:  JSL return frame
                REP     #$30
                MX      %00
                PLB                                     ; pull PHB byte → DBR =
                                                       ; caller's bank
                PLY                                     ; balance PHY
                PLX                                     ; balance PHX
                PLA                                     ; balance PHA
                ; A/X/Y now garbage.  Load idx via LDAL (DBR is caller's;
                ; abs-DBR-rel would land in caller bank).
_we001          LDAL    _cdRegIdx
                AND     #$00FF
                SEC
                RTL

;------------------------------------------------------------------------------
; _cdRegLDAL - self-modifying LDAL cell used by _Mod_RegisterCharDevImpl
; to read bytes out of the caller's bank without DP indirect addressing.
; M flag at JSR-time selects 8-bit or 16-bit load (caller uses M=0 for
; the 16-bit "peek" semantics — high byte unused, just an artifact of
; LDAL's M-dependent size).
;------------------------------------------------------------------------------
_cdRegLDAL      DFB     $AF,$00,$00,$00                 ; LDAL <addr>
                DFB     $60                             ; RTS
