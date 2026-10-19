# docs/history — dated design records (not the live record)

Everything under `docs/history/` is a **dated record**: the plans and designs
behind work as it was proposed, point-in-time audits and measurements, and the
abandoned message-passing design.  Each is true as of its date and is not
revised as the system moves on.  Read it for *why* the code is shaped as it is,
not for *what is true now*.

## Where the live record lives

| Question | Authoritative source |
|----------|----------------------|
| What's **shipped**? | [`../../CHANGELOG.md`](../../CHANGELOG.md) |
| What's **next**? | [`../ROADMAP.md`](../ROADMAP.md) |
| How does subsystem X **work today**? | the guides indexed in [`../README.md`](../README.md) |
| 65816 / IIgs / Merlin32 / MAME gotchas | [`../iigs-lessons/`](../iigs-lessons/) |

## What's here

- **`plans/`** — dated plans and designs, named `YYYY-MM-DD-<topic>.md`.  A plan
  may describe work that landed as written, landed differently, or was dropped;
  the commit history and the current guides say which.
- **`audits/`** — point-in-time inventories, reviews and measurements.
- The dated reports and screenshots at this level — measurements and captures
  kept beside the plans that cite them.
- **[`ipc.md`](ipc.md)** — the message-passing design FGX did not adopt.
