;==============================================================================
; libc_start.s - libc's half of program startup (shared libc SP3 spec,
; section 3).  A program's crt0 (crt0_lib.s) calls _libc_start first, and
; its signal stub jumps to _libc_sigtramp: both name libc's own core cells,
; which a program linked against libc.so cannot.  Their scratch cells are in
; libc_start_data.s.
;==============================================================================
_LS_DATA_DP     EQU     $B8                 ; DP byte: the task's data bank (fcc_runtime.s DP map)
_LS_SETMASK     EQU     102                 ; SYS_SIGSETMASK
_LS_ARGS_MAX    EQU     16                  ; MUST MATCH args_data.s ARGS_MAX
_LS_ENV_MAX     EQU     256                 ; MUST MATCH args_data.s ARGS_ENV_MAX
_LS_ENVV_MAX    EQU     32                  ; MUST MATCH args_data.s ARGS_ENVV_MAX

;------------------------------------------------------------------------------
; _libc_start - fill libc's argument, environment and signal cells.
; JSL'd by crt0 before it pushes anything, A = the offset of the program's
; _sig_tramp in segment 0 (the kernel delivers signals there).  After the JSL
; (3 bytes) and the PHP (1) the kernel's argv frame is at caller_S = S+4:
; argc at caller_S+1, argv[i] at +3+2i, envp after argv's NULL.  MX %00 in
; and out; RTL.
;------------------------------------------------------------------------------
                FGX2_EXPORT _libc_start
_libc_start     MX      %00
                STA     _sig_tramp_off
                PHP
                REP     #$30
                MX      %00
                TSC
                CLC
                ADC     #4
                STA     _ls_callerS

                ; Zero output state.
                STZ     args_argc
                STZ     __progname
                LDA     #1
                STA     args_optind                 ; BSD: optind starts at 1
                STZ     args_optarg
                STZ     args_optopt
                ; Cache the DBR (the data bank holding args_env) so the
                ; envp walk can stamp each environ entry's bank byte.  argv
                ; needs no such value: its strings are all in bank 0.
                STZ     _ls_dataBank
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _ls_dataBank
                REP     #$20
                MX      %00
                LDX     #0
@cs_zaL         STZ     args_argv,X
                INX
                INX
                CPX     #4*_LS_ARGS_MAX
                BCC     @cs_zaL

                ; Read kernel argc from caller_S+1.
                LDA     _ls_callerS
                INC
                TAX
                LDAL    $000000,X
                AND     #$00FF                      ; cap at 255
                STA     _ls_kernArgc

                ; Walk argv[i] for i = 0..kernArgc-1.  Copy each string into
                ; and point args_argv[i] at it in the frame (only if
                ; i < _LS_ARGS_MAX).
                STZ     _ls_walkIdx
@cs_walkL       LDA     _ls_walkIdx
                CMP     _ls_kernArgc
                BCS     @cs_walkDone

                ; ptr_addr = caller_S + 3 + 2*walkIdx.
                LDA     _ls_walkIdx
                ASL
                CLC
                ADC     #3
                CLC
                ADC     _ls_callerS
                TAX
                LDAL    $000000,X                   ; A = argv[walkIdx] ptr
                STA     _ls_strBank0Ptr

                ; If walkIdx < _LS_ARGS_MAX, store a 4-byte char* (offset+bank)
                ; into args_argv[walkIdx].
                LDA     _ls_walkIdx
                CMP     #_LS_ARGS_MAX
                BCS     @cs_skipPtr
                ASL                                 ; *4 (4-byte entries)
                ASL
                TAX
                LDA     _ls_strBank0Ptr
                STA     args_argv,X                 ; +0/+1 = the frame offset
                STZ     args_argv+2,X               ; +2 = bank 0, +3 = pad
                ; Track args_argc as the count of slots actually populated.
                INC     args_argc

                ; If this is argv[0], compute __progname = basename(argv[0]).
                LDA     _ls_walkIdx
                BNE     @cs_skipPtr
                JSR     _ls_set_progname

@cs_skipPtr     INC     _ls_walkIdx
                JMP     @cs_walkL

@cs_walkDone    ; T7-environ (E1): walk the envp table that follows argv's NULL
                ; terminator (ptrs from caller_S + 5 + 2*kernArgc) and pack
                ; each "NAME=VAL" string into args_env; an entry that would
                ; not fit ends the walk (fail-soft).  The
                ; block is double-NUL terminated for getenv's walker.
                STZ     args_envc
                STZ     _ls_envIdx
                STZ     _ls_envOff
