;==============================================================================
; SPDX-License-Identifier: BSD-2-Clause
; SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
; FGX-Provenance: 2.11BSD usr/sys/pdp/mch_xxx.s, usr/lib/libc/pdp/gen/bcopy.s
;   setjmp and longjmp written for FGX after usr/sys/pdp/mch_xxx.s, 2.11BSD, and
;   bcopy after usr/lib/libc/pdp/gen/bcopy.s.
;   Original work: Copyright (c) 1987 Regents of the University of California.
;   All rights reserved.
;
; net_asm.s - the network code's assembly in bsdnet0: the C-to-kernel seam the
; other kernel modules share, unchanged.  kc_sys.s only moves D, and reads a C
; string through the caller's DBR, which is the data bank where C's strings are.
; tools/build_bsdnet.py PUTs that file first: a macro from a nested PUT is not
; visible to the file that PUT it.
;==============================================================================
_modFnPtrTab    ANOP
_modFnPtrBytes  EQU     0

; kc_printstr(s) - log a string with no newline handling of its own.
kc_printstr     MX      %00
                ENTERK
                LDA     6,S
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                LEAVEK
                RTL

;------------------------------------------------------------------------------
; spl.  The 65816 has one mask, so what these return is the I bit as it was and
; splx puts it back, as kc_spltty does in the tty bank.
;
; splnet MASKS NOTHING.  It exists on the PDP-11 to hold off the network software
; interrupt, and netintr runs only at the kernel's deferred-work drain, which no
; kernel code reaches until it sleeps.  So a region at splnet cannot be entered,
; and masking through TCP processing would stop the VBL.  Nothing may call
; protocol code from an interrupt while this holds.
;
; splimp and splhigh set I: they guard what the driver touches at interrupt time.
;------------------------------------------------------------------------------
splimp          MX      %00
                PHP
                SEI
                SEP     #$20
                MX      %10
                PLA
                AND     #$04
                REP     #$20
                MX      %00
                AND     #$00FF
                RTL

splhigh         MX      %00
                PHP
                SEI
                SEP     #$20
                MX      %10
                PLA
                AND     #$04
                REP     #$20
                MX      %00
                AND     #$00FF
                RTL

splnet          MX      %00
                PHP
                SEP     #$20
                MX      %10
                PLA
                AND     #$04
                REP     #$20
                MX      %00
                AND     #$00FF
                RTL

splx            MX      %00
                LDA     4,S
                AND     #$0004
                BNE     @sx_keep
                CLI
                RTL
@sx_keep        SEI
                RTL

;------------------------------------------------------------------------------
; The drain's two doors, in the tty bank (src/kernel/tty/net_hooks.s).  The kernel
; bank comes from SYS_KCALL's bank-0 JML cell, so nothing here needs a core entry.
;------------------------------------------------------------------------------
setsoftnet      MX      %00
_nhSoft         JSL     KTTY_NET_SOFT   ; the bank byte is stamped by net_hookinit
                RTL

; net_hookinit() - stamp that JSL and hand the drain netintr_enter.
net_hookinit    MX      %00
                PHB
                PHK
                PLB
                SEP     #$20
                MX      %10
                LDAL    SYS_KCALL+3     ; the live kernel bank
                CLC
                ADC     #2              ; the tty bank
                STA     |_nhSoft+3
                STA     |@hook+3
                PHK
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                LDA     #netintr_enter
@hook           JSL     KTTY_NET_HOOK
                PLB
                RTL

; net_stack_bot() - the lowest address of netintr's stack.
net_stack_bot   MX      %00
                LDA     #FGX_STK_NET
                RTL

; net_stack_paint() - fill it, so net_stack_hwm can read how deep it has been.
net_stack_paint MX      %00
                LDX     #FGX_STK_NET_SIZE-2
                LDA     #$A5A5
@sp_l           STAL    $000000+FGX_STK_NET,X
                DEX
                DEX
                BPL     @sp_l
                RTL

