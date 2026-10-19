#!/usr/bin/env python3
"""doc_wav_probe.py — audio-free playback oracle.

Analyzes a WAV captured from MAME (-wavwrite) to answer "is the DOC producing
sound, and at roughly what pitch?" without anyone having to listen.

Reports per-channel RMS (and dBFS), whether signal is present above a threshold,
and a dominant-frequency estimate (FFT if numpy is available, else autocorrelation).

Usage:
    tools/modplayer/doc_wav_probe.py capture.wav [--rms-threshold 0.003]
                                                 [--expect-hz 440 --tol 0.1]
Exit code 0 if signal is present (and, when --expect-hz given, within tolerance).
"""
import argparse
import math
import struct
import sys
import wave


def read_wav(path):
    with wave.open(path, "rb") as w:
        nch, sw, fr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw == 1:        # unsigned 8-bit
        samples = [b - 128 for b in raw]
        scale = 128.0
    elif sw == 2:      # signed 16-bit LE
        samples = list(struct.unpack("<%dh" % (len(raw) // 2), raw))
        scale = 32768.0
    elif sw == 4:      # signed 32-bit LE
        samples = list(struct.unpack("<%di" % (len(raw) // 4), raw))
        scale = 2147483648.0
    else:
        raise ValueError("unsupported sample width: %d bytes" % sw)
    chans = [samples[c::nch] for c in range(nch)]
    return fr, scale, chans


def rms(xs):
    if not xs:
        return 0.0
    return math.sqrt(sum(x * x for x in xs) / len(xs))


def dominant_hz(xs, fr, scale):
    """Best-effort dominant frequency. numpy FFT if present, else autocorrelation."""
    if len(xs) < 64:
        return None
    try:
        import numpy as np
        a = np.asarray(xs, dtype=float)
        a = a - a.mean()
        win = np.hanning(len(a))
        spec = np.abs(np.fft.rfft(a * win))
        spec[0] = 0.0
        freqs = np.fft.rfftfreq(len(a), 1.0 / fr)
        return float(freqs[int(np.argmax(spec))])
    except ImportError:
        # Autocorrelation: find first strong peak after lag 0.
        mean = sum(xs) / len(xs)
        ys = [x - mean for x in xs]
        n = len(ys)
        lo = max(1, fr // 5000)   # up to ~5 kHz
        hi = min(n - 1, fr // 50)  # down to ~50 Hz
        best_lag, best_val = 0, 0.0
        for lag in range(lo, hi):
            s = 0.0
            for i in range(n - lag):
                s += ys[i] * ys[i + lag]
            if s > best_val:
                best_val, best_lag = s, lag
        return fr / best_lag if best_lag else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("wav")
    ap.add_argument("--rms-threshold", type=float, default=0.003,
                    help="normalized RMS above which signal is 'present' (default 0.003)")
    ap.add_argument("--expect-hz", type=float, default=None)
    ap.add_argument("--tol", type=float, default=0.1, help="fractional tolerance for --expect-hz")
    args = ap.parse_args()

    fr, scale, chans = read_wav(args.wav)
    print("samplerate=%d Hz  channels=%d  frames=%d" % (fr, len(chans), len(chans[0]) if chans else 0))

    present = False
    dom = None
    for ci, xs in enumerate(chans):
        norm = [x / scale for x in xs]
        r = rms(norm)
        dbfs = 20 * math.log10(r) if r > 0 else float("-inf")
        ch_present = r > args.rms_threshold
        present = present or ch_present
        d = dominant_hz(xs, fr, scale) if ch_present else None
        if d and dom is None:
            dom = d
        print("  ch%d: rms=%.5f (%.1f dBFS)  signal=%s  dominant=%s"
              % (ci, r, dbfs, "YES" if ch_present else "no",
                 ("%.1f Hz" % d) if d else "-"))

    if not present:
        print("RESULT: SILENT (no signal above threshold)")
        return 1
    if args.expect_hz is not None:
        if dom is None:
            print("RESULT: signal present but no pitch estimate")
            return 1
        err = abs(dom - args.expect_hz) / args.expect_hz
        ok = err <= args.tol
        print("RESULT: %s — dominant %.1f Hz vs expected %.1f Hz (%.1f%% off)"
              % ("PASS" if ok else "PITCH MISMATCH", dom, args.expect_hz, err * 100))
        return 0 if ok else 1
    print("RESULT: SIGNAL PRESENT")
    return 0


if __name__ == "__main__":
    sys.exit(main())
