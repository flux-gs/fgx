;==============================================================================
; hwaddr.s - the Uthernet II's Ethernet address: derived from its slot, and
; overridden by /etc/hwaddr.conf (hwaddr.conf(5)).
;
; The address is one cell, _u2Mac, with the slot it was derived for in
; _u2MacSlot.  uthernet.s derives it at the card's probe, applies the file, logs
; it and writes it to the chip's SHAR, which is where the network modules' w5
; driver reads it at attach (if_w5.c) to give wz0 its link-level address.
;
; PUT by src/kernel/main.s.
;==============================================================================

;------------------------------------------------------------------------------
; _Net_DeriveMac - _u2Mac = 00:08:DC:F6:00:<slot>, the derived default.
;
;   In:  A.lo = slot (1..7).  MX %00.  Out: MX %00.  Clobbers A.
;------------------------------------------------------------------------------
_Net_DeriveMac  MX      %00
                PHB
                PHK
                PLB                     ; DBR = kernel bank for the statics
                AND     #$00FF
                STA     _u2MacSlot
                SEP     #$20
                MX      %10
                STA     _u2Mac+5        ; MAC[5] = slot
                LDA     #$00
                STA     _u2Mac+0
                STA     _u2Mac+4
                LDA     #$08
                STA     _u2Mac+1
                LDA     #$DC
                STA     _u2Mac+2
                LDA     #$F6
                STA     _u2Mac+3
                REP     #$20
                MX      %00
                PLB
                RTS

;------------------------------------------------------------------------------
; _ifhw_hexNib - ASCII hex digit (A.lo) -> nibble (A.lo).  C=1 ok / C=0 not hex.
; MX %00.
;------------------------------------------------------------------------------
_ifhw_hexNib    MX      %00
                CMP     #'0'
                BCC     @hn_bad
                CMP     #'9'+1
                BCC     @hn_dig
                ORA     #$20                    ; fold to lower-case
                CMP     #'a'
                BCC     @hn_bad
                CMP     #'f'+1
                BCS     @hn_bad
                SEC
                SBC     #'a'-10                 ; a..f -> 10..15
                SEC
                RTS
@hn_dig         SEC
                SBC     #'0'                    ; 0..9
                SEC
                RTS
@hn_bad         CLC
                RTS

;------------------------------------------------------------------------------
; _ifhw_hexByte - parse 2 hex digits at _ifhwLine[X] -> A.lo byte.  Advances X
; by 2.  C=1 ok / C=0 malformed.  MX %00.
;------------------------------------------------------------------------------
_ifhw_hexByte   MX      %00
                CPX     _ifhwLen
                BCS     @hb_bad
                LDA:    _ifhwLine,X
                AND     #$00FF
                JSR     _ifhw_hexNib
                BCC     @hb_bad
                ASL
                ASL
                ASL
                ASL                             ; hi nibble << 4
                STA     _ifhwTmp
                INX
                CPX     _ifhwLen
                BCS     @hb_bad
                LDA:    _ifhwLine,X
                AND     #$00FF
                JSR     _ifhw_hexNib
                BCC     @hb_bad
                ORA     _ifhwTmp
                INX
                SEC
                RTS
@hb_bad         CLC
                RTS

;------------------------------------------------------------------------------
; _ifhw_parseLine - parse "_ifhwLine[0.._ifhwLen]" = "<slot> aa:bb:cc:dd:ee:ff"
; and, if well-formed and its slot is the card's, overwrite _u2Mac.
; '#'/blank/malformed lines are silently ignored (keep the derived default).
; MX %00.  DBR=kernel-bank (for the _ifhw* and _u2Mac abs statics).
;------------------------------------------------------------------------------
_ifhw_parseLine MX      %00
                LDX     #0
@pl_skip1       CPX     _ifhwLen
                BCS     @pl_bail
                LDA:    _ifhwLine,X
                AND     #$00FF
                CMP     #'#'
                BEQ     @pl_bail
                CMP     #' '
                BEQ     @pl_adv1
                CMP     #$09
                BEQ     @pl_adv1
                BRA     @pl_slot
@pl_adv1        INX
                BRA     @pl_skip1
@pl_slot        LDA:    _ifhwLine,X             ; slot digit
                AND     #$00FF
                CMP     #'0'
                BCC     @pl_bail
                CMP     #'9'+1
                BCS     @pl_bail
                SEC
                SBC     #'0'
                STA     _ifhwSlot
                INX
@pl_skip2       CPX     _ifhwLen                ; skip WS before the MAC
                BCS     @pl_bail
                LDA:    _ifhwLine,X
                AND     #$00FF
                CMP     #' '
                BEQ     @pl_adv2
                CMP     #$09
                BEQ     @pl_adv2
                BRA     @pl_mac
@pl_adv2        INX
                BRA     @pl_skip2
@pl_bail        MX      %00                     ; common exit (mid-routine: keeps
                RTS                             ; all bail branches in range)
@pl_mac         MX      %00
                LDY     #0                      ; octet index 0..5
@pl_octet       JSR     _ifhw_hexByte           ; A=byte, X+=2, C=1 ok
                BCC     @pl_bail
                PHY
                SEP     #$20
                MX      %10
                STA:    _ifhwMac,Y
                REP     #$20
                MX      %00
                PLY
                INY
                CPY     #6
                BCS     @pl_apply
                CPX     _ifhwLen                ; expect ':' separator
                BCS     @pl_bail
                LDA:    _ifhwLine,X
                AND     #$00FF
                CMP     #':'
                BNE     @pl_bail
                INX
                BRA     @pl_octet
@pl_apply       MX      %00
                LDA     _ifhwSlot               ; this card's slot?
                CMP     _u2MacSlot
                BNE     @pl_bail
                SEP     #$20
                MX      %10
                LDX     #0
