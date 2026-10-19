; devnodes.s -- the /dev nodes' device numbers, as the build made them.
;
; WRITTEN BY tools/ninja/gen.py FROM ITS DEV_NODES LISTS.  Edit the lists
; there; this file is regenerated whenever build.ninja is.  A module that
; owns one of these nodes registers AT this number (CDF_FIXED,
; include/chardev.s), so the number on the volume and the slot in the
; live registry cannot drift apart with the order modules load in.
DEVNODE_NULL         EQU     0
DEVNODE_PTYP0        EQU     1
DEVNODE_TTYP0        EQU     2
DEVNODE_PTYP1        EQU     3
DEVNODE_TTYP1        EQU     4
DEVNODE_TTYV1        EQU     5
DEVNODE_TTYV2        EQU     6
DEVNODE_CONSOLE      EQU     7
DEVNODE_TTY          EQU     8
DEVNODE_TTY01        EQU     18
DEVNODE_BPF0         EQU     19
DEVNODE_TTYV3        EQU     9
DEVNODE_RSD0         EQU     10
DEVNODE_RSD1         EQU     11
DEVNODE_RSD2         EQU     12
DEVNODE_RSD3         EQU     13
DEVNODE_RSD4         EQU     14
DEVNODE_RSD5         EQU     15
DEVNODE_RSD6         EQU     16
DEVNODE_RSD7         EQU     17
DEVNODE_CDA          EQU     20
DEVNODE_TTY00        EQU     21
DEVNODE_KLOG         EQU     22
