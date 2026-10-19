;==============================================================================
; ifconfig_sys.s - network interface table helpers + the SYS_IFCONFIG handler.
;
; The ifnet table is a Kmalloc'd soft-global reached via the DP long-pointer
; _ifTablePtr (dpmap.s); records are accessed [_ifTablePtr],Y by the IF_* field
; offsets in include/ifnet.s.  _AllocIfTable (main.s) allocated + zeroed it.
;
; T2 implements _Ifnet_Register (device-init).  _Ifnet_FindByIndex/ByName and
; _Sys_Ifconfig arrive in T4/T5 (where they are exercised).
;
; PUT by src/kernel/main.s.  Spec:
;   docs/superpowers/specs/2026-06-05-fgx-net-config-design.md
;==============================================================================

;------------------------------------------------------------------------------
; _Ifnet_Register - claim the first free ifnet record for a slot, derive its
; name + MAC, mark LINK_UP.
;
;   In:  A.lo = slot (1..7).  MX %00.
;   Out: X = record byte-offset into the table (0,32,64,96), or $FFFF if the
;        table is full.  MX %00.  Clobbers A, Y.
;
; Name = "u2s<slot>" (low-ASCII, NUL-padded to 8).  MAC = 00:08:DC:F6:00:<slot>
; (derived default; /etc/hwaddr.conf override is applied later by
; _Ifnet_LoadHwaddr, T3).  IP fields stay zero (set by DHCP / ifconfig).
; PHB/PHK/PLB so the _ifn* abs statics resolve under DBR=kernel-bank ($02 =
; assembly ORG) regardless of caller (feedback_kernel_helper_dbr_discipline);
; [_ifTablePtr],Y is DBR-independent.
;------------------------------------------------------------------------------
_Ifnet_Register MX      %00
                PHB
                PHK
                PLB                     ; DBR = kernel-bank for the _ifn* statics
                REP     #$30
                MX      %00
                AND     #$00FF
                STA     _ifnSlot        ; save slot

                ; --- find the first free record (IF_Name word = 0) ---
                LDY     #0              ; Y = record offset
@ir_find        LDA     [_ifTablePtr],Y ; Name[0..1] (16-bit); 0 == free
                BEQ     @ir_free
                TYA
                CLC
                ADC     #IF_REC_SIZE
                TAY
                CPY     #IFNET_BLK_SIZE
                BCC     @ir_find
                ; table full
                LDX     #$FFFF
                PLB
                RTS

@ir_free        STY     _ifnOff         ; record base offset (return value)
                ; --- fill the record (byte fields: M8, X16) ---
                SEP     #$20
                MX      %10
                ; Name = 'u' '2' 's' <digit> + NUL pad to 8
                LDA     #$75            ; 'u'
                STA     [_ifTablePtr],Y
                INY
                LDA     #$32            ; '2'
                STA     [_ifTablePtr],Y
                INY
                LDA     #$73            ; 's'
                STA     [_ifTablePtr],Y
                INY
                LDA     _ifnSlot        ; slot byte
                CLC
                ADC     #$30            ; -> ASCII digit '1'..'7'
                STA     [_ifTablePtr],Y
                INY
                LDA     #$00            ; Name[4..7] = NUL pad
                STA     [_ifTablePtr],Y
                INY
                STA     [_ifTablePtr],Y
                INY
                STA     [_ifTablePtr],Y
                INY
                STA     [_ifTablePtr],Y
                INY                     ; Y = offset + IF_Slot (8)
                LDA     _ifnSlot
                STA     [_ifTablePtr],Y ; IF_Slot
                INY                     ; Y = offset + IF_Mac (9)
                LDA     #$00            ; MAC[0]
                STA     [_ifTablePtr],Y
                INY
                LDA     #$08            ; MAC[1]
                STA     [_ifTablePtr],Y
                INY
                LDA     #$DC            ; MAC[2]
                STA     [_ifTablePtr],Y
                INY
                LDA     #$F6            ; MAC[3]
                STA     [_ifTablePtr],Y
                INY
                LDA     #$00            ; MAC[4]
                STA     [_ifTablePtr],Y
                INY
                LDA     _ifnSlot        ; MAC[5] = slot
                STA     [_ifTablePtr],Y
                INY                     ; Y = offset + IF_Flags (15)
                LDA     #IFF_LINK_UP
                STA     [_ifTablePtr],Y
                ; IP fields (16..31) remain zero from _AllocIfTable.
                REP     #$30
                MX      %00
                LDX     _ifnOff         ; X = record offset (return)
                PLB
                RTS

;------------------------------------------------------------------------------
; _Ifnet_FindBySlot - find the ifnet record whose IF_Slot == A.
;   In:  A.lo = slot.  MX %00.  Out: C=1 + X = record offset, or C=0.
;------------------------------------------------------------------------------
_Ifnet_FindBySlot MX    %00
                AND     #$00FF
                STA     _ifnSlotF
                LDY     #0
