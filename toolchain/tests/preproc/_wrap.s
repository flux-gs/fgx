;==============================================================================
; _wrap.s — Shared wrapper for fcc preprocessor fixtures.
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
