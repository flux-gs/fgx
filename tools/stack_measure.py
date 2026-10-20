#!/usr/bin/env python3
"""Relocated (P3-3 3.2): the canonical implementation now lives in the
toolchain at toolchain/src/ld/stack_measure.py so the linker (fgx_ld.py) can
import it and the toolchain stays self-contained across releases.  This shim
preserves the historical `tools/stack_measure.py` audit invocation path."""
import os
import runpy
import sys

_LD = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "toolchain", "src", "ld")
sys.path.insert(0, _LD)
runpy.run_module("stack_measure", run_name="__main__")