; net_stack_hwm() - the bytes of it ever used.
net_stack_hwm   MX      %00
                LDX     #0
@hw_l           LDAL    $000000+FGX_STK_NET,X
                CMP     #$A5A5
                BNE     @hw_d
                INX
                INX
                CPX     #FGX_STK_NET_SIZE
                BCC     @hw_l
@hw_d           TXA
                EOR     #$FFFF
                SEC
                ADC     #FGX_STK_NET_SIZE
                RTL

; netintr_enter - the drain calls this.  D is already kernel C's: the tty bank's
; bracket set it.  DBR is set here to the data bank.  S moves to netintr's stack,
; whose floor stands in for the caller's while it is there.  The idle site drains
; with I set, and the protocols run with it clear; the caller gets its own back.
netintr_enter   MX      %00
                PHB
                PHP
                PHK
                PLB
                SEP     #$20
                MX      %10
                LDA     |_bnDataBank
                PHA
                PLB
                REP     #$20
                MX      %00
                TSC
                TAX
                LDA     _fcc_stkfloor
                TAY
                LDA     #FGX_STK_NET_TOP
                TCS
                PHX
                PHY
                LDA     #FGX_STK_NET+FCC_STK_FLOOR_MARGIN
                STA     _fcc_stkfloor
                LDA     #1
                STA     |net_in_intr
                CLI
                PHK
                PEA     @ret-1
                PHK
                PEA     netintr-1
                RTL
@ret            STZ     |net_in_intr
                PLA
                STA     _fcc_stkfloor
                PLA
                TCS
                PLP
                PLB
                RTL

;------------------------------------------------------------------------------
; bcopy(src, dst, n) - 2.11BSD's (libc pdp/gen/bcopy.s): n unsigned, and an
; overlapping move handled, backward when dst is above src.  Here that is MVN
; forward and MVP backward, seven cycles a byte.  An overlap needs one bank, so
; only then is the offset compare taken; across banks MVN is always right.  A
; pointer does not carry into the next bank, as fcc's own `p++' does not.
;
;   4,S src offset   6,S src bank   8,S dst offset   10,S dst bank   12,S n
;
; THE BANK OPERANDS ARE PATCHED INTO THE CODE, as uio_copy does in the VFS bank
; (src/modules/vfs/uio_copy.s): operand+1 the destination bank, +2 the source.
; That is not re-entrant, and needs no guard: kernel code is not preempted, and
; no interrupt handler reaches the stack (if_w5.c: only task level and netintr).
; MVN and MVP leave DBR on the destination bank; PLB gives the caller's back.
;------------------------------------------------------------------------------
bcopy           MX      %00
                LDA     12,S
                BEQ     @bc_none        ; zero is not 65536: MVN moves A+1
                PHB                     ; the frame is one byte further now
                PHK
                PLB                     ; DBR = this bank, for the patches
                SEP     #$20
                MX      %10
                LDA     7,S             ; src bank
                STA     |@bc_fwd+2
                STA     |@bc_back+2
                LDA     11,S            ; dst bank
                STA     |@bc_fwd+1
                STA     |@bc_back+1
                CMP     7,S
                REP     #$20
                MX      %00
                BNE     @bc_up          ; two banks: no overlap
                LDA     9,S
                CMP     5,S
                BEQ     @bc_out         ; dst == src: nothing to move
                BCS     @bc_down        ; dst above src: backward
@bc_up          LDA     5,S
                TAX
                LDA     9,S
                TAY
                LDA     13,S
                DEC
@bc_fwd         MVN     $00,$00         ; banks patched above
                PLB
                RTL
@bc_down        LDA     13,S            ; MVP starts at each block's last byte
                DEC
                PHA
                CLC
                ADC     7,S             ; src + n-1 (the frame is two further)
                TAX
                PLA
                PHA
                CLC
                ADC     11,S            ; dst + n-1
                TAY
                PLA
@bc_back        MVP     $00,$00         ; banks patched above
@bc_out         PLB
@bc_none        RTL

