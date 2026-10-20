;==============================================================================
; errno.s - BSD-compatible errno constants.
;
; Values match 4.3BSD / BSD 2.11 exactly. Returned in A on any Fs_* error
; (carry clear, A = errno).
;==============================================================================

EPERM           EQU     1               ; operation not permitted (credentials P2:
                                        ; a non-root setuid/setgid to an id that is
                                        ; neither the real nor the saved-set one)
ENOENT          EQU     2
; --- Values FGX does not itself return yet, provided so BSD port source
; --- compares against them as written (tcsh tests errno == EACCES).
; --- Canonical 4.3BSD/2.11BSD numbers; do not renumber.
; --- (EPERM graduated OUT of this block above: setuid/setgid now return it.)
EACCES          EQU     13              ; permission denied
EFAULT          EQU     14              ; bad address
ENOTBLK         EQU     15              ; block device required
ENODEV          EQU     19              ; no such device
ETXTBSY         EQU     26              ; text file busy
EMLINK          EQU     31              ; too many links
EDOM            EQU     33              ; argument out of domain
ERANGE          EQU     34              ; result too large
ESRCH           EQU     3               ; no such process
EIO             EQU     5
ENXIO           EQU     6               ; no such device or address (chardev not registered)
E2BIG           EQU     7               ; argv+envp exceeds child's stack-page budget
ENOEXEC         EQU     8               ; binary not in valid format
EBADF           EQU     9
ECHILD          EQU     10              ; no child processes (BSD #10)
EAGAIN          EQU     11              ; resource temporarily unavailable / process table full
EWOULDBLOCK     EQU     EAGAIN          ; BSD alias (net would-block returns EAGAIN)
ENOTDIR         EQU     20
EISDIR          EQU     21
EINVAL          EQU     22
ENFILE          EQU     23
EMFILE          EQU     24
ENOTTY          EQU     25              ; inappropriate ioctl for device
ENOTSUP         EQU     45
ENOPROTOOPT     EQU     42              ; setsockopt: no such option at this level
ENAMETOOLONG    EQU     63
EADDRNOTAVAIL   EQU     49              ; can't bind a source addr not on this host

; TCP / connection errno (4.3BSD values; EOPNOTSUPP reuses ENOTSUP=45)
EINTR           EQU     4               ; interrupted by a signal (^C)
EPIPE           EQU     32              ; write to a closed connection
ECONNRESET      EQU     54              ; connection reset by peer
EISCONN         EQU     56              ; socket is already connected
ENOTCONN        EQU     57              ; socket is not connected
ETIMEDOUT       EQU     60              ; connection timed out
ECONNREFUSED    EQU     61              ; connection refused (peer RST)
ENOBUFS         EQU     55              ; no buffer space available (send queue full)
ENOTSOCK        EQU     38              ; socket operation on non-socket
EPROTOTYPE      EQU     41              ; protocol wrong type for socket
EADDRINUSE      EQU     48              ; address already in use
EAFNOSUPPORT    EQU     47              ; address family not supported
EDESTADDRREQ    EQU     39              ; send() on an unconnected datagram socket
EMSGSIZE        EQU     40              ; message too long for the buffer

EBUSY           EQU     16
EEXIST          EQU     17
EXDEV           EQU     18              ; cross-device link (rename across dirs → mv copies)
ENOTEMPTY       EQU     66              ; directory not empty (rmdir)
ENOMEM          EQU     12
ENOSYS          EQU     78
EFBIG           EQU     27              ; file would exceed 16 MB tree limit
ENOSPC          EQU     28              ; volume bitmap exhausted
EROFS           EQU     30              ; volume is read-only
ESPIPE          EQU     29              ; illegal seek (pipe/console/dir)

;==============================================================================
; END errno.s
;==============================================================================
