;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     macros.s
; Purpose:  Common macros for FGX development
; Author:   FGX Development Team
; Created:  2025-02-01
;
; This file contains macros that simplify common operations and ensure
; consistent code patterns throughout FGX.
;
;==============================================================================

;==============================================================================
; CPU MODE MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _NATIVE - Switch to 65816 native mode with 16-bit registers
;------------------------------------------------------------------------------
; Sets: Native mode, 16-bit A, 16-bit X/Y
; Use at kernel entry points and after reset
;------------------------------------------------------------------------------
_NATIVE         MAC
                CLC                     ; Clear carry for XCE
                XCE                     ; Switch to native mode
                REP     #$30            ; 16-bit A, X, Y
                LONGA   ON
                LONGI   ON
                <<<

;------------------------------------------------------------------------------
; _A8 - Set accumulator to 8-bit mode
;------------------------------------------------------------------------------
_A8             MAC
                SEP     #$20            ; 8-bit accumulator
                LONGA   OFF
                <<<

;------------------------------------------------------------------------------
; _A16 - Set accumulator to 16-bit mode
;------------------------------------------------------------------------------
_A16            MAC
                REP     #$20            ; 16-bit accumulator
                LONGA   ON
                <<<

;------------------------------------------------------------------------------
; _XY8 - Set index registers to 8-bit mode
;------------------------------------------------------------------------------
_XY8            MAC
                SEP     #$10            ; 8-bit X, Y
                LONGI   OFF
                <<<

;------------------------------------------------------------------------------
; _XY16 - Set index registers to 16-bit mode
;------------------------------------------------------------------------------
_XY16           MAC
                REP     #$10            ; 16-bit X, Y
                LONGI   ON
                <<<

;------------------------------------------------------------------------------
; _AXY8 - Set all registers to 8-bit mode
;------------------------------------------------------------------------------
_AXY8           MAC
                SEP     #$30            ; 8-bit A, X, Y
                LONGA   OFF
                LONGI   OFF
                <<<

;------------------------------------------------------------------------------
; _AXY16 - Set all registers to 16-bit mode
;------------------------------------------------------------------------------
_AXY16          MAC
                REP     #$30            ; 16-bit A, X, Y
                LONGA   ON
                LONGI   ON
                <<<

;==============================================================================
; SYSTEM CALL MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _SYSCALL - Execute a system call
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = System call number
; Notes:
;   Sets up stack and executes COP instruction
;------------------------------------------------------------------------------
_SYSCALL        MAC
                COP     FGX_COP_SIG     ; FGX system call signature
                DFB     ]1              ; System call number
                <<<

;------------------------------------------------------------------------------
; _SYSRET - Return from system call handler
;------------------------------------------------------------------------------
; Restores state and returns to caller
;------------------------------------------------------------------------------
_SYSRET         MAC
                RTI                     ; Return from interrupt/COP
                <<<

;==============================================================================
; MEMORY ACCESS MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _LDAL - Load accumulator long (explicit 24-bit address)
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = 24-bit address
;------------------------------------------------------------------------------
_LDAL           MAC
                LDA     >]1             ; Force long addressing
                <<<

;------------------------------------------------------------------------------
; _STAL - Store accumulator long (explicit 24-bit address)
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = 24-bit address
;------------------------------------------------------------------------------
_STAL           MAC
                STA     >]1             ; Force long addressing
                <<<

;------------------------------------------------------------------------------
; _SETDP - Set direct page register
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Direct page address (must be page-aligned in bank 0)
;------------------------------------------------------------------------------
_SETDP          MAC
                PEA     ]1              ; Push direct page value
                PLD                     ; Pull to direct page register
                <<<

;------------------------------------------------------------------------------
; _SETDBR - Set data bank register
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Bank number
;------------------------------------------------------------------------------
_SETDBR         MAC
                LDA     #]1             ; Load bank number
                PHA                     ; Push to stack
                PLB                     ; Pull to data bank register
                <<<

;==============================================================================
; STACK MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _PUSH16 - Push 16-bit value to stack
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Value or address to push
;------------------------------------------------------------------------------
_PUSH16         MAC
                LDA     ]1
                PHA
                <<<

;------------------------------------------------------------------------------
; _PUSH32 - Push 32-bit value to stack
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Low word
;   ]2 = High word
;------------------------------------------------------------------------------
_PUSH32         MAC
                LDA     ]2              ; Push high word first
                PHA
                LDA     ]1              ; Then low word
                PHA
                <<<

