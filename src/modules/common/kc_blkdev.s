;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     src/modules/common/kc_blkdev.s
; Purpose:  the block-device kernel services, for the modules whose C calls
;           them: the CD-ROM filesystems' unmounts and spec_ioctl
; Created:  2026-10-21
;
; NOT IN kc_sys.s, which every module PUTs: vfs.mod has no room for routines
; it never calls.
;
;==============================================================================

;------------------------------------------------------------------------------
; kc_blkstale(dev) -> 0.  The medium in block device `dev' may change now that
; nothing is mounted from it: a CD-ROM is probed again on its next read
; (Dev_BlkStale).  Any other device is left as it is, so the call is always
; safe to make.
;------------------------------------------------------------------------------
kc_blkstale     MX      %00
                ENTERK
                LDA     6,S                     ; dev
                LDX     #KSVC_BLKSTALE
                JSL     SYS_KCALL
                LDA     #0
                LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_blkioctl(dev) -> errno, 0 on success.  `(*bdevsw[major(dev)].d_ioctl)'
; with the request already staged by the ioctl syscall, as kc_cdioctl's is
; (ufsdir/kc_chardev.s).  ENOTTY for a request the device does not carry.
;------------------------------------------------------------------------------
kc_blkioctl     MX      %00
                ENTERK
                LDA     6,S                     ; dev
                LDX     #KSVC_BLKIOCTL
                JSL     SYS_KCALL
                BCS     @kbio_zero
                AND     #$00FF                  ; C=0: A = errno
                BRA     @kbio_out
@kbio_zero      LDA     #0
@kbio_out       LEAVEK
                RTL
