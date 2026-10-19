;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     src/modules/ufsdir/kc_chardev.s
; Purpose:  cdevsw's bulk chardev ops, for vfs.mod's kernel C
; Created:  2026-08-22
;
; NOT IN ../common/kc_sys.s, which every module PUTs: only vfs.mod's C calls
; these, and a routine one module needs belongs to that module.
;
;==============================================================================

;------------------------------------------------------------------------------
; kc_cddread(dev, uio) / kc_cddwrite(dev, uio) -> (status << 8) | value.
;
;   status 0   DO NOT LOOP; the low byte is the errno, 0 for success.  Usually
;              the op ran and this is its answer; it is also what a RECORD
;              device with no d_read answers (EIO), because telling such a
;              device's caller to loop is apple/fgx#198's silent half.
;   status 1   THIS DEVICE HAS NO BULK OP -- the caller uses its own per-byte
;              loop.  Every per-byte device answers this, which is most of them.
;   status 2   the index names no device; the low byte is ENODEV
;
; THREE OUTCOMES AND ONE 16-BIT RETURN, kc_cdread's idiom two routines up, and
; for a sharper reason here: an errno sentinel would collide.  nodev() in the
; line-discipline switch returns ENODEV, and that switch is exactly where tty
; bulk reads route once the discipline lands -- "no bulk op" and "the
; discipline refused" must not be the same answer.
;
; THE uio POINTER FITS IN REGISTERS: offset in A, bank in Y's high byte beside
; the index.  An earlier cut believed it did not, exported a scraped kernel
; shim, and had THIS side dispatch -- which put the registry read on fcc's
; direct page, where [_cdTablePtr] is not a table pointer at all.  Everything
; is on the kernel's side of the KSVC now, where the direct page is right by
; construction.
;
; Stack, with the caller's args above ENTERK's PHD:  6,S dev   8,S uio.lo
; 10,S uio.bank.  fcc passes a pointer as offset-then-bank.
;------------------------------------------------------------------------------
; A DEV THAT WILL NOT FIT A BYTE IS REFUSED HERE, not masked.
;
; The index shares Y with the uio's bank byte, so only its low 8 bits travel.
; v_rdev is a dev_t -- an unsigned short, read FROM DISK -- so a value above
; 255 is reachable, and masking it would hand the kernel a low byte that
; passes the bounds check while naming a different device.  The first draft of
; this file masked with CHARDEV_MAX-1, which was worse still: it forced every
; out-of-range index into a VALID one.
;
; Status 2 is the same answer the kernel's own bounds check gives, because it
; is the same question asked one step earlier.
kc_cddread      MX      %00
                ENTERK
                LDA     6,S                     ; dev -- see the note above
                CMP     #CHARDEV_MAX
                BCC     @kcdr_ok
                LDA     #$0200+ENODEV           ; status 2
                LEAVEK
                RTL
