;==============================================================================
; _wrap_ss.s - wrapper for fcc M31 fixtures (the software-stack tier).
;
; Identical to M22/_wrap.s now that crt0.s allocates the software-stack region
; unconditionally (soft-stack is the default).  Kept as a distinct wrapper only
; so the M31 fixtures stay grouped; PUTs the shared crt0.s.
;==============================================================================

                MX      %11
                ORG     $0B0000

SYS_EXIT        EQU     1
SYS_WRITE       EQU     4
SYS_TRAMP       EQU     $000328

fcc_hdr         ASC     'FGX1'
                DFB     <$0B0000
                DFB     >$0B0000
                DFB     ^$0B0000
                DFB     $00
                DA      _crt0_start-$0B0000
                DA      fcc_end-fcc_text
                DA      0
                DFB     fcc_stack_pages
                DFB     $00

fcc_text        EQU     *
                PUT     ../../lib/crt0.s
                PUT     fcc_output.s
                PUT     ../../lib/fcc_runtime.s
                PUT     ../../lib/fcc_runtime_data.s
                PUT     ../../lib/libc_c_data.s
                PUT     ../../lib/libfgx_data.s
                PUT     ../../lib/args.s
                PUT     ../../lib/args_data.s
fcc_end         EQU     *
