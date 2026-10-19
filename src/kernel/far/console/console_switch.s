;==============================================================================
; console_switch.s - virtual console state save/load (slice D task 2).
;
; Public (far bank, DBR = far bank on entry):
;   Con_SaveVCState   A = VC index (0..NVC-1).  Live console state -> block.
;   Con_LoadVCState   A = VC index (0..NVC-1).  Block -> live console state.
;
; These move the flat per-VC image defined in far.s (CON_VC_STATE, VCS_*).
; They do NOT repatch the framebuffer bank and do NOT repaint -- Con_SwitchVC
; sequences those around them.  Kept separate because the save half runs while
; the OUTGOING console is still live and the load half while the INCOMING one
; is not yet on screen; fusing them would hide that asymmetry.
;
; TWO REGIONS, ONE ADDRESS SPACE.  VCS_VT and VCS_ALT are both far-bank to
; far-bank, so absolute-indexed moves reach them with DBR already set and the
; whole routine is two symmetric copy loops each way.
;
; NOT ISR-SAFE.  See Con_RepatchBank's header: the console engine must be
; quiescent across a switch, which is why the request is drained at a safe
; point rather than executed where it is detected.
;==============================================================================

; THERE USED TO BE A THIRD REGION, AND IT IS WORTH KNOWING WHY IT IS GONE.
;
; The console's live scalars -- cursor, viewport, colour -- were direct-page
; cells at $C0..$CF, an address space no DBR-relative access from this bank can
; touch, so they needed a copy loop of their own with its own addressing mode.
; They now live in CON_VT_STATE at $4A..$59 (include/console.s) and ride the
; VCS_VT copy like everything else.  The region, the loop and the mode are all
; deleted.
;
; The loop was worth deleting on its history alone.  The first cut wrote
; `LDAL $0000C0,X`, reasoning that the direct page is bank 0 and _conWritePtr
; sits at offset $C0.  That is wrong: D was $B700 at runtime, so the scalars
; lived at $00:B7C0 and $00:00C0 was unrelated memory.  Every save and load
; silently operated on the wrong 16 bytes -- the console kept working only
; because nothing was ever really saved OR restored, so the live state just
; persisted.  It surfaced the moment something legitimately changed the cursor
; (Con_Clear homing it on a fresh VC) and the restore failed to put it back.
;
; The ERR guard meant to catch that compared CON_VC_DPBASE against _conWritePtr
; and passed -- because _conWritePtr was a DUM 0 OFFSET, not an address.  It was
; comparing the constant to itself.  A guard that cannot fail is worse than
; none: it reads as proof.
;
; Both failures needed a datum to be in the direct page to be possible at all.
; Moving it out is what retires them, rather than a better guard over the same
; shape.

;------------------------------------------------------------------------------
; Con_SwitchVC - make VC A the on-screen console.
;
; In:   MX %00.  A = incoming VC index (high byte clear), X = its framebuffer
;       bank (the CORE side owns Bank_Alloc, so it passes the bank in rather
;       than this routine reaching across for it).  Y = outgoing VC index.
; Out:  screen shows the incoming VC.  Clobbers A, X, Y.
;
; MUST NOT RUN IN AN ISR.  The caller is the drain point, not the detector --
; see _kVcSwitchReq in include/memmap.s.  Between the repatch and the repaint
; the console engine's operands point at the incoming bank while the DP scalars
; may still describe the outgoing one, so a task preempted here and resumed
; inside the engine would read a torn console.  That is the wrong-bank smear of
; #20/!58, which cost two sessions.
;
; ORDER IS LOAD-BEARING, and this is the whole routine:
;
;   1. save outgoing state   -- while its DP scalars are still the live ones
;   2. repatch to the new bank -- Con_RepatchBank; also updates _kConsoleBank
;   3. load incoming state   -- its scalars now describe the newly-pointed bank
;   4. repaint               -- Con_RenderAll, from the incoming CharBuf
;
; Save before repatch (1 before 2) because the save reads DP scalars that
; describe the OUTGOING screen.  Load after repatch (3 after 2) because the
; loaded scalars are only meaningful once the operands address the incoming
; bank.  Repaint last, because it is the only step that touches the visible
; screen and everything it reads must already be consistent.
;------------------------------------------------------------------------------
Con_SwitchVC    ENT
                MX      %00
                PHX                             ; incoming bank
                PHA                             ; incoming VC
                TYA
                AND     #$00FF
                JSR     Con_SaveVCState         ; 1: outgoing, still live
                PLA                             ; incoming VC
                PLX                             ; incoming bank
                PHA
                TXA
                AND     #$00FF
                JSR     Con_RepatchBank         ; 2: operands + _kConsoleBank
                PLA                             ; incoming VC
                JSR     Con_LoadVCState         ; 3: now meaningful
                JSR     Con_RenderAll           ; 4: visible screen last
                RTS

