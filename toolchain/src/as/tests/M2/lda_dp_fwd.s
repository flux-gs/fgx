; M2: LDA with forward reference to a DP-valued EQU.
; Per the EQU-aware fold policy: EQU'd symbols are named constants
; (e.g. `_fcc_ptr EQU $E8` for fcc's DP scratch slot), so they FOLD
; to dp form when value < 256.  Label symbols (defined by DS / DA /
; DW or as code labels) keep the ABS form regardless of resolved
; value — that prevents accidental DP routing for globals that
; happen to land at low addresses in their bank.
; Expected here: A5 42 (LDA dp $42, 2 bytes).  Iterative pass-1
; converges the forward-ref to dp since `foo` is EQU'd.
                MX      %00
                LDA     foo
foo             EQU     $42
