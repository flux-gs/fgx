# Merlin32 Reference

This document is a paraphrased Markdown reference based on the Merlin32 documentation published by Brutal Deluxe:

- Source: [https://brutaldeluxe.fr/products/crossdevtools/merlin/](https://brutaldeluxe.fr/products/crossdevtools/merlin/)
- Retrieved: 2026-04-22

It is meant as a local, readable quick reference for this repo rather than a verbatim copy of the original manual.

## Overview

Merlin32 is a cross-assembler for 6502-family CPUs, including 6502, 65C02, and 65C816. It runs on modern desktop systems and is designed to stay broadly compatible with Merlin 16+ source style while adding a cleaner cross-development workflow.

Key points:

- Supports Merlin 16+-style macros, variables, conditionals, loops, local labels, and expressions.
- Produces either fixed-address binaries or relocatable Apple IIgs OMF 2.1 output.
- Works especially well for Apple IIgs projects that still want Merlin-like source compatibility.
- Uses external editors and IDEs rather than bundling an editor like classic Merlin.

## Command Line

### Basic usage

```text
Merlin32.exe [-V] <macro_folder_path> <source_file_path|link_file_path>
```

### Parameters

| Parameter | Meaning |
| --- | --- |
| `-V` | Optional verbose mode. Produces assembly output text and symbol files. |
| `<macro_folder_path>` | Folder containing macro definition files such as `*.Macs.s`. |
| `<source_file_path|link_file_path>` | Either a master source file or, preferably, a link file. |

### Notes

- Quote paths that contain spaces.
- Transfer source and macro files as text.
- If files come from Apple II media, you may need to clear the high bit first.
- CADIUS can help with both `CLEARHIGHBIT` and `INDENTFILE`.

### Typical invocation

```text
Merlin32.exe -V c:\AppleIIgs\Merlin\Library c:\AppleIIgs\Source\Cogito\Cogito_Link.s
```

### Outputs

Depending on the project, Merlin32 can generate:

- A fixed-address binary file.
- An Apple IIgs OMF file.
- Verbose per-segment output listings.
- Symbol files.

## Source Format

### Four-column layout

Merlin32 source follows the classic Merlin shape:

| Column | Purpose |
| --- | --- |
| Label | Symbol, macro name, variable name, local label, etc. |
| Opcode | CPU opcode, assembler directive, or macro invocation. |
| Operand | Parameter for the opcode or directive. |
| Comment | Starts with `;`. |

Spacing is flexible. Tabs or spaces are fine. CADIUS can re-indent files afterward.

### Case sensitivity

Merlin32 is case-sensitive for user-defined names:

- Labels
- Macros
- Variables
- Equates

Opcode spelling is more forgiving, but user-defined identifiers are not.

### Comments

- Full-line comments can start with `*` or `;`.
- Indented `;` text becomes a trailing comment.
- Blank lines are ignored.

## Opcodes and Addressing

### CPU opcodes

Merlin32 accepts the normal 65C816 opcode set, plus some familiar aliases such as:

- `BGE` as an alias for `BCS`
- `BLT` as an alias for `BCC`

For long-address forms, Merlin32 recognizes mnemonics such as:

- `LDAL`
- `STAL`
- `ADCL`
- `JMPL`

### Addressing rules

Merlin32 tries to remove ambiguity:

- Immediate data should start with `#`.
- Bare numeric operands are treated as addresses unless the expression clearly collapses to data.
- Small addresses default to direct-page addressing.
- Long addressing can be forced with an `L` suffix on the opcode or `>` in the operand.

Examples:

```asm
LDA   #$01        ; immediate data
LDA   $10         ; direct page
LDA   $2000       ; absolute
LDAL  $E12000     ; long
LDA   >LABEL      ; force long form
```

### `MX`, `REP`, and `SEP`

Merlin32 tracks accumulator and index width while assembling:

- `MX %00` means 16-bit accumulator and index registers.
- `MX %11` means 8-bit accumulator and index registers.
- `REP` and `SEP` also update Merlin32's internal size tracking.

This matters for immediate operands because `LDA #1` may assemble as either 8-bit or 16-bit code depending on the current `M` state.

## Numbers, Strings, and Data

### Number formats

| Format | Example |
| --- | --- |
| Hex | `$E12000` |
| Binary | `%0000_1111` |
| Decimal | `160` |

Use `#` when you want a literal value instead of an address:

```asm
LDA   #$00A0
LDA   $2000
```

### Strings

Merlin32 uses only two string delimiters:

- `'single quotes'` for high-bit-clear ASCII
- `"double quotes"` for high-bit-set text-screen style data

You can also splice numeric byte values into strings when needed.

### Common data directives

| Directive | Purpose |
| --- | --- |
| `HEX` | Raw hexadecimal bytes |
| `DFB` / `DB` | Bytes |
| `DDB` | Big-endian 16-bit values |
| `DA` / `DW` | Little-endian 16-bit values |
| `ADR` | 3-byte addresses |
| `ADRL` | 4-byte addresses |
| `DS` | Reserved storage, optionally filled |
| `ASC` | ASCII text |
| `DCI` | Text with final byte inverted |
| `INV` | Inverse-video text |
| `FLS` | Flashing text |
| `REV` | Reversed text |
| `STR` | Length-prefixed string with 1-byte length |
| `STRL` | Length-prefixed string with 2-byte length |

## Labels, Expressions, and Variables

### Labels

- Labels are case-sensitive and should be unique.
- A label may appear on a line by itself and will take the next address.
- For Merlin 16+ compatibility, keep label length at 26 characters or less.

### Local labels

Merlin32 supports two local-label styles:

| Form | Behavior |
| --- | --- |
| `]NAME` | Backward-only local label |
| `:NAME` | Local label with scope between enclosing global labels |

Restrictions:

- Local labels cannot be the first label in a file.
- Local labels are not meant for `ENT`/`EXT`.
- `]` locals are backward-only.

### Expressions

Supported operators include:

- Comparison: `<`, `=`, `>`, `#`
- Arithmetic: `+`, `-`, `*`, `/`
- Logical: `&`, `.`, `!`

Merlin-style evaluation is left-to-right by default. Use braces -- NOT
parentheses -- for algebraic grouping:

```asm
1+2*3      ; evaluates left-to-right
{1+2*3}    ; evaluates with grouped precedence
```

**This has cost a day, so it is measured here rather than left as a
convention.** `LDY #12+4*4` emits `A0 40`: sixty-four, `{12+4}*4`, not the
twenty-eight a C reader sees. In UFS 2.3 that expression was a dinode's
`di_addr[NDADDR]` offset; it assembled clean, read past the end of a 64-byte
structure, found a zero, and a zero block address is a legal sparse HOLE -- so
the kernel loaded four blocks, zero-filled fifty-four, and the machine reset
into ROM with nothing on screen. **Any constant that mixes `+` with `*` needs
braces or a spelled-out `EQU`**, and the spelled-out one is better where the
value has a name in the source it came from.

`ERR` is stricter still: its expression evaluator handles neither parentheses
nor braces, and reports *"'(' can't be translated as a numeric expression"*.
Build the value in an `EQU` first and give `ERR` the two symbols.

### Equates and variables

Use `EQU` or `=` for constants:

```asm
HOME      EQU  $FC58
KBD       =    $C000
```

Variables begin with `]` and can be reassigned:

```asm
]LINE     =    $2000
]LINE     =    ]LINE+$A0
```

Forward references to variables are not allowed.

## Flow Control

### Loops with `LUP`

`LUP` repeats a block until `--^`:

```asm
]LINE     =    $2000
          LUP  200
          DA   ]LINE
]LINE     =    ]LINE+$A0
          --^
```

If you need repeated labels inside a loop, use `@` in the label name so Merlin32 can generate unique variants.

### Conditions

Merlin32 supports two conditional forms:

- `DO ... ELSE ... FIN`
- `IF ... ELSE ... FIN`

`ELSE` is optional. `FIN` is required.

Typical uses:

- Feature-flag style assembly
- Size- or platform-specific code
- Macro behavior based on parameters
- Tests against current `MX` state

## Macros

### Definition and invocation

Define a macro with `MAC` and end it with `EOM` or `<<<`:

```asm
WaitForKey  MAC
WFK1        LDA   $C000
            BPL   WFK1
            BIT   $C010
            <<<
```

Call it by using the macro name as the opcode:

```asm
            WaitForKey
```

Alternative call forms:

- `PMC`
- `>>>`

### Parameters

Macros may use up to eight positional parameters:

- `]1` through `]8`
- `]0` gives the argument count

Parameter separators are flexible for single-argument calls. Multi-argument calls use `;`.

### Important macro rules

- Define a macro before its first use.
- Nested macros are supported.
- For Merlin 16+ compatibility, keep nesting to 15 levels or less.
- Macro-local labels are rewritten internally to unique generated names in listings.

### Macro files

Use `USE` to include macro definition files. Merlin32 looks them up from the macro folder passed on the command line. Old Merlin-style subfolder prefixes may still appear in source, but Merlin32 only cares about the file name.

## Origins, Relocation, and Includes

### `ORG`

Use `ORG` when code must live at a fixed address:

```asm
ORG  $2000
ORG  $038000
```

Notes:

- Default origin is `$8000` in bank `$00` if no `ORG` is present.
- Very small origins can trigger direct-page interpretation for low addresses.
- Bare `ORG` can be used as a re-ORG marker after temporarily assembling code elsewhere.

### `REL`

Use `REL` for relocatable Apple IIgs output. Merlin32 assembles from a virtual base and emits OMF 2.1 output suitable for GS/OS-style programs.

### File inclusion

| Directive | Meaning |
| --- | --- |
| `USE` | Include text files, usually macros or shared definitions |
| `PUT` | Include source files |
| `PUTBIN` | Include binary files as assembled data |

Important limitation:

- `USE`, `PUT`, and `PUTBIN` belong in the master source file for a segment.
- Do not expect nested `PUT` or nested `PUTBIN` trees inside included source to behave like a general include system.

Paths may be:

- Bare filenames
- Relative paths
- Absolute paths

## Miscellaneous Directives

### `DUM` / `DEND`

Creates a dummy section used for label layout without emitting object code. This is useful for:

- Describing memory-mapped layouts
- Naming direct-page structures
- Declaring external memory organization

### `END`

Stops source processing. Anything after it is ignored.

### `CHK`

Emits an XOR checksum byte for fixed-address code. This is not suitable for relocatable output that will be patched by a loader.

### `DAT`

Emits the build date or date-time in one of several preset formats, with either high-bit-clear or high-bit-set text encoding.

### `ERR`

Forces an assembly error if its expression evaluates nonzero. Handy for size guards and build-time assertions.

## Output Model

Merlin32 performs assembly and linking as one overall process. Unlike classic Merlin 16+, it does not rely on persistent intermediate `.L` object files on disk.

The output type is controlled by `TYP`:

- `$B2` through `$BD` mean OMF-style output.
- Other values produce fixed-address files.

## Segments and Cross-Segment References

A segment is built from one master source file and may include additional source or binary content.

### Cross-segment symbols

For multi-segment projects:

- `ENT` marks a symbol exported by the current segment.
- `EXT` declares a symbol imported from another segment.

Guidelines:

- Use long addressing when crossing banks or working with OMF-loaded segments.
- External-label expressions must stay simple.
- Resolution happens during linking, so missing external symbols fail the overall build.

## Link Files

Merlin32 link files describe the structure of the final program rather than replaying classic Merlin link steps.

### Merlin 16+ vs Merlin32

Main differences:

- Merlin 16+ worked through separate object files and linker commands.
- Merlin32 assembles and links in one pass.
- Old Merlin 16+ link files are not directly reusable.
- `SAV` and `LNK` are effectively replaced by `DSK` plus Merlin32's link-file structure.
- If binary blobs are needed, Merlin32 expects them to come from source via `PUTBIN`.

### Common link-file conventions

- Link files use the same label/opcode/operand/comment style as source files.
- Comments can still start with `*` or `;`.
- The file is typically split into one program block and one or more segment or output-file blocks.

## Building Apple IIgs OMF Applications

For OMF output, the link file usually defines:

| Directive | Meaning |
| --- | --- |
| `DSK` | Output program name |
| `TYP` | OMF file type such as `S16`, `EXE`, `NDA`, `CDA`, etc. |
| `AUX` | ProDOS auxiliary type |
| `XPL` | Add the `~ExpressLoad` segment |
| `ASM` | Master source file for a segment |
| `DS` | Zero-fill size to append to the segment |
| `KND` | Segment kind and attribute bits |
| `ALI` | Alignment such as `NONE`, `PAGE`, or `BANK` |
| `BSZ` | Bank-size constraint |
| `ORG` | Load origin, or `0` for relocatable |
| `LNA` | Load name |
| `SNA` | Segment name |

### OMF notes

- Segment 1 is the entry segment.
- `KND` defaults to code plus static/bank-relative attributes.
- `ALI` defaults to `NONE`.
- `ORG 0` means relocatable.
- Small single-segment OMF projects can skip the link file and put `REL`, `DSK`, and `TYP` directly in the master source.
- Even then, the official docs recommend using a link file for clarity.

### Common OMF type aliases

Examples mentioned in the official docs include:

- `LIB`
- `S16`
- `RTL`
- `EXE`
- `PIF`
- `NDA`
- `CDA`
- `TOL`
- `DVR`
- `LDF`
- `FST`

## Building Fixed-Address Files

Fixed-address output is appropriate for systems that do not rely on dynamic relocation, such as:

- Apple II under DOS 3.3 or ProDOS 8
- Apple IIgs in fixed-load environments
- SNES-style workflows
- Other 65C816 systems with explicit memory placement

### Fixed-address link files

Each output file typically needs:

| Directive | Meaning |
| --- | --- |
| `TYP` | File type |
| `DSK` | Output path/name |
| `ORG` | Starting load address for the file |
| `ASM` | Master source file(s) |
| `SNA` | Optional segment name |

Notes:

- Several segments can be merged into one file.
- When segments are merged, only the first segment needs an explicit file-level `ORG`.
- Small one-segment projects can skip the link file and place `DSK`, `TYP`, and `ORG` in the master source file.

### File types

The original docs list many ProDOS/GSOS file type aliases. Common ones include:

- `BIN`
- `TXT`
- `SRC`
- `OBJ`
- `DOC`
- `PNT`
- `PIC`
- `FON`
- `CMD`
- `BAS`
- `SYS`
- `REL`

## Compatibility Notes

### Unsupported or deprecated Merlin 16+ features

The Merlin32 docs explicitly call out several Merlin 16+ commands as unsupported, ignored, or deprecated, especially commands tied to editor behavior, listing formatting, or older linker flow.

Examples include:

- `AST`
- `CYC`
- `EXP`
- `KBD`
- `LST`
- `LSTDO`
- `PAG`
- `PAU`
- `SW`
- `TTL`
- `SKP`
- `TR`
- `EXD` in favor of `EXT`
- `SAV` in favor of `DSK`
- `LNK` in favor of `DSK`

### String delimiter difference

Classic Merlin 16+ tolerated many delimiter characters. Merlin32 intentionally simplifies this:

- Only `'` and `"` are supported as string delimiters.

### Stricter parsing

Merlin32 is generally stricter than Merlin 16+:

- Invalid opcode spellings are rejected instead of being truncated.
- Forward references to `]local` labels are not allowed.
- Some `EQU`-driven source that assembled one way in Merlin 16+ may behave differently in Merlin32 because expression evaluation happens later and more explicitly.

## FAQ Highlights

The official page's FAQ for release 1.2 highlights these changes:

- Revised link-file format with mandatory `TYP`
- Better symbol-file output for CYRENE workflows
- Better handling of `BRL` across bank boundaries
- Improved error reporting for bad jumps
- Relative and absolute file paths for directives such as `ASM`, `DSK`, `PUT`, `PUTBIN`, and `USE`
- Longer output paths for `DSK`
- Deprecation of `SAV` and `LNK`
- Apple Silicon macOS support

The FAQ also notes:

- Source compatibility with Merlin 16+ is strong but not perfect.
- The source code is distributed in the downloadable package.
- The project is written in C and can be rebuilt for other platforms if needed.

## Practical Takeaways

- Prefer link files even for smaller projects.
- Use `REL` plus OMF output for GS/OS-style applications.
- Use `ORG`-based fixed-address output for ROM-style or ProDOS 8 style loading.
- Keep source structure simple: one master source per segment, with `PUT` and `PUTBIN` managed from there.
- Treat Merlin32 as strict Merlin syntax, not permissive legacy Merlin behavior.
- Use verbose output and symbol files when validating assembly behavior.

## Official References

The source page cites these references:

- Merlin 16+ documentation by Glen Bredon
- Apple IIgs GS/OS Reference, Appendix F: OMF 2.1
- Programming the 65816
- Le IIgs Epluche
- ORCA/M documentation

For official downloads and the original HTML manual, use the source page:

- [https://brutaldeluxe.fr/products/crossdevtools/merlin/](https://brutaldeluxe.fr/products/crossdevtools/merlin/)
