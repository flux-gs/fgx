;==============================================================================
; crt0.s - userland C-runtime startup for FGX command-line tools.
;
; PUT-included at the top of each user binary's text segment.  Owns the
; FGX1 program-entry contract:
;
;   1. DBR setup (PHK/PLB sets DBR = own bank).  D is whatever the
;      kernel handed off — currently an MM-allocated bank-0 DP page
;      per task (Commit C); user code makes no assumption about which
;      page, just that it has 256 B of DP scratch.
;   2. Walk the BSD-shaped argv/envp frame the kernel laid on the task's
;      stack at posix_spawn time (slice-3 B.1) and populate the args.s
;      globals: args_argc, args_argv[], __progname.
;   3. JSR main.  User code returns A = 8-bit exit status.
;   4. JSL SYS_EXIT — never returns.
;
; The FGX1 header in each binary is updated to point at `_crt0_start`
; (was `xxx_entry`).  User code now lives in a `main` symbol that crt0
; jumps to.  Drop PHK/PLB and JSL SYS_EXIT from main; crt0 owns both.
;
; Stack frame at crt0 entry (kernel posix_spawn convention):
;     1,S    argc                (16-bit, low byte holds count)
;     3,S    argv[0] ptr         (16-bit bank-0 stack address)
;     5,S    argv[1] ptr
;     ...
;     3+2*argc,S   NULL          (argv terminator)
;     5+2*argc,S   envp[0] ptr
;     ...
;
; All ptrs reference NUL-terminated strings on the same bank-0 stack page,
; and args_argv[] POINTS AT THEM THERE.  crt0 copies nothing: the strings sit
; above `saved_S' with the stack growing down away from them, so they outlive
; every use, which is what 2.11BSD's exec arranges too (apple/fgx#301).
;
; Caller convention (the FGX1 loader's JML to entry):
;   - Native, MX %11.  crt0 immediately REPs to MX %00.
;   - Stack: only the argv frame is on the stack (no return addr above it).
;   - DBR seeded from the resume-frame at TCB_DataBank (own bank); crt0
;     PHK/PLB to normalize.  D is the first page of the task's stack
;     reservation (task.s Task_AllocStack).
;
; Dependencies:
;   - PUT'd binary must define `main` (MX %00 entry) returning A = exit code.
;   - PUT'd binary must define SYS_EXIT and SYS_TRAMP EQUs.
;   - PUT'd binary must also PUT args.s (provides args_argc / args_argv /
;     __progname storage that crt0 writes into).
;==============================================================================

;------------------------------------------------------------------------------
; P3-3 3.3: fcc locals live on the bank-0 HARDWARE stack — each function's
; prologue TSC-seeds the _fcc_fb frame base (S+1, bank 0).  crt0 no longer
; mallocs/seeds a software-stack region; that scaffolding is deleted.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; _crt0_start - entry point.  FGX1 header's entry offset must point here.
;------------------------------------------------------------------------------
_crt0_start     MX      %11
                REP     #$30
                MX      %00
                ; Loader's _Loader_StageArgs (process.s) pre-sets DBR to
                ; the binary's data bank (FGX1: same as PB; multi-bank
                ; FGX2: bank-of-n_data_segment, possibly != PB).  Do
                ; NOT PHK/PLB here — that would force DBR=PB and break
                ; multi-bank's seg0-code-reads-seg1-data invariant.

                JSR     _crt0_setup_argv            ; fills args.s globals

                JSR     main                        ; user code; A = exit status

                AND     #$00FF                      ; clamp to 8 bits
                JSL     SYS_TRAMP
                DFB     SYS_EXIT
@_crt0_safety   BRA     @_crt0_safety               ; SYS_EXIT does not return

;------------------------------------------------------------------------------
; _crt0_setup_argv - walk the bank-0 stack-laid argv frame and populate
; args_argc + args_argv[0..argc-1] + __progname, each pointing INTO the frame.  Initialize args_optind = 1 (BSD getopt convention: optind
; starts after argv[0]).
;
; Caller MX %00.  Clobbers A/X/Y.  Preserves S (uses TSC scratch only).
;------------------------------------------------------------------------------
_crt0_setup_argv MX     %00
                PHP
                REP     #$30
                MX      %00

                ; Capture caller's S.  We entered via JSR so S = caller_S - 2.
                ; PHP -1 → S = caller_S - 3.  Therefore caller_S = S + 3.
                TSC
                CLC
                ADC     #3
                STA     _crt0_callerS

                ; Zero output state.
                STZ     args_argc
                STZ     __progname
                LDA     #1
                STA     args_optind                 ; BSD: optind starts at 1
                STZ     args_optarg
                STZ     args_optopt
                LDX     #0
@cs_zaL         STZ     args_argv,X
                INX
                INX
                CPX     #4*ARGS_MAX
                BCC     @cs_zaL

                ; Read kernel argc from caller_S+1.
                LDA     _crt0_callerS
                INC
                TAX
                LDAL    $000000,X
                AND     #$00FF                      ; cap at 255
                STA     _crt0_kernArgc

                ; Walk argv[i] for i = 0..kernArgc-1 and POINT args_argv[i] at
                ; the kernel's frame -- no copy.  The strings already sit in
                ; bank 0 above `saved_S', where the stack grows down away from
                ; them, so they are stable for the life of the process; that is
                ; 2.11BSD's own arrangement, where `copyoutstr' puts them on the
                ; new process's stack and `suword((caddr_t)ap, ucp)' stores each
                ; argv[i] pointing into it (usr/sys/sys/kern_exec.c:300-338).
                STZ     _crt0_walkIdx