;------------------------------------------------------------------------------
; Con_EnterVC / Con_LeaveVC - bracket a write to a NON-ACTIVE virtual console.
;
; Con_EnterVC   A = target VC, X = target bank, Y = active VC.
; Con_LeaveVC   A = active VC, X = active bank, Y = target VC.
;
; Between them the console engine is pointed at the target VC with rendering
; suppressed, so ordinary Con_Write calls land in the target's CharBuf/AttrBuf
; and the visible screen never changes.  The caller writes its whole buffer
; inside the bracket: this is TWO far calls per write(2), not per byte, which
; is the difference between a repatch amortised over a line of output and one
; paid 80 times for it.
;
; Suppression is _conRenderState = 3, the same value SYS_SCREEN_CTL uses --
; Con_RenderRow skips all pixel work at >= 2.  Set AFTER Con_LoadVCState,
; which forces it to 0; see the note there on why it is never restored from
; the block.
;
; Con_LeaveVC saves the target's state FIRST.  Its cursor moved, its parser may
; be mid-sequence, and all of that has to persist for the next write to the
; same line -- dropping it would make every background write start from
; whatever the previous one left in the shared engine.
;
; NOT ISR-SAFE and NOT REENTRANT, for the same reason as Con_SwitchVC: between
; the two calls the engine describes a console that is not on screen.
;------------------------------------------------------------------------------
Con_EnterVC     ENT
                MX      %00
                ; REMEMBER THE PIPELINE STATE THIS BRACKET IS ABOUT TO TAKE OVER.
                ; Con_LeaveVC's Con_LoadVCState forces VT_RENDER_STATE to 0, so
                ; every bracket used to END with rendering live no matter what it
                ; STARTED with -- including a 3 that a task holding the physical
                ; screen had installed with SYS_SCREEN_CTL.  Its pixels are in no
                ; CharBuf, so once rendering came back the console painted over
                ; them, and there was nothing left to restore the 3 from:
                ; VT_RENDER_STATE sits past VCS_VT_LEN, so no VC block carries it.
                ;
                ; The switch path already refuses outright while an owner is set
                ; (_Vc_DrainSwitch, ttyv.s); this is the BRACKETED write path
                ; being held to the same rule, except that a write can be
                ; honoured rather than refused -- the bytes belong in the
                ; target's CharBuf either way, and suppressed is exactly where
                ; the pipeline should stay.
                ;
                ; ONLY THE BRACKETED PATH.  When VC 0 is the active console an
                ; ordinary console write is not bracketed, and does not come
                ; through here (apple/fgx#136).
                ;
                ; Saved for ALL values, not just 3: putting back what was there
                ; is both simpler and more faithful than special-casing the
                ; suspension (apple/fgx#135).
                PHA                             ; A IS THE TARGET VC and the read
                SEP     #$20                    ;   below clobbers it
                MX      %10
                LDA    |CON_VT_STATE+VT_RENDER_STATE
                STA    |CON_VT_STATE+VT_BRACKET_RENDER
                REP     #$30
                MX      %00
                PLA
                PHX                             ; target bank
                PHA                             ; target VC
                TYA
                AND     #$00FF
                PHA                             ; active VC, needed again below
                JSR     Con_SaveVCState         ; active VC, still live
                PLY                             ; Y = active VC
                PLA                             ; A = target VC
                PLX                             ; X = target bank
                PHA
                PHY
                TXA
                AND     #$00FF
                JSR     Con_RepatchBank         ; operands -> target bank
                PLY                             ; active VC
                PLA                             ; target VC
                JSR     _Con_VCFirstUse         ; seed a virgin block, C=1 if we
                PHP                             ;   just did (needs a clear)
                JSR     Con_LoadVCState         ; forces renderState 0 ...
                ; Suppress BEFORE any clear.  Con_Clear repaints, and this VC is
                ; not on screen: with rendering live it would wipe and redraw the
                ; console the user is actually looking at, which is the exact
                ; leak this whole bracket exists to prevent.  It is also the
                ; expensive path -- a full-screen clear plus 25 rows of pixel
                ; work -- for a buffer nobody can see.
                ;
                ; UNLESS THE TARGET HAS A DISPLAY OF ITS OWN.  Con_LoadVCState
                ; has just set _conBackendOn for the card's console, whose
                ; every write should reach the card whether or not it has the
                ; keyboard; rendering stays live for it, and the render sites
                ; send the pixels to the card rather than the SHR.
                BIT    |_conBackendOn
                BMI     @cev_ownDisplay
                SEP     #$20
                MX      %10
                LDA     #3                      ; ... and we opt straight back
                STA    |CON_VT_STATE+VT_RENDER_STATE
                REP     #$30
                MX      %00
@cev_ownDisplay PLP
                BCC     @cev_haveState
                ; FRESH BANK: fill the VC's OWN buffers, and note which routines
                ; do that.  NOT Con_Clear -- it MVNs bank $01, the SHR PIXEL
                ; framebuffer at a fixed address, which is neither this VC's
                ; CharBuf nor even in its bank.  On a background VC that wiped
                ; the screen the user was looking at while leaving the VC's
                ; buffer full of whatever the previous owner of the bank left
                ; behind: raw 65816 code, in the run that exposed this.
                ;
                ; _Con_FillCharBuf and _Con_FillAttrBuf move through the PATCHED
                ; operands, so after Con_RepatchBank above they land in this VC's
                ; bank -- which is the whole point.
                JSR     _Con_FillCharBuf
                JSR     _Con_FillAttrBuf
                ; HOME THE CURSOR.  _Con_VCFirstUse seeds a virgin block from
                ; the LIVE console's state -- deliberately, so the VC inherits
                ; real geometry and mode rather than a second set of defaults --
                ; and its header states the contract: "The cursor position comes
                ; along too and is immediately reset by the caller's Con_Clear."
                ; 822b3c13b replaced Con_Clear (which wrongly MVN'd the bank-$01
                ; PIXEL framebuffer) with the two buffer fills above, and lost
                ; the homing that Con_Clear's tail performed.
                ;
                ; The cost was invisible rather than fatal: the console has
                ; scrolled through boot and /etc/rc by the time init's VC line
                ; first writes, so a fresh VC inherited a cursor deep in the ring
                ; and every session's first output landed there.  bsh's prompt
                ; was found at row 16 of an otherwise blank-looking buffer.
                LDA     #0
                STA    |CON_VT_STATE+VT_CUR_ROW
                STA    |CON_VT_STATE+VT_CUR_COL
                STA    |CON_VT_STATE+VT_TOP_ROW
                SEP     #$20
                MX      %10
                STA     CON_VT_STATE+VT_PENDING_WRAP
                REP     #$30
                MX      %00
                ; Both end in MVN, and MVN LEAVES DBR ON THE DESTINATION BANK.
                ; They do carry _DBRK, but restore DBR here anyway rather than
                ; depending on a callee's internals: this is the #20/!58 class,
                ; and it cost two sessions because the damage lands far from the
                ; move.
                PHK
                PLB
@cev_haveState  RTS

;------------------------------------------------------------------------------
; _Con_VCFirstUse - give a never-used VC block a valid console state.
;
; In:   MX %00.  A = target VC, Y = active VC (whose block was JUST saved and
;       therefore holds a live, valid state).  A is preserved.
; Out:  C=1 if the block was virgin and has now been seeded (the caller must
;       clear the framebuffer), C=0 if it already held a state.
;
; A ZEROED BLOCK IS NOT A VALID CONSOLE.  Con_Init zeroes CON_VC_STATE at boot,
; so a VC that has never been entered would load VT_SR_TOP = VT_SR_BOT = 0, no
; autowrap, no tab stops and a null write pointer.  Loading that and then
; writing wedged the machine hard: the first newline scrolled against a
; degenerate scroll region and never came back, taking the console with it --
; no panic, no BRK, just a live kernel writing to a screen nobody could see.
;
; Seeding from the ACTIVE VC's block is what makes this cheap and correct: it
; was saved moments ago, so it carries the real geometry, mode, palette and tab
; stops rather than a second hand-maintained set of defaults that could drift
; from Con_Init's.  The cursor position comes along too and is immediately
; reset by the caller's Con_Clear.
;------------------------------------------------------------------------------
_Con_VCFirstUse MX      %00
                PHA                             ; target VC
                JSR     _Con_VCBlockOff
                TAX                             ; X = target block base
                LDA     CON_VC_STATE+VCS_INIT_FLAG,X
                AND     #$00FF
                BEQ     @cfu_virgin
                PLA
                CLC                             ; already has a state
                RTS
@cfu_virgin     PHX                             ; target base
                TYA
                AND     #$00FF
                JSR     _Con_VCBlockOff
                TAY                             ; Y = active block base
                PLX                             ; X = target base
                PHX
                LDA     #0
@cfu_copy       PHA
                LDA     CON_VC_STATE,Y
                STA     CON_VC_STATE,X
                INX
                INX
                INY
                INY
                PLA
                INC
                INC
                CMP     #VCS_USED
                BCC     @cfu_copy
                PLX                             ; target base
                LDA     #1
                STA     CON_VC_STATE+VCS_INIT_FLAG,X
                PLA                             ; target VC
                SEC                             ; seeded -> caller clears
                RTS

Con_LeaveVC     ENT
                MX      %00
                PHX                             ; active bank
                PHA                             ; active VC
                TYA
                AND     #$00FF
                JSR     Con_SaveVCState         ; target: cursor + parser state
                PLA
                PLX
                PHA
                TXA
                AND     #$00FF
                JSR     Con_RepatchBank         ; operands -> active bank
                PLA
                JSR     Con_LoadVCState         ; forces renderState to 0 ...
                SEP     #$20
                MX      %10
                LDA    |CON_VT_STATE+VT_BRACKET_RENDER
                STA    |CON_VT_STATE+VT_RENDER_STATE   ; ... put back what the
                REP     #$30                            ;     bracket found
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Con_VCBlockOff - A = VC index -> A = byte offset of its block.
; In/Out MX %00.  A's high byte MUST be clear on entry.  Clobbers nothing else.
;
; No bounds check: both callers are internal and pass a validated index.  If
; that ever stops being true this is where the check goes, not at the copies.
;------------------------------------------------------------------------------
_Con_VCBlockOff MX      %00
                ; offset = idx * VCS_SIZE, and VCS_SIZE is $80 precisely so
                ; this is a shift run with nothing to check.  See far.s.
                ASL     A                       ; idx*2
                ASL     A                       ; *4
                ASL     A                       ; *8
                ASL     A                       ; *16
                ASL     A                       ; *32
                ASL     A                       ; *64
                ASL     A                       ; *128 = VCS_SIZE
                RTS

;------------------------------------------------------------------------------
; Con_SaveVCState - A = VC index.  Live console state -> that VC's block.
; MX %00 in, MX %00 out.  DBR = far bank.  Clobbers A, X, Y.
;------------------------------------------------------------------------------
Con_SaveVCState ENT
                MX      %00
                AND     #$00FF                  ; clear stale B before the index
                                                ;   math -- #34's shape
                JSR     _Con_VCBlockOff
                STA     _conVcBase              ; block base offset

                ; A SAVED STATE IS A VALID STATE, so say so.  VCS_INIT_FLAG was
                ; written in exactly one place -- _Con_VCFirstUse's seeding arm
                ; -- so a block could hold a real state saved here and still read
                ; as virgin.  That never showed while only the ttyv lines were
                ; bracketed, because a ttyv block IS virgin until its first
                ; Con_EnterVC and the seed is then correct.
                ;
                ; VC 0 is the counter-example and it is not a corner case: it is
                ; the boot console, so its block is only ever populated by a save
                ; on the way OUT of it, never by a first-use seed.  Bracketing a
                ; console write into VC 0 (syscall.s @sw_conGateOK, apple/fgx#129)
                ; therefore found INIT_FLAG clear, seeded from the ACTIVE VC and
                ; cleared the framebuffer -- measured: VC 0's whole boot log and
                ; shell history vanished and its buffer came back holding only
                ; the two lines the bracketed write had just put there.
                LDX     _conVcBase
                LDA     #1
                STA     CON_VC_STATE+VCS_INIT_FLAG,X

                ; --- VCS_VT: far bank -> far bank.  Carries the console
                ;     SCALARS at $4A..$59, which used to need a copy region and
                ;     an address space of their own. ---
                LDX     _conVcBase
                LDY     #0
@svv_loop       LDA     CON_VT_STATE,Y
                STA     CON_VC_STATE+VCS_VT_OFF,X
                INX
                INX
                INY
                INY
                CPY     #VCS_VT_LEN
                BCC     @svv_loop

                ; --- VCS_ALT: far bank -> far bank. ---
                LDX     _conVcBase
                LDY     #0
@sva_loop       LDA     CON_ALT_SAVE,Y
                STA     CON_VC_STATE+VCS_ALT_OFF,X
                INX
                INX
                INY
                INY
                CPY     #VCS_ALT_LEN
                BCC     @sva_loop
                RTS

;------------------------------------------------------------------------------
; Con_LoadVCState - A = VC index.  That VC's block -> live console state.
; MX %00 in, MX %00 out.  DBR = far bank.  Clobbers A, X, Y.
;
; The exact inverse of Con_SaveVCState, region for region.  It does NOT repaint:
; the caller runs Con_RenderAll after, because the framebuffer bank must be
; repatched between the load and the repaint.
;------------------------------------------------------------------------------
Con_LoadVCState ENT
                MX      %00
                AND     #$00FF
                JSR     _Con_VCBlockOff
                STA     _conVcBase

                ; --- VCS_VT: carries the console scalars at $4A..$59. ---
                LDX     _conVcBase
                LDY     #0
@ldv_loop       LDA     CON_VC_STATE+VCS_VT_OFF,X
                STA     CON_VT_STATE,Y
                INX
                INX
                INY
                INY
                CPY     #VCS_VT_LEN
                BCC     @ldv_loop

                ; --- VCS_ALT ---
                LDX     _conVcBase
                LDY     #0
@lda_loop       LDA     CON_VC_STATE+VCS_ALT_OFF,X
                STA     CON_ALT_SAVE,Y
                INX
                INX
                INY
                INY
                CPY     #VCS_ALT_LEN
                BCC     @lda_loop

                ; FORCE IMMEDIATE-RENDER.  VT_RENDER_STATE sits at $5A, past
                ; VCS_VT_LEN, so the copy above neither saved nor restored it --
                ; but this store is still REQUIRED, and for a reason the layout
                ; does not cover.  The value is LIVE, and it describes the
                ; OUTGOING VC's pixel pipeline: carried across unchanged, a 3
                ; reads to Con_RenderRow as a live direct-SHR claim and leaves
                ; the incoming VC's pixels frozen.  Being
                ; outside the copied range only means it cannot come back stale
                ; from a block; it does not clear itself.
                ;
                ; A background write sets 3 deliberately AFTER calling this, so
                ; ordering matters: this is the floor, the caller opts back out.
                SEP     #$20
                MX      %10
                LDA     #0
                STA    |CON_VT_STATE+VT_RENDER_STATE
                REP     #$30
                MX      %00
                ; WHERE THIS CONSOLE'S PIXELS GO.  The five render sites test
                ; _conBackendOn; it follows the VC whose state is now live, so
                ; the card's console renders on the card inside a write
                ; bracket and an SHR console renders on the SHR, from the same
                ; sites.  _conVcBase is the VC's block offset, idx*VCS_SIZE;
                ; the display table is one byte per VC.
                LDA     _conVcBase
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR                             ; back to the VC index
                TAX
                LDA     _conVcDisplay,X
                AND     #$00FF
                BEQ     @ldv_shr
                LDA     #$8080
@ldv_shr        STA     _conBackendOn
                RTS

