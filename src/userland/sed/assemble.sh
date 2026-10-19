#!/bin/bash
# Reassemble the single-file sed.c from the vendored 2.11BSD source.
# The tool build compiles ONE .c (src/userland/sed/sed.c); sed.h DEFINES the globals (dedup the
# duplicate reend/lbend/cp tentative defs), then sed0.c + sed1.c minus includes.
SRC="$(dirname "$0")/../../../vendor/2.11BSD/usr/bin/sed"
OUT="$(dirname "$0")/sed.c"
{
  cat <<'HDR'
/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD sed(1)
 *   Ported from sed(1), 2.11BSD (sed0.c 4.2, sed1.c 4.2, sed.h 4.1; Berkeley).
 *   Copyright (c) 1985 The Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * Near-VERBATIM single-file assembly of sed0.c (compile) + sed1.c (execute) +
 * sed.h (declarations), produced by assemble.sh.  Edits vs upstream:
 *   1. drop sed.h's duplicate reend/lbend/cp tentative definitions (~99-101),
 *      which a single translation unit rejects as redefinitions;
 *   2. gline() ends a line on CR ('\r') as well as LF, so sed reads FGX-native
 *      ProDOS CR-terminated text files (build.sh stages on-disk text as CR;
 *      verbatim gline only saw '\n' -> never found a line -> zero output).
 *      Matches the FGX line-ending convention already in wc/uniq/fold/grep.
 * All sed logic — its own regexp (compile/advance) and command set — is unchanged.
 */
HDR
  echo '#include <stdio.h>'
  echo '/* ---- sed.h (inlined; dup reend/lbend/cp dropped) ---- */'
  awk 'NR>=3{ if($0 ~ /^char[[:space:]]*\*reend;/){r++; if(r>1)next} if($0 ~ /^char[[:space:]]*\*lbend;/){l++; if(l>1)next} if($0 ~ /^char[[:space:]]*\*cp;/){p++; if(p>1)next} print }' "$SRC/sed.h"
  echo '/* ---- sed0.c (compile/parse) ---- */'
  grep -vE '^#include' "$SRC/sed0.c" | awk 'NR>1'
  echo '/* ---- sed1.c (execute) ---- */'
  grep -vE '^#include' "$SRC/sed1.c" | awk 'NR>1'
} > "$OUT"
# FGX adaptation #2: gline() must end a line on CR too (ProDOS-native files;
# see the header note + wc/uniq/fold/grep).  \x27 = single quote, so the bash
# single-quoted perl program can still match sed's '\n' literal.
perl -i -pe 's/\(c = \*p2\+\+\) == \x27\\n\x27/(c = *p2++) == \x27\\n\x27 || c == \x27\\r\x27/' "$OUT"
grep -q "c == '\\\\r'" "$OUT" || { echo "assemble.sh: CR-terminator patch did NOT apply" >&2; exit 1; }
echo "wrote $OUT ($(wc -l < "$OUT") lines)"
