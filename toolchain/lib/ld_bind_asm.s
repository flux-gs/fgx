;==============================================================================
; ld_bind_asm.s - the shared-library binder's hand-written half (shared libc
; SP4 spec, section 5.4): the loop that patches a run of sites.  A site is
; (segment, offset[, original word]); `segs' gives each segment's (offset,
; bank) once loaded, so a library's core and template segments, which sit
; inside its last bank, resolve as its code banks do.  In C the loop is about
; 410 cycles a site.
;==============================================================================

;------------------------------------------------------------------------------
; _ld_patch(sites, n, segs, kind, val, bank, only) - kind 0: a site is
; (segment, offset), 3 bytes, and the word there becomes val and the byte
; after it bank (a call's or a pointer's 24 bits); kind 1: a site is
; (segment, offset, original word), 5 bytes, and the word there becomes the
; original word + val (a data site moved by the delta), so a bind writes
; the same bytes however often it runs.  only = $FF patches every site; any
; other value only the sites in that segment.  Uses fcc's caller-saved
; pointer scratch: _fcc_ptr2 the site list, _fcc_fpr0 the segment table,
; _fcc_ptr the site.  Far: JSL'd from C, RTL.  Arguments, above the 3-byte
; return: sites 4, n 8, segs 10, kind 14, val 16, bank 18, only 20.
;------------------------------------------------------------------------------
                FGX2_EXPORT _ld_patch
_ld_patch       MX      %00
                LDA     4,S                     ; sites
                STA     _fcc_ptr2
                LDA     6,S
                STA     _fcc_ptr2+2
                LDA     10,S                    ; segs
                STA     _fcc_fpr0
                LDA     12,S
                STA     _fcc_fpr0+2
                LDA     8,S                     ; n
                BEQ     @lp_done
                TAX
                LDY     #0
@lp_site        MX      %00
                LDA     [_fcc_ptr2],Y           ; the segment, in the low byte
                AND     #$00FF
                PHA                             ; 1,S = the site's segment
                LDA     20+2,S                  ; only
                AND     #$00FF
                CMP     #$00FF
                BEQ     @lp_take
                CMP     1,S
                BEQ     @lp_take
                PLA                             ; another segment: step over it
                LDA     14,S                    ; kind
                BEQ     @lp_skip3
                INY
                INY
@lp_skip3       INY
                INY
                INY
                BRA     @lp_next
@lp_take        PLA
                ASL
                ASL
                PHY
                TAY
                LDA     [_fcc_fpr0],Y           ; its offset once loaded
                STA     _fcc_ptr
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     [_fcc_fpr0],Y           ; its bank
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLY
                INY
                LDA     [_fcc_ptr2],Y           ; the site's offset
                CLC
                ADC     _fcc_ptr
                STA     _fcc_ptr
                INY
                INY
                LDA     14,S                    ; kind
                BNE     @lp_data
                LDA     16,S                    ; val
                STA     [_fcc_ptr]
                PHY
                LDY     #2
                SEP     #$20
                MX      %10
                LDA     18+2,S                  ; bank
                STA     [_fcc_ptr],Y
                REP     #$20
                MX      %00
                PLY
                BRA     @lp_next
@lp_data        MX      %00
                LDA     [_fcc_ptr2],Y           ; the original word
                CLC
                ADC     16,S                    ; + val
                STA     [_fcc_ptr]
                INY
                INY
@lp_next        MX      %00
                DEX
                BEQ     @lp_done
                JMP     @lp_site
@lp_done        MX      %00
                RTL