;------------------------------------------------------------------------------
; _PUSHALL - Save all registers to stack
;------------------------------------------------------------------------------
_PUSHALL        MAC
                PHA                     ; Save A
                PHX                     ; Save X
                PHY                     ; Save Y
                PHB                     ; Save data bank
                PHD                     ; Save direct page
                <<<

;------------------------------------------------------------------------------
; _PULLALL - Restore all registers from stack
;------------------------------------------------------------------------------
_PULLALL        MAC
                PLD                     ; Restore direct page
                PLB                     ; Restore data bank
                PLY                     ; Restore Y
                PLX                     ; Restore X
                PLA                     ; Restore A
                <<<

;==============================================================================
; COMPARISON AND BRANCHING MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _CMP16 - Compare 16-bit values
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = First value (in A)
;   ]2 = Second value
; Result:
;   Flags set as per CMP instruction
;------------------------------------------------------------------------------
_CMP16          MAC
                CMP     ]1
                <<<

;------------------------------------------------------------------------------
; _BLT - Branch if less than (signed)
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Target label
; Note:
;   Use after CMP for signed comparison
;------------------------------------------------------------------------------
_BLT            MAC
                BMI     ]1              ; Branch if negative (A < operand)
                <<<

;------------------------------------------------------------------------------
; _BGE - Branch if greater than or equal (signed)
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Target label
;------------------------------------------------------------------------------
_BGE            MAC
                BPL     ]1              ; Branch if positive (A >= operand)
                <<<

;==============================================================================
; LOOP MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _REPEAT - Start of repeat loop
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Loop counter label
;   ]2 = Count
;------------------------------------------------------------------------------
_REPEAT         MAC
]1              =       ]2
:loop
                <<<

;------------------------------------------------------------------------------
; _UNTIL - End of repeat loop (decrement and branch)
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Loop counter label
;   ]2 = Loop start label
;------------------------------------------------------------------------------
_UNTIL          MAC
                DEX
                BNE     ]2
                <<<

;==============================================================================
; DEBUG MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _DEBUG - Conditional debug output
;------------------------------------------------------------------------------
; Only assembled when DEBUG flag is set
; Parameters:
;   ]1 = Debug message or action
;------------------------------------------------------------------------------
_DEBUG          MAC
                DO      DEBUG
                ]1
                FIN
                <<<

;------------------------------------------------------------------------------
; _BREAK - Insert breakpoint (BRK instruction)
;------------------------------------------------------------------------------
; Use for debugging - triggers BRK handler
;------------------------------------------------------------------------------
_BREAK          MAC
                BRK                     ; Software breakpoint
                DFB     ]1              ; Optional signature byte
                <<<

;------------------------------------------------------------------------------
; _ASSERT - Assert condition (debug builds only)
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Branch instruction if condition FALSE (e.g., BEQ)
;   ]2 = Error code
;------------------------------------------------------------------------------
_ASSERT         MAC
                DO      DEBUG
                ]1      :ok             ; Skip if condition true
                BRK                     ; Assertion failed
                DFB     ]2              ; Error code
:ok
                FIN
                <<<

;==============================================================================
; STRING MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _STR - Define a null-terminated string
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = String text
;------------------------------------------------------------------------------
_STR            MAC
                ASC     ]1
                DFB     $00             ; Null terminator
                <<<

;------------------------------------------------------------------------------
; _PSTR - Define a Pascal-style string (length-prefixed)
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = String text
;------------------------------------------------------------------------------
_PSTR           MAC
                DFB     :end-:start     ; Length byte
:start          ASC     ]1
:end
                <<<

;==============================================================================
; TOOLBOX CALL MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _TOOL - Call an IIgs Toolbox function
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Tool call number (e.g., MT_VERSION)
;------------------------------------------------------------------------------
_TOOL           MAC
                JSL     $E10000         ; Tool dispatcher
                DW      ]1              ; Tool/function number
                <<<

;------------------------------------------------------------------------------
; _TOOLERR - Check toolbox error and branch if error
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Label to branch to on error
;------------------------------------------------------------------------------
_TOOLERR        MAC
                BCS     ]1              ; Carry set = error
                <<<

;==============================================================================
; INTERRUPT MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _CLI - Enable interrupts (clear interrupt disable)
;------------------------------------------------------------------------------
_CLI            MAC
                CLI
                <<<

