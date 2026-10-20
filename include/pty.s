;==============================================================================
; pty.s - pty pair-record layout and flags.
;
; Split out of src/kernel/pty.s when the pty driver body became pty.mod
; (2026-08-11).  BOTH sides need these: the core bank keeps the pair table,
; the rings and _Pty_Init, while the module holds every routine that walks
; them.  One definition, PUT by both, so a record field can never mean two
; different offsets on the two sides of the seam -- which would be a silent
; corruption, not a build error.
;==============================================================================

PTY_NPAIR       EQU     2
; `PTY_RING_SZ' AND `PTY_RING_MASK' STOOD HERE and went with the last ring at
; T6 increment 4a.  A pty's bytes live in `struct tty's clists now in BOTH
; directions -- `t_rawq' inbound since the 4a flip, `t_outq' outbound since T4
; increment 4 -- so the size of a pty buffer is NCLIST's question and not this
; file's.  (The EQU had been halved 256 -> 128 on 2026-07-27 to fund signal
; disposition work; the whole 256 bytes of core bank it backed are back now.)


; --- pair record ---
                DUM     0
PTYR_Flags      DS      2               ; PTYF_* bits
PTYR_TtyIdx     DS      2               ; owning slave tty index (1 or 2)
PTYR_TtyOff     DS      2               ; = TtyIdx * TTY_SIZE (cached)
; ALL SIX RING CURSORS STOOD HERE and are gone: PTYR_OutHead/OutTail/OutCount
; with the slave->master ring at T4 increment 7, PTYR_InHead/InTail/InCount
; with the master->slave ring at T6 increment 4a.  REMOVED rather than stubbed,
; unlike the vtable directory entries beside them: this record is a DUM layout
; that pty.mod and the core's src/kernel/pty.s both PUT and are both rebuilt
; from, so nothing outside the image bakes an offset into it.  A slot TABLE is
; the other case and says so where it lives.
PTYR_Send       DS      2               ; `pt_send': the TIOCPKT_* status bits
                                        ; owed to the master, delivered ahead
                                        ; of any data and cleared by that read
                                        ; (2.11BSD tty_pty.c:252-257).  A WORD
                                        ; for a u_char, because everything in
                                        ; this record is one and the arms that
                                        ; OR into it are 16-bit.
PTYR_SIZE       EQU     *
                DEND

; `ttyselect's `rw' argument, from `usr/sys/h/file.h'.  A THIRD copy of a
; two-valued constant, and named PTY_ so it cannot collide: TTYIO_FREAD /
; TTYIO_FWRITE in include/ktty.s is the core bank's spelling and FREAD / FWRITE
; in src/kernel/tty/tty.h is the one the tty bank's C compiles against.  All
; three are the same two numbers on either side of two banks, which ktty.s's own
; note already says of its pair.
PTY_FREAD       EQU     1
PTY_FWRITE      EQU     2

PTYF_MOPEN      EQU     $0001           ; master side open (exclusive)
PTYF_SOPEN      EQU     $0002           ; >=1 slave fd open
PTYF_PKT        EQU     $0004           ; TIOCPKT packet mode (master reads)
PTYF_STOPPED    EQU     $0008           ; `PF_STOPPED' (tty_pty.c:53): output
                                        ; is stopped and the master has been
                                        ; told, so the restart owes it a
                                        ; TIOCPKT_START.  It REPLACES the old
                                        ; PTYF_FLUSHPEND, which was a one-bit
                                        ; stand-in for `pt_send' able to carry
                                        ; only the flush; the real byte is
                                        ; PTYR_Send above.

; minor encoding at registration: minor = pair*2 + side (0=master 1=slave)
