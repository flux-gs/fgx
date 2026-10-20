;==============================================================================
; ld.s - ld.mod, the shared-library registry (shared libc SP4 spec, section 4).
;
; One row per library made resident this boot: its banks (granted to the row,
; held by no task, so no exit frees them), its core's base in the per-boot
; arena below HEAP_LIM, its state, and how many processes use it.  A table
; indexed by process slot holds one bit per row: the kernel's exit, fork,
; exec and slot-allocation hooks keep it, and with it each row's count.  A row
; nobody uses keeps its banks until Bank_Alloc finds the pool dry, when the
; reclaim hook gives one row's banks back; its arena slot stays, so a reload
; lands at the same base.
;
; Reached only through LD_TRAMP ($00:031A), which mod_init points here:
;   A = 0..4  SYS_LDCTL's services (the tty bank's _Ld_Ctl refuses the rest);
;             X/Y = the caller's 50-byte block, offset and bank.
;   A = $80.. the kernel's hooks; Y = a pid.
; Entered in kernel context (a syscall, or a kernel path) with MX %00, on the
; task's kernel stack.  A task switches only where this code sleeps
; (KSVC_SLEEP in ACQUIRE): the kernel has no safepoints.
;
; RULES (spec section 4): no scratch in these statics lives across a
; KSVC_SLEEP or a KSVC_BANKGRANT (whose Bank_Alloc can re-enter this module's
; reclaim); RECLAIM never picks a LOADING row, never sleeps, and touches only
; the row table.  Every static is zero in the file: modimage checks a loaded
; module against its file and allows only zero-in-file bytes to differ.
;==============================================================================

                MX      %11
                PUT     modplace.s
                ORG     MODP_ORG

                PUT     ../../../include/config.s
                PUT     ../../../include/macros.s
                PUT     ../../../include/kernel.s       ; LD_TRAMP, LDS_*, LDH_*
                PUT     ../../../include/errno.s
                PUT     ../../../include/modules.s      ; SYS_KCALL, KSVC_*
                ; DP soft-globals (_libcTmp2): one DUM block, emits nothing.
                PUT     ../../../include/dpmap.s

;------------------------------------------------------------------------------
; FGXM header v2 (40 bytes).
;------------------------------------------------------------------------------
ld_bss          EQU     0

ld_hdr          ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi
                DFB     $02                             ; +7  header format v2
                DA      mod_init-$050000                ; +8  entry, bank-rel
                DA      ld_end-ld_text                  ; +10 text bytes
                DA      ld_bss                          ; +12 bss bytes
                DA      ld_vtdir-ld_text                ; +14 vtdir offset
ld_name         ASC     'ld'                            ; +16 module name
                DS      16-*+ld_name                    ;     NUL-pad to 16
                DA      $0000                           ; +32 module version
                ; +34 build identity.  $0000 = not build-locked: this module
                ; bakes no kernel address; it names only bank-0 cells.
                DA      $0000
                DS      4                               ; +36 reserved

ld_text         EQU     *

ld_vtdir        ASC     'VTDR'
                DA      VT_END

;------------------------------------------------------------------------------
; The block (SYS_LDCTL's parameter, 50 bytes, <sys/ldctl.h>) and a row (the
; block's 50 bytes with the same layout, then the loader's pid and the
; arena-slot flag).
;------------------------------------------------------------------------------
B_NAME          EQU     0               ; 16, NUL-padded
B_MAJOR         EQU     16
B_MINOR         EQU     17
B_CRC           EQU     18              ; 4
B_ROW           EQU     22
B_NBANKS        EQU     23
B_BANKS         EQU     24              ; 8
B_COREBASE      EQU     32
B_CORESIZE      EQU     34
B_TMPL          EQU     36
B_EXPT          EQU     38
B_ROWS          EQU     40
B_BINDER        EQU     42              ; 3
B_STATE         EQU     45
B_USERS         EQU     46
B_PINNED        EQU     47
B_DEPS          EQU     48              ; 2, bit r: this row imports from row r
BLK_SZ          EQU     50
R_OWNER         EQU     50              ; pid loading it (LOADING)
R_SLOT          EQU     51              ; 1 once core_base is assigned
ROW_SZ          EQU     52
LD_ROWS         EQU     16
LD_MAXBANKS     EQU     8