;------------------------------------------------------------------------------
; _SEI - Disable interrupts (set interrupt disable)
;------------------------------------------------------------------------------
_SEI            MAC
                SEI
                <<<

;------------------------------------------------------------------------------
; _CRITICAL - Begin critical section (save and disable interrupts)
;------------------------------------------------------------------------------
; Saves current interrupt state and disables interrupts
;------------------------------------------------------------------------------
_CRITICAL       MAC
                PHP                     ; Save processor status (including I flag)
                SEI                     ; Disable interrupts
                <<<

;------------------------------------------------------------------------------
; _ENDCRITICAL - End critical section (restore interrupt state)
;------------------------------------------------------------------------------
_ENDCRITICAL    MAC
                PLP                     ; Restore processor status
                <<<

;==============================================================================
; VIDEO MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _SHRADDR - Calculate SHR screen address
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Scanline number (0-199)
; Result:
;   A = Low word of address
; Note:
;   High byte is always $E1 (SHR bank)
;   Address = $E12000 + (scanline * 160)
;------------------------------------------------------------------------------
_SHRADDR        MAC
                LDA     #]1             ; Scanline
                ASL     A               ; * 2
                ASL     A               ; * 4
                ASL     A               ; * 8
                ASL     A               ; * 16
                ASL     A               ; * 32
                STA     :temp
                ASL     A               ; * 64
                ASL     A               ; * 128
                CLC
                ADC     :temp           ; * 160 (128 + 32)
                ADC     #$2000          ; Add base offset
                <<<

;------------------------------------------------------------------------------
; _SETSCB - Set SCB for a scanline
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Scanline number (0-199)
;   ]2 = SCB value
;------------------------------------------------------------------------------
_SETSCB         MAC
                _A8
                LDA     #]2
                STAL    SHR_SCB+]1
                _A16
                <<<

;==============================================================================
; ALIGNMENT MACROS
;==============================================================================

;------------------------------------------------------------------------------
; _ALIGN - Align to boundary
;------------------------------------------------------------------------------
; Parameters:
;   ]1 = Alignment (must be power of 2)
;------------------------------------------------------------------------------
_ALIGN          MAC
                DS      \,$00           ; Merlin pads to boundary
                <<<

;------------------------------------------------------------------------------
; _PAGE - Align to page boundary (256 bytes)
;------------------------------------------------------------------------------
_PAGE           MAC
                DS      \,$00
                <<<

;==============================================================================
; KERNEL MEMORY DISCIPLINE
;==============================================================================

;------------------------------------------------------------------------------
; _ZeroBankRegion - zero a bank-$02 region [start, end) using MVN propagation.
;
; Parameters:
;   ]1  Start label (bank-$02 address, e.g. CON_EXPAND).
;   ]2  End label   (one past last byte, e.g. KMem_ConExpand_end).
;
; Requires: MX %00 on entry; DBR = $02 on entry.
; Leaves:   MX %00; DBR = $02 (MVN destination bank).
; Clobbers: A, X, Y, flags.
;
; Technique: STZ the first byte, then MVN from byte N to byte N+1 for
; (size-2) more bytes.  The MVN reads the byte we just zeroed and copies
; it forward, propagating zeros through the whole range with no branch.
; Requires size >= 2.
;------------------------------------------------------------------------------
_ZeroBankRegion MAC
                SEP     #$20
                MX      %10
                STZ     ]1
                REP     #$20
                MX      %00
                LDA     #{]2}-{]1}-2
                LDX     #{]1}&$FFFF
                LDY     #{{]1}+1}&$FFFF
                MVN     $02,$02
                <<<

