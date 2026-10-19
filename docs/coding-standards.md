# FGX Coding Standards

## Philosophy

1. **Clarity over cleverness**: Code should be immediately understandable
2. **Documentation is mandatory**: Every file, routine, and non-obvious line
3. **Consistency**: Follow these standards throughout the codebase
4. **Simplicity**: Prefer straightforward solutions over micro-optimizations
5. **Conformance is read, never remembered**: see the next section

---

## Conformance: check K&R and BSD, from the source, every time

FGX is a BSD system with a K&R compiler. Both of those are *claims*, and a claim
that is never checked drifts. So:

**Before writing an fcc parser or codegen change**, read the relevant section of
K&R 2nd ed — the C Reference Manual, Appendix A — and **quote the sentence that
decides it in the commit message**. The book is indexed for offline search as
`kr_c`:

```
mcp__gs-mcp__search_iigs_docs(query, doc_filter=["kr_c"])
mcp__gs-mcp__get_iigs_page(doc_id="kr_c", page=N)
```

**Before implementing or changing a syscall, a libc function, or kernel
behaviour with a BSD counterpart**, read the counterpart. It is vendored:
`vendor/2.11BSD/` (the porting source, including the kernel under `usr/sys/`),
`vendor/4.3BSD-Reno/` (the VFS source), and the complete distributions under
gitignored `examples/`. Name the file and function in the commit.

**`vendor/2.11BSD/` IS A 1999 SNAPSHOT, AND THE ORACLE IS NOT.** The tree is at
approximately **patch level 429** (newest source stamp 1999/11/26) and stays
there by decision, because the ports were made against those bytes and moving
them would invalidate every `docs/PROVENANCE.md` row naming a line in it. The
live 2.11BSD PDP-11/70 this project checks bytes against is at **patch 498**
(September 2025) -- about 69 patches and 26 years apart. Where they disagree,
the machine is what 2.11BSD does *today*.

So: **when upstream code looks wrong, or a defect smells like one somebody else
would have hit, check the patches before diverging.** The archive is mirrored to
gitignored `examples/2.11BSD-Patches/` (1-479 from retro11.de, plus
`DESCRIPTIONS-480-499.txt` off the machine); each carries
Subject/Index/Description/Repeat-By/Fix, so `grep -rl ufs_alloc
examples/2.11BSD-Patches/` finds it by file and `grep -rli 'inode.*hang'` by
symptom. This is not hypothetical: the review that produced this note found
apple/fgx#278, an `ialloc`
defect FGX had inherited verbatim and which upstream fixed in patch 433, four
patches past the vendored tree.

### Why this is a rule and not a nicety

Every time conformance has been *asserted from memory* and then actually
checked, the check produced a finding rather than reassurance:

| item | asserted | what reading it found |
|---|---|---|
| #153 | "meets A.8.6.3" | a **third defect** — A.10.2 requires declarations to agree and fcc checked nothing |
| #158 | "A.2.6 says adjacent literals concatenate" | the clause **order** — the null is appended *after* the join, so concatenation acts on decoded bytes and `"\1" "2"` must be `01 '2'`. An untested case, and one where both readings compile |
| #127/#128 | "a wildcard bind should serve loopback" | `in_pcbbind` **never touches a device**, so the whole mechanism was wrong; the fix belonged at `listen()`, not `bind()` |

A remembered spec is a remembered *conclusion*. The text carries clause order,
scope words and exceptions — which is exactly where the untested cases live.

### What "checked" means

- **Quote it.** A section number alone is not evidence, and naming one reads as
  having checked. Paste the sentence.
- **Say when you have not.** "Not verified against K&R" is a legitimate commit
  line; a section number you did not open is not.
- **State divergences rather than letting them be discovered.** Where FGX
  cannot or will not match, say so in the man page's BUGS section and the
  commit — as `getpeername(2)` does for the loopback connector's absent port,
  and `Fs_Truncate` does for tree files.

