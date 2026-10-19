#!/usr/bin/env python3
"""Generate a module's kernel-address EQU include from the kernel build listing.

BSD-style build-time symbol resolution (cf. 4.4BSD `modload`'s `ld -A /vmunix`,
or a monolithic relink): loadable modules reference kernel state at addresses
SCRAPED from the freshly-built kernel listing, instead of hand-typing `KAD_*` /
SCC EQUs that go stale when the kernel layout shifts. Regenerated every build,
so the addresses can never drift out of sync and no `ERR` anchor is needed --
the generator IS the guard (a renamed/removed kernel symbol fails the build).

Also generates the KERNEL BUILD IDENTITY that Mod_Load checks -- see build_id()
and emit_kernel_id() below.

Usage:  gen_kernel_exports.py <kernel-listing> <module> <out.s>
        gen_kernel_exports.py --kernel-id <out.s>
"""
import re
import sys

# module -> [(export_EQU_name, kernel_symbol, byte_offset, form), ...]
#   value  = (kernel_symbol address in bank $02) + byte_offset
#   form 'lo16'  -> emit $XXXX     (16-bit DBR-relative offset; serial + *_off)
#   form 'abs24' -> emit $02XXXX   (24-bit absolute; the far bank's shims)
#
# `abs24' CANNOT NAME A RELOCATED KERNEL ROUTINE, and the $02 above is the whole
# reason: $02 is the ASSEMBLY ORG bank, not the bank the kernel was relocated
# into at boot.  It is right for what it is used for -- addresses a consumer
# resolves for itself -- and WRONG for a module that wants to `JSL' into kernel
# code.  Exporting one that way (apple/fgx#108 T7, 2026-08-28) sent serial.mod
# into bank $02: the machine booted to a prompt, nothing ever arrived in the
# line's `t_rawq', and with a reader on the line it took down an in-flight
# `_Chardev_Dispatch' -- a blank screen, which passes every `screen_lacks'.
#
# A MODULE CALLS KERNEL CODE THROUGH THE BANK-0 GATEWAY, `MOD_JT_BASE'
# (include/modules.s) -- a KSVC or a jumptable slot.  It is at a fixed bank-0
# address precisely so it survives relocation, which no exported bank byte does.
MANIFESTS = {
    # far: the FAR KERNEL BANK (src/kernel/far, bin/fgxfar.bin).  Not a module --
    # a second statically linked kernel image in the kernel handle's headroom
    # bank.  See docs/history/plans/far-kernel-bank.md.
    #
    # These are the RTL SHIMS in src/kernel/far_shims.s, not the routines
    # themselves -- every core routine the far bank needs is RTS-terminated and
    # a cross-bank JSL/RTS mismatch would corrupt the stack.  abs24: the far bank does
    # `JSL <scraped $02XXXX>` and Far_BankInit rewrites the baked $02 bank byte to
    # the live core bank at boot (the site carries a _cfpNNN marker so
    # gen_far_bankpatch.py finds it).  parse_listing resolves any label
    # definition, code included, so ordinary routine labels work here.
    'far': [
        ('_FarSh_Fs_Open',  '_FarSh_Fs_Open',  0, 'abs24'),
        ('_FarSh_Fs_Read',  '_FarSh_Fs_Read',  0, 'abs24'),
        ('_FarSh_Fs_Close', '_FarSh_Fs_Close', 0, 'abs24'),
        ('_FarSh_LogStr',   '_FarSh_LogStr',   0, 'abs24'),
        ('_FarSh_Kmalloc',  '_FarSh_Kmalloc',  0, 'abs24'),
        ('_FarSh_Sleep',    '_FarSh_Sleep',    0, 'abs24'),
        ('_FarSh_SleepUn',  '_FarSh_SleepUn',  0, 'abs24'),
        ('_FarSh_Wakeup',   '_FarSh_Wakeup',   0, 'abs24'),
        ('_FarSh_BlkIo',    '_FarSh_BlkIo',    0, 'abs24'),
        ('_FarSh_BlkReads', '_FarSh_BlkReads', 0, 'abs24'),
        ('_FarSh_KernDP',   '_FarSh_KernDP',   0, 'abs24'),
        ('_FarSh_VcKbdOK',  '_FarSh_VcKbdOK',  0, 'abs24'),
        ('_FarSh_Halt',     '_FarSh_Halt',     0, 'abs24'),
        ('_FarSh_ModFindVtable', '_FarSh_ModFindVtable', 0, 'abs24'),
        ('_FarSh_CurPid',   '_FarSh_CurPid',   0, 'abs24'),
        # The chardev registry, by name, for the far bank -- UFS 1.7d I3.
        # KSVC_CDLOOKUP is a module's road to the same body; the far bank has
        # no SYS_KCALL, so it takes this one.
        ('_FarSh_CdLookup', '_FarSh_CdLookup', 0, 'abs24'),
        # loader.s's reach-back, far-bank phase 3.  Fs_OpenCore is a SECOND
        # door onto Fs_Open, for a path that is already in the core bank --
        # see the shim's header for why that is a different contract and not
        # a duplicate.
        ('_FarSh_Fs_OpenCore', '_FarSh_Fs_OpenCore', 0, 'abs24'),
        ('_FarSh_Fs_ReadN', '_FarSh_Fs_ReadN', 0, 'abs24'),
        ('_FarSh_Fs_Lseek', '_FarSh_Fs_Lseek', 0, 'abs24'),
        ('_FarSh_Bank_Alloc', '_FarSh_Bank_Alloc', 0, 'abs24'),
        ('_FarSh_Bank_Free', '_FarSh_Bank_Free', 0, 'abs24'),
        # The shared-text table, which lives in the tty bank (text.s).
        ('_FarSh_TextFind', '_FarSh_TextFind', 0, 'abs24'),
        ('_FarSh_TextClaim', '_FarSh_TextClaim', 0, 'abs24'),
        ('_FarSh_TextFill', '_FarSh_TextFill', 0, 'abs24'),
        ('_FarSh_Core_Alloc', '_FarSh_Core_Alloc', 0, 'abs24'),
        ('_FarSh_Core_Free', '_FarSh_Core_Free', 0, 'abs24'),
        ('_FarSh_TextUnref','_FarSh_TextUnref',0, 'abs24'),
        ('_FarSh_ModRegister', '_FarSh_ModRegister', 0, 'abs24'),
        ('_FarSh_ModHeader', '_FarSh_ModHeader', 0, 'abs24'),
        ('_mlPlaceAny',     '_mlPlaceAny',     0, 'abs24'),
        # SYS_MODLOAD's streaming install (apple/fgx#308).  The header chunk
        # tells the registrar where the caller's own copy of the header is,
        # and reads back the two answers only the core can give: which bank
        # the ordinal maps to, and where this module's text begins in it.
        ('_mlHdrBank',      '_mlHdrBank',      0, 'abs24'),
        ('_mlHdrOff',       '_mlHdrOff',       0, 'abs24'),
        ('_mlBank',         '_mlBank',         0, 'abs24'),
        ('_mlTextBase',     '_mlTextBase',     0, 'abs24'),
        # ...and what an ABORT has to give back: the two append-only table
        # counters as the header half found them, and the bank, but only when
        # this load is the one that allocated it.
        ('_mlSaveExtCount', '_mlSaveExtCount', 0, 'abs24'),
        ('_mlSaveRegCount', '_mlSaveRegCount', 0, 'abs24'),
        ('_modExtCount',    '_modExtCount',    0, 'abs24'),
        ('_mlBankFresh',    '_mlBankFresh',    0, 'abs24'),
        ('_mlSaveValid',    '_mlSaveValid',    0, 'abs24'),
        ('_mlBankOrd',      '_mlBankOrd',      0, 'abs24'),
        ('_modBankTab',     '_modBankTab',     0, 'abs24'),
        # Core STATICS the far-bank loader reaches by _cfp-marked long
        # addressing.  Resolved from the kernel listing rather than moved into
        # memmap.s (where _frnDst*/_fsLsWhence already sit and so need no row):
        # both of these live inside a region another routine zeroes by its
        # bounds, and relocating a static out of such a region is how
        # apple/fgx#120 happened.
        ('_ps_childTCB', '_ps_childTCB', 0, 'abs24'),
        ('_Sys_CallerBank', '_Sys_CallerBank', 0, 'abs24'),
        # unp_nameop's OUT parameter: the descriptor slot a lookup found.  The
        # core-side KSVC arm stages the IN value and reads the OUT one; this row
        # is what lets the far bank's shim name the word at all.
        ('_unpSlot', '_unpSlot', 0, 'abs24'),
    ],
    # tty: the TTY KERNEL BANK (src/kernel/tty, bin/fgxtty.bin).  A THIRD
    # statically linked kernel image, at live kernel bank + 2.  See
    # docs/history/plans/tty-kernel-bank.md.
    #
    # IT REUSES THE FAR BANK'S SHIMS rather than growing a set of its own.  The
    # shims are ordinary CORE-bank routines whose only job is to be
    # RTL-terminated; nothing in them is far-specific, and a second copy would
    # be core-bank bytes spent to say the same thing twice.  The name keeps its
    # _FarSh_ spelling for that reason -- it names where the shims LIVE, which
    # is neither of the banks that call them.
    #
    # Kept to what is actually reached.  A scraped symbol nothing calls is a
    # row in a generated table that no build step can tell from a live one.
    'tty': [
        ('_FarSh_LogStr',   '_FarSh_LogStr',   0, 'abs24'),
        ('_FarSh_KernDP',   '_FarSh_KernDP',   0, 'abs24'),
        ('_FarSh_Wakeup',   '_FarSh_Wakeup',   0, 'abs24'),
        # The INTERRUPTIBLE sleep, T6 increment 4b.  `_FarSh_SleepUn' below is
        # the buffer wait's; this one is `ttread's, which must answer a signal
        # rather than re-loop -- upstream sleeps at TTIPRI, which is above
        # PZERO and therefore PCATCH.
        ('_FarSh_Sleep',    '_FarSh_Sleep',    0, 'abs24'),
        ('_FarSh_CdTtyIdx', '_FarSh_CdTtyIdx', 0, 'abs24'),
        # The pump's two doors onto the core's byte source, and the INTR flush
        # the heartbeat latched because it consumed the ^C, RETIRED AT T6
        # INCREMENT 4b -- which is what the row here always said would happen:
        # "these retire at T6, when a receive interrupt feeds the discipline
        # the way upstream does."  The heartbeat calls `kc_ttyinput' now.
        # ttyblock/ttyunblock's RTSCTS arm.  FGX has no cdevsw array, so
        # d_ioctl is the registry's _Chardev_Ioctl reached through here.
        ('_FarSh_CdIoctl',  '_FarSh_CdIoctl',  0, 'abs24'),
        # ttwakeup/ttyowake.  selwakeup is one CHANNEL in FGX, not a recorded
        # proc; gsignal is _Kill_GroupFanout, which the tty bank feeds from its
        # own t_pgrp rather than through _ttyTable.
        ('_FarSh_SelWakeup','_FarSh_SelWakeup',0, 'abs24'),
        ('_FarSh_Gsignal',  '_FarSh_Gsignal',  0, 'abs24'),
        # ttyflush and, at T6, ttyinput's ^S path.
        ('_FarSh_CdStop',   '_FarSh_CdStop',   0, 'abs24'),
        # t_oproc's drain -- T3 stage 3.  A RUN of bytes, not one, because the
        # queue is walked with ndqb the way dzstart walks it.
        ('_FarSh_CdWrite',  '_FarSh_CdWrite',  0, 'abs24'),
        ('_FarSh_Uiomove',  '_FarSh_Uiomove',  0, 'abs24'),
        # ttread's one-character handoff.  In vfs.mod beside uiomove, because
        # T4's tty_pty.c calls it four times from a third bank again.
        ('_FarSh_Ureadc',   '_FarSh_Ureadc',   0, 'abs24'),
        # ttywait's `sleep(&tp->t_outq, TTOPRI)'.  UNINTERRUPTIBLE, the same
        # choice the far bank made: ttywait re-tests its condition after every
        # wake, so an interruptible sleep's "a signal is pending, I did not
        # sleep" answer would spin the loop at full speed rather than block.
        ('_FarSh_SleepUn',  '_FarSh_SleepUn',  0, 'abs24'),
        # ttyopen's session acquisition.  The ONE core predicate this bank
        # calls rather than porting: FGX resolves "which process is this open
        # for" through _kCttyTarget, which upstream's u.u_procp cannot say.
        ('_FarSh_SeTtyOpen','_FarSh_SeTtyOpen',0, 'abs24'),
        # ttwrite's background gate.  The PREDICATE is C in tty.c -- both BSD
        # trees put it in the tty layer -- and these carry two of the three
        # per-process fields it cannot see from here; the third, whether the
        # caller still holds its parent, this bank reads itself (kc_sys.s
        # kt_holdsparent).
        ('_FarSh_CurPgrp',  '_FarSh_CurPgrp',  0, 'abs24'),
        ('_FarSh_CurCtty',  '_FarSh_CurCtty',  0, 'abs24'),
        ('_FarSh_SigOpted', '_FarSh_SigOpted', 0, 'abs24'),
        # ttycheckoutq's "did a signal arrive while I waited".  The RAW pending
        # mask, both words: this kernel numbers pending bits without BSD's
        # decrement, so signals 16..23 -- every job-control signal -- sit in
        # byte 2 and a low-word answer would be blind to them.
        ('_FarSh_SigPending','_FarSh_SigPending',0, 'abs24'),
        # ttioctl's two per-process reads.  _FarSh_SpgOk answers the WHOLE of
        # TIOCSPGRP's ownership test rather than exporting pfind and inferior,
        # which the core already owns as Task_Lookup and _Spg_Permitted.
        ('_FarSh_CurUid',   '_FarSh_CurUid',   0, 'abs24'),
        ('_FarSh_SpgOk',    '_FarSh_SpgOk',    0, 'abs24'),
        # kc_panic's exit.  A broken tty invariant halts rather than returning,
        # so the bank needs the same loud stop the far one has.
        ('_FarSh_Halt',     '_FarSh_Halt',     0, 'abs24'),
        # The shared-text table's reclaim (text.s) gives a text's pages back.
        ('_FarSh_Core_Free','_FarSh_Core_Free',0, 'abs24'),
    ],
    'serial': [
        ('_sccRxCountB', '_sccRxCountB', 0, 'lo16'),
        ('_sccStopsB', '_sccStopsB', 0, 'lo16'),
        ('_isrEntryRR3', '_isrEntryRR3', 0, 'lo16'),
        # apple/fgx#108 T7: the open count that gates the receive interrupt's
        # trip into the line discipline.  DATA ONLY -- the trip itself goes
        # through KSVC_TTYIRQINPUT, because `abs24' below cannot name a
        # relocated kernel routine.
        ('_sccOpenB', '_sccOpenB', 0, 'lo16'),
        ('_sccTxBuf', '_sccTxBuf', 0, 'lo16'),
        ('_sccTxHead', '_sccTxHead', 0, 'lo16'),
        ('_sccTxTail', '_sccTxTail', 0, 'lo16'),
        ('_sccTxInProgress', '_sccTxInProgress', 0, 'lo16'),
        # chan A (printer port / tty00) ring set — mirror of the chan-B set.
        ('_sccRxBufA', '_sccRxBufA', 0, 'lo16'),
        ('_sccRxHeadA', '_sccRxHeadA', 0, 'lo16'),
        ('_sccRxTailA', '_sccRxTailA', 0, 'lo16'),
        ('_sccTxBufA', '_sccTxBufA', 0, 'lo16'),
        ('_sccTxHeadA', '_sccTxHeadA', 0, 'lo16'),
        ('_sccTxTailA', '_sccTxTailA', 0, 'lo16'),
        ('_sccTxInProgressA', '_sccTxInProgressA', 0, 'lo16'),
        # (serial-side _simStat* counters dropped 2026-06-24 — see memmap.s.)
    ],
    # bpf: /dev/bpf0 capture module (src/modules/bpf). The capture BLOCK is in
    # the kernel heap, reached via the DP soft-globals _bpfBase/_bpfSnapPtr/
    # _bpfPhysTmp (DP offsets, hardcoded in bpf.s -- they don't appear in the
    # bank-$02 listing). These manifest syms are the bank-$02 STATICS the
    # module touches: the _Sys_Rd* read-descriptor slots (lo16, DBR-relative
    # under DBR=$02 during chardev dispatch) and the W5100 bus shadows
    # _u2Imr/_u2Locked (abs24; STAL/LDAL in the capture driver + U2 macros).
    # klog: /dev/klog (src/modules/klog), a cursored read-only view of the
    # kernel log ring for syslogd.  Everything it needs from the core bank is an
    # address or a size, so nothing here is a constant copied into the module:
    # the ring's write index and wrapped flag and the ring size all stay
    # single-sourced in include/memmap.s, and the cursor cells live beside them
    # because a chardev op runs with DBR = the kernel bank.
    'klog': [
        ('_Sys_RdMax', '_Sys_RdMax', 0, 'lo16'),
        ('_Sys_RdBufOff', '_Sys_RdBufOff', 0, 'lo16'),
        ('_Sys_CallerBank', '_Sys_CallerBank', 0, 'lo16'),
        ('_Sys_IoctlCmd', '_Sys_IoctlCmd', 0, 'lo16'),
        ('_Sys_IoctlArgLo', '_Sys_IoctlArgLo', 0, 'lo16'),
        ('_Sys_IoctlArgBank', '_Sys_IoctlArgBank', 0, 'lo16'),
        ('_kernLogHead', '_kernLogHead', 0, 'lo16'),
        ('_kernLogWrap', '_kernLogWrap', 0, 'lo16'),
        ('_klogRd', '_klogRd', 0, 'lo16'),
        ('_klogOpen', '_klogOpen', 0, 'lo16'),
        ('_klogVfsUiomove', '_klogVfsUiomove', 0, 'lo16'),
        ('_klogVfsBank', '_klogVfsBank', 0, 'lo16'),
    ],
    'bpf': [
        ('_Sys_RdMax', '_Sys_RdMax', 0, 'lo16'),
        ('_Sys_RdBufOff', '_Sys_RdBufOff', 0, 'lo16'),
        ('_Sys_CallerBank', '_Sys_CallerBank', 0, 'lo16'),
        ('_u2Imr', '_u2Imr', 0, 'lo16'),
        ('_u2Locked', '_u2Locked', 0, 'lo16'),
        ('_u2SltBit', '_u2SltBit', 0, 'lo16'),
        # Detected W5100 slot (1..7; 0=none), read by the module's _W5_PatchSlot
        # at mod_init entry (DBR=kernel bank) to bind its own U2_* sites.
        ('_u2Slot',   '_u2Slot',   0, 'lo16'),
    ],
    # net: the networking stack module (src/modules/net). Phase 1 = SYS_IFCONFIG.
    # The ifconfig scratch statics (_ifn*/_ifc*) STAY kernel-side in
    # ifconfig_sys.s and are reached DBR-relative (lo16, DBR=$02 during
    # dispatch); the syscall args come from the dispatcher's _Sys_Saved* slots;
    # _ifS1Off is the slot-1 record offset; _W5_WriteIpFromRec is the one kernel
    # routine the IFC_SET path JSLs (abs24).
    'net': [
        ('_Sys_SavedA', '_Sys_SavedA', 0, 'lo16'),
        ('_Sys_SavedX', '_Sys_SavedX', 0, 'lo16'),
        ('_Sys_CallerBank', '_Sys_CallerBank', 0, 'lo16'),
        ('_ifcOp', '_ifcOp', 0, 'lo16'),
        ('_ifnIdx', '_ifnIdx', 0, 'lo16'),
        ('_ifnCount', '_ifnCount', 0, 'lo16'),
        ('_ifnName', '_ifnName', 0, 'lo16'),
        ('_ifcRecOff', '_ifcRecOff', 0, 'lo16'),
        ('_ifcTmpW', '_ifcTmpW', 0, 'lo16'),
        ('_ifS1Off', '_ifS1Off', 0, 'lo16'),
        # RTL trampoline (net_dispatch.s) wrapping the JSR/RTS kernel routine
        # _W5_WriteIpFromRec, so the module can JSL it without a stack mismatch.
        ('_Net_KCall_W5WriteIp', '_Net_KCall_W5WriteIp', 0, 'abs24'),
        # --- Phase 2 (socket.s move) ---
        # Syscall arg saved by the dispatcher (SavedA/X already above).
        ('_Sys_SavedY', '_Sys_SavedY', 0, 'lo16'),
        # ioctl(2)'s staged command and argument, for the SIOCGIF* op.
        ('_Sys_IoctlCmd', '_Sys_IoctlCmd', 0, 'lo16'),
        ('_Sys_IoctlArgLo', '_Sys_IoctlArgLo', 0, 'lo16'),
        ('_Sys_IoctlArgBank', '_Sys_IoctlArgBank', 0, 'lo16'),
        # The _sock* scratch statics the moved handlers/helpers read+write; they
        # STAY in socket.s (kernel), reached DBR-relative (DBR=$02 during
        # dispatch).  Also read by the kept kernel transport cores.
        ('_sockTmpProto', '_sockTmpProto', 0, 'lo16'),
        ('_sockTmpTag', '_sockTmpTag', 0, 'lo16'),
        ('_sockTmpHw', '_sockTmpHw', 0, 'lo16'),
        ('_sockTmpOff', '_sockTmpOff', 0, 'lo16'),
        ('_sockTmp2', '_sockTmp2', 0, 'lo16'),
        ('_sockBufOff', '_sockBufOff', 0, 'lo16'),
        ('_sockLen', '_sockLen', 0, 'lo16'),
        ('_sockDstIp', '_sockDstIp', 0, 'lo16'),
        ('_sockDstPort', '_sockDstPort', 0, 'lo16'),
        ('_sockSrcOff', '_sockSrcOff', 0, 'lo16'),
        ('_sockRecvFlags', '_sockRecvFlags', 0, 'lo16'),
        ('_sockSendFlags', '_sockSendFlags', 0, 'lo16'),
        ('_sockOptLevel', '_sockOptLevel', 0, 'lo16'),
        ('_sockOptName', '_sockOptName', 0, 'lo16'),
        ('_sockOptLen', '_sockOptLen', 0, 'lo16'),
        ('_sockOptVal', '_sockOptVal', 0, 'lo16'),
        ('_sockBindAddr', '_sockBindAddr', 0, 'lo16'),
        ('_sockAcceptLOff', '_sockAcceptLOff', 0, 'lo16'),
        # RTL wrappers for the kernel routines net.mod still calls (Phase 3 moved
        # the transport in-module, so only the FCB layer remains kernel-side).
        ('_Net_KCall_FcbAlloc', '_Net_KCall_FcbAlloc', 0, 'abs24'),
        ('_Net_KCall_SockFdToDesc', '_Net_KCall_SockFdToDesc', 0, 'abs24'),
        # --- Phase 3 (transport + ring + _Sock_PollIntr move) ---
        # Con_PollKey + _sleep, for the now-in-module _Sock_PollIntr.
        ('_Net_KCall_ConPollKey', '_Net_KCall_ConPollKey', 0, 'abs24'),
        ('_Net_KCall_Sleep', '_Net_KCall_Sleep', 0, 'abs24'),
        # Inline statics that stayed in uthernet.s (the transport reads them).
        ('_w5SockInUse', '_w5SockInUse', 0, 'lo16'),
        ('_tcpNextPort', '_tcpNextPort', 0, 'lo16'),
        # W5100 bus shadows (the U2_LOCK/UNLOCK macros STAL/LDAL these).
        ('_u2Imr', '_u2Imr', 0, 'lo16'),
        ('_u2Locked', '_u2Locked', 0, 'lo16'),
        ('_u2SltBit', '_u2SltBit', 0, 'lo16'),
        # Detected W5100 slot (1..7; 0=none), read by the module's _W5_PatchSlot
        # at mod_init entry (DBR=kernel bank) to bind its own U2_* sites.
        ('_u2Slot',   '_u2Slot',   0, 'lo16'),
        # Additional _sock* statics the transport cores read+write.
        ('_sockSrcIp', '_sockSrcIp', 0, 'lo16'),
        ('_sockSrcPort', '_sockSrcPort', 0, 'lo16'),
        ('_sockRxLen', '_sockRxLen', 0, 'lo16'),
        ('_sockCapLen', '_sockCapLen', 0, 'lo16'),
        ('_sockRingRun', '_sockRingRun', 0, 'lo16'),
        ('_sockTxWr', '_sockTxWr', 0, 'lo16'),
        ('_sockTxBase', '_sockTxBase', 0, 'lo16'),
        ('_sockPhys', '_sockPhys', 0, 'lo16'),
        # net_loop.s + pipe.s moved into net.mod 2026-08-11.  Their STATICS
        # stayed in the core bank (syscall.s / fs.s / net_dispatch.s write them
        # directly, and they are how arguments reach the moved bodies --
        # _Net_Dispatch clobbers A, so nothing travels in a register).
        ('_ttyTable', '_ttyTable', 0, 'lo16'),
        ('_nSelSleepers', '_nSelSleepers', 0, 'lo16'),
        ('_loopHandled', '_loopHandled', 0, 'lo16'),
        ('_loopDstPort', '_loopDstPort', 0, 'lo16'),
        ('_loopConnOff', '_loopConnOff', 0, 'lo16'),
        ('_loopLisOff', '_loopLisOff', 0, 'lo16'),
        ('_loopAccOff', '_loopAccOff', 0, 'lo16'),
        ('_loopIsRecv', '_loopIsRecv', 0, 'lo16'),
        ('_loopMsgNb', '_loopMsgNb', 0, 'lo16'),
        ('_loopRingA', '_loopRingA', 0, 'lo16'),
        ('_loopRingB', '_loopRingB', 0, 'lo16'),
        ('_loopScratch', '_loopScratch', 0, 'lo16'),
        ('_loopBits', '_loopBits', 0, 'lo16'),
        ('_loopRxLen', '_loopRxLen', 0, 'lo16'),
        # unp.s -- AF_UNIX SOCK_DGRAM.  Statics stay in the core bank for the
        # same reason the loopback ones do, and _unpHdr additionally MUST: it is
        # the source buffer _Pipe_WriteAt copies the record header from, so it
        # has to live in a bank the module can name an address in.
        #
        # THE ORDER HERE IS IRRELEVANT but the order in src/kernel/unp.s is not:
        # they are one contiguous block that a blocking recv saves on the task's
        # stack, and _unpBlkEnd anchors its length.
        ('_unpHandled', '_unpHandled', 0, 'lo16'),
        ('_unpArgBlk', '_unpArgBlk', 0, 'lo16'),
        ('_unpDescOff', '_unpDescOff', 0, 'lo16'),
        ('_unpPeerOff', '_unpPeerOff', 0, 'lo16'),
        ('_unpRingOff', '_unpRingOff', 0, 'lo16'),
        ('_unpPayLen', '_unpPayLen', 0, 'lo16'),
        ('_unpNeed', '_unpNeed', 0, 'lo16'),
        ('_unpGot', '_unpGot', 0, 'lo16'),
        ('_unpHdr', '_unpHdr', 0, 'lo16'),
        ('_unpBlkEnd', '_unpBlkEnd', 0, 'lo16'),
        ('_unpNameOp', '_unpNameOp', 0, 'lo16'),
        ('_unpSlot', '_unpSlot', 0, 'lo16'),
        ('_pipeThunkFd', '_pipeThunkFd', 0, 'lo16'),
        ('_loopThunkSock', '_loopThunkSock', 0, 'lo16'),
        ('_pipeRecOff', '_pipeRecOff', 0, 'lo16'),
        ('_pipeReqLen', '_pipeReqLen', 0, 'lo16'),
        ('_pipeDone', '_pipeDone', 0, 'lo16'),
        ('_pipeBufOff', '_pipeBufOff', 0, 'lo16'),
        ('_pipeBufBank', '_pipeBufBank', 0, 'lo16'),
        ('_pipeUio', '_pipeUio', 0, 'lo16'),
        ('_pipeKIov', '_pipeKIov', 0, 'lo16'),
        ('_pipeKUio', '_pipeKUio', 0, 'lo16'),
        ('_sockUio', '_sockUio', 0, 'lo16'),
        ('_sockUioBank', '_sockUioBank', 0, 'lo16'),
        ('_soHasDst', '_soHasDst', 0, 'lo16'),
        ('_soBounce', '_soBounce', 0, 'lo16'),
        ('_unpUio', '_unpUio', 0, 'lo16'),
        ('_unpUioBank', '_unpUioBank', 0, 'lo16'),
        ('_unpFrom', '_unpFrom', 0, 'lo16'),
        ('_pipeUioBank', '_pipeUioBank', 0, 'lo16'),
        ('_pipeSeg', '_pipeSeg', 0, 'lo16'),
        ('_netVfsUiomove', '_netVfsUiomove', 0, 'lo16'),
        ('_netVfsBank', '_netVfsBank', 0, 'lo16'),
        ('_netUioCp', '_netUioCp', 0, 'lo16'),
        ('_pipeChunk', '_pipeChunk', 0, 'lo16'),
        ('_pipeCur', '_pipeCur', 0, 'lo16'),
        ('_pipeCount', '_pipeCount', 0, 'lo16'),
        ('_pipeAllocIdx', '_pipeAllocIdx', 0, 'lo16'),
        ('_pipeRdFd', '_pipeRdFd', 0, 'lo16'),
        ('_pipeWrFd', '_pipeWrFd', 0, 'lo16'),
        ('_pipeUserFdOff', '_pipeUserFdOff', 0, 'lo16'),
        ('_pipeBothTmp', '_pipeBothTmp', 0, 'lo16'),
        ('_pipeNonBlk', '_pipeNonBlk', 0, 'lo16'),
        ('_pipeBufSz', '_pipeBufSz', 0, 'lo16'),
        ('_pgNew', '_pgNew', 0, 'lo16'),
        ('_pgNewSz', '_pgNewSz', 0, 'lo16'),
        ('_pgHead', '_pgHead', 0, 'lo16'),
        ('_pgCount', '_pgCount', 0, 'lo16'),
        ('_w5RxHdrLen', '_w5RxHdrLen', 0, 'lo16'),
    ],
    # ramdisk: the /RAM5 driver, lifted out of the core bank 2026-08-11.  All
    # lo16: the module runs at DBR = kernel bank (Mod_Load JSLs mod_init
    # without changing DBR, and the block ops are entered the same way), so its
    # body reads these DBR-relatively exactly as it did in-kernel.  The _rd*
    # four stayed kernel-side because the dispatch stubs report on them.
    'ramdisk': [
        ('_rdBufPtr', '_rdBufPtr', 0, 'lo16'),
        ('_rdSizeBytes', '_rdSizeBytes', 0, 'lo16'),
        ('_rdBlocks', '_rdBlocks', 0, 'lo16'),
        ('_rdPresent', '_rdPresent', 0, 'lo16'),
        ('_kFgxUserID', '_kFgxUserID', 0, 'lo16'),
        ('_fsDirBuf', '_fsDirBuf', 0, 'lo16'),
        ('_diskStates', '_diskStates', 0, 'lo16'),
        ('_blkCurHi', '_blkCurHi', 0, 'lo16'),
        ('_blkCurBufBank', '_blkCurBufBank', 0, 'lo16'),
        ('_blkSrcPool', '_blkSrcPool', 0, 'lo16'),
        ('_kBlkTabBase', '_kBlkTabBase', 0, 'lo16'),
    ],
    # pty: the pty driver, lifted out of the core bank 2026-08-11.  All lo16
    # for the same reason as ramdisk -- the module's ops are entered by the
    # chardev JSL trampoline with DBR still the KERNEL bank, so the bodies
    # read these DBR-relatively exactly as they did in-kernel.  That is what
    # let them move verbatim.
    #
    # The pair table and the scratch cells stayed kernel-side (the core bank
    # owns them; _Pty_Init zeroes them at boot), so the module reaches ALL of
    # its own state through this manifest.  BOTH RING BUFFERS ARE GONE FROM IT
    # NOW -- see the tombstone below.
    #
    # _fcbPtr / _libcTmp2 / _shTmp2 are NOT here: they are direct-page, and DP
    # labels never reach the listing this scrapes.  pty.mod PUTs
    # include/dpmap.s (one DUM block, emits nothing) instead of hardcoding
    # them the way bpf/serial/ramdisk do.
    # cda: /dev/cda (src/modules/cda).  Its ioctl op reads the syscall layer's
    # copy of the command and argument, DBR-relative with DBR = kernel bank
    # during chardev dispatch, as pty's does.
    # sscon: the Second Sight console.  Both are read by long loads whose
    # bank byte the module patches from the anchor, because its hooks run
    # with DBR = the far bank.
    'sscon': [
        ('_kConsoleBank', '_kConsoleBank', 0, 'lo16'),
        ('_kFgxUserID', '_kFgxUserID', 0, 'lo16'),
    ],
    'cda': [
        ('_kConRestoreReq', '_kConRestoreReq', 0, 'lo16'),
        ('_Sys_IoctlArgBank', '_Sys_IoctlArgBank', 0, 'lo16'),
        ('_Sys_IoctlArgLo', '_Sys_IoctlArgLo', 0, 'lo16'),
        ('_Sys_IoctlCmd', '_Sys_IoctlCmd', 0, 'lo16'),
    ],
    'pty': [
        ('_ptyTable', '_ptyTable', 0, 'lo16'),
        # `_ptyOutRings' AND `_ptyInRings' were here.  The out ring went at T4
        # increment 7 (unfed since increment 4 made `t_outq' a pty's pending
        # output); the in ring went at T6 increment 4a (unfed since the flip
        # made the master's write feed `ttyinput' at arrival).  256 bytes of
        # the CORE bank each.  Removing an entry CHANGES THE KERNEL BUILD ID,
        # which is the point of this table: a module built against the old
        # kernel is refused rather than loaded against a kernel whose symbols
        # have moved under it.
        ('_ptyTmpB', '_ptyTmpB', 0, 'lo16'),
        ('_ptyTmpR', '_ptyTmpR', 0, 'lo16'),
        ('_ptyTmpB2', '_ptyTmpB2', 0, 'lo16'),
        ('_ptyTmpB3', '_ptyTmpB3', 0, 'lo16'),
        ('_ptyTmpN', '_ptyTmpN', 0, 'lo16'),
        # The bulk-read path (apple/fgx#198): vfs.mod's bank and the one
        # entry point this module imports from it, plus the one-byte
        # region the packet prefix is handed to uiomove from.
        ('_ptyVfsBank', '_ptyVfsBank', 0, 'lo16'),
        ('_ptyVfsUiomove', '_ptyVfsUiomove', 0, 'lo16'),
        ('_ptyPktByte', '_ptyPktByte', 0, 'lo16'),
        ('_ptyDrN', '_ptyDrN', 0, 'lo16'),
        ('_ptyDrRun', '_ptyDrRun', 0, 'lo16'),
        ('_ptyNbFlag', '_ptyNbFlag', 0, 'lo16'),
        ('_ptyLtc', '_ptyLtc', 0, 'lo16'),
        ('_ttyTable', '_ttyTable', 0, 'lo16'),
        ('_nSelSleepers', '_nSelSleepers', 0, 'lo16'),
        ('_Sys_CallerBank', '_Sys_CallerBank', 0, 'lo16'),
        ('_Sys_IoctlArgBank', '_Sys_IoctlArgBank', 0, 'lo16'),
        ('_Sys_IoctlArgLo', '_Sys_IoctlArgLo', 0, 'lo16'),
        ('_Sys_IoctlCmd', '_Sys_IoctlCmd', 0, 'lo16'),
        ('_Sys_RdBufOff', '_Sys_RdBufOff', 0, 'lo16'),
        ('_Sys_RdMax', '_Sys_RdMax', 0, 'lo16'),
    ],
}

