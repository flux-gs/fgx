;==============================================================================
; args.s - userland argv parsing for FGX command-line tools (BSD getopt
; shape).  CODE ONLY — DBR-accessed state lives in args_data.s.
;
; Slice 4.5 split args.s into code and data.  Every binary that PUTs
; args.s MUST also PUT args_data.s (typically right after).  See
; src/userland/lib/README.md for the convention.
;
; PUT-included alongside crt0.s by each user binary.  crt0.s walks the
; kernel's stack-laid argv/envp frame at process entry and populates the
; storage defined in args_data.s:
;
;   args_argc       total argc, including argv[0]
;   args_argv[0..]  own-bank ptrs to NUL-term argv strings
;   __progname      own-bank ptr to basename of argv[0]
;   args_optind     next argv slot to scan (BSD-getopt convention; init 1)
;   args_optarg     ptr to current option's argument (or 0)
;   args_optopt     last option char processed (for diagnostics)
;
; This file provides the option-iteration API:
;
;   Args_Next  (A = ptr to spec string)
;       Returns A = option char (8-bit) on hit;
;               A = 0    when out of options (EOF);
;               A = '?'  for unknown option (sets args_optopt);
;               A = ':'  for missing argument (silent mode; sets args_optopt).
;       Z flag tracks A (caller can BEQ for EOF).
;       Spec syntax mirrors getopt(3): "abc:d" means -a, -b, -c <arg>, -d.
;       Bundled flags ("-laF") are unwound across successive calls.
;       "--" ends option scanning; optind advances past it; returns A=0.
;       Bare "-" is treated as a positional arg; returns A=0.
;
;   Args_Argv  (A = relative idx)
;       C=1 + X = own-bank ptr to args_argv[args_optind + idx];
;       C=0 if (args_optind + idx) ≥ args_argc.
;
;   Args_Argc
;       Y = args_argc - args_optind  (positional count remaining post-getopt).
;
;   Args_ProgName
;       C=1 + X = ptr to __progname; C=0 if absent.
;
; Caller convention:
;   - DBR must point at caller's bank (crt0 owns this).
;   - Caller is MX %00 on entry; routines preserve M/X via PHP/PLP.
;
; Migration notes:
;   - Args_Parse is GONE.  crt0 does the stack walk + string copy at
;     process entry.  Binaries no longer call any per-arg setup.
;   - Args_HasFlag is GONE.  Migrate to Args_Next iteration.
;   - Args_Argv semantics changed: indexes RELATIVE to args_optind.
;     For binaries that don't call Args_Next, optind stays at 1 so
;     Args_Argv(0) still returns the first positional (= argv[1]) —
;     matches the slice-2 tokenize-and-strip behavior.
;==============================================================================

ARGS_MAX        EQU     16                      ; max argv slots tracked


;------------------------------------------------------------------------------
; NO CODE LIVES HERE ANY MORE.
;
; args.s used to carry an asm getopt (Args_Next) plus Args_Argv / Args_Argc /
; Args_ProgName / Args_PrintBadOpt.  Every userland tool moved to libc's
; getopt(3) (toolchain/lib/libc_c/getopt.c, which keeps its own optind/optarg),
; and NOTHING called any of them: a repo-wide search found the names only in
; their own definitions and in the _Output.txt listings of binaries that PUT
; this file.
;
; They are deleted rather than kept, because apple/fgx#301 made them WRONG as
; well as unused.  Each read an argv string DBR-relatively --
; `LDA args_argv,X / STA ARGS_DP_WORD / LDA (ARGS_DP_WORD),Y' -- discarding the
; bank byte its own vector stores.  That was true only while crt0 copied every
; string into the binary's own data bank.  crt0 points at the kernel's bank-0
; frame now, so those five reads would fetch from the data bank at a bank-0
; offset: silently, and as plausible-looking garbage.  Dead code that is also
; incorrect is a trap for whoever reaches for it next.
;
; What remains is DATA, in args_data.s: args_argc, args_argv[], __progname and
; the environ block, all written by crt0 and read by C.
;------------------------------------------------------------------------------
