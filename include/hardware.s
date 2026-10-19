;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     hardware.s
; Purpose:  Apple IIgs hardware equates and constants
; Author:   FGX Development Team
; Created:  2025-02-01
;
; This file contains all hardware-related equates for the Apple IIgs,
; including memory-mapped I/O addresses, soft switches, and hardware
; constants. Organized by subsystem for easy reference.
;
;==============================================================================

;==============================================================================
; MEMORY MAP - GENERAL
;==============================================================================

; Bank boundaries
HW_BANK_ZERO    EQU     $00             ; System bank (DP, stacks)
HW_BANK_IO      EQU     $E0             ; I/O and SHR bank
HW_BANK_SHR     EQU     $E1             ; SHR graphics bank
HW_BANK_ROM     EQU     $F0             ; Start of ROM banks

; Key addresses in bank $00
HW_RESET_VEC    EQU     $00FFFC         ; Reset vector
HW_IRQ_VEC      EQU     $00FFFE         ; IRQ vector (emulation mode)
HW_NMI_VEC      EQU     $00FFFA         ; NMI vector
HW_COP_VEC      EQU     $00FFF4         ; COP vector (native mode)
HW_BRK_VEC      EQU     $00FFE6         ; BRK vector (native mode).  Was $FFF6,
                                        ; which is the unused EMULATION slot --
                                        ; nothing referenced it, so the error
                                        ; sat here as a trap rather than a bug.
                                        ; Measured: apple/fgx#305's runaway BRK
                                        ; landed at $00:0000 because $00:FFE6
                                        ; reads $0000.

;==============================================================================
; SOFT SWITCHES - MEMORY
;==============================================================================

; Language card / bank switching
HW_LCBANK2_RD   EQU     $C080           ; Read LC bank 2, write-protect
HW_LCBANK2_RW   EQU     $C081           ; Read LC bank 2, write-enable
HW_ROMIN_RD     EQU     $C082           ; Read ROM, write-protect LC
HW_LCBANK2_RWX  EQU     $C083           ; Read LC bank 2, write-enable (x2)
HW_LCBANK1_RD   EQU     $C088           ; Read LC bank 1, write-protect
HW_LCBANK1_RW   EQU     $C089           ; Read LC bank 1, write-enable
HW_ROMIN_RW     EQU     $C08A           ; Read ROM, write-protect LC
HW_LCBANK1_RWX  EQU     $C08B           ; Read LC bank 1, write-enable (x2)

; Auxiliary memory (IIe compatibility)
HW_80STORE_OFF  EQU     $C000           ; Disable 80STORE
HW_80STORE_ON   EQU     $C001           ; Enable 80STORE
HW_RDMAINRAM    EQU     $C002           ; Read main RAM
HW_RDAUXRAM     EQU     $C003           ; Read aux RAM
HW_WRMAINRAM    EQU     $C004           ; Write main RAM
HW_WRAUXRAM     EQU     $C005           ; Write aux RAM

; Memory state reads
HW_RDLCBNK2     EQU     $C011           ; Read: LC bank 2 selected?
HW_RDLCRAM      EQU     $C012           ; Read: LC RAM selected?
HW_RDRAMRD      EQU     $C013           ; Read: aux RAM read enabled?
HW_RDRAMWRT     EQU     $C014           ; Read: aux RAM write enabled?

;==============================================================================
; SOFT SWITCHES - VIDEO
;==============================================================================

; Video mode switches
HW_80COL_OFF    EQU     $C00C           ; Disable 80-column mode
HW_80COL_ON     EQU     $C00D           ; Enable 80-column mode
HW_ALTCHAR_OFF  EQU     $C00E           ; Normal character set
HW_ALTCHAR_ON   EQU     $C00F           ; Alternate character set

HW_TEXT_OFF     EQU     $E0C050         ; Graphics mode
HW_TEXT_ON      EQU     $E0C051         ; Text mode
HW_MIXED_OFF    EQU     $E0C052         ; Full screen
HW_MIXED_ON     EQU     $E0C053         ; Mixed text/graphics
HW_PAGE1        EQU     $E0C054         ; Display page 1
HW_PAGE2        EQU     $E0C055         ; Display page 2
HW_LORES        EQU     $E0C056         ; Lo-res graphics
HW_HIRES        EQU     $E0C057         ; Hi-res graphics