@fs_l           LDA     [_ifTablePtr],Y         ; Name word; 0 = empty record
                BEQ     @fs_skip
                PHY
                TYA
                CLC
                ADC     #IF_Slot
                TAY                             ; Y -> IF_Slot field
                SEP     #$20
                MX      %10
                LDA     [_ifTablePtr],Y         ; record slot byte
                CMP     _ifnSlotF
                BEQ     @fs_hit8
                REP     #$20
                MX      %00
                PLY
                BRA     @fs_skip
@fs_hit8        REP     #$20
                MX      %00
                PLY                             ; Y = record base
                TYA
                TAX                             ; X = record offset
                SEC
                RTS
@fs_skip        MX      %00
                TYA
                CLC
                ADC     #IF_REC_SIZE
                TAY
                CPY     #IFNET_BLK_SIZE
                BCC     @fs_l
                CLC
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
; and, if well-formed and a record matches the slot, overwrite its IF_Mac.
; '#'/blank/malformed lines are silently ignored (keep the derived default).
; MX %00.  DBR=kernel-bank (for the _ifhw*/_ifn* abs statics).
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
                LDA     _ifhwSlot               ; find record for this slot
                JSR     _Ifnet_FindBySlot
                BCC     @pl_bail
                TXA
                CLC
                ADC     #IF_Mac
                TAY                             ; Y = record MAC offset
                SEP     #$20
                MX      %10
                LDX     #0
@pl_wr          LDA:    _ifhwMac,X
                STA     [_ifTablePtr],Y
                INY
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
; _Ifnet_LoadHwaddr - read /etc/hwaddr.conf and apply per-slot MAC overrides to
; the ifnet records.  ENOENT (no file) is not an error.  Called at device-init,
; after _Ifnet_Register, before the SHAR write.  MX %00 in/out.
;------------------------------------------------------------------------------
_Ifnet_LoadHwaddr MX    %00
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
; _Ifnet_FindByIndex / _Ifnet_FindByName / _Ifc_CopyRecToIfr / _Ifc_LoadName /
; _Ifc_SetIpFields MOVED to net.mod (② net-mod reclaim, Phase 1) — they are the
; SYS_IFCONFIG read path, only called by the (now-moved) handler.  The scratch
; statics they use stay below (the module reaches them via the manifest).
;------------------------------------------------------------------------------
;==============================================================================
; _Sys_Ifconfig (SYS_IFCONFIG #70) MOVED to net.mod (src/modules/net/net.s as
; net_op_ifconfig), ② net-mod reclaim Phase 1.  The kernel keeps a dispatch
; thunk (_Sys_Ifconfig in net_dispatch.s) routing #70 into the module via
; _Net_Dispatch.  The ifconfig scratch statics below STAY kernel-side (the
; module reaches them DBR-relative via the gen_kernel_exports manifest), as
; does the boot-time iface registration (_Ifnet_Register / _Ifnet_LoadHwaddr /
; _Ifnet_FindBySlot, used by _Net_RegPrimary at boot).  The IFC_* read helpers
; (_Ifnet_FindByIndex/ByName, _Ifc_*) also moved to net.mod.
;==============================================================================

;------------------------------------------------------------------------------
; ifnet helper scratch (bounded module-local statics; syscall/boot context).
;------------------------------------------------------------------------------
_IFHW_LINE_MAX  EQU     64
_IFHW_BUF_MAX   EQU     64
_ifnSlot        DS      2               ; slot arg (low byte significant)
_ifnOff         DS      2               ; record base offset (return cache)
_ifnSlotF       DS      2               ; _Ifnet_FindBySlot target slot
_ifnIdx         DS      2               ; _Ifnet_FindByIndex target index
_ifnCount       DS      2               ; _Ifnet_FindByIndex running count
_ifnName        DS      8               ; _Ifnet_FindByName target name
_ifcOp          DS      2               ; SYS_IFCONFIG sub-op
_ifcRecOff      DS      2               ; _Ifc_CopyRecToIfr/_SetIpFields record offset
_ifcTmpW        DS      2               ; _Ifc_SetIpFields word scratch
_ifhwFd         DS      2               ; /etc/hwaddr.conf open fd
_ifhwBuf        DS      _IFHW_BUF_MAX   ; read-ahead window, refilled by
_ifhwBufLen     DS      2               ;   _ifhw_getByte; Len = bytes held,
_ifhwBufIdx     DS      2               ;   Idx = how many handed out
_ifhwLine       DS      _IFHW_LINE_MAX  ; current line buffer
_ifhwLen        DS      2               ; current line length
_ifhwSlot       DS      2               ; parsed slot
_ifhwMac        DS      8               ; parsed MAC (6 + pad)
_ifhwTmp        DS      2               ; hex-byte scratch
