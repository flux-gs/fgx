;==============================================================================
; ttyv.s - the console and virtual console tty lines.
;
; /dev/console is tty[0]; /dev/ttyv1-ttyv3 are tty lines appended to
; _ttyTable after the pty pairs, each routed to its own virtual console
; (ttyv3 is the Second Sight card when the sscon module finds one).  Opens,
; reads, writes and ioctls go through the 2.11BSD tty discipline in the tty
; bank; this file holds the chardev entry points, the VC focus switch and the
; tty-line accessors the rest of the kernel uses.  A dispatch for a line that
; is not a ttyv line answers ENXIO.
;
; WHY tty[3..4] AND NOT tty[1..2]: pair 0 -> tty[1] and pair 1 -> tty[2] are
; baked at pty.s:94-102.  Appending leaves the tty offsets alone;
; registering AFTER the pty slaves in _Chardev_InitBuiltins leaves the chardev
; indices alone.  Inserting ahead of either would silently misdirect the ptys,
; which is what the logintest/inithup guard exists to catch.
;
; Bank: assembled at $02 and relocated with the rest of the kernel.  The vtable
; below bakes ^ bank bytes of $02; _Chardev_Dispatch ignores them and JSLs
; through _cdDispOpsBank (the live bank captured at registration), exactly as
; the /dev/null vtable comment in chardev.s describes.
;==============================================================================

