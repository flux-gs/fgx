;==============================================================================
; alloc_state.s - libc-core type constants + field-offset equates + name table.
;
; Arena / chunk / type-stats field offsets are declared here as EQUates so
; alloc.s and any code that walks the tables share one source of truth.
; Sizes (KMEM_*) and the state blocks (Kmem_Arenas, Kmem_TypeStats,
; Kmem_ArenaCount) live in include/memmap.s (they're DUM/DS allocations).
;==============================================================================

;------------------------------------------------------------------------------
; M_* type constants.  Index 0 = M_FREE is reserved for free-chunk marker.
;------------------------------------------------------------------------------
M_FREE          EQU     0
M_TEMP          EQU     1
M_SHELL         EQU     2
M_FONT          EQU     3
M_FS            EQU     4
M_CONSOLE       EQU     5
M_KERN          EQU     6
M_ANON          EQU     7
M_LAST          EQU     8

_name_free      ASC     '(free)',00
_name_temp      ASC     'M_TEMP',00
_name_shell     ASC     'M_SHELL',00
_name_font      ASC     'M_FONT',00
_name_fs        ASC     'M_FS',00
_name_console   ASC     'M_CONSOLE',00
_name_kern      ASC     'M_KERN',00
_name_anon      ASC     '(anon)',00

Kmem_TypeNames  DW      _name_free, _name_temp, _name_shell, _name_font
                DW      _name_fs,   _name_console, _name_kern, _name_anon

;------------------------------------------------------------------------------
; Arena record field offsets (16 bytes total).
;------------------------------------------------------------------------------
ARENA_BANK          EQU  0       ; 1 B: bank number (e.g. $05)
ARENA_PAD0          EQU  1       ; 1 B: padding
ARENA_FIRST         EQU  2       ; 2 B: offset of first chunk header
ARENA_FREEHEAD      EQU  4       ; 2 B: offset of first free chunk
ARENA_TOTAL         EQU  6       ; 2 B: total heap bytes in this bank
ARENA_USED          EQU  8       ; 2 B: currently allocated bytes
ARENA_PEAK          EQU  10      ; 2 B: peak bytes
ARENA_ALLOCS        EQU  12      ; 2 B: cumulative alloc count
ARENA_FREES         EQU  14      ; 2 B: cumulative free count

;------------------------------------------------------------------------------
; Type stats record field offsets (8 bytes each).
;------------------------------------------------------------------------------
TS_INUSE            EQU  0       ; 2 B: currently allocated bytes of this type
TS_COUNT            EQU  2       ; 2 B: currently allocated chunks of this type
TS_CALLS            EQU  4       ; 2 B: cumulative alloc calls of this type
TS_PEAK             EQU  6       ; 2 B: peak inuse bytes

;------------------------------------------------------------------------------
; Chunk header offsets (8 B total; data at +8; guard at +8+data_size).
;------------------------------------------------------------------------------
CH_SIZE             EQU  0       ; 2 B: user-data size (excl. header + guard)
CH_TYPE             EQU  2       ; 2 B: M_* index (0 = free)
CH_NEXT             EQU  4       ; 2 B: offset of next chunk in arena (0 = last)
CH_FREENEXT         EQU  6       ; 2 B: offset of next free chunk (0 = tail)
CH_HEADER_LEN       EQU  8
CH_GUARD_LEN        EQU  1
CH_GUARD            EQU  $A5

;------------------------------------------------------------------------------
; Arena constants.
;------------------------------------------------------------------------------
KMEM_HEAP_FIRST_BANK EQU $07            ; static-$02-build name only.  The
                                        ; live heap banks are rest-of-OS
                                        ; offsets (REST_HEAP_FIRST_OFF,
                                        ; include/kernel.s, read at run time
                                        ; from _kHeapFirstBank); the heap
                                        ; grows into pool banks on demand,
                                        ; up to KMEM_MAX_ARENAS.
KMEM_FIRST_CHUNK_OFF EQU $0008    ; first chunk starts at offset 8 per arena;
                                  ; offsets 0..7 are reserved padding so that
                                  ; offset 0 can serve as the null/end-of-list
                                  ; sentinel (no chance a real chunk lives there).
KMEM_ARENA_SIZE_HI   EQU $FFF8    ; usable bytes per arena (leave 8 B at top)
KMEM_INIT_CHUNK_SIZE EQU $FFE7    ; = $FFF8 - FIRST_CHUNK_OFF - CH_HEADER_LEN
                                  ;     - CH_GUARD_LEN = $FFF8-8-8-1 = $FFE7
