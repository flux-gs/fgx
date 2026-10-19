;==============================================================================
; SPDX-License-Identifier: BSD-2-Clause
; SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
;
; FGX-Provenance: 2.11BSD tty_tty(4)
;   Ported from usr/sys/sys/tty_tty.c, 2.11BSD.  Original work:
;   Copyright (c) 1986 Regents of the University of California.
;   All rights reserved.
;
; tty_tty.s - /dev/tty, the indirect driver for the controlling terminal.
;
; A program that has been redirected still needs its terminal: `cmd | more'
; leaves more(1) with a pipe on fd 0, so its pager key has to come from
; somewhere else.  BSD's answer is this device, and every one of its ops is the
; same two lines -- fail if the process has no controlling terminal, otherwise
; re-dispatch to the one it has:
;
;       syread(dev, uio, flag)
;       {
;               if (u.u_ttyp == NULL)
;                       return (ENXIO);
;               return ((*cdevsw[major(u.u_ttyd)].d_read)(u.u_ttyd, uio, flag));
;       }
;                       -- vendor/2.11BSD/usr/sys/sys/tty_tty.c:30-37
;
; FGX HAD NO SUCH DEVICE, and SYS_GETKEY/SYS_POLLKEY grew into the gap.  Those
; take no fd at all: they dequeue the kernel keyboard ring, so more(1), ping,
; udpecho, tip, worm, robots and netdump read the PHYSICAL CONSOLE no matter
; which terminal they are running on.  Measured over a pty by the ptykey
; fixture, which types `z' at the console and writes `X' into the pty: the
; program on the pty reports pk=z rd=X -- it took the console's keystroke, and
; the byte on its own terminal was reachable only through the fd those two
; syscalls do not have (apple/fgx#151).
;
; WHERE THE RE-DISPATCH HAPPENS, and why it is not a vtable forward.  BSD's
; line discipline is reached THROUGH cdevsw, so syread can forward at the same
; layer it was called from.  FGX's is not: _Sys_Read classifies a tty chardev
; by index and jumps into the shared discipline with _kTtyRdPtr pointing at the
; line, never touching COPS_Read (syscall.s @rd_disc).  So the indirection has
; to happen one step EARLIER, on the chardev index itself: _SyTty_Resolve turns
; the /dev/tty index into the caller's controlling line's index right where the
; index is read out of the FCB, and everything downstream -- discipline,
; SIGTTIN gate, background-write gate, ioctl routing -- is then the code that
; already serves that line.  That is `major(u.u_ttyd)' substitution expressed
; in FGX's dispatch, and it keeps the semantics BSD chose deliberately: the
; indirection is re-evaluated PER OP, so an fd held across a change of
; controlling terminal follows the process rather than the terminal it was
; opened on.
;
; The ops below are therefore reached ONLY when the resolve found nothing --
; i.e. exactly BSD's `u.u_ttyp == NULL' arm -- plus open(2), which resolve does
; not cover.  That leaves them all saying ENXIO, which is the whole of what
; tty_tty.c has to say in that case.
;==============================================================================

                MX      %00

;------------------------------------------------------------------------------
; _syttyIdx - chardev idx of /dev/tty, captured at registration.
;
; $FFFF until registered, the same discipline _ptyMasterIdx0/1, _ttyvIdx0/1 and
; _conIdx keep: a failed registration must not alias chardev idx 0, or every
; op on /dev/null would be redirected through here.
;------------------------------------------------------------------------------
_syttyIdx       ENT
                DS      2

;------------------------------------------------------------------------------
; _ttyCdIdx - tty index -> chardev idx, or $FFFF for a line with no node.
;
; This is FGX's cdevsw row for a terminal, and it is a TABLE rather than a scan
; of CD_TtyOff for one specific reason: the console registers with tty offset
; 0, which _Chardev_SetTtyOff also uses as its "not a tty" sentinel, so tty[0]
; is exactly the line a reverse scan cannot find.  Populated in
; _Chardev_InitBuiltins beside each registration, so there is one place where a
; line's node is recorded.
;------------------------------------------------------------------------------
_ttyCdIdx       ENT
                DS      2*NTTY

;------------------------------------------------------------------------------
; _SyTty_NoteLine - record the chardev node that serves a tty line.
;
; In:   MX %00.  A = chardev idx, X = tty INDEX (not the byte offset).
; Out:  A unchanged, so this can sit in front of the _Chardev_SetTtyOff call
;       that wants the same idx.  Clobbers X.
;------------------------------------------------------------------------------
_SyTty_NoteLine ENT
                MX      %00
                PHA
                TXA
                ASL     A                       ; word index
                TAX
                PLA
                STA     _ttyCdIdx,X
                RTS

;------------------------------------------------------------------------------
; _SyTty_InitLines - mark every tty line as having no chardev node.
;
; MX %00.  Clobbers A, X.  Must run before the first registration:
; _KMem_ClearGlobals leaves the table ZEROED, and zero is chardev idx 0
; (/dev/null), so an unregistered line would resolve there instead of failing.
;------------------------------------------------------------------------------
_SyTty_InitLines ENT
                MX      %00
                LDX     #0
@sil_L          LDA     #$FFFF
                STA     _ttyCdIdx,X
                INX
                INX
                CPX     #2*NTTY
                BCC     @sil_L
                RTS

;------------------------------------------------------------------------------
; _SyTty_Resolve - substitute the caller's controlling line for /dev/tty.
;
; In:   MX %00.  A = chardev idx, high byte clear.
; Out:  MX %00.  A = the chardev idx to act on.
; PRESERVES X AND Y: the seam arms that call it hold their own arguments there.
;
; This is 2.11BSD tty_tty.c's `syread'/`sywrite'/`syioctl'/`syselect' --
; "if (u.u_ttyp == NULL) return (ENXIO); return ((*cdevsw[major(u.u_ttyd)]
; .d_read)(u.u_ttyd, uio, flag));" -- done on the INDEX rather than inside the
; ops, because FGX's tty drivers find their line by the index the seam staged
; (_Sys_WrCdIdx, _selCdIdx) and not by the dispatch.  So the vnode road's
; entries into the switch call this before they stage anything: KSVC_CDREAD,
; KSVC_CDWRITE, KSVC_CDPOLL, `_Io_CdThenTty' for ioctl, and `_Chardev_Bulk'
; for d_read/d_write.  It stays a per-op substitution, as upstream's is, so an
; fd held across a change of controlling terminal follows the process.
;
; Any index that is not /dev/tty returns unchanged, so the other devices pay
; one compare and a taken branch.
;
; When the caller has NO controlling terminal the index is left ON /dev/tty,
; whose ops answer ENXIO -- upstream's `u.u_ttyp == NULL' arm, living with the
; device it belongs to.
;------------------------------------------------------------------------------
_SyTty_Resolve  ENT
                MX      %00
                CMP     _syttyIdx
                BEQ     @str_isTty
                RTS                             ; not /dev/tty
