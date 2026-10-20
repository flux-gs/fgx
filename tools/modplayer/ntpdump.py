#!/usr/bin/env python3
"""Parse a NinjaTracker .ntp and tally note-lifecycle effects over the full song.
Format: re/shellplay/PHASE_A_NOTES.md §1 (little-endian).

Used as the closed-loop oracle for ntpplay's -c (check) diag counts: it walks the
order table exactly as the engine does, so its lifecycle counts equal the engine's
dispatch counts for a correct implementation.
"""
import sys


def parse_ntp(buf):
    o = 0
    magic = buf[0:4]; o = 4
    version = buf[o]; o += 1
    ntracks = buf[o]; o += 1
    ninstr  = buf[o]; o += 1
    npat    = buf[o]; o += 1
    norder  = buf[o]; o += 1
    namelen = buf[o]; o += 1
    songname = buf[o:o+namelen]; o += namelen
    tracks = []
    for _ in range(ntracks):
        tracks.append(tuple(buf[o:o+3])); o += 3
    instruments = []
    for _ in range(ninstr):
        typ = buf[o]
        length = buf[o+1] | (buf[o+2] << 8) | (buf[o+3] << 16)
        rep_ptr = buf[o+4] | (buf[o+5] << 8) | (buf[o+6] << 16)
        rep_len = buf[o+7] | (buf[o+8] << 8) | (buf[o+9] << 16)
        vol = buf[o+10]; fine = buf[o+11]; docptr = buf[o+12]; docsize = buf[o+13]
        mlen = buf[o+14]; o += 15
        name = buf[o:o+mlen]; o += mlen
        instruments.append(dict(type=typ, length=length, vol=vol, finetune=fine,
                                docptr=docptr, docsize=docsize, name=name))
    order = list(buf[o:o+norder]); o += norder
    pattern_base = o
    patstep = ntracks * 256                      # 64 rows * ntracks * 4 bytes

    def note(pat, row, trk):
        off = pattern_base + pat*patstep + row*ntracks*4 + trk*4
        return buf[off:off+4]                     # (note_index, instrument, effect, value)

    # tally effects over the actual played song (order table walk)
    eff = {}
    life = dict(setvol=0, setvol0=0, volslide=0, notecut=0, notedelay=0,
                setspeed=0, posjump=0, patbreak=0, slideup=0, slidedown=0, porta=0,
                arp=0, vibrato=0, combo5=0, combo6=0)
    for pat in order:
        for row in range(64):
            for trk in range(ntracks):
                n = note(pat, row, trk)
                if len(n) < 4:
                    continue
                e, v = n[2], n[3]
                eff[e] = eff.get(e, 0) + 1
                if e == 0x00 and v != 0:
                    life["arp"] += 1
                if e == 0x0C:
                    life["setvol"] += 1
                    if v == 0:
                        life["setvol0"] += 1
                elif e == 0x0A:
                    life["volslide"] += 1
                elif e == 0x0F:
                    life["setspeed"] += 1
                elif e == 0x0B:
                    life["posjump"] += 1
                elif e == 0x0D:
                    life["patbreak"] += 1
                elif e == 0x01:
                    life["slideup"] += 1
                elif e == 0x02:
                    life["slidedown"] += 1
                elif e == 0x03:
                    life["porta"] += 1
                elif e == 0x04:
                    life["vibrato"] += 1
                elif e == 0x05:
                    life["combo5"] += 1
                elif e == 0x06:
                    life["combo6"] += 1
                elif e == 0x0E:
                    sub = v >> 4
                    if sub == 0x0C:
                        life["notecut"] += 1
                    elif sub == 0x0D:
                        life["notedelay"] += 1
    return dict(magic=magic, version=version, ntracks=ntracks, ninstr=ninstr,
                npat=npat, norder=norder, songname=songname, tracks=tracks,
                instruments=instruments, order=order, effect_counts=eff,
                lifecycle_counts=life)


def main(argv):
    if len(argv) < 2:
        print("usage: ntpdump.py FILE.ntp [--counts]")
        return 2
    d = parse_ntp(open(argv[1], "rb").read())
    lc = d["lifecycle_counts"]
    if "--counts" in argv:
        # one line, matching the engine's diag summary field order + width.
        # 4 hex digits per field: the engine prints these via print_hex16 (16-bit
        # counters), and real songs exceed 255 (conrad: setv=901, vsl=2351).
        print(f"cut={lc['notecut']:04X} setv={lc['setvol']:04X} "
              f"vz={lc['setvol0']:04X} vsl={lc['volslide']:04X} ndl={lc['notedelay']:04X} "
              f"spd={lc['setspeed']:04X} pj={lc['posjump']:04X} br={lc['patbreak']:04X} "
              f"su={lc['slideup']:04X} sd={lc['slidedown']:04X} po={lc['porta']:04X} "
              f"arp={lc['arp']:04X} vib={lc['vibrato']:04X} "
              f"c5={lc['combo5']:04X} c6={lc['combo6']:04X}")
        return 0
    print(f"{d['songname'].decode('latin1')!r}  v{d['version']} "
          f"tracks={d['ntracks']} instr={d['ninstr']} pat={d['npat']} order={d['norder']}")
    print("lifecycle:", lc)
    print("all effects (MOD# -> count):",
          {f"{k:X}": v for k, v in sorted(d['effect_counts'].items())})
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