@pl_wr          LDA:    _ifhwMac,X
                STA:    _u2Mac,X
                INX
                CPX     #6
                BCC     @pl_wr
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _ifhw_getByte - hand out the next byte of /etc/hwaddr.conf, refilling the
; window when it runs dry.
;
; THE READ CROSSES TO THE VFS, and it has to: `Fs_Read' answers EBADF for every
; descriptor -- it gates on `FCB_StorageType', which prodos.mod was the only
; writer of -- so the per-byte loop this replaces read nothing and the caller
; took the EBADF for end-of-file.  /etc/hwaddr.conf was silently ignored
; (apple/fgx#356).  `_Sys_DevRead' is the core bank's door to `vfs_read' and is
; what every read(2) of a file already goes through.
;
; `_Sys_CallerBank' IS THE BUFFER'S BANK for that call, and writing it here is
; safe because this runs at BOOT, from `_ProbeUthernet2', with no syscall in
; flight -- pid 0 is still the only task and init has not been spawned.  The
; root is mounted well before this: `root_mount' is main.s:697 and the probe is
; main.s:863.
;
; In:  _ifhwFd open.  MX %00, DBR = kernel bank.
; Out: C=1 + A = the byte, or C=0 at end of file (or on any read error, which
;      is the same thing to the caller: the overrides it has are what it gets).
;------------------------------------------------------------------------------
_ifhw_getByte   MX      %00
                LDA     _ifhwBufIdx
                CMP     _ifhwBufLen
                BCC     @gb_have                ; window still holds bytes
                ; Refill.  A short count is not an error -- vfs_read returns
                ; what is left -- and zero means end of file.
                SEP     #$20
                MX      %10
                _BANKK
                STA     _Sys_CallerBank         ; the window is in THIS bank
                REP     #$30
                MX      %00
                LDA     _ifhwFd
                AND     #$00FF
                LDX     #_ifhwBuf
                LDY     #_IFHW_BUF_MAX
                JSR     _Sys_DevRead            ; C=1 + A = bytes, C=0 + A = errno
                BCC     @gb_eof
                AND     #$00FF
                BEQ     @gb_eof
                STA     _ifhwBufLen
                STZ     _ifhwBufIdx
@gb_have        LDX     _ifhwBufIdx
                SEP     #$20
                MX      %10
                LDA:    _ifhwBuf,X
                REP     #$30
                MX      %00
                AND     #$00FF
                PHA
                LDA     _ifhwBufIdx
                INC
                STA     _ifhwBufIdx
                PLA
                SEC
                RTS
@gb_eof         REP     #$30
                MX      %00
                LDA     #0
                CLC
                RTS

;------------------------------------------------------------------------------
; _Net_LoadHwaddr - read /etc/hwaddr.conf and apply the card's slot's line to
; _u2Mac.  ENOENT (no file) is not an error.  Called at device-init, after
; _Net_DeriveMac, before the SHAR write.  MX %00 in/out.
;------------------------------------------------------------------------------
_Net_LoadHwaddr MX      %00
                PHP
                REP     #$30
                MX      %00
                PHB
                PHK
                PLB                             ; DBR=kernel-bank for the _ifhw* statics
                LDX     #_ifhwPath
                JSR     Fs_Open
                BCC     @lh_done                ; no file -> all derived
                AND     #$00FF
                STA     _ifhwFd
                STZ     _ifhwBufLen             ; window empty: first getByte fills
                STZ     _ifhwBufIdx
@lh_lineStart   STZ     _ifhwLen
@lh_charL       JSR     _ifhw_getByte           ; C=1+A=byte; C=0 = end of file
                BCC     @lh_eof
                AND     #$00FF
                CMP     #$000A
                BEQ     @lh_eol
                CMP     #$000D
                BEQ     @lh_eol
                LDX     _ifhwLen                ; append to line buffer if room
                CPX     #_IFHW_LINE_MAX-1
                BCS     @lh_charL
                SEP     #$20                    ; A.lo already = the char byte
                MX      %10
                STA:    _ifhwLine,X
                REP     #$20
                MX      %00
                LDA     _ifhwLen
                INC
                STA     _ifhwLen
                BRA     @lh_charL
@lh_eol         JSR     _ifhw_parseLine
                BRA     @lh_lineStart
@lh_eof         LDA     _ifhwFd
                AND     #$00FF
                JSR     Fs_Close
                LDA     _ifhwLen                ; parse a final line w/o newline
                BEQ     @lh_done
                JSR     _ifhw_parseLine
@lh_done        PLB
                PLP
                RTS

_ifhwPath       ASC     '/etc/hwaddr.conf',00

;------------------------------------------------------------------------------
; The address, and the file reader's scratch (boot context).
;------------------------------------------------------------------------------
_IFHW_LINE_MAX  EQU     64
_IFHW_BUF_MAX   EQU     64
_u2Mac          DS      6               ; the card's Ethernet address
_u2MacSlot      DS      2               ; the slot it was derived for
_ifhwFd         DS      2               ; /etc/hwaddr.conf open fd
_ifhwBuf        DS      _IFHW_BUF_MAX   ; read-ahead window, refilled by
_ifhwBufLen     DS      2               ;   _ifhw_getByte; Len = bytes held,
_ifhwBufIdx     DS      2               ;   Idx = how many handed out
_ifhwLine       DS      _IFHW_LINE_MAX  ; current line buffer
_ifhwLen        DS      2               ; current line length
_ifhwSlot       DS      2               ; parsed slot
_ifhwMac        DS      8               ; parsed MAC (6 + pad)
_ifhwTmp        DS      2               ; hex-byte scratch