;==============================================================================
; FGX2 CROSS-BANK CALLING CONVENTION (Phase 3.2)
;==============================================================================
;
; Cross-bank calls in FGX2 use JSL with a runtime-patched bank byte and a
; callee prologue/epilogue that switches DBR to the data segment's bank.
; The loader's reloc table patches two placeholder bytes:
;
;   1. CALLER side: a JSL operand's bank byte (assembled as 0).  Reloc
;      points at the JSL opcode + 3 with tgt_seg = callee's segment.
;      No caller-side macro — `JSL callee_label-callee_seg_start` already
;      emits `22 LL HH 00`, which is the placeholder shape.  Document the
;      reloc as src = caller_seg, offset = jsl_label + 3, tgt = callee_seg.
;
;   2. CALLEE side: the prologue's `LDA #imm8` immediate byte.  Reloc
;      points at `func_label + FGX2_CALLEE_DATA_BANK_OFFSET` with tgt =
;      n_data_segment (header field).
;
; Stack discipline: PHB at entry pushes caller's DBR; PHA-then-PLB before
; the body sets DBR = data_bank without dropping the saved value; PLB at
; exit restores caller's DBR; RTL pops the JSL frame.
;
; Use:
;
;   func_label      FGX2_CALLEE_ENTER
;                   ; body — M=16, X=16, DBR = data segment's bank
;                   FGX2_CALLEE_LEAVE
;
; Reloc entry for the LDA #data_bank patch (slice 3.1 hand-emit shape):
;
;                   DFB     <callee_seg>
;                   DA      func_label-<callee_seg_start>+FGX2_CALLEE_DATA_BANK_OFFSET
;                   DFB     <n_data_segment>
;
; The Phase 4 Python linker will emit these from compiler hints
; automatically; for slice 3.x they're hand-written in test sources.
;------------------------------------------------------------------------------

FGX2_CALLEE_DATA_BANK_OFFSET EQU 4      ; offset of LDA #imm8's imm byte
                                        ; within FGX2_CALLEE_ENTER's expansion
                                        ; (PHB=1 + SEP #$20=2 + LDA opcode=1).

;------------------------------------------------------------------------------
; FGX2 cross-bank xref macros (Phase 4.2).
;
; These macros emit the standard cross-bank prologue / call-site bytes
; (same as slice 3.2).  `tools/fgx_ld.py` scans the Merlin listing's
; macro-invocation rows for `FGX2_XREF_JSL_BANK` and `FGX2_CALLEE_ENTER`,
; reads the args from the source-text column, and uses the row's address
; column + a kind-specific delta to compute the patch-byte offset.  No
; manual offset bookkeeping in the manifest.
;
; Tags are documentary only — fgx_ld doesn't consume them; pick names
; that make call sites obvious in the listing.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; FGX2_XREF_JSL_BANK - cross-bank JSL call site.
;
; Emits a JSL with bank-byte placeholder = 0.  fgx_ld sees the macro
; invocation row at address X, adds +3 (JSL bank-byte offset), and emits
; a reloc entry (src_seg, X+3, tgt_seg).
;
; Params:
;   ]1  unique tag (documentary; e.g. `to_seg1_func`)
;   ]2  target segment index (0..7)
;   ]3  target offset within target segment (16-bit)
;------------------------------------------------------------------------------
FGX2_XREF_JSL_BANK MAC
                JSL     ]3                      ; bank byte = 0 placeholder
                <<<

;------------------------------------------------------------------------------
; FGX2_CALLEE_ENTER - cross-bank callee prologue.
;
; Saves caller's DBR, switches DBR to the data segment's bank via an
; LDA #imm/PHA/PLB pair whose imm byte the loader patches at link time.
; Leaves M=16, X=16, DBR = data_bank.
;
; fgx_ld sees the macro invocation row at address X, adds +4 (= PHB +
; SEP #$20 + LDA opcode = 1+2+1) = the imm byte offset, and emits a
; reloc (src_seg, X+4, tgt_seg).
;
; Params:
;   ]1  unique tag (documentary; typically the function's symbol name)
;   ]2  target segment index = n_data_segment (header field)
;
; Requires: MX %00 on entry (the body runs at M=16).
;------------------------------------------------------------------------------
FGX2_CALLEE_ENTER MAC
                PHB                             ; save caller's DBR
                SEP     #$20
                MX      %10
                LDA     #$00                    ; PATCHED by reloc to data_bank
                PHA
                PLB                             ; DBR = data_bank
                REP     #$20
                MX      %00
                <<<

;------------------------------------------------------------------------------
; FGX2_CALLEE_LEAVE - cross-bank callee epilogue.
;
; Restores caller's DBR from the PHB at entry and returns via RTL.
; Requires: MX %00 on entry; stack must hold the entry's saved DBR on top.
;------------------------------------------------------------------------------
FGX2_CALLEE_LEAVE MAC
                PLB                             ; restore caller's DBR
                RTL
                <<<