### It is deliberately not machine-checked

A gate that grepped commit messages for "A.7.3" would be satisfied by typing
"A.7.3", which is the failure it would exist to prevent. The check is the
reviewer's, and the quoted sentence is what makes it reviewable.

### Which BSD, when the two disagree

FGX is a **2.11BSD system with a 4.3BSD-Reno VFS in it**, and Reno is in it only
because 2.11BSD has no vnodes to port. Where the two trees disagree about
anything outside the VFS, 2.11BSD wins: it is the 16-bit-int codebase, sized for
a small machine, and it is what the rest of this kernel already is.

**The worked example is the credential, because it is where the seam actually
falls.** Reno passes a refcounted `struct ucred *` down every vnode op, holds
one on an open file (`f_cred`) and copies one on exec. 2.11BSD has **no
`struct ucred` anywhere in its kernel** — its check is `access(ip, mode)`
(`usr/sys/sys/ufs_fio.c:32`), reading `u.u_uid` out of the u-area. FGX takes
2.11BSD's: the ids live in the u-area and the filesystem reads them through
`kc_curuid`/`kc_curgid`. A credential here is a property of the running process,
not of a file, and no `ucred` is owed. `file.h`'s `f_cred` note is the canonical
statement; the rest of the VFS points at it.

The thing that makes this a rule rather than a preference is what it saved:
FGX's `ucred`-shaped fields were carried for a campaign as "gaps" waiting on a
credential that was never going to arrive in that shape, and the comments saying
so went stale the moment real credentials landed in the u-area instead. When a
Reno construct has no 2.11BSD counterpart, ask whether this kernel wants the
construct or the *behaviour* — and if the answer is the behaviour, say so at the
field rather than leaving a promise nobody means to keep.

Corollary, and it is the one that bites: **2.11BSD usually has an answer that
needs no Reno machinery.** `access(2)` must be answered for the *real* ids;
Reno does it by passing a different `ucred`, and 2.11BSD does it by swapping the
real ids into the u-area around the call and putting them back (`saccess`,
`usr/sys/sys/ufs_syscalls.c:383`). Look for that answer before concluding a
Reno structure is required.

---

## File Organization

### File Header

Every source file must begin with a header block:

```asm
;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     filename.s
; Purpose:  Brief description of file's purpose
; Author:   Author name
; Created:  YYYY-MM-DD
; Modified: YYYY-MM-DD
;
; Copyright (c) YYYY. All rights reserved.
;
;==============================================================================
```

### Section Organization

Files should be organized in this order:

```asm
;==============================================================================
; [File Header]
;==============================================================================

;==============================================================================
; INCLUDES
;==============================================================================
        USE     hardware.s
        USE     kernel.s

;==============================================================================
; CONSTANTS
;==============================================================================
CONSTANT_NAME   EQU     $1234

;==============================================================================
; MACROS
;==============================================================================
MACRO_NAME      MAC
        ; macro body
        <<<

;==============================================================================
; DATA
;==============================================================================
        DUM     $0000           ; Direct page variables
DP_Variable     DS      2
        DEND

DataLabel       DFB     $00,$01,$02

;==============================================================================
; CODE
;==============================================================================
RoutineName:
        ; code
        RTS

;==============================================================================
; END OF FILE
;==============================================================================
```

---

## Naming Conventions

### Labels

| Type              | Convention      | Example            |
|-------------------|-----------------|---------------------|
| Public routines   | FGX_PascalCase  | `FGX_CreateTask`   |
| Private routines  | _PascalCase     | `_FindFreeSlot`    |
| Local labels      | @lowercase      | `@loop`, `@done`   |
| Constants         | UPPER_SNAKE     | `MAX_TASKS`        |
| Equates           | UPPER_SNAKE     | `TASK_READY`       |
| Variables         | PascalCase      | `CurrentTask`      |
| Direct page vars  | DP_PascalCase   | `DP_Temp1`         |
| Hardware regs     | HW_UPPER        | `HW_KEYBOARD`      |

