;==============================================================================
; ld_bind_entry.s - the binder's entry, in libc.so's bank-0 hand-written code
; only (fgx_libso.LIBSO_BANK0): a static link (fgx_static) has no binder to
; enter, and carrying this jump would pull the whole binder in.
;==============================================================================

;------------------------------------------------------------------------------
; _ld_bind(frame, tab, copy, blk) - the binder's entry, from crt0_dyn through
; the registry's binder field.  libc's _fcc_dbr, a cell in libc's core, which
; crt0 has just copied into this data bank, is seeded first: the C binder
; converts ints to pointers before _libc_start would.  Then ld_bind, with
; the caller's frame (a tail jump: its arguments and return stay put).
;------------------------------------------------------------------------------
                FGX2_EXPORT _ld_bind
_ld_bind        MX      %00
                SEP     #$20
                MX      %10
                PHB
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     _fcc_dbr
                FGX2_FARJUMP ld_bind