;------------------------------------------------------------------------------
; FGX2 named-symbol cross-segment refs (Phase 4.4).
;
; FGX2_EXPORT and FGX2_IMPORT_JSL close the "if I add an instruction to a
; callee segment, every caller breaks silently" hazard from slice 4.2.
; The linker (`tools/fgx_ld.py`) scans for these macros in the Merlin
; listing, builds an exports table, resolves each import by name, patches
; the import's JSL operand with the resolved offset, and emits a bank-byte
; reloc for the JSL's bank byte (same runtime contract as FGX2_XREF_JSL_BANK).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; FGX2_EXPORT - declare a symbol exported from the current segment.
;
; Emits no bytes.  fgx_ld reads the macro invocation row's address column
; as the symbol's offset within the segment, and records it in the segment's
; exports table.
;
; Params:
;   ]1  symbol name (linker-visible; e.g. `seg1_func`)
;------------------------------------------------------------------------------
FGX2_EXPORT     MAC
;               (intentionally empty - linker reads address from listing)
                <<<

;------------------------------------------------------------------------------
; FGX_SECT / FGX_ENDS -- one unit of a library pile (fcc --sections): a whole
; function, or one data item.  fgx_gc (toolchain/src/ld/fgx_gc.py) keeps or
; drops each unit by whether the tool can reach its labels.  No bytes.
; Params (FGX_SECT):
;   ]1  the unit's label
;------------------------------------------------------------------------------
FGX_SECT        MAC
;               (intentionally empty - fgx_gc reads the source)
                <<<
FGX_ENDS        MAC
;               (intentionally empty - fgx_gc reads the source)
                <<<

;------------------------------------------------------------------------------
; FGX2_MODE - per-TU toolchain-contract stamp (P3-5 I2, Layer2Gate).
;
; Emits no bytes.  fcc stamps one invocation at the top of every generated
; .s (code AND data segment output); fgx_ld collects every invocation from
; every listing and FAILS THE LINK unless all values agree with the
; linker's expected contract version (FGX_ABI_CURRENT).  Catches a stale
; pre-flip .s (regenerated-golden or build artifact) staged into a
; post-flip link — the "make-from-src/cc silently stale" class that
; otherwise ships a works-single-bank/corrupts-multi-bank binary.
;
; Params:
;   ]1  contract version word (currently 2 = post-Phase-3: 32-bit ptr
;       model, hw stack, kernel ABI v2)
;------------------------------------------------------------------------------
FGX2_MODE       MAC
;               (intentionally empty - linker reads value from listing)
                <<<

;------------------------------------------------------------------------------
; FGX2_RELOC_COUNT - per-TU reloc-row declaration (P3-5 I3, fail-closed
; transport).
;
; Emits no bytes.  fcc writes one invocation at the END of every generated
; .s (code AND data output) declaring how many listing-significant FGX2_*
; rows (FGX2_MODE + the reloc/export macros) that file emitted.  fgx_ld
; counts the rows it actually RECOGNIZED per source file and FAILS THE LINK
; on any mismatch — closing the silent-skip hole: a listing row the parser
; drops (the g_op_table-at-$0000 class) produces NO reloc and NO error
; today; with the declaration, the count comes up short and the link dies.
;
; Params:
;   ]1  expected number of FGX2_* macro rows from this file (excluding
;       this FGX2_RELOC_COUNT row itself)
;------------------------------------------------------------------------------
FGX2_RELOC_COUNT MAC
;               (intentionally empty - linker reads value from listing)
                <<<

;------------------------------------------------------------------------------
; FGX2_IMPORT_JSL - cross-segment JSL call by name.
;
; Emits `JSL $000000` (4-byte placeholder).  fgx_ld looks up <name> in
; segment <tgt_seg>'s exports, writes the resolved 16-bit offset to the
; JSL operand's low+high bytes (invocation_addr + 1, +2), and emits a
; reloc entry (src_seg, invocation_addr + 3, tgt_seg) for the bank byte.
;
; Params:
;   ]1  unique tag (documentary; e.g. `seg1_call`)
;   ]2  imported symbol name (must match an FGX2_EXPORT in tgt segment)
;   ]3  target segment index (0..7)
;------------------------------------------------------------------------------
FGX2_IMPORT_JSL MAC
                JSL     $000000                 ; LL,HH PATCHED by linker
                                                ; bank byte patched at load
                <<<