### Prefixes

| Prefix   | Meaning                              |
|----------|--------------------------------------|
| FGX_     | Public kernel API                    |
| _        | Private/internal routine             |
| @        | Local label (within routine)         |
| DP_      | Direct page variable                 |
| TCB_     | Task Control Block field             |
| MSG_     | Message-related constant             |
| ERR_     | Error code                           |
| HW_      | Hardware address/constant            |
| TB_      | Toolbox-related                      |
| SHR_     | Super High Resolution graphics       |
| ADB_     | Apple Desktop Bus                    |
| DOC_     | Ensoniq DOC sound chip               |

---

## Comments

### Routine Documentation

Every routine must have a header comment:

```asm
;=============================================================================
; FGX_RoutineName - Brief one-line description
;-----------------------------------------------------------------------------
; Purpose:
;   Detailed explanation of what this routine does. Include enough detail
;   that someone unfamiliar with the code can understand it.
;
; Input:
;   A     = Description of A register input
;   X     = Description of X register input
;   Y     = Description of Y register input (if used)
;   Stack = Description of stack parameters (if any)
;
; Output:
;   A     = Description of return value
;   X     = Description of X register on exit (if meaningful)
;   Carry = Set on error, clear on success
;
; Destroys:
;   List registers that are NOT preserved
;
; Notes:
;   - Any important notes about usage
;   - Side effects, assumptions, limitations
;   - Related routines or documentation references
;=============================================================================
FGX_RoutineName:
        ; Implementation
        RTS
```

### Inline Comments

```asm
; Good: Explains WHY, not just WHAT
        LDA     #$80            ; Set bit 7 for 640 mode (SHR requirement)
        STA     >SHR_SCB

; Bad: Just restates the instruction
        LDA     #$80            ; Load $80 into A

; Good: Explains non-obvious logic
        ; VBL occurs every 16.67ms; multiply by 60 for ~1 second
        LDA     #60
        STA     SleepTicks

; Good: Section dividers for long routines
        ;-----------------------------------------
        ; Phase 1: Validate parameters
        ;-----------------------------------------

        ; ... code ...

        ;-----------------------------------------
        ; Phase 2: Allocate resources
        ;-----------------------------------------
```

### Comment Alignment

Align inline comments to column 40 when practical:

```asm
        LDA     CurrentTask             ; Get active task pointer
        BEQ     @noTask                 ; Null check
        LDA     TaskStatus,X            ; Get task status
        CMP     #TASK_READY             ; Is it ready to run?
        BNE     @blocked                ; No, handle blocked case
```

---

## Code Style

### Indentation

- Use 8-space tabs for opcode column
- Use spaces for alignment within operands
- Labels start at column 1
- Opcodes at column 9 (after one tab)
- Operands immediately follow opcode
- Comments at column 40 or after operand

```asm
Label:                                  ; Column 1
        LDA     #$1234                  ; Column 9 (tab), comment at 40
        STA     >LongAddressName        ; Operand immediately follows
```

### Instruction Formatting

```asm
; Opcode in uppercase
        LDA     #$00                    ; Good
        lda     #$00                    ; Bad

; Hex values in uppercase with $ prefix
        LDA     #$FF                    ; Good
        LDA     #$ff                    ; Bad
        LDA     #255                    ; Acceptable for decimal context

; Explicit addressing modes when ambiguous
        LDA     $00                     ; Direct page
        LDAL    $010000                 ; Long absolute
        LDA     >$1234                  ; Force absolute (bank 0)
```

### Register Width

Always make register width explicit after any REP/SEP:

```asm
        REP     #$30                    ; 16-bit A, X, Y
        LONGA   ON
        LONGI   ON

        ; ... 16-bit operations ...

        SEP     #$20                    ; 8-bit A
        LONGA   OFF

        ; ... 8-bit A, 16-bit X/Y ...
```