; IIgs-specific video (bank $E0 for reliable I/O access in native mode)
HW_NEWVIDEO     EQU     $E0C029         ; New video register (IIgs)
                                        ; Bit 7: SHR enable
                                        ; Bit 6: Linearize SHR memory
                                        ; Bit 5: SHR bank latch enable
                                        ; Bits 0-4: Border color (0-15)

; Mega II video counters (Apple IIgs Tech Note #39). 16-bit beam-position
; counter = 7-bit horizontal + 9-bit vertical.  $C02E = vertical bits V1..V8
; (high 8 of 9); $C02F bit 7 = vertical LSB (VA/V0), bits 6-0 = horizontal.
; Vertical V ranges $FA..$1FF (NTSC, 262 lines); V=$100 is SHR scan line 0;
; V increments every 63.7 us (one scan line).  VBL IRQ fires at scan line 192
; (V=$1C0), the same instant _kSystemTicks ticks.  Used for the hi-res timer
; (frame*262 + intra-frame scanline).  Read low byte of V:  LDAL HW_HORIZCNT /
; asl a / LDAL HW_VERTCNT / rol a  (TN #39 example).  ★Use LDAL (long): these
; live in bank $E0, which is NOT the DBR (= live kernel bank) during kernel
; execution, so a plain LDA abs reads $<kbank>:C02E/F RAM and returns V=0.
HW_VERTCNT      EQU     $E0C02E         ; vertical counter, bits V1..V8
HW_HORIZCNT     EQU     $E0C02F         ; bit7 = vertical LSB (V0); bits6-0 = horizontal

; NEWVIDEO bit masks
NEWVID_SHR      EQU     %10000000       ; Enable Super HiRes
NEWVID_LINEAR   EQU     %01000000       ; Linearize SHR memory
NEWVID_BANKLATCH EQU    %00100000       ; Bank latch enable
NEWVID_BORDER   EQU     %00011111       ; Border color mask

; FGX NEWVIDEO setting: SHR enabled, black border
FGX_NEWVIDEO    EQU     %10000000       ; $80 - SHR on, border=0 (black)

HW_STATEREG     EQU     $E0C068         ; State register
                                        ; Bit 0: INTCXROM
                                        ; Bit 1: ROMBANK
                                        ; Bit 2: LCBNK2
                                        ; Bit 3: RDROM
                                        ; Bit 4: RAMWRT
                                        ; Bit 5: RAMRD
                                        ; Bit 6: PAGE2
                                        ; Bit 7: ALTZP

HW_SHADOW       EQU     $E0C035         ; Shadow register
                                        ; Bit 0: Inhibit Text/LoRes shadowing
                                        ; Bit 1: Inhibit HiRes Page 1 shadowing
                                        ; Bit 2: Inhibit HiRes Page 2 shadowing
                                        ; Bit 3: Inhibit Super HiRes shadowing
                                        ; Bit 4: Inhibit Aux HGR shadowing
                                        ; Bit 5: Inhibit Alt Display Mode
                                        ; Bit 6: Inhibit I/O/LC shadowing

; Shadow register bit masks
SHADOW_TEXT     EQU     %00000001       ; Inhibit Text/LoRes
SHADOW_HIRES1   EQU     %00000010       ; Inhibit HiRes Page 1
SHADOW_HIRES2   EQU     %00000100       ; Inhibit HiRes Page 2
SHADOW_SHR      EQU     %00001000       ; Inhibit Super HiRes
SHADOW_AUXHGR   EQU     %00010000       ; Inhibit Aux HGR
SHADOW_ALTDISP  EQU     %00100000       ; Inhibit Alt Display Mode
SHADOW_IOLC     EQU     %01000000       ; Inhibit I/O/LC

; FGX shadow setting: inhibit IIe shadowing but KEEP SHR shadowing
; This allows writes to $01/2000 to shadow to $E1/2000
FGX_SHADOW      EQU     %01110111       ; $77 - inhibit all EXCEPT SHR (bit 3=0)

HW_CYAREG       EQU     $E0C036         ; CYA (system speed) register
                                        ; Bit 0-3: Disk motor detect
                                        ; Bit 4: Shadow all banks
                                        ; Bit 5: (reserved)
                                        ; Bit 6: (reserved)
                                        ; Bit 7: 1=fast (2.8MHz), 0=slow (1MHz)

; CYA register bit masks
CYA_SHADOWALL   EQU     %00010000       ; Shadow all banks (dangerous!)
CYA_FAST        EQU     %10000000       ; Fast mode (2.8+ MHz)

; FGX CYA setting: fast mode, no shadow-all
FGX_CYAREG      EQU     %10000000       ; $80 - fast mode only

; Vertical blank
HW_VBL          EQU     $E0C019         ; Vertical blank status
                                        ; Bit 7: 1=VBL active
HW_RDVBLBAR     EQU     $E0C019         ; Same as above

;==============================================================================
; SUPER HIGH RESOLUTION (SHR)
;==============================================================================

; SHR memory addresses (in bank $E1)
SHR_SCREEN      EQU     $E12000         ; Start of SHR pixel data
SHR_SCB         EQU     $E19D00         ; Scanline Control Bytes
SHR_PALETTES    EQU     $E19E00         ; Color palettes

; SHR screen dimensions
SHR_WIDTH_640   EQU     640             ; Pixels wide in 640 mode
SHR_WIDTH_320   EQU     320             ; Pixels wide in 320 mode
SHR_HEIGHT      EQU     200             ; Scanlines
SHR_BPL_640     EQU     160             ; Bytes per line (640 mode)
SHR_BPL_320     EQU     160             ; Bytes per line (320 mode)
SHR_SCREEN_SIZE EQU     32000           ; Total screen bytes (200 * 160)

; SCB bit definitions
SCB_MODE_320    EQU     %00000000       ; 320 mode (bit 7 = 0)
SCB_MODE_640    EQU     %10000000       ; 640 mode (bit 7 = 1)
SCB_FILL        EQU     %01000000       ; Fill mode enable (bit 6)
SCB_INTERRUPT   EQU     %00100000       ; Interrupt on scanline (bit 5)
SCB_PAL_MASK    EQU     %00001111       ; Palette number mask (bits 0-3)

; Palette structure
; Each palette has 16 colors, each color is 2 bytes (4 bits each: R, G, B)
; Palette byte format: xxxxRRRR GGGGBBBB (little-endian: low byte first)
SHR_PAL_SIZE    EQU     32              ; Bytes per palette (16 colors * 2)
SHR_NUM_PALS    EQU     16              ; Number of palettes

; Common colors (12-bit RGB, stored as $0RGB)
SHR_BLACK       EQU     $0000           ; Black
SHR_WHITE       EQU     $0FFF           ; White
SHR_RED         EQU     $0F00           ; Red
SHR_GREEN       EQU     $00F0           ; Green
SHR_BLUE        EQU     $0009           ; Blue ($000099 — IIgs system blue)
SHR_YELLOW      EQU     $0FF0           ; Yellow
SHR_CYAN        EQU     $00FF           ; Cyan
SHR_MAGENTA     EQU     $0F0F           ; Magenta
SHR_DGRAY       EQU     $0555           ; Dark gray
SHR_LGRAY       EQU     $0AAA           ; Light gray
SHR_DKGRAY      EQU     $0333           ; Darker gray (for background)

;==============================================================================
; KEYBOARD
;==============================================================================

HW_KEYBOARD     EQU     $C000           ; Keyboard data
                                        ; Bit 7: Key pressed (strobe)
                                        ; Bits 0-6: ASCII code
HW_KBDSTROBE    EQU     $C010           ; Clear keyboard strobe

HW_ANYKEY       EQU     $C010           ; Any key down status

; Special key codes
KEY_RETURN      EQU     $8D             ; Return/Enter
KEY_ESC         EQU     $9B             ; Escape
KEY_LEFT        EQU     $88             ; Left arrow
KEY_RIGHT       EQU     $95             ; Right arrow
KEY_UP          EQU     $8B             ; Up arrow
KEY_DOWN        EQU     $8A             ; Down arrow
KEY_DELETE      EQU     $FF             ; Delete
KEY_TAB         EQU     $89             ; Tab
KEY_SPACE       EQU     $A0             ; Space

;==============================================================================
; APPLE DESKTOP BUS (ADB)
;==============================================================================

; ADB registers
ADB_DATA        EQU     $C026           ; ADB data register
ADB_STATUS      EQU     $C027           ; ADB status register
                                        ; Bit 7: Mouse data pending
                                        ; Bit 6: Interrupt pending
                                        ; Bit 5: Data valid
                                        ; Bit 4: Mouse button
                                        ; Bit 3: Command/data
                                        ; Bit 2: ADB busy
                                        ; Bit 1: Autoincrement
                                        ; Bit 0: Command complete

; ADB commands
ADB_CMD_RESET   EQU     $00             ; Reset ADB bus
ADB_CMD_FLUSH   EQU     $01             ; Flush device
ADB_CMD_LISTEN  EQU     $08             ; Listen command base
ADB_CMD_TALK    EQU     $0C             ; Talk command base

; ADB device addresses
ADB_ADDR_KBD    EQU     $02             ; Keyboard
ADB_ADDR_MOUSE  EQU     $03             ; Mouse

;==============================================================================
; ENSONIQ DOC (SOUND)
;==============================================================================

; DOC registers (via GLU)
DOC_DATA        EQU     $C03C           ; DOC data register
DOC_ADDR_LO     EQU     $C03D           ; DOC address low
DOC_ADDR_HI     EQU     $C03E           ; DOC address high
DOC_CTRL        EQU     $C03F           ; DOC control
                                        ; Bit 7: Read/write (1=read)
                                        ; Bit 6: Auto-increment
                                        ; Bit 5: Volume control
                                        ; Bits 0-4: Reserved

; DOC internal registers (addressed via DOC_ADDR)
DOC_OSC_FREQ_LO EQU     $00             ; Oscillator frequency low (per osc)
DOC_OSC_FREQ_HI EQU     $20             ; Oscillator frequency high
DOC_OSC_VOL     EQU     $40             ; Oscillator volume
DOC_OSC_DATA    EQU     $60             ; Oscillator wavetable pointer
DOC_OSC_CTRL    EQU     $80             ; Oscillator control
DOC_OSC_SIZE    EQU     $A0             ; Oscillator wavetable size

; DOC control register bits
DOC_CTRL_FREE   EQU     %00000001       ; Free-run mode
DOC_CTRL_ONESHOT EQU    %00000010       ; One-shot mode
DOC_CTRL_SYNC   EQU     %00000100       ; Sync mode
DOC_CTRL_SWAP   EQU     %00001000       ; Swap mode

; Sound RAM (64KB in bank $E1)
SOUND_RAM       EQU     $E10000         ; Start of sound RAM
SOUND_RAM_SIZE  EQU     $10000          ; 64KB

;==============================================================================
; DISK / SMARTPORT
;==============================================================================

; SmartPort entry (varies by slot, this is for slot 5)
; Actual entry point is at $Cn00 where n = slot number
SMARTPORT_SLOT5 EQU     $C500           ; Slot 5 firmware
SMARTPORT_SLOT6 EQU     $C600           ; Slot 6 firmware (typically disk)

; SmartPort command codes
SP_CMD_STATUS   EQU     $00             ; Get device status
SP_CMD_READBLK  EQU     $01             ; Read block
SP_CMD_WRITEBLK EQU     $02             ; Write block
SP_CMD_FORMAT   EQU     $03             ; Format device
SP_CMD_CONTROL  EQU     $04             ; Control command
SP_CMD_INIT     EQU     $05             ; Initialize device
SP_CMD_OPEN     EQU     $06             ; Open device
SP_CMD_CLOSE    EQU     $07             ; Close device
SP_CMD_READ     EQU     $08             ; Read bytes
SP_CMD_WRITE    EQU     $09             ; Write bytes

; SmartPort error codes
SP_ERR_NONE     EQU     $00             ; No error
SP_ERR_BADCMD   EQU     $01             ; Invalid command
SP_ERR_BADPCNT  EQU     $02             ; Invalid parameter count
SP_ERR_IOERR    EQU     $27             ; I/O error
SP_ERR_NODRIVE  EQU     $28             ; No drive connected
SP_ERR_WPROT    EQU     $2B             ; Write protected
SP_ERR_BADBLK   EQU     $2D             ; Invalid block number

; Disk constants
DISK_BLOCK_SIZE EQU     512             ; Bytes per block
DISK_BLOCKS_800K EQU    1600            ; Blocks on 800K floppy

;==============================================================================
; SLOTS AND EXPANSION
;==============================================================================

; Slot I/O space
HW_SLOT_IO      EQU     $C080           ; Slot I/O base ($C0n0 for slot n)
HW_SLOT_ROM     EQU     $C100           ; Slot ROM base ($Cn00 for slot n)
HW_SLOT_EXPROM  EQU     $C800           ; Expansion ROM (shared)

; Slot number extraction
SLOT_SHIFT      EQU     4               ; Shift for slot number in address

;==============================================================================
; INTERRUPTS
;==============================================================================

; Interrupt status/control
HW_INTFLAG      EQU     $C023           ; Interrupt flag register (IIgs)
                                        ; Bit 7: Any interrupt pending
                                        ; Bit 6: VBL interrupt
                                        ; Bit 5: Quarter-second interrupt
                                        ; Bit 4: Keyboard interrupt
                                        ; Bit 3: Scan-line interrupt
                                        ; Bit 2: External VGC interrupt
                                        ; Bit 1: ADB data interrupt
                                        ; Bit 0: ADB service request

HW_INTENABLE    EQU     $C041           ; Interrupt enable register (Mega II)
                                        ; Bit 3: Enable 1-second interrupt
                                        ; Bit 4: Enable VBL interrupt

; VGC interrupt control
HW_VGCINT       EQU     $C032           ; VGC interrupt control
                                        ; Bit 3: Clear scan-line interrupt
                                        ; Bit 4: Enable scan-line interrupt
                                        ; Bit 5: Enable second interrupt

;==============================================================================
; SYSTEM SPEED
;==============================================================================

; Speed control
HW_SPEED        EQU     $C036           ; System speed register
                                        ; Bit 7: 1=fast, 0=slow
                                        ; (HW_STATEREG defined above at $C068)

; Speed constants
SPEED_SLOW      EQU     %00000000       ; 1 MHz (IIe compatibility)
SPEED_FAST      EQU     %10000000       ; 2.8 MHz (native)
; Note: Accelerators (ZipGS, TransWarp) can run faster

;==============================================================================
; MISCELLANEOUS
;==============================================================================

; ROM identification
HW_ROMID        EQU     $FBB3           ; ROM version byte
ROMID_01        EQU     $FE             ; ROM 01
ROMID_03        EQU     $00             ; ROM 03

; Battery RAM / Real-time clock
HW_BRAM         EQU     $C033           ; Battery RAM data
HW_BREG         EQU     $C034           ; Battery RAM address

; Paddle / Joystick
HW_PADDLE0      EQU     $C064           ; Paddle 0 value
HW_PADDLE1      EQU     $C065           ; Paddle 1 value
HW_PADDLE2      EQU     $C066           ; Paddle 2 value
HW_PADDLE3      EQU     $C067           ; Paddle 3 value
HW_PADDLETRIG   EQU     $C070           ; Trigger paddle read

HW_BUTTON0      EQU     $C061           ; Button 0 (open apple)
HW_BUTTON1      EQU     $C062           ; Button 1 (closed apple)
HW_BUTTON2      EQU     $C063           ; Button 2

; Speaker
HW_SPEAKER      EQU     $C030           ; Toggle speaker

; Annunciators (active low)
HW_ANNUNC0_OFF  EQU     $C058           ; Annunciator 0 off
HW_ANNUNC0_ON   EQU     $C059           ; Annunciator 0 on
HW_ANNUNC1_OFF  EQU     $C05A           ; Annunciator 1 off
HW_ANNUNC1_ON   EQU     $C05B           ; Annunciator 1 on
HW_ANNUNC2_OFF  EQU     $C05C           ; Annunciator 2 off
HW_ANNUNC2_ON   EQU     $C05D           ; Annunciator 2 on
HW_ANNUNC3_OFF  EQU     $C05E           ; Annunciator 3 off
HW_ANNUNC3_ON   EQU     $C05F           ; Annunciator 3 on

;==============================================================================
; END OF FILE
;==============================================================================