@ce_L           LDA     _ls_kernArgc
                CLC
                ADC     _ls_envIdx
                ASL
                CLC
                ADC     #5
                CLC
                ADC     _ls_callerS
                TAX
                LDAL    $000000,X                   ; A = envp[envIdx] ptr
                BEQ     @ce_done                    ; NULL terminator
                STA     _ls_strBank0Ptr
                ; T7 E4: record this entry's args_env offset in the `environ`
                ; vector BEFORE packing it (_ls_envOff still points at the
                ; entry's first byte).  A slot written for an entry that then
                ; fails to fit is harmless: @ce_done NUL-terminates at
                ; _ls_envIdx, overwriting it.
                LDA     _ls_envIdx
                CMP     #_LS_ENVV_MAX
                BCS     @ce_noVec                   ; vector full, keep packing
                ASL                                 ; *4 (4-byte entries)
                ASL
                TAX
                LDA     _ls_envOff
                CLC
                ADC     #args_env
                STA     args_envv,X                 ; +0/+1 = offset
                LDA     _ls_dataBank
                STA     args_envv+2,X               ; +2 = bank, +3 = 0 (pad)
@ce_noVec       JSR     _ls_copyToEnv             ; C=0 -> did not fit, stop
                BCC     @ce_done
                INC     _ls_envIdx
                INC     args_envc
                BRA     @ce_L
@ce_done        ; terminating EMPTY string (the double NUL)
                LDY     _ls_envOff
                SEP     #$20
                MX      %10
                LDA     #0
                STA     args_env,Y
                REP     #$20
                MX      %00
                ; T7 E4: NULL-terminate the environ vector and publish it.
                LDA     _ls_envIdx
                CMP     #_LS_ENVV_MAX
                BCC     @ce_vecOk
                LDA     #_LS_ENVV_MAX              ; clamp: reserved last slot
@ce_vecOk       ASL                                 ; *4
                ASL
                TAX
                STZ     args_envv,X
                STZ     args_envv+2,X
                LDA     #args_envv                  ; environ = &args_envv[0]
                STA     environ
                LDA     _ls_dataBank
                STA     environ+2
                ; The task's data bank, which the walk above cached in
                ; _ls_dataBank: for _libc_sigtramp (DP is per-task and
                ; bank-free) and for libc's int->pointer conversions.
                LDA     _ls_dataBank
                STA     _fcc_dbr
                SEP     #$20
                MX      %10
                STA     _LS_DATA_DP
                REP     #$20
                MX      %00
                PLP
                RTL


_ls_copyToEnv MX      %00
                LDX     _ls_strBank0Ptr
                LDY     _ls_envOff
                SEP     #$20
                MX      %10
@cv_L           CPY     #_LS_ENV_MAX-2
                BCS     @cv_nofit
                LDAL    $000000,X
                STA     args_env,Y
                BEQ     @cv_done
                INX
                INY
                BRA     @cv_L
@cv_nofit       REP     #$20
                MX      %00
                CLC
                RTS
@cv_done        INY
                REP     #$20
                MX      %00
                STY     _ls_envOff
                SEC
                RTS

_ls_set_progname MX  %00
                ; Default basename = the start of argv[0] in the frame.
                LDA     _ls_strBank0Ptr
                STA     _ls_baseOff
                LDX     _ls_strBank0Ptr
@pn_L           SEP     #$20
                MX      %10
                LDAL    $000000,X                   ; byte of argv[0], bank 0
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @pn_done
                INX
                CMP     #'/'
                BNE     @pn_L
                STX     _ls_baseOff               ; offset just past the '/'
                BRA     @pn_L
@pn_done        LDA     _ls_baseOff
                STA     __progname
                RTS

;------------------------------------------------------------------------------
; _libc_sigtramp - the fcc signal-handler adapter, reached by JML from the
; program's segment-0 _sig_tramp (crt0_lib.s) with the kernel's delivery
; frame; _libc_start stashes the data bank in DP $B8 (_LS_DATA_DP).
;------------------------------------------------------------------------------
                FGX2_EXPORT _libc_sigtramp

_libc_sigtramp  MX      %00
                PHP                                 ; syscall C (+ flags)
                PHX                                 ; syscall return A
                PHY                                 ; syscall return Y
                AND     #$00FF
                TAY                                 ; Y = signum (A dies below)
                PHB                                 ; save delivery-time DBR
                SEP     #$20
                MX      %10
                LDA     _LS_DATA_DP                ; DP $B8 (_libc_start stashed it)
                PHA
                PLB                                 ; DBR = data bank
                REP     #$20
                MX      %00
                ; --- #53: BLOCK THE DELIVERED SIGNAL FOR THIS HANDLER ---
                ; The kernel has already OR'd the bit into its own per-task
                ; mask.  Two things still have to happen here.
                ;
                ; SAVE THE PRE-DELIVERY MASK ON THIS FRAME.  Not in a per-task
                ; kernel cell: a DIFFERENT signal may nest inside this handler,
                ; and each delivery must unwind to its own predecessor.  The
                ; trampoline's own stack gives that for free.
                ;
                ; AND BLOCK IT IN LIBC'S SHADOW TOO, which is not belt-and-
                ; braces.  libc computes sigblock(m) as sigsetmask(shadow | m),
                ; so a handler calling sigblock(0) -- which is literally tcsh
                ; pintr1's first act, `sigsetmask(sigblock(0) & ~sigmask(SIGINT))`
                ; -- would reinstall a shadow that lacks the kernel's block and
                ; UNBLOCK ITS OWN SIGNAL mid-handler.  The fix would then be
                ; defeated in precisely the case it exists for.
                LDA     _sig_curmask+2
                PHA
                LDA     _sig_curmask
                PHA                                 ; saved: hi then lo
                LDA     #1
                STA     _ls_sigbit
                STZ     _ls_sigbitHi
                TYA                                 ; A = signum
                DEC                                 ; bit (sig-1)
                BEQ     @st_bitDone                 ; signal 1 -> bit 0, no shift
                TAX
@st_bitL        ASL     _ls_sigbit
                ROL     _ls_sigbitHi
                DEX
                BNE     @st_bitL
@st_bitDone     LDA     _sig_curmask
                ORA     _ls_sigbit
                STA     _sig_curmask
                LDA     _sig_curmask+2
                ORA     _ls_sigbitHi
                STA     _sig_curmask+2
                ; --- sigaction(2)'s sa_mask: the set this handler runs with
                ; blocked IN ADDITION to its own signal.  Upstream applies it in
                ; postsig -- `p_sigmask |= u.u_sigmask[sig] | mask'
                ; (vendor/2.11BSD/usr/sys/sys/kern_sig2.c, setsigvec stores it) --
                ; and this is FGX's postsig: the only place that both knows the
                ; signum and owns the unwind.
                ;
                ; `_sig_act_maskoff' is 0 unless the binary called sigaction, so
                ; a plain signal(2) user pays one LDA and a branch.  The table is
                ; sigaction's own static in THIS data bank, hence abs,X off a zero
                ; base with the whole address in X.
                ;
                ; The kernel's own mask has only the delivered bit, so the set has
                ; to be pushed down as well as shadowed -- one syscall, and only
                ; when there is a set.  The restore at @st_back pops the
                ; pre-delivery mask and reinstalls it, which unwinds this too.
                LDA     _sig_act_maskoff
                BEQ     @st_noActMask
                TYA                                 ; signum (Y is untouched)
                ASL
                ASL                                 ; sig * 4 (a 32-bit set each)
                CLC
                ADC     _sig_act_maskoff            ; read twice: cheaper than a
                TAX                                 ;   scratch cell in every binary
                LDA:    $0000,X
                ORA:    $0002,X
                BEQ     @st_noActMask               ; empty set: nothing to do
                LDA:    $0000,X
                ORA     _sig_curmask
                STA     _sig_curmask
                LDA:    $0002,X
                ORA     _sig_curmask+2
                STA     _sig_curmask+2
                ; Y IS THE SIGNUM AND THE SYSCALL CLOBBERS IT.  The identical
                ; call at @st_back needs no such guard and says "A/X/Y are free
                ; here" -- true there, because the dispatch is already done.
                ; Here the signum still has to index `_sig_c_tab' and be pushed
                ; as the handler's argument, so it is saved across the call.
                PHY
                LDA     _sig_curmask                ; A = lo16, X = hi16:
                LDX     _sig_curmask+2              ;   SYS_SIGSETMASK's shape
                JSL     SYS_TRAMP
                DFB     _LS_SETMASK
                PLY
@st_noActMask   PHY                                 ; fcc int arg (signum)
                ; #45 Fix B2: hard-floor tripwire before dispatching the C
                ; handler.  The handler runs its (possibly UNGUARDED small-frame)
                ; C subtree on top of the interrupted frame + this trampoline.
                ; An unguarded handler skips the prologue STKGUARD floor check,
                ; so trap LOUDLY (exit 134) here if the stack has already reached
                ; the HARD floor StackBase (= _fcc_stkfloor - MARGIN) rather than
                ; let the handler scribble below the arena into a neighbouring
                ; task.  Compare against StackBase, NOT _fcc_stkfloor: the pad
                ; region [StackBase, floor) is LEGAL for non-C users (this
                ; trampoline, IRQ/shim pushes), so a floor compare would false-
                ; trap a normal signal delivered at deep C depth.  `-6` also
                ; covers the 6 dispatch bytes still to be pushed (PHK/PEA/PHA/PHA)
                ; before the RTL into the handler.  Real room = B1' sizing
                ; (stack_measure signal one-hop reserve); this only backstops an
                ; overrun.  (S+MARGIN can't wrap: task arenas are low bank 0.)
                TSC                                 ; A = S (MX %00; A dead here)
                CLC
                ADC     #128-6                      ; S + MARGIN - dispatch pushes
                CMP     _fcc_stkfloor               ; vs StackBase+MARGIN (DP $B9)
                BCC     @st_oflow                   ; below hard floor -> trap
                ; Signum -> registered C handler cell.  This set MUST match the
                ; kernel's catchable set (signal.s _SigHndBase) and libc's
                ; signal() dispatch: the kernel schedules THIS trampoline for
                ; any of them, so a signum missing an arm here would fall
                ; through to the SIGINT cell and call the wrong handler.
                ; ONE INDEXED LOAD, not a per-signal CMP chain (apple/fgx#58).
                ; The chain here had one arm per catchable signal and was half
                ; of the five-signal ceiling -- the kernel's five handler
                ; tables were the other half.  _sig_c_tab is the process's own
                ; disposition table (libc_data), BSD's u_signal[NSIG], indexed
                ; by the signum the kernel handed us in Y.
                ;
                ; Y is still the signum and must stay so: it was PHY'd above as
                ; the handler's fcc int argument.
                TYA
                ASL
                ASL                                 ; sig * 4 (far-cell stride)
                TAX
                LDA     _sig_c_tab+2,X              ; bank byte (+ pad)
                PHA
                LDA     _sig_c_tab,X                ; handler offset
                PLX                                 ; X = bank, A = offset --
                                                    ;   the shape @st_have wants
@st_have        CMP     #2                          ; SIG_DFL (0) / SIG_IGN (1)?
                BCS     @st_call                    ;   only with bank 0: a handler
                TAY                                 ;   at bank:$0000 is a function
                TXA                                 ;   (K&R A.6.6: a null pointer
                AND     #$00FF                      ;   is unequal to any pointer
                BEQ     @st_skip                    ;   to a function), not a raw
                TYA                                 ;   disposition
@st_call        TAY                                 ; Y = handler offset
                PHK                                 ; return frame: this bank
                PEA     @st_back-1
                SEP     #$20
                MX      %10
                TXA
                PHA                                 ; target bank
                REP     #$20
                MX      %00
                TYA
                DEC
                PHA                                 ; target offset-1
                RTL                                 ; -> C handler (far-call shape)
@st_back        PLA                                 ; pop the signum arg
                ; --- #53: undo the handler block ---
                ; Pop the pre-delivery mask (lo then hi -- pushed hi first),
                ; write it back to libc's shadow, and reinstall it in the KERNEL.
                ; The pop order leaves A = lo16 and X = hi16, which is exactly
                ; SYS_SIGSETMASK's convention.  A/X/Y are free here: the
                ; interrupted context's registers are still deeper on the stack
                ; and are pulled at @st_restore.
                ;
                ; This syscall's own exit may deliver a signal that was blocked
                ; and is now pending -- nesting one more trampoline on top of
                ; this one.  That is correct, and it is how a coalesced signal
                ; finally runs.
                PLA                                 ; saved mask lo
                STA     _sig_curmask
                PLX                                 ; saved mask hi
                STX     _sig_curmask+2
                JSL     SYS_TRAMP
                DFB     _LS_SETMASK
                PLB                                 ; restore delivery-time DBR
@st_restore     PLY                                 ; syscall return Y
                PLX                                 ; syscall return A
                PLP                                 ; syscall C (widths saved MX %00)
                TXA                                 ; A = return value (sets N/Z)
                RTL                                 ; pop user JSL frame -> resume
@st_skip        PLA                                 ; pop the signum arg
                ; No handler ran, but the kernel still blocked the signal on
                ; delivery -- unwind it, or it stays blocked forever.
                ; --- #53: undo the handler block ---
                ; Pop the pre-delivery mask (lo then hi -- pushed hi first),
                ; write it back to libc's shadow, and reinstall it in the KERNEL.
                ; The pop order leaves A = lo16 and X = hi16, which is exactly
                ; SYS_SIGSETMASK's convention.  A/X/Y are free here: the
                ; interrupted context's registers are still deeper on the stack
                ; and are pulled at @st_restore.
                ;
                ; This syscall's own exit may deliver a signal that was blocked
                ; and is now pending -- nesting one more trampoline on top of
                ; this one.  That is correct, and it is how a coalesced signal
                ; finally runs.
                PLA                                 ; saved mask lo
                STA     _sig_curmask
                PLX                                 ; saved mask hi
                STX     _sig_curmask+2
                JSL     SYS_TRAMP
                DFB     _LS_SETMASK
                PLB
                BRA     @st_restore
; #45 Fix B2 trap target: stack hit the hard floor before handler dispatch.
; NEAR JMP into this segment's runtime copy of _fcc_stkoflow (same convention
; as the fcc prologue STKGUARD), which reports + exits 134.
@st_oflow       JMP     _fcc_stkoflow
;==============================================================================
; END libc_start.s
;==============================================================================
