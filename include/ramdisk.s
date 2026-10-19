;==============================================================================
; ramdisk.s - /RAM5 RAM-disk equates: GS/OS rendezvous + sizing constants.
;
; Rendezvous addresses for the ROM 3 GS/OS RAM Disk Tool Set (#13) bank-$E1
; globals (from ram5.aii) plus BRAM size-graduation refs and the FGX clamp
; constants used to size the FGX-owned /RAM5 buffer.  Pure EQUs; no runtime
; code or storage here.
;
; PUT by src/kernel/main.s.
;==============================================================================

;------------------------------------------------------------------------------
; GS/OS RAM Disk Tool Set (#13) rendezvous - bank $E1 globals (ROM 3).
;------------------------------------------------------------------------------
RD_CurDiskSize  EQU     $E11642         ; size in bytes (blocks = size/512)
RD_DiskHandles  EQU     $E11646         ; MM handle to the buffer (0 = none)
RD_FormatFlag   EQU     $E1164A         ; $FFFF = has ProDOS dir, 0 = needs one
RD_RamUnit      EQU     $E10FBC         ; generated SmartPort unit number

;------------------------------------------------------------------------------
; BRAM size refs (ReadBParam $0C03) and FGX sizing constants.
;------------------------------------------------------------------------------
RD_BP_MIN       EQU     $0036           ; minimum RAM-disk size graduation
RD_BP_MAX       EQU     $0037           ; maximum
RD_DEFAULT_BYTES EQU    $00100000       ; 1 MB fallback if BRAM unreadable/zero
RD_MAX_BYTES    EQU     $00200000       ; clamp ceiling (don't starve FGX)

;==============================================================================
; END ramdisk.s
;==============================================================================