@str_isTty      PHX
                PHY
                JSR     _Se_CurCtty             ; A = ctty tty index, or $FFFF
                CMP     #NTTY                   ; $FFFF (none) also fails this
                BCS     @str_none
                ASL     A                       ; word index
                TAX
                LDA     _ttyCdIdx,X
                CMP     #$FFFF
                BNE     @str_out
@str_none       LDA     _syttyIdx               ; no controlling terminal: stay
                                                ;   on /dev/tty, whose ops answer
                                                ;   ENXIO
@str_out        PLY
                PLX
                RTS

;------------------------------------------------------------------------------
; The ops.  Reached only with no controlling terminal (see the header), except
; _SyTty_Open, which _SyTty_Resolve does not cover because open(2) reads the
; index straight out of the path lookup.
;
; DELIBERATELY NOT FORWARDING THE OPEN.  syopen re-dispatches to the real
; device's d_open, but the only thing that accomplishes for a tty is
; ttyopen()'s session claim -- and that is guarded on `p_pgrp == 0', which
; cannot hold here: a process with no group has no controlling terminal, so it
; took the ENXIO arm two instructions ago.  Forwarding would still bump the
; target node's CD_OpenCount, and _Chardev_Close gates the driver teardown on
; that count, so a /dev/tty open would postpone the real line's last close.
;------------------------------------------------------------------------------
_SyTty_Open     MX      %00
                JSR     _Se_CurCtty
                CMP     #$FFFF
                BEQ     @sto_none
                SEC
                RTL
@sto_none       LDA     #ENXIO
                CLC
                RTL

_SyTty_Close    MX      %00
                SEC
                RTL

_SyTty_Read     MX      %00
                LDA     #ENXIO                  ; NOT A=0: that is the chardev
                CLC                             ;   read contract's EOF, and a
                RTL                             ;   pager would read it as a
                                                ;   finished file rather than a
                                                ;   missing terminal

_SyTty_Write    MX      %00
                LDA     #ENXIO
                CLC
                RTL

_SyTty_Ioctl    MX      %00
                ; TIOCNOTTY SUCCEEDS WITH NO CONTROLLING TERMINAL, and that
                ; ordering is tty_tty.c's own: syioctl tests this command BEFORE
                ; the `u.u_ttyp == NULL' check, because "give up the terminal" is
                ; already satisfied by a task that has none.  This arm is only
                ; ever reached in that case -- with a ctty, _SyTty_Resolve has
                ; already sent the ioctl to the real line, where @si_dtch does
                ; the detaching.
                LDA     _Sys_IoctlCmd
                CMP     #TIOCNOTTY
                BEQ     @sti_notty
                LDA     #ENXIO
                CLC
                RTL
@sti_notty      LDA     #0
                SEC
                RTL

_SyTty_Poll     MX      %00
                LDA     #0                      ; neither readable nor writable;
                SEC                             ;   syselect's ENXIO arm returns
                RTL                             ;   0 ready descriptors too

;------------------------------------------------------------------------------
; _SyTtyChardev_Ops - CharDev_Ops vtable.  Order MUST match the COPS_* offsets
; in include/chardev.s.
;------------------------------------------------------------------------------
_SyTtyChardev_Ops ENT
                DFB     <_SyTty_Open,>_SyTty_Open,^_SyTty_Open
                DFB     <_SyTty_Close,>_SyTty_Close,^_SyTty_Close
                DFB     <_SyTty_Read,>_SyTty_Read,^_SyTty_Read
                DFB     <_SyTty_Write,>_SyTty_Write,^_SyTty_Write
                DFB     <_SyTty_Ioctl,>_SyTty_Ioctl,^_SyTty_Ioctl
                DFB     <_SyTty_Poll,>_SyTty_Poll,^_SyTty_Poll
                DFB     0,0,0                                   ; d_read:  none -- per-byte
                DFB     0,0,0                                   ; d_write: none -- per-byte
                DFB     0,0,0                                   ; d_stop:  nothing in flight

_SyTtyName      ASC     'tty',00

;==============================================================================
; END tty_tty.s
;==============================================================================