@cs_walkL       LDA     _crt0_walkIdx
                CMP     _crt0_kernArgc
                BCS     @cs_walkDone

                ; ptr_addr = caller_S + 3 + 2*walkIdx.
                LDA     _crt0_walkIdx
                ASL
                CLC
                ADC     #3
                CLC
                ADC     _crt0_callerS
                TAX
                LDAL    $000000,X                   ; A = argv[walkIdx] ptr
                STA     _crt0_strBank0Ptr

                ; If walkIdx < ARGS_MAX, store a 4-byte char* (offset+bank)
                ; into args_argv[walkIdx].
                LDA     _crt0_walkIdx
                CMP     #ARGS_MAX
                BCS     @cs_skipPtr
                ASL                                 ; *4 (4-byte entries)
                ASL
                TAX
                LDA     _crt0_strBank0Ptr
                STA     args_argv,X                 ; +0/+1 = the frame offset
                STZ     args_argv+2,X               ; +2 = bank 0, +3 = pad
                ; Track args_argc as the count of slots actually populated.
                INC     args_argc

                ; If this is argv[0], compute __progname = basename(argv[0]).
                LDA     _crt0_walkIdx
                BNE     @cs_skipPtr
                JSR     _crt0_set_progname

@cs_skipPtr     INC     _crt0_walkIdx
                JMP     @cs_walkL

@cs_walkDone    ; T7-environ (E1): walk the envp table that follows argv's NULL
                ; terminator (ptrs from caller_S + 5 + 2*kernArgc) and pack
                ; each "NAME=VAL" string into args_env; an entry that would
                ; not fit ends the walk (fail-soft).  The
                ; block is double-NUL terminated for getenv's walker.
                STZ     args_envc
                STZ     _crt0_envIdx
                STZ     _crt0_envOff
@ce_L           LDA     _crt0_kernArgc
                CLC
                ADC     _crt0_envIdx
                ASL
                CLC
                ADC     #5
                CLC
                ADC     _crt0_callerS
                TAX
                LDAL    $000000,X                   ; A = envp[envIdx] ptr
                BEQ     @ce_done                    ; NULL terminator
                STA     _crt0_strBank0Ptr
                JSR     _crt0_copyToEnv             ; C=0 -> did not fit, stop
                BCC     @ce_done
                INC     _crt0_envIdx
                INC     args_envc
                BRA     @ce_L
@ce_done        ; terminating EMPTY string (the double NUL)
                LDY     _crt0_envOff
                SEP     #$20
                MX      %10
                LDA     #0
                STA     args_env,Y
                REP     #$20
                MX      %00
                PLP
                RTS