# Merlin32 listing column with the emitted address.  Two shapes:
#   "02/F993 : 00 00 ..."   - a byte-emitting Code/Data line
#   "02/46AC            |"   - a Directive line (e.g. a routine label sitting on
#                             its `MX %00` line, which emits no bytes but carries
#                             the label + its address).  Match the address column
#                             whether it's followed by ` : <bytes>` or the next
#                             `|` column separator, so a label whose definition
#                             line is a directive still resolves.
ADDR_RE = re.compile(r'\b02/([0-9A-Fa-f]{4})\s*(?::|\|)')


def parse_listing(path):
    """Return {label: 'XXXX'} for every label-definition line in the listing.

    A definition line is "...| 02/XXXX : <bytes> | <label> <directive> ...";
    the label is the first token of the final '|'-separated column.
    """
    addrs = {}
    with open(path, errors='replace') as f:
        for line in f:
            if '|' not in line:
                continue
            src = line.rsplit('|', 1)[-1].strip()
            if not src:
                continue
            label = src.split()[0]
            if label in addrs:
                continue                      # first (definition) wins
            m = ADDR_RE.search(line)
            if m:
                addrs[label] = 0x020000 | int(m.group(1), 16)   # bank-$02 addr
    return addrs


#==============================================================================
# Kernel build identity.
#
# A module image bakes kernel ADDRESSES (the EQUs above).  Load it against a
# different kernel build and every one of them points at the wrong byte -- a
# silent wrong-address failure, the same class as the `git checkout
# kernel_exports.s` boot-brick.  MOD_JT_CORE_BUILD (include/modules.s) is the
# word Mod_Load compares the module's header against.
#
# The identity is the low 15 bits of a SUM OF EXPORTED KERNEL ADDRESSES, with
# bit 15 forced set.  Two properties earn those choices:
#
#   - It is derived from the addresses THEMSELVES, so it moves whenever a baked
#     address moves -- including the case a kernel-size stamp misses, where two
#     equal-sized routines swap places and the total size is unchanged.
#   - It is NEVER $0000.  $0000 is the header's "not build-locked" sentinel
#     (hello.mod, which bakes no kernel addresses), so an id that could come
#     out zero by chance would silently disable the check on every module.
#     Bit 15 is one bit of entropy spent to make that impossible.
#
# NON-CIRCULAR, which is the whole trick.  The MODULE side is a resolved
# number, scraped from the kernel listing -- fine, modules assemble after the
# kernel.  The KERNEL side cannot be: the kernel would have to be assembled to
# produce the listing that produced the number to assemble into the kernel.  So
# the kernel side is emitted as a SYMBOLIC expression over kernel labels, which
# needs no listing at all and is generated before the kernel assembles; Merlin
# resolves it in the same pass that defines the labels.  Both sides are built
# by id_sample() below, so they cannot drift apart.
#
# WHY A SAMPLE, AND NOT EVERY SYMBOL.  MERLIN32 ABORTS -- SIGABRT, no message,
# no listing, ninja reports only "Abort trap: 6" -- ABOVE 80 LABEL REFERENCES
# IN EQU EXPRESSIONS.  Measured 2026-08-11 by bisection: 80 assembles, 81
# aborts.  It is a COUNT limit, not a value-range or nesting one; verified by
# holding the running total near zero with alternating +/- signs (still
# aborts at the same count) and by flattening the EQU chain to depth 2 (same
# cliff).  The manifests export 125 terms over 104 distinct symbols, so the
# full sum cannot be expressed.  id_sample() therefore dedupes, folds every
# constant byte offset into ONE term, and then strides evenly through what is
# left to at most ID_TERM_LIMIT symbols.
#
# What that costs, stated plainly: the id is a sum over a fixed SAMPLE of the
# exported addresses, so a kernel change that moved ONLY unsampled symbols
# would not be detected.  In practice a layout change moves a contiguous swath
# of the kernel and the sample spans every manifest, so this is a theoretical
# gap rather than a live one -- but it is a gap, and it is why the limit is set
# well below the cliff rather than at it.
#==============================================================================

