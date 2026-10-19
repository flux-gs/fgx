;==============================================================================
; sigmask.s - the per-task blocked-signal mask.  FAR BANK.
;
; SYS_SIGSETMASK (#102) and SYS_SIGPROCMASK (#120) are one routine; the core
; bank keeps only a five-byte thunk (src/kernel/signal.s).  HERE because the
; core bank has been at its ceiling for months and this is a cold syscall: the
; first cut cost 119 bytes there against 31 free, and `_Sys_Uptime', `_Sys_RtcRead'
; and `_Sys_RtcWrite' already take this road for the same reason.
;
; The mask itself is NOT here.  It lives in the Kmalloc'd signal-handler block at
; SIGHND_MASK_OFF, (pid-1)*4, reached through the direct-page long pointer
; `_sigHndPtr' -- so this routine needs D on the kernel page, which a syscall
; arm has, and the bytes it reads are heap, not far-bank statics.  Only the
; scratch below is bank-local, which is why the PHK/PLB bracket is here at all.
;==============================================================================

_spmNewLo       DS      2               ; requested mask, low word
_spmNewHi       DS      2               ; requested mask, high word
_spmHow         DS      2               ; SIG_* how
_spmSlot        DS      2               ; this task's slot offset in the block
_spmOldWord     DS      2               ; the word currently being combined
_spmOldLo       DS      2               ; old mask, low word, for the return
_spmOldHi       DS      2               ; old mask, high word

;------------------------------------------------------------------------------
; _Sys_SigProcMaskFar - read and update the calling task's blocked mask.
;
; In:  A = new mask lo16, X = new mask hi16, Y = how.  MX %00.
; Out: C=1, A = old lo16, Y = old hi16.  C=0 + A = EINVAL for an unknown how.
;
; A = low word and Y = HIGH word is the 32-bit return convention the __syscall
; builtin already latches -- libc reads the second half back with
; `__syscall_y()', lseek does exactly this (toolchain/lib/libc_c/syscall_file.c),
; and fcc_runtime_data.s calls the latch cell "the return-hi word".
;
; ONE ROUTINE, TWO NUMBERS.  #102 is BSD's retired `sigsetmask' and #120 is
; `sigprocmask', which this 2.11BSD carries as syscall 32 while 109 and 110 are
; "(old sigblock)" and "(old sigsetmask)" in usr/sys/sys/syscalls.c.  how = 0 is
; SIG_SETMASK because that is what #102's callers already send: libc's
; sigsetmask passes 0 as the third syscall argument, so the old number keeps its
; meaning with no change on either side.  The old mask now comes back from both,
; which is what lets libc stop shadowing it in `_sig_curmask'.
;
; SIGKILL AND SIGSTOP CANNOT BE BLOCKED -- apple/fgx#471.  `sigcantmask' is
; `sigmask(SIGKILL) | sigmask(SIGSTOP)' (vendor/2.11BSD/usr/sys/h/signalvar.h:121)
; and upstream subtracts it on the two arms that can ADD bits, and deliberately
; NOT on UNBLOCK (usr/sys/sys/kern_sig2.c:230-238) -- clearing a bit that can
; never be set is harmless.  Without it a task blocks SIGKILL, `_Sys_CheckSignal'
; steps over the pending bit for ever, and the task cannot be killed.
;
; ENFORCED ON THE WRITE, not in libc: the mask is reachable through either
; number from any caller, and a guard only one road passes is the shape
; `_Sys_Signal' already avoids for the CATCH path, where SIGKILL and SIGSTOP are
; refused a handler outright.
;
; The user convention is bit (s-1), so SIGKILL (9) is $0100 of the low word and
; SIGSTOP (17) is bit 0 of the high word.
;------------------------------------------------------------------------------
_Sys_SigProcMaskFar ENT
                MX      %00
                CPY     #SIG_HOW_COUNT
                BCC     @spm_howOK
                LDA     #EINVAL
                CLC
                RTL                             ; no DBR to restore yet
@spm_howOK      PHB                             ; the scratch above is far-bank
                PHK
                PLB
                STA     _spmNewLo
                STX     _spmNewHi
                STY     _spmHow
                LDA     _curTask
                AND     #$00FF
                DEC
                ASL
                ASL                             ; (pid-1)*4
                CLC
                ADC     #SIGHND_MASK_OFF
                TAY
                STY     _spmSlot

                ; --- low word ---
                LDA     [_sigHndPtr],Y
                STA     _spmOldWord
                STA     _spmOldLo
                LDA     _spmNewLo
                AND     #{$FFFF-SIG_CANTMASK_LO}    ; never block SIGKILL
                JSR     _Spm_Combine
                LDY     _spmSlot
                STA     [_sigHndPtr],Y

                ; --- high word ---
                INY
                INY
                STY     _spmSlot
                LDA     [_sigHndPtr],Y
                STA     _spmOldWord
                STA     _spmOldHi
                LDA     _spmNewHi
                AND     #{$FFFF-SIG_CANTMASK_HI}    ; never block SIGSTOP
                JSR     _Spm_Combine
                LDY     _spmSlot
                STA     [_sigHndPtr],Y

                LDA     _spmOldLo
                LDY     _spmOldHi
                SEC
                PLB                             ; restore the caller's DBR
                RTL

;------------------------------------------------------------------------------
; _Spm_Combine - one word of the update.
;
; In:  A = the new word, already stripped of sigcantmask.  _spmOldWord = the
;      word just read back from the slot.  _spmHow = how.  DBR = this bank.
; Out: A = the word to store.
;------------------------------------------------------------------------------
_Spm_Combine    MX      %00
                LDX     _spmHow
                CPX     #SIG_BLOCK
                BEQ     @spc_block
                CPX     #SIG_UNBLOCK
                BEQ     @spc_unblock
                CPX     #SIG_QUERY
                BEQ     @spc_query
                RTS                             ; SIG_SETMASK: A as given
@spc_block      ORA     _spmOldWord
                RTS
@spc_unblock    EOR     #$FFFF
                AND     _spmOldWord
                RTS
@spc_query      LDA     _spmOldWord             ; write the old word back
                RTS