; setjmp(env) / longjmp(env, val) - the kernel's, after 2.11BSD pdp/mch_xxx.s:
; sleep() longjmps to u.u_qsave when a signal breaks an interruptible sleep, and
; uipc_syscalls.c's setjmp arms catch it.  fcc emits both as builtins with env in
; X (an offset in DBR's bank, the data bank) and, for longjmp, val in A.
; The layout is libc's (toolchain/lib/libc.s) less the signal mask, which is
; libc's business and not the kernel's; its two words carry val across the
; restore here instead.
;   +0 PB  +1 DBR  +2 _fcc_fb  +4 PC  +6 S  +8 D  +10 _fcc_sfp  +12 val
;   +16..+47 the callee-saved band _fcc_img16.._fcc_img31 ($78-$97)
setjmp          MX      %00
                PHP
                REP     #$30
                MX      %00
                PHY
                SEP     #$20
                MX      %10
                LDA     6,S                     ; the caller's PB
                STA:    $0000,X
                PHB
                PLA
                STA:    $0001,X
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                STA:    $0002,X
                LDA     4,S                     ; the return PC
                STA:    $0004,X
                TSC
                CLC
                ADC     #6                      ; S at the call, once returned
                STA:    $0006,X
                TDC
                STA:    $0008,X
                LDA     _fcc_sfp
                STA:    $000A,X
                TXA
                CLC
                ADC     #16+30
                TAY
                LDX     #30
@sj_band        LDA     $78,X
                STA:    $0000,Y
                DEY
                DEY
                DEX
                DEX
                BPL     @sj_band
                PLY
                PLP
                LDA     #0
                RTL

longjmp         MX      %00
                REP     #$30
                MX      %00
                CMP     #0
                BNE     @lj_val
                LDA     #1
@lj_val         STA:    $000C,X
                LDA:    $0008,X
                TCD                             ; D first: the band is D-relative
                PHX
                TXA
                CLC
                ADC     #16+30
                TAY
                LDX     #30
@lj_band        LDA:    $0000,Y
                STA     $78,X
                DEY
                DEY
                DEX
                DEX
                BPL     @lj_band
                PLX
                LDA:    $0002,X
                STA     _fcc_fb
                LDA:    $000A,X
                STA     _fcc_sfp
                LDA:    $0006,X
                TCS
                SEP     #$20
                MX      %10
                LDA:    $0000,X                 ; RTL pulls PC then PB
                PHA
                REP     #$20
                MX      %00
                LDA:    $0004,X
                PHA
                LDA:    $000C,X
                TAY                             ; val, across the bank change
                SEP     #$20
                MX      %10
                LDA:    $0001,X
                PHA
                PLB
                REP     #$20
                MX      %00
                TYA
                RTL

; kc_sigraise(sig) - post sig to the calling process (sosend's SIGPIPE).
kc_sigraise     MX      %00
                ENTERK
                LDA     6,S
                LDX     #KSVC_SIGRAISE
                JSL     SYS_KCALL
                LEAVEK
                RTL

; kc_unpname(op, path, so) - an AF_UNIX name through the kernel's unp_nameop
; (KSVC_UNPNAME, src/kernel/vfs/vfs_syscalls.c): UNP_OP_BIND names path for so,
; UNP_OP_LOOKUP finds the socket path names, UNP_OP_UNBIND releases so's name.
; path is a far pointer to a NUL-terminated name, so the socket's offset in this
; bank.  Returns the errno, or 0 with a lookup's socket in bn_unpso.  The kernel
; cells are written with DBR on the kernel bank, as w5_asm.s reads its own.
; Arguments, after ENTERK and the PHB: op 7,S; path 9,S and its bank 11,S;
; so 13,S.
kc_unpname      MX      %00
                ENTERK
                PHB
                SEP     #$20
                MX      %10
                LDAL    SYS_KCALL+3
                PHA
                PLB
                REP     #$20
                MX      %00
                LDA     7,S
                STA     |_unpNameOp
                LDA     13,S
                STA     |_unpSlot
                PLB
                LDA     10,S                    ; path's bank (8,S is its offset)
                AND     #$00FF
                TAY
                LDA     8,S
                LDX     #KSVC_UNPNAME
                JSL     SYS_KCALL
                BCC     @ku_out                 ; A = the errno
                PHB
                SEP     #$20
                MX      %10
                LDAL    SYS_KCALL+3
                PHA
                PLB
                REP     #$20
                MX      %00
                LDA     |_unpSlot
                PLB
                STA     |bn_unpso
                LDA     #0
@ku_out         LEAVEK
                RTL

; kc_unpfile(op, a, b, c) - a descriptor passed over AF_UNIX: the file-table op
; (KSVC_UNPFILE, src/kernel/vfs/vfs_file.c unp_fileop) on the handles in a
; rights record.  The block is the kernel's _unpfArgs, written with DBR on the
; kernel bank as kc_unpname writes its cells; its last two words point at
; bn_unpfout in this bank, where fpfetch leaves its struct file.  Returns the
; op's answer.  Arguments, after ENTERK and the PHB: op 7,S, a 9,S, b 11,S,
; c 13,S.
kc_unpfile      MX      %00
                ENTERK
                PHB                             ; this bank, for the result block
                LDA     1,S
                AND     #$00FF
                TAY
                SEP     #$20
                MX      %10
                LDAL    SYS_KCALL+3
                PHA
                PLB                             ; DBR = the kernel bank
                REP     #$20
                MX      %00
                STY     |_unpfArgs+10           ; bn_unpfout: bank
                LDA     #bn_unpfout
                STA     |_unpfArgs+8            ;   and offset
                LDA     7,S
                STA     |_unpfArgs
                LDA     9,S
                STA     |_unpfArgs+2
                LDA     11,S
                STA     |_unpfArgs+4
                LDA     13,S
                STA     |_unpfArgs+6
                PLB
                LDX     #KSVC_UNPFILE
                JSL     SYS_KCALL               ; C=1 + A = the answer
                LEAVEK
                RTL

; bn_sysent - net.mod's way in for a process's socket call (src/modules/net/
; net_kso.s).  Entered as by JSL, with A = the offset in bank 0 of the call block
; on the caller's kernel stack.  D becomes kernel C's register page and DBR the
; data bank, as for any kernel C, and bn_sys (machine/bn_sys.c) is called with a
; far pointer to the block.  Out: C=1 + A = u.u_r.r_val1 + X = r_val2, or C=0 +
; A = u.u_error.  fcc's stack floor is the caller's slot's for the call, so a
; socket call that runs off the slot halts through _fcc_stkoflow; the page's
; floor is put back at return, and swtch saves it per task across a sleep.
bn_sysent       MX      %00
                PHB
                PHD
                TAX
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     _fcc_stkfloor           ; the caller's floor, back at return
                PHA
                LDA     |_kCurKStkBase          ; DBR is still net.mod's, the
                CLC                             ;   kernel bank: this task's slot
                ADC     #FCC_STK_FLOOR_MARGIN
                STA     _fcc_stkfloor
                PHK
                PLB
                SEP     #$20
                MX      %10
                LDA     |_bnDataBank
                PHA
                PLB
                REP     #$20
                MX      %00
                PEA     0                       ; the block's bank
                PHX                             ; and offset
                PHK
                PEA     @bs_ret-1
                PHK
                PEA     bn_sys-1
                RTL
@bs_ret         PLX
                PLX
                PLA
                STA     _fcc_stkfloor
                LDA     |bn_ret                 ; u_error
                BNE     @bs_err
                LDA     |bn_ret+4               ; u_r.r_val2
                TAX
                LDA     |bn_ret+2               ; u_r.r_val1
                PLD
                PLB
                SEC
                RTL
@bs_err         PLD
                PLB
                CLC
                RTL