;------------------------------------------------------------------------------
; FGX2_FARCALL <name> - cross-bank call to a user function the linker resolves
; GLOBALLY (no caller-supplied target segment, unlike FGX2_IMPORT_JSL).  Emits
; `JSL $000000`; fgx_ld looks up <name> across ALL segments' FGX2_EXPORTs,
; patches the operand offset (+1,+2) and emits a bank reloc (+3).  The callee
; (an fcc user function under --far-calls) returns via RTL.
;
; Params:
;   ]1  user function name (must match an FGX2_EXPORT in some segment)
;------------------------------------------------------------------------------
FGX2_FARCALL    MAC
                JSL     $000000                 ; LL,HH,BB PATCHED by linker
                <<<

;------------------------------------------------------------------------------
; FGX2_FARJUMP <name> - cross-bank JUMP to a routine the linker resolves
; GLOBALLY, as FGX2_FARCALL resolves a call.  Emits `JML $000000'; fgx_ld
; patches the operand offset (+1,+2) and emits a bank reloc (+3).  It pushes
; nothing: a tail jump, whose caller has already built the frame the target's
; RTL returns through (crt0_lib.s _sig_tramp, ld_bind_entry.s).
;
; Params:
;   ]1  routine name (must match an FGX2_EXPORT in some segment)
;------------------------------------------------------------------------------
FGX2_FARJUMP    MAC
                JML     $000000                 ; LL,HH,BB PATCHED by linker
                <<<

;------------------------------------------------------------------------------
; PILE_CALL <name> - call an ENT/RTL routine assembled in the same segment,
; with no reloc: the libc pile's calls between its own members, as fcc's
; emit_pile_call writes them.  Not an FGX2_* name, because it gives fgx_ld
; nothing to record and must not count toward a file's FGX2_RELOC_COUNT.  The frame is JSL-shaped, built with PHK, so the
; callee's RTL returns here in whatever bank the segment was loaded.  PER is
; PC-relative; the return address minus one is the RTL's own address, 7 bytes
; past PER.
;
; Params:
;   ]1  the routine's label
;------------------------------------------------------------------------------
PILE_CALL       MAC
                PHK
                PER     *+7
                PHK
                PEA     ]1-1
                RTL
                <<<

;------------------------------------------------------------------------------
; FGX2_LONG_PTR - cross-segment 4-byte long pointer (Phase 4.5).
;
; The data analogue of FGX2_IMPORT_JSL.  Emits 4 bytes:
;
;   +0..+1  16-bit offset of <name> in segment <tgt_seg>   (PATCHED by linker)
;   +2      bank byte                                       (PATCHED by loader)
;   +3      $00 pad
;
; fgx_ld.py scans the listing for FGX2_LONG_PTR rows, looks up <name> in
; the target segment's exports table, patches bytes +0/+1 with the resolved
; offset (little-endian), and emits a reloc entry (src_seg, addr+2, tgt_seg)
; for the loader to write the bank byte at load time.
;
; The target label must be declared via FGX2_EXPORT in its segment.
;
; Use case: fcc-emitted initialisers that reference data in another segment
; (e.g. `char *names[] = { "foo", "bar" }` where the names live in the code
; segment's string pool but `names[]` lives in the data segment).
;
; Params:
;   ]1  unique tag (documentary; e.g. `s5_ptr`)
;   ]2  imported symbol name (must match an FGX2_EXPORT in tgt segment)
;   ]3  target segment index (0..7)
;------------------------------------------------------------------------------
FGX2_LONG_PTR   MAC
                DA      $0000                   ; LL,HH PATCHED by linker
                DFB     $00                     ; bank byte patched at load
                DFB     $00                     ; pad
                <<<

;------------------------------------------------------------------------------
; FGX2_ABS_OFFSET - cross-segment 2-byte offset (Phase 4.5).
;
; Emits 2 bytes: the 16-bit offset of <name> in segment <tgt_seg>, patched
; by fgx_ld.py at link time.  No reloc is emitted — the bank byte is
; implied by surrounding code (typically PHK at deref).
;
; Use case: fcc's in-struct char* fields (2 bytes), where the deref site
; does PHK to recover the bank.  When --data-segment puts the struct in
; seg1 but the string in seg0, Merlin32 in seg1 can't see _S<n> — this
; macro is the substitute.
;
; Params:
;   ]1  unique tag (documentary)
;   ]2  imported symbol name
;   ]3  target segment index (0..7)
;------------------------------------------------------------------------------
FGX2_ABS_OFFSET MAC
                DA      $0000                   ; LL,HH PATCHED by linker
                <<<

;==============================================================================
; END OF FILE
;==============================================================================
