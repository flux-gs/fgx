;==============================================================================
; _wrap_libc.s - M11 wrapper with FGX userland libc + cc-target shims.
;
; Same shape as _wrap.s, plus PUTs of:
;   - src/userland/lib/libc.s        (FGX libc primitives)
;   - tools/fcc/fcc_libc_shims.s     (cc-target shim wrappers)
; placed AFTER fcc_runtime.s, BEFORE args.s, so user code (in fcc_output.s)
; can JSR c_strlen, c_strcmp, c_printf, ... by name.
;==============================================================================

                MX      %11
                ORG     $0B0000

SYS_EXIT        EQU     1
SYS_WRITE       EQU     4
SYS_TRAMP       EQU     $000328
LIBC_FAR        EQU     0                 ; near flavor: JSR/RTS libc entry (see libc.s)

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
                PUT     ../../lib/libc.s
                PUT     ../../lib/libc_data.s
                PUT     ../../lib/fcc_libc_shims.s
                PUT     ../../lib/libc_c.s
                PUT     ../../lib/libfgx.s
                PUT     ../../lib/args.s
                PUT     ../../lib/args_data.s
fcc_end         EQU     *