ST_EMPTY        EQU     0               ; never used
ST_FREE         EQU     1               ; aborted or reclaimed; slot kept
ST_LOADING      EQU     2
ST_READY        EQU     3

;==============================================================================
; mod_init - point LD_TRAMP at ld_entry: a JML with this module's live bank,
; as fpsim.mod plants FPSIM_TRAMP.  Runs in the modload syscall.
;==============================================================================
mod_init        MX      %00
                PHP
                SEP     #$20
                MX      %10
                LDA     #$5C                    ; JML
                STAL    LD_TRAMP+0
                LDA     #<ld_entry
                STAL    LD_TRAMP+1
                LDA     #>ld_entry
                STAL    LD_TRAMP+2
                PHK
                PLA
                STAL    LD_TRAMP+3
                PLP
                SEC
                RTL

;==============================================================================
; ld_entry - LD_TRAMP's target.  A = selector.  Services: X/Y = the caller's
; block, kept on the stack for the call (a woken ACQUIRE copies it again).
; Hooks: Y = pid.  DBR = this module's bank throughout; the caller's restored.
; X/Y need not survive: the tty slots save what their callers need.
;==============================================================================
ld_entry        MX      %00
                PHB
                PHK
                PLB
                CMP     #LDH_EXIT
                BCS     @le_hook
                STX     ld_off                  ; copied before any sleep;
                STY     ld_bnk                  ;   ACQUIRE re-reads after one
                PHY                             ; 3,S at a service's entry =
                PHX                             ;   offset, 5,S = bank
                ASL
                TAX
                JSR     (ld_svctab,X)
                PLX
                PLX
                PLB
                RTL
@le_hook        SEC
                SBC     #LDH_EXIT
                CMP     #LDH_RECLAIM-LDH_EXIT+1
                BCS     @le_badhook
                ASL
                TAX
                JSR     (ld_hooktab,X)
                PLB
                RTL
@le_badhook     PLB
                CLC
                RTL

ld_svctab       DA      svc_acquire
                DA      svc_grant
                DA      svc_commit
                DA      svc_abort
                DA      svc_lookup
ld_hooktab      DA      hook_exit
                DA      hook_fork
                DA      hook_exec
                DA      hook_talloc
                DA      hook_reclaim

;==============================================================================
; copy_in / copy_out - the caller's block <-> ld_blk, through ld_off/ld_bnk.
; MVN's bank bytes are immediates, so they are written into the instruction
; here (zero in the file); SEI keeps another caller from rewriting them
; between the write and the move.  MVN leaves DBR = its destination, so both
; end PHK/PLB.  Clobber A/X/Y.
;==============================================================================
copy_in         MX      %00
                PHP
                SEI
                SEP     #$20
                MX      %10
                LDA     ld_bnk
                STA     ci_mvn+2                ; source bank
                PHK
                PLA
                STA     ci_mvn+1                ; destination bank: here
                REP     #$30
                MX      %00
                LDX     ld_off
                LDY     #ld_blk
                LDA     #BLK_SZ-1
ci_mvn          MVN     $00,$00                 ; operands written above
                PHK
                PLB
                PLP
                RTS

copy_out        MX      %00
                PHP
                SEI
                SEP     #$20
                MX      %10
                LDA     ld_bnk
                STA     co_mvn+1                ; destination bank: the caller
                PHK
                PLA
                STA     co_mvn+2                ; source bank: here
                REP     #$30
                MX      %00
                LDX     #ld_blk
                LDY     ld_off
                LDA     #BLK_SZ-1
co_mvn          MVN     $00,$00                 ; operands written above
                PHK
                PLB                             ; DBR was the caller's bank
                PLP
                RTS

