; fgx_syscalls.inc - REFERENCE copy of the FGX syscall contract VALUES.
; AUTHORITATIVE SOURCE: FGX include/loader.s (numbers), userland .link.s (SYS_TRAMP),
; src/userland/lib/libc.s (SYS_GETKEY_NUM). FGX is the source of truth; keep in sync.
; The golden tests define these inline in _wrap.s; this file is for future standalone
; consumers (the harness). See syscall.h for semantics + the buffer-bank ABI.
;
SYS_TRAMP       EQU     $000328
SYS_EXIT        EQU     1
SYS_READ        EQU     3
SYS_WRITE       EQU     4
SYS_OPEN        EQU     5
SYS_CLOSE       EQU     6
SYS_LSEEK       EQU     19
SYS_GETKEY      EQU     50
SYS_GETFSSTAT   EQU     67
SYS_GETKEY_NUM  EQU     50