@kcdr_ok        LDA     10,S                    ; uio bank
                AND     #$00FF
                XBA                             ; -> Y's high byte
                ORA     6,S                     ; | dev, now known < CHARDEV_MAX
                TAY
                LDA     12,S                    ; the ioflag; only its NDELAY
                AND     #VFS_IO_NDELAY          ;   bit travels, as CDIDX_NDELAY
                BEQ     @kcdr_go                ;   in the index byte`s top bit
                TYA
                ORA     #CDIDX_NDELAY
                TAY
@kcdr_go        ANOP
                LDA     8,S                     ; uio offset
                LDX     #KSVC_CDDREAD
                JSL     SYS_KCALL
                LEAVEK
                RTL

kc_cddwrite     MX      %00
                ENTERK
                LDA     6,S
                CMP     #CHARDEV_MAX
                BCC     @kcdw_ok
                LDA     #$0200+ENODEV
                LEAVEK
                RTL
@kcdw_ok        LDA     10,S
                AND     #$00FF
                XBA
                ORA     6,S
                TAY
                LDA     12,S                    ; the ioflag -- see kc_cddread
                AND     #VFS_IO_NDELAY
                BEQ     @kcdw_go
                TYA
                ORA     #CDIDX_NDELAY
                TAY
@kcdw_go        ANOP
                LDA     8,S
                LDX     #KSVC_CDDWRITE
                JSL     SYS_KCALL
                LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_cdioctl(dev) -> errno, 0 on success.  UFS 1.7d I4.
;
; `(*cdevsw[major(dev)].d_ioctl)(dev, com, data, fflag)' as vfs.mod can spell
; it -- and it spells only the first argument, because on FGX the other three
; are already where the op looks for them.  include/modules.s carries the whole
; argument for KSVC_CDIOCTL; the short form is that _Chardev_Dispatch passes an
; op only Y, so cmd and arg travel in kernel singletons that _Sys_Ioctl stages
; before it classifies the descriptor.  spec_ioctl's `com' and `data' are
; therefore not dropped: they are the very values already staged, arrived here
; by a longer road.
;
; A DEV THAT WILL NOT FIT A BYTE IS REFUSED, not masked -- kc_cddread's note
; above gives the reason, and it is the same reason: v_rdev is read FROM DISK,
; so an out-of-range index is reachable and masking it names a REAL but
; different device.  ENXIO rather than ENODEV: this is the answer spec_open
; already gives for a device node that names nothing (spec_vnops.c:262), and an
; ioctl is not the place to invent a second spelling of it.
;
; THE ANSWER IS AN ERRNO, NOT A CARRY, because that is what the C caller can
; use.  The registry answers C=1, or C=0 with A = errno; folding them here
; means VOP_IOCTL's caller compares against 0 the way every other vnode op's
; does.  A device with no d_ioctl answers ENOTTY, which is what BSD returns for
; a request a device does not implement -- an answer, not a failure.
;------------------------------------------------------------------------------
kc_cdioctl      MX      %00
                ENTERK
                LDA     6,S                     ; dev -- see the note above
                CMP     #$0100
                BCC     @kcio_ok
                LDA     #ENXIO
                LEAVEK
                RTL
@kcio_ok        LDX     #KSVC_CDIOCTL
                JSL     SYS_KCALL
                BCS     @kcio_zero
                AND     #$00FF                  ; C=0: A = errno
                BRA     @kcio_out
@kcio_zero      LDA     #0
@kcio_out       LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_cdpoll(dev) -> the POLL* mask, or 0 when the index names no device.
;
; `(*cdevsw[major(dev)].d_select)(dev, which)' -- except that FGX's d_select
; answers BOTH directions in one dispatch and the caller picks its bit, where
; Reno's takes `which' and answers one (spec_vnops.c:350).  So `which' does not
; travel: spec_select applies it to the mask this returns.
;
; ZERO IS "NEITHER DIRECTION IS READY", AND THAT IS THE RIGHT ANSWER FOR A BAD
; INDEX rather than a lost error.  select(2) has nowhere to put an errno for one
; descriptor of a set -- Reno's spec_select returns a readiness, not a status --
; so a device that cannot be polled must report itself not ready and let the
; caller block or time out.  The kernel's own bounds check answers the same way.
;------------------------------------------------------------------------------
kc_cdpoll       MX      %00
                ENTERK
                LDA     6,S
                CMP     #$0100
                BCC     @kcpo_ok
                LDA     #0                      ; not ready -- see above
                LEAVEK
                RTL
@kcpo_ok        LDX     #KSVC_CDPOLL
                JSL     SYS_KCALL
                BCS     @kcpo_out
                LDA     #0
@kcpo_out       LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_cdread(idx, flag) -> (status << 8) | value.
;
;   status 0   a byte was read; it is in the low byte
;   status 1   END OF FILE; the low byte is zero
;   status 2   an error; the low byte is the errno
;
; THREE OUTCOMES AND ONE 16-BIT RETURN, which is why this is not the plain
; "0 or errno" the other four use.  The registry answers a read with C=1 and a
; byte, or C=0 with A -- where A = 0 means end of file and anything else is an
; errno (/dev/null's Read is exactly `LDA #0; CLC`).  Packing the two into one
; word keeps that distinction; returning the byte alone would make a read of
; 0x00 -- an ordinary byte -- indistinguishable from EOF.
;------------------------------------------------------------------------------
; THE ioflag RIDES IN BIT 4 of the index, which is free because CHARDEV_MAX is
; 16 and so is VFS_IO_NDELAY; src/kernel/chardev.s splits it and carries the ERR
; that keeps the two equal.  Only the NDELAY bit travels -- an ioflag may carry
; others and the kernel's mask would take them for an index.
;
; Stack, with the caller's args above ENTERK's PHD:  6,S idx   8,S flag
kc_cdread       MX      %00
                ENTERK
                LDA     6,S
                AND     #$00FF
                CMP     #CHARDEV_MAX
                BCC     @kcr_in
                LDA     #$0200+ENODEV           ; status 2, as the bulk pair
                LEAVEK
                RTL
@kcr_in         PHA                             ; the clean index, briefly
                LDA     10,S                    ; the ioflag -- 8,S, shifted by
                AND     #VFS_IO_NDELAY          ;   the push above
                ASL                             ; VFS_IO_NDELAY -> CDIDX_NDELAY,
                ASL                             ;   the bit it travels in.  The
                ASL                             ;   ERR in chardev.s pins the
                                                ;   distance to both constants.
                ORA     1,S                     ; | the index
                PLX                             ; drop the staged copy; X is
                LDX     #KSVC_CDREAD            ;   reloaded on the next line
                JSL     SYS_KCALL
                BCC     @kcr_notByte
                AND     #$00FF                  ; C=1: status 0, byte in low
                BRA     @kcr_out
@kcr_notByte    AND     #$00FF
                BEQ     @kcr_eof                ; A = 0 -> end of file
                CLC
                ADC     #$0200                  ; status 2, errno in low
                BRA     @kcr_out
@kcr_eof        LDA     #$0100                  ; status 1, low byte zero
@kcr_out        LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_cdwrite(idx, byte, flag) -> 0, or an errno.
;
; Stack, with the caller's args above ENTERK's PHD:
;   6,S idx   8,S byte   10,S flag
;------------------------------------------------------------------------------
kc_cdwrite      MX      %00
                ENTERK
                LDA     8,S                     ; the byte -> Y, since X
                AND     #$00FF                  ;   selects the service and A
                TAY                             ;   carries the index
                LDA     6,S
                AND     #$00FF
                CMP     #CHARDEV_MAX
                BCC     @kcw_in
                LDA     #ENODEV
                LEAVEK
                RTL
@kcw_in         PHA                             ; the clean index, briefly
                LDA     12,S                    ; the ioflag -- 10,S, shifted by
                AND     #VFS_IO_NDELAY          ;   the push above
                ASL                             ; -> CDIDX_NDELAY; see kc_cdread
                ASL
                ASL
                ORA     1,S                     ; | the index
                PLX                             ; drop the staged copy; X is
                LDX     #KSVC_CDWRITE           ;   reloaded on the next line
                JSL     SYS_KCALL
                BCS     @kcw_ok
                AND     #$00FF
                BRA     @kcw_out
@kcw_ok         LDA     #0
@kcw_out        LEAVEK
                RTL