;==============================================================================
; row_addr - A = row index (0..LD_ROWS-1) -> X = the row's address.  A table,
; so no scratch: reclaim calls it from inside a GRANT.  Clobbers A.
;==============================================================================
row_addr        MX      %00
                AND     #$000F
                ASL
                TAX
                LDA     ld_rowtab,X
                TAX
                RTS

; Merlin32 evaluates left to right, so ld_rows+n*ROW_SZ would be
; (ld_rows+n)*ROW_SZ: each entry is ld_rows + the row's offset, n * 52.
ld_rowtab                               ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)
                DA      ld_rows+0
                DA      ld_rows+52
                DA      ld_rows+104
                DA      ld_rows+156
                DA      ld_rows+208
                DA      ld_rows+260
                DA      ld_rows+312
                DA      ld_rows+364
                DA      ld_rows+416
                DA      ld_rows+468
                DA      ld_rows+520
                DA      ld_rows+572
                DA      ld_rows+624
                DA      ld_rows+676
                DA      ld_rows+728
                DA      ld_rows+780

;------------------------------------------------------------------------------
; find_row - ld_blk's name and major -> C=1 + A = row index, or C=0.
; new_row  - -> C=1 + A = the first EMPTY row's index, or C=0.
; Clobber A/X/Y.
;------------------------------------------------------------------------------
find_row        MX      %00
                LDA     #0
@fr_next        PHA
                JSR     row_addr
                SEP     #$20
                MX      %10
                LDA:    B_STATE,X
                BEQ     @fr_no                  ; EMPTY
                LDA:    B_MAJOR,X
                CMP     ld_blk+B_MAJOR
                BNE     @fr_no
                LDY     #0
@fr_cmp         LDA:    B_NAME,X
                CMP     ld_blk+B_NAME,Y
                BNE     @fr_no
                INX
                INY
                CPY     #16
                BCC     @fr_cmp
                REP     #$30
                MX      %00
                PLA
                SEC
                RTS
@fr_no          REP     #$30
                MX      %00
                PLA
                INC
                CMP     #LD_ROWS
                BCC     @fr_next
                CLC
                RTS

new_row         MX      %00
                LDA     #0
@nr_next        PHA
                JSR     row_addr
                SEP     #$20
                MX      %10
                LDA:    B_STATE,X
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @nr_got
                PLA
                INC
                CMP     #LD_ROWS
                BCC     @nr_next
                CLC
                RTS
@nr_got         PLA
                SEC
                RTS

;------------------------------------------------------------------------------
; row_to_blk - X = row address: its 50 block bytes -> ld_blk.  Clobbers A/Y.
; blk_name_to_row - ld_blk's name and major -> the row at X.  Clobbers A/Y.
;------------------------------------------------------------------------------
row_to_blk      MX      %00
                PHX
                LDY     #0
@rb_l           LDA:    0,X
                STA     ld_blk,Y
                INX
                INX
                INY
                INY
                CPY     #BLK_SZ
                BCC     @rb_l
                PLX
                RTS

blk_name_to_row MX      %00
                PHX
                LDY     #0
@bn_l           LDA     ld_blk,Y
                STA:    0,X
                INX
                INX
                INY
                INY
                CPY     #B_MAJOR+2              ; name, major, minor
                BCC     @bn_l
                PLX
                RTS

;------------------------------------------------------------------------------
; use_addr - A = pid (1..NPROC) -> X = &ld_use[pid-1], C=1; C=0 out of range.
; row_bit - A = row index -> A = 1 << index.
;------------------------------------------------------------------------------
use_addr        MX      %00
                AND     #$00FF
                BEQ     @ua_bad
                CMP     #NPROC+1
                BCS     @ua_bad
                DEC
                ASL
                CLC
                ADC     #ld_use
                TAX
                SEC
                RTS
@ua_bad         CLC
                RTS

row_bit         MX      %00
                AND     #$000F
                TAX
                LDA     #1
