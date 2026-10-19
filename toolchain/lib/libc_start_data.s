;==============================================================================
; libc_start_data.s - libc_start.s's scratch cells, in libc's core (shared
; libc SP3 spec, section 3).  libc_start.s runs from libc's bank, so its
; cells are ordinary core cells.
;==============================================================================
_ls_callerS     DA      0
_ls_kernArgc    DA      0
_ls_walkIdx     DA      0
_ls_strBank0Ptr DA      0
_ls_envIdx      DA      0
_ls_envOff      DA      0
_ls_baseOff     DA      0
_ls_dataBank    DA      0
_ls_sigbit      DA      0
_ls_sigbitHi    DA      0