; /dev/console -- tty[0], the physical console (apple/fgx#121).  Registering
; it is the whole fix: every other line is a device init opens onto the child's
; 0/1/2, so _Se_TtyOpen binds ctty AND foreground group in the child exactly as
; 2.11BSD's ttyopen() does (tty.c:646-660).  The console had no node, so it fell
; outside that mechanism and NO task on tty[0] ever had a controlling terminal
; -- leaving every `tp == u.u_ttyp' test live on the VCs and dead on the console.
_ConName        ASC     'console',00
_TtyvName_1     ASC     'ttyv1',00
_TtyvName_2     ASC     'ttyv2',00
_TtyvName_3     ASC     'ttyv3',00

; _vcBorderTbl - the SHR border colour of each virtual console, NVC entries
; indexed by VC number, in $C034's low nibble: VC 0 blue (the colour Con_Init
; sets), VC 1 dark green, VC 2 purple, VC 3 orange.  The border follows the
; console that has the KEYBOARD (_kVcFocus), not the one on the screen: the
; two agree after Option-1..3, and after Option-4 the IIgs screen keeps its
; console while the keys go to the card's, so the orange border is the one
; visible sign of where typing lands.
_vcBorderTbl    DFB     2,4,3,9

;------------------------------------------------------------------------------
; _Vc_FocusBorder - paint the SHR border in _kVcFocus's colour.  Read-modify-
; write of $C034, whose high nibble is the clock control (console_init.s).
; MX %00.  Preserves A, X, Y.
;------------------------------------------------------------------------------
_Vc_FocusBorder MX      %00
                PHA
                PHX
                LDX     _kVcFocus
                SEP     #$20
                MX      %10
                LDA     _vcBorderTbl,X
                PHA                             ; the colour, under the RMW
                LDAL    $E0C034
                AND     #$F0                    ; keep the clock-control nibble
                ORA     1,S
                STAL    $E0C034
                PLA
                REP     #$20
                MX      %00
                PLX
                PLA
                RTS

;------------------------------------------------------------------------------
; Chardev ops.  D0 stubs -- see the header.  ABI matches the /dev/null set:
; A.lo = chardev idx on entry, C=1 = ok, C=0 + A = errno on failure.
;------------------------------------------------------------------------------
_Ttyv_Open      MX %00
                ; Give the line a real discipline at open, exactly as the pty
                ; slave does.  Without this a VC comes up with an undefined
                ; sgtty state -- no ECHO, no CRMOD, a zero canonical buffer --
                ; and a getty on it would read raw garbage.  TTY_Backend is left
                ; 0, which selects the CONSOLE (keyboard) byte source: a VC IS a
                ; console, it just may not be the one on screen.
                ; THE MINOR ARRIVES IN Y, not in _cdArgByte.  _Chardev_Dispatch
                ; documents it: "Y = minor byte, A = arg byte -- meaningful for
                ; COPS_Write (the byte to send); IGNORED by the other ops"
                ; (chardev.s:376-387).  An earlier cut read _cdArgByte here, so
                ; open() computed its tty offset from whatever byte the last
                ; WRITE had staged.  vcwrite survived by luck -- the cell
                ; happened to be 0, which maps to tty[3] and is correct for
                ; ttyv1 -- while a shell spawned on the line by init got garbage
                ; and _Tty_CookedDefaults wrote through an out-of-range offset.
                TYA
                AND     #$0003                  ; minor 0/1/2 -> VC 1/2/3
                PHX
                PHY
                BEQ     @to_vc1                 ; minor*TTY_SIZE, not minor*2 --
                CMP     #2                      ;   an ASL here put ttyv2 at
                BEQ     @to_vc3                 ;   tty[3]+2, smearing ttyv1's
                LDX     #TTY_SIZE*4             ;   live state with cooked
                BRA     @to_haveX               ;   defaults and deriving a
@to_vc3         LDX     #TTY_SIZE*6             ;   bogus ctty index
                BRA     @to_haveX
@to_vc1         LDX     #TTY_SIZE*3
@to_haveX
                JSR     _Tty_CookedDefaults
                ; ACQUIRE THIS LINE AS THE CALLER'S SESSION -- ctty AND
                ; foreground process group, in ttyopen()'s single guarded
                ; block.  init opens the device inside the CHILD (spawnx
                ; file_actions), so the shell that will run on this VC is the
                ; task acquiring it -- no spawn plumbing needed.  Without this,
                ; SYS_GETKEY has no tty binding and a shell on a background VC
                ; dequeues console keystrokes directly (apple/fgx#41): the tail
                ; of every typed command vanished into the second shell.
                JSR     _Se_TtyOpen             ; X = tty byte offset (preserved)
                PLY
                PLX
                SEC                             ; the line exists; opening is ok
                RTL

; _Ttyv_Close - COPS_Close.  BSD's ttyclose(), which FGX had left empty.
;
; 2.11BSD tty.c:
;
;     ttyclose(tp)
;     {
;             ttyflush(tp, FREAD|FWRITE);
;             tp->t_pgrp = 0;
;             tp->t_state = 0;
;     }
;
; `t_pgrp = 0` is the load-bearing line: ttyopen() only CLAIMS a line whose
; t_pgrp is 0, so leaving it set makes the next opener JOIN the dead session
; instead of founding its own.  This routine was `SEC / RTL` -- it did nothing
; -- so when a getty on ttyv1 exited, tty[3] kept naming the dead getty's pid
; and the next getty adopted it (apple/fgx#72).
;
; That adoption is why the suite stayed green, and why it is still a bug: pids
; are ONE BYTE (TCB_TaskID; pids run 1..NPROC), so the space wraps fast on a
; machine respawning gettys.  The moment the dead leader's pid is reused by an
; unrelated process, that process silently belongs to this line's foreground
; group and takes its ^C and ^Z, with nothing in the system to explain why.
;
; The pty side has done this since it shipped -- _Pty_MaybeReset zeroes
; TTY_FgPgrp when the pair fully closes -- so this is the virtual consoles
; catching up to their own sibling, not a new idea.
;
; THE MINOR ARRIVES IN Y, exactly as in _Ttyv_Open above, and for the same
; reason: _cdArgByte is the WRITE byte and reading it here would compute the
; tty offset from whatever was last printed.  That trap has already cost one
; bug on the open side; it is not repeated here.
;
; CanonLen/CanonPos are zeroed as ttyflush's analogue -- the same two cells
; _Tty_DeliverSig clears on INTR (signal.s:324-325), so typed-ahead does not
; survive into the next session on the line.
_Ttyv_Close     MX %00
                PHX
                PHY
                TYA
                AND     #$0003                  ; minor 0/1/2 -> VC 1/2/3
                BEQ     @tc_vc1
                CMP     #2
                BEQ     @tc_vc3
                LDX     #TTY_SIZE*4             ; ttyv2 -> tty[4]
                BRA     @tc_haveX
@tc_vc3         LDX     #TTY_SIZE*6             ; ttyv3 -> tty[6]
                BRA     @tc_haveX
@tc_vc1         LDX     #TTY_SIZE*3             ; ttyv1 -> tty[3]
@tc_haveX       PHX                             ; _Se_TtyOffToIdx IS the X counter,
                TXA                             ;   and X is live for the STZs
                JSR     _Se_TtyOffToIdx         ;   below
                LDX     #0
                JSR     _Tty_SetPgrp            ; the next opener FOUNDS a session
                PLX
                TXA                             ; increment 8b: the queue is the
                JSR     _Se_TtyOffToIdx         ;   bank's, so the flush is too
                LDX     #TTYIO_FREAD+TTYIO_FWRITE
_ktp079         JSL     KTTY_KC_TTFLUSH
                PLY
                PLX
                SEC
                RTL

_Ttyv_Read      MX %00
                LDA #0                          ; D0: no backend ring yet (D1.5
                CLC                             ;   builds it) -> immediate EOF
                RTL

_Ttyv_Write     MX %00
                ; The byte is staged in _cdArgByte by the caller.  Whichever VC
                ; this line belongs to, the console engine is ALREADY pointing
                ; at it: either it is the on-screen VC, or _Vc_WriteEnter
                ; bracketed the whole write(2) before the loop started, or
                ; _Vc_EchoEnter pointed it there for a run of the discipline's
                ; own output.  So this is an ordinary Con_Write -- the routing
                ; happened one level up, which is the only place it can happen
                ; without paying a 194-byte repatch per character.
                LDA     _Sys_WrCdIdx
                AND     #$00FF
                JSR     _Vc_FromCdIdx           ; -> X = this line's tty offset
                BCS     @tw_haveTty
                LDA     #ENXIO                  ; not a ttyv line: a dispatch
                CLC                             ;   with a foreign index lands
                RTL                             ;   here
                ; ONLCR IS THE DISCIPLINE'S, AND THIS ROUTINE MUST NOT MAP AT
                ; ALL.  The only caller of this op is `tty_oproc' draining
                ; `t_outq', and `ttyoutput' has ALREADY turned LF into CR+LF on
                ; the way into that queue (tty.c:400, upstream's "Turn <nl> to
                ; <cr><lf> if desired").  Mapping again here puts CR CR LF on
                ; the wire: survivable on the console, which treats the second
                ; CR as a no-op, and not through telnetd, where it reads as
                ; corrupted text.
                ;
                ; THE ECHO COMES THROUGH HERE TOO.  `ttyinput' runs on the
                ; receive interrupt, so an echoed byte goes into `t_outq' like
                ; any other output and reaches this op through `tty_oproc' and
                ; `kc_cdwrite'.  One path, already mapped.
@tw_haveTty     PHX                             ; tty offset
                LDA     _cdArgByte
                AND     #$00FF
_kfp332         JSL     KFAR_CON_WRITE
                PLX
                SEC
                RTL

_Ttyv_Ioctl     MX %00
                LDA #ENOTTY                     ; D1.5 adds the idx->tty-offset
                CLC                             ;   mapping that ttyname() needs
                RTL

;------------------------------------------------------------------------------
; _Con_DRead / _Con_DWrite / _Ttyv_DRead / _Ttyv_DWrite - cdevsw's d_read and
; d_write for the four KERNEL-BANK tty lines.  apple/fgx#198's third defect.
;
; UPSTREAM IS ONE LINE AND SO IS THE BODY HERE:
;
;     cnread(dev, uio, flag)
;     {
;         register struct tty *tp = &cons[minor(dev)];
;         return ((*linesw[tp->t_line].l_read)(tp, uio, flag));
;     }
;
; -- vendor/2.11BSD/usr/sys/pdp/cons.c:86-94, with `cnwrite' below it identical
; but for `l_write'.  `_Tty_Read'/`_Tty_Write' ARE that dispatch: they cross
; into the tty bank, where `kc_ttread'/`kc_ttwrite' index `linesw[tp->t_line]'.
; So these four routines are the frame unpacking and nothing else.
;
; **THE WRITE HALF COST A STACK MOVE TO GET HERE -- apple/fgx#246.**  It was
; written first and it RESET THE MACHINE, because `ttwrite' kept upstream's
; `char obuf[OBUFSIZ]' on the kernel stack and the vnode road is about 136
; bytes deeper than the registry road was: the whole `vn_write' -> `spec_write' ->
; `spec_chwrite' -> `kc_cddwrite' chain of fcc frames is still standing under
; it.  Painted-arena high-water, one probe, one byte,
; `tools/mame_test/kstkhwm_check.py':
;
;     the same write through the registry              266 of 512
;     the READ half, through `/dev'                     402 of 512  (110 spare)
;     the WRITE half, through `/dev', at OBUFSIZ 32     448 of 512  ( 64 spare)
;     ...so at OBUFSIZ 100                              516 of 512  -- RESET
;
; Nothing catches that: `_fcc_stkfloor' is left at zero on FGX_DP_KERNELC, so
; it is a wild write below the stack and a blank screen.  The buffer is in the
; u-area now (`U_TtyObuf'), which gives all 100 bytes back on EVERY tty write
; rather than buying this one road its margin by shrinking a chunk size.
;
; WHY THE SLOTS WERE EMPTY UNTIL NOW.  Before T3-T6 moved the discipline into
; the bank there was no `l_read' to dispatch, so `spec_chread' found no bulk op
; and fell to its PER-BYTE loop -- which reads a tty line with no discipline at
; all.  That is apple/fgx#198 (3): the same line behaves differently depending
; on which of the two roads a caller reached it by.
;
; THE MINOR NAMES THE LINE, exactly as upstream's `&cons[minor(dev)]' does, and
; NOT `_cdBulkArg' -- _Chardev_Bulk's header states that nothing is held in a
; static across the dispatch, because a bulk op can BLOCK and `ttread' does.
;
; In:  Y = minor.  Frame: 9,S uio offset, 11,S uio bank, 13,S flag.
; Out: C=1 success, or C=0 + A = errno.
;------------------------------------------------------------------------------
_Con_DRead      MX      %00
                LDX     #UIO_READ
                JSR     @tv_stage
                BCC     @tv_err                 ; A = EINVAL, C already clear
                LDA     #0                      ; the console IS tty[0]
                JSR     _Tty_Read
                BRA     @tv_done

_Con_DWrite     MX      %00
                LDX     #UIO_WRITE
                JSR     @tv_stage
                BCC     @tv_err
                LDA     _conIdx                 ; the bracket, see @tv_bracket
                JSR     _Vc_WriteEnter
                BCC     @tv_err                 ; ENOMEM; no bracket was opened
                LDX     #UIO_WRITE              ; staged again: see @tv_stage
                JSR     @tv_stage
                BCC     @tv_wrDone              ; A = EINVAL; the bracket closes
                LDA     #0
                JSR     _Tty_Write
                BRA     @tv_wrDone

_Ttyv_DRead     MX      %00
                LDX     #UIO_READ
                JSR     @tv_stage
                BCC     @tv_err
                JSR     @tv_idx
                JSR     _Tty_Read
                BRA     @tv_done

_Ttyv_DWrite    MX      %00
                LDX     #UIO_WRITE
                JSR     @tv_stage
                BCC     @tv_err
                JSR     @tv_cdidx               ; the bracket, see @tv_bracket
                JSR     _Vc_WriteEnter
                BCC     @tv_err                 ; ENOMEM; no bracket was opened
                LDX     #UIO_WRITE              ; staged again: see @tv_stage
                JSR     @tv_stage
                BCC     @tv_wrDone              ; A = EINVAL; the bracket closes
                JSR     @tv_idx
                JSR     _Tty_Write
@tv_wrDone      JSR     _Vc_WriteLeave          ; preserves A and the carry
                ; fall through

                ; `ttread'/`ttwrite' answer an ERRNO with 0 for success; a
                ; chardev op answers in the CARRY.  EOF NEEDS NO ARM OF ITS OWN:
                ; upstream's is `return (0)' having moved nothing (tty.c:1789),
                ; so it arrives here as errno 0 with the uio untouched -- and a
                ; read(2) that moved zero bytes and succeeded IS end of file.
@tv_done        CMP     #0
                BNE     @tv_err
                SEC
                RTL
@tv_err         CLC
                RTL

                ; Minor 0/1/2 is VC 1/2/3 at tty[3]/tty[4]/tty[6] -- the same
                ; mapping `_Ttyv_Close' spells out, computed from the minor
                ; rather than from a captured chardev index so that this op
                ; needs nothing that survived the dispatch.
@tv_idx         TYA
                AND     #$0003                  ; minor 0/1/2 -> VC 1/2/3
                CMP     #2
                BEQ     @tvi_v3
                CLC
                ADC     #3                      ; -> tty[3] / tty[4]
                RTS
@tvi_v3         LDA     #6                      ; -> tty[6], the card's line
                RTS

                ; @tv_bracket - why the WRITE ops carry `_Vc_WriteEnter' and
                ; the read ops do not.
                ;
                ; UPSTREAM HAS NO SUCH THING: `cnwrite' is
                ; `(*linesw[tp->t_line].l_write)(tp, uio, flag)' and nothing
                ; else (2.11BSD pdp/cons.c:96-104).  FGX's console engine is
                ; MULTIPLEXED -- one renderer pointed at one VC's framebuffer
                ; bank -- and `tty_oproc' paints through it synchronously, so a
                ; write to a line that is not on screen lands wherever the
                ; engine happens to point unless something repoints it first.
                ; That something is this pair, and `_Vc_WriteEnter's own header
                ; states what happens without it: the bytes "splash a
                ; background session's output across whatever the user is
                ; looking at".
                ;
                ; HERE AND NOT IN `spec_chwrite', for the reason
                ; `_Vc_WriteEnter's header gives about `_Chardev_Write': the
                ; bracket costs a 194-byte repatch and must be paid ONCE per
                ; write(2).  A d_write IS once per write(2) -- it is handed the
                ; whole uio -- and it is in the core bank, where the pair
                ; already lives.  In `spec_chwrite' it would be a new KSVC seam
                ; out of vfs.mod for the same effect.
                ;
                ; THE READ OPS ARE BARE, deliberately.  A read paints only
                ; through the ECHO, and the echo leaves by `_FarSh_CdWrite',
                ; which refuses this bracket in as many words -- it reorders
                ; output enough to interleave a typed line with concurrent
                ; program output.  That shim points the engine at the typed
                ; line's console itself when the keyboard is on a console the
                ; screen is not showing (`_Vc_EchoEnter'), and otherwise the
                ; engine is already pointing at it.
                ;
                ; @tv_cdidx - Y = minor -> A = this VC line's CHARDEV index,
                ; which is what `_Vc_FromCdIdx' compares against.  $FFFF for an
                ; unregistered line, which that routine matches nothing for and
                ; so leaves unbracketed -- the pre-registration answer, and the
                ; right one.
@tv_cdidx       TYA
                AND     #$0003                  ; minor 0/1/2 -> VC 1/2/3
                BEQ     @tvc_v1
                CMP     #2
                BEQ     @tvc_v3
                LDA     _ttyvIdx1
                RTS
@tvc_v1         LDA     _ttyvIdx0
                RTS
@tvc_v3         LDA     _ttyvIdx2
                RTS

;------------------------------------------------------------------------------
; @tv_stage - stage the bulk op's frame into the two cells `_Tty_Read' and
; `_Tty_Write' read: `_libcTmp2' = a far pointer at the uio, `_Sys_CdFlag' =
; the op's flag.
;
; THE OFFSETS ARE FOUR HIGHER HERE THAN IN THE OP, and they are counted rather
; than assumed: the op reads 9/11/13,S, this routine is JSR'd from it (+2) and
; pushes Y (+2), so it reads 13/15/17,S.  _Chardev_Bulk's header is explicit
; that the frame reaches an op through THREE call instructions -- guessing the
; depth is how a shim reads the wrong words.
;
; Y IS THE MINOR AND MUST SURVIVE -- `@tv_idx' reads it after this returns.
;
; THE FRAME IS ASSERTED, NOT ASSUMED.  `uio_rw' must read as the direction this
; op is; get the offsets wrong and `_libcTmp2' is a wild pointer, which is
; unlikely to read as the one value X names.  X CARRYING UIO_WRITE FOR THE
; WRITE OPS IS WHAT MAKES IT DISCRIMINATE: a check that accepted UIO_READ alone
; would pass on a wild read, zero being UIO_READ.
;
; THE BANK BYTE IS STORED 8-BIT.  `_libcTmp2' is THREE bytes ($54..$56), so a
; 16-bit store at `_libcTmp2+2' runs into the next DP cell -- memmap.s:158 says
; so at the cell itself.
;
; THE WRITE OPS STAGE TWICE.  `_libcTmp2' is caller-saved scratch (dpmap.s),
; and the write bracket between staging and `_Tty_Write' can allocate: a
; virtual console's first write takes a screen bank, and with the pool dry
; Bank_Alloc's Memory Manager grant writes `_libcTmp2' (_MM_ClaimBanksToRow).
; Staging again after the bracket hands `_Tty_Write' the pointer from the
; frame, not whatever the bracket left in the cell (apple/fgx#514).
;
; In:  X = UIO_READ or UIO_WRITE.  MX %00.
; Out: C=1 staged, Y preserved.  C=0 + A = EINVAL when the frame does not read
;      as a uio in that direction.
;------------------------------------------------------------------------------
@tv_stage       PHY
                LDA     13,S                    ; uio offset
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     15,S                    ; uio bank
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                LDA     17,S                    ; the op's `flag' (VFS_IO_NDELAY
                STA     _Sys_CdFlag             ;   today; 0 through a vnode)
                LDY     #UIO_RW
                TXA
                CMP     [_libcTmp2],Y
                BNE     @tvs_bad
                PLY
                SEC
                RTS
@tvs_bad        PLY
                LDA     #EINVAL
                CLC
                RTS

;------------------------------------------------------------------------------
; _Tty_PollReadable - would a read(2) on this line return WITHOUT blocking?
;
; In:  X = tty byte offset.  MX %00.  Out: C=1 readable.  Preserves X.
;
; "A key is in the ring" is NOT the same question, and answering it was wrong in
; BOTH directions (apple/fgx#129):
;
;   - COOKED mode gathers a whole line before read() returns (@rd_gather,
;     syscall.s), so one non-newline key in the ring made select say readable
;     and the read that followed then BLOCKED -- the one answer select may not
;     give.  Cooked is the default discipline, so this was the common case; only
;     a RAW/CBREAK reader like telnet(1) escaped it.
;   - A committed line still being handed out with an empty ring reported NOT
;     readable, though read() would return instantly -- so a select-driven
;     byte-at-a-time canonical reader hung on data it already owned.
;
; SG_RAWCB is the same mask the read path itself uses to pick char-at-a-time, so
; the two cannot drift.
;
; THE FIRST QUESTION IS `ttnread''s: the queue is a clist in the tty bank, so
; the count comes from upstream's own readiness routine.
;
; THERE IS NO KEYBOARD-RING TEST, AND ADDING ONE IS THE BUG.  Bytes reach
; `t_rawq' AT ARRIVAL, so `ttnread' already sees every one of them and nothing
; drains `_kKbdRing' on a read(2) session.  The ring therefore saturates at
; KBD_RING_SZ and stays there, and a test on `_kKbdRingCount' would answer
; "readable" forever -- a RAW/CBREAK reader is then told to read a line whose
; clist is empty, and blocks.  That is the one answer select may not give
; (apple/fgx#243: telnet(1) stopped servicing its socket between keystrokes).
;
; A POLL OP IS THE READER THAT NEVER SHOWS UP IN A WITNESS, so every change
; that stops feeding a queue has to ask what still reads it.
;;------------------------------------------------------------------------------
_Tty_PollReadable MX    %00
                PHX                             ; _Se_TtyOffToIdx clobbers X;
                TXA                             ;   _Tty_NRead does not
                JSR     _Se_TtyOffToIdx
_ktp078         JSL     KTTY_KC_TTNREAD         ; increment 8b: upstream's own
                PLX                             ;   answer, not the core's old
                CMP     #0                      ;   CanonPos<CanonLen compare
                BEQ     @tpr_no                 ; the discipline has bytes, or
                                                ;   nothing is readable at all
@tpr_yes        SEC
                RTS
@tpr_no         CLC
                RTS


; _Ttyv_Poll - readiness of a virtual-console line (apple/fgx#129).
;
; THIS WAS A STUB RETURNING POLLOUT ONLY, and that is why a select-driven
; program was deaf on a virtual console.  read(2) got a ttyv arm routing into
; the gated line discipline; _Sel_Classify never got the twin, so select could
; never report a VC readable -- and a program that reads ONLY when select says
; so therefore never read at all.  Measured: telnet(1) on ttyv1 sat in
; select(), its keystrokes accumulated in the shared _kKbdRing, and the backlog
; was handed to whichever console became active next -- typing on VC1 came out
; on VC0 after a switch.
;
; Readable means the same thing it means for the console arm of _Sel_Classify:
; a key is waiting in the ring.  The VC test is what the console arm needs too,
; because THE RING IS SHARED -- every console would otherwise see every
; keystroke as its own.  A line that is not the one on screen cannot read, so
; it is not readable, which is exactly what its blocking read would do
; (_Tty_GetByte's @tgb_vcWait sleeps until its VC is on screen).  Reporting
; otherwise would make select promise a read that then blocks.
;
; Writable ALWAYS: a background VC's writes go to its own bank and do not wait
; for the screen.
;
; In: _selCdIdx = chardev index (staged by @cl_cd; the dispatcher clobbers A).
; Out: A = POLL* mask, C=1.  MX %00.
_Ttyv_Poll      MX %00
                LDA     _selCdIdx
                AND     #$00FF
                JSR     _Vc_FromCdIdx           ; -> A = VC index, X = tty offset
                BCC     @tp_wr                  ; not a ttyv line: write-only
                CMP     _kVcFocus               ; our VC has the keyboard?
                BNE     @tp_wr                  ;   no -> a read here would block
                JSR     _Tty_PollReadable       ; ...and would a read RETURN?
                BCC     @tp_wr
                LDA     #POLLIN+POLLOUT
                SEC
                RTL
@tp_wr          LDA     #POLLOUT
                SEC
                RTL

;------------------------------------------------------------------------------
; _Con_Open / _Con_Close - /dev/console, which IS tty[0] (apple/fgx#121).
;
; The VC ops derive their tty offset from the MINOR; the console has exactly one
; line, so these hardcode offset 0 rather than teaching that arithmetic a third
; case.  Everything else is shared with the VC ops, because a console and a
; virtual console differ only in which one is on screen -- _Ttyv_Open's own
; header says so.
;
; _Con_Open is ttyopen(): give the line a real discipline, then acquire it as
; the OPENER's session.  init opens the device in the CHILD, so the process that
; will run on the console is the one that binds it -- no parent-side plumbing,
; which is precisely the half that was missing.
;------------------------------------------------------------------------------
_Con_Open       MX %00
                PHX
                PHY
                LDX     #0                      ; the console IS tty[0]
                JSR     _Tty_CookedDefaults
                JSR     _Se_TtyOpen             ; ctty + pgrp, ttyopen()'s block
                PLY
                PLX
                SEC
                RTL

; _Con_Close - BSD's ttyclose() for tty[0].  `t_pgrp = 0' is the load-bearing
; line: ttyopen() only CLAIMS a line whose group is 0, so leaving it set makes
; the next opener JOIN the dead session.  Until the console had a node there was
; nowhere for this to happen at all, which is why init has to publish the group
; from the parent on every respawn -- that workaround can go once this runs.
; CanonLen/CanonPos are ttyflush's analogue, so type-ahead does not survive into
; the next session on the line.
_Con_Close      MX %00
                LDA     #0                      ; tty[0]
                LDX     #0
                JSR     _Tty_SetPgrp
                LDA     #0                      ; increment 8b: ttyflush on the
                LDX     #TTYIO_FREAD+TTYIO_FWRITE ; bank's queue, not the core's
_ktp080         JSL     KTTY_KC_TTFLUSH         ;   cursor
                SEC
                RTL

;------------------------------------------------------------------------------
; _ConChardev_Ops - /dev/console.  Read/Write/Ioctl/Poll are the VC ops
; unchanged: reads and writes go through the d_read/d_write slots below, the
; Ioctl op's ENOTTY sends tty commands on to the shared block through
; `_Io_CdThenTty', and Poll works off the chardev index via _Vc_FromCdIdx.
;------------------------------------------------------------------------------
_ConChardev_Ops ENT
                DFB     <_Con_Open,>_Con_Open,^_Con_Open
                DFB     <_Con_Close,>_Con_Close,^_Con_Close
                DFB     <_Ttyv_Read,>_Ttyv_Read,^_Ttyv_Read
                DFB     <_Ttyv_Write,>_Ttyv_Write,^_Ttyv_Write
                DFB     <_Ttyv_Ioctl,>_Ttyv_Ioctl,^_Ttyv_Ioctl
                DFB     <_Ttyv_Poll,>_Ttyv_Poll,^_Ttyv_Poll
                DFB     <_Con_DRead,>_Con_DRead,^_Con_DRead      ; d_read:  `cnread'
                DFB     <_Con_DWrite,>_Con_DWrite,^_Con_DWrite   ; d_write: `cnwrite'
                DFB     0,0,0                                   ; d_stop: none -- see the note
                                                                ;   below this table

;------------------------------------------------------------------------------
; _TtyvChardev_Ops - CharDev_Ops vtable.  Order MUST match COPS_* offsets in
; include/chardev.s.
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; WHY THE CONSOLE AND VC ROWS CARRY NO d_stop.
;
; It is NOT that nothing is in flight.  `tty_oproc' PAINTS THE SCREEN
; synchronously, holding `t_outq.c_cf' and a byte count across a call that runs
; for as long as a scroll takes, with interrupts on -- output in flight in
; every sense that matters, and upstream's `dz' rather than its `cn'.
;
; THE HANDSHAKE IS CARRIED, JUST NOT HERE (apple/fgx#254).  A d_stop cannot set
; TS_FLUSH on this ABI -- a chardev op receives a MINOR, not a `struct tty *',
; as serial.s records for the one driver that has a body -- and `kc_cdstop'
; defers at interrupt time, which is exactly when the INTR arm's `ttyflush'
; runs.  So `ttyflush' sets the latch and `tty_oproc' honours it, which is
; dzstop's and dzxint's halves in the two places this port can reach.  A d_stop
; row here would add nothing.
;------------------------------------------------------------------------------
_TtyvChardev_Ops ENT
                DFB     <_Ttyv_Open,>_Ttyv_Open,^_Ttyv_Open
                DFB     <_Ttyv_Close,>_Ttyv_Close,^_Ttyv_Close
                DFB     <_Ttyv_Read,>_Ttyv_Read,^_Ttyv_Read
                DFB     <_Ttyv_Write,>_Ttyv_Write,^_Ttyv_Write
                DFB     <_Ttyv_Ioctl,>_Ttyv_Ioctl,^_Ttyv_Ioctl
                DFB     <_Ttyv_Poll,>_Ttyv_Poll,^_Ttyv_Poll
                DFB     <_Ttyv_DRead,>_Ttyv_DRead,^_Ttyv_DRead   ; d_read:  `cnread'
                DFB     <_Ttyv_DWrite,>_Ttyv_DWrite,^_Ttyv_DWrite ; d_write: `cnwrite'
                DFB     0,0,0                                   ; d_stop: none -- see below

;------------------------------------------------------------------------------
; _ttyvIdx0 / _ttyvIdx1 / _ttyvIdx2 - chardev indices of the three VC lines,
; captured at registration.  $FFFF until registered, so a failed registration can never
; alias chardev idx 0 (the same trap _ptyMasterIdx0/1 guard against).  D1.5's
; ioctl and read dispatch select on these.
;------------------------------------------------------------------------------
_ttyvIdx0       ENT
                DS  2
_ttyvIdx1       ENT
                DS  2
_ttyvIdx2       ENT
                DS  2
; Same discipline for the console node.
_conIdx         ENT
                DS  2

;------------------------------------------------------------------------------
; _Se_TtyOffToIdx - A = tty BYTE offset -> A = tty index.  MX %00.
; TTY_SIZE is not a power of two, so this divides by repeated subtraction --
; NTTY is 5, so it runs at most four times.
;
;------------------------------------------------------------------------------
_Se_TtyOffToIdx MX      %00
                LDX     #0
@sto_loop       CMP     #TTY_SIZE
                BCC     @sto_done
                SEC
                SBC     #TTY_SIZE
                INX
                BRA     @sto_loop
@sto_done       TXA
                RTS


;------------------------------------------------------------------------------
; _Tty_PgrpOf / _Tty_SetPgrp - the foreground process group.  A = tty INDEX;
; _Tty_SetPgrp also takes X = the group.  MX %00.
;
; apple/fgx#108 T3 stage 1c.  `t_pgrp' lives in the tty bank's `ttys[]' now, so
; every reader crosses a bank.  Thin wrappers over export slots 8/9 rather than
; a JSL at each site: every JSL site would need its own _ktp marker and a row in
; src/kernel/tty_patchsites.s, and two wrappers cost two rows where fifteen call
; sites would cost fifteen.
;
; THEY PRESERVE X AND Y -- and _Tty_SetPgrp preserves A as well -- because that
; is what makes them a DROP-IN for the `LDA _ttyTable+TTY_FgPgrp,X' and
; `STZ ...,X' they replace, which clobbered no register at all.  Measured the
; hard way: syscall.s's tty read gate never touched X, the accessor path did,
; and @rd_disc then ran the read with a foreign X.  The gate's DECISION was
; right throughout -- logging showed it never once chose background -- so every
; symptom pointed at the comparison and none of it was the comparison.
;
; THE PULLS SET N/Z FROM THE RESTORED REGISTER, so a caller that branches on
; "no foreground group" needs its own CMP #0.
;
; A BAD INDEX READS AS ZERO rather than propagating the slot's carry: zero is
; what every caller already treats as "no foreground group", and the slot's
; @tpg_bad leaves A holding the INDEX, which _Kill_GroupFanout would happily
; match against init.  _TtyStateProbe calls the slot directly, so the carry is
; still under test.
;------------------------------------------------------------------------------
_Tty_PgrpOf     ENT
                MX      %00
                PHY
                PHX
_ktp019         JSL     KTTY_PGRP_GET
                BCS     @tpo_ok
                LDA     #0                      ; a bad line has no fg group
@tpo_ok         PLX
                PLY
                RTS

_Tty_SetPgrp    ENT
                MX      %00
                PHA                             ; the index, and the caller's A
                PHY
                PHX                             ; X is the VALUE, and the
_ktp020         JSL     KTTY_PGRP_SET           ;   caller's register too
                PLX
                PLY
                PLA
                RTS

;------------------------------------------------------------------------------
; _Tty_Ioctl - hand one ioctl to the tty bank's ttioctl (apple/fgx#108 T3
; stage 2).  A = tty INDEX; _Sys_IoctlCmd = the command; _libcTmp2 = the
; caller's argument far pointer (as @si_argp leaves it).  MX %00.
;
; Out: A = 0 handled, A = $FFFF the discipline does not know the command, else
; A = an errno.  C is not meaningful -- the caller tests A.  X and Y clobbered,
; which is safe here and NOWHERE ELSE: this is called from the ioctl
; dispatcher's tail, which needs neither afterwards.  Contrast _Tty_PgrpOf
; above, whose register transparency was paid for the hard way at stage 1c.
;
; KERNEL C, SO NOT AT INTERRUPT TIME.  include/kernelc.s makes kernel C a
; singleton across the far and tty banks alike; an ioctl arrives from a
; syscall, where no other C context can be live, which is exactly why slots
; 8-11 next door had to be assembly and this one need not be.
;
; THE ARGUMENTS ARE STAGED ON THE STACK BEFORE THE BRACKET, and that is forced
; rather than stylistic.  KTTY_KC_ENTER points DBR at the tty bank and D at
; FGX_DP_KERNELC, so after it neither `_Sys_IoctlCmd' (kernel bank, DBR) nor
; `_libcTmp2' (kernel direct page, D) can be read at all -- and the pushes
; cannot precede the bracket, because the three bytes it saves would then sit
; between the arguments and the callee's frame and fcc would read the return
; address as argument one (include/kernelc.s:320 states that trap at length).
; Stack-relative addressing is the one mode that survives both switches, so
; the values are pushed first and re-read at n,S after.  The same idiom is at
; src/modules/common/probe_dev.s:234, and for the same reason.
;
; EVERY OFFSET BELOW IS THEREFORE A RUNNING TOTAL, and each push moves all of
; them.  They are written out per step rather than left to be recomputed,
; because an off-by-two here reads as a plausible wrong ioctl argument.
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; _Tty_Chars - give one line the tty bank's default special characters
; (apple/fgx#108 T3 stage 2b).  A = tty INDEX.  MX %00.
;
; REGISTER-TRANSPARENT IN X AND Y, because its one caller is
; `_Tty_CookedDefaults', which indexes `_ttyTable' with X across its whole
; body.  That is stage 1c's rule, and the reason it is a rule: an accessor
; replacing an inline store clobbers what the store did not.
;
; Arguments are staged on the stack for the reason _Tty_Ioctl's header gives at
; length -- KTTY_KC_ENTER switches DBR and D, and the pushes cannot precede it.
; One 16-bit argument, so the arithmetic is short enough to read: the staged
; index sits at 1,S, the bracket puts it at 4,S, and nothing is pushed between.
;------------------------------------------------------------------------------
; _Tty_IntrQuitOf - A = tty INDEX -> A = t_intrc, X = t_quitc, Y = sg_flags.
; MX %00.  PRESERVES NOTHING: all three registers are results, which changed at
; stage 2d when the slot gained the mode word.  Its one caller is the KSVC arm
; in jumptable.s, which wants all three.
;
; A bad index answers 0,0,0 rather than leaving the caller's registers, so a
; caller that compares a byte against both characters gets "matches neither"
; instead of a stale one -- and 0 is not a character any of the callers can be
; holding, because the pty write path has already refused a NUL.  Zero flags
; likewise mean "cooked, no echo", which is the safe reading of a line that
; does not exist.
_Tty_IntrQuitOf ENT
                MX      %00
_ktp023         JSL     KTTY_INTRQUIT
                BCS     @tiq_ok
                LDA     #0
                TAX
                TAY
@tiq_ok         RTS

;------------------------------------------------------------------------------
; THE MODE WORD ACCESSORS (apple/fgx#108 T3 stage 2d).  `_ttyTable+TTY_SgFlags'
; and `_ttyTable+TTY_Lmode' are gone; `ttys[].t_flags' is the only copy, and it
; is ONE LONG whose low word is `sg_flags' and whose HIGH word is the local mode
; word.  That is upstream's own arrangement, not a packing convenience:
; `usr/sys/h/ioctl.h:175-189' defines every L* bit as `((int)(BIT>>16))', so
; LTOSTOP $0040 IS TOSTOP $00400000 shifted down.
;
; THEY TAKE A BYTE OFFSET, NOT AN INDEX, and that is deliberate.  Nearly every
; caller holds an offset in X -- the heartbeat, the signal paths, the console
; write, the read path -- so an index-taking accessor would put
; `PHX / TXA / JSR _Se_TtyOffToIdx / ... / PLX' at eight call sites instead of
; the conversion once, here.  Contrast `_Tty_PgrpOf', whose 1c callers had
; indexes to hand.
;
; THEY ARE REGISTER-TRANSPARENT IN X AND Y, and the setter in A as well.
; They replace `LDA _ttyTable+TTY_SgFlags,X' and `STA ...,X', which clobbered
; nothing; stage 1c paid for that rule the hard way and apple/fgx#224 paid for
; it again.  ONE OF THESE RUNS AT INTERRUPT TIME -- toolbox.s's heartbeat reads
; the mode word at 60 Hz -- which is why the slot behind them is assembly.
;
; A BAD OFFSET READS AS ZERO, matching _Tty_PgrpOf: cooked, no echo, no local
; bits, which is the safe reading of a line that does not exist.
; A = tty byte offset, X = sg_flags, Y = the local mode word.  Preserves all
; three, so it is a drop-in for the five stores the cooked-defaults seed made.
_Tty_SetFlagsAt ENT
                MX      %00
                PHA                             ; the offset, and the caller's A
                PHX                             ; X is a VALUE and the converter
                JSR     _Se_TtyOffToIdx         ;   counts in it
                PLX
                PHX                             ; ...and both values must also
                PHY                             ;   survive the slot
_ktp027         JSL     KTTY_FLAGS_SET
                PLY
                PLX
                PLA
                RTS

; KTTY SLOT 16 IS STUBBED, NOT REMOVED.  A slot's address is positional --
; `KTTY_SLOT0 + 4n' -- so deleting one slides every slot above it and silently
; repoints their callers.  include/ktty.s keeps the EQU and ttybank.s jumps it
; at `_Ktty_StubHalt'.

;------------------------------------------------------------------------------
; _Tty_SetWinSz - a line's WINDOW SIZE (apple/fgx#108 T3 stage 2c).  A = tty
; INDEX, X = ws_row, Y = ws_col.  MX %00.
;
; PRESERVES A, X AND Y -- stage 1c's rule, and here it is load-bearing twice
; over: `_Tty_CookedDefaults' indexes `_ttyTable' with X across its whole body
; and calls this with the INDEX in A that `_Tty_Chars' needs next, so the
; wrapper has to hand back everything it was given.  An accessor replacing an
; inline store clobbers what the store did not.
;
; ASSEMBLY ON BOTH SIDES, so no KTTY_KC_ENTER bracket and no staging: the slot
; takes its arguments in registers.  See include/ktty.s slot 15.
;------------------------------------------------------------------------------
_Tty_SetWinSz   ENT
                MX      %00
                PHA                             ; the index, and the caller's A
                PHY                             ; Y and X are the VALUES, and
                PHX                             ;   the caller's registers too
_ktp024         JSL     KTTY_WINSZ_SET
                PLX
                PLY
                PLA
                RTS

;------------------------------------------------------------------------------
; _Tty_NRead - A = tty INDEX -> A = bytes a read(2) would return now, 0 = it
; would block.  MX %00.  Clobbers X and Y.
;
; `ttnread' is upstream's own readiness answer, and it knows what a
; `CanonPos < CanonLen' compare cannot: in cooked mode an unterminated raw key
; is not a readable LINE.
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; _Tty_LineOpen - A = tty INDEX -> A = errno, 0 = opened.  MX %00.  Clobbers X
; and Y.
;
; The discipline's `l_open', which is `ttyopen' -- the routine that sets
; TS_ISOPEN and runs the session-acquisition block.  A pty slave open comes here
; rather than straight at `_Se_TtyOpen': `ttyopen' reaches that same core
; routine through `kc_ttyopen' and then does the rest of the open the tty
; structure owns, so the two banks cannot end up with different ideas of what an
; open did.
;------------------------------------------------------------------------------

; SEVERAL KTTY SLOTS CARRY THEIR OWN ENTRY STUB AND HAVE NO CORE-BANK WRAPPER
; (apple/fgx#268).  A wrapper that is a seam BRACKET and nothing else -- stage,
; cross, unstage -- earns no core bytes, so the slot's stub does the crossing
; and the KSVC arm calls the slot directly:
;
;   20  _KTty_Flush       `ttyflush'
;   23  _KTty_Modem       `ttymodem'.  A carrier DROP on an open line is the
;                         hangup: SIGHUP then SIGCONT to the line's foreground
;                         group, then both queues flushed.  Its only callers
;                         are the pty master's open and close -- upstream's
;                         `ptcopen'/`ptcclose' -- because a pty's carrier is
;                         the presence of its controller and nothing else.
;   24  _KTty_LineClose   `l_close' then `ttyclose', the pair `ptsclose' calls:
;                         the first takes the discipline off the line, the
;                         second flushes both queues, clears the foreground
;                         group and clears the whole of t_state.  Without the
;                         second, TS_ISOPEN never comes down and one session's
;                         unread input is the next session's first read.
;   25  _KTty_PtyOproc    the pty slave's `t_oproc'
;   31  _KTty_Stopped     `ttstopped'
;   32  _KTty_Select      `ttselect'
;   35  _KTty_PtcInput    `ptcwrite's inner loop
;   40  _KTty_GetRaw      the raw key read behind SYS_GETKEY/SYS_POLLKEY
;
; THE OFFSET-TO-INDEX CONVERSION STAYS CORE-SIDE in every one of them:
; `_Se_TtyOffToIdx' is core code, and so is the Y-to-X swap the KSVC convention
; forces.
;
; SLOTS 27 AND 28 STILL LAND ON `kc_ttoutq_cf' and `kc_ttoutq_flush' in the tty
; bank although nothing calls them: slot NUMBERS are append-only, because a
; slot's address is `KTTY_SLOT0 + 4n' and deleting one repoints every caller
; above it.  `_Tty_OutqUio' below is the door the master read uses instead --
; a uio, a destination that is a CURSOR, serving both master-read paths.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; _Tty_OutqRun - A = tty INDEX -> A = contiguous bytes available now, 0 = none.
; MX %00.  Clobbers X and Y.  `ndqb' behind the seam; see kc_ttoutq_run.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; _Tty_OutqUio - A = tty INDEX, X = uio OFFSET, Y = uio BANK -> A = errno.
; MX %00.  Clobbers X and Y.
;
; The vnode route's delivery: the queue's runs go to `uiomove' for cdevsw's
; `d_read' (apple/fgx#198).  A uio is a CURSOR, which is what packet mode needs
; -- `ptcread' writes its prefix with `ureadc(0, uio)' -- so both master-read
; paths come through this one door.
;
; A FAR POINTER IS PUSHED HIGH WORD FIRST, which is fcc's own order at every
; call site the tty bank already makes: `PEI _fcc_fpr0+2' then `PEI _fcc_fpr0'.
; Arguments go right to left, so the uio's two words precede the index.
;------------------------------------------------------------------------------
_Tty_OutqUio    ENT
                MX      %00
                PHA                             ; staged: the index
                PHX                             ; staged: uio offset
                PHY                             ; staged: uio bank
                KTTY_KC_ENTER                   ; +3 -> bank 4,S  off 6,S  idx 8,S
                LDA     4,S
                PHA                             ; arg2 HIGH: the uio's bank
                LDA     8,S
                PHA                             ; arg2 LOW:  the uio's offset
                LDA     12,S
                PHA                             ; arg1: idx
_ktp045         JSL     KTTY_KC_TTOUTQUIO       ; slot 29; A = errno
                TAY                             ; the pops below clobber A
                PLA                             ; the caller pops its arguments
                PLA
                PLA
                KTTY_KC_LEAVE
                PLA                             ; drop the three staged words
                PLA
                PLA
                TYA
                RTS

;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
_Tty_Write      ENT
                MX      %00
                PHA                             ; staged: tty index
                LDA     _Sys_CdFlag
                PHA                             ; staged: flag
                LDA     _libcTmp2+2
                PHA                             ; staged: uio-ptr BANK (low byte
                                                ;   of the word; the high half
                                                ;   is never read)
                LDA     _libcTmp2
                PHA                             ; staged: uio-ptr offset
                ; staged, from S+1:  off@1 bank@3 flag@5 idx@7
                KTTY_KC_ENTER                   ; +3:  off@4 bank@6 flag@8 idx@10
                LDA     8,S                     ; the staged flag
                PHA                             ; arg3 flag -> off@6 bank@8
                                                ;              flag@10 idx@12
                ; arg2 is a 4-byte fcc far pointer at the uio and goes on HIGH
                ; PART FIRST, so that ascending from the callee's frame it reads
                ; offset, offset, bank, pad -- where fcc looks.  vfs.s:396
                ; spells the same push out.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; pad byte  -> off@7 bank@9
                                                ;              flag@11 idx@13
                LDA     9,S                     ; the staged bank byte
                PHA                             ;           -> off@8 flag@12
                                                ;              idx@14
                REP     #$30
                MX      %00
                LDA     8,S                     ; the staged offset word
                PHA                             ;           -> flag@14 idx@16
                LDA     16,S
                PHA                             ; arg1 idx  (fcc reads
                                                ;   RIGHT-TO-LEFT, so last)
_ktp032         JSL     KTTY_KC_TTWRITE         ; slot 17
                TAY                             ; the errno; every pop below
                                                ;   clobbers A
                TSC
                CLC
                ADC     #8                      ; the caller pops its own
                TCS                             ;   arguments: 2+2+1+1+2
                KTTY_KC_LEAVE
                TSC
                CLC
                ADC     #8                      ; ...and then the four staged
                TCS                             ;   words
                TYA
                RTS

;------------------------------------------------------------------------------
; _Tty_Read - the core's call into the tty bank's READ half.  T3 stage 4.
;
; _Tty_Write's twin, argument for argument, and its header above is the one to
; read: the staging order, why every value is pushed BEFORE KTTY_KC_ENTER, and
; the silent failure that happens when _libcTmp2 is read after it instead.
; Nothing about that reasoning is different here, which is exactly why this
; routine is a copy rather than a variation.
;
; In:  A = tty index, _libcTmp2 = far pointer at the uio (built by _Sys_UioOne),
;      _Sys_CdFlag = the op's flag.
; Out: A = errno, 0 on success.  HOW MUCH WAS READ IS NOT HERE -- it is
;      u.u_ttyuio.uio_offset, which ureadc advanced as it stored.  See
;      kc_ttread (tty_dev.c) for why the subtraction that looks equivalent is not.
;------------------------------------------------------------------------------
_Tty_Read       ENT
                MX      %00
                PHA                             ; staged: tty index
                LDA     _Sys_CdFlag
                PHA                             ; staged: flag
                LDA     _libcTmp2+2
                PHA                             ; staged: uio-ptr BANK
                LDA     _libcTmp2
                PHA                             ; staged: uio-ptr offset
                ; staged, from S+1:  off@1 bank@3 flag@5 idx@7
                KTTY_KC_ENTER                   ; +3:  off@4 bank@6 flag@8 idx@10
                LDA     8,S                     ; the staged flag
                PHA                             ; arg3 flag -> off@6 bank@8
                                                ;              flag@10 idx@12
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; pad byte  -> off@7 bank@9
                                                ;              flag@11 idx@13
                LDA     9,S                     ; the staged bank byte
                PHA                             ;           -> off@8 flag@12
                                                ;              idx@14
                REP     #$30
                MX      %00
                LDA     8,S                     ; the staged offset word
                PHA                             ;           -> flag@14 idx@16
                LDA     16,S
                PHA                             ; arg1 idx  (fcc reads
                                                ;   RIGHT-TO-LEFT, so last)
_ktp034         JSL     KTTY_KC_TTREAD          ; slot 19
                TAY                             ; the errno; every pop below
                                                ;   clobbers A
                TSC
                CLC
                ADC     #8                      ; the caller pops its own
                TCS                             ;   arguments: 2+2+1+1+2
                KTTY_KC_LEAVE
                TSC
                CLC
                ADC     #8                      ; ...and then the four staged
                TCS                             ;   words
                TYA
                RTS

_Tty_Ioctl      ENT
                MX      %00
                PHA                             ; staged: tty index
                LDA     _Sys_IoctlCmd
                PHA                             ; staged: command
                LDA     _libcTmp2+2
                PHA                             ; staged: arg-ptr BANK (low byte
                                                ;   of the word; the high half
                                                ;   is never read)
                LDA     _libcTmp2
                PHA                             ; staged: arg-ptr offset
                ; staged, from S+1:  off@1 bank@3 cmd@5 idx@7
                KTTY_KC_ENTER                   ; +3:  off@4 bank@6 cmd@8 idx@10
                LDA     #TTYIO_FREAD+TTYIO_FWRITE
                PHA                             ; arg4 flag  -> off@6 bank@8
                                                ;              cmd@10 idx@12
                ; arg3 is a 4-byte fcc far pointer and goes on HIGH PART FIRST,
                ; so that ascending from the callee's frame it reads offset,
                ; offset, bank, pad -- where fcc looks.  vfs.s:396 spells the
                ; same push out.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; pad byte -> off@7 bank@9
                                                ;             cmd@11 idx@13
                LDA     9,S                     ; the staged bank byte
                PHA                             ;          -> off@8 cmd@12 idx@14
                REP     #$30
                MX      %00
                LDA     8,S                     ; the staged offset word
                PHA                             ;          -> cmd@14 idx@16
                LDA     14,S
                PHA                             ; arg2 com  -> idx@18
                LDA     18,S
                PHA                             ; arg1 idx  (fcc reads
                                                ;   RIGHT-TO-LEFT, so last)
_ktp021         JSL     KTTY_KC_TTIOCTL         ; slot 12; bank byte patched at
                                                ;   boot off the _ktp021 label
                TAY                             ; the return value; every pop
                                                ;   below clobbers A
                TSC
                CLC
                ADC     #10                     ; the caller pops its own
                TCS                             ;   arguments: 2+1+1+2+2+2
                KTTY_KC_LEAVE
                TSC
                CLC
                ADC     #8                      ; ...and then the four staged
                TCS                             ;   words
                TYA
                RTS


;------------------------------------------------------------------------------
; _Se_SetCtty - A = tty index.  Record it as _curTask's controlling terminal.
; MX %00.  Clobbers A, X, Y.  Stored as index+1 in SE_Flags bits 8-10 so 0
; keeps its meaning of "none" for every task that never opened a tty.
;------------------------------------------------------------------------------
_Se_SetCtty     ENT
                MX      %00
                AND     #$0007
                INC                             ; index+1; 0 stays "none"
                ASL     A
                ASL     A
                ASL     A
                ASL     A
                ASL     A
                ASL     A
                ASL     A
                ASL     A                       ; << SEF_CTTY_SHIFT (8)
                STA     _shTmp1
                ; Whose ctty?  _kCttyTarget when a spawn is applying file
                ; actions (the child), else _curTask.  See include/memmap.s.
                LDA     _kCttyTarget
                AND     #$00FF
                BNE     @ssc_havePid
                LDA    |_kCurPid                ; who is RUNNING, page-
                AND     #$00FF                  ;   independent.  `_curTask' is
                                                ;   a PER-PAGE identity and a
                                                ;   KSVC driver open runs on the
                                                ;   ENTERK-cached page; see
                                                ;   _Se_TtyOpenPg's note
@ssc_havePid    BEQ     @ssc_none               ; no target task (boot)
                DEC                             ; seoff = (pid-1)*32 + SE_Flags,
                ASL                             ;   the same shape _SE_PGroupOf
                ASL                             ;   uses (signal.s:333)
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_CTTY_CLEAR         ; clear the old ctty bits
                ORA     _shTmp1
                STA     [_schedTblPtr],Y
@ssc_none       RTS

;------------------------------------------------------------------------------
; _Se_TtyOpen - 2.11BSD ttyopen() for the line whose _ttyTable byte offset is
; in X.  Preserves X; clobbers A, Y.  MX %00.
;
;     if (pp->p_pgrp == 0) {          /* opener has no process group yet */
;         u.u_ttyp = tp;              /* ...the ctty binding is INSIDE here */
;         u.u_ttyd = dev;
;         if (tp->t_pgrp == 0)
;             tp->t_pgrp = pp->p_pid; /* the line gets a foreground group */
;         pp->p_pgrp = tp->t_pgrp;    /* and the opener joins it */
;     }
;                       -- examples/2.11BSD/usr/sys/sys/tty.c:653-659
;
; ONE ATOMIC ACQUISITION, WHICH IS THE WHOLE POINT (apple/fgx#60).  In BSD a
; process that ALREADY HAS a group acquires NOTHING from an open -- not the
; process group and not the controlling terminal either.  Splitting the two --
; binding the ctty unconditionally while only the pgrp half carries the guard
; -- lets a grouped process opening any tty rebind its ctty to a line it is NOT
; in the foreground group of, and `_Vc_CttyIsActive'/`_Tty_CurIsFg' then judge
; it against that line.  Splitting one BSD concept across two pieces of state
; and moving only one of them is the defect shape behind #51, #52, #55 and #57.
;
; BOTH PGRP LINES MATTER, not just the ctty binding.  The heartbeat converts ^C
; to SIGINT only for a line WITH a foreground group (toolbox.s); with none, the
; raw $03 is enqueued and the cooked discipline inserts it into the input buffer
; as an ordinary character.  Only csh/tcsh issue TIOCSPGRP, so under bsh the
; line would never acquire one by any other route.
;
; WHOSE session: _kCttyTarget when a spawn is applying file actions, else
; _curTask -- init opens the device inside the CHILD, and getting this wrong
; would put the SHELL's line under INIT's process group.
;------------------------------------------------------------------------------
; IT IS SPLIT IN TWO, AND THE SPLIT IS THE POINT.  `_Se_TtyOpenPg' below owns
; only PER-PROCESS state -- which process this open is for -- and the line's
; `t_pgrp' travels in and out through A, because the tty bank's `ttyopen' has
; its own `struct tty' and a routine that wrote the core's copy would leave the
; bank's stale.  That division is what docs/history/plans/tty-kernel-bank.md section 9 argues
; from the source: BSD's `isbackground(p, tp)' is handed the proc and owns the
; tp, which is why ttyopen is the one place the tty bank calls a core predicate
; at all.  `_Se_TtyOpen' is the core's own entry and supplies the table read
; and write.
;------------------------------------------------------------------------------
; _Se_TtyOpenPg - In:  X = tty INDEX, A = that line's CURRENT foreground pgrp.
;                 Out: A = the line's foreground pgrp AFTER the open.
;                 Preserves X.  Clobbers Y, _shTmp0, _shTmp2 (and _shTmp1 via
;                 _Se_SetCtty).  MX %00.
;
; An INDEX rather than a byte offset because both callers have one: the tty
; bank indexes `ttys[]' and the wrapper below converts.  It is also what
; _Se_SetCtty wants.
;------------------------------------------------------------------------------
_Se_TtyOpenPg   ENT
                MX      %00
                STA     _shTmp2                 ; the line's fg pgrp, in and out
                PHX                             ; tty index
                LDA     _kCttyTarget
                AND     #$00FF
                BNE     @typ_havePid
                ; `_kCurPid' AND NOT `_curTask'.  `_curTask' is a DIRECT-PAGE
                ; cell and, since the kernel page became per-task, a PER-PAGE
                ; IDENTITY: page N's copy holds N (include/memmap.s at
                ; `_kCurPid').  This arm must not depend on the page its caller
                ; happened to leave in D: on a page that is not the running
                ; task's, `_curTask' answers THAT page's number, and a zero takes
                ; the "no target task (boot)" arm below and binds NOTHING, with
                ; no error anywhere.
                ;
                ; `_kCurPid' is the split's own answer to "who is RUNNING", for
                ; callers that must ask from outside a page: @kc_curpid reads it
                ; for the same reason and @kc_curuid rebuilds the page for it.
                ; It is also upstream's question -- ttyopen's `pp = u.u_procp'
                ; is the running process (2.11BSD tty.c:652).
                LDA    |_kCurPid
                AND     #$00FF
@typ_havePid    BEQ     @typ_done               ; no target task (boot)
                STA     _shTmp0                 ; pid
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_PGroup
                TAY                             ; Y = &SE_PGroup(target)
                LDA     [_schedTblPtr],Y
                BNE     @typ_done               ; already in a group: BSD leaves
                                                ;   an existing session alone --
                                                ;   ctty included, see above
                ; --- u.u_ttyp = tp: bind the controlling terminal ---
                ; _Se_SetCtty clobbers A/X/Y (Y is our SE_PGroup cursor), so
                ; the index comes back off the stack and Y is rebuilt after.
                ; _shTmp0 and _shTmp2 survive: SetCtty uses _shTmp1.
                PLX
                PHX
                TXA                             ; A = tty index
                JSR     _Se_SetCtty
                LDA     _shTmp0
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_PGroup
                TAY                             ; Y = &SE_PGroup(target), again
                LDA     _shTmp2
                BNE     @typ_join               ; line already has a fg group
                LDA     _shTmp0                 ; ...else it becomes ours
                STA     _shTmp2
@typ_join       STA     [_schedTblPtr],Y        ; opener joins the line's group
@typ_done       PLX
                LDA     _shTmp2
                RTS

;------------------------------------------------------------------------------
; _Se_TtyOpen - the core bank's entry: X = the line's _ttyTable BYTE OFFSET.
; Preserves X; clobbers A, Y.  MX %00.  Supplies the table read and write that
; _Se_TtyOpenPg does not.
;------------------------------------------------------------------------------
_Se_TtyOpen     ENT
                MX      %00
                TXA
                JSR     _Se_TtyOffToIdx         ; A = tty index (clobbers X)
                PHA                             ; the index, for the store below
                JSR     _Tty_PgrpOf             ; A = the line's fg pgrp
                PLX                             ; X = tty index
                PHX
                JSR     _Se_TtyOpenPg           ; X = index, A = the current
                                                ;   group; out A = the group
                                                ;   after the open.  It takes an
                                                ;   INDEX and preserves X.
                TAX                             ; X = the group to record
                PLA                             ; A = tty index
                JSR     _Tty_SetPgrp
                RTS

;------------------------------------------------------------------------------
; _Se_TtyDetach - 2.11BSD TIOCNOTTY, the primitive that makes ttyopen's
; `p_pgrp == 0` guard reachable from userland (apple/fgx#60).
;
;     if (cmd == TIOCNOTTY) {
;         u.u_ttyp = 0; u.u_ttyd = 0; u.u_procp->p_pgrp = 0; return (0);
;     }
;                       -- examples/2.11BSD/usr/sys/sys/tty_tty.c:57-62
;
; This is what a session-creating daemon calls before opening the line it means
; to own; telnetd.c:266-271 is the canonical sequence -- open /dev/tty,
; TIOCNOTTY, close, THEN open the slave.  rlogind, rshd, script, uucpd and
; window all do the same.  FGX had no such primitive and got the invariant for
; free instead, because spawn handed out pgrp 0; #60 is what happens when that
; free lunch is withdrawn.
;
; SENDS NO SIGNAL and does NOT touch the LINE's t_pgrp -- BSD does neither.  The
; line's foreground group dies at its last close (ttyclose, tty.c:695-703).
;
; Target is _kCttyTarget when a spawn is applying file actions, else _curTask --
; the same choice _Se_TtyOpen makes, so that a DETACH file action detaches the
; CHILD being spawned rather than the spawner.  MX %00.  Clobbers A, X, Y.
;------------------------------------------------------------------------------
_Se_TtyDetach   ENT
                MX      %00
                LDA     _kCttyTarget
                AND     #$00FF
                BNE     @std_havePid
                LDA     _curTask
                AND     #$00FF
@std_havePid    BNE     @std_go
                RTS                             ; no target task (boot)
@std_go         DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _shTmp0                 ; seoff = (pid-1) * SE_SIZE
                ; p_pgrp = 0
                CLC
                ADC     #SE_PGroup
                TAY
                LDA     #0
                STA     [_schedTblPtr],Y
                ; u.u_ttyp = 0: clear the ctty index+1 field, leaving the rest
                ; of SE_Flags alone.
                LDA     _shTmp0
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_CTTY_CLEAR
                STA     [_schedTblPtr],Y
                RTS

;------------------------------------------------------------------------------
; _Se_CurCtty - A = _curTask's controlling tty INDEX, or $FFFF if it has none.
; MX %00.  Clobbers X, Y.
;------------------------------------------------------------------------------
_Se_CurCtty     ENT
                MX      %00
                LDA     _curTask
                AND     #$00FF
                BEQ     @scc_none
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_CTTY_MASK
                BEQ     @scc_none
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR                             ; >> SEF_CTTY_SHIFT
                DEC                             ; stored as index+1
                RTS
@scc_none       LDA     #$FFFF
                RTS

;------------------------------------------------------------------------------
; _Se_CurPgrp - A = _curTask's process group, 0 if there is no current task.
; MX %00.  Clobbers X, Y.
;
; apple/fgx#108 T3: BSD's `u.u_procp->p_pgrp' as another bank can ask for it.
; ZERO IS THE NEUTRAL ANSWER, not an error -- the same shape _Sys_GetRlimit
; takes when it has no u-area, and it lands right: a caller comparing it with
; tp->t_pgrp finds no mismatch on a line that has claimed no group either, so
; the background gate cannot fire during boot.
;------------------------------------------------------------------------------
_Se_CurPgrp     ENT
                MX      %00
                LDA     _curTask
                AND     #$00FF
                BEQ     @scp_none
                JMP     _SE_PGroupOf            ; tail call -> A = SE_PGroup
@scp_none       LDA     #0
                RTS

;------------------------------------------------------------------------------
; _Vc_CttyIsActive - may _curTask consume keystrokes right now?
;
; Out: C=1 yes, C=0 no.  MX %00.  Clobbers A, X, Y.
;
; Yes when the task has NO controlling tty (every caller that predates slice D,
; served exactly as before), or when its ctty is the console, or when its ctty
; is a virtual console that is the one on screen.
;
; A PTY CTTY IS ANSWERED NO, and that is apple/fgx#151.  "A pty's keys come
; in-band from its master, not from this ring" describes what a pty reader
; SHOULD do and is the opposite of what a yes would permit: a program on a pty
; could dequeue the PHYSICAL CONSOLE's keystrokes through SYS_GETKEY /
; SYS_POLLKEY, which take no fd.  The ptykey fixture types a key at the console
; and watches for a telnet-side program eating it.
;
; This is the choke point every consumer bottoms out at (console_kbd.s
; Con_PollKey), so one branch covers getkey, pollkey, the pipe ^C peek and the
; socket ^C peek together -- and anything added later, by construction.
;
; The callers that must not merely be starved by this answer are handled where
; they can say something better: _Sys_GetKey returns ENOTTY rather than sleeping
; forever on a ring that will never be its own, and _Sys_PollKey yields.
;------------------------------------------------------------------------------
_Vc_CttyIsActive ENT
                MX      %00
                JSR     _Se_CurCtty             ; A = ctty index, or $FFFF
                CMP     #$FFFF
                BEQ     @vca_no                 ; NO CONTROLLING TERMINAL MATCHES
                                                ;   NOTHING (apple/fgx#117).  It
                                                ;   used to resolve to VC 0, which
                                                ;   made a task with no terminal
                                                ;   the owner of the console
                                                ;   whenever VC 0 was on screen --
                                                ;   BSD never resolves a null ctty
                                                ;   to a terminal, it compares
                                                ;   `tp == u.u_ttyp' and a NULL
                                                ;   matches no tty at all
                                                ;   (2.11BSD tty.c:1157, :1348).
                                                ; That answer was DEFENSIBLE while
                                                ;   _Se_SetCtty was reached only
                                                ;   from _Ttyv_Open, so every
                                                ;   console-side task had ctty
                                                ;   "none" and a strict rule would
                                                ;   have starved the console.
                                                ;   apple/fgx#121 gave the console
                                                ;   a real /dev/console node, and
                                                ;   ctty is inherited across fork
                                                ;   and spawn (process.s:421), so
                                                ;   the tasks this leniency was
                                                ;   protecting now carry tty[0] on
                                                ;   their own account.
                                                ; Boot (_curTask=0) lands here too
                                                ;   and is answered no; Con_GetKey
                                                ;   is only ever reached from a
                                                ;   syscall handler, so there is
                                                ;   no taskless consumer to starve
                                                ;   (console_kbd.s:112).
                ; tty[0] -> VC 0, tty[3] -> VC 1, tty[4] -> VC 2, tty[6] -> VC 3;
                ; the ptys (tty[1..2]) and the serial line (tty[5]) are not
                ; this ring's keys (apple/fgx#151), and neither is anything
                ; a mapping by subtraction would have put next to a console.
                JSR     _Vc_FromTtyIdx
                BCC     @vca_no
                CMP     _kVcFocus               ; THE KEYBOARD'S console, which
                BEQ     @vca_yes                ;   the card's may be while the
@vca_no         CLC                             ;   SHR shows another
                RTS
@vca_yes        SEC
                RTS

;------------------------------------------------------------------------------
; _Vc_FromTtyIdx - A = tty index -> C=1, A = its VC index; C=0 for a line
; that is not a console.  MX %00.  The one map from tty lines to consoles
; that the key-ownership tests share; the chardev-index map is
; _Vc_FromCdIdx below.
;------------------------------------------------------------------------------
_Vc_FromTtyIdx  MX      %00
                CMP     #0
                BEQ     @vft_0
                CMP     #3
                BEQ     @vft_1
                CMP     #4
                BEQ     @vft_2
                CMP     #6
                BEQ     @vft_3
                CLC
                RTS
@vft_0          LDA     #0
                SEC
                RTS
@vft_1          LDA     #1
                SEC
                RTS
@vft_2          LDA     #2
                SEC
                RTS
@vft_3          LDA     #VC_CARD
                SEC
                RTS

;------------------------------------------------------------------------------
; _Vc_CttyNoKeys - can _curTask NEVER receive a console keystroke?
;
; Out: C=1 when its controlling terminal is a pty, or it has none at all.
;      C=0 for the console and for a virtual console.  MX %00.  Clobbers A,X,Y.
;
; _Vc_CttyIsActive answers NO to all four of those, and the callers that would
; otherwise SLEEP on the answer need them told apart: a background virtual
; console should WAIT, because its turn at the screen does come, while a pty or
; a terminal-less task is waiting for something that cannot happen.
;
; This is the strict identity predicate apple/fgx#117 asked for.  The issue
; proposed keeping a lenient answer beside it for keystroke arbitration; that
; is no longer needed, because apple/fgx#121 gave console tasks a real ctty, so
; _Vc_CttyIsActive could be made strict as well and there is now ONE rule.
;------------------------------------------------------------------------------
_Vc_CttyNoKeys  ENT
                MX      %00
                JSR     _Se_CurCtty             ; A = ctty index, or $FFFF
                CMP     #$FFFF
                BEQ     @vnk_yes                ; no controlling terminal at all
                CMP     #0                      ; tty[0] = the console
                BEQ     @vnk_no
                CMP     #3                      ; tty[1..2] = the pty slaves
                BCC     @vnk_yes
@vnk_no         CLC
                RTS
@vnk_yes        SEC
                RTS

;------------------------------------------------------------------------------
; _Vc_FromCdIdx - A = chardev idx -> which VC line is this?
;
; In:   MX %00.  A = chardev index (high byte clear).
; Out:  C=1, A = VC index (1 or 2), X = that line's _ttyTable byte offset.
;       C=0 if the chardev is not a ttyv line.  A undefined.
; Clobbers: A, X.
;
; VC n lives at tty[2+n]: tty[0] is the console, tty[1..2] are the pty slaves.
; The mapping is computed from TTY_SIZE rather than written out, so growing
; NTTY cannot leave a stale literal behind.
;------------------------------------------------------------------------------
_Vc_FromCdIdx   MX      %00
                ; The console is VC 0 (apple/fgx#121).  Answering for it here is
                ; what gives /dev/console its write bracketing, its poll and its
                ; sgtty ioctl routing -- _Io_CdThenTty's _Chardev_TtyOff,
                ; _Vc_WriteEnter and _Ttyv_Poll all ask this one question.
                CMP     _conIdx
                BEQ     @vfc_con
                CMP     _ttyvIdx0
                BEQ     @vfc_v1
                CMP     _ttyvIdx1
                BEQ     @vfc_v2
                CMP     _ttyvIdx2
                BEQ     @vfc_v3
                CLC
                RTS
@vfc_con        LDX     #0                      ; VC 0 -> tty[0]
                LDA     #0
                SEC
                RTS
@vfc_v1         LDX     #TTY_SIZE*3             ; VC 1 -> tty[3]
                LDA     #1
                SEC
                RTS
@vfc_v2         LDX     #TTY_SIZE*4             ; VC 2 -> tty[4]
                LDA     #2
                SEC
                RTS
@vfc_v3         LDX     #TTY_SIZE*6             ; VC 3 -> tty[6]
                LDA     #3
                SEC
                RTS

;------------------------------------------------------------------------------
; _Vc_WriteEnter / _Vc_WriteLeave - bracket ONE write(2) to a ttyv line.
;
; Called around a whole write, NOT by the per-byte write op: a ttyv write op
; that bracketed itself would run the 194-byte repatch loop twice per character
; -- about 160 repatches for one 80-column line.  Hoisted it is two far calls
; per write(2).
;
; _Vc_WriteEnter  preserves X and Y.
; _Vc_WriteLeave   preserves A, X, Y AND the carry -- the error exit reaches it
;                  with A = errno and C=0 to bubble up, so clobbering either
;                  would turn a failed write into a silent success.
;
; No bracket is opened when the target VC is already on screen: the live engine
; is pointing at it, so the bytes land correctly with rendering ON, which is
; what a foreground write should do.
;------------------------------------------------------------------------------
; _Vc_WriteEnter returns C=1 on success, or C=0 + A=ENOMEM when the target VC
; has no framebuffer bank and none can be had, and the caller bubbles that up
; as the write's errno.  The two alternatives are both worse: writing the bytes to
; the LIVE console would splash a background session's output across whatever
; the user is looking at, and discarding them would report a successful write
; that went nowhere.  A getty that cannot get a screen should find out.
;
; THE LINE COMES IN A, not from _Sys_WrCdIdx.  The d_write ops reached from
; `_Chardev_Bulk' are the callers, and a singleton they leave alone would
; bracket whichever line the last write(2) was for.
_Vc_WriteEnter  ENT
                MX      %00
                PHX
                PHY
                STZ     _kVcWrBracket
                STZ     _kVcWrCurs
                AND     #$00FF
                JSR     _Vc_FromCdIdx           ; -> A = VC index
                BCC     @vwe_ok                 ; not a ttyv line: nothing to do
                CMP     _kVcActive
                BEQ     @vwe_curs               ; already on screen: no bank bracket
                                                ;   -- but the cursor still has to
                                                ;   come down, see @vwe_curs
                PHA                             ; target VC
                JSR     _Vc_EnsureBank          ; FIRST WRITE allocates here
                BCS     @vwe_haveBank
                PLA                             ; drop the saved VC
                LDA     #ENOMEM
                PLY
                PLX
                CLC
                RTS
@vwe_haveBank   TAX                             ; X = target bank
                PLA                             ; A = target VC
                PHA
                INC
                STA     _kVcWrBracket           ; VC + 1, so 0 stays "none"
                PLA
                LDY     _kVcActive              ; Y = outgoing VC
_kfp333         JSL     KFAR_CON_ENTERVC
@vwe_curs       ; TAKE THE BLOCK CURSOR DOWN before the bytes land, and put it
                ; back after.  Without the pair a getty writes its prompt and
                ; blocks in read() having never drawn a cursor.  The echo path
                ; (`kc_cdwrite', far_shims.s `_FarSh_CdWrite') carries the same
                ; hide/show pair.
                ;
                ; AFTER the ENTERVC above, never before: Con_EnterVC swaps the live
                ; console state to the target VC, so hiding first would take the
                ; cursor down in the OUTGOING console and leave this one's rendered
                ; flag set -- which then makes the re-show a silent no-op, because
                ; Con_ShowCursor is idempotent on VT_CURS_RENDERED.
                LDA     #1
                STA     _kVcWrCurs
_kfp337         JSL     KFAR_CON_HIDECURSOR
                ; AND LET THE WRITE'S FULL-SCREEN SCROLLS BE COUNTED, the pixels
                ; moving once when it ends (console_scroll.s Con_WriteArm).
_kfp1016        JSL     KFAR_CON_WRARM
@vwe_ok         PLY
                PLX
                SEC
                RTS

;------------------------------------------------------------------------------
_Vc_WriteLeave  ENT
                MX      %00
                PHP                             ; carry = the write's verdict
                PHA                             ; A = errno on the failure path
                PHX
                PHY
                ; Put the cursor back BEFORE any LeaveVC below, so it is drawn
                ; into the console the write went to rather than the one we are
                ; about to switch back to.  For a background VC that render is
                ; suppressed by the open bracket and only updates its AttrBuf,
                ; which is what makes the cursor correct the moment it is
                ; switched to.
                LDA     _kVcWrCurs
                BEQ     @vwl_noCurs
                STZ     _kVcWrCurs
_kfp1017        JSL     KFAR_CON_WRDONE         ; the scrolls it counted, drawn
_kfp338         JSL     KFAR_CON_SHOWCURSOR
@vwl_noCurs     LDA     _kVcWrBracket
                BEQ     @vwl_done
                DEC                             ; A = the VC we bracketed
                TAY                             ; Y = target VC (to save)
                STZ     _kVcWrBracket
                LDA     _kVcActive
                AND     #$00FF
                ASL     A
                TAX
                LDA     _kVcBank,X              ; active VC's bank
                AND     #$00FF
                TAX
                LDA     _kVcActive
                AND     #$00FF
_kfp334         JSL     KFAR_CON_LEAVEVC
@vwl_done       PLY
                PLX
                PLA
                PLP
                RTS

;------------------------------------------------------------------------------
; _Vc_EchoEnter / _Vc_EchoLeave - point the console engine at the line
; `_Sys_WrCdIdx' names for one run of the discipline's output, and put it back.
;
; Called by `_FarSh_CdWrite' around its byte loop, and by nothing else.  A
; write(2) to a VC line arrives there inside `_Vc_WriteEnter's bracket, so the
; engine already describes that line's console and this pair does nothing.
; The discipline's OWN output does not: the echo of a keystroke is queued at
; arrival time and drained at a soft site, and the keyboard can be on a
; console the SHR screen is not showing -- the card's, after Option-4 -- so
; the echo of a name typed at the card's login prompt would land in the ring
; of whichever console the engine was describing, and be painted there.
;
; THE ENGINE IS RETURNED TO THE CONSOLE IT WAS FOUND ON, which is the
; bracketed VC when a write is in flight (a task asleep in `ttwrite' holds
; its bracket open) and the active VC otherwise.  Which far routine makes
; each hop follows from that: `Con_EnterVC' saves the live render state and
; suppresses rendering for a console that is not on screen, `Con_LeaveVC'
; restores that saved state -- so with no bracket open the hop out is an
; Enter and the hop back a Leave, and with one open the hop out is a Leave
; (the line's console gets the state the bracket saved, and the card's
; console renders live either way) and the hop back an Enter, which saves it
; again for the bracket's own Leave.  Nothing here touches `_kVcWrBracket'.
;
; A line whose VC has no bank yet is left alone: only a console that has
; been written to can hold the keyboard (`_Vc_DrainSwitch' refuses the
; switch otherwise), so this is the console's and the ptys' road, not an
; error.  MX %00.  Clobbers A, X, Y.
;------------------------------------------------------------------------------
_Vc_EchoEnter   ENT
                MX      %00
                STZ     _kVcEchoFrom
                LDA     _Sys_WrCdIdx
                AND     #$00FF
                JSR     _Vc_FromCdIdx           ; A = the line's VC
                BCC     @vee_done               ; not a VC line
                PHA                             ; 3,S below: the line's VC
                LDA     _kVcWrBracket           ; the engine's console + 1:
                BNE     @vee_haveCur            ;   the bracketed VC, else
                LDA     _kVcActive              ;   the active one
                INC
@vee_haveCur    PHA                             ; 1,S: cur + 1
                DEC
                CMP     3,S
                BEQ     @vee_same               ; already pointed at it
                LDA     3,S
                ASL     A
                TAX
                LDA     _kVcBank,X
                AND     #$00FF
                BEQ     @vee_same               ; no bank: nowhere to point
                TAX                             ; X = the line's bank
                LDA     1,S
                STA     _kVcEchoFrom            ; cur + 1: a hop is open
                DEC
                TAY                             ; Y = cur, the console to save
                LDA     _kVcWrBracket
                BNE     @vee_leaveTo
                LDA     3,S                     ; A = the line's VC
_kfp962         JSL     KFAR_CON_ENTERVC        ; no bracket: an Enter out
                BRA     @vee_same
@vee_leaveTo    LDA     3,S                     ; A = the line's VC
_kfp963         JSL     KFAR_CON_LEAVEVC        ; a bracket is open: a Leave out
@vee_same       PLA
                PLA
@vee_done       RTS

_Vc_EchoLeave   ENT
                MX      %00
                LDA     _kVcEchoFrom
                BEQ     @vel_done               ; no hop was made
                STZ     _kVcEchoFrom
                DEC
                PHA                             ; 1,S: cur, the console to return to
                LDA     _Sys_WrCdIdx
                AND     #$00FF
                JSR     _Vc_FromCdIdx           ; A = the line's VC (it was one)
                TAY                             ; Y = the line's VC, to save
                LDA     1,S
                ASL     A
                TAX
                LDA     _kVcBank,X
                AND     #$00FF
                TAX                             ; X = cur's bank
                LDA     _kVcWrBracket
                BNE     @vel_enterBack
                LDA     1,S                     ; A = cur, the active VC
_kfp967         JSL     KFAR_CON_LEAVEVC        ; no bracket: a Leave back
                BRA     @vel_pop
@vel_enterBack  LDA     1,S                     ; A = cur, the bracketed VC
_kfp969         JSL     KFAR_CON_ENTERVC        ; a bracket is open: an Enter back
@vel_pop        PLA
@vel_done       RTS

;------------------------------------------------------------------------------
; _Vc_EnsureBank - A = VC index.  Return that VC's framebuffer bank, allocating
; it on first use.
;
; In:   MX %00.  A = VC index (0..NVC-1); high byte MUST be clear.
; Out:  C=1, A = bank number (never 0).
;       C=0, A = ENOMEM -- the user bank pool is exhausted.  The registry entry
;            is left 0, so a later call retries rather than caching a failure.
; Clobbers: A, X, Y.
;
; LAZY, AND THE TRIGGER IS FIRST WRITE (2026-08-05).  Not first switch:
; once /etc/ttys turns the ttyv lines `on`, every getty writes its prompt within
; seconds of boot, long before a user switches to it.  First-switch would
; therefore allocate at boot anyway while looking lazy in the code -- the worst
; of both.  First-write allocates exactly when the line genuinely starts
; existing, and a line left `off` never costs a bank at all.
;
; A VC bank is 64 KB out of a 24-bank user pool that co-resident binaries are
; already competing for (apple/fgx#37: each holds a private libc bank since the
; archive conversion).  Failing here is therefore a REAL outcome, not a
; theoretical one, which is why this returns a status instead of halting.
;------------------------------------------------------------------------------
; _Vc_RdTtyIsActive - is the tty currently being read (_kTtyRdPtr) the one whose
; VC is on screen?  C=1 yes (or not a VC line at all -- the console and the ptys
; are unaffected), C=0 no.  MX %00.  Preserves A, X, Y.
;
; Compares ADDRESSES rather than indices because _kTtyRdPtr is what the read
; discipline actually dereferences; deriving an index would add a mapping that
; could drift from the one in _Vc_FromCdIdx.
_Vc_RdTtyIsActive ENT
                MX      %00
                PHA
                PHX
                LDA     _kTtyRdPtr
                CMP     #_ttyTable               ; tty[0] IS VC 0 -- gate it too
                BEQ     @vra_vc0
                CMP     #_ttyTable+{TTY_SIZE*3}   ; ttyv1?
                BEQ     @vra_vc1
                CMP     #_ttyTable+{TTY_SIZE*4}   ; ttyv2?
                BEQ     @vra_vc2
                CMP     #_ttyTable+{TTY_SIZE*6}   ; ttyv3, the card's?
                BEQ     @vra_vc3
                PLX                             ; a pty: always allowed, its keys
                PLA                             ;   arrive in-band from the master
                SEC                             ;   and never touch this ring
                RTS
@vra_vc0        LDX     #0                      ; THE CONSOLE MUST WAIT ITS TURN.
                BRA     @vra_cmp                ;   Gating only the ttyv lines
@vra_vc1        LDX     #1                      ;   left tty[0]'s shell reading
                BRA     @vra_cmp                ;   the ring while a DIFFERENT
@vra_vc2        LDX     #2                      ;   console had the keys -- so
                BRA     @vra_cmp
@vra_vc3        LDX     #VC_CARD
@vra_cmp        CPX     _kVcFocus               ; the console the keyboard feeds
                BEQ     @vra_yes
                PLX
                PLA
                CLC
                RTS
@vra_yes        PLX
                PLA
                SEC
                RTS

_Vc_EnsureBank  ENT
                MX      %00
                AND     #$00FF
                ASL     A                       ; word index into _kVcBank
                TAX
                LDA     _kVcBank,X
                AND     #$00FF
                BEQ     @veb_alloc
                SEC                             ; already allocated
                RTS
@veb_alloc      PHX                             ; Bank_Alloc clobbers X
                JSR     Bank_Alloc              ; -> C=1, A.lo = bank
                PLX
                BCC     @veb_fail
                AND     #$00FF
                STA     _kVcBank,X
                SEC                             ; A.lo = the bank, for the caller
                RTS
@veb_fail       LDA     #ENOMEM                 ; entry stays 0 -> a later write
                CLC                             ;   retries; a cached failure
                RTS                             ;   would be permanent

;------------------------------------------------------------------------------
; _Con_DrainRestore - repaint the console a desk accessory left, if asked.
;
; In:   MX %00, DBR = kernel bank.  Called from the same safe points as
;       _Vc_DrainSwitch.
; Out:  Clobbers A.  X and Y are kept.
;
; A classic desk accessory may draw on Super Hi-Res and leave it as it drew it:
; DocVue leaves SCB 0 and palette 0 all zero and its own pixels in the frame
; buffer (measured), so the console keeps rendering text nobody can see.
; cda.mod's RestAll hook sets _kConRestoreReq as the menu closes; the menu runs
; inside an interrupt, where the console engine may be part-way through a
; write, so the restore -- SCBs, palettes, every row -- waits for a safe point.
; It is the release half of SYS_SCREEN_CTL (_Sys_ScreenCtl).  While a task owns
; the screen its pixels are in no CharBuf, so the request is dropped.
;------------------------------------------------------------------------------
_Con_DrainRestore ENT
                MX      %00
                LDA     _kConRestoreReq
                BNE     @cdr_have
                RTS
@cdr_have       STZ     _kConRestoreReq
                LDA     _screenOwner
                BNE     @cdr_done
                LDA     _kFarReady              ; the console is in the far bank
                BEQ     @cdr_done
                PHX
                PHY
_kfp364         JSL     KFAR_CON_INITSCBS       ; SCBs back to the mode's template
_kfp365         JSL     KFAR_CON_INSTALLPALETTES ; the console palettes
_kfp366         JSL     KFAR_CON_RENDERALL      ; every row from the CharBuf
                PLY
                PLX
@cdr_done       RTS

;------------------------------------------------------------------------------
; _Vc_DrainSwitch - perform a pending VC switch, if one was requested.
;
; In:   MX %00.  Called from a SAFE POINT only (a kernel-DP context that is not
;       inside the console engine), never from the heartbeat.
; Out:  C=1 if a switch happened, C=0 if there was nothing to do or it was
;       refused.  Clobbers A, X, Y.
;
; DETECTION AND EXECUTION ARE DIFFERENT PROBLEMS.  Alt-N is noticed in the
; keyboard ISR, which only ever SETS _kVcSwitchReq; the switch itself rewrites
; 97 bank operands and swaps ~108 B of console state, so running it where it is
; noticed would let a task be preempted mid-rewrite and resume reading a torn
; console -- the wrong-bank smear of #20/!58.  This is the same shape as
; _kTtySigPend, drained a few lines away in _Sys_CheckSignal.
;
; REFUSES while a task owns the physical screen.  SYS_SCREEN_CTL lets a task
; claim SHR directly (_screenOwner, syscall.s:696-745); such a task's pixels are
; in no CharBuf, so switching away and back could not restore them, and
; _conRenderState 3 means SUSPENDED rather than a pending scroll.  The request
; is DROPPED rather than deferred: holding it would fire the switch at an
; arbitrary later moment the user no longer associates with their keystroke.
; _Exit_Core auto-releases the claim (process.s:1371,2319), so this cannot wedge.
;------------------------------------------------------------------------------
_Vc_DrainSwitch ENT
                MX      %00
                LDA     _kVcSwitchReq
                BNE     @vds_have
                CLC                             ; nothing pending: the common
                RTS                             ;   path is one LDA + branch
                ; The BODY preserves X and Y.  The caller is _Sys_CheckSignal,
                ; mid-way through its own register use, and this path has never
                ; executed until alt-N lands in task 4 -- so a clobber here
                ; would first appear as a signal-delivery bug at the moment the
                ; first switch fires, with nothing pointing back to this
                ; routine.  The save is on the switch path only; the common
                ; "nothing pending" exit above touches A alone.
@vds_have       PHX
                PHY
                STZ     _kVcSwitchReq           ; consume it either way
                LDX     _screenOwner
                BEQ     @vds_go
                BRA     @vds_refuse             ; a task owns SHR -> drop it
@vds_go         DEC                             ; stored as index+1 so 0 = none
                AND     #$00FF
                PHA                             ; incoming VC
                ; ONLY SWITCH TO A CONSOLE THAT EXISTS.  This used to call
                ; _Vc_EnsureBank, which ALLOCATES on demand -- so Option-N for a
                ; line that /etc/ttys ships `off` handed the user a brand-new
                ; bank full of the previous owner's memory and painted it.  On
                ; screen that is a wall of coloured garbage (Option-3 with
                ; ttyv2 off).
                ;
                ; A live console has a bank because its getty wrote a prompt;
                ; the first-write allocation IS the session's existence proof.
                ; So testing _kVcBank[N] tracks the number of lines actually on,
                ; without the kernel needing to know anything about /etc/ttys --
                ; turn a line on and its console becomes reachable the moment it
                ; prints, turn it off and Option-N for it is inert.
                ;
                ; VC 0 always has one (the boot console), so the physical
                ; console can never become unreachable this way.
                ASL     A                       ; word index into _kVcBank
                TAX
                LDA     _kVcBank,X
                AND     #$00FF
                BEQ     @vds_dropRefuse         ; no session on that line
                TAX                             ; X = incoming bank
                BRA     @vds_haveBank
@vds_dropRefuse PLA                             ; drop the saved VC
                BRA     @vds_refuse
@vds_haveBank
                PLA                             ; A = incoming VC
                PHA
                ; THE CARD'S CONSOLE HAS A DISPLAY OF ITS OWN.  While sscon.mod
                ; has a card for VC_CARD, Option-4 hands it the keyboard and
                ; leaves the SHR on the console it shows: the card keeps
                ; rendering VC_CARD through the write bracket whether or not
                ; it has the keys, so there is nothing to switch.  Without a
                ; card VC_CARD is a fourth SHR console and switches like the
                ; rest.
                CMP     #VC_CARD
                BNE     @vds_shr
                LDY     _kVcCard                ; (X holds the incoming bank)
                BEQ     @vds_shr
                PLA
                STA     _kVcFocus               ; the keys, and nothing else
                BRA     @vds_logged
@vds_shr        LDY     _kVcActive              ; Y = outgoing VC
_kfp335         JSL     KFAR_CON_SWITCHVC
                PLA
                STA     _kVcActive              ; only after it succeeded
                STA     _kVcFocus               ; the SHR's console has the keys
@vds_logged
                JSR     _Vc_FocusBorder         ; the border names the console
                                                ;   that has the keys now
                PLY
                PLX
                SEC
                RTS
@vds_refuse     PLY
                PLX
                CLC
                RTS

;------------------------------------------------------------------------------
; _Tty_DrainOutPend - restart output the interrupt-time discipline deferred.
; apple/fgx#108 T6 increment 4b.
;
; THE PERFORM HALF OF THE OUTPUT RAIL.  `ttyinput' running in the heartbeat
; fills `t_outq' and marks the line TS_TIMEOUT rather than calling `t_oproc',
; because a chardev dispatch cannot run at interrupt time -- `_Chardev_Dispatch'
; self-modifies one shared five-byte JSL cell whose critical region runs through
; the device call (chardev.s:501, memmap.s:1772) -- and because FGX's console
; `t_oproc' PAINTS THE SCREEN, which is not a thing to do inside a VBL handler
; even if it were re-entrant.  This is where the paint happens instead.
;
; UPSTREAM'S SHAPE, NOT AN FGX INVENTION.  `dzstart' hands its run to the silo
; and returns; 2.11BSD's own deferral bit is TS_TIMEOUT and its own restart
; routine is `ttrstrt' -- `t_state &= ~TS_TIMEOUT; ttstart(tp)' -- reached
; through `timeout()'.  `ttrstrt' has been ported and CALLER-LESS in this tree
; since T3 (tty.c:251, which says so).  This gives it the caller.
;
; TWO SITES CALL IT, the two `_Tty_DrainSigPend' already uses: `_Sys_CheckSignal'
; and swtch's idle loop.  BOTH ARE NEEDED, and the idle one is not a belt-and-
; braces: a COOKED line wakes its reader on a LINE DELIMITER, so between the
; first keystroke and Enter there may be no syscall at all, and echo would
; arrive in a burst when the line was submitted.
;
; ENTERING C FROM THE IDLE LOOP IS SAFE, and signal.s says otherwise about
; `_kTtyFlushPend' -- "one of that routine's two callers is the swtch idle loop,
; where entering the shared kernel-C register file is not safe".  THAT COMMENT
; PREDATES apple/fgx#204.  `_KcDp_Save' (sched.s:297) is unconditional now and
; runs before the pick; `_KcDp_Rest' (:390) runs only on the pick's success
; path; and the idle arm `@sw_none' (:435) sits between them and re-enters
; `@sw_pick' when it is done.  So the shared band belongs to nobody there: the
; outgoing task's copy is already in its slot and no incoming task's has been
; restored.  The comment is left alone on purpose -- it is about a different
; cell and its own claim is not re-measured here.
;
; THE SUMMARY IS CLEARED FIRST AND THE BANK ASKED SECOND, which is the ordering
; `_kTtySigAny' spells out: the heartbeat can fire mid-drain, and clearing last
; would drop a mark set inside the window.  Clearing first costs at worst one
; extra scan that finds nothing.
;
; Clobbers A/X/Y.  MX %00.  Kernel-DP contexts only.
;------------------------------------------------------------------------------
_Tty_DrainOutPend MX    %00
                LDA     _kTtyOutAny
                BNE     @tdop_go
                RTS                             ; the common path: one BEQ
@tdop_go        STZ     _kTtyOutAny             ; FIRST -- see above
                LDA     _kTtyReady              ; no bank, nothing to drain
                BNE     @tdop_call
                RTS
@tdop_call      KTTY_KC_ENTER                   ; the ORDINARY bracket: this is
                                                ;   task context, not the ISR
_ktp054         JSL     KTTY_KC_TTDRAIN         ; slot 39; A = lines restarted
                KTTY_KC_LEAVE
                RTS
