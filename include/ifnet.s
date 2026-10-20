;==============================================================================
; ifnet.s - network interface table layout (kernel ifnet record + userland
; ifreq share one 32-byte layout) + SYS_IFCONFIG sub-ops + interface flags.
;
; The kernel keeps one record per detected interface in a Kmalloc'd soft-global
; reached via the DP long-pointer _ifTablePtr (dpmap.s), accessed [_ifTablePtr],Y
; by the IF_* field offsets below.  _AllocIfTable (main.s) allocates+zeros it at
; boot; _Ifnet_Register (ifconfig_sys.s) fills name+MAC at device-init.
;
; PUT by src/kernel/main.s.  The C mirror lives in
; src/userland/ifconfig/ifreq.h — keep the two layouts in lockstep.
; Spec: docs/superpowers/specs/2026-06-05-fgx-net-config-design.md
;==============================================================================

;------------------------------------------------------------------------------
; Per-interface record / ifreq field offsets (one 32-byte record).
;------------------------------------------------------------------------------
IF_Name         EQU  0      ; 8 B  NUL-padded "u2sN"
IF_Slot         EQU  8      ; 1 B  physical slot (1..7); also the IFC_GETN index
IF_Mac          EQU  9      ; 6 B  MAC written to W5100 SHAR
IF_Flags        EQU  15     ; 1 B  IFF_* bitmask
IF_Ip           EQU  16     ; 4 B  IPv4, network order
IF_Netmask      EQU  20     ; 4 B
IF_Broadcast    EQU  24     ; 4 B
IF_Gateway      EQU  28     ; 4 B  (programmed into the W5100 GAR, uthernet.s)
IF_REC_SIZE     EQU  32

IF_MAX          EQU  4                       ; max simultaneous interfaces
IFNET_BLK_SIZE  EQU  IF_MAX*IF_REC_SIZE      ; 128 — heap block size

;------------------------------------------------------------------------------
; Interface flags (IF_Flags byte).
;------------------------------------------------------------------------------
IFF_LINK_UP     EQU  $01     ; card present + SHAR written
IFF_IP_CONF     EQU  $02     ; IP layer configured (DHCP or ifconfig)
IFF_DHCP        EQU  $04     ; IP came from a DHCP lease

;------------------------------------------------------------------------------
; SYS_IFCONFIG sub-ops (passed in A.lo).
;------------------------------------------------------------------------------
IFC_GETN        EQU  0       ; by index: ifr.IF_Slot = index N -> fill or ENOENT
IFC_GET         EQU  1       ; by name: ifr.IF_Name -> fill the rest
IFC_SET         EQU  2       ; by name -> set ip/netmask/broadcast/gateway
IFC_SETMAC      EQU  3       ; reserved; the v1 ifconfig tool does not expose it
IFC_SETDHCP     EQU  4       ; as IFC_SET, but the IP came from a DHCP lease:
                             ; also sets IFF_DHCP.  Plain IFC_SET CLEARS that
                             ; bit, so a hand-config after a lease stops
                             ; claiming dhcp.  Without this op the kernel could
                             ; not tell dhclient from ifconfig (both went
                             ; through IFC_SET), so IFF_DHCP had NO setter and
                             ; ifconfig's "status: active (dhcp lease)" line
                             ; was dead code from the day it was written.

;------------------------------------------------------------------------------
; The BSD interface ioctls on a socket (2.11BSD h/ioctl.h `_IOWR(i, n, ...)',
; low 16 bits; <sys/ioctl.h> carries the same numbers), served by net.mod's
; net_op_ifioctl.  struct ifreq is 32 bytes: ifr_name[16] then a 16-byte union
; (sockaddr, or the flags short at +16); struct ifconf is ifc_len (2) then the
; ifc_buf far pointer (offset +2, bank +4).
;------------------------------------------------------------------------------
SIOCGIFADDR     EQU  $690D
SIOCGIFFLAGS    EQU  $6911
SIOCGIFBRDADDR  EQU  $6912
SIOCGIFCONF     EQU  $6914
SIOCGIFNETMASK  EQU  $6915
SIOC_IF_GROUP   EQU  $6900       ; the 'i' group, cmd & $FF00
IFREQ_SIZE      EQU  32
IFR_ADDR        EQU  16          ; the union: sockaddr / ifr_flags
; 2.11BSD net/if.h's flag values, which an FGX record's IF_Flags maps onto.
BSD_IFF_UP        EQU  $0001
BSD_IFF_BROADCAST EQU  $0002
BSD_IFF_LOOPBACK  EQU  $0008
BSD_IFF_RUNNING   EQU  $0040
