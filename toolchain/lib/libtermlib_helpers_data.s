;==============================================================================
; libtermlib_helpers_data.s - the baked termcap entries libtermlib_helpers.s
; reads DBR-relative: the IIgs SHR console ("fgx") and a remote ANSI/vt102
; terminal.  termlib's (2.11BSD libtermlib: tgetent), PUT into the data
; segment of every program that links termlib.
;==============================================================================

pf_tmpByte      DA      0                       ; libtermlib_helpers.s scratch

;------------------------------------------------------------------------------
; Baked "fgx" termcap tables.
;
; String table entry: 2-byte name + 2-byte own-bank pointer.
; Number table entry: 2-byte name + 2-byte value.
; Flag table entry:   2-byte name.
; Sentinel: 2 NUL bytes at start of next entry.
;------------------------------------------------------------------------------
tc_str_table    ASC     'cm'
                DA      tc_cm
                ASC     'cl'
                DA      tc_cl
                ASC     'ce'
                DA      tc_ce
                ASC     'up'
                DA      tc_up
                ASC     'do'
                DA      tc_do
                ASC     'le'
                DA      tc_le
                ASC     'nd'
                DA      tc_nd
                ASC     'so'
                DA      tc_so
                ASC     'se'
                DA      tc_se
                ASC     'us'
                DA      tc_us
                ASC     'ue'
                DA      tc_ue
                ASC     'md'
                DA      tc_md
                ASC     'me'
                DA      tc_me
                ASC     'mr'                     ; reverse-video on (== so)
                DA      tc_mr
                ASC     'AF'                     ; set ANSI fg colour (parameterised)
                DA      tc_AF
                ASC     'AB'                     ; set ANSI bg colour (parameterised)
                DA      tc_AB
                ASC     'op'                     ; restore default fg+bg pair
                DA      tc_op
                ASC     'cd'                     ; clear to end of display (ED)
                DA      tc_cd
                ASC     'cs'                     ; change scroll region (DECSTBM)
                DA      tc_cs
                ASC     'sr'                     ; scroll reverse 1 line (RI)
                DA      tc_sr
                ASC     'ti'                     ; enter ca mode (alt-screen)
                DA      tc_ti
                ASC     'te'                     ; exit ca mode (alt-screen)
                DA      tc_te
                ASC     'ku'                     ; up-arrow key sends ESC[A
                DA      tc_up
                ASC     'kd'                     ; down-arrow key sends ESC[B
                DA      tc_do
                ASC     'kr'                     ; right-arrow key sends ESC[C
                DA      tc_nd
                ASC     'kl'                     ; left-arrow key sends ESC[D
                DA      tc_kl
                DFB     0,0,0,0                  ; sentinel (entry-sized)

tc_num_table    ASC     'co'
                DA      80
                ASC     'li'
                DA      25                       ; SHR console paints 25 visible rows
                ASC     'Co'                     ; colours: 8 ANSI codes -> 4-colour row palette
                DA      8
                DFB     0,0,0,0

tc_flag_table   ASC     'am'                     ; auto-margin
                ASC     'bs'                     ; backspace
                DFB     0,0                      ; sentinel

;------------------------------------------------------------------------------
; SECOND ENTRY: a REMOTE ansi/vt102 terminal (apple/fgx#147).
;
; Until now tgetent() returned 1 for any TERM and every cap came from the one
; entry above -- which describes the IIgs SHR CONSOLE.  Driving a real
; xterm/Terminal.app with it is wrong in a way that shows the moment a line is
; written to its last column:
;
;   the console wraps IMMEDIATELY when the last column is written (am, no xn);
;   an xterm DEFERS the wrap and leaves the cursor AT the margin (am AND xn).
;
; elvis asks exactly that question -- curses.c:613,
;   AM = (tgetflag("am") && !tgetflag("xn"))
; -- so with xn missing it believed the wrap had already happened, started the
; next line, and the following line's first characters landed at the right edge
; instead.  Reported over telnet as comments "pushed over to the screen border
; on the right hand side" once NAWS made full-width writes routine.
;
; The STRINGS are shared with the console entry: both ends speak the same
; vt102 sequences, and that is the half FGX already had right.  What differs is
; the margin behaviour and the default size -- 24 rows, the conventional remote
; default and what a pty is seeded to, rather than the SHR panel's 25.
;------------------------------------------------------------------------------
tc_ansi_num_table ASC   'co'
                DA      80
                ASC     'li'
                DA      24                       ; remote default, not the SHR 25
                ASC     'Co'
                DA      8
                DFB     0,0,0,0

tc_ansi_flag_table ASC  'am'                     ; auto-margin
                ASC     'bs'                     ; backspace
                ASC     'xn'                     ; MAGIC MARGIN: writing the last
                                                 ;   column does NOT wrap; the
                                                 ;   cursor stays at the margin
                DFB     0,0                      ; sentinel

;------------------------------------------------------------------------------
; The entry tgetent() last selected.  The three lookup helpers read the tables
; THROUGH these rather than from fixed labels, which is what makes more than one
; terminal describable at all.  Default = the console entry, so a caller that
; never calls tgetent (or names something unknown) behaves exactly as before.
;------------------------------------------------------------------------------
_tcStrTbl       DA      tc_str_table
_tcNumTbl       DA      tc_num_table
_tcFlagTbl      DA      tc_flag_table

;------------------------------------------------------------------------------
; vt102 escape sequences emitted by our SHR console's VT parser.
; ASC sets bit 7; the parser/Con_Write already strips it, so plain
; high-ASCII strings work.  Length byte first?  No -- termcap strings
; are NUL-terminated.
;------------------------------------------------------------------------------
tc_cm           ASC     $1B,'[%i%d;%dH',$00      ; cursor motion (vi/tgoto fmt)
tc_cl           ASC     $1B,'[H',$1B,'[2J',$00   ; clear screen
tc_ce           ASC     $1B,'[K',$00             ; clear EOL
tc_up           ASC     $1B,'[A',$00             ; cursor up 1
tc_do           ASC     $1B,'[B',$00             ; cursor down 1
tc_le           DFB     $08,$00                  ; cursor left 1 (^H)
tc_nd           ASC     $1B,'[C',$00             ; cursor right 1
tc_so           ASC     $1B,'[7m',$00            ; standout on (reverse)
tc_se           ASC     $1B,'[0m',$00            ; standout off
tc_us           ASC     $1B,'[4m',$00            ; underline on  (scanline-7 fill)
tc_ue           ASC     $1B,'[24m',$00           ; underline off
tc_md           ASC     $1B,'[1m',$00            ; bold on  (bold font variant)
tc_me           ASC     $1B,'[0m',$00            ; turn off all attributes
tc_mr           ASC     $1B,'[7m',$00            ; reverse on (inverse video; same code as so)
; Colour caps for the 640 four-colour text mode.  The console renders SGR
; 30-37 fg / 40-47 bg (collapsed onto the 4-colour row palette: default,
; warm, cool, + the slot-0 background).  AF/AB carry a termcap %d param, so
; a consumer needs tparm/tgoto to fill it (the vi termlib slice) -- declared
; ahead here like cm; raw ESC[3Nm / ESC[4Nm already work today.
tc_AF           ASC     $1B,'[3%dm',$00          ; set fg: ESC[3<n>m, n=0..7
tc_AB           ASC     $1B,'[4%dm',$00          ; set bg: ESC[4<n>m, n=0..7
tc_op           ASC     $1B,'[39;49m',$00        ; original pair: default fg + default bg
; elvis / full-screen-editor caps -- each VERIFIED against the SHR console VT
; parser (src/drivers/console/console_vthandler.s):
tc_cd           ASC     $1B,'[J',$00             ; clear to end of display: ED default = cursor->end (_Vt_Erase_CursorToEnd)
tc_cs           ASC     $1B,'[%i%d;%dr',$00      ; set scroll region top;bot, 1-based like cm (DECSTBM, _Vt_Handle_DECSTBM)
tc_sr           ASC     $1B,'M',$00              ; scroll reverse 1 line (RI, Con_ReverseIndex)
tc_ti           ASC     $1B,'[?1049h',$00        ; enter ca mode = alt-screen enter (Con_EnterAltScreen; VT ?1049 wired in console_vthandler.s)
tc_te           ASC     $1B,'[?1049l',$00        ; exit  ca mode = alt-screen exit  (Con_ExitAltScreen)
; Cursor-key caps (ku/kd/kl/kr): the kernel heartbeat (src/kernel/toolbox.s)
; now emits real vt100 arrow sequences -- naked Up/Down/Right/Left -> ESC[A/B/C/D
; (Ctrl+letter comes through as the bare control code).  ku/kd/kr reuse the
; identical cursor-motion strings (tc_up/tc_do/tc_nd); kl needs ESC[D (tc_le is
; the ^H cursor-move cap, not the key sequence).
tc_kl           ASC     $1B,'[D',$00             ; left-arrow key sequence (ESC[D)
