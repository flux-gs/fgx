# Cosmetic / small-issue notes

Running list of small or cosmetic items to revisit later. Reviewed periodically; items don't block any in-flight work. Add freely; sort by area roughly. If an item turns out to be quick during a review, just do it inline.

Format per item:
- **YYYY-MM-DD** — short description.
  Optional second line with context (file path, repro, etc.).

## Open

- **2026-06-06** — Boot: halt with a visible error if the root mount fails.
  `src/kernel/main.s` (`_kfp905`, `JSL KFAR_VFS_ROOTMOUNT`) checks the result of
  `src/kernel/far/root_mount.c` but only logs the success case; on failure it
  stays silent and the boot dies several lines later with a generic "init load
  failed", which doesn't name the mount as the cause.

- **2026-05-17** — Move the ProDOS module's in-memory block buffers out of
  kernel-resident FGX_DATA. `_fsDataBuf` / `_fsIndexBuf` / `_fsDirBuf`
  (`include/fs.s`, allocated in `include/memmap.s`) are still kernel statics
  read directly by `src/drivers/fs/fs.s`; `src/modules/prodos/prodos.s`'s FOPs
  bake `KAD_*` EQUs against them at build time. Moving them module-private
  would still shrink FGX_DATA; not done.

- **2026-05-15** — `tools/check_mx.py` only walks `fgx_S*_Output.txt` plus
  `fgxfar_Output.txt`/`fgxtty_Output.txt`; it still doesn't walk module
  listings (`build/module_*_Output.txt`), so a module-local static-MX leak
  goes undetected the way a kernel/far/tty one wouldn't.


- **2026-05-14** — Minor video tearing during `ls -l` scroll (timing margin
  between the VBL renderer in `src/kernel/far/console/console_buffer.s` /
  `console_render.s` and the heartbeat task body). Cosmetic, low priority.

- **2026-05-12** — Colorize executables in `ls -l` (target colour: yellow).
  Still blocked on two pieces: (1) nothing exposes a ProDOS file-type/exec bit
  to stat — `src/drivers/fs/fs.s`'s stat struct carries only `ST_ProFlags`
  (access byte) and `ST_ProStorage` (storage nibble), and the VFS ProDOS node
  layer (`src/kernel/vfs/prodos_node.c`) only distinguishes `VREG`/`VDIR`; (2)
  palette 0 (`src/kernel/far/console/console_color.s`) still has only a few fg
  slots, so SGR 33 (yellow) has nowhere uncontested to map.

- **2026-05-10** — Add a `-?` usage option consistently across userland
  commands (23 tools use `getopt(3)` today; none document a dedicated help
  flag).

- **2026-05-10** — Better text-color interface (long-term). 640 SHR text is
  still 4 colors per pixel via per-row palette switching; see
  `docs/history/plans/2026-06-30-scanline-framebuffer-console-design.md` for
  the no-dithering rationale. Revisit what a legible 16-color text palette and
  SGR mapping would look like.

- **2026-06-05** — dhclient-specific socket/FS interaction: a file dhclient
  creates can be unreadable by the *next* dhclient process (plain FS
  create-then-reopen was disproven as a general bug by a standalone
  diagnostic; create/reopen works in every other dimension tested). Likely a
  socket<->FS scratch/buffer interaction in `src/userland/dhclient/dhclient.c`
  around the W5100 socket fd + file ops. Worked around by shipping
  `/etc/dhcp.lease` as a pre-existing placeholder so dhclient only overwrites.
  Root cause not yet found; low priority.

- **2026-06-06** — PLAN (net direction): software IP/ICMP stack so netdump
  sees ICMP. Per `docs/networking.md`, ICMP is still fully offloaded to the
  W5100 (no software IP stack); while a MACRAW/`/dev/bpf0` capture or an
  IPRAW-ICMP socket is open, the chip's hardware ping auto-reply stops, so
  netdump can't show FGX answering its own pings. Planned fix: a software
  IP/ICMP/ARP path over MACRAW frames, keeping UDP/TCP on the W5100 offload.
  Big effort; not started.

- **2026-06-06** — TOOLING (evaluate): "Graphify" tool. Look at what it is and
  whether it would help FGX's workflow (kernel call/IRQ-chain visualization,
  memory-map diagrams, dependency graphs). Not blocking; pure dev-experience
  eval, not yet done.
