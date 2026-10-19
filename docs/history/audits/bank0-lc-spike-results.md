# The language-card spike -- measured, not argued

**Result: 16,384 bytes of bank-0 RAM confirmed, and FGX runs on it.**

> **CONFIRMED ON REAL HARDWARE, 2026-08-13.** A IIgs booting the probe image
> reports **PASS** -- the same verdict MAME gives. Both `$D000` banks are
> independently writable and hold different values at the same address, and the
> region above them is one flat, unswitched 8 K. **This was the single item the
> assessment listed as unsettleable in emulation**, and it is now settled: the
> hardware behaves as the documentation describes, on silicon.

Run 2026-08-13 on branch `spike/language-card` (commit `3f42ea1bf`, **not for
merge** -- the probe is a throwaway). This supersedes every "verify before
trusting" caveat attached to the language-card option in
`docs/history/audits/bank0-upper-region-options.md` and
`docs/history/audits/bank0-assessment-review-response.md`.

---

## 1. What was measured

A boot-time probe drives the `$C08x` switches with the two-consecutive-reads
idiom, writes distinct canaries into each region, reads them back, and then
**deliberately leaves LC RAM mapped** so the rest of boot and the whole suite
run with it in place.

| question | measured | verdict |
|---|---|---|
| initial switch state | `$C011=$80`, `$C012=$00` | read-ROM, bank 2 -- **matches the documented power-on state** |
| `$D000` bank 1 writable? | wrote `$A5`, read `$A5` | **yes** |
| `$D000` bank 2 writable? | wrote `$C3`, read `$C3` | **yes** |
| are the banks **distinct**? | bank 1 re-read `$A5` after bank 2 got `$C3` | **yes -- separate RAM, not an alias** |
| `$E000-$FFFF` writable? | wrote `$E7`, read `$E7` | **yes** |
| is `$E000` bank-switched? | same `$E7` under bank 2 | **no -- one flat 8K** |

**Total: 4,096 + 4,096 + 8,192 = 16,384 bytes**, exactly the "16 KB of RAM in a
12 KB window" structure the hardware reference describes. Confirmed by
measurement rather than inherited from a document.

## 2. The result that actually matters

**With LC RAM mapped over bank-0 ROM for the entire run, the full MAME suite
passes 97 of 97.**

That covers interrupts (heartbeat, serial, console), the network stack and pty
traffic under `telnet_loopback`'s nine live tasks, kernel C (`kcprobe`), module
loading, SmartPort detection, and the filesystem. The boot log is clean:
modules load, `/` mounts, `ls /` works.

**And nothing contends for the space.** After a full networking run, the
complete 4,096 bytes at `$D000` and 8,192 bytes at `$E000` contain **exactly one
non-zero byte each -- the probe's own canaries**. Twelve kilobytes examined,
two bytes written, both ours. No stray write from the kernel, the ROM, the
toolbox, or any interrupt handler.

## 3. Why the earlier risk rating was wrong

The option was shelved at **high** risk on two premises, both false:

- *"Native vectors live at `$00:FFE0-$FFFF`, inside the space."* They are
  fetched from the bank-`$FF` ROM shadow while I/O shadowing is on, and the
  interrupt entry stub sits at `$C071` in the soft-switch space, which `$C08x`
  does not touch. **97 passing tests with interrupts firing throughout is the
  empirical form of that argument.**
- *"An IRQ arriving in the wrong LC state is the sharp edge."* The suite
  includes the SmartPort path, the serial IRQ path and heavy pty churn. Nothing
  broke.

**FGX has always driven these switches.** `main.s:1409-1410` does
`LDAL $E0C082` twice to force ROM in before calling `$00FE1F` for machine
identification. The idiom, the address form and the ordering constraint were
already in the tree -- only the other direction had ever been used.

## 4. What this unlocks

Moving the per-pid kernel stacks (3,072 B), the per-pid direct pages (3,072 B)
and `FGX_DP_KERNELC` (256 B) -- **6,400 B** -- into the flat 8 KB at
`$E000-$FFE3` leaves 1,764 B spare there and both `$D000` banks (8,192 B)
completely free.

The arena would become `$0C00-$B2FF` plus the reclaimed `$B300-$BFFF`:
**about 180 pages against 153 today, +27 pages**. That is:

- **apple/fgx#45's `NPROC` ladder unblocked** -- every slot costs 2 arena pages,
  so +27 pages is room for many more processes;
- **or** kernel stacks doubled to 512 B x 12 = 6,144 B, which also fits in the
  spare `$D000` banks, if the kernel-C depth that Phase 2a warned about arrives;
- **or** both, since they draw on different parts of the 16 KB.

**This is the first option in the entire assessment that raises the ceiling
rather than rearranging what is under it.**

## 5. What is still owed before shipping it

The spike proves feasibility. A production change needs:

1. **`$C068` STATEREG discipline** around any path that must select ROM --
   principally the SmartPort excursion, which enters emulation mode **without
   masking interrupts** (`block.s:225-227`). The state register packs the
   read-ROM and bank selects for a one-instruction save/restore; the documented
   trap is that **write-enable is not in the register and cannot be read back**.
2. **A boot ordering rule.** FGX calls bank-0 ROM twice, both at boot:
   `loader.s:578` (`JSR $FDED`) and `main.s:1426` (`JSR $FE1F`). The switch-in
   must happen after hardware detection. The probe already sits after it.
3. **Reset behaviour.** Reset reinitialises the switches to read-ROM, so the
   switch-in must be part of the boot path, not a one-time setup.
4. **A geometry checker rule** so nothing silently places bank-0 data expecting
   ROM to be mapped there.
5. ~~**Real hardware confirmation.**~~ **DONE** -- a real IIgs reports PASS.

**What real hardware confirmed, exactly:** the run was the
**probe-and-restore** form, which proves the RAM behaves as documented.

**The session-long hardware test is NOT obtainable this way and is not
pending** (the maintainer, 2026-08-13). A diagnostic image that boots, prints and
restores cannot demonstrate a working session, and an image that leaves LC RAM
mapped would have to be *used* as a daily system to prove anything -- which is
not a test anyone can run to a schedule. **So "does FGX survive a session on
LC RAM" rests on the 97/97 emulator result and does not have a hardware
counterpart.** That is a real limit on the evidence, recorded rather than left
as an open action item.

The practical consequence: the session question gets answered **by shipping**,
not by a spike. Productionisation carries that risk, and the mitigations below
are what manage it.