# Well below the measured cliff of 81, so that adding manifest symbols (which
# only makes the sample sparser, never the file bigger) can never walk the
# kernel build into that silent abort.
ID_TERM_LIMIT = 64


# Every (kernel_symbol, byte_offset) any module manifest exports, in a fixed
# order.
def id_terms():
    return [(ksym, offset)
            for module in sorted(MANIFESTS)
            for _export, ksym, offset, _form in MANIFESTS[module]]


def id_sample():
    """The terms actually summed: (symbols, folded_constant).

    Duplicates are dropped (a symbol two modules both bake adds no detection
    power counted twice) and the byte offsets are folded into one constant --
    both purely to spend the scarce ~80 label references on distinct
    addresses.  If distinct symbols still exceed ID_TERM_LIMIT, stride evenly
    through them so the sample spans every manifest rather than stopping part
    way down the first.
    """
    terms = id_terms()
    const = sum(offset for _ksym, offset in terms)
    syms, seen = [], set()
    for ksym, _offset in terms:
        if ksym not in seen:
            seen.add(ksym)
            syms.append(ksym)
    if len(syms) > ID_TERM_LIMIT:
        stride = len(syms) / ID_TERM_LIMIT
        syms = [syms[int(i * stride)] for i in range(ID_TERM_LIMIT)]
    return syms, const