@rbt_l          CPX     #0
                BEQ     @rbt_done
                ASL
                DEX
                BRA     @rbt_l
@rbt_done       RTS

; cur_pid - -> A = the running task's pid (KSVC_CURPID reads _kCurPid, which
; does not depend on D).
cur_pid         MX      %00
                LDX     #KSVC_CURPID
                JSL     SYS_KCALL
                AND     #$00FF
                RTS

; wake - wake every process asleep on a registry row.
wake            MX      %00
                LDA     #WCHAN_LD
                LDX     #KSVC_WAKEUP
                JSL     SYS_KCALL
                RTS

; owned - ld_blk's row: C=1 + X = its address when the running task owns it
; LOADING; C=0 + A = EPERM otherwise (or a row out of range).
owned           MX      %00
                JSR     cur_pid
                STA     ld_pid
                LDA     ld_blk+B_ROW
                AND     #$00FF
                CMP     #LD_ROWS
                BCS     @ow_no
                JSR     row_addr
                SEP     #$20
                MX      %10
                LDA:    B_STATE,X
                CMP     #ST_LOADING
                BNE     @ow_no8
                LDA:    R_OWNER,X
                CMP     ld_pid
                BNE     @ow_no8
                REP     #$30
                MX      %00
                SEC
                RTS
@ow_no8         MX      %10
                REP     #$30
                MX      %00
@ow_no          LDA     #EPERM
                CLC
                RTS

