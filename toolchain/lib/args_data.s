;==============================================================================
; args_data.s - DBR-accessed state for args.s.
;
; Slice 4.5: extracted from args.s.  Every binary that PUTs args.s
; MUST also PUT args_data.s.  For single-bank binaries the two
; live in the same segment; multi-bank fas's seg0.link.s PUTs
; args.s (code) while seg1.link.s PUTs args_data.s (DBR state).
;
; ARGS_MAX is defined in args.s; this file references it so args.s
; must be PUT'd first.
;==============================================================================

;------------------------------------------------------------------------------
; Storage.  Lives in caller's bank.  crt0 writes args_argc/args_argv/
; __progname/args_optind during _crt0_setup_argv; user code reads.
;------------------------------------------------------------------------------
args_argc       DA      0
args_optind     DA      0
args_optarg     DA      0
args_optopt     DA      0
__progname      DA      0
args_argv       DS      4*ARGS_MAX,0

; T7-environ (E1): the child's environment, captured by crt0 from the
; kernel-laid envp frame.  Packed "NAME=VAL" NUL-terminated strings,
; terminated by an EMPTY string (double NUL).  Fixed 256 bytes (fail-soft
; truncate) so no link-template EQU churn.
ARGS_ENV_MAX    EQU     256
args_envc       DA      0
args_env        DS      ARGS_ENV_MAX,0

; T7-environ (E4): the POSIX/BSD `environ` global.  args_env above is a
; PACKED block that getenv() walks; `environ` is the vector form -- a
; NULL-terminated array of pointers INTO that block, which is what portable
; BSD code reads directly.  The Bourne shell's setupenv() (sh/name.c) is the
; case that forced this: it imports the whole environment with
; `STRING *e = environ; WHILE *e DO setname(*e++) OD` and never calls
; getenv(), so without a real `environ` it saw an empty environment and the
; login shell came up with no PATH at all.
;
; Entries are 4-byte far pointers (offset, bank, pad), same layout as
; args_argv, so `char **` deref and `e++` stride work unmodified.  _libc_start
; (libc_start.s) fills this in as it packs args_env; a binary built on the near crt0 (no
; env capture) leaves it zeroed, so *environ is NULL == empty environment.
; (Merlin evaluates strictly left-to-right with no parentheses, so the
; "+4" for the reserved NULL terminator slot trails the multiply.)
ARGS_ENVV_MAX   EQU     32
args_envv       DS      4*ARGS_ENVV_MAX+4,0
environ         DS      4,0