def build_id(addrs):
    """The 16-bit build identity, from resolved addresses (module side)."""
    syms, const = id_sample()
    return ((sum(addrs[s] for s in syms) + const) & 0x7FFF) + 0x8000


def emit_kernel_id(outpath):
    """Write the kernel side: the same sum, as a Merlin expression.

    Merlin has no operator precedence -- it evaluates strictly left to right --
    so `<sum>&$7FFF+$8000` is ((sum & $7FFF) + $8000), matching build_id().
    The chain is split across several EQUs to keep source lines short; only the
    final DA emits bytes (two, at the tail of the kernel image).
    """
    syms, const = id_sample()
    assert len(syms) <= ID_TERM_LIMIT
    lines, prev, PER_LINE = [], str(const), 6
    for i in range(0, len(syms), PER_LINE):
        expr = prev + ''.join('+' + s for s in syms[i:i + PER_LINE])
        prev = f'_kbid{i // PER_LINE:03d}'
        lines.append(f'{prev:23s} EQU     {expr}')

    text = ('* AUTO-GENERATED by tools/gen_kernel_exports.py --kernel-id -- DO NOT EDIT.\n'
            '* THE KERNEL BUILD IDENTITY.  A sum of exported kernel addresses,\n'
            '* low 15 bits, bit 15 forced set (never $0000 -- that is the module\n'
            "* header's 'not build-locked' sentinel).  Emitted SYMBOLICALLY, so\n"
            '* this file needs no kernel listing and can be generated BEFORE the\n'
            '* kernel assembles.  _JT_Init publishes it at MOD_JT_CORE_BUILD;\n'
            '* Mod_Load refuses any module whose header disagrees.  The module\n'
            '* side is the same sum, resolved from the listing.\n'
            '*\n'
            f'* {len(syms)} of {len(set(s for s, _ in id_terms()))} distinct exported symbols, plus the folded\n'
            '* offset constant.  MERLIN32 ABORTS SILENTLY above 80 label refs in\n'
            '* EQU expressions (measured: 80 builds, 81 aborts), so this is a\n'
            '* SAMPLE, not the whole set.  See tools/gen_kernel_exports.py.\n'
            + '\n'.join(lines) + '\n'
            f'_kernBuildId            DA      {prev}&$7FFF+$8000\n')

    try:
        if open(outpath).read() == text:
            print(f'gen_kernel_exports: {outpath} unchanged '
                  f'({len(syms)} sampled symbols)')
            return
    except FileNotFoundError:
        pass
    with open(outpath, 'w') as f:
        f.write(text)
    print(f'gen_kernel_exports: wrote {outpath} ({len(syms)} sampled symbols)')


