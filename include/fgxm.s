;==============================================================================
; fgxm.s - FGXM module-binary format constants.
;
; Mirrors include/loader.s's FGX1 layout, with magic 'FGXM' and the +14..+15
; slot redefined as "vtdir_offset" (the byte offset within text where the
; module's vtable directory begins).
;
; Vtable directory layout (at vtdir_offset bytes past load_addr):
;
;   ASC  'VTDR'                   ; 4 B magic; loader sentinel
;   DA   VT_<TYPE>                ; 2 B type tag (see include/modules.s)
;   DA   <vtable_offset>          ; 2 B bank-relative offset of vtable
;   ...                           ; more (vtype, voffset) tuples
;   DA   VT_END                   ; 2 B terminator ($0000)
;==============================================================================

FGXM_HEADER_SZ  EQU     40                  ; v2: 16 (v1) + name[16] + modver[2] + rsvd[6]

; load_addr, 3 bytes at +4.  Its LOW 16 BITS are the module's offset within the
; SHARED module bank -- where it was assembled to live, and therefore where
; Mod_Load must put it (module code is ORG-dependent).  The bank byte is
; meaningless: the loader supplies the real bank.  This was "informational
; only, ignored" while every module owned a whole bank and sat at offset 0.
; See tools/gen_modplace.py.
FGXM_OFF_LOAD   EQU     4                   ; 3 bytes: load address.  lo16 = the
                                            ;   OFFSET in the bank; the HIGH
                                            ;   byte is a BANK ORDINAL, below.
; THE LOAD ADDRESS'S HIGH BYTE IS AN ORDINAL, NOT A BANK.  A module is
; assembled at $05xxxx by convention and has no idea which real bank it will be
; loaded into, so it cannot name one; what it CAN name is which packing chain
; it belongs to.  $05 is ordinal 0 -- the shared module bank every module used
; before there was a second -- $06 is ordinal 1, and so on.  Mod_Load subtracts
; this base and maps the ordinal to a bank it allocates (_modBankTab).
; tools/gen_modplace.py OWN_BANK is the other end of the same contract.
FGX_MOD_ORG_BANK EQU    $05                 ; assembly ORG bank = ordinal 0
; Entry offset, BANK-relative -- NOT relative to load_addr, whatever the old
; name suggested.  Mod_Load JSLs (bank):this value unmodified, so a module
; computes it as `mod_init-$050000` (the bank base) and NOT as
; `mod_init-MODP_ORG`, which would be short by its own placement offset.
FGXM_OFF_ENTRY  EQU     8                   ; 2 bytes: entry offset, bank-relative
FGXM_OFF_TEXT   EQU     10                  ; 2 bytes: text size (bytes to copy)
FGXM_OFF_BSS    EQU     12                  ; 2 bytes: bss size (bytes to zero)
FGXM_OFF_VTDIR  EQU     14                  ; 2 bytes: vtdir offset within text
FGXM_OFF_FMTVER EQU     7                   ; 1 byte:  header format version (v2 = 2)
FGXM_OFF_NAME   EQU     16                  ; v2: 16-byte NUL-padded module name
FGXM_NAME_LEN   EQU     16
FGXM_OFF_MODVER EQU     32                  ; v2: 2-byte module version (reserved, 0)
; The kernel build this image's baked kernel addresses came from -- see
; KERN_BUILD_ID in the module's generated kernel_exports.s, and the header of
; tools/gen_kernel_exports.py.  Mod_Load refuses a module whose id disagrees
; with the running kernel's (published at MOD_JT_CORE_BUILD by _JT_Init),
; because every address the image baked would then point at the wrong byte.
; $0000 = NOT BUILD-LOCKED: the module bakes no kernel addresses and has no
; kernel_exports.s (hello.mod).  Taken from the v2 reserved bytes at +34.
FGXM_OFF_COREBUILD EQU  34                  ; 2 bytes: kernel build identity
FGXM_HDR_FMT_VER EQU    2                   ; current header format version

;------------------------------------------------------------------------------
; VTDR sentinel magic (4 B at the start of the vtable directory).  Little-
; endian word pairs for CMP convenience:
;   bytes "VTDR" = $56 $54 $44 $52 → LDAL lo word = $5456 ("VT"),
;                                    LDAL hi word = $5244 ("DR")
;------------------------------------------------------------------------------
VTDR_MAGIC_LO   EQU     $5456                ; "VT" little-endian
VTDR_MAGIC_HI   EQU     $5244                ; "DR" little-endian