;------------------------------------------------------------------------------
; _crt0_copyToEnv - copy the NUL-terminated bank-0 string at
; _crt0_strBank0Ptr into args_env at _crt0_envOff.  Returns C=1 and
; advances _crt0_envOff past the NUL on success; C=0 (envOff unchanged)
; if the whole string + the walker's final double-NUL would not fit —
; the entry is dropped whole so getenv never sees a truncated NAME=VAL.
; Caller MX %00.
;------------------------------------------------------------------------------
_crt0_copyToEnv MX      %00
                LDX     _crt0_strBank0Ptr
                LDY     _crt0_envOff
                SEP     #$20
                MX      %10
@cv_L           CPY     #ARGS_ENV_MAX-2
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
                STY     _crt0_envOff
                SEC
                RTS

;------------------------------------------------------------------------------
; _crt0_set_progname - set __progname to basename of args_argv[0].  Walks
; argv[0] IN THE KERNEL'S BANK-0 FRAME, tracking the offset just past the last
; '/'.  No '/' → __progname = ptr to the whole of argv[0].  Caller MX %00.
;
; X IS 16-BIT HERE and the scan is `LDAL $000000,X', not an 8-bit index into a
; 256-byte buffer: argv[0] used to be a copy in the data bank at an offset
; under 256, and it is the frame now, which is a full bank-0 address.
;
; __progname STAYS A 2-BYTE NEAR CELL and now holds a bank-0 offset.  Nothing
; dereferences it: libc's err(3) says in as many words that it cannot (the cell
; is two bytes where an fcc `char *' is four), and derives the name from
; args_argv[0] instead -- which is a real far pointer and needs no change here.
;------------------------------------------------------------------------------
_crt0_set_progname MX  %00
                ; Default basename = the start of argv[0] in the frame.
                LDA     _crt0_strBank0Ptr
                STA     _crt0_baseOff
                LDX     _crt0_strBank0Ptr
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
                STX     _crt0_baseOff               ; offset just past the '/'
                BRA     @pn_L
@pn_done        LDA     _crt0_baseOff
                STA     __progname
                RTS

;------------------------------------------------------------------------------
; crt0 scratch storage.  Accessed via DBR-relative absolute (`STA _crt0_*`).
;
; SINGLE-BANK FGX1: DBR == own bank == PB, so the DA cells below ARE the
; storage that gets read/written.  Works as declared.
;
; MULTI-BANK FGX2 (fas, future C binaries with --data-segment): at runtime
; DBR = seg1 (data) bank, but these DA cells physically reserve bytes in
; seg0 (code) bank.  The DBR-relative `STA _crt0_callerS` therefore stores
; into seg1 at the SAME OFFSET where this cell sits in seg0 — NOT into the
; declared seg0 cell.  Same multi-bank hazard as fcc_runtime.s used to have
; (see feedback_fas_load_corrupts_src_at_certain_addrs.md).
;
; THIS IS CURRENTLY SAFE because crt0 is the first PUT in seg0 (right after
; the macros + seg1_layout.s, both of which emit zero bytes), so these DA
; cells land at seg0 offsets ~$00EF..$00FB — INSIDE seg1's 256-byte head
; padding (see tools/fas/seg1.link.s `DS 256`).  Any write to a seg1 offset
; < $0100 falls in that pad and corrupts nothing.
;
; IF crt0 ever grows past ~256 bytes of code+data, these cells will spill
; past the seg1 pad and start corrupting libc_data globals.  At that point
; split this into a separate crt0_data.s and PUT it into seg1.link.s
; (parallel to the fcc_runtime_data.s split, commit 06dadee).
;------------------------------------------------------------------------------
_crt0_callerS       DA  0
_crt0_kernArgc      DA  0
_crt0_walkIdx       DA  0
_crt0_strBank0Ptr   DA  0
; T7 E1: env-capture bound.  MUST MATCH args_data.s's ARGS_ENV_MAX (the
; storage lives in the DATA segment; EQUs don't cross segment assemblies,
; so it is duplicated here like the templates' ARGS_MAX).
ARGS_ENV_MAX        EQU 256
_crt0_envIdx        DA  0
_crt0_envOff        DA  0
_crt0_baseOff       DA  0

;==============================================================================
; END crt0.s
;==============================================================================