### Control Flow

```asm
; Use meaningful local labels
@loop:  LDA     Array,X
        BEQ     @done                   ; Exit on zero
        INX
        CPX     #MAX_COUNT
        BNE     @loop
@done:  RTS

; Avoid deeply nested branches - use early returns
FGX_Validate:
        ; Early exit for invalid input
        CMP     #0
        BEQ     @invalid
        CMP     #MAX_VALUE
        BCS     @invalid

        ; Main logic here
        ; ...

        CLC                             ; Success
        RTS

@invalid:
        SEC                             ; Error
        RTS
```

---

## Data Structures

### Structure Documentation

Document every field in data structures:

```asm
;=============================================================================
; Task Control Block (TCB)
;-----------------------------------------------------------------------------
; Size: 48 bytes
; Alignment: None required
;=============================================================================
TCB_TaskID      EQU     $00             ; [2] Unique task identifier
TCB_Status      EQU     $02             ; [2] READY/RUNNING/BLOCKED/ZOMBIE
TCB_Priority    EQU     $04             ; [1] Current priority (0-7)
TCB_BasePrio    EQU     $05             ; [1] Base priority (for aging)
TCB_StackBank   EQU     $06             ; [2] Bank containing task stack
TCB_StackPtr    EQU     $08             ; [2] Current stack pointer
; ... etc ...
TCB_SIZE        EQU     48              ; Total size in bytes
```

### Magic Numbers

Never use magic numbers; define constants:

```asm
; Bad
        CMP     #32
        BCS     @error

; Good
MAX_TASKS       EQU     32

        CMP     #MAX_TASKS
        BCS     @error
```

---

## Error Handling

### Return Conventions

- **Carry = SUCCESS.** `C=1` on success, `C=0` on error with the errno in `A`.
  This is the whole-system convention -- every syscall, the loader
  (`include/loader.s`: "On success: C=1 ... On failure: C=0, A = errno"), the FOP
  and chardev vtables, and the userland ABI. Do not invert it locally.
- Return the errno (`include/errno.s`, 2.11BSD numbering) in `A` when `C=0`.
- Document all possible error returns.

```asm
;=============================================================================
; Fs_Example - Example with error handling
;-----------------------------------------------------------------------------
; Output:
;   C=1 on success, A = result
;   C=0 on error,   A = errno
;                         ENOENT = resource not found
;                         ENOMEM = out of memory
;=============================================================================
Fs_Example:
        ; ... implementation ...

        BCS     @success

        ; Error path
        LDA     #ENOENT
        CLC
        RTS

@success:
        LDA     Result
        SEC
        RTS
```

### Defensive Programming

```asm
; Validate inputs
FGX_SetPriority:
        ; Check priority range
        CPX     #8                      ; Priority must be 0-7
        BCS     @invalidPriority

        ; Check task ID
        CMP     #MAX_TASKS
        BCS     @invalidTask

        ; ... rest of implementation ...

@invalidPriority:
@invalidTask:
        LDA     #EINVAL
        CLC                             ; C=0 = error
        RTS
```

---

## Assembly Directives

### Merlin 32 Specifics

```asm
; Use EQU for constants
MAX_VALUE       EQU     $FF

; Use = as alternative (same as EQU)
MIN_VALUE       =       $00

; Define bytes
Data            DFB     $01,$02,$03     ; Define bytes
                DW      $1234           ; Define word (16-bit)
                ADR     Label           ; Define 24-bit address
                ADRL    Label           ; Define 32-bit address

; Reserve space
Buffer          DS      256             ; Reserve 256 bytes

; Dummy sections for direct page layout
                DUM     $00
DP_Var1         DS      2
DP_Var2         DS      2
                DEND

; Conditional assembly
                DO      DEBUG
                JSR     DebugPrint
                FIN

; Macros
PrintChar       MAC
                LDA     ]1              ; ]1 is first parameter
                JSL     FGX_PutChar
                <<<
```