;==============================================================================
; svc_acquire - ld_blk's name/major.  READY: count the caller in, the row
; out, A = 0.  Absent or FREE: the caller owns it LOADING, A = 1 (a FREE
; row's banks and arena slot are kept).  LOADING by another: sleep on
; WCHAN_LD and look again; a pending signal ends the wait with EINTR.
;==============================================================================
svc_acquire     MX      %00
@sa_again       JSR     copy_in
                JSR     cur_pid
                PHA                             ; 1,S = pid (survives a sleep)
                JSR     find_row
                BCS     @sa_found
                JSR     new_row
                BCS     @sa_new
                PLA
                LDA     #ENOMEM                 ; the registry is full
                CLC
                RTS
@sa_new         STA     ld_idx
                JSR     row_addr
                JSR     blk_name_to_row
                SEP     #$20
                MX      %10
                LDA     ld_idx
                STA:    B_ROW,X                 ; a row knows its own index
                LDA     #0
                STA:    B_NBANKS,X
                STA:    R_SLOT,X
                STA:    B_USERS,X
                BRA     @sa_load8
@sa_found       STA     ld_idx
                JSR     row_addr
                SEP     #$20
                MX      %10
                LDA:    B_STATE,X
                CMP     #ST_READY
                BEQ     @sa_ready8
                CMP     #ST_LOADING
                BEQ     @sa_busy8
@sa_load8       MX      %10
                LDA     #ST_LOADING             ; absent or FREE: yours
                STA:    B_STATE,X
                LDA     1,S
                STA:    R_OWNER,X
                REP     #$30
                MX      %00
                JSR     row_to_blk
                SEP     #$20
                MX      %10
                LDA     ld_idx
                STA     ld_blk+B_ROW
                REP     #$30
                MX      %00
                JSR     copy_out
                PLA
                LDA     #1
                SEC
                RTS
@sa_ready8      MX      %10
                REP     #$30
                MX      %00
                LDA     ld_idx
                JSR     row_bit
                STA     ld_bit
                LDA     1,S
                JSR     use_addr                ; X = &ld_use[pid-1]
                LDA:    0,X
                BIT     ld_bit
                BNE     @sa_counted
                ORA     ld_bit
                STA:    0,X
                LDA     ld_idx
                JSR     row_addr
                SEP     #$20
                MX      %10
                LDA:    B_USERS,X
                INC
                STA:    B_USERS,X
                REP     #$30
                MX      %00
@sa_counted     LDA     ld_idx
                JSR     row_addr
                JSR     row_to_blk
                SEP     #$20
                MX      %10
                LDA     ld_idx
                STA     ld_blk+B_ROW
                REP     #$30
                MX      %00
                JSR     copy_out
                PLA
                LDA     #0
                SEC
                RTS
@sa_busy8       MX      %10
                LDA:    R_OWNER,X
                CMP     1,S
                BEQ     @sa_load8               ; already ours: load on
                REP     #$30
                MX      %00
                PLA
                JSR     ld_sleep                ; A = 1 interrupted
                LSR
                BCC     @sa_woke
                LDA     #EINTR
                CLC
                RTS
@sa_woke        LDA     3,S                     ; the block again: statics
                STA     ld_off                  ;   may hold another caller's
                LDA     5,S
                STA     ld_bnk
                BRL     @sa_again

;==============================================================================
; svc_grant - ld_blk's row, owned LOADING by the caller; ld_blk's nbanks =
; how many more, its core_size the library's core, or 0 for banks alone.
; At most LD_MAXBANKS a row (EINVAL).  The core base is assigned from the
; arena the first time this boot a core_size is given, before the loader
; needs it to move the core's sites, and kept after: a slot holds one core
; size, and another is EINVAL.  A loader takes its banks before it can read
; what the library needs, and its core only once those are resident, so
; cores are placed in the order the libraries need each other.  Each bank comes from
; KSVC_BANKGRANT, whose Bank_Alloc may run this module's reclaim -- so the
; count lives on the stack, not in a static.  ENOMEM: the banks granted so
; far stay on the row, the block goes out, then C=0.
;==============================================================================
svc_grant       MX      %00
                JSR     copy_in
                JSR     owned                   ; X = row
                BCS     @sg_own
                RTS
@sg_own         LDA     ld_blk+B_NBANKS
                AND     #$00FF
                PHA                             ; 1,S = how many more
                LDA:    B_NBANKS,X
                AND     #$00FF
                CLC
                ADC     1,S
                CMP     #LD_MAXBANKS+1
                BCC     @sg_room
                PLA
                LDA     #EINVAL
                CLC
                RTS
@sg_room        LDA     ld_blk+B_CORESIZE       ; 0: banks alone, no core yet
                BEQ     @sg_based
                SEP     #$20
                MX      %10
                LDA:    R_SLOT,X
                REP     #$30
                MX      %00
                AND     #$00FF
                BNE     @sg_slotted
                LDA     ld_arena                ; 0 means HEAP_LIM
                BNE     @sg_arena
                LDA     #HEAP_LIM
@sg_arena       SEC
                SBC     ld_blk+B_CORESIZE
                STA:    B_COREBASE,X
                STA     ld_arena
                LDA     ld_blk+B_CORESIZE
                STA:    B_CORESIZE,X
                SEP     #$20
                MX      %10
                LDA     #1
                STA:    R_SLOT,X
                REP     #$30
                MX      %00
                BRA     @sg_based
@sg_slotted     LDA     ld_blk+B_CORESIZE       ; a slot holds one core size
                CMP:    B_CORESIZE,X
                BEQ     @sg_based
                PLA
                LDA     #EINVAL
                CLC
                RTS
@sg_based       LDA     ld_blk+B_ROW
                AND     #$00FF
                PHA                             ; 1,S = row, 3,S = more
@sg_loop        LDA     3,S                     ; 1,S = row, 3,S = more
                BEQ     @sg_done
                LDX     #KSVC_BANKGRANT
                JSL     SYS_KCALL               ; C=1 + A = bank
                BCC     @sg_enomem
                PHA                             ; 1,S = bank
                LDA     3,S                     ; the row
                JSR     row_addr                ; X = row
                SEP     #$20
                MX      %10
                LDA:    B_NBANKS,X
                INC
                STA:    B_NBANKS,X
                REP     #$30
                MX      %00
                AND     #$00FF
                DEC                             ; the slot it goes in
                STA     ld_tmp                  ;   (used at once)
                TXA
                CLC
                ADC     ld_tmp
                TAX                             ; X = row + slot
                PLA                             ; the bank
                SEP     #$20
                MX      %10
                STA:    B_BANKS,X
                REP     #$30
                MX      %00
                LDA     3,S
                DEC
                STA     3,S
                BRA     @sg_loop
@sg_done        PLA                             ; row
                JSR     row_addr
                JSR     row_to_blk
                PLA
                JSR     copy_out
                LDA     #0
                SEC
                RTS
@sg_enomem      PLA                             ; row
                JSR     row_addr
                JSR     row_to_blk
                PLA
                JSR     copy_out
                LDA     #ENOMEM
                CLC
                RTS
;==============================================================================
; svc_commit - ld_blk's row, owned LOADING by the caller: its fields in
; (minor, crc, template and EXPT offsets, block rows, binder, pinned, and
; deps, the rows it imports from), READY with the caller its one user; wake
; waiters.
;==============================================================================
svc_commit      MX      %00
                JSR     copy_in
                JSR     owned                   ; X = row, ld_pid = caller
                BCS     @sc_own
                RTS
@sc_own         SEP     #$20
                MX      %10
                LDA     ld_blk+B_MINOR
                STA:    B_MINOR,X
                LDA     ld_blk+B_PINNED
                STA:    B_PINNED,X
                LDA     ld_blk+B_BINDER
                STA:    B_BINDER,X
                LDA     ld_blk+B_BINDER+1
                STA:    B_BINDER+1,X
                LDA     ld_blk+B_BINDER+2
                STA:    B_BINDER+2,X
                REP     #$30
                MX      %00
                LDA     ld_blk+B_CRC
                STA:    B_CRC,X
                LDA     ld_blk+B_CRC+2
                STA:    B_CRC+2,X
                LDA     ld_blk+B_DEPS
                STA:    B_DEPS,X
                LDA     ld_blk+B_TMPL
                STA:    B_TMPL,X
                LDA     ld_blk+B_EXPT
                STA:    B_EXPT,X
                LDA     ld_blk+B_ROWS
                STA:    B_ROWS,X
                SEP     #$20
                MX      %10
                LDA     #ST_READY
                STA:    B_STATE,X
                LDA     #1
                STA:    B_USERS,X
                LDA     #0
                STA:    R_OWNER,X
                REP     #$30
                MX      %00
                PHX
                LDA     ld_blk+B_ROW
                JSR     row_bit
                STA     ld_bit
                LDA     ld_pid
                JSR     use_addr
                LDA:    0,X
                ORA     ld_bit
                STA:    0,X
                PLX
                JSR     row_to_blk
                JSR     copy_out
                JSR     wake
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; ld_sleep - sleep on WCHAN_LD -> A = 1 if a signal ended the wait.  The
; syscall dispatcher may have staged a pointer in the kernel's DP scratch;
; another task runs while this one sleeps and swtch saves no DP
; (apple/fgx#100), so _libcTmp2 is saved across it: 3 bytes in 2
; overlapping words, as net_xport.s's _Sock_PollIntr saves it.
;------------------------------------------------------------------------------
ld_sleep        MX      %00
                LDA     _libcTmp2+1
                PHA
                LDA     _libcTmp2
                PHA
                LDA     #WCHAN_LD
                LDX     #KSVC_SLEEP
                JSL     SYS_KCALL
                REP     #$30                    ; _sleep may return 8-bit
                MX      %00
                TAY                             ; the verdict
                PLA
                STA     _libcTmp2
                PLA
                STA     _libcTmp2+1
                TYA
                RTS

;------------------------------------------------------------------------------
; svc_abort - ld_blk's row, owned LOADING by the caller: FREE, its banks and
; arena slot kept for the next loader; wake waiters.
; svc_lookup - ld_blk's name/major -> the row out (any state), or ENOENT.
;------------------------------------------------------------------------------
svc_abort       MX      %00
                JSR     copy_in
                JSR     owned
                BCS     @sab_own
                RTS
@sab_own        SEP     #$20
                MX      %10
                LDA     #ST_FREE
                STA:    B_STATE,X
                LDA     #0
                STA:    R_OWNER,X
                REP     #$30
                MX      %00
                JSR     wake
                LDA     #0
                SEC
                RTS

svc_lookup      MX      %00
                JSR     copy_in
                JSR     find_row
                BCS     @sl_found
                LDA     #ENOENT
                CLC
                RTS
@sl_found       STA     ld_idx
                JSR     row_addr
                JSR     row_to_blk
                SEP     #$20
                MX      %10
                LDA     ld_idx
                STA     ld_blk+B_ROW
                REP     #$30
                MX      %00
                JSR     copy_out
                LDA     #0
                SEC
                RTS

;==============================================================================
; Hooks.  Y = a pid.  Return C=0 (RECLAIM: C=1 a bank went back).
;==============================================================================
; release - the pid in A: each row whose bit it holds loses a user; its bits
; clear.  Clobbers A/X/Y.
release         MX      %00
                JSR     use_addr
                BCC     @rl_out
                LDA:    0,X
                STZ:    0,X
                LDY     #0                      ; Y = row index
@rl_l           LSR
                BCC     @rl_next
                PHA
                PHY
                TYA
                JSR     row_addr
                SEP     #$20
                MX      %10
                LDA:    B_USERS,X
                BEQ     @rl_zero
                DEC
                STA:    B_USERS,X
@rl_zero        REP     #$30
                MX      %00
                PLY
                PLA
@rl_next        INY
                CPY     #LD_ROWS
                BCC     @rl_l
@rl_out         RTS

; hook_exit - release the pid's rows; a row it owns LOADING becomes FREE
; (banks and slot kept) and its waiters wake.
hook_exit       MX      %00
                PHY
                TYA
                JSR     release
                PLY
                STY     ld_pid
                LDA     #0
@he_l           PHA
                JSR     row_addr
                SEP     #$20
                MX      %10
                LDA:    B_STATE,X
                CMP     #ST_LOADING
                BNE     @he_next8
                LDA:    R_OWNER,X
                CMP     ld_pid
                BNE     @he_next8
                LDA     #ST_FREE
                STA:    B_STATE,X
                LDA     #0
                STA:    R_OWNER,X
                REP     #$30
                MX      %00
                JSR     wake
                BRA     @he_next
@he_next8       MX      %10
                REP     #$30
                MX      %00
@he_next        PLA
                INC
                CMP     #LD_ROWS
                BCC     @he_l
                CLC
                RTS

; hook_exec - the old image's rows go (an exec'ing task is loading nothing).
hook_exec       MX      %00
                TYA
                JSR     release
                CLC
                RTS

; hook_fork - Y = the child: it uses what the running task (its parent)
; uses, and each of those rows gains a user.
hook_fork       MX      %00
                STY     ld_pid                  ; the child
                JSR     cur_pid
                JSR     use_addr                ; the parent's word
                BCC     @hf_out
                LDA:    0,X
                PHA                             ; 1,S = the parent's bits
                LDA     ld_pid
                JSR     use_addr
                BCC     @hf_drop
                LDA     1,S
                STA:    0,X
                LDY     #0
@hf_l           LDA     1,S
                LSR
                STA     1,S
                BCC     @hf_next
                PHY
                TYA
                JSR     row_addr
                SEP     #$20
                MX      %10
                LDA:    B_USERS,X
                INC
                STA:    B_USERS,X
                REP     #$30
                MX      %00
                PLY
@hf_next        INY
                CPY     #LD_ROWS
                BCC     @hf_l
@hf_drop        PLA
@hf_out         CLC
                RTS

; hook_talloc - a slot just handed out uses nothing.
hook_talloc     MX      %00
                TYA
                JSR     use_addr
                BCC     @ht_out
                STZ:    0,X
@ht_out         CLC
                RTS

; hook_reclaim - Bank_Alloc found the pool dry.  The first row READY or FREE
; with no users, not pinned, holding banks: each bank back to the pool, the
; row FREE with its arena slot kept.  C=1 if one was found.  Never a LOADING
; row; no sleep; nothing but the row table and the stack.
hook_reclaim    MX      %00
                LDA     #0
@hr_l           PHA
                JSR     row_addr
                SEP     #$20
                MX      %10
                LDA:    B_STATE,X
                CMP     #ST_READY
                BEQ     @hr_cand
                CMP     #ST_FREE
                BNE     @hr_next8
@hr_cand        LDA:    B_USERS,X
                BNE     @hr_next8
                LDA:    B_PINNED,X
                BNE     @hr_next8
                LDA:    B_NBANKS,X
                BEQ     @hr_next8
                REP     #$30
                MX      %00
                LDA     1,S                     ; this row
                JSR     depended
                BCS     @hr_next16
                SEP     #$20
                MX      %10
                ; give each bank back, last first
@hr_free        LDA:    B_NBANKS,X
                BEQ     @hr_freed
                DEC
                STA:    B_NBANKS,X
                REP     #$30
                MX      %00
                AND     #$00FF
                PHX
                CLC
                ADC     1,S
                TAY                             ; Y = row + slot
                LDA:    B_BANKS,Y
                AND     #$00FF
                LDX     #KSVC_BANKFREE
                JSL     SYS_KCALL
                PLX
                SEP     #$20
                MX      %10
                BRA     @hr_free
@hr_freed       LDA     #ST_FREE
                STA:    B_STATE,X
                REP     #$30
                MX      %00
                PLA
                SEC
                RTS
@hr_next8       MX      %10
                REP     #$30
@hr_next16      MX      %00
                PLA
                INC
                CMP     #LD_ROWS
                BCC     @hr_l
                CLC
                RTS

;------------------------------------------------------------------------------
; depended - A = a row -> C=1 when a READY row's deps name it: that row's
; relocated bytes hold this one's banks, so it goes first.  X kept; only the
; stack and the row table (reclaim's rule).
;------------------------------------------------------------------------------
depended        MX      %00
                PHX
                JSR     row_bit
                PHA                             ; 1,S = its bit, 3,S = X
                LDA     #0
@dp_l           PHA                             ; 1,S = i, 3,S = bit, 5,S = X
                JSR     row_addr                ; X = row i
                SEP     #$20
                MX      %10
                LDA:    B_STATE,X
                CMP     #ST_READY
                REP     #$30
                MX      %00
                BNE     @dp_next
                LDA:    B_DEPS,X
                AND     3,S
                BNE     @dp_yes
@dp_next        PLA
                INC
                CMP     #LD_ROWS
                BCC     @dp_l
                PLA
                PLX
                CLC
                RTS
@dp_yes         PLA
                PLA
                PLX
                SEC
                RTS

;==============================================================================
; Statics.  Zero in the file (modimage); the row table is the registry.
; ld_off/ld_bnk/ld_blk/ld_idx/ld_bit/ld_pid/ld_tmp are a call's scratch:
; none is relied on across a KSVC_SLEEP or KSVC_BANKGRANT.
;==============================================================================
ld_off          DS      2               ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)
ld_bnk          DS      2               ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)
ld_idx          DS      2               ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)
ld_bit          DS      2               ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)
ld_pid          DS      2               ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)
ld_tmp          DS      2               ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)
ld_arena        DS      2               ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)
ld_blk          DS      BLK_SZ          ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)
ld_use          DS      NPROC*2         ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)
ld_rows         DS      LD_ROWS*ROW_SZ  ; MODBANK-OK: only from ld_entry's tree, DBR = ours (PHK/PLB)

ld_end          EQU     *

; Placement guards (tools/gen_modplace.py writes MODP_* into modplace.s).
                ERR     ld_hdr-MODP_ORG
                ERR     ld_end-MODP_ORG+ld_bss/MODP_LIMIT
