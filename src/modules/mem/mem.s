;==============================================================================
; SPDX-License-Identifier: BSD-2-Clause
; SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
; FGX-Provenance: 2.11BSD usr/sys/pdp/mem.c
;   Written for FGX after mmrw, usr/sys/pdp/mem.c, 2.11BSD.  Original work:
;   Copyright (c) 1986 Regents of the University of California.
;   All rights reserved.
;
; mem.mod - /dev/mem and /dev/kmem, 2.11BSD mmrw's minors 0 and 1.  /dev/null,
; its minor 2, is the kernel's own (src/kernel/chardev.s).
;
; ONE ADDRESS SPACE, SO ONE BODY.  On the PDP-11 minor 0 maps physical memory
; through seg5 and minor 1 reads kernel virtual addresses.  The 65816 has no
; MMU: the file offset is the 24-bit address for both, and both arms are
; upstream's kmem one, `uiomove((caddr_t)uio->uio_offset, c, uio)'.
;
; THE I/O WINDOW IS REFUSED, an FGX divergence.  $C000-$CFFF of banks $00, $01,
; $E0 and $E1 is soft switches and slot I/O, where a read changes the
; machine's state: a byte copy across it would flip video modes and drive
; motors.  EFAULT, as an address the process may not touch.  A move is cut at
; the window and at the bank's end, so it never runs into either.
;
; uiomove IS vfs.mod's, found on each call (KSVC_FINDVTABLE): this module keeps
; no state, so it needs no cell in the core bank.
;==============================================================================

                PUT     modplace.s
                ORG     MODP_ORG

                PUT     ../../../include/config.s
                PUT     ../../../include/devnodes.s     ; DEVNODE_MEM, _KMEM
                PUT     ../../../include/errno.s
                PUT     ../../../include/chardev.s      ; CDF_*, COPS_*, UIO_*
                PUT     ../../../include/modules.s      ; KSVC_FINDVTABLE
                PUT     ../../../include/kernel.s
                PUT     ../../../include/dpmap.s        ; _libcTmp0-2
                PUT     kernel_exports.s

                MX      %00

mem_bss         EQU     0

mem_hdr         ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi
                DFB     $02                             ; +7  header format version
                DA      mod_init-$050000                ; +8  entry offset
                DA      mem_end-mem_text                ; +10 text bytes
                DA      mem_bss                         ; +12 bss bytes
                DA      mem_vtdir-mem_text              ; +14 vtdir offset
mem_modname     ASC     'mem'                           ; +16 module name
                DS      16-*+mem_modname                ;     NUL-pad to 16 bytes
                DA      $0000                           ; +32 module version
                DA      KERN_BUILD_ID                   ; +34 kernel build identity
                DS      4                               ; +36 reserved

mem_text        EQU     *

mem_vtdir       ASC     'VTDR'
                DA      $0000                           ; VT_END

;==============================================================================
; mod_init - MX %00, DBR = kernel bank.  Patch the ops tables' bank bytes, then
; register /dev/mem (minor 0) and /dev/kmem (minor 1) on the same ops.
;==============================================================================
mod_init        MX      %00
                PHB
                PHK
                PLB                             ; DBR = our bank
                SEP     #$30
                MX      %11
                PHK
                PLA
                LDX     #2
@mi_spL         STA:    mem_ops,X
                INX
                INX
                INX
                CPX     #24                     ; 8 filled slots x 3 B
                BCC     @mi_spL
                REP     #$30
                MX      %00
                LDA     #mem_name
                LDX     #mem_ops
                LDY     #{{CDF_RECORD+CDF_FIXED+{DEVNODE_MEM*4}}*256}+0
                JSL     MOD_REGISTERCHARDEV
                BCC     @mi_fail
                LDA     #kmem_name
                LDX     #mem_ops
                LDY     #{{CDF_RECORD+CDF_FIXED+{DEVNODE_KMEM*4}}*256}+1
                JSL     MOD_REGISTERCHARDEV
                BCC     @mi_fail
                LDX     #regok_msg
                JSL     SYS_MODLOG
                PLB
                SEC
                RTL
@mi_fail        LDX     #regfail_msg
                JSL     SYS_MODLOG
                PLB
                SEC
                RTL

;==============================================================================
; The ops.  DBR = kernel bank, D = the kernel page on entry; each RTLs.
;==============================================================================
mem_open        MX      %00
mem_close       SEC
                RTL

; The per-byte slots are never reached: CDF_RECORD with d_read and d_write
; sends every read and write through those.
mem_byte        LDA     #ENOTSUP
                CLC
                RTL

mem_ioctl       LDA     #ENOTTY
                CLC
                RTL

mem_poll        LDA     #POLLIN+POLLOUT
                SEC
                RTL

;------------------------------------------------------------------------------
; mem_rw - d_read and d_write: mmrw.  The uio says which way (uiomove).
;
; In:  Y = minor.  Frame: 9,S uio offset, 11,S uio bank, 13,S flag (klog.mod's
;      klog_dread has the arithmetic).
; Out: C=1 + A = 0, or C=0 + A = errno.
;
;   while (uio->uio_resid) {
;           c = uio_resid, cut at the bank's end and at the I/O window;
;           uiomove((caddr_t)uio->uio_offset, c, uio);
;   }
;
; _libcTmp2 holds the uio, _libcTmp0 the count, _libcTmp1 the address's bank.
;------------------------------------------------------------------------------
mem_rw          MX      %00
                LDA     9,S
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     11,S
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
@rw_loop        LDY     #UIO_RESID
                LDA     [_libcTmp2],Y
                BNE     @rw_more
                LDA     #0
                SEC
                RTL
