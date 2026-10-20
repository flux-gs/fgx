; M8: @local labels — fas mangles `@name` to "Global@name" using the
; nearest preceding global label as scope.  Merlin32's duplicate-
; label check is global (not scope-aware), so this fixture uses
; uniquely-named locals to keep the Merlin oracle byte-eq path —
; the scoping logic itself is exercised internally by fas (every
; @-ref resolves through the mangling layer).
                MX      %00
funcA           LDX     #5
@loopA          DEX
                BNE     @loopA
                RTS
funcB           LDY     #3
@loopB          DEY
                BNE     @loopB
                RTS