---

## Version Control

### Commit Messages

Follow conventional commit format:

```
type(scope): brief description

Longer explanation if needed. Wrap at 72 characters.

- Bullet points for multiple changes
- Reference issues: Fixes #123
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code change that neither fixes bug nor adds feature
- `test`: Adding tests
- `chore`: Build process, auxiliary tools

### Tagging

Use semantic versioning: `vMAJOR.MINOR.PATCH`

- MAJOR: Breaking changes
- MINOR: New features, backward compatible
- PATCH: Bug fixes, backward compatible

---

## File Types

| Extension | Purpose                    |
|-----------|----------------------------|
| `.s`      | Assembly source file       |
| `.mac`    | Macro library              |
| `.md`     | Markdown documentation     |
| `.sh`     | Shell script               |

---

## Example: Complete Routine

```asm
;=============================================================================
; FGX_MemCopy - Copy memory block
;-----------------------------------------------------------------------------
; Purpose:
;   Copies a block of memory from source to destination. Handles overlapping
;   regions correctly by detecting direction and copying appropriately.
;
; Input:
;   Stack (pushed in order):
;     - Destination pointer (4 bytes, long)
;     - Source pointer (4 bytes, long)
;     - Byte count (2 bytes)
;
; Output:
;   Carry = Clear on success
;   Carry = Set on error (invalid parameters)
;
; Destroys:
;   A, X, Y
;
; Notes:
;   - Uses MVN/MVP for efficient block moves
;   - Handles zero-length copy (no-op, returns success)
;   - Source and destination may overlap
;=============================================================================
FGX_MemCopy:
        ;-----------------------------------------
        ; Set up stack frame and get parameters
        ;-----------------------------------------
        PHB                             ; Save data bank
        PHD                             ; Save direct page

        TSC                             ; Set up direct page on stack
        SEC
        SBC     #DP_LocalSize
        TCD

        ;-----------------------------------------
        ; Get parameters from stack
        ;-----------------------------------------
        LDA     DP_Count                ; Get byte count
        BEQ     @zeroLength             ; Zero bytes = no-op

        ;-----------------------------------------
        ; Determine copy direction
        ;-----------------------------------------
        ; If dest > src and they overlap, copy backwards
        LDA     DP_DestLo
        CMP     DP_SrcLo
        LDA     DP_DestHi
        SBC     DP_SrcHi
        BCC     @copyForward            ; Dest < Src, safe to copy forward

        ; Check for overlap
        ; ... (overlap detection logic) ...

@copyForward:
        ;-----------------------------------------
        ; Forward copy using MVN
        ;-----------------------------------------
        REP     #$30                    ; 16-bit A, X, Y
        LONGA   ON
        LONGI   ON

        LDX     DP_SrcLo                ; Source offset
        LDY     DP_DestLo               ; Dest offset
        LDA     DP_Count
        DEC     A                       ; MVN uses count-1

        MVN     DP_SrcBank,DP_DestBank  ; Move bytes forward

        ;-----------------------------------------
        ; Clean up and return
        ;-----------------------------------------
@done:
        PLD                             ; Restore direct page
        PLB                             ; Restore data bank
        CLC                             ; Success
        RTL

@zeroLength:
        ; Zero bytes requested - valid but no-op
        PLD
        PLB
        CLC
        RTL

        ;-----------------------------------------
        ; Direct page variable definitions
        ;-----------------------------------------
        DUM     $01                     ; Start at offset 1 (past return addr)
DP_Count        DS      2               ; Byte count
DP_SrcLo        DS      2               ; Source offset
DP_SrcBank      DS      2               ; Source bank
DP_DestLo       DS      2               ; Destination offset
DP_DestBank     DS      2               ; Destination bank
DP_LocalSize    EQU     *-$01
        DEND
```
