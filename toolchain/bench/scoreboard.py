def print_scoreboard(snap):
    print(f"# fbench — {snap['tag']} (toolchain {snap['toolchain_git'][:12]})")
    g = snap["size"]["goldens"]
    s = snap["system"]
    print(f"\n## Size\n- goldens: {g['total_bytes']} bytes, {g['total_asm_lines']} asm lines")
    print(f"- kernel: {s['kernel_bytes']}  fcc-userland: {s['fcc_userland_bytes']}")
    print(f"- DP(fcc): {snap['dp']['fcc_bytes']} bytes  overlaps: {len(snap['dp']['overlaps'])}")
    # Cycles come from the kernel harness (us_per_call); older bare-metal
    # snapshots used cyc_per_call — accept either.
    def _cyc(v): return v.get("us_per_call", v.get("cyc_per_call"))
    if snap["cycles"]:
        measured = {n: v for n, v in snap["cycles"].items() if _cyc(v) is not None}
        if measured:
            print("\n## Cycles (us/call, kernel) — emulated; delta-vs-baseline authoritative")
            print("| bench | us/call | iters |\n|---|--:|--:|")
            for n, v in sorted(snap["cycles"].items()):
                cyc = f"{_cyc(v):.1f}" if _cyc(v) is not None else "-"
                print(f"| {n} | {cyc} | {v.get('iters') or '-'} |")
        else:
            print(f"\n## Cycles: UNMEASURED — {len(snap['cycles'])} benches built ok "
                  f"(MAME absent; run on a machine with MAME for live us/call numbers)")
    else:
        print("\n## Cycles: UNMEASURED (size-only snapshot — MAME/merlin32 absent or no markers)")