def main():
    if len(sys.argv) == 3 and sys.argv[1] == '--kernel-id':
        emit_kernel_id(sys.argv[2])
        return
    if len(sys.argv) != 4:
        sys.exit('\n'.join(__doc__.strip().splitlines()[-2:]))
    listing, module, outpath = sys.argv[1], sys.argv[2], sys.argv[3]
    if module not in MANIFESTS:
        sys.exit(f'gen_kernel_exports: no manifest for module {module!r}')
    syms = MANIFESTS[module]
    addrs = parse_listing(listing)

    # The id sums EVERY manifest's symbols, not just this module's, so a
    # missing symbol anywhere is fatal here too -- name the module that needs
    # it, since it is usually not the one being generated.
    for ksym, _offset in id_terms() + [(s, o) for _e, s, o, _f in syms]:
        if ksym not in addrs:
            owner = next(m for m in sorted(MANIFESTS)
                         if any(s == ksym for _e, s, _o, _f in MANIFESTS[m]))
            sys.exit(f'gen_kernel_exports: kernel symbol {ksym!r} (needed by '
                     f'{owner}.mod) not found in {listing} -- renamed or removed? '
                     f'Update the kernel or the {owner} manifest.')

    out = []
    for export, ksym, offset, form in syms:
        addr = addrs[ksym] + offset
        val = f'${addr & 0xFFFF:04X}' if form == 'lo16' else f'${addr & 0xFFFFFF:06X}'
        out.append(f'{export:23s} EQU     {val}')

    # The build identity this module is locked to.  Its header carries this
    # word; Mod_Load refuses the module if the running kernel published a
    # different one at MOD_JT_CORE_BUILD.
    out.append(f'{"KERN_BUILD_ID":23s} EQU     ${build_id(addrs):04X}')

    text = ('* AUTO-GENERATED by tools/gen_kernel_exports.py -- DO NOT EDIT.\n'
            f'* Kernel-state addresses for {module}.mod, resolved from the kernel\n'
            '* build listing at build time (BSD ld-A style). Regenerated every\n'
            '* build, so these never drift stale; the generator is the guard.\n'
            + '\n'.join(out) + '\n')

    # WRITE ONLY ON CHANGE.  This file is an INPUT to the module link edge, and
    # the kernel listing it derives from is rewritten by every kernel build --
    # so writing unconditionally relinked all five modules whenever the kernel
    # was touched, even though the exported addresses had not moved.  ninja's
    # `restat` can only prune that if the mtime actually stays put.
    try:
        if open(outpath).read() == text:
            print(f'gen_kernel_exports: {outpath} unchanged '
                  f'({len(syms)} symbols from the {module} manifest)')
            return
    except FileNotFoundError:
        pass
    with open(outpath, 'w') as f:
        f.write(text)
    print(f'gen_kernel_exports: wrote {outpath} '
          f'({len(syms)} symbols from the {module} manifest)')


if __name__ == '__main__':
    main()
