#!/usr/bin/env python3
"""build_bsdnet.py -- link the network C into code banks over one data bank.

An FGXM module's C normally runs with DBR on its own bank, so it cannot name
another module's global.  2.11BSD's layers share globals throughout, so these
modules share a data bank instead: DBR is bsdnetd's in all of them.

  bsdnetd          every .data.s, the coalesced tentative definitions, one set
                   of fcc_runtime_data.s, and a JML stub per function a data
                   cell names.  Every cell in it is stamped with its own bank.
  bsdnet0-3        a jump table at the start of the text, one JMP per function
                   another module needs; a JML stub per function it imports; EQUs
                   for the data symbols; the TU code and the fcc runtime code.

A call arrives at a stub in the caller's own bank (fcc's pile call pushes PHK),
and the stub's JML adds no stack frame, so the callee's RTL returns straight to
the caller.  A slot's address follows from its position in a sorted list, so a
code module needs no other code module's listing and the build has no cycle.
bsdnetd is assembled first, twice, because its cell table comes from its own
listing and goes last, where it cannot move what it describes.

The bank bytes of stubs are stamped when the last module loads, since no bank is
known before then: each module records its bank in bsdnetd, and the last to load
calls each one's _bnLink, then enters bsdnet_init.

Usage: build_bsdnet.py <split.list> <object dir> <modules out dir> <stem>...
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CODE = ("0", "1", "2", "3")
LAST = CODE[-1]
ORDINAL = {"d": 8, **{m: 9 + i for i, m in enumerate(CODE)}}
NAME = {"d": "bsdnetd", **{m: "bsdnet" + m for m in CODE}}
BANKIDX = {"d": 0, **{m: 1 + i for i, m in enumerate(CODE)}}
BANKBYTES = 2 * len(BANKIDX)
HDR = 40
INC = ("config", "macros", "kernel", "dpmap", "modules", "kernelc", "ktty")
RT_CODE = ("src/kernel/far/fcc_rt.s", "src/kernel/far/fcc_ktrap.s")
RT_DATA = "toolchain/lib/fcc_runtime_data.s"
ALWAYS_D = ("src/kernel/libc/alloc_state.s",)
LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\b")
WORD = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def org(m):
    return (0x05 + ORDINAL[m]) << 16


def labels(path):
    out = set()
    with open(path, errors="replace") as f:
        for line in f:
            m = LABEL.match(line)
            if m and not line.startswith(("*", ";")):
                out.add(m.group(1))
    return out


def operands(path):
    """Every identifier in a line, its comment dropped.  fcc's macro operands
    use `;' as a separator with no space before it, a comment has one."""
    out = set()
    with open(path, errors="replace") as f:
        for line in f:
            if line.startswith(("*", ";")):
                continue
            out.update(WORD.findall(re.split(r"\s;", line, 1)[0]))
    return out


def functions(path):
    out = set()
    with open(path, errors="replace") as f:
        for line in f:
            m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s+(ENT|MX)\b", line)
            if m:
                out.add(m.group(1))
    return out


def kern_id():
    """Build-locked, as net.mod and bpf.mod are: the driver holds kernel addresses."""
    with open(os.path.join(ROOT, "build/bsdnet/kernel_exports.s")) as f:
        for line in f:
            if line.startswith("KERN_BUILD_ID"):
                return line.split()[2]
    sys.exit("build_bsdnet: no KERN_BUILD_ID in build/bsdnet/kernel_exports.s")


def header(m, bss="0"):
    b = org(m)
    n = NAME[m]
    return f"""                MX      %11
                ORG     ${b:06X}
""" + "".join(f"                PUT     ../../../include/{i}.s\n" for i in INC) + f"""
bn_hdr          ASC     'FGXM'
                DFB     $00
                DFB     $00
                DFB     ${b >> 16:02X}
                DFB     $02
                DA      mod_init-${b:06X}
                DA      bn_end-bn_text
                DA      {bss}
                DA      bn_vtdir-bn_text
bn_name         ASC     '{n}'
                DS      {16 - len(n)}
                DA      $0000
                DA      {kern_id()}
                DS      4
bn_text         EQU     *
"""


def link_routine():
    """_bnLink -- stamp this module's stub bank bytes.  Entered with DBR on
    bsdnetd, where the banks are; left there."""
    s = "\n_bnLink         MX      %00\n                PHB\n"
    for off in range(BANKBYTES - 2, 0, -2):
        s += f"                LDA     bn_banks+{off}\n                PHA\n"
    s += """                LDA     bn_banks
                PHK
                PLB
                STA     |_bnBanks
"""
    for off in range(2, BANKBYTES, 2):
        s += f"                PLA\n                STA     |_bnBanks+{off}\n"
    s += f"""                LDY     #0
@l              CPY     #_bnStubBytes
                BCS     @d
                LDA     |_bnStubTab,Y
                TAX
                LDA     |_bnStubTab+2,Y
                PHY
                TAY
                LDA     |_bnBanks,Y
                SEP     #$20
                MX      %10
                STA     |$0000,X
                REP     #$20
                MX      %00
                PLY
                INY
                INY
                INY
                INY
                BRA     @l
@d              PLB
                RTL
_bnBanks        DS      {BANKBYTES}
"""
    return s


def stubs(imports, where):
    """imports: {name: (module, slot address)}"""
    out = ["; JML stubs; the bank byte is stamped at link\n"]
    rows = ["_bnStubTab      ANOP\n"]
    for name in sorted(imports):
        tm, addr = imports[name]
        out.append(f"{name:<15} DFB     $5C\n                DA      ${addr & 0xFFFF:04X}\n"
                   "                DFB     $00\n")
        rows.append(f"                DA      {name}+3\n                DA      {BANKIDX[tm] * 2}\n")
    rows.append(f"_bnStubBytes    EQU     {len(imports) * 4}\n")
    return "".join(out) + "".join(rows)


def assemble(workdir, m):
    n = NAME[m]
    d = os.path.join(workdir, n)
    r = subprocess.run(["merlin32", "-V", n + ".link.s"], cwd=d,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                       errors="replace")
    if r.returncode != 0 or not os.path.exists(os.path.join(d, n)):
        sys.stderr.write(r.stdout[-3000:])
        sys.exit(f"build_bsdnet: {n} did not assemble")
    return os.path.join(d, "_Output.txt")


def write_module(workdir, m, body):
    n = NAME[m]
    d = os.path.join(workdir, n)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, n + ".s"), "w") as f:
        f.write(body)
    with open(os.path.join(d, n + ".link.s"), "w") as f:
        f.write(f"            TYP    $06\n            DSK    {n}\n"
                f"            ORG    ${org(m):06X}\n\n            ASM    {n}.s\n"
                f"            SNA    {n}\n")


def symbol_addresses(listing, m):
    bank = f"{org(m) >> 16:02X}"
    rx = re.compile(r"\|\s*%s/([0-9A-F]{4})(?:\s*:[^|]*)?\s*\| ([A-Za-z_][A-Za-z0-9_]*)\s" % bank)
    out = {}
    with open(listing, errors="replace") as f:
        for line in f:
            if "| Comment" in line:
                continue
            k = rx.search(line)
            if k and k.group(2) not in out:
                out[k.group(2)] = int(k.group(1), 16)
    return out


def rel(path, workdir):
    return os.path.relpath(path, os.path.join(workdir, "x"))


def main():
    split, objdir, modout, stems = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
    place = {}
    with open(split) as f:
        for line in f:
            p = line.split("#")[0].split()
            if p:
                place[p[0]] = p[1]
    tus = {m: [] for m in CODE}
    asm = {m: [] for m in CODE}
    for s in stems:
        if s.endswith(".s"):
            asm[place[s]].append(os.path.join(ROOT, "src/kernel/bsdnet", s))
        else:
            tus[place[s]].append(os.path.join(objdir, s.replace("/", "_")))
    workdir = objdir

    defs = {m: set() for m in CODE}
    for m in CODE:
        for t in tus[m]:
            defs[m] |= functions(t + ".s")
        for a in asm[m]:
            defs[m] |= functions(a)
            if os.path.basename(a) == "net_asm.s":
                defs[m] |= functions(os.path.join(ROOT, "src/modules/common/kc_sys.s"))
    owner = {}
    for m in CODE:
        for fn in defs[m]:
            if fn in owner:
                sys.exit(f"build_bsdnet: {fn} is in bsdnet{owner[fn]} and bsdnet{m}")
            owner[fn] = m

    # What each side refers to.
    used = {m: set() for m in CODE}
    rtcode = [os.path.join(ROOT, p) for p in RT_CODE]
    for m in CODE:
        for t in tus[m]:
            used[m] |= operands(t + ".s")
        for a in asm[m]:
            used[m] |= operands(a)
            if os.path.basename(a) == "net_asm.s":
                used[m] |= operands(os.path.join(ROOT, "src/modules/common/kc_sys.s"))
    alld = [t + ".data.s" for m in CODE for t in tus[m]]
    usedd = set()
    for p in alld:
        usedd |= operands(p)

    # Exports: functions another module, or a data cell, names.  Sorted, so a
    # slot's address is a pure function of the list.
    exports = {m: [] for m in CODE}
    for fn, m in sorted(owner.items()):
        if fn in usedd or any(fn in used[o] for o in CODE if o != m):
            exports[m].append(fn)
    # bsdnet_init is entered by the last module's mod_init.
    if owner.get("bsdnet_init", LAST) != LAST and "bsdnet_init" not in exports[owner["bsdnet_init"]]:
        exports[owner["bsdnet_init"]].append("bsdnet_init")
        exports[owner["bsdnet_init"]].sort()
    slot = {}
    for m in CODE:
        for i, fn in enumerate(exports[m]):
            slot[fn] = (m, (org(m) & 0xFF0000) + HDR + i * 3)

    # The data image.
    subprocess.check_call([sys.executable, os.path.join(ROOT, "toolchain/tools/gen_commons.py"),
                           os.path.join(objdir, "commons.data.s")]
                          + [t + ".comm" for m in CODE for t in tus[m]],
                          stdout=subprocess.DEVNULL)
    dstubs = {fn: slot[fn] for fn in owner if fn in usedd}
    ddir = os.path.join(workdir, NAME["d"])
    os.makedirs(ddir, exist_ok=True)
    table = os.path.join(ddir, "fnptr_patchsites.s")
    with open(table, "w") as f:
        f.write("_modFnPtrTab    ANOP\n_modFnPtrBytes  EQU     0\n")

    def dbody():
        s = header("d")
        s += "                DS      $100-40\n"
        s += """bn_vtdir        ASC     'VTDR'
                DA      VT_BSDNET
                DA      bn_banks-bn_text
                DA      VT_END
bn_banks        DS      """ + str(BANKBYTES) + """               ; each module's bank, bsdnetd first
bn_links        DS      """ + str(BANKBYTES) + """               ; each module's _bnLink, in its own bank
"""
        s += stubs(dstubs, "d")
        s += link_routine()
        s += """
mod_init        MX      %00
                PHP
                REP     #$30
                MX      %00
                PHB
                PHK
                PLB
                ; every cell in this image holds an address in this bank
                SEP     #$20
                MX      %10
                PHK
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY
                LDX     #0
@c              CPX     #_modFnPtrBytes
                BCS     @cd
                PHX
                LDA     |_modFnPtrTab,X
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA     |$0000,X
                REP     #$20
                MX      %00
                PLX
                INX
                INX
                BRA     @c
@cd             ANOP
                SEP     #$20
                MX      %10
                PHK
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     |bn_banks
                LDA     #_bnLink
                STA     |bn_links
                PLB
                PLP
                SEC
                RTL
"""
        for p in ALWAYS_D:
            s += f"                PUT     {rel(os.path.join(ROOT, p), workdir)}\n"
        s += f"                PUT     {rel(os.path.join(ROOT, RT_DATA), workdir)}\n"
        for p in alld:
            s += f"                PUT     ../{os.path.basename(p)}\n"
        s += "                PUT     ../commons.data.s\n"
        s += "                PUT     fnptr_patchsites.s\n"
        s += "bn_end          EQU     *\n"
        # Wait channels are these addresses' low 16 bits, and the kernel's fixed
        # ones are $FFxx (check_wchans.py): this image stays below them.  So a
        # network channel can alias only another module's address channel, whose
        # sleeper re-tests its condition as BSD's all do.
        s += f"                ERR     bn_end-${org('d'):06X}/$FF00\n"
        return s

    write_module(workdir, "d", dbody())
    listing = assemble(workdir, "d")
    subprocess.check_call([sys.executable, os.path.join(ROOT, "tools/gen_mod_bankpatch.py"),
                           listing, table, "--bank", f"{org('d') >> 16:02X}", "--allow-empty"],
                          stdout=subprocess.DEVNULL)
    listing = assemble(workdir, "d")
    subprocess.check_call([sys.executable, os.path.join(ROOT, "tools/check_mx.py"), listing],
                          stdout=subprocess.DEVNULL)
    dsyms = symbol_addresses(listing, "d")
    for name in ("bn_banks", "bn_links"):
        if name not in dsyms:
            sys.exit(f"build_bsdnet: {name} not found in the bsdnetd listing")
    dlabels = set()
    for p in alld + [os.path.join(objdir, "commons.data.s"), os.path.join(ROOT, RT_DATA)] + \
            [os.path.join(ROOT, p) for p in ALWAYS_D]:
        dlabels |= labels(p)

    # The code images.
    for m in CODE:
        refs = set(used[m])
        for p in rtcode:
            refs |= operands(p)
        refs |= {"bn_banks", "bn_links"}
        eq = ""
        base = org(m) & 0xFF0000
        for name in sorted((dlabels | {"bn_banks", "bn_links"}) & refs):
            if name not in dsyms:
                sys.exit(f"build_bsdnet: data symbol {name} not in the bsdnetd listing")
            eq += f"{name:<15} EQU     ${base + dsyms[name]:06X}\n"
        imports = {fn: slot[fn] for fn in slot
                   if slot[fn][0] != m and fn in used[m]}
        if m == LAST and owner.get("bsdnet_init", LAST) != LAST:
            imports["bsdnet_init"] = slot["bsdnet_init"]
        idx = BANKIDX[m]
        s = header(m) + eq
        s += "; the slots: another module's stub JMLs here\n"
        for fn in exports[m]:
            s += f"                JMP     {fn}\n"
        s += """bn_vtdir        ASC     'VTDR'
                DA      VT_END
"""
        s += stubs(imports, m) + link_routine()
        s += f"""
_bnDataBank     DS      2               ; MODBANK-OK: read under PHK/PLB
mod_init        MX      %00
                PHP
                REP     #$30
                MX      %00
                PHB
                PHK
                PLB
                LDA     #VT_BSDNET
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @have
                LDA     #@msgNoData
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                BRL     @fail
@msgNoData      ASC     'bsdnet: no bsdnetd - load it first',$00
@have           TXA
                AND     #$00FF
                STA     |_bnDataBank
                TAX
                SEP     #$20
                MX      %10
                PHK
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY                     ; Y = our bank
                SEP     #$20
                MX      %10
                TXA
                PHA
                PLB                     ; DBR = the data bank
                REP     #$20
                MX      %00
                TYA
                STA     bn_banks+{idx * 2}
                LDA     #_bnLink
                STA     bn_links+{idx * 2}
"""
        if m == LAST:
            s += _last_module()
        s += """@back           PHK
                PLB
@out            PLB
                PLP
                SEC
                RTL
@fail           PLB
                PLP
                CLC
                RTL
"""
        if m == LAST:
            s += _last_strings()
        s += f"                PUT     {rel(os.path.join(ROOT, 'src/kernel/far/fcc_dp.s'), workdir)}\n"
        for p in RT_CODE:
            s += f"                PUT     {rel(os.path.join(ROOT, p), workdir)}\n"
        for a in asm[m]:
            if os.path.basename(a) == "w5_asm.s":
                s += "                PUT     ../kernel_exports.s\n"
            if os.path.basename(a) == "net_asm.s":
                s += f"                PUT     {rel(os.path.join(ROOT, 'src/modules/common/kc_sys.s'), workdir)}\n"
            s += f"                PUT     {rel(a, workdir)}\n"
        for t in tus[m]:
            s += f"                PUT     ../{os.path.basename(t)}.s\n"
        s += "bn_end          EQU     *\n"
        write_module(workdir, m, s)
        subprocess.check_call([sys.executable, os.path.join(ROOT, "tools/check_mx.py"),
                               assemble(workdir, m)], stdout=subprocess.DEVNULL)

    os.makedirs(modout, exist_ok=True)
    for m in ("d",) + CODE:
        n = NAME[m]
        os.replace(os.path.join(workdir, n, n), os.path.join(modout, n))


def _last_module():
    """The last module's mod_init continues here with DBR on the data bank: stamp every
    module's stubs, enter the C, log its answer."""
    s = ""
    # A module that never loaded has a zero link and a zero bank: refuse, by name.
    for m, i in BANKIDX.items():
        s += f"""                LDA     bn_links+{i * 2}
                BNE     @have{i}
                PHK
                PLB
                LDA     #@msgMiss{i}
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                BRL     @fail
@have{i}        ANOP
"""
    for i in range(len(BANKIDX)):
        s += f"""                PHK
                PEA     @ret{i}-1
                SEP     #$20
                MX      %10
                LDA     bn_banks+{i * 2}
                PHA
                REP     #$20
                MX      %00
                LDA     bn_links+{i * 2}
                DEC
                PHA
                RTL
@ret{i}         ANOP
"""
    s += """                PHD
                LDA     #FGX_DP_KERNELC
                TCD
                PHK
                PEA     @retc-1
                PHK
                PEA     bsdnet_init-1
                RTL
@retc           PLD
                PHK
                PLB
                PHA
                CMP     #0
                BNE     @bad
                LDA     #@msgOk
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                BRA     @eol
@bad            LDA     #@msgBad
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDA     1,S
                LDX     #KSVC_LOGDEC16
                JSL     SYS_KCALL
@eol            LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                PLA
"""
    return s


def _last_strings():
    return """@msgOk          ASC     'bsdnet: ok',$00
@msgBad         ASC     'bsdnet: BROKEN ',$00
""" + "".join(f"@msgMiss{i}      ASC     'bsdnet: {NAME[m]} not loaded',$00\n"
              for m, i in BANKIDX.items())


if __name__ == "__main__":
    main()
