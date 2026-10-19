;==============================================================================
; bpf.s - /dev/bpf0 capture-block boot allocator (kernel residue after P0.4).
;
; The /dev/bpf0 character device + the W5100 MACRAW capture driver moved OUT of
; the kernel into the loadable bpf.mod (src/modules/bpf) for the kernel-bank
; reclaim.  All that stays in the kernel is the boot-time allocation of the
; capture BLOCK: the driver reaches it through the kernel DP soft-globals
; _bpfBase / _bpfSnapPtr / _bpfPhysTmp (include/dpmap.s), which are kernel-owned
; DP state and must be set up before bpf.mod's first open().
;
; Why the alloc stays kernel-side: there is no Kmalloc in the module gateway at all
; _Phase1_StubHalt today, so a module-side Kmalloc would red-border-halt the
; kernel.  Exposing the allocator to modules is a separate future ABI step;
; until then the kernel hands the module a ready heap block via these DP slots.
;
; Called once at boot from FGX_Entry (main.s).  Preserves X (caller's TCB) and
; Y; clobbers A.  Capture only starts at open() inside the module, so this runs
; whether or not the Uthernet II is present.
;==============================================================================

;------------------------------------------------------------------------------
; _Bpf_AllocBlk - Kmalloc the resident MACRAW capture block (M_KERN) and wire
; up the kernel DP long-pointers _bpfBase / _bpfSnapPtr that bpf.mod uses.  The
; block lives in the heap (outside the kernel data bank); the module reaches it via [dp],Y.
;------------------------------------------------------------------------------
_Bpf_AllocBlk   ENT
                MX      %00
                PHX
                PHY
                LDA     #BPF_BLK_SIZE
                LDX     #M_KERN
                JSR     Kmalloc
                BCC     @ba_allocFail
                LDA     _kmallocResult          ; _bpfBase = block ptr (lo16 + bank)
                STA     _bpfBase
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2
                STA     _bpfBase+2
                REP     #$20
                MX      %00
                JSR     _SoftGlob_ValidatePtr   ; always-on: panic if not in heap
                LDA     _bpfBase                ; _bpfSnapPtr = _bpfBase + BPF_SnapBuf
                CLC
                ADC     #BPF_SnapBuf
                STA     _bpfSnapPtr
                SEP     #$20
                MX      %10
                LDA     _bpfBase+2
                ADC     #$00                    ; + carry into bank
                STA     _bpfSnapPtr+2
                ; zero the block: CapState=0 (idle) + Sat/SatRept=0 + scratch=0
                LDY     #$0000
                LDA     #$00
@ba_zL          STA     [_bpfBase],Y
                INY
                CPY     #BPF_BLK_SIZE
                BCC     @ba_zL
                ; A SUCCESSFUL ALLOCATION SAYS NOTHING.  `net: /dev/bpf0
                ; capture block ready' named a device that does not exist yet:
                ; this is the KERNEL reserving a heap block, and /dev/bpf0 is
                ; registered later, by bpf.mod, which announces itself.  The
                ; line also printed on every machine with no Ethernet card at
                ; all -- the block is allocated whether or not one is fitted --
                ; so it reported a capture buffer for a device that would never
                ; capture anything.  The FAILURE still speaks: a block that
                ; could not be allocated is a driver that will not work.
                ; REP #$30, NOT #$20.  The entry pushed X and Y at 16 bits and
                ; the shared exit below pulls them at MX %00; returning here
                ; after `REP #$20' alone leaves X 8-BIT, so PLY/PLX pull one
                ; byte each where two were pushed and the caller returns on a
                ; shifted stack.  It does not fault -- it shows up as a task's
                ; kernel stack reading 8 bytes deeper, which is how
                ; kstkhwm_check caught it.
                REP     #$30
                MX      %00
                PLY
                PLX
                RTS
@ba_allocFail   MX      %00
                LDA     #bpf_allocMsg
@ba_log         MX      %00
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                JSR     Kern_LogEOL
                PLY
                PLX
                RTS

bpf_allocMsg    ASC     'net: /dev/bpf0 block alloc FAILED',00
