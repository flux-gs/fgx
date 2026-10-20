;==============================================================================
; FGX Configuration (AUTO-GENERATED from cfg/system.cfg)
; DO NOT EDIT - modify cfg/system.cfg and rebuild
;==============================================================================

CFG_VIDEO_BG_COLOR   EQU     $0333
CFG_VIDEO_BG_COLOR_LO EQU     $33
CFG_VIDEO_BG_COLOR_HI EQU     $03
CFG_VIDEO_FG_COLOR   EQU     $0FFF
CFG_VIDEO_FG_COLOR_LO EQU     $FF
CFG_VIDEO_FG_COLOR_HI EQU     $0F
CFG_VIDEO_ACCENT_COLOR EQU     $0AAA
CFG_VIDEO_ACCENT_COLOR_LO EQU     $AA
CFG_VIDEO_ACCENT_COLOR_HI EQU     $0A
CFG_VIDEO_SECONDARY_COLOR EQU     $0000
CFG_VIDEO_SECONDARY_COLOR_LO EQU     $00
CFG_VIDEO_SECONDARY_COLOR_HI EQU     $00
CFG_KERNEL_NPROC     EQU     32
CFG_SSCON_SLOT       EQU     3
CFG_KERNEL_KSLOTS    EQU     7
CFG_KERNEL_KSTK      EQU     1024
CFG_KERNEL_BANKS     EQU     3
CFG_REST_KMOD_BANKS  EQU     3
CFG_REST_HEAP_BANKS  EQU     2
CFG_REST_USER_BANKS  EQU     56
CFG_REST_MIN_USER_BANKS EQU     3
CFG_KERNEL_STKOVER   EQU     1
CFG_KERNEL_KCPROBE   EQU     1
CFG_KERNEL_VFSPROBE  EQU     0
CFG_KERNEL_UFSPROBE  EQU     0
CFG_KERNEL_UFSVNPROBE EQU     0
CFG_KERNEL_UFSWPROBE EQU     0
CFG_KERNEL_UFSDEVPROBE EQU     0
CFG_KERNEL_VNOPSPROBE EQU     0
CFG_KERNEL_SPEXT     EQU     1

; --- BANK-0 LAYOUT, DERIVED FROM kernel.nproc ---------------------------------
; Do not hand-edit or re-literalise these in kernel.s / fs.s / stage2.s:
; they must move together, and check_bank0_geometry.py enforces both the
; resulting geometry and the fact that those files still alias these names.
CFG_STK_KTASKS       EQU     $E000
CFG_BLK_STAGE        EQU     $1800
CFG_STK_ARENA        EQU     $1A00
CFG_DP_KERNELC       EQU     $BF00
CFG_DP_KKERN         EQU     $0900
CFG_DP_KERNELC_IRQ   EQU     $FC00
CFG_STK_KIRQ         EQU     $FD00
CFG_KSLOT_DP         EQU     $D000
CFG_STK_BOOT         EQU     $F800
CFG_KHOME_STRIDE     EQU     2048
CFG_STK_SWITCH       EQU     $DE00
CFG_STK_ARENA_PAGES  EQU     165

; --- REST-OF-OS LAYOUT, DERIVED FROM rest.* ----------------------------------
; kernel.s and stage2.s alias these names; tools/mkfgxunix.py reads them.
CFG_REST_CONSOLE_BANK_OFF EQU     0
CFG_REST_FONTS_BANK_OFF   EQU     1
CFG_REST_KMOD_FIRST_OFF   EQU     2
CFG_REST_HEAP_FIRST_OFF   EQU     5
CFG_REST_USER_FIRST_OFF   EQU     7
CFG_RESTOFOS_BANKS        EQU     $3F
CFG_RESTOFOS_MIN_BANKS    EQU     $0A

;==============================================================================
; END OF AUTO-GENERATED CONFIG
;==============================================================================