@rw_more        STA     _libcTmp0               ; c = resid
                LDY     #UIO_OFFSET+2
                LDA     [_libcTmp2],Y           ; the address's high word
                CMP     #$0100
                BCS     @rw_fault               ; past the 24-bit space
                STA     _libcTmp1               ; its bank
                LDY     #UIO_OFFSET
                LDA     [_libcTmp2],Y
                TAX                             ; X = the offset in the bank
                LDA     _libcTmp1
                AND     #$00FE                  ; $00 or $01
                BEQ     @rw_io
                CMP     #$00E0                  ; $E0 or $E1
                BNE     @rw_bank
@rw_io          CPX     #$C000
                BCC     @rw_below
                CPX     #$D000
                BCC     @rw_fault               ; inside the window
                BRA     @rw_bank
@rw_below       TXA                             ; stop at the window
                EOR     #$FFFF
                SEC
                ADC     #$C000                  ; $C000 - offset
                CMP     _libcTmp0
                BCS     @rw_bank
                STA     _libcTmp0
@rw_bank        TXA                             ; stop at the bank's end
                BEQ     @rw_call                ; a whole bank: resid binds
                EOR     #$FFFF
                INC                             ; $10000 - offset
                CMP     _libcTmp0
                BCS     @rw_call
                STA     _libcTmp0
@rw_call        JSR     _Mem_Uio                ; A = errno
                CMP     #0
                BEQ     @rw_loop
                CLC
                RTL
@rw_fault       LDA     #EFAULT
                CLC
                RTL

;------------------------------------------------------------------------------
; _Mem_Uio - uiomove(address, _libcTmp0, uio) in vfs.mod.  X = the address's
; offset, _libcTmp1 its bank, _libcTmp2 the uio.  Out: A = errno (0 = moved).
; The call is klog.mod's _Klog_Uio, with the target found here.
;------------------------------------------------------------------------------
_Mem_Uio        MX      %00
                PHX                             ; the address's offset
                LDA     #VT_VFSCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL               ; C=1 + A = voffset, X.lo = bank
                BCS     @mu_have
                PLX
                LDA     #ENXIO                  ; no vfs.mod: nothing moves bytes
                RTS
@mu_have        CLC
                ADC     #VFSCORE_Uiomove
                TAY                             ; the slot's offset in vfs.mod
                PHB                             ; the kernel bank, for the exit
                SEP     #$20
                MX      %10
                TXA
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$30
                MX      %00
                LDA     |$0000,Y                ; uiomove's offset in vfs.mod
                PLB                             ; DBR = kernel bank
                PLY                             ; Y = the address's offset
                PHB                             ; for the exit
                PHD
                PHA                             ; 1,S = uiomove's offset
                PHX                             ; 1,S = vfs bank, 3,S = offset
                ; uiomove(cp, n, uio): the uio, then n, then cp, last first.
                LDA     _libcTmp2+2
                AND     #$00FF
                PHA                             ; uio bank
                LDA     _libcTmp2
                PHA                             ; uio offset
                LDA     _libcTmp0
                PHA                             ; n
                LDA     _libcTmp1
                PHA                             ; cp bank
                PHY                             ; cp offset
                LDA     13,S                    ; uiomove's offset
                TAX
                LDA     #FGX_DP_KERNELC
                TCD                             ; fcc's register file, for C
                SEP     #$20
                MX      %10
                LDA     11,S                    ; vfs.mod's bank
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$30
                MX      %00
                PHK
                PEA     memret_uio-1
                PHB                             ; target bank
                TXA
                DEC     A
                PHA                             ; target - 1
                RTL                             ; PILECALL
memret_uio      TAY                             ; park the errno
                TSC
                CLC
                ADC     #14                     ; the arguments, vfs bank, offset
                TCS
                PLD
                PLB
                TYA
                RTS

;==============================================================================
; The vtable: nine 3-byte slots (include/chardev.s); mod_init patches the banks.
;==============================================================================
mem_ops         DFB     <mem_open,>mem_open,^mem_open
                DFB     <mem_close,>mem_close,^mem_close
                DFB     <mem_byte,>mem_byte,^mem_byte
                DFB     <mem_byte,>mem_byte,^mem_byte
                DFB     <mem_ioctl,>mem_ioctl,^mem_ioctl
                DFB     <mem_poll,>mem_poll,^mem_poll
                DFB     <mem_rw,>mem_rw,^mem_rw         ; d_read: mmrw
                DFB     <mem_rw,>mem_rw,^mem_rw         ; d_write: mmrw
                DFB     0,0,0                   ; d_stop: nothing in flight
mem_name        ASC     'mem',00
kmem_name       ASC     'kmem',00

regok_msg       ASC     '/dev/mem and /dev/kmem ready',00
regfail_msg     ASC     'chardev registration failed',00

mem_end         EQU     *

                ERR     mem_hdr-MODP_ORG
                ERR     mem_end-MODP_ORG+mem_bss/MODP_LIMIT
