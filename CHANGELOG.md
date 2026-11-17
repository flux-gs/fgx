# Changelog

All notable changes to FGX, a port of 2.11BSD to the Apple IIgs.  Format:
[Keep a Changelog](https://keepachangelog.com); versions:
[SemVer](https://semver.org).  See docs/VERSIONING.md.

## [2.3.0] - 2026-11-17

### Changed

- fcc: `inline' is a name unless a declaration follows it
  K&R A.2.4 lists the keywords and `inline' is not among them; its only
  allowance is that "Some implementations also reserve the words fortran
  and asm."  fcc took `inline' as C99's function specifier everywhere, so
  2.11BSD cat.c, which declares `int ... inline;' and assigns `inline = 0;'
  at the start of a statement, was refused with "expected declarator name".
  
  `inline' is now a specifier only when the next token can carry a
  declaration on: an identifier, a type keyword, static, struct, union,
  enum or typedef.  Everywhere else it is an ordinary identifier.
  `static inline int f' and `inline int f' compile as before.
  
  Fixture M40/inline_ident declares, assigns and compares a variable named
  `inline' and returns 42; the previous compiler refuses it.  All 719 fcc
  fixtures pass.

- kernel: fstat on a pipe answers instead of jumping through its FCB
  root_fstat chose vn_stat on `f_type == DTYPE_VNODE' alone.  A descriptor
  the core makes (kdesc_alloc: a pipe end, among others) is DTYPE_VNODE
  provisionally, with an FCB in f_data rather than a vnode, so fstat on
  an unused pipe called vn_stat on that pointer and the machine took a wild
  jump.  `echo hi | cat' with 2.11BSD's cat, which fstats its stdin and
  stdout before reading, brought it down every time.
  
  The vnode test is now `f_ops == &vnops', the one vector vfs_openat
  installs, as _Sys_VnodeFp and ld_fd_is_vnode already decide it; fp_isvn
  is that test, shared by ld_fd_is_vnode and root_fstat.  A descriptor
  that is not a vnode's answers as 4.3BSD-Reno's fstat
  (kern/kern_descrip.c) answers a socket: soo_stat's zeroed buffer.

- head(1), cat(1): the 2.11BSD sources, verbatim
  Both were rewrites that wrote one byte per write(2).  head now is
  vendor/2.11BSD/usr/ucb/head.c, which reads with fgets and writes a line
  per printf/fflush; cat is vendor/2.11BSD/usr/bin/cat.c, with its
  fastcat block copy, stdio for the flag paths, and the fstat
  input-is-output guard the rewrite had dropped.
  
  `head -200' of a man page to the console takes 589 frames, down from
  2,137, at 7 MHz.  The POSIX `-n N' the rewrite accepted is gone, as it
  is upstream; `head -N' is the form.

- ufs: a file's new data block is not zeroed on the disk first
  ufs_bmapx sent every block a file grew by through bmapnew, which
  cleared a buffer and wrote it synchronously before handing back the
  number; ufs_write then wrote the real bytes over it.  Every appended
  block cost two synchronous writes.
  
  2.11BSD's bmap (usr/sys/sys/ufs_bmap.c) allocates a data block with
  `balloc(ip, flags)', cleared only when the caller asks, and writes it
  synchronously only under B_SYNC, which only directories pass, "so they
  never appear with garbage in them on the disk".  Indirect blocks are
  cleared and written synchronously "so that indirect blocks never point
  at garbage".  bmapnew now takes that distinction: indirect blocks and a
  directory's data blocks are zeroed on the platter as before, and a plain
  file's data block comes back as a bare number.  ufs_write and ufs_itrunc
  already clear a fresh partial block in memory, keyed by *freshp, and
  write it themselves.
  
  Copying a 93 KB file takes 313 frames, down from 385; a 93 KB cat to a
  file 325, down from 385.  fsck -n is clean after a 90-file directory and
  the copy.

- fcc: a signed % by a power of two is inlined
  K&R 2nd ed A.7.6 (p.166): "it is always true that (a/b)*b + a%b is
  equal to a."  fcc's signed `/' truncates toward zero, inline and in
  _fcc_divs16 alike, so the remainder takes the dividend's sign, which is
  what _fcc_mods16 returns.  fcc inlined `% 2^k' only for an unsigned
  dividend and sent a signed one to _fcc_mods16, a sixteen-step division
  loop.  2.11BSD libc's isleap, `y % 4' on a signed year inside timesub's
  walk over every year since 1970, made that helper 10.9% of `ls -l /bin'.
  
  The sequence takes |a| & (k-1) and negates it back for a negative
  dividend; -32768 negates to itself and masks to 0, its remainder.  It is
  the same size for every k.  A signed `%' by any other constant now takes
  the constant-libcall node, which picks _fcc_mods16 by signedness: two
  instructions fewer than the general path it used before, and the four
  goldens that moved (M19/uchar_compound, M21/modop, M37/namecache,
  M37/rnd) show exactly that.
  
  Fixture M37/mods_pow2 compares `x % 4' and `x % 512' against the helper
  for every x from -1100 to 1100, checks the A.7.6 identity, and pins
  -32768, 32767 and k = 1; on the machine it returns 42, and an emitter
  that skips the negative arm returns 116.  `ls -l /bin' takes 565 frames,
  down from 613.

- fcc runtime: one division core per width, and short paths for small numbers
  The four 16-bit helpers each carried their own sixteen-step restoring
  loop that shifted the dividend, the remainder and the quotient through
  memory.  They now share _fcc_udiv16, which keeps the remainder in A and
  builds the quotient in the shifted dividend's own cell: about half the
  cycles a step.  A dividend under 256 has eight leading zero bits that
  only shift zeros, so XBA moves the low byte up and the loop runs eight
  steps; printf's digit loop and the date arithmetic divide small numbers
  far more often than large ones.
  
  The 32-bit pair shares _fcc_long_udiv the same way.  A divisor that fits
  a word divides in two word passes, the high word and then the low word
  with the first pass's remainder carried in, which is long division by a
  one-digit divisor in base 65536; a zero high word skips the first pass.
  A wider divisor keeps the 32-step loop.
  
  Both cores were checked against a model of the loop on 3.5 million
  operand pairs before assembly.  Fixtures M37/div16_sweep and
  M37/ldiv_sweep check every path against repeated subtraction, K&R 2nd
  ed A.7.6's "(a/b)*b + a%b is equal to a" and known quotients, signed and
  unsigned, at the ends of each range.  The runtime oracle passes 684/684
  of the fixtures it scored.
  
  `od -c /bin/cat' takes 733 frames, down from 901; `ls -l /bin' 529,
  down from 541.  The shared cores are smaller, too: the far kernel bank
  has 183 bytes free, up from 22.

- fcc peephole: the CLC;ADC -> INC fold checks that V is dead too
  INC does not set the overflow flag, so the fold is sound only where no
  BVC or BVS reads the V an ADC #1 or SBC #1 left.  The comment over
  carry_dead_after said fcc never observes V; fcc's signed compares now
  end SEC ; SBC ; BVC, so that stopped being true.  v_dead_after is the
  second gate.  It is block-local because every BVC/BVS fcc emits, 4,238
  in 424 files, takes V from an ADC, SBC or BIT earlier in its own block.
  
  No fixture's output changes; the case it guards has not been emitted
  yet.  test_peephole covers it.

- fcc peephole: a constant operand is used directly, not through _fcc_tmp_b
  fcc puts the second operand of a 16-bit operation in _fcc_tmp_b even
  when it is a literal, so `c == 10' compiled to
      LDA #10 ; STA _fcc_tmp_b ; TXA ; CMP _fcc_tmp_b
  and a negative literal was negated at run time: `c != -1' loaded 1, then
  EOR #$FFFF and INC, behind a PHA/PLA to keep the left operand.
  
  Three rules take that out.  pat_neg_const loads `-k' directly.
  pat_tmpb_const hands the literal to whatever reads it back -- CMP, SBC,
  ADC, AND, ORA, EOR and the loads -- and drops the store; the load goes
  too when A is overwritten unread, and a PHA/PLA pair left with nothing
  between them goes with it.  pat_tmpb_dead_store drops any other store to
  _fcc_tmp_b that nothing reads.  An immediate operand gives the reader
  the same value and the same flags.  No width change, label, branch or
  other store may sit between the store and the reader.
  
  All three rest on _fcc_tmp_b never being live across a basic block.
  That holds over every fcc-compiled file in the tree -- 23,776 reads in
  381 tool and library files and 3,448 in 45 kernel files, each preceded
  by a store in its own block -- and tmpb_block_local checks it again for
  each unit, which gets none of the rules if any read lacks one.
  
  The tree's fcc output falls from 1,227,029 instructions to 1,197,843,
  and _fcc_tmp_b references from 45,574 to 20,571.  The far and tty
  kernel banks gain 1,322 and 1,805 bytes of room.  Measured at 7 MHz:
  cmp 289 -> 265 frames, sed 2,449 -> 2,353, grep 1,801 -> 1,753,
  od 733 -> 709, ls -l 529 -> 517.  462 goldens moved, each only by these
  rewrites; the runtime oracle passes all 692 fixtures it scores, and
  test_peephole covers each rule and its refusals.

- fcc runtime: the division cores' retired cells go, and the libso self-test counts them
  _fcc_div_rem and _fcc_div_quo held the 16-bit loop's remainder and
  quotient; _fcc_udiv16 keeps the remainder in A and builds the quotient
  in _fcc_div_dvd, so nothing references them and check_libc_data refuses
  them.  fgx_libso's self-test pins the runtime's unit count, now 69 with
  _fcc_udiv16 and _fcc_long_udiv, and _fcc_long_mods reaches
  _fcc_long_udiv through _fcc_long_divs.

- fcc: `*(q)->p = c' stores through (q)->p, not into it
  K&R 2nd ed A.7.2: "A parenthesized expression is a primary expression
  whose type and value are identical to those of the unadorned
  expression."  A.7.3 makes `(q)->p' a postfix expression, A.7.4 makes a
  unary expression `unary-operator cast-expression', and A.7.4.3: "The
  unary * operator denotes indirection, and returns the object or function
  to which its operand points."  So `*(q)->p = c' is `*q->p = c'.
  
  fcc parsed the operand of the `*' as the whole assignment `(q)->p = c':
  a computed base's member chain absorbs a following `=' as a store, and
  nothing told it that it was inside a unary operand.  The `*' then read
  the result and dropped it, and c went into the POINTER.  2.11BSD putc's
  line-buffered arm is `(*(p)->_ptr = (x)) != '\n'', so a terminal's
  stdout overwrote its own buffer pointer with each character.
  
  g_unop_operand is set while a `*''s operand is parsed and turns the
  chain's store absorption off; build_assign clears it for every full
  expression nested inside the operand, so `*(q->p = b) = c' still
  assigns inside its parentheses.  No other fixture's output changes.
  Fixture M37/derefparen covers the statement form, putc's value form, an
  assignment in the operand's parentheses and `*(q)->p++ = c'; the
  previous compiler stores 'x' into q->p.

- libc: stdio is 2.11BSD's -- struct _iobuf, _iob, and getc/putc as macros
  FGX's stdio was its own: an opaque FILE that was a slot in a four-byte
  table, and getc and putc as chains of four or five calls through slot,
  buffer-index and pointer lookups.  The 2026-10-23 profile put that chain
  at 56% of grep, 70% of wc and 76% of tr.
  
  <stdio.h> is now 2.11BSD's (5.3, 3/15/86): struct _iobuf with its
  count, pointer, base and size, the _iob table, and getc, putc, getchar,
  putchar, feof, ferror, fileno and clearerr as macros, so a buffered
  character is a decrement and a load in the caller.  Each stdio routine is
  the upstream file it names in vendor/2.11BSD/usr/lib/libc/stdio/ --
  findiop, filbuf, flsbuf, fopen, fdopen, freopen, fread, fwrite, fgets,
  fputs, gets, puts, getw, putw, ungetc, fseek, ftell, rewind, clearerr,
  setvbuf, setbuf, setbuffer, the printf family -- most of them verbatim in
  the body, and perror is gen/perror.c.  stdout is line-buffered on a
  terminal and fully buffered otherwise, stderr is unbuffered, and a read
  stream is buffered whatever it reads, as upstream's are; getpass
  unbuffers its own stream.  sscanf builds upstream's _IOSTRG FILE, so
  doscan.c reads through getc and ungetc again.
  
  FGX deltas, each forced:
  - _doprnt is the existing formatter, a transcription of 2.11BSD's
    pdp/stdio/doprnt.s; it stages 64 bytes and hands them to the FILE with
    fwrite.  printf returns the count, as 2.11BSD's vfprintf does.
  - An unbuffered stream borrows a 128-byte local buffer in fprintf,
    vfprintf and fputs, not BUFSIZ: the bank-0 stack every process shares.
  - exit still flushes through _lc_flush_hook, which _flsbuf names
    _cleanup, so a program that only calls exit links no stdio.
  - _iob is a C global in libc's per-process core and is libc.so's data
    export in place of stdin, stdout and stderr; findiop's sbuf is pinned
    in the core because _smallbuf's initialiser takes its address.
  - NULL stays ((char *)0) and the functions keep their prototypes.
  - popen is still a stub.
  
  Measured at 7 MHz on a 93 KB file: tr 3,229 -> 925 frames, wc 1,849
  -> 601, grep 1,753 -> 817, sed 2,353 -> 1,453, compress 4,465 -> 3,253.
  od (709 -> 769) and ls -l (517 -> 529) are slightly slower: they print
  through fputs and fputc, which are putc per character on a far FILE
  pointer that fcc rebuilds for every field.  The runtime oracle passes all
  693 fixtures it scores and the MAME suite passes.

- libc: exit, sprintf, vsprintf and popen are 2.11BSD's; stdio borrows BUFSIZ
  exit is vendor/2.11BSD/usr/lib/libc/stdio/exit.c, `_cleanup(); _exit(code);`,
  and crt0 calls exit with main's value, as 2.11BSD's crt0 does.  The flush hook
  that _flsbuf armed and crt0 called is gone, and _exit has its own member, the
  counterpart of pdp/sys/_exit.s.  With per-function linking, a static binary
  that prints shrinks 70 to 154 bytes, one that never prints grows 145, and sh
  grows 1,929.
  
  sprintf and vsprintf are stdio/sprintf.c and vsprintf.c: an _IOSTRG FILE with
  a count of 32767.  sprintf takes its arguments through <stdarg.h>, as printf.c
  does, because <stdio.h> declares it variadic.  snprintf and vsnprintf keep the
  engine's buffer mode.
  
  popen and pclose are vendor/2.11BSD/usr/lib/libc/gen/popen.c, verbatim in the
  body: a pipe, vfork, and /bin/sh -c, with pclose returning the wait status.
  M22/popen reads from a command, writes to one, and checks an exit status.
  
  fprintf, vfprintf and fputs borrow upstream's BUFSIZ buffer for an unbuffered
  stream, where they borrowed 128 bytes.

- fcc: a member of a global at a constant offset is read and written in place
  K&R A.7.3.3: "Thus the expression E1->MOS is the same as (*E1).MOS."
  K&R A.7.3.1: "The expression E1[E2] is identical (by definition) to
  *((E1)+(E2))."  So (&_iob[1])->_cnt is the object at _iob+16, an address
  the assembler knows.  It was built at run time instead: the data bank
  through PHB, the offset through LDA #_iob and an index shifted four times,
  then a copy into _fcc_ptr for each member touched.  <stdio.h>'s getc and
  putc are exactly this shape, on stdin and stdout.
  
  The address of a global now goes into an FPR symbolically, as the global
  and an offset.  A constant index or member offset moves the offset; a
  member load, store or ++/-- through it is LDA/STA _iob+16.  Every other
  use of the register builds it first, keeping A, and a label or branch
  builds it keeping the flags as well, so each path into a join agrees on
  what the register holds.  The ternary builds each arm's register before
  it drops it, since the join reads what the arm left there.  Naming a
  register still symbolic is a compile-time error.
  
  getchar() falls from about 70 instructions to 15 on its fast path; putchar
  from 380 lines of assembly to 172.  Measured in MAME on a 93 KB file:
  tr 925 -> 637 frames, grep 817 -> 697, od 781 -> 697, sed 1453 -> 1333,
  compress 3253 -> 3073.
  
  A dynamically bound program's data sites may now name a member of an
  imported table (_iob+16); ld_bind and fgx_bind move the word a site
  carries by the table's displacement, so test_dyn checks the sites lie
  inside _iob rather than at its first byte.  M37/symfold covers the
  folded forms, a branch inside the index, and a pointer compared as
  unsigned long after one side was passed as a constant address.

- fcc: a big frame's parameters are copied near S; ++/-- through a pointer stays in its register
  A parameter sits above the whole frame, at 6 + FRAMESIZE + its offset from
  S, so one BUFSIZ buffer (fputs, fprintf, vfprintf, and many tools) put every
  parameter beyond n,S's 8-bit reach, on the _fcc_fp path: six instructions an
  access.  K&R A.10.1: "the parameters are understood to be declared just
  after the beginning of the compound statement constituting the function's
  body", and "the arguments are converted as necessary and assigned to the
  parameters".  In such a function each int, char, long or pointer parameter
  gets a frame slot among the scalars, assigned once at entry from where the
  caller pushed it, and is read and written there.
  
  A function whose body takes the address of any parameter keeps them all in
  place, since `&last' is how stdarg and varargs reach the arguments after it;
  the walker dies on a homed parameter's address, so a form the scan misses is
  a compile error.  main keeps its parameters: argc and argv are bound into
  their pushed slots before the entry point.  fputs compiles to 423 lines,
  from about 800.
  
  `p->f++' and `--p->f' read and write the member through the register
  holding p (`LDA [_fcc_fprK]'), instead of first copying it into _fcc_ptr
  through an 8-bit width switch.
  
  The peephole turns a signed comparison with a literal 0 into `CMP #0': the
  subtraction cannot overflow, so `SEC; SBC #0; BVC; EOR #$8000' gave the
  same N and Z.  getc's `--cnt >= 0' is that shape.
  
  New fixture M37/parmhome: each parameter kind read and written across calls
  in a 300-byte frame, a struct-pointer getc loop, and a variadic function
  whose va_start still reaches the argument after its parameter.
  
  Measured in MAME, frames over a 93 KB input: od -c 697 -> 649, wc 601 -> 565,
  grep 697 -> 685, tr 637 -> 625, ls -l 553 -> 541, compress 3,073 -> 3,061.

- fcc: a pointer already in its register is not loaded again; a comparison with 0 is CMP #0
  A walker loads a pointer local into an fpr for each member it reaches, so
  2.11BSD's putc, `--(p)->_cnt >= 0 ? (*(p)->_ptr++ = (x))', loaded p from
  the frame twice, four instructions each time.  While lowering, fcc now
  records which local each fpr was loaded from or stored to, and a second load
  of the same local into the same register is `LDA _fcc_fprK', which leaves A
  holding the offset word as the full load does.  The record is cleared by
  what the lowered text does: a label, call, jump or unknown instruction
  clears it all; a store to _fcc_fprK clears K; a store to a frame slot clears
  that local, or all when no local is named; a `*+N' branch clears it after
  the next op too.  A local whose address is taken or that raw code touches
  is never recorded.  K&R A.7.3.3: "E1->MOS is the same as (*E1).MOS"; the
  member's value is still read through the register every time.
  
  A signed `<' or `>=', or any `==' or `!=', against a literal 0 is now
  `CMP #0' and the branch, without pushing the left side and subtracting:
  A - 0 cannot overflow, so N is the sign.  This replaces the peephole that
  rewrote the subtraction afterwards, whose label stood between the two loads
  above.
  
  The peephole's _fcc_tmp_b rules ran on no unit containing an __asm block,
  libc among them.  An __asm line carries a sentinel label, so a read of
  _fcc_tmp_b inside one already fails the unit's check; the extra refusal
  is gone.
  
  New fixture M37/fprhold: the pointer changed between two member reads by
  assignment, ++, a store through a pointer to it, a call, a joining branch,
  and another pointer loaded into the same register.
  
  Measured in MAME, frames over a 93 KB input: od -c 649 -> 625, wc 565 ->
  541, tr 625 -> 613, ls -l 541 -> 529, sed 1,333 -> 1,321, compress 3,061 ->
  3,049, cmp 277 -> 265.

- fcc: type specifiers in any order; an index that calls keeps its base's bank
  K&R A.8.2: "At most one of the words long or short may be specified
  together with int; the meaning is the same if int is not mentioned ... At
  most one of signed or unsigned may be specified together with int or any of
  its short or long varieties, or with char", and A.8's declaration
  specifiers are a sequence in no order.  `int long v' was refused,
  `(long unsigned *)p' did not parse, and `(long unsigned)x' compiled as a
  SIGNED long: the cast's abstract declarator took `unsigned' as its name.
  4.3BSD-Reno's doprnt.c casts through both.  The specifiers after an int,
  char or long base are now one routine, consume_trailing_specifiers, for a
  declaration and a cast alike.
  
  K&R A.7.3.1: "E1[E2] is identical (by definition) to *((E1)+(E2))".  A
  pointer base's bank waited in _fcc_ptr+2 while the index was evaluated,
  and a function called in the index that reached memory through _fcc_ptr
  left its own bank there: Reno's `digs[__lc_pf_qdiv(_quad, base)]' read
  its digit from bank 0 and %lld printed a NUL.  A read through a local
  pointer and a store through a local or global one now stage the bank
  again from the pointer when the index made a call other than a runtime
  helper (ir_call_since).  A global pointer's read already loads its base
  after the index.
  
  New fixtures: M40/specorder; M37/idxcall, whose callee clobbers _fcc_ptr+2
  through `*q++' and which fails without the fix, read and store alike.

- libc: _doprnt is 4.3BSD-Reno's doprnt.c; snprintf writes through an _IOSTRG FILE
  vendor/4.3BSD-Reno/lib/libc/stdio/doprnt.c (5.39, 6/28/90) replaces the
  transcription of 2.11BSD's doprnt.s.  It writes literal text straight into
  the FILE's buffer and a converted field with one bcopy, where the old
  engine staged its output and handed it over 64 bytes at a time with
  fwrite.  It adds what the transcription lacked: precision on integers,
  the `#', ` ' and `+' flags, `h', `%i', `%n', `%p', width on `%c' and
  "(null)" for a null `%s'.
  
  FGX deltas, each in the file's header:
  - ARG casts a plain int to its basetype.  Upstream's int is 32 bits; here
    `va_arg(argp, int)' into a u_long sign-extended %x of 0xffff to ffffffff.
  - %qd and %lld stay 64-bit (QUADINT, after netbsd-0-9's vfprintf.c),
    divided as four words in place because the pile cannot reach the long
    long runtime.
  - %e, %f and %g call __lc_pf_float with cvt's interface: fltpr.c's ecvt
    and fcvt layout, or ffltpr's `?' in a static program that prints no
    float, as 2.11BSD splits pdp/stdio/fltpr.s from doprnt.s.  cvt is double
    arithmetic, which every printf user would otherwise load.
  - %s uses <string.h>'s memchr: upstream's block-scope `char *memchr()'
    hid the prototype.  memchr is 4.3BSD-Reno's string/memchr.c, its own
    member, with an int count as <string.h>'s other mem functions take.
  
  snprintf and vsnprintf build an _IOSTRG FILE over the caller's buffer as
  2.11BSD's sprintf.c does, its count the room; _flsbuf drops the character
  of a string that has run out (flsbuf.c's one delta), and _doprnt counts
  it, so the answer is the length the whole output would have had.
  
  The engine's statics leave libc's per-process core (200 bytes).  libc.so
  grows 4,940 bytes, to 223,922, most of it fourteen expansions of the
  putc macro; the libcso probe's bank cap rises from 8 KB to 12 KB because
  _doprnt is 10,974 bytes and the cap exists only to spread libc over
  banks.
  
  Measured in MAME: ls -l /bin 529 -> 505 frames.

- fcc: a far branch whose target is in reach is a short one
  fcc emits every conditional jump as `B!cc *+5 ; BRL L' and every
  unconditional one as `BRL L', five and three bytes, and Merlin32 does not
  relax them.  A peephole pass now rewrites the pair as `Bcc L' and the lone
  BRL as `BRA L' when L lies within -128..+127.
  
  The distance is summed from an upper bound on each line's size: a
  DO/ELSE/FIN block counts as its larger arm, a direct-page operand is two
  bytes only for the runtime's own cells, any other symbol is the long form.
  A line the pass cannot size refuses every branch across it, and a branch
  inside the reach of a `*+N' skip keeps its bytes.  Shortening one branch
  only shrinks the distances the others measured, so each pass is sound and
  a second finds what the first enabled.
  
  stack_check.py carried a depth to a label only from a conditional branch.
  After `BRA L' its walk went dead, L restarted at depth 0, and the next PLA
  read as a pull below the frame (ntpd's ntp_proto.c).  An unconditional
  branch now carries its depth too.
  
  36,000 far pairs in the built system: the staged files shrink by 144 KB,
  libc.so by 8,755 bytes, tcsh by 19.7 KB.  One putc expansion is 15 bytes
  smaller.  M37/putcsize is that expansion on both of its store paths.

- fcc: TAX;TXA keeps the TAX; CMP #0 after an op that set N and Z from A goes
  The register allocator homes a push in X, and a push popped at once
  becomes `TAX ; TXA' (13,000 sites).  TXA puts back what A holds and sets N
  and Z as TAX did; fcc never narrows X outside __asm text, so it goes.
  
  A truth test is `CMP #0'.  After an instruction that set N and Z from the
  value it left in A -- a load, a pull, a transfer, logic or arithmetic, with
  only stores and pushes between -- the compare sets the same N and Z, and
  is needed only for the carry.  It goes when the carry is dead on every
  path: written or returned past before anything reads it, following a
  branch that does not read the carry to its label as well as through, BRA
  and BRL to theirs, and both arms of a DO block.  A call, a jump, __asm
  text or a line the walk does not know counts as a read.
  
  Branch relaxation runs before and after, so the walk follows `Bcc L' rather
  than stopping at `*+5'.  The staged files shrink by a further 44.6 KB,
  libc.so by 2,727 bytes; one putc expansion by 8 more.

- fcc: the value of an assignment to a char is the byte stored
  K&R A.7.17: "The type of an assignment expression is that of its left
  operand, and the value is the value stored in the left operand after the
  assignment has taken place."  A char store writes A's low byte and left
  the whole word in A, so `(c = 0x1C1) == 0xC1' was false, and stdio's putc
  -- `(int)(*(unsigned char *)(p)->_ptr++ = (x))' -- returned x rather than
  the byte it wrote.  Every kind of store did it.
  
  walk_expr now masks A after a char store whose value is used.  A
  statement's root and the left operand of a comma (A.7.18: "the value of
  the left expression is discarded") are not, so they cost nothing; an
  expression statement walks through walk_expr_stmt, which also drops a
  pointer result instead of loading its offset.  N_STORE_VAR carries its
  right operand's descriptor, which chained pointer stores read, so the
  type stored comes from its symbol.  fcc's char is unsigned, so the mask
  is the conversion.
  
  M37/charasgval stores 0x1C1 through each kind of store and reads 0xC1.

- fcc: && and || in a condition are branches
  K&R A.7.14: "the first operand is evaluated, including all side effects;
  if it is equal to 0, the value of the expression is 0.  Otherwise, the
  right operand is evaluated" -- and A.7.15 the same for || with "unequal".
  walk_cond_branch fused only comparisons, so `if (a && b)', a loop's
  `a && b' and a ternary's condition built the 0/1 the operator returns as a
  value and then tested it: LDA #1 / BRA / LDA #0 / CMP #0 / B!cc *+5 / BRL.
  Now each operand branches: when either operand decides alone (&& for
  false, || for true) both branch to the target; otherwise the first
  branches past the second.  `!' inverts the sense of its operand's branch.
  
  The staged files shrink by 110.6 KB, libc.so by 6,512 bytes.

- fcc: a pointer register keeps its pointer across a label every path agrees on
  The hold record -- which local pointer each fpr holds while lowering --
  was cleared at every label, so a pointer used on both arms of a ternary or
  an if was loaded from the frame again on each.  A label reached only by
  forward branches that have all been lowered now holds what every one of
  them and the code falling into it agree on.  A label a later branch
  reaches, or that text names (a jump table, a hand-built branch), holds
  nothing, and neither does one an earlier `*+N' skip may land on past its
  fall-through.
  
  The signed compare's overflow fix-up, `BVC L / EOR #$8000 / L', is now a
  branch and a label op instead of text, so the record crosses it too; the
  branch skips only the EOR and is near.

- fcc: ++/-- of a pointer through an fpr yields into that fpr
  `p->q++' read the old pointer's offset into _fcc_tmp_b and its bank into
  _fcc_ptr+2, then bridged both into a fresh fpr with a width change -- the
  same register the address had been in, since the address dies when the
  word is written back.  The result's offset and bank now go straight into
  that register: the bank word is one 16-bit store, the pad byte being
  don't-care.  Ten bytes and a SEP/REP pair less at each, and putc's
  `*(p)->_ptr++' is one.  The staged files shrink by 4.4 KB, libc.so by
  359 bytes.

- fcc: the carry walk follows a far branch pair
  A `B!cc *+5 ; BRL L' pair that relaxation cannot shorten is a branch to L
  and a fall-through past the BRL; the walk that proves a `CMP #0' carry
  dead stopped at the `*+5'.  It now follows both.
  
  The staged files shrink by 6.0 KB, libc.so by 270 bytes.

- fcc: a TAX whose X no path reads goes
  The register allocator homes a pushed value in X with TAX and pops it
  with TXA.  When the pop folds away -- pat_tmpb_const turns
  `TAX; LDA #k; STA _fcc_tmp_b; TXA; AND _fcc_tmp_b` into
  `TAX; AND #k` -- the TAX is left holding a copy nothing reads.  putc's
  `(p)->_flag & _IOLBF` and its `!= '\n'` test each kept one.
  
  pat_dead_tax drops a TAX when N and Z are dead after it and X is dead
  on every path: written (LDX, TAX, TSX, TYX, PLX) before anything reads
  it.  The path walk is the carry's, now dead_on_paths with the effect
  as a parameter (carry_effect, x_effect): it follows conditional
  branches to their labels as well as through, BRA/BRL to theirs, both
  arms of a DO, four branches deep.  A read is TXA, TXY, TXS, STX, PHX,
  CPX, INX, DEX, MVN, MVP, any `,X' operand, a call -- setjmp and
  longjmp take the jmp_buf in X, and FGX2_FARCALL counts as a call -- or
  a return, since a caller may read X after one.  A jump, `__asm' text
  or a line the walk does not know also counts as a read.
  
  Unit tests dead_tax, tax_read_at_label, tax_before_jsr,
  tax_before_setjmp, tax_at_return, tax_indexed and tax_nz_live.  An fcc
  that let FGX2_FARCALL write X fails p33_setjmp_local, jmpbuf_width,
  sigjmpmask and libso_calls under MAME, and the shell hangs at boot.
  
  985 TAX lines leave the goldens.  The staged system is 8,027 bytes
  smaller, libc.so 415, and no file grew.

- fcc: ++/-- of a pointer member reaches the member through Y
  K&R A.7.3.4: "The value of the expression is the value of the operand.
  After the value is noted, the operand is incremented ++ or decremented
  -- by 1."
  
  `p->_ptr++' -- the heart of getc and putc -- walked the lvalue to its
  address by adding the member offset into p's own register
  (LDA fpr; INC; INC; STA fpr) and then read, wrote and reloaded the
  member at offset 0.  emit_lvalue_addr_off is the lvalue walker with
  the final offset left to the caller; emit_lvalue_addr flushes it as
  before.  N_LV_INCDEC_E on a pointer leaf passes it to
  emit_ptr_incdec_into_fpr, which reads the member with LDY #off, writes
  it back with Y unchanged, and reads the bank at off+2.  A sym register
  or a non-pointer leaf flushes the offset as before.
  
  One putc or getc expansion is 3 bytes and about 9 cycles shorter on
  the path that does not flush.  An fcc that stored the new pointer at
  offset 0 instead of through Y fails putcsize and stdioops under MAME.
  
  The staged system is 684 bytes smaller, libc.so 68, and no file grew.

- fcc: a long operation's constant right operand goes straight to the second operand
  K&R A.6.5: "Otherwise, if one operand is long int and the other is
  unsigned int, the effect depends on whether a long int can represent
  all values of an unsigned int; if so, the unsigned int operand is
  converted to long int ... Otherwise, if one operand is long int, the
  other is converted to long int."
  
  `l & 15', `l >>= 4', `l % 10': the left operand was pushed, the
  constant loaded into A and widened by a call to _fcc_long_from_int,
  stashed in the second-operand cells, and the left operand popped back
  -- 20-odd instructions and a call to place a number the compiler
  already knew.  When the right operand of a long binary operator or of
  a long `op=' is an integer constant (ast_const_int, which also folds
  constant expressions such as `1L << (2-1)'), emit_stage_long_b writes
  it to _fcc_long_b_lo/_hi through X, widened at its own type: an
  unsigned int zero-extends, an int sign-extends, a long is taken whole.
  The left operand stays in A:_fcc_long_hi throughout.
  
  Fixture M37/longconst exercises a zero-extended mask (0xFFFF), a
  sign-extended one (-1), `l + -2', a shift, division and remainder by
  a constant, and the compound `-=', `|=', `<<=' and `^='.  An fcc that
  kept only the low byte of the high word returns 16 instead of 42.
  
  The staged system is 57,236 bytes smaller, libc.so 2,127, and no file
  grew.

- libc: printf's digits are 4.4BSD's, and a decimal that fits a word divides as one
  Reno's _doprnt took every digit with `_ulong % base' and `_ulong /=
  base': two 32-bit runtime divisions per digit, whatever the base and
  whatever the size of the value.  Profiled under MAME, a printf loop
  spent 23% of its time in _fcc_long_udiv and its callers.
  
  The digits are now 4.4BSD's, from netbsd-0-9's
  lib/libc/stdio/vfprintf.c (5.50 12/16/92), vendored from examples/ as
  doprnt's %q already drew on it: "unsigned mod by a constant is easier
  than that by a variable; hence this switch" -- octal by `& 7' and
  `>>= 3', hex by `& 15' and `>>= 4', and decimal by a loop that leaves
  the last digit undivided ("many numbers are 1 digit").  FGX's delta:
  a decimal value divides as a long only while it is wider than 16 bits,
  and the rest of its digits come from u_int division, the machine's
  word.
  
  Fixture M37/pfdigits checks %d, %u, %ld, %lu, %o, %#o, %lo, %x, %X,
  %#lx, widths, precision and %.0d of 0, either side of 65536.  A libc
  whose word path started at 0x1ffff instead of 0xffff returns 30
  instead of 42.

- libc: bcopy moves a word at a time, in the direction an overlap needs
  bcopy was a C byte loop -- about thirty instructions a byte once
  compiled, behind a 32-bit compare of the two pointers -- and stdio
  calls it for every buffered run: _doprnt's digits and strings, fread
  and fwrite.  It was 8% of a printf loop under MAME.
  
  It is now inline asm through [dp],Y, as memcpy beside it is, with the
  shape of 4.3BSD-Reno's lib/libc/string/bcopy.c: going forward, whole
  words and then the trailing byte; going backward, the end byte first
  and then the words; nothing when the length is 0 or the two are the
  same.  Forward is taken when dst is below src or the two are in
  different banks.  Every word is read before the store that could
  overwrite it.  memcpy's own loop runs backward but takes its odd byte
  last, which a copy one byte up would read after overwriting it, so
  bcopy keeps its own.  A negative length copies nothing, as before.
  
  Fixture M37/bcopyovl copies one byte up and one byte down at odd and
  even lengths, apart, in place, a single byte, and lengths 0 and -1,
  each against a byte loop through a temporary.  A bcopy that took the
  odd byte last going backward returns 36 instead of 42.
  
  With the two changes before it (the long constant operand in fcc and
  the digits), a printf loop is 21% faster, 505 to 397 frames.  These
  two libc changes make libc.so 310 bytes larger and the 19 statically
  linked programs about 300 bytes each.

- fcc: a function that calls others keeps its loop-hot locals in a callee-saved direct-page band
  fcc promotes hot locals to direct-page slots, $C0-$DF, where a pointer
  is dereferenced in place (`LDA [_fcc_img3]') instead of being copied
  out of its stack slot on every use.  Any C function may reuse those
  slots, so only a function that calls none could hold a value there:
  the promotion was whole-function and stopped at the first call, and
  every loop with a putc, a strcmp or a callback in it kept its locals on
  the stack.
  
  $78-$97, _fcc_img16.._fcc_img31, is now callee-saved.  A function that
  calls another C function promotes its loop-hot locals there -- pointers
  first, as they gain the most, then longs, then int and char locals
  weighted as two loop accesses -- and keeps the leaf promotion of its
  call-free loops in $C0-$DF.  Its prologue pushes the caller's words
  after _fcc_fb (`PEI _fcc_img16'...), FRAMESIZE counts the pushes so a
  parameter's `n+FRAMESIZE,S' still reaches it, and the SBC and ADC that
  allocate and free the locals leave them out.  The epilogue pulls them
  back once the locals are freed; with more than one return, each frees
  its locals and branches to one shared tail, <fn>_bandx, so the pulls
  are not copied per return.  The prologue, epilogue and FRAMESIZE lines
  are tagged when recorded and rewritten by ir_band_frame once the
  promotion knows how many words it used, so a function that uses none
  emits exactly what it did.
  
  A longjmp skips the epilogues between it and its setjmp.  2.11BSD's
  pdp/gen/setjmp.s restores r2-r4 by rolling those frames back, which
  needs frames that record what they saved; 4.3BSD-Reno's
  i386/gen/setjmp.s saves ebx, esi, edi and ebp in the jmp_buf instead,
  and that is what this does: setjmp copies the band to jmp_buf
  +16..+47 and longjmp copies it back, so jmp_buf is 48 bytes.  K&R B.8:
  "Accessible objects have the values they had at the time longjmp was
  called, except that non-volatile automatic variables in the function
  calling setjmp become undefined if they were changed after the setjmp
  call."
  
  Kernel and module C run on another direct page and do not use the
  band.  Nor does a recursive function -- a soft-frame cycle member or a
  self-recursive one: its saves would repeat at every level, on the
  hardware stack a soft frame exists to spare.  A first cut that let
  them in cut bsh's sourced-script depth from 218 commands to 43.  gen_fcc_dp.py keeps its names in fcc_dp.s for the fpsim module,
  whose softdouble runs on the calling task's page, and leaves them out
  of the context switch's save range.  stack_check.py reads the
  `#<fn>_FRAMESIZE-<n>' teardown and the shared tail, with a self-test
  case.  docs/userland-abi.md records the convention.
  
  Fixture M37/dpband nests band users through calls and recursion and
  reads a function's band locals after a longjmp has skipped a deeper
  function's epilogue.  An fcc that pulled the words back in the wrong
  order fails it under MAME, and so does a libc whose longjmp leaves the
  band alone (30 instead of 42).
  
  MAME frames: grep 649 -> 553, sed 1285 -> 1165, cmp 253 -> 229, ls
  457 -> 445, od 553 -> 541, compress 2797 -> 2749; tr, wc and a printf
  loop unchanged, their hot pointers being struct pointers, which the
  promotion does not take.  The staged system is 10.3 KB smaller and
  libc.so 911 bytes; 85 files grew.

- fcc: a fn-ptr struct field takes any null pointer constant
  A function-pointer field in a struct initializer accepted only a bare 0.
  FGX's NULL, ((char *)0), and (void *)0 stopped the compile with "fn-ptr
  field init: need function name or 0". FreeBSD ee's menu tables fill their
  unused handlers with NULL.
  
  K&R A.6.6: "An integral constant expression with value 0, or such an
  expression cast to type void *, may be converted, by a cast, by
  assignment, or by comparison, to a pointer of any type."
  
  The field now uses the same null test as the neighboring data-pointer
  arm (field_init_is_null), so (void *)0, ((char *)0) and (MARK (*)())0
  all initialize the field to null. ((char *)0) is accepted as the data
  pointer arm already accepts it; strictly it is not a null pointer
  constant, and FGX's NULL has that form so that an argument passed to an
  unprototyped function is a full 4-byte pointer.
  
  M22/fnptr_null covers NULL and (void *)0 beside a named function.

- curses: keypad mode, after NetBSD 1.5
  keypad(win, TRUE) makes wgetch return a KEY_ value for a key whose
  termcap sequence arrives whole: ku kd kl kr kh and k0-k9, which 4.3BSD
  curses already reads into KU..K9 at setterm. The values and the KEY_
  names are NetBSD 1.5's (lib/libcurses/curses.h); keypad() is its
  keypad.c, with 4.3BSD names (the _KEYPAD flag in _flags, KS, _putchar).
  
  wgetch follows NetBSD 1.5's inkey() in getch.c: bytes that begin a
  sequence but stop matching, or do not finish before the inter-key delay,
  come back one at a time, matched again from the start, so a lone ESC is
  ESC. Two departures: the sequences are matched against the table
  directly rather than built into keymaps (at most fifteen, three bytes
  each on the console), and the delay is a 0.2 s select(2) on the
  terminal, 2.11BSD's tty having no termios VMIN/VTIME. wgetch now returns
  an int.
  
  Two System V names ee calls, which 4.3BSD curses lacks:
  - fixterm(): FreeBSD 2.2.8 ncurses defines it as reset_prog_mode().
    4.3BSD curses saves no program mode, so it re-applies the modes _tty
    holds, and the caller sets the rest with raw(), noecho() and nonl().
  - wnoutrefresh(win): NetBSD 1.5 copies the window to a virtual screen
    for a later doupdate(). 4.3BSD curses has no virtual screen, so the
    window is refreshed at once.
  
  The NetBSD 1.5 sources are vendored under vendor/netbsd-1-5.

- ld: a program file too big for a bank is packed function by function
  A program built from one .c whose code exceeds 64 KB could not link:
  fgx_pack places translation units, and a single one larger than a bank
  has nowhere to go. FreeBSD ee is 118 KB of C in one file.
  
  fcc --sections already marks each function as its own unit, and every
  call between functions is an FGX2_FARCALL the linker resolves across
  segments, so a function in another bank is reached the way a function
  in another file is. fgx_pack.split_code writes the file's main section
  for segment 0 and every other section as its own pack unit, each with
  the file's header and an FGX2_RELOC_COUNT of its own rows, which fgx_ld
  checks per file. fgx_dyn takes it as --split; the manifest key "split"
  compiles the entry file with --sections and links with --split.
  fgx_pack's self-test covers the split and each piece's row count.

- ee: the easy editor, from FreeBSD 2.2.8
  ee(1) by Hugh Mahon, FreeBSD 2.2.8 usr.bin/ee: a modeless screen editor
  with its key help on screen and an ESC menu for saving, searching and
  leaving, for someone who does not want vi. It builds from the vendored
  ee.c unchanged, against the 2.11BSD curses with keypad mode, with
  FreeBSD's Makefile defines less HAS_NCURSES and SLCT_HDR and with
  NO_CATGETS, FGX having no message catalogs. Its 118 KB of C links as
  one file split across two code banks.
  
  /bin/ree is a hard link to it, as upstream's Makefile installs it
  (LINKS=${BINDIR}/ee ${BINDIR}/ree), ee.c giving argv[0] "ree" its
  restricted mode. The man page is formatted from ee.1 with mandoc, with
  a BUGS section for what FGX does not have: message catalogs, lp, spell
  and ispell, and keys beyond what termcap lists.
  
  ee.c is distributed under the Artistic license, vendored beside it as
  doc/Artistic.

- fcc: signedness, pointer width and branch fixes from the SOMI port
  Fixes found porting Secret of Monkey Island, mostly unsigned and signed
  char handling against fcc's AND #$00FF zero-extension.
  
  - A pointer's is_unsigned marks its POINTEE, in every way of reading
    through it: p[i], *(p+i), an array's decayed name, a pointer element.
    The index's signedness was used, or none, so an unsigned short read
    through a pointer and widened to long sign-extended $F248 to
    $FFFFF248. K&R A.7.3.1: "The expression E1[E2] is identical (by
    definition) to *((E1)+(E2))." Pointer minus pointer is a signed int.
  - An assignment's value carries its target's signedness. K&R A.7.17:
    "The type of an assignment expression is that of its left operand."
  - A relational comparison of two pointers compares bank:offset as an
    unsigned long. K&R A.7.9: the result "depends on the relative
    locations in the address space of the pointed-to objects"; one object
    may span banks, and the offset words alone put $09:0003 below
    $08:FF00.
  - A pointer converted to long, or passed where a long is read, masks the
    pad byte: a pointer store writes offset and bank only, so the fourth
    byte holds whatever the slot held ($55E1191C for a Memory Manager
    handle at $E1:191C).
  - An int stored into a pointer element writes all four bytes. A word
    store left the bank of a "null" entry as stale memory had it.
  - An unsigned int constant in a constant expression zero-extends. K&R
    A.2.5.1: "An integer constant may be suffixed by the letter u or U, to
    specify that it is unsigned."
  - A typedef takes one pointer derivation per '*' and a long base:
    `typedef void **Handle'. K&R A.8.9: "A typedef declaration attributes
    a type to each name among its declarators in the usual way."
  - --signed-char: a char not declared unsigned holds -128..127, folded by
    (v ^ $80) - $80. K&R A.4.2: "whether the value is signed, is
    implementation-dependent." Off by default.
  - The peephole that deletes a BRL to the next label also deletes a
    far conditional `B?? *+5' skipping it: with the BRL gone, the skip
    landed three bytes past the label, mid-instruction.
  - _fcc_long_from_int sets N from A before its BPL, as callers may load
    X between.

- fcc: the SOMI fixes on the current pointer registers and char stores
  Two places where those fixes meet code they were not written against.
  
  A relational pointer comparison reads each operand's bank word directly,
  and a symbolic register (`&_iob[NSTATIC]', from the stdio port) has no
  bank word until it is built: compiling libc's findiop.c stopped with
  "fcc-fpr: a symbolic register named before it was built". Both operands
  are built first, as the pointer-to-long cast already does.
  
  --signed-char folded a char value only when the expression type was
  char. A store to a plain variable (N_STORE_VAR) carries its right-hand
  side's type, so `(d = 0xFF) == -1' compared 255. The fold now takes a
  store's object type and signedness from store_object_type, as the
  A.7.17 truncation beside it does, and skips a store whose value is
  discarded. K&R A.7.17: "the value is the value stored in the left
  operand after the assignment has taken place."

- fcc: regression fixtures for the SOMI fixes
  One fixture per behavior, each returning 42. Built with the compiler
  before these fixes, seven of the eight fail in MAME and the eighth does
  not compile: asg_unsigned returns 0, bra_next 255, ptee_unsigned 32,
  ptr_elem0 22, ptr_relbank 0, uconst_long 0, and typedef_pp is refused
  ("bad typedef pointer base"). M43 compiles with --signed-char, an option
  the earlier compiler does not have.
  
  bra_next is the shape tcsh's ed.refresh.c already hit: `if (a < b) { }'
  left `BPL *+5' with its BRL deleted, jumping three bytes past the label
  in the shipped tcsh.
  
  The pad-byte masking has no fixture: whether a stale pad reaches a long
  depends on what the pointer register held before, which a fixture
  cannot set.

- fcc: goldens and fn-ptr patch sites for the SOMI fixes
  Fifteen goldens move, each with the change that moves it: the bank
  byte masked to its low half where a pointer becomes a long (longptr,
  longptr_impl, ptrlong_cast, sigsptrlong, stdcells, sysc, wait3ops,
  ptrinit_const, symfold) and relational pointer comparisons made on the
  whole address (ptr_cmp, gptr_heap, tar_ctor, biocache, specops,
  vreclaim). The kernel and module fn-ptr patch-site tables are
  regenerated for the code addresses that moved with them.

- fcc: five statement and initializer forms K&R allows
  return takes the comma level.  A.9.6 gives "return expression(opt);",
  and an expression is A.7.18's "expression , assignment-expression", so
  `return (*s)++, 40;' parses; it stopped at the comma before.
  
  A parenthesized expression statement may end in a void comma operand.
  A.7.18: "The type and value of the result are the type and value of
  the right operand", so `(x), set(42);' is a void expression used as a
  statement, where its value is discarded.  It now goes through the same
  statement builder as an unparenthesized comma statement.
  
  A statement may begin with a constant or a unary operator.  A.9.2:
  "expression-statement: expression(opt);".  A debug macro that expands
  to a constant leaves `0;', which was "expected statement".
  
  A pointer field initializer takes constant subscripts.  A.7.19: "the
  unary & operator may be applied to external or static objects, and to
  external and static arrays subscripted with a constant expression".
  `&g.s[2]' and `&g.c[2].v' in a struct initializer become g+offset; a
  member path alone was accepted before.
  
  A function-pointer member reached by `.' and then `->' is callable.
  A.7.3.2: the postfix expression "must be of type ``pointer to function
  returning T,'' for some type T, and the value of the function call has
  type T."  `pack.who->func(30, 10)' and `(pack.who->func)(1, 1)' carry
  the member's signature through the chain to the call.
  
  Fixtures (M44): return_comma, paren_comma_void, const_stmt,
  sfld_subscript, fnptr_chain_call.  Each is refused by the previous fcc
  and returns 42 in MAME.

- fcc: a diagnostic on a macro-expanded token names the macro's use
  A macro body is tokenized from its #define text on its own, so every
  body token carried a line and column in that text, and an error found
  at one was reported as file.c:1:1, wherever the macro was used.  An
  expansion frame now records the location of the name that invoked it
  and gives it to each token it hands out, as cpp reports expansions.
  The invoking name has already been stamped when it came from an outer
  body, so a nested expansion reports the outermost use.  Argument spans
  keep their tokens' own locations.
  
  K&R Appendix A says nothing about diagnostic locations; this follows
  cpp.  Only token locations change: all 749 fixture goldens are the
  same.
  
  reject/macro_diag_loc pins the location two expansions deep.

- fcc: struct initializers take nested braces at every level
  K&R A.8.7: "If an aggregate contains members of aggregate type, the
  initialization rules apply recursively.  Braces may be elided in the
  initialization as follows: if the initializer for an aggregate's member
  that itself is an aggregate begins with a left brace, then the
  succeeding comma-separated list of initializers initializes the members
  of the subaggregate".  A static struct initializer took braces one
  level deep, around a top-level member, and refused a second '{' inside
  it, so a member that is an array of structs or a rank-2 array could
  only be initialized flat.  An automatic struct refused any aggregate
  member at all.
  
  struct_init_leaves now records, for each leaf, the aggregate it belongs
  to at every brace level: the member, then each struct member, array row
  and array element inside it.  The parser keeps a stack of open groups.
  A '{' opens the aggregate one level inside the innermost open group,
  or deeper when the levels between were elided and the leaf is in the
  middle of them, as `{ 1, 2, 3, { 4, 5 } }' gives c[1] its braces.  A
  short group zero-fills only its own aggregate.  A string literal fills
  the char array whose first element it meets, so each row of a
  char[2][4] takes its own string.
  
  The automatic struct initializer uses the same leaves and rules, and
  stores zero into every leaf its list does not reach.  It used to skip
  the aggregate members when zero-filling, so `struct rec r = { 9 };'
  left r.name and r.t holding whatever was on the stack.  A.8.7: "If
  there are fewer initializers in the list than members of the
  structure, the trailing members are initialized with 0."
  
  All 749 existing goldens are unchanged.  Fixtures (M44): init_nested
  (static: fully braced, elided outer level, short groups, rank-2 rows,
  char rows, an array of structs), init_nested_local (automatic, on a
  dirtied stack), and reject/init_too_many_braces.

- fcc: & of an array member's element, for any element type and rank
  K&R A.7.3.1: "One of the two expressions must have type ``pointer to
  T'', where T is some type, and the other must have integral type; the
  type of the subscript expression is T."  A.7.4.2: "If the type of the
  operand is T, the type of the result is ``pointer to T.''"
  
  The address-of arm for `&s.f[i]' listed the element types it took --
  char, int, long, float and struct -- so an array of pointers or of
  doubles fell past it with the '[' unread: `&c.a[1]' with `char *a[2]'
  was "expected ';'".  It now takes any rank-1 array member.  The `->'
  arm's member-array test had the same list; pointer and double arrays
  reached its generic chain loop instead, and now take the scaled arm
  like the rest.
  
  A rank-2 member takes two subscripts, and neither arm read the second:
  `&c.m[1][2]' and `&p->m[1][2]' stopped at it.  Both now hand the run
  to the uniform lvalue walker, which scales by row and element.
  
  All 751 existing goldens are unchanged.  M44/addr_member_elem stores
  through each address -- pointer, long, double and struct elements, a
  rank-2 element, from a static, a local and a pointer base, and under
  a cast -- and reads the member back, so a wrong stride lands in the
  wrong element.

- fcc: pointers to function pointers
  K&R A.8.6.1: "In a declaration T D where D has the form
  * type-qualifier-list(opt) D1 and the type of the identifier in the
  declaration T D1 is ``type-modifier T,'' the type of the identifier of
  D is ``type-modifier type-qualifier-list pointer to T.''"  Applied
  twice, `int (**pp)()' is a pointer to a pointer to a function
  returning int.  fcc refused it in
  every position: "pointer to array/function ... is not supported here"
  for a variable or member, "expected parameter name" for a parameter,
  and the cast and sizeof type names stopped at the second `*'.
  
  The type is the function pointer's tword under one more pointer group,
  and the symbol carries the call signature the way a function pointer's
  does.  fnptr_based() names the types that carry one -- a function
  pointer under any pointer or array layers -- and the nodes that load,
  dereference, subscript, offset or cast such a value hand it on, so
  `(*pp)(x)', `pp[i](x)', `(**pp)(x)', `(*(pp + 1))(x)', `(*o.vec)(x)'
  and `p->vec[i](x)' all reach the call arm with it.
  
  - Variables and members: parse_declarator takes `(**name)(params)',
    named or abstract, so a global or local also takes an ordinary
    pointer initializer (`= &t[1]', `= t').
  - Parameters: parse_fn_ptr_declarator reports the extra `*'s to the
    K&R and prototype parameter paths.  An array of function pointers as
    a parameter is now that type too -- A.8.6.3: "The types of
    parameters that are arrays or functions are altered to pointers" --
    where it used to be refused.
  - Typedefs: `typedef int (**PP)();' carries its signature to every
    use, as a function-pointer typedef does.
  - Casts: `(int (**)())x' is an ordinary pointer cast.  A function-
    pointer cast `(int (*)())x' now interns its own parameter list
    instead of skipping it and keeping the operand's signature, so a
    call through the cast of a non-function pointer has one (A.7.5: a
    cast "causes conversion of the value of the expression to the named
    type").
  - sizeof takes an abstract declarator group, `sizeof(int (*)())' and
    `sizeof(int (**)())'; it took neither.
  
  All 752 existing goldens are unchanged.  M44/fnptr_ptr calls through
  every spelling above -- local, global (initialized too), member by `.'
  and `->', K&R, prototype and array parameters, typedef, cast, pointer
  arithmetic, a store through the pointer, sizeof -- and checks each
  result.

- fcc: pointers held in direct page, read in place
  A pointer parameter or local used several times is now kept in an img
  pair whatever it points to, and the far-pointer register a load copies
  it into is read from the pair directly.  The copy was eight bytes per
  use -- `LDA n,S / STA fpr+2 / LDA n,S / STA fpr' -- and joe 2.8 had
  7,803 of them, mostly struct pointer parameters reached with `p->'.
  
  Promotion (ir.c).  ir_promote_ptrs took only pointers to int, char
  and void, and a parameter only when a loop used it.  A pointer to
  anything else now qualifies when every access to it is a whole-value
  move (ir_ptr_value_only) and no IR text addresses its stack slot --
  ir_text_touches_slot reads the `; fccstk b=' annotations, so a raw
  access raw_accessed does not flag still disqualifies it.  Such a
  pointer is promoted for size: a parameter with three loads, a local
  with two, which is what an 8-byte entry seed and a band pair's save
  and restore cost.
  
  The read in place (peephole.c, pat_img_fpr_alias).  After the copy
  `LDA img{s+1} / STA fpr{k}+2 / LDA img{s} / STA fpr{k}', readers of
  fpr{k} up to its next write read `[_fcc_img{s}]' instead, and the copy
  goes but for the `LDA img{s}' that leaves the offset in A.  It stops
  at a write to the pair, and keeps the copy unless the register is
  dead on every path from where it stopped.  A C call clobbers the far-
  pointer registers without reading them; an _fcc_ runtime helper
  touches only $E8 and up; a return reads _fcc_fpr0, the pointer return
  register.
  
  The lvalue walker (parse_stmt.c).  `(p)[i] = v', `(p)->m' and `(*p)'
  took p's address and read the pointer back through it, which marked p
  address-taken.  K&R A.7.3.1: "The expression E1[E2] is identical (by
  definition) to *((E1)+(E2))", and A.7.3.3: "the expression E1->MOS is
  the same as (*E1).MOS" -- the step's object is at the pointer's value,
  so the walker loads that.  joe's vs.h writes every store as
  `(v)[p]=(el)'.
  
  reads_loc (peephole.c) did not know that `[_fcc_img{n}]' reads the
  bank byte in _fcc_img{n+1}: the cells are named, not `_fcc_img{n}+2'.
  pat_dead_store dropped a pointer's bank store when the pointer was
  assigned twice in straight-line code.  It applied to the int, char
  and void pointers promoted before this too.

- fgx_dyn: a refused over-cap link no longer blocks the rerun
  A link that packs more segments than fgx_ld accepts writes seg9 and
  up before fgx_ld refuses it.  The next run's clear_outputs then found
  files outside fgx_dyn's output pattern, which allowed seg0..seg8 only,
  and stopped with "holds seg9 ... which fgx_libso does not write"
  instead of reporting the real refusal again.  The pattern takes any
  segment number; the self-test checks seg9 and seg10_rt.

- fcc: a pointer read from memory takes its bank as a word
  emit_fpr_deref_field read a stored pointer's bank byte in 8-bit mode:
  
      LDA [r] / PHA / SEP #$20 / LDY #2 / LDA [r],Y / STA r+2 / REP #$20
      / PLA / STA r
  
  The byte above the bank is the pointer's pad, and the PAD DISCIPLINE
  already rules it don't-care: whole-register moves copy bank and pad as
  a word, and every consumer -- the null test, ==, the relational
  compare, the cast to long -- masks it with AND #$00FF.  So the bank is
  read as a word with the pad, without the mode switch:
  
      LDA [r] / PHA / LDY #2 / LDA [r],Y / STA r+2 / PLA / STA r
  
  (`INY / INY' after the offset when the member is not at 0.)  Both
  halves are read before the register is written, and A is the offset
  at the end as before.  The same holds for a member of an object at a
  fixed address.  The PB fallback for a pointer without a stored bank
  went with it: every pointer type stores its bank.

- fcc: a call's arguments come off the stack with PLY
  After a call whose arguments were not all words, fcc dropped them with
  stack-pointer arithmetic, keeping the return value in Y around it:
  
      TAY / TSC / CLC / ADC #n / TCS / TYA          (8 bytes; 6 discarded)
  
  and an all-word call with `TAY / PLA x n / TYA'.  Y is dead at every
  call site -- expression evaluation uses A, and the callee did not keep
  Y -- so the words can be pulled into Y directly, leaving A alone:
  
      PLY x n/2                                      (n/2 bytes)
  
  emit_drop_arg_bytes does that for up to four words and keeps the
  arithmetic beyond, where it is the shorter and quicker of the two.
  Every call path goes through it; emit_drop_args is gone.  A PLY sets
  the flags from Y, not A, so the peephole keeps a following `CMP #0'
  that it would have folded after TYA.

- kernel: getfsstat(2) reads its buffer size, not the buffer's address
  _Sys_GetfsStat pushed bufsize, then parked the buffer offset on the
  stack while it built the far pointer, then pushed the pointer.  The
  parked word sat between sbp and bufsize -- where vfs_getfsstat reads
  its second argument -- so bufsize arrived as the buffer's address,
  maxcount came out as that over sizeof (struct statfs), and every mount
  was copied whatever room the caller gave.  2.11BSD ufs_syscalls2.c:98
  (getfsstat) bounds the copy by the caller's size:
  
      maxcount = uap->bufsize / sizeof (struct statfs);
  
  and vfs_getfsstat does the same; the glue fed it the wrong word.
  
  df(1) passes a malloc'd buffer sized for every mount, so it never
  noticed.  A 128-byte stack buffer took the second entry over its own
  frame: M37/miscops crashed the machine, which the fixture oracle
  reported as a chunk that never finished.
  
  The offset now waits in X (bufsize has already been pushed from it),
  and the cleanup drops the six argument bytes.
  
  M45/getfsstat_room gives getfsstat room for one entry and checks the
  bytes after it untouched.

- vendor: novi from davepl/pdpsrc
  Dave Plummer's novi(1), bsd/novi at commit 381ac12 of
  https://github.com/davepl/pdpsrc -- the sources, Makefile, README,
  deploy script and the two test programs; the prebuilt test binary is
  left out.  Unmodified.  The repository carries no LICENSE file; its
  author has stated the terms as BSD-2-Clause.

- novi(1): Dave Plummer's disk-backed editor, under BSD-2-Clause
  novi is a nano-like full-screen editor written for split-I/D 2.11BSD on
  the PDP-11.  The document never sits in memory: two scratch files form
  a gap at the cursor, so editing costs bounded memory whatever the file
  size, which suits a task whose data lives in one 64 KB bank.  It was
  ported in August and held out of the tree because its upstream states
  no license; asked, its author answered "you can assume NOVI is under
  the 2_BSD license".  The sources carry BSD-2-Clause with his copyright
  beside FGX's, and docs/PROVENANCE.md, LICENSE and vendor/README.md
  record it.
  
  Two of the port's deltas were ProDOS-era and their reason is gone, so
  novi follows upstream (vendor/pdpsrc/bsd/novi) again:
  
  - The scratch files and the cut file are unlinked as soon as mkstemp
    returns them, upstream's scratch() and make_cutfile().  The port kept
    the names and unlinked at close because ProDOS freed an unlinked
    file's blocks at once; UFS -- and FGX's ProDOS driver -- now keep an
    open file's blocks until its last close.  A hard kill no longer
    leaves files in /tmp.
  - buf_save stats the original and fchmods the temporary before the
    rename, as upstream does.  The port dropped both because ProDOS had
    no permission bits; without them a save turned a 755 file into 0600.
  
  The deltas that remain are for speed and for the console: no ftruncate
  per keystroke, the bulk read the redraw uses, the screen shadow, and
  the sgtty branch taking __FGX__.  terminal.h, which carries the shadow's
  two declarations, gains the header and PROVENANCE row it lacked.
  
  The man page's caveats describe today's system: ^C reaches novi as the
  position report (the console honors RAW mode now), and a save is
  atomic except on a ProDOS volume, whose rename removes the target
  first (pd_rename).

- kernel: per-process CPU time and the load average
  2.11BSD's hardclock charges each tick to the running process
  (sys/kern_clock.c:78-90): `u.u_ru.ru_utime++' in user mode,
  `u.u_ru.ru_stime++' in system mode, nothing when there is no process.
  The heartbeat now does the same into two TCB fields, TCB_Utime and
  TCB_Stime, which take the place of the unused TCB_WakeTime and
  TCB_LastRun.  They live in the TCB rather than the u-area because the
  heartbeat reaches the task table in the kernel bank and cannot follow
  the u-area's far pointer; it finds the running task by _kCurPid.
  Task_Alloc clears both for a new process, as fork clears u_ru.
  
  procs(2) records grow from 42 to 54 bytes: the effective uid (U_Uid,
  2.11BSD's p_uid), the priority, and the user and system ticks.
  struct procinfo in <fgx.h> follows.
  
  The load average is 2.11BSD's (sys/vm_sched.c): every fifth lbolt,
  vmmeter's `time.tv_sec % 5 == 0', _Vm_Loadav counts the runnable tasks
  and applies loadav():
  
      avg[i] = (cexp[i] * (avg[i]-(n<<8)) + (((long)n)<<16)) >> 8;
  
  with cexp 0353, 0373, 0376.  Multiplied out the numerator is
  cexp*avg + 256*n*(256-cexp), whose second term is a multiple of 256, so
  the routine computes ((cexp*avg) >> 8) + (256-cexp)*n, one 8x16
  multiply.  Upstream also counts an uninterruptible sleep; FGX records no
  such flag, so a task blocked in the disk path is not counted.
  
  vm.loadavg (VM_LOADAVG) now answers with struct loadavg, as
  kern_sysctl.c's vm_sysctl builds it from avenrun with fscale 256;
  <sys/resource.h> gains the structure, from 2.11BSD's h/resource.h.

- fcc: a prototype parameter declared as an array of any type
  K&R A.10.1: "If a parameter is declared to have type `array of type,'
  the declaration is adjusted to read `pointer to type'".  The named
  `T name[]...' shape in a prototype was taken by the multi-dimensional
  array path, which knows int and char and refused every other base with
  "multi-dim param base must be int or char"; 2.11BSD getloadavg(3)
  declares `double loadavg[]'.  A single dimension of any other base now
  falls through to the scalar path, whose decay arm already adjusts it to
  a pointer.  A multi-dimensional array of another base is still refused.
  
  Fixture M45/param_array: long and struct array parameters indexed and
  written through as pointers.

- libc: getloadavg(3)
  2.11BSD vendor/2.11BSD/usr/lib/libc/gen/getloadavg.c (8.1.1, 1/15/95),
  vendored with this, verbatim in the body: the vm.loadavg sysctl's
  averages divided by its fscale.  Its own member, being double
  arithmetic only its callers should link.  <stdlib.h> declares it, as
  2.11BSD's does; the cat page is 2.11BSD's.

- libtermlib: tgetstr copies the capability into the caller's area
  2.11BSD termcap.c: "the strings are placed in area, which is a ref
  parameter which is updated" -- tdecode() copies the decoded string to
  *area, NUL-terminates it and advances *area past it.  FGX's tgetstr
  returned a pointer into its built-in vt100 table and left *area alone,
  so a caller that keeps only its area found nothing there: top(1) sizes
  and copies out the bytes tgetstr used and stopped with "not enough data
  space for terminal capabilities".  The string is now copied as upstream
  copies it.  Every caller in the tree passes an area of 20 to 2048 bytes
  against capabilities of a few bytes each.

- cp(1): 2.11BSD's, verbatim
  vendor/2.11BSD/usr/bin/cp.c (4.13, 10/11/85) in place of a reduced
  port.  The old one created every target with mode 0, so a copied
  program was not executable, and had no -i, -r or -p; its header gave
  the reasons as no opendir, fchmod or utimes in libc, all of which libc
  now has.  Upstream creates the target with the source's mode and
  fchmods one that exists.

- yes(1): 2.11BSD's, verbatim
  vendor/2.11BSD/usr/ucb/yes.c (5.1, 5/31/85).  The port printed five
  lines and stopped, its header saying SIGPIPE delivery in a pipeline was
  unspecified.  It is delivered: `yes | head -2' prints two lines and yes
  ends on SIGPIPE.  The shell then reports 141, as 2.11BSD's sh does --
  await() keeps the first nonzero status it reaps (service.c:287).

- w(1): the load averages in the heading
  The heading carries upstream's load-average clause again
  (vendor/2.11BSD/usr/ucb/w.c:168), from getloadavg(3) now that the
  kernel keeps the averages; uptime(1), the same program, prints it too.
  JCPU and PCPU stay out: upstream's JCPU adds each process's u_cru, the
  CPU time of finished children, which the kernel does not keep.  The man
  page's description and BUGS follow.

- top(1): Dave Plummer's process monitor for 2.11BSD
  From davepl/pdpsrc bsd/top at commit f489ca9, vendored unmodified at
  vendor/pdpsrc/bsd/top with the bsd/pdp11_unistd.h it includes.  Its
  author states his pdpsrc code is BSD-2-Clause; LICENSE, vendor/README
  and docs/PROVENANCE.md say so.
  
  screen.c, screen.h and format.h are verbatim.  top.c keeps upstream's
  display, sorting, keys and timing and changes where the numbers come
  from.  Upstream reads the proc table, cp_time and every u-area through
  nlist(3), /dev/kmem, /dev/mem and /dev/swap, which FGX does not have
  (apple/fgx#538).  Here:
  - the process table is procs(2), each record with its uid, priority and
    user and system ticks;
  - cp_time is vm.cp_time and the clock rate kern.clockrate;
  - memory is vm.meter's resident and free pages, FGX having no
    hw.physmem, and swap is reported as none.
  procs(2) copies every record in one call, so upstream's validation
  re-read and its unavailable and swapped states go.  NI is 0
  (setpriority(2) stores nothing), TEXT is `-', DATA is the heap's
  high-water break and STACK the bank-0 reservation; a row's history is
  keyed by pid and takes only a growing tick count, there being no start
  time per process.  The man page is new, from upstream's README.
  
  MAME test top: a CPU-bound copy of yes under a name nothing types runs
  for eight seconds, then top -s 2 until an injected q.  top_check.py
  reads the last frame: the 1-minute load average is not 0.00, the busy
  row's TIME is at least a second and its DTIME is not 0.00.  With the
  heartbeat's charging and _Vm_Loadav disabled all three fail.

- fcc: storage class specifiers and qualifiers after the type
  K&R A.8: "the declaration-specifiers consist of a sequence of type and
  storage class specifiers", and its grammar takes them in any order:
  
      declaration-specifiers:
          storage-class-specifier declaration-specifiers-opt
          type-specifier declaration-specifiers-opt
          type-qualifier declaration-specifiers-opt
  
  parse_type_spec took static, extern, register, auto, const and volatile
  only before the type, so 2.11BSD tee.c's `int register r,w,p;' stopped at
  `register' with "expected ';'".  The specifiers after the base type are
  now consumed for every base, and a `static' among them makes a local
  static exactly as a leading one does: build_decl hands it to
  parse_static_local, which now takes the parsed TypeSpec, so `int static
  n = 1;' and `static int n = 1;' compile to the same code.  `int typedef
  T;' is still refused.
  
  Fixture M45/spec_order: the orders tee and its neighbors use, and a
  trailing-static counter with an initializer that an auto would reset;
  it fails with the static hand-off removed.

- libc: telldir(3) and seekdir(3)
  From 2.11BSD vendor/2.11BSD/usr/lib/libc/gen/telldir.c and seekdir.c
  (5.2, 3/9/86), vendored with this.  Upstream's interface: telldir names
  a position and "Only values returned by telldir should be passed to
  seekdir".  Upstream's position is lseek(dd_fd) less what is still
  buffered; a FGX DIR is the whole directory read at opendir (dir.c), so
  the position is the cursor into that snapshot and seekdir sets it.  A
  reopened, unchanged directory lists in the same order, so a position
  carries across closedir and opendir, which is how du(1) uses it.
  
  One new member, telldir.c, after dir.c; <sys/dir.h> declares both.

- userland: tail, tee, comm, split, tsort, rev, expand, unexpand, printf, sum, tty, dd, du
  The 2.11BSD text and file tools FGX lacked, each the vendored source
  verbatim behind the provenance header, with its 2.11BSD cat page, in
  /bin:
  
      vendor/2.11BSD/usr/ucb/{tail,expand,unexpand}.c
      vendor/2.11BSD/usr/bin/{tee,dd,du}.c
      vendor/2.11BSD/usr/usr.bin/{comm,split,tsort,rev,sum,tty}.c
      vendor/2.11BSD/usr/usr.bin/printf/printf.c
  
  Two deltas:
  - dd's BIG is 32767.  number(big) takes `big' as an undeclared, so int,
    parameter and is passed the long 2147483647.  The PDP-11 stores a
    long's high word first, so 2.11BSD's dd read 32767; the 65816 stores
    the low word first, so dd read -1 and answered every argument with
    "dd: argument 1 out of range".  32767 is the bound dd had on its own
    machine.
  - du's `long curoff' starts at 0, not NULL.  2.11BSD's NULL is a bare 0;
    FGX's is ((char *)0), and a pointer converts to a long only by a cast
    (K&R A.6.6).
  
  tee needed fcc to accept `int register', and du needed telldir(3) and
  seekdir(3); both land in the commits before this one.
  
  MAME test texttools runs each tool from a staged script, its needles
  outputs rather than typed text; it goes red with dd's BIG at its upstream
  value.

- gen.py: fcc flags keep their quoting
  rebase_flags split a tool's flags with shlex and joined them back with
  spaces, so a flag that carried quotes lost them: diff(1)'s
  -DDIFF='"/bin/diff"' reached fcc as -DDIFF=/bin/diff, an expression
  rather than a string.  The tokens are now joined with shlex.join.  No
  existing tool's command line changes.

- include: <assert.h>
  2.11BSD's assert.h (4.2 85/01/21), verbatim: assert(ex) prints the file
  and line to stderr and exits 1 when ex is false, and NDEBUG compiles it
  away.  patch(1) includes it.

- fcc: a struct's pointer field initialized by an address plus a constant
  A pointer field in a brace initializer took &global, a global name, a
  member or a constant subscript, and stopped at a following `+' or `-':
  2.11BSD sort's `struct field proto = { nofold+128, zero+128, ... }' died
  "expected ',' between struct field inits".  K&R A.7.19: "Initializers
  must evaluate either to a constant or to the address of a previously
  declared external or static object plus or minus a constant."  The
  scalar pointer initializer already took the displacement; the field path
  now does too, scaled by the pointee as pointer arithmetic is (A.7.7), and
  folded into the relocation's addend like a member offset.
  
  Fixture M45/field_ptr_disp: char and int pointer fields with + and -,
  the int one scaling by 2, and the int after them landing in its own
  member.  Returns 42 in MAME.

- fcc: __LINE__ and __FILE__
  K&R A.12.10: "__LINE__ A decimal constant containing the current source
  line number.  __FILE__ A string literal containing the name of the file
  being compiled."  fcc defined neither, and 2.11BSD's assert(), which
  patch(1) calls, names both.  Each is replaced where the preprocessor
  meets it, so a use inside a macro body reports the line the macro is
  used on, as assert() needs, and __FILE__ is the path fcc was given.
  
  Fixture M45/predef_line_file: __LINE__ bare and through a macro, and the
  end of __FILE__.  Returns 42 in MAME.

- fcc: an element of a global array of struct pointers keeps its struct
  `struct line *file[2]; ... file[0][i].value' (2.11BSD diff, diffreg.c)
  died "subscripting a struct pointer here has no known stride".  Reading
  an element of a global pointer array typed it as the pointer but dropped
  the struct, which the same read of a local array keeps, so the second
  subscript had no size to scale by.  K&R A.7.3.1: "E1[E2] is identical
  (by definition) to *((E1)+(E2))", and the sum scales by the struct's size
  as for any struct pointer.  The global arm now carries the struct, as
  the local arm and the pointer-to-pointer arm below it do.
  
  Fixture M45/gptr_struct_arr: reads and a store through file[k][i] on a
  three-int struct, where a stride of 2 would land on the wrong member.
  Returns 42 in MAME.

- fcc: a static local declared as a function pointer
  `static int (*hupval)(),(*intval)();' (2.11BSD patch, util.c's
  set_signals) died "expected name in static-local decl": the static-local
  declarator took stars, a name and subscripts, and never the
  parenthesized function-pointer form that block-scope autos and
  file-scope globals both accept.  K&R A.4.1: "Static objects may be local
  to a block or external to all blocks, but in either case retain their
  values across exit from and reentry to functions and blocks."  A static
  local function pointer is now the file-scope fn-ptr global, under the
  static-local alias, with that global's optional initializer.  The hidden
  global's mangled name is made by one helper the two arms share.
  
  Fixture M45/static_fnptr: two in one list set on one call and called on
  the next, and a third initialized to a function.  Returns 42 in MAME.

- include: <a.out.h> over FGX's executable header
  2.11BSD's a.out.h names the header `struct exec' and tests it with
  N_BADMAG(x), true when x.a_magic is not an executable's magic.  diff(1)
  calls that on the first block of each file to decide whether it is
  binary.  FGX's header is the one include/loader.s describes, sixteen
  bytes beginning "FGX2" or "FGX3", so struct exec is that magic and the
  rest of the header, and N_BADMAG checks for those two.  Upstream's
  PDP-11 magics, overlay headers and N_*OFF macros describe a format FGX
  does not have and are not carried.

- fgxfs: files staged under /usr/libexec are executable
  install_mode gives 0755 to files staged into the executable directories
  and 0644 to the rest.  /usr/libexec is where 2.11BSD installs the
  programs other programs run -- diff(1)'s diffh, diff3(1)'s diff3 (their
  Makefiles' `install' targets) -- and a 0644 diffh answered "Permission
  denied" when diff -h executed it.

- userland: sort, find, xargs, diff, diff3, patch, pr
  From 2.11BSD, each with its cat page.  sort, find, xargs, diff, pr and
  patch are in /bin; diff's diffh and diff3's comparison program are in
  /usr/libexec as their Makefiles install them, and /bin/diff3 is the
  upstream shell script that drives it.  pr is here because diff -l pipes
  through it.  patch is Larry Wall's, under his terms (LICENSE).
  
  diff, diffh, diff3, pr and patch are verbatim.  The deltas:
  - sort and diff build with -Dpdp11, as tcsh does: 2.11BSD's pdp11 arms
    are its 16-bit-int ones.  sort's MEM is 16*2048 there and 128*2048
    otherwise, which overflows a 16-bit int to 0 and left sort looping on
    brk() for ever; diff counts a directory's entries before allocating.
  - find's twelve predicates from glob() to ok() read their node through
    private structs that overlay struct anode on the PDP-11's equal-size
    function pointer, int and pointer.  On FGX the function pointer is four
    bytes, every field read the wrong word, and -name matched nothing.
    They take the struct anode mk() built and cast L and R back.
  - xargs lets the command line take ARG_MAX / 2 rather than ARG_MAX - 4K:
    NCARGS is 5120 on 2.11BSD and 768 on FGX, where the subtraction went
    negative and every run ended "insufficient space for command".
  - diff.h defines its globals in each file that includes it, so diff
    links them as commons.
  
  find's fast-find database is not ported: updatedb is a csh script that
  calls awk and mail, which FGX does not have, and bigram and code exist
  only to serve it.
  
  MAME test texttools2 runs each tool from a staged script; find's needle
  went red with the predicates still reading the PDP-11 overlay.

- fcc: a call may pass more arguments than a VARARGSn definition names
  lint's VARARGSn comment on a definition was recorded as n_fixed, but the
  argument count check ignored it, so a call that passed more arguments than
  the definition names died with "expects N arguments".  2.11BSD ftp's
  command(fmt, args) is marked VARARGS1 and reaches its printf arguments by
  walking up from &args.  K&R A.7.3.2 (p.163) says "The number of arguments
  must be the same as the number of explicitly described parameters" only
  when the declaration in scope is new-style; for an old-style one, "The
  effect of the call is undefined if the number of arguments disagrees with
  the number of parameters in the definition".  The check now stands aside
  when the definition carries the marker.  Arguments are pushed right to
  left, so the named parameters sit at fixed offsets and the extras lie
  above them.
  
  The marker was also lost when a preprocessor directive stood between it
  and the definition, as ftp's #ifdef pyr does.  scan_tok gave the marker to
  the token it was starting before it knew the token was a directive, and
  the directive's own rescan then cleared it.  A directive now passes the
  marker on to the next real token, and raw-mode tokens (#if expressions,
  macro bodies) never take it.
  
  Fixture M45/varargs_lint.c: a VARARGS1 definition behind an #ifdef, called
  with three arguments, sums them through &args.

- fcc: a block-scope extern declaration carries its struct type
  A block-scope `extern' declaration of a name no file-scope declaration had
  introduced was entered as a global with its type code and element count
  only: no struct id, no struct size, no unsigned flag and no function
  signature.  Pointer arithmetic on such an array then died with "internal:
  struct-pointer stride with unknown struct id".  2.11BSD ftp's help()
  declares `extern struct cmd cmdtab[];' inside the function and steps
  through it with `c = cmdtab + j * lines + i'.
  
  K&R A.11.2 (p.188): "If it does include extern, and an external
  declaration for is active in the scope surrounding the block, then the
  identifier has the same linkage as the external declaration, and refers to
  the same object or function; but if no external declaration is visible,
  its linkage is external."  The declaration names the program's object, so
  the global now records the declared type whole, as the file-scope path
  does.
  
  Fixture M45/blk_extern_struct.c: a block-scope extern struct array,
  defined later in the file, indexed by pointer arithmetic.

- provenance: the check sees a port before it is committed
  check_provenance.py looked only at files git tracks.  A port is checked
  while it is being written, before it is added, so a new file passed
  unseen; and committing it changed no input of the build stamp, so the
  check never ran again.  2.11BSD diff's diffdir.c and diffreg.c reached
  main that way with no registry rows, through two green gates.
  
  The scan now takes untracked files too (git ls-files --cached --others
  --exclude-standard), so git's ignore rules still keep build products out,
  and the stamp's input list gains each new file as soon as build.ninja is
  regenerated.  The two diff rows are added.

- libc: herror(3)
  2.11BSD's herror.c from lib/libc/net, verbatim in the body: herror()
  writes its argument and the message for h_errno to standard error in one
  writev(2), and h_errlist and h_nerr are the message table.  h_errno
  already lives in netdb.c, which the gethostbyname resolver sets; herror
  follows it in the aggregate.  ftp(1) calls it when a host name does not
  resolve.

- include: <arpa/ftp.h>
  2.11BSD's arpa/ftp.h (5.4), verbatim: the FTP reply classes, and the
  type, form, structure and mode codes ftp(1) uses.

- userland: ftp
  2.11BSD's ftp(1) from usr/ucb/ftp, every file verbatim behind its
  provenance header, installed as /bin/ftp with its cat page.  ftp_var.h
  defines its globals in every file, so they link as commons, and the code
  is packed across segments (about 125 KB in all).
  
  The linker's stack model asks for 89 pages, 22,714 bytes, which is more
  than the 83-page cap, so it is clamped.  The deepest path that does not
  recurse is 3,281 bytes; the rest is the reserve for the recursive paths
  (glob, macros).
  
  The ftp test runs ftp from a staged script: help prints the command
  table, status reports the defaults, and an open to a port nothing listens
  on is refused over loopback.  No server is involved, so nothing is
  transferred.

- net: bind(2) to port 0 picks the port
  2.11BSD in_pcbbind chooses the local port at bind when the caller asks
  for port 0 (vendor/2.11BSD/usr/sys/netinet/in_pcb.c:97, `if (lport == 0)
  do { ... head->inp_lport++ ...'), so getsockname(2) can name it before
  listen(2).  Both of FGX's bind arms recorded the 0 instead: net_op_bind's
  hardware path and _Loop_BindTry.  ftp(1)'s initconn binds its data socket
  to port 0 and sends getsockname's answer in a PORT command, so it sent
  `PORT a,b,c,d,0,0' and vsftpd answered `500 Illegal PORT command'.  Both
  arms now take _Sock_EphemPort's next port when the caller's is 0.
  
  _Sock_EphemPort's counter is seeded to 49152 only when the Uthernet card
  initializes, so with no card the first two picks were 0 and 1.  The
  picker now applies the range test itself, as in_pcbbind's loop does
  (`if (head->inp_lport++ < IPPORT_RESERVED || ...) head->inp_lport =
  IPPORT_RESERVED'): a counter below 49152, never seeded or wrapped,
  restarts there.
  
  loopprobe -0 binds port 0 on the wildcard and on 127.0.0.1; both ports
  must be at least 1024 and differ, and a connect to the loopback port must
  reach its listener.  Before the fix it printed `zero ports wild 0 loop 0'.
  The bindzero test runs it.

- net: the W5100's socket 0 serves connections when capture does not hold it
  _W5_SockAlloc handed out sockets 1..3 and kept socket 0 back for
  /dev/bpf0, because the W5100 runs MACRAW only on socket 0.  bpf is not
  loaded by default, so the machine had three hardware sockets for every
  connection: inetd's telnet listener, ntpd and an ftp control connection
  used them all, and ftp's data connection failed with ENOBUFS.
  
  The allocator now hands out 1..3 first and socket 0 last.  bpf_open
  claims socket 0 through the same bitmap, _w5SockInUse, and answers EBUSY
  while a connection holds it; bpf_close gives it back.  bpf reaches the
  bitmap through its kernel exports.  The W5100 interrupt handler records
  a ready bit per socket and wakes socket sleepers, and nothing reads
  socket 0's bit as capture data, so a connection on socket 0 only gains
  interrupt-driven wakeups.

- ftp: passive mode, from 4.4BSD-Lite2
  2.11BSD's ftp makes every data connection by listening on a local port
  and sending its address in a PORT command, so the server connects back.
  Behind NAT that cannot work: MAME's Uthernet is NAT'd behind the host,
  the address FGX sends is not the one the server sees the control
  connection come from, and vsftpd answers `500 Illegal PORT command'.
  
  4.4BSD-Lite2's ftp (8.x) added passive mode: the `passive' command
  toggles it, initconn sends PASV and connects to the address the server
  returns, and dataconn hands back that connected socket instead of
  accepting one.  Those pieces are taken verbatim into ftp.c, cmds.c,
  cmdtab.c, main.c and ftp_var.h; 2.11BSD's getreply already saves the
  PASV reply in pasv[] for its proxy command.  As in Lite2, passive mode
  starts off.  The Lite2 ftp sources are vendored, from the CSRG archive's
  GitHub copy, and its man text for `passive' is added to the cat page.
  
  Measured against a vsftpd 3.0.5 server through the emulated Uthernet:
  in passive mode `ls' lists and a binary `get' of a 1,110,016-byte file
  matches the host's copy (sum 59370 1084).  The ftp test toggles passive
  mode; no server is reachable from the gate, so no transfer is tested
  there.

- ftp: passive mode is on by default
  Active mode cannot work behind NAT: the server is told to connect back to
  an address it cannot reach, and one it does not see the control
  connection come from.  MAME's Uthernet is always behind NAT, so with
  4.4BSD-Lite2's default every session needed `passive' before its first
  transfer.  ftp now starts in passive mode, as later BSD ftp does;
  `passive' turns it off for a server that refuses PASV, which prints
  `Passive mode refused.'  The man page and the provenance row record the
  difference from Lite2.
  
  Measured against vsftpd through the emulated Uthernet with no `passive'
  typed: ls lists, and a binary get matches the host's copy.

- fcc: # and ## in macro replacement
  fcc's preprocessor died on `#' inside a #define body.  K&R A.12.3
  (p.189): "if an occurrence of a parameter in the replacement token
  sequence is immediately preceded by #, string quotes (") are placed
  around the corresponding parameter, and then both the # and the
  parameter identifier are replaced by the quoted argument"; "each ## is
  deleted, together with any white space on either side, so as to
  concatenate the adjacent tokens and form a new token"; and "Unless the
  parameter in the replacement sequence is preceded by #, or preceded or
  followed by ##, the argument tokens are examined for macro calls, and
  expanded as necessary".
  
  A macro body is tokenized in raw mode, which now yields `#' and `##' as
  tokens.  At expansion the call keeps each argument as written beside its
  expanded form: a parameter after `#' becomes a string spelling the
  unexpanded argument, with one space where the source had white space and
  string and character literals re-escaped; a parameter beside `##' is
  substituted unexpanded; then each `##' joins its neighbors by re-scanning
  their joined spelling, which must give one token.  An empty argument
  leaves the other side alone.  An object-like body's `##' is applied once
  at #define.  #define refuses `##' at the start or end of a replacement
  ("## may not appear at the beginning or end") and a `#' not followed by
  a parameter.
  
  2.11BSD's uipc_domain.c builds unixdomain and inetdomain with the
  pre-ANSI x/**/domain; A.12 replaces a comment with a single space, so the
  net-mux port writes `##' there.
  
  Fixture M46/pp_paste.c: cat(x, ONE) pastes the unexpanded name, xcat
  expands first, and #x quotes an argument holding a string literal.
  Rejects: ## at either end, # before a non-parameter.

- fcc: an extern declaration may name an incomplete struct
  `extern struct domain inetdomain;' before struct domain is complete was
  refused ("by-value struct global requires complete type").  K&R A.8.3
  (p.173): "Objects with an incomplete structure or union type may be
  mentioned in contexts where their size is not needed, for example in
  declarations (not definitions), for specifying a pointer, or for creating
  a typedef, but not otherwise."
  
  An extern declaration of such an object is now accepted, and the check
  moves to where a size is needed.  When the struct completes, every
  global of that type still without a size takes the struct's size.  A
  definition still needs a complete type, and while the type is incomplete
  `.' on the object ("member of an object of incomplete struct type") and
  sizeof ("sizeof an object of incomplete struct type") are refused.
  2.11BSD's netinet/in.h declares inetdomain this way.
  
  Fixture M46/extern_incomplete.c: the extern precedes the struct, the
  object is defined after it, and sizeof and member access see the whole
  type.  Rejects: a member and sizeof of an object whose struct never
  completes.

- fcc: a whole struct array element is a struct value
  `ip_srcrt.route[i] = dst;', with route an array of struct in_addr, was
  refused ("struct-array element LHS requires '.field'"), and so was an
  element on the right ("struct-array indexed access requires '.field'").
  K&R A.7.17 (p.169): in simple assignment "One of the following must be
  true: ... both operands are structures or unions of the same type".
  
  On the left, the statement-level fast paths for `x.arr[i]' and
  `p->arr[i]' now hand a whole-element store to the expression layer,
  which copies structs, as they already do for a struct-valued subfield.
  On the right, an element with no `.' is the element's address node
  typed as the struct, since fcc carries a struct value as its address;
  a first version wrapped it in a dereference, and the struct store then
  used the element's first word as the source address.
  
  Fixture M46/struct_elem_assign.c: stores into a global's array member, a
  local array and an array member through a pointer, from a struct and
  from another element, with the neighbors untouched; an element also
  passes by value as an argument.

- fcc: an address plus a constant in an array-of-pointers initializer
  `char *tp[] = { t+4 };' was refused ("expected ',' or '}' in init
  list"), and so were `&t[2]' and `int *ip[] = { iarr+3 };'.  K&R A.7.19
  (p.170): "the unary & operator may be applied to external or static
  objects, and to external and static arrays subscripted with a constant
  expression", and "Initializers must evaluate either to a constant or to
  the address of a previously declared external or static object plus or
  minus a constant."
  
  The char*[] and T*[] item parsers keep their checks on the item and then
  hand it to sfld_ptr_addr_init, which #45 taught the struct-field form:
  `&g', an array name, `&g[k]', `&g.m', and `+ k' or `- k' scaled by the
  pointee.  The item packs the global's index in the low 16 bits and the
  byte offset in the high 16, as a pointer struct field does, and both
  array emitters now decode that and emit label+offset.  The offset is
  read sign-extended in all three emitters, so `t - 1' is a displacement
  of -1 rather than 65535.
  
  Fixture M46/ptrarr_addr_disp.c: char*[] and int*[] tables with plain,
  subscripted and displaced items, the int ones scaling by two.

- fcc: a bit-field reached through a pointer or a member chain is its bits
  A bit-field reached any way but `s.f' on a named struct was read and
  written as its whole containing word.  `x->c', `p->w.b', `q->r->w.b' and
  `p->arr[i].b' loaded the word without shifting or masking, and stores
  through the member-chain walker wrote the value over the neighboring
  fields: `hp->w.b = 9' compiled to one word store of 9.  The same code
  came out of main's compiler.  K&R A.8.3 (p.173): a field member "is
  interpreted as an object of integral type of the specified length in
  bits".  2.11BSD's IP and TCP headers are bit-fields (ip_hl:4, ip_v:4;
  th_off:4, th_x2:4), read and set through pointers.
  
  The member-chain walker records a bit-field leaf on the chain head, and
  the chain's load and plain store extract and merge its bits through the
  address the walker computes.  The arrow-to-struct-value load and store
  (N_AV_SCALAR, S_AV_STORE), the element-member paths, and every member
  load and word store done through a far pointer at a field's byte offset
  go through two helpers, emit_fpr_deref_member and
  emit_fpr_deref_store_wordmember, which handle a bit-field and are
  otherwise the existing code.  So op= and ++/-- on those paths read and
  write the field's bits.  The cumulative-offset member that indexed
  member chains synthesize now keeps the field's bit position.  A
  statement storing to an array element's bit-field goes to the
  expression layer.  Through the uniform walker, op= and ++/-- on a
  bit-field leaf are refused rather than compiled as a word.  Fields stay
  unsigned, as the direct paths already treat them (A.8.3: "whether an
  int field is treated as signed is implementation-dependent").
  
  Fixture M46/bitfield_access.c: each of seven ways of reaching a field
  writes it and reads it back, the neighboring fields keep their values,
  and a wide value keeps only the field's bits.

- fcc: & of any lvalue, but not of a bit-field or a register variable
  `&' took a list of operand shapes, and 2.11BSD's socket and IP code
  spells three it did not have: IA_SIN's
  `&(((struct in_ifaddr *)ia)->ia_addr)', sblock's `&(sb)->sb_flags' with
  sb itself `&so->so_snd', and sorwakeup's `&(so)->so_rcv' with so itself
  `inp->inp_socket'.  K&R A.7.4.2 (p.164): "The operand must be an lvalue
  referring neither to a bit-field nor to an object declared as register,
  or must be of function type"; A.7.3.3 makes `E1->MOS' an lvalue "if the
  type is not an array type", whatever expression E1 is.
  
  A parenthesized group followed by `->' or `[', inside any number of
  wrapping parentheses, is now read as a value and the chain after it as an
  address, the mechanism the cast and call arms already use.  Groups the
  older arms compile -- a bare name, `(*p)', a cast straight after the `&'
  -- keep their code, so every existing program compiles as before.  `&*p'
  is p (A.7.4.3 makes `*p' an lvalue).
  
  The two refusals A.7.4.2 requires had never been made: `&' of a bit-field
  and of a variable declared register compiled.  `register' is now kept on
  the type specifier and carried to locals and K&R parameters.  Only the
  variable's own storage is refused -- `&r', and `&r.m' or `&r[i]' on a
  struct or array; through a register pointer, `&p->m' and `&p[i]' name
  the object it points to, as 2.11BSD's kern_subr.c and tcsh's sh.dir.c
  take them.  A bit-field is refused on the direct paths and wherever a
  chain's address is taken.
  
  Fixture M46/addrof_lvalue.c: the three 2.11BSD shapes with and without a
  wrapping pair of parentheses, &p->arr[2], &a[1].addr, &*p, and & through
  a register pointer.  Rejects: & of a bit-field directly and through a
  chain, & of a register variable.

- fcc: a function may return a struct by value
  K&R A.10.1: "A function may return an arithmetic type, a structure, a
  union, a pointer, or void, but not a function or an array."  2.11BSD's
  in.c returns a struct in_addr from in_makeaddr().
  
  The caller passes the address of a temporary of its own as a hidden
  parameter 0; the callee copies the returned value through it and returns
  that address, which the caller then holds as the struct value.  Each call
  gets its own temporary, so two calls in one expression, a recursive call
  and a discarded call are all safe.  Calls through a function pointer carry
  the struct in the signature (FnSig.sret_sid), and a member of the result
  (`f().x', `(*fp)().y') reads through the returned address.
  
  A struct-returning definition after an implicit int declaration of the
  same name is refused.  The --sigs sidecar skips struct-returning
  functions, as it skips struct parameters: struct ids are local to a
  translation unit.
  
  docs/userland-abi.md gives the convention.

- fcc: a call through a function pointer at the end of a member chain
  K&R A.7.3.2: "The postfix expression (after possible explicit
  declaration and pointer generation, Par.A7.1) must be of type ``pointer
  to function returning T,'' for some type T".  Nothing restricts how the
  pointer is reached.
  
  A function-pointer member one or more `.' hops past an arrow carried no
  signature, so `(*p->s.fn)(x)', `(p->s.fn)(x)' and `p->s.fn(x)' died on
  "expected ';'".  2.11BSD's netinet/if_ether.c calls
  `(*ac->ac_if.if_output)(&ac->ac_if, m, &sa)'.  The leaf now carries the
  member's signature, and a call may follow it directly.

- fcc: a typedef may name an array of known size
  K&R A.8.9: "A typedef declaration attributes a type to each name among
  its declarators in the usual way (see Par.A.8.6).  Thereafter, each such
  typedef name is syntactically equivalent to a type specifier keyword for
  the associated type."  2.11BSD's pdp/seg.h declares
  `typedef struct segm_reg mapinfo[2];'.
  
  The typedef records its element count, and a declaration through the
  name gets that array: a global, a local or a struct member is sized by
  it, a parameter declared with it is a pointer, and sizeof of the name is
  the whole array.  A sizeless array typedef keeps completing at each use
  from its initializer.
  
  A comment on call_add_sret no longer nests a comment opener.

- fcc: a struct function may return the struct a pointer points to
  K&R A.7.4.3: "The unary * operator denotes indirection, and returns the
  object or function to which its operand points. ... If the type of the
  expression is ``pointer to T,'' the type of the result is T."  2.11BSD's
  netinet/in.c ends in_makeaddr() with `return (*(struct in_addr *)&addr);'.
  
  A struct value is its address, so the value of `*p' is p itself, which
  is how an assignment already reads `s = *p'.  The return of a
  struct-returning function refused `*p' as not being a struct.

- fcc: sizeof of `*' applied to any expression
  K&R A.7.4.8: "The operand is either an expression, which is not
  evaluated, or a parenthesized type name."  2.11BSD's uipc_syscalls.c
  copies out `sizeof (*uap->anamelen)' bytes.
  
  `sizeof *E' and `sizeof (*E)' took only a bare name after the stars, so
  `*p->m', `*(p->m)' and the like died on "expected ')'".  Any other
  operand is now built as an expression and sized by the type it points to
  (A.7.4.3: "If the type of the expression is ``pointer to T,'' the type
  of the result is T"), so a struct or a char pointee has its own size
  rather than that of the value a load leaves.

- fcc: a struct function declared before its definition passes the hidden pointer
  K&R A.10.1: "A function may return an arithmetic type, a structure, a
  union, a pointer, or void".  A declaration at block scope, as 2.11BSD's
  netinet/ip_icmp.c declares `extern struct in_addr in_makeaddr();', or
  one beside other declarators in a file-scope list (`struct s gs, f();')
  recorded the struct as a plain return type, so a call before the
  definition passed no hidden temporary and the callee copied its value
  through whatever lay in parameter 0.  Both declarations now mark the
  function as returning a struct by value, as its definition does.

- fcc: a call of a struct function needs the struct complete
  K&R A.8.3: "Objects with an incomplete structure or union type may be
  mentioned in contexts where their size is not needed, for example in
  declarations (not definitions), for specifying a pointer, or for
  creating a typedef, but not otherwise."
  
  A call reserves a temporary of the returned struct in the caller's
  frame.  Called while the struct was still incomplete, the temporary had
  no size and the callee wrote the value over the caller's frame.  The
  call is refused until the struct is complete.

- fcc: a pointer to or an array of an array typedef is refused
  K&R A.8.9: "each such typedef name is syntactically equivalent to a type
  specifier keyword for the associated type".  `typedef long A[4]; A x[2];'
  declares an array of arrays and `A *p' a pointer to an array, which the
  declarator does not represent: x was sized as two ints and p was indexed
  through its own storage.  Both are refused rather than compiled at the
  wrong size.

- fcc: ++ and -- on a bit-field step its bits in value position too
  K&R A.7.4.1: "The operand is incremented ++ or decremented -- by 1.  The
  value of the expression is the value after the incrementation", and
  A.7.3.4 gives postfix the value before; A.8.3 makes a field "an object of
  integral type of the specified length in bits".
  
  `++p->b', `p->b++', `s.b--' and the like, used for their value, bumped
  the whole containing word and yielded it, changing the neighboring
  fields; through a longer member chain they were refused.  Both now read
  the field, step it, store it back into its own bits and yield the new or
  the old field value; the field wraps within its width.

- fcc: --shared-data, for code banks over one data bank
  An FGXM module's C runs with DBR on its own bank, so an indirect call moves DBR
  to the callee and restores it afterwards.  --shared-data is for several code
  banks that share one data bank: DBR is that bank in all of them, so the call
  reads the target's bank from the pointer for the RTL frame and leaves DBR
  alone.  Everything else about --module-bank stands, including MOD_FN_PTR cells.
  
  K&R A.7.3.2 (p.163): "The ANSI standard blesses the practice of some existing
  compilers by permitting the same syntax for calls to functions and to functions
  specified by pointers."  A direct call between these banks leaves DBR alone, so
  a call through a pointer must too.
  
  A tentative definition across these banks needs nothing new: --commons and
  gen_commons already implement A.10.2.

- fcc: a pointer initializer in a module gets a stamped cell
  `char *p = "x"', `int *q = &g' and `&arr[1]' in a data initializer emitted
  FGX2_LONG_PTR or LIBC_DATA_PTR, which fgx_ld patches.  A module has no linker
  and include/macros.s defines neither macro for it, so such a file could not
  assemble as a module.  No kernel C met this until the network code, whose
  inetdomain names inetsw.  Under --module-bank the cell is now MOD_FN_PTR: the
  offset resolves at assembly and _Mod_StampFnPtrs writes the image's bank.
  
  K&R A.7.19 (p.170): "Initializers must evaluate either to a constant or to the
  address of a previously declared external or static object plus or minus a
  constant."

- net: code banks over one data bank, linked at load
  An FGXM module's C runs with DBR on its own bank, so it cannot name another
  module's global, and 2.11BSD's network layers share theirs throughout.  These
  modules share a data bank.  tools/build_bsdnet.py takes a translation unit list
  and fcc's output and writes bsdnetd, holding all the data, and bsdnet0-2, holding
  the code.  A call between code banks arrives at a stub in the caller's bank whose
  JML adds no stack frame, so the callee's RTL returns straight to the caller.
  
  Each module records its bank in bsdnetd; bsdnet2 stamps the stubs when it loads
  and enters bsdnet_init.  The import and export lists come from fcc's output, and
  tentative definitions coalesce through gen_commons as K&R A.10.2 asks.
  
  The netprobe test, at kernel.netprobe = 1, runs globals both ways, a tentative
  definition in two files, a direct call, a call through a cell in the data bank,
  string literals, pointer initializers and the runtime's scratch across banks.
  Built with --module-bank instead of --shared-data it reports case 4, the call
  through a cell.
  
  The modules are staged but no boot loads them.  They take ordinals 8-11, so
  MOD_BANK_MAX is 12.  They also filled the loader's extent table, so _modExtBank
  packs to a byte per entry and MOD_EXT_MAX is 20; shortening one diagnostic pays
  for it, and the core bank went from 12 bytes free to 10.

- fcc tests: run_reject finds shared_data_flag from any directory
  The gate runs it from the repository root.

- vendor: the 2.11BSD network sources
  usr/sys/net, netinet and the uipc_ files with the headers they read, pristine,
  from examples/2.11BSD.

- net: port 2.11BSD's network sources and write the machine seam
  Every file of the port set compiles: net/, netinet/ and sys/uipc_*, compiled but
  not yet linked.
  
  The configuration symbol is fgx, not pdp11.  With fcc's 4-byte pointers the pdp11
  arm is wrong: ih_pad, ipq_pad and ipf_pad (netinet/ip_var.h) pad 2-byte pointers
  up to the VAX layout, so here they would misplace every overlaid IP header, and
  BYTE_ORDER would be PDP_ENDIAN.  fgx takes the VAX layout and the pdp11 word-size
  choices, per site; docs/PROVENANCE.md lists each one.
  
  h/mbuf.h has MMINOFF 10 and MTAIL 4, so MLEN is 114 where a VAX has 112.  dtom,
  mtod, cltom, mtocl and MTOCL go through long, because a pointer no longer fits an
  int.  mtod adds m_off within the bank: h/mbuf.h's MCLGET stores a 16-bit
  difference, which wraps for a cluster below its mbuf.
  
  pdp/net_mac.h's supervisor-space calls become direct calls.  h/user.h and h/proc.h
  are reduced to the fields read.  FREAD, FWRITE, FDEFER and FMARK come from
  4.3BSD-Reno sys/file.h and fcntl.h.

- fcc: an unsigned member stays unsigned through every access path
  N_ARROW_CHAIN and N_AV_SCALAR dropped the member's signedness, so (x)->off and
  x->in.v read an unsigned short as signed: $FF80 widened to long as $FFFFFF80, and
  compared and shifted as a negative number.  Every BSD macro spells its argument
  with parentheses, so `(m)->m_off >= MSIZE' in h/mbuf.h's M_HASCL answered wrong
  for a cluster stored as a wrapped offset.
  
  K&R A.7.3.3 (p.164): "The result refers to the named member of the structure or
  union to which the pointer expression points, and the type is the type of the
  member".
  
  A green mutation found it: replacing mtod's 16-bit add with a 32-bit one should
  carry into the next bank, and did not, because the offset had been sign extended
  back to the right answer.  The kernel's own C changes too, so the ufs and ufsdir
  function-pointer tables move.

- net: link the stack; mbufs run
  All of net/, netinet/ and the socket layer but uipc_syscalls.c and uipc_usrreq.c
  link into four code banks over the data bank, and the last module to load runs
  mbinit and domaininit.  AF_UNIX stays out of the domain list until its code links.
  
  The code is 182 KB and the data image 41 KB, 35 KB of that the mbuf pool, so five
  banks in all.  MOD_BANK_MAX is 13 and MOD_EXT_MAX 24; shortening two loader
  messages pays for it, and the core bank has 20 bytes free.
  
  machine/net_kern.c gives the code its kernel routines through the same kc_ seam
  the other modules use; cpfromkern and mfkd keep pdp/net_copy.s's interface.  What
  later phases replace is in machine/s2_stubs.c.  timeout is empty for now, so no
  timer fires yet.
  
  netprobe now checks the data model on the machine: sizeof(struct mbuf) is 128,
  struct ipovly and struct ip are 20, struct tcpiphdr is 40, and struct inpcb,
  tcpcb and socket fit an mbuf; dtom undoes mtod; a cluster reached through a
  wrapped m_off stays in its bank; the pool exhausts at its count and refills; and
  m_copy, m_adj and m_pullup give the right bytes.  A 32-bit mtod reports case 18.

- net: spl, in_cksum, and MGET at interrupt level
  The 65816 has one mask, so splimp and splhigh set I and return the I bit as it
  was, as kc_spltty does; splx restores it.  splnet masks nothing.  On the PDP-11 it
  holds off the network software interrupt, and here netintr runs only at the
  kernel's deferred-work drain, which kernel code reaches only by sleeping, as it
  does upstream.  Masking through TCP processing would stop the VBL.
  check_spl_balance now covers the network files for splimp and splhigh.
  
  in_cksum is 65816 assembly with upstream's odd-byte handling (pdp/in_cksum.c),
  checked on the machine against values computed independently, across split and
  empty mbufs.
  
  MGET's `(ms&0340) <= 0100' reads a PDP priority, and spl returns a bit here, so
  the test was always true and an interrupt-level M_DONTWAIT ran the protocol
  drains.  It tests the bit now.
  
  The wait channel is an address's low 16 bits.  The kernel's fixed channels are
  $FFxx, so an assembly check keeps the data image below them, which leaves aliases
  only with other modules' address channels, whose sleepers re-test.

- net: netintr runs at the deferred-work drain
  schednetisr sets netisr under upstream's own splimp, and setsoftnet marks the
  summary word the kernel's drain already tests, at syscall exit and in the idle
  loop.  The drain enters the tty bank as it does for soft output; after kc_ttdrain
  the tty bank calls netintr through a vector, which is empty until the network
  modules load.  No C context is live at those sites, so the shared kernel-C
  register file is free, and a kernel with no network modules pays no new test.
  
  netintr is pdp/net_trap.s's loop in C, with its IP and RAW arms, and it must not
  sleep, as a software interrupt must not.
  
  The core bank is untouched.  The two doors are tty-bank slots, and a module takes
  the kernel bank from SYS_KCALL's bank-0 JML cell.
  
  netprobe checks that schednetisr is not synchronous, that netintr runs after the
  syscall returns, and that a pass scheduling itself runs again inside the same
  entry.  Without the loop the last of those fails.
  
  Latency is the drain's: about 67 ms past a compute-bound C program, whose
  safepoint yields every four VBLs.  Assembly and goto-formed loops wait for their
  next syscall.

- net: measure the kernel stack under the network code
  tools/net_stack_depth.py walks fcc's output for frames, pushes and calls, with a
  table for the calls through pointers.  The deepest netintr chain is 515 bytes and
  sosend 391, against kernel.kstk's 1024.  Both include PRU_CONTROL paths a real call
  cannot reach and a guess for the driver, so S2 measures on the machine.

- net: the cluster array has room for its alignment
  mbinit aligns the cluster pool with `(xmbutl | CLBYTES-1) + 1', which wastes a
  whole cluster when the array is already aligned.  uipc_mbuf.c's slack is 7 mbufs,
  896 of the 1024 bytes that takes, so in one layout out of eight the last cluster
  ran up to 128 bytes past the array into the next global.  The current layout
  happened to be safe, and any new tentative definition could move it.  Upstream
  has the same arithmetic; XMBUTL_SLACK is a full cluster under fgx.
  
  netprobe case 19 checks the size and where the pool actually landed.

- net: a partial set of network modules is refused by name
  The last module to load walked every module's link entry.  One that never loaded
  left a zero link and a zero bank, so the walk transferred to bank 0, offset 0, and
  that crash erases its own evidence.  A missing file, a refused module or a short
  modload command was enough.
  
  It now names the missing module and fails its init, and a code module that finds
  no bsdnetd fails too rather than reporting success.  The netpartial test loads
  partial sets and checks the machine survives.

- netpartial: the assertion is not satisfied by its own command line
- net: netintr runs on a stack of its own
  The drain reaches netintr from the idle loop as well as from syscall exit, and
  the idle loop stands on the 512-byte scheduler stack, which the static chain
  already nearly fills.  FGX_STK_NET is 1024 bytes directly below it in the mapped
  $D000 bank; check_bank0_geometry.py holds the placement.  netintr_enter moves S
  there, sets fcc's stack floor for it so an overflow halts through _fcc_stkoflow,
  opens interrupts, and restores all three on the way out.  2.11BSD's sleep() has
  no counterpart for this check: net_kern.c's sleep panics by name when netintr is
  running, since a second entry would overwrite the first on the one stack.
  
  bsdnet_init paints the stack and hooks the drain first, because its initializers
  may schedule.  check_mx now covers bsdnetd.  kernel.netprobe's value reaches the
  compile: 2 and 3 select the halting cases, netstkovf and netsleep.

- net: callouts, ticked from netintr
  machine/net_callout.c is timeout, untimeout and softclock from 2.11BSD's
  sys/kern_clock.c, on a table of 20 private to the network modules.  There is no
  clock interrupt to charge each tick, so net_charge takes the ticks that have
  passed, in netintr and before each insertion: without the second, a new entry
  was charged for time before it was armed and fired up to 8 ticks early.
  
  The heartbeat marks the drain every 8th tick, 11 bytes in core, so timers run on
  a quiet machine.  A kernel with no network modules pays one kc_ttdrain scan 7.5
  times a second.  mfkd's lbolt called kc_ticks with no buffer; it passes one now.

- net: lo0 comes up, and an ICMP echo crosses the real IP path
  bsdnet_init now follows netstart() in 2.11BSD's sys/sys_net.c: mbinit, loattach,
  ifinit and domaininit at splimp, then 127.0.0.1 on lo0 through in_control's
  SIOCSIFADDR, which upstream leaves to ifconfig.
  
  The probe sends an echo through ip_output, looutput, ipintr and icmp_input, and
  sees the request and the reply counted, then has a bad IP header checksum refused
  with no answer.  A lo0 echo reaches 330 bytes of netintr's stack from its paint,
  against 469 from net_stack_depth.py, which now leaves PRU_CONTROL out of the walk
  and follows raw_usrreq to rip_output and net_softclock to its timers.

- net: the W5100's bus for the network modules
  machine/w5_asm.s holds the chip primitives the driver is written over: the lock
  net.mod's U2_LOCK takes, register reads and writes, and copies to and from the
  rings.  They address the chip through X, long-indexed from slot 0's addresses,
  so one routine serves any slot with no patch table.  The kernel's bus state is
  reached with DBR on the live kernel bank.
  
  The network modules now hold kernel addresses, so they carry the build identity
  as net.mod and bpf.mod do, from their own list in gen_kernel_exports.py.

- net: the MACRAW driver
  net/if_w5.c is an Ethernet ifnet over the W5100's socket 0, shaped after deoutput,
  destart, deread, deget and deioctl in 2.11BSD's pdpif/if_de.c, now vendored.
  MACRAW with the MAC filter is $44 in Sn_MR and the frame's 2-byte header includes
  itself; MR's ping block goes on so icmp_input answers pings rather than both.
  
  Attach claims socket 0 from the kernel's allocator, as bpf_open does, and with no
  card or the socket held the stack carries on with lo0 alone and says so.  The
  address and netmask are those DHCP left in the chip.
  
  Nothing runs from the interrupt: the ISR now marks the drain as well as disarming
  itself, 3 bytes in core, and netintr drains.  w5rint takes 8 frames a pass and asks
  for another.  A length the ring cannot hold reopens the socket and counts an
  error, and a frame with no mbuf to go into is skipped and counted.  It also polls,
  so a lost interrupt costs 133 ms.
  
  W5100 datasheet v1.1.6 is silent on MACRAW beside open sockets and on the MAC
  filter bit, which is from Linux's w5100.c and the W5100S manual.

- fcc: a struct argument is a copy whatever the declaration says
  K&R A.7.3.2: "In preparing for the call to a function, a copy is made of each
  argument; all argument-passing is strictly by value."  fcc made the copy only when
  the parameter's type was in scope.  Through an old-style declaration or a call
  before the definition, it pushed the 2-byte address of the struct while the callee
  read the value from the same slots.  2.11BSD's in.h declares `u_long in_netof();'
  and route.c's inet_hash calls in_netof(sin->sin_addr), so every network route was
  filed under garbage and rtalloc answered ENETUNREACH.
  
  With no parameter type, the argument's own struct type now gives the size.  The
  "by-value struct argument not yet supported in a variadic call" reject goes too:
  fcc treats `()' as variadic, so it stood in the way of exactly these calls, and the
  fixture reads a struct back through va_arg.
  
  va_arg(ap, struct s) needed one more: A.7.2, "A parenthesized expression is a
  primary expression whose type and value are identical to those of the unadorned
  expression", and `s = (*p);' was refused where `s = *p;' was not.  It now takes
  the same pointer.
  
  Fixture M46/struct_arg_olddecl.

- net: ARP and an echo on the wire
  The probe sends an ICMP echo to the gateway the chip holds.  arpresolve holds the
  frame, the ARP reply releases it, and the reply comes back through w5rint, ipintr
  and icmp_input.  A burst of 45 echoes with the drain held overruns the 2 KB ring:
  33 frames arrive, the near-full ring is counted, and the machine answers afterward.
  netnoreply aims at an unused address, and arptimer clears the entry unanswered.
  
  netftp gets a 1,110,016-byte file through ftp's passive mode over the chip's own
  TCP while the stack holds socket 0, and its size and sum(1) match the host's copy,
  so the emulated chip routes by port beside MACRAW.  It needs the shipping rc.local:
  the suite's starts inetd and ntpd, which leave ftp no socket for data.

- bpf: netdump reads packets again, and watches the kernel stack
  /dev/bpf0 is a record device with no d_read, and since record devices are refused
  at _Chardev_Bulk rather than looped, every read of it answered EIO without reaching
  the driver: netdump listened and never printed a packet.  bpf_dread is cdevsw's
  d_read, one whole record through vfs.mod's uiomove, as _PtyM_DRead is.
  
  With the kernel network stack attached, socket 0 is the stack's.  bpf_open finds
  VT_BSDNET and reads a ring of 8 records that net/if_w5.c fills from both w5rint and
  w5start, instead of claiming the socket.  A full ring counts into BPF_Sat, so
  netdump's "[saturated N]" keeps its meaning, and with no stack, or a stack with no
  driver, capture is direct as before.  The ring is in the network modules' data, so
  a boot without them pays 2 bytes of heap.

- netprobe: the wire samples see what the same netintr entry did
  The samples ran in np_hook, before ipintr, so an answer that arrived in this entry
  waited for the next one and every round trip read one poll period.  np_tail runs
  after the loop.  The probe also reports how long the burst took to drain.

- net: a torn read of the receive count does not cost the ring
  The chip updates Sn_RX_RSR as frames land.  Two byte reads across a change to the
  high byte come back 256 short, the head frame's length then exceeds the count, and
  the socket was reopened with every queued frame lost.  w5rint now reads until two
  reads agree, as WIZnet's reference drivers do.

- net_stack_depth: the socket calls a process makes, measured
  The calls run on the caller's 1024-byte kernel slot, which cannot switch
  stacks because sbwait sleeps on it.  A UDP sendto walks to 766 bytes,
  about 890 with the entry and an interrupt frame; sendit's 16-entry iovec
  array is 300 of them.  TCP's worst sendto is 826 and is recorded for S4.
  The walk now uses the W5100 driver's real frames in place of a guess.

- libc: the socket errnos 2.11BSD's network stack answers
  EINPROGRESS, EALREADY, EPROTONOSUPPORT, ESOCKTNOSUPPORT, EPFNOSUPPORT,
  ENETDOWN, ENETUNREACH, ENETRESET, ECONNABORTED, ESHUTDOWN, ETOOMANYREFS,
  EHOSTDOWN and EHOSTUNREACH, with 2.11BSD's numbers (usr/sys/h/errno.h)
  and syserrlst's messages in 4.3BSD-Reno's wording (sys/errno.h), which is
  the same for all thirteen.  strerror(ENETUNREACH) answered "Unknown
  error: 51"; M11/lc_errno now checks it.

- bsdnet: a process inside the stack -- sleep, signals, setjmp, errno
  sleep() is 2.11BSD's (sys/kern_synch.c): a signal that breaks a sleep
  above PZERO leaves EINTR in u_error and longjmps to u.u_qsave, where
  uipc_syscalls.c's setjmp arms catch it; an ordinary wakeup leaves 0.  u is
  one global, so the caller's copy is kept across the sleep in a slot of its
  own, by pid, sized from kernel.nproc: sleep is at the bottom of the deepest
  socket call and its stack has no room for a copy.  u_ofile moves to the
  end so the copy stops short of it.
  
  setjmp and longjmp are the kernel's, after pdp/mch_xxx.s, in libc's layout
  less the signal mask: S, D, DBR, the return address, fcc's frame cells and
  its callee-saved band.  Probe case 51 longjmps out of a recursion and reads
  a local by an address taken afresh, which goes wrong if _fcc_fb is not
  restored.
  
  suser() sets EPERM as sys/sys_net.c's does, and the stack's EWOULDBLOCK is
  EAGAIN, userland's one would-block errno; case 52 fails the build if they
  differ.

- bsdnet: sogetnam and sogetpeer pass pr_usrreq real null pointers
  Both call through so_proto->pr_usrreq, which has no prototype, with bare
  0s for its unused mbuf arguments.  K&R A.7.3.2: "The effect of the call
  is undefined if the number of arguments disagrees with the number of
  parameters in the definition of the function, or if the type of an
  argument after promotion disagrees with that of the corresponding
  parameter."  A 0 is an int, which on the PDP-11 is a pointer's size and
  here is half of one, so udp_usrreq read its arguments shifted and freed a
  stray mbuf: getsockname(2) on a kernel socket panicked mfree.  They are
  (struct mbuf *)0 now; no other call through a function pointer in the
  port passes a bare 0.

- bsdnet: a process's socket call, into uipc_syscalls.c's bodies
  bn_sysent is net.mod's way in: a far pointer in bsdnetd's bn_sys cell,
  called with a block naming the syscall's registers on the caller's
  kernel stack.  It runs kernel C's register page and the data bank, and
  bn_sys.c turns FGX's libc argument blocks into the struct a each body of
  2.11BSD's uipc_syscalls.c reads through u.u_ap: bind, connect, sendto,
  recvfrom, send, recv, setsockopt, getsockname, getpeername, shutdown.
  read and write are sys_generic.c's sorw, select is sys_socket.c's
  soo_select, which arms sb_sel so a datagram wakes the selector, and
  close is soclose.  pdp/trap.c's syscall() is the model for the entry:
  one setjmp, through which a sleep a signal breaks returns its EINTR.
  
  The descriptor stays net.mod's, so getf() answers one static file
  standing for it and falloc and ufalloc are panics nothing reaches:
  socket creation calls socreate directly.  copyin, copyout, uiomove
  (sys/kern_subr.c) and netcopyout (pdp/net_copy.s) copy through far
  pointers.  selwakeup wakes FGX's one select channel, and sosend's
  SIGPIPE is posted to the calling process.  MSG_DONTWAIT, which FGX's
  <sys/socket.h> has and 2.11BSD does not, is SS_NBIO for the call.
  
  sys_socket.c is vendored verbatim; uipc_syscalls.c now links, in
  bsdnet3 with the rest of this.

- net: a UDP socket is the kernel's when the network modules are loaded
  socket(AF_INET, SOCK_DGRAM) with bsdnetd registered takes a descriptor
  tagged XPORT_KSO, owning no chip socket, and asks the network modules
  for a struct socket, whose offset the record keeps over SOCK_FAddr.
  Every op on such a descriptor -- bind, connect, sendto, recvfrom, send,
  recv, setsockopt, getsockname, getpeername, read, write, shutdown,
  select's status and FIONREAD, the SIOCGIF ioctls and close -- goes to
  net_kso.s first, ahead of the AF_UNIX and loopback arms, and from there
  to the kernel's stack; listen and accept answer EOPNOTSUPP and EINVAL as
  udp_usrreq and accept would.  Without the modules nothing changes.
  
  loopprobe -u runs the cases over lo0 and netudp runs it.  FIONREAD on a
  datagram socket counts the sender's address as 2.11BSD's sbappendaddr
  does, so seven bytes read as 23.

- fcc: a struct argument written `*p' is the whole struct
  K&R A.7.4.3: "If the type of the expression is ``pointer to T,'' the type
  of the result is T."  A.7.3.2: "In preparing for the call to a function,
  a copy is made of each argument; all argument-passing is strictly by
  value."  fcc types a dereference for a scalar read, so with p a struct
  pointer, f(*p) pushed the struct's first word and the callee read the
  rest of its parameter from the caller's stack.  It did so through an
  old-style declaration and through a prototype alike.  2.11BSD's
  if_ether.c arpresolve calls in_broadcast(*destip); in_broadcast saw half
  of 255.255.255.255, and every broadcast became an ARP request for it.
  
  A `*p' argument whose pointee is a struct is now walked as the pointer
  and copied as any struct argument is.  Fixture M46/struct_arg_deref: a
  parameter, a register parameter, a global pointer, *(w + 1), a 6-byte
  struct, and a prototype; it returned 63 before.  Goldens 777/777.

- fcc: a store through an element of an array of struct pointers
  `ms[k]->m_len = x' died "expected '='" while `return (ms[k]->len)' compiled.
  K&R A.7.3.1: "A postfix expression followed by an expression in square
  brackets is a postfix expression"; A.7.3.3 makes that followed by an
  arrow and an identifier a postfix expression too, and A.7.17 asks of the
  left operand only that it be a modifiable lvalue.  The statement layer
  had no store arm for an index followed by an arrow.  It now routes the
  shape to the lvalue walker, gated on the base being an array of struct
  pointers, so no shape that already had an arm moves: =, op= and ++ all
  reach it.
  
  Fixture M46/store_index_arrow: local and global arrays, a long member and
  a computed index.  Goldens 778/778.

- bsdnet: a checksum's overlay is cleared whole
  udp_input, udp_output, tcp_input, tcp_template and tcp_respond zero the
  IP overlay's two queue pointers (ih_next, ih_prev) before in_cksum sums
  the header as bytes.  A pointer fcc stores is its offset and its bank;
  the fourth byte is the pad and is left as it was.  On a received datagram
  that byte still held the high byte of ip_len, so every UDP datagram
  longer than 255 bytes failed its checksum -- a DHCP OFFER among them --
  and passed on lo0 only while small.  IH_CLRQ (ip_var.h) clears the eight
  bytes with bzero on fgx and keeps upstream's assignment elsewhere.

- libc: the resolver waits for its answer with select
  _dns_resolve polled recvfrom 90 times a try for an EAGAIN, which a
  datagram socket's receive does not give: it waits for a datagram, as
  2.11BSD's soreceive does, so a lookup whose nameserver never answered
  waited for ever.  Each try now waits 1.5 s in select and reads only when
  something has arrived.  recvfrom was also passed its fromlen as the
  integer 16 where it takes a pointer and writes back through it.
  
  ntpd's test stages a resolv.conf naming a nameserver no route reaches, so
  its lookups really query: with none the resolver returned before
  recvfrom and the old one passed too.

- net: the network modules at every boot, an address, and routes
  /etc/rc loads bsdnetd and bsdnet0-3 after net and before /etc/netstart,
  so dhclient's socket is the kernel's, as every UDP socket now is; a
  machine with no card still has lo0.
  
  With no address in the chip, w5 takes 0.0.0.0, as early BOOTP clients
  were configured: in_ifinit routes network 0 to the interface, and
  in_netof(255.255.255.255) is 0, so a DISCOVER to the broadcast address
  leaves through w5 from 0.0.0.0 and the server's broadcast reply is ours
  in ip_input.  dhclient asks for that broadcast reply.  A host route for
  255.255.255.255 to the interface keeps a later DISCOVER off the default
  route once there is an address.  The default route goes through the
  chip's gateway register.  rtrequest deletes a route only when its gateway
  matches, so the driver keeps the gateway and address it routed by and
  deletes those first.  Inbound ARP is dropped while the address is 0.0.0.0:
  in_arpinput would take every RFC 5227 probe for a duplicate of it.
  
  SYS_IFCONFIG's set writes the chip as before and then tells the stack,
  which reads the address back from the chip (BNOP_IFCHANGED), past
  in_control's suser check, since the chip already has it.
  
  dhclient waits for a reply with select and what is left of its timeout,
  since a receive now waits for a datagram.
  
  Probe cases 54 and 55, on the card in netw5: an address off the net goes
  through the gateway, the broadcast address through the host route, and a
  new gateway replaces the default route.  netw5 stages rc.netlate, rc.in
  without the network modules, so they load after DHCP as its wire cases
  need.  Cases 57 and 58 check in_cksum over chains against a flat sum.

- loopprobe, unixprobe: their UDP sockets are the kernel stack's
  unixprobe's idle-socket check makes the socket non-blocking first, since
  a datagram socket's recvfrom waits for a datagram as soreceive's does,
  and a send with no card answers ENETUNREACH: lo0 is always there, so
  in_pcbconnect picks it and ip_output reports the missing route.
  loopprobe's setsockopt checks get 2.11BSD's answers: SO_LINGER with an
  int is EINVAL (sosetopt wants a struct linger), and a level other than
  SOL_SOCKET on a UDP socket is EINVAL from ip_ctloutput.  loopprobe -u
  gains a 300-byte datagram, more than one mbuf holds.

- bsdnet: ifioctl passes pr_usrreq its command as a pointer
  ifioctl's default arm hands an interface ioctl the socket's protocol
  does not know to pr_usrreq as (so, PRU_CONTROL, cmd, data, ifp), with
  cmd an int.  pr_usrreq has no prototype, and K&R A.7.3.2: "the effect
  of the call is undefined if ... the type of an argument after promotion
  disagrees with that of the corresponding parameter."  udp_usrreq and
  in_control read three mbuf pointers; the int is half of one here, so
  data and ifp arrived shifted and SIOCGIFADDR answered EADDRNOTAVAIL for
  every interface.  The command goes as (struct mbuf *)cmd, as
  sys_socket.c's soo_ioctl already passes it.
  
  ifcprobe expects lo0's flags as 2.11BSD's if_loop.c leaves them, UP and
  LOOPBACK: loattach never sets IFF_RUNNING.

- loopprobe, ntpd: datagrams across processes, signals and daemons
  loopprobe -u adds four cases on the kernel's UDP:
    eintr  a receive a SIGALRM interrupts answers EINTR, the handler has
           run, and the socket still works;
    two    a child sleeps in recv while the parent's connected send draws
           ECONNREFUSED from the port unreachable; then the child gets its
           own datagram and its own errno;
    fork   a socket shared across fork survives the child's close;
    size   a 200-byte datagram read with 50 bytes gives 50 and drops the
           rest, and a send over the send buffer's limit is EMSGSIZE.
  loopprobe -s sends a syslog record to 127.0.0.1:514, and netudp runs it
  against syslogd -u and expects the record on the console.
  
  ntpd's test stages an ntp.conf with a numeric peer, 127.0.0.2, beside a
  named server the resolver cannot reach, and ntpdc asks ntpd for its
  peer table over lo0 and prints the peer.  ntpd sends no reply at all
  when it has no peers.

- bsdnet: the W5100 interface is wz0
  The ifnet was named "w5".  2.11BSD's ifunit (net/if.c) takes the first
  digit of a name as its unit, so the "w50" SIOCGIFCONF reports parsed as
  interface "w", unit 5, matched nothing, and SIOCGIFFLAGS answered ENXIO:
  ntpd logged "get interface flags: Device not configured" on every boot
  with a card.  "wz" carries no digit, as 2.11BSD's own drivers' names
  (il, qe, de) do not.

- netprobe: the wire cases wait for the lease; the tests load at boot
  With the network modules loading at boot, the probe reached its wire
  cases before dhclient had put a gateway in the chip and echoed to
  0.0.0.0.  The wire start now waits in state 13 until GAR is set, and
  runs the route cases (54, 55) again there, since at init there is no
  gateway to route through.
  
  The tests written when the modules were loaded by hand:
    netw5, netnoreply  boot the release rc and read what the boot loaded;
                       netw5 also checks ntpd finds its interfaces
    netprobe           reads the boot's log
    netbusy, netstkovf,
    netsleep           stage the release rc less the network modules, so
                       the command's modload is still the trigger
    netdumptap         the same, and its workload takes a lease under
                       netdump so the probe's ARP and echo are watched
    netftp             runs on the standard image; with the probe its
                       name lookup could fall in the probe's undrained
                       burst

- net: UDP is the kernel stack's alone
  A datagram socket no longer opens one of the W5100's sockets.  The chip's
  UDP transport is gone: _Udp_OpenAt, _Udp_SendCore, _Udp_RecvCore,
  _Udp_PortShare and _Udp_Connect, the XPORT_UDP arms of the transport
  seams, _So_Send's peer handling, getpeername's datagram arm, and
  _So_UdpPeer, _So_UdpPeerLoad, _So_UdpFrom and _Sock_HwShared.  Without
  the network modules socket(AF_INET, SOCK_DGRAM) answers EPROTONOSUPPORT,
  which is 2.11BSD's socreate (sys/uipc_socket.c) when no protosw matches.
  
  SO_REUSEADDR is accepted and no longer stored: its only reader was the
  chip's port sharing.  The boot init no longer writes socket 0 as a UDP
  socket to 255.255.255.255:67, which it never opened.
  
  ifconfig's options line, ifconfig(8), networking.md and modules.md say
  UDP is the kernel stack's.  loopprobe -n opens one UDP socket, and
  netudp_nomod runs it without the modules.

- bsdnet: the transmitter sends queued frames back to back
  w5start ended its pass when the chip was still sending the previous
  frame, and the next one waited for a later netintr entry.  It now polls
  the free count up to 130 times, 3 ms at the 23 us a read measures, over
  the 1.2 ms a full frame takes on a 10 Mb wire, and only past that leaves
  the rest for the next pass.
  
  Probe case 56 queues five full 1066-byte echo requests to the gateway
  with the transmitter held, releases them and counts all five out in one
  w5start.  MAME's uthernet2 reports the ring free as soon as SEND is
  issued, so there the case passes with no wait at all; it discriminates
  only on hardware.

- mame_test: Uthernet II tests run alone
  Every emulated Uthernet II has the same MAC, 00:08:dc:f6:00:01, so two
  card tests run in parallel lease the same address from the LAN's DHCP
  server and take each other's frames: the kernel stack logs a duplicate
  IP address, and DNS replies go to the other machine.  A manifest whose
  mame_slots name uthernet2 now joins the serial tail, after the parallel
  batch drains, as timing tests and save-state users do.

- net: a kernel socket forward keeps its caller's descriptor
  _Kso_Do and _Kso_DoIoctl hand a socket call to the kernel's stack, which
  may sleep: socreate's m_getclr(M_WAIT) waits on mfree when mbufs run
  out.  Another process's call meanwhile rewrites the shared
  _sockTmpOff, and socket(2) read it after the forward to store the new
  struct socket and to fill the FCB, so it could write into another
  process's descriptor and leave its own record without a socket.  Both
  forwards now keep the caller's _sockTmpOff on the stack and put it back
  before returning, which covers socket(2) and close(2)'s free of the
  descriptor after soclose.

- bsdnet: a socket call has its slot's stack floor
  fcc's stack guard compares S against _fcc_stkfloor on the kernel-C
  page, which is 0 for a process's kernel calls, so a socket call that
  ran off its kernel slot wrote into the slot below.  bn_sysent now sets
  the floor to the running task's slot base (_kCurKStkBase, exported to
  the network modules) plus FCC_STK_FLOOR_MARGIN, and restores the
  page's floor at return; swtch already saves the band holding it per
  task.
  
  kernel.netprobe = 5 makes the first socket call recurse, and
  netkstkovf asserts it halts through _fcc_stkoflow with the floor of
  the slot it ran on.

- bsdnet: sendit takes its name and rights in mbufs
  2.11BSD's sendit builds the destination name and the access rights in
  two MSIZE buffers on the kernel stack, 256 bytes of a 300-byte frame.
  On a process's 1024-byte kernel slot that left TCP's deepest sendto 28
  bytes short of the 128-byte margin.  sendit now gets them through
  sockargs, from 4.3BSD-Reno's kern/uipc_syscalls.c (m_get(M_WAIT, type),
  EINVAL past MLEN), less Reno's COMPAT_43 arm and its sa_len store, and
  frees both on every return, including the interrupted one.
  
  net_stack_depth.py --check walks bn_sys, adds 60 bytes of entry and 64
  of interrupt frame, and fails under 128 spare: 996 of 1024 before,
  854 after.  socreate, sogetnam and sogetpeer join the indirect-call
  table as pr_usrreq callers.

- fs: _Fcb_Alloc returns in its caller's mode
  Its header said it returned with M=1 and X=0 and no PLP, and a caller
  in net_loop.s repeated it.  Every exit is a PLP, so the caller's M and
  X come back; code written to the header ran its 8-bit stores as 16-bit
  instructions.  The header and the caller's comment say so now.

- net: a datagram socket's FCB names its struct socket
  A UDP socket on the kernel stack took one of net.mod's twelve socket
  descriptors only to hold the struct socket's address.  The FCB now
  holds it, in FCB_SockSo (FstPriv+0, two bytes), as 2.11BSD's f_data
  holds a socket; FCB_SockIdx moves to FstPriv+2 for the transports that
  still use the table.  socket(2) makes the struct socket, then the FCB
  (_Kso_Socket), and closes it again if the process has no descriptor
  left.  _Sock_FdToDesc leaves the fd's socket in _sockTmpSo, which
  read, write, select, close and every socket call test first, so these
  sockets are as many as memory holds.
  
  Every ioctl on such a socket goes to soo_ioctl (sys/sys_socket.c):
  FIONBIO sets SS_NBIO on the socket, FIONREAD stores so_rcv.sb_cc as
  the int FGX's ioctl takes where 2.11BSD's is a long, SIOCATMARK
  reads SS_RCVATMARK, and FIOASYNC and the process-group ioctls answer
  ENOTTY as the kernel did.  The descriptor's SOCK_NB no longer reaches
  the stack.
  
  loopprobe -u case many opens twenty UDP sockets in one process and
  reads a datagram from each; it failed at the ninth before, on EMFILE
  from the full table.  The core bank has 0 bytes free after this.

- libc: listen passes its backlog, accept names the peer
  listen(2) took only the descriptor and sent the kernel a backlog of 0,
  and accept(2) took only the listener and never filled in the peer's
  address, though <sys/socket.h> declares both with 2.11BSD's arguments.
  listen now passes the backlog in X, which 2.11BSD's solisten sizes
  so_qlimit from.  accept asks the new socket's getpeername for the name
  when the caller passes one, and cuts it to *addrlen as 2.11BSD's
  accept() does.
  
  <sys/socket.h> gains SO_LINGER and struct linger, from 2.11BSD's
  sys/socket.h.

- bsdnet: listen and accept on the kernel stack
  BNOP_LISTEN runs 2.11BSD's listen() (sys/uipc_syscalls.c) with the
  caller's backlog.  BNOP_ACCEPT runs accept() whole: soacc1's wait,
  the descriptor, soqremque and soaccept.  net.mod has taken the FCB
  before the call, as accept() takes its descriptor before the dequeue,
  so falloc and ufalloc hand accept() a static struct file and the new
  socket comes back from its f_socket; an accept that fails after the
  dequeue closes the socket.  The name is left to the caller's libc.

- net: TCP sockets are the kernel stack's
  With the network modules loaded, socket(AF_INET, SOCK_STREAM) makes a
  2.11BSD struct socket that its FCB names, like a UDP one, so TCP
  connections are as many as memory holds.  listen(2) forwards with the
  backlog.  accept(2) on a kernel socket takes the new FCB first, then
  waits and dequeues on the stack, then names the socket in the FCB;
  an accept with no descriptor left answers EMFILE and leaves the
  connection queued, and an accept the stack refuses gives the FCB back.
  Every shutdown(2) how goes to net.mod now, so a kernel socket's
  SHUT_RD reaches soshutdown; for the chip's sockets net.mod answers it
  as the kernel did.
  
  loopprobe -t runs TCP cases over lo0: 10 KB each way, a non-blocking
  connect, a refused connect, data written and closed at once, a reset
  from SO_LINGER 0 with ECONNRESET, EPIPE and SIGPIPE, a listener
  shared across fork, MSG_OOB, and the names of both ends (nettcp).
  loopprobe -m holds 16 connections open at once and moves 1 KB each
  way on each (tcpmany): it stopped at the second before, on the
  loopback rings' one pending connection.  Plain loopprobe's listener
  sets SO_REUSEADDR, since a run right after another meets TIME_WAIT;
  its MSG_OOB refusal checks go with the rings that refused, and a
  connect on a listener expects soconnect's EOPNOTSUPP.

- telnet: urgent data as 2.11BSD sends it
  TCP carries urgent data now, so telnet's send(MSG_OOB) and its
  SIOCATMARK recv are 2.11BSD's again (usr/ucb/telnet.c): the in-band
  fallback on EOPNOTSUPP and its PROVENANCE note go.

- bsdnet: a pool for sixteen connections
  An idle TCP connection holds 8 mbufs, 4 at each end (socket, inpcb,
  tcpcb and header template), and a listener 3, so 16 connections and
  their listener hold 131 of the 170 2.11BSD's PDP-11 pool gave.
  NMBUFS is 280 under fgx, where the pool lives in the network modules'
  data bank rather than a mapped window; bsdnetd's data now runs to
  $E5C2 of its bank.
  
  loopprobe -m adds two cases after the 16 connections.  backlog makes 8
  connects against a backlog of 2 with nobody accepting, and all 8 are
  accepted within 30 seconds, sonewconn having dropped the SYNs past
  3 * so_qlimit / 2 for the clients to retransmit.  exhaust opens TCP
  sockets in five children until something runs out, then closes them
  all, twice: the second round must make as many as the first.  The
  system file table runs out first (NFILE 64, ENFILE at 39); with the
  pool halved for a control, ENOBUFS comes at 26 in both rounds, and a
  socket(2) that finds the pool empty waits in socreate until a close
  frees one, as 2.11BSD's does.  The parent's accepts time out, so a
  child that stops cannot hang the test.

- libc: bind, connect and sendto pass the name's length
  bind(2) and connect(2) dropped their addrlen and the kernel took 16
  bytes, a sockaddr_in, so an AF_UNIX path longer than 13 characters was
  cut and bound a different name.  Both pass addrlen in Y, which the
  call left unused.  sendto(2) packed only an IPv4 address and port;
  its block now carries the sockaddr's own offset, bank and length too
  (words 7-9), so a path can be named per datagram.

- vfs: an AF_UNIX name records its socket
  unp_nameop's v_un carried net.mod's descriptor slot plus one, and the
  vnode a bound socket holds was kept in a 12-entry table indexed by that
  slot.  The caller is now 2.11BSD's uipc_usrreq.c in the network
  modules, so v_un carries the socket itself, its offset in their data
  bank, and the table pairs socket and vnode, NFILE entries, a bound
  socket being an open file.  A bind takes its entry before the walk,
  which sleeps, and gives it back on any failure; an unbind finds it by
  socket.  4.3BSD-Reno's unp_bind and unp_connect, which the function
  carries, are otherwise unchanged.
  
  KSVC_UNPNAME takes the path's bank in Y rather than assuming the
  syscall caller's, since the name now comes from the network modules'
  mbuf or stack.

- bsdnet: AF_UNIX on uipc_usrreq.c
  The unix domain joins domaininit and uipc_usrreq.c and uipc_proto.c
  link, in bsdnet0.  The file-system half is 2.11BSD's supervisor-to-
  kernel calls (sys/sys_kern.c): unpbind, unpconn and unpdet go to the
  kernel's unp_nameop through kc_unpname and KSVC_UNPNAME, with
  unp_inode holding the socket as the mark that it is bound, and iput
  has nothing to release.
  
  Access rights answer EOPNOTSUPP: PRU_SEND refuses a message carrying
  them, and unp_externalize, unp_dispose and unp_gc have nothing to do,
  because upstream passes struct file pointers and an FGX descriptor is
  an FCB these modules cannot name.
  
  bind and connect take libc's name length, or the family's whole
  sockaddr for a binary that passes none, and sendto the caller's own
  sockaddr, so an AF_UNIX path reaches unp_bind and unp_connect whole.

- net: AF_UNIX sockets are the kernel stack's
  socket(AF_UNIX, ...) makes a 2.11BSD struct socket that its FCB names,
  datagram or stream; without the network modules there is no AF_UNIX,
  EPROTONOSUPPORT.  net.mod's unp.s is no longer reached.
  
  unixprobe -s runs the stream type and the names: a pair moving 8 KB
  each way to end of file, ECONNREFUSED from a bound socket that does
  not listen and from a closed socket's name, EADDRINUSE on a second
  bind, and 20 datagram sockets bound at once.  unixprobe's positive
  control asks for SOCK_RAW, EPROTONOSUPPORT, now that SOCK_STREAM
  exists, and a sendto naming a path on a connected socket expects
  uipc_usrreq.c's EISCONN.  unix(4) describes the family as it is.

- net: raw sockets and ping on the kernel stack
  socket(AF_INET, SOCK_RAW, ...) makes a 2.11BSD struct socket on
  raw_ip.c, so ping goes through the kernel's ICMP like everything else;
  without the network modules there is no raw socket,
  EPROTONOSUPPORT.  The chip's IPRAW socket is no longer reached.
  
  A raw socket hands up the whole IP datagram (rip_input), and its
  recvfrom blocks, so ping reads its reply past the IP header, ip_hl
  words in, prints the TTL from it, and waits for a reply in select for
  up to a second.  Every ICMP message the host receives arrives on the
  socket, ping's own echo request among them when it pings 127.0.0.1,
  so only an echo reply with its id and seq counts, as before.  A raw
  socket is root's (raw_usrreq.c, SS_PRIV), so ping is installed setuid
  root, as 2.11BSD's Makefile installs it (usr/bin/ping/Makefile:30).
  
  pingloop pings 127.0.0.1 three times over lo0; it timed out three
  times before.

- libc: the resolver's nameserver address names its family
  _dns_resolve built the nameserver's sockaddr_in with AF_INET in byte 1.
  sin_family is a short, stored low byte first, so the family read as
  0x0200 and the kernel stack's in_pcbconnect refused the address: every
  name lookup failed and ftp(1) answered "Unknown host".  The chip's UDP
  core read only the port and address, which is why it never showed.
  
  AF_INET now goes in byte 0.

- inetd: a listener is bound once and accepts forever
  Every TCP socket is the kernel stack's, where accept(2) leaves the
  listener listening, as 2.11BSD's does.  inetd's main loop goes back to
  upstream's: no re-arm after each accept, and no budget of three wire
  listeners, which was the W5100's socket count.  A service that cannot
  be bound is still carried as down and retried every RETRY_SECS.
  
  ROADMAP's "who re-arms a TCP listener" item is answered by this and
  removed.

- ifconfig: no offload options line
  The W5100 no longer carries IP, ARP, TCP or ICMP: its socket 0 is a
  MACRAW frame pipe under the kernel stack, so the options=<TCP4,...> line
  described hardware nobody uses.  The interface shows name and flags,
  then ether and inet, as BSD's does.

- net: the chip transports and the socket table retire
  Every socket is a 2.11BSD struct socket on the kernel stack, reached
  from its FCB through FCB_SockSo.  What the stack replaced goes:
  
  - net.mod's socket-descriptor table and its twelve-entry cap
    (SOCKD_MAX, FCB_SockIdx, the core's table allocation);
  - the W5100's TCP and IPRAW cores and their socket allocator
    (net_xport.s, the hardware-socket half of net.s);
  - the loopback rings (net_loop.s) and the AF_UNIX rings (unp.s), in
    net.mod and their core-bank halves;
  - the core's per-call socket scratch, the select and ioctl paths that
    read it, and close's table teardown.
  
  net.mod's ops now forward to the stack or answer EBADF; the pipe
  shims it still needs are net_kcall.s.  net.mod is 2,838 bytes, and
  the core bank has 525 bytes free where it had none.
  
  The chip's socket 0 keeps the whole of its buffer memory: RMSR and
  TMSR are $03, 8 KB each way, the MACRAW ring is 8 KB in if_w5.c and
  bpf, and the attach line reports the receive size it reads from the
  chip ("rx 8192").
  
  uipc_usrreq.c and uipc_proto.c move to bsdnet bank 2: bank 0 overflows
  at kernel.netprobe 1.
  
  tools/check_net_retired.py fails the build if a definition of any
  retired name comes back.  check_sock_argblk.py holds libc's argument
  block against bn_sys.c, the one remaining reader.  The sleep-safety
  checker's block-save case is the pipe scratch, the live block.

- loopprobe: a bulk mode, and comments for the kernel stack
  -b sends 1 MB over lo0 from a child writer to a reader that counts
  it, prints "BULK <bytes>", and exits 0 only if every byte arrived; run
  under time(1) it gives a loopback transfer's rate.
  
  The comments that explained each case by the loopback rings, the
  W5100's slots and the descriptor table now say what the case asserts
  on the kernel stack.  No assertion changes.

- net: the stack's bcopy is 2.11BSD's, in assembly
  bcopy was a C byte loop in net_kern.c.  It is now 65816 assembly in
  net_asm.s, after 2.11BSD's libc pdp/gen/bcopy.s, which is vendored with
  this change: the length is unsigned, and an overlapping move is handled,
  copied backward when the destination is above the source.  MVN moves
  forward and MVP backward, seven cycles a byte; the bank operands are
  patched in place, as uio_copy.s does in the VFS bank.  The C loop only
  ever copied forward, so a move to a higher address in the same buffer
  overwrote its own source.
  
  A 1 MB TCP transfer over lo0 under MAME takes 28.6 s, from 41.0 s.
  
  netprobe case 7 checks bcopy across banks and overlapping either way.
  netprobe.json reads the network lines with grep: more modules load after
  the stack than when it was written, and tail -10 no longer reaches them.

- kernel: an exec laid over its own stack keeps its new home
  A task whose new stack range lands on other tasks' ranges is given a
  home, and so is every task under it (_Uimg_Overlap, then _Uimg_Walk at
  UI_COMMIT or UI_DEFER).  At pass 3, in exec, the new range may also lie
  on the placer's own old range, and the walk gave that a home too.  A
  pid has one home, so Uimg_HomeAlloc replaced the new range's home with
  one for the old range, and Task_FreeStack freed it with the old range.
  The task then ran on a shared range with no home, and the next park or
  restore halted with "uimg: no home for pid N".  login exec'ing the
  shell after a telnet login took this path.
  
  The commit walk now passes over the placer: its old range is freed when
  exec finishes and never needs a home.  2.11BSD has no counterpart; the
  homes are FGX's bank-0 stack overlay.

- ROADMAP: point at #48, the unseeded HEAP_LIM cell
- forkpair: lim takes the HEAP_LIM seed a dynamic program starts with
  forkpair lim required the HEAP_LIM cell to read $FFF8 at start and in an
  exec'd copy.  That is the loader's seed, and it holds only for a static
  program: the shared-library binder lowers the cell to the lowest library
  core (toolchain/lib/libc_c/ld_bind.c), and libc_init lowers it again to
  its blocks.  forkpair is dynamic, so it started at $F523 and the mode
  failed on every image since.
  
  The mode now takes the value it starts with as its seed: at most $FFF8
  and not below the break.  The exec'd copy is given that value and must
  start with it, rather than with the $E000 its parent left in the cell.

- net: interface and route ioctls reach the stack, and an interface has a link address
  An ioctl on a socket that bn_sys.c does not answer itself now goes to
  2.11BSD's soo_ioctl (sys/sys_socket.c), whose tail sends an 'i' command
  to ifioctl, an 'r' command to rtioctl, and the rest to the protocol's
  PRU_CONTROL.  SIOCADDRT and SIOCDELRT were answered by ifioctl as an
  interface name before, ENXIO.
  
  SIOCGIFCONF returns, after an interface's addresses, its link-level
  address, as 4.3BSD-Reno's ifconf does (net/if.c, net/if_dl.h, vendored):
  an AF_LINK sockaddr_dl with the interface's place in the list, its
  type, and for an ethernet its arpcom's address.  2.11BSD's sockaddr is a
  fixed 16 bytes with a u_short family, so the fields from sdl_index on
  are Reno's and the name, which ifr_name carries, is left out.
  
  Userland gains the setter ioctls (low 16 bits, as the getters),
  <net/route.h> with struct rtentry, <net/if_dl.h>, and AF_LINK.
  ifcprobe -l checks the route ioctls and the link address on lo0.

- libc: inet_makeaddr, inet_network and getnetbyname
  2.11BSD's usr/lib/libc/inet/inet_maddr.c and inet_network.c and
  net/getnent.c and getnbyname.c, verbatim and vendored, with their
  declarations: struct netent in <netdb.h>, the two inet functions in
  <arpa/inet.h>, and the address-class macros of 2.11BSD's netinet/in.h
  (IN_CLASSA_NET and the rest) in <netinet/in.h>.  ifconfig(8) reads a
  host or network name through them.
  
  Fixture M11/lc_inetnet: inet_makeaddr in each class, inet_network on
  dotted, hex and junk input.  It did not compile before (no declaration
  of inet_makeaddr).  The oracle gains its 42; the rest of oracle.json is
  re-sorted, unchanged.

- ifconfig: 2.11BSD's, on the kernel stack's interfaces
  ifconfig is 2.11BSD's usr/sbin/ifconfig/ifconfig.c (4.20.1): one
  interface, its flags, metric, inet address, netmask, broadcast and
  destination through the SIOCGIF* and SIOCSIF* socket ioctls.  The FGX
  ifconfig it replaces read and set net.mod's interface table through
  SYS_IFCONFIG and listed every interface when given none; upstream takes
  exactly one.
  
  Its deltas: XNS is compiled out, the kernel having no NS family;
  NEXTARG takes the pdp11 value; the netmask prints with %lX, libc's
  printf being 4.3BSD-Reno's, where %X is an int and 2.11BSD's is a long;
  and a status line shows the interface's link-level address as an ether
  line, from the AF_LINK entry SIOCGIFCONF returns.
  
  ifconfig(8) is upstream's page with a BUGS section for those, and for
  what 2.11BSD itself does: an interface marked down still carries what
  the routing table sends it, as neither ip_output nor the loopback driver
  tests IFF_UP.

- libc: nlist, after 2.11BSD
  nlist(3) is 2.11BSD's usr/lib/libc/gen/nlist.c, with the a.out offset
  routines of pdp/gen/nsym.c beside it, both verbatim and vendored.  It
  reads a 2.11BSD name list: <sys/exec.h> is upstream's a.out header and
  <nlist.h> upstream's struct nlist.  a.out.h's N_BADMAG, N_TXTOFF,
  N_SYMOFF and N_STROFF sit in nsym.c rather than <a.out.h>, which
  describes FGX's own executables.
  
  <nlist.h> drops n_filler, which pads a two-byte pointer out to the
  union's four bytes; a pointer is four bytes here already, so a program's
  struct nlist and the one nlist reads agree without it.

- kernel: /dev/mem and /dev/kmem, and the stack's name list in /netnix
  /dev/mem and /dev/kmem are 2.11BSD's mmrw minors 0 and 1
  (usr/sys/pdp/mem.c, vendored), in a module, mem.mod, loaded at boot.
  The 65816 has no MMU, so both are upstream's kmem arm,
  uiomove((caddr_t)uio->uio_offset, c, uio), through vfs.mod's uiomove: the
  file offset is the 24-bit address.  The I/O window, $C000-$CFFF of banks
  $00, $01, $E0 and $E1, answers EFAULT, since a read there switches the
  machine's state, and a move stops short of it and of a bank's end.  The
  nodes are character devices 23 and 24, 0640 root:kmem as upstream
  installs them; CHARDEV_MAX goes from 24 to 32 to hold them.  mem(4) is
  upstream's page with the FGX notes.
  
  route(8)'s flushroutes finds the stack's tables with nlist("/netnix")
  and reads `netdata' from /unix for where the network's data is.  On FGX
  the stack's data is one bank, loaded where the boot puts it, so the
  build writes /netnix as a name list only (tools/mknetnix.py): a 2.11BSD
  a.out header and one symbol per label of bsdnetd's data image, each
  value its offset in that bank.  sysctl kern.netdata (KERN_NETDATA 25)
  answers the bank as an address, found through the module registry
  (Mod_FindVtable, VT_BSDNET), 0 with no stack loaded; read-only.
  
  kmemprobe reads the stack's rthashsize through all three, is refused the
  I/O window, writes and reads back a byte of its own through /dev/mem,
  and as uid 1 is refused /dev/kmem.

- klogprobe: the module-bank refusal reads `cannot place'
  The probe makes a fresh kernel log line by loading pty a second time and
  looks for the refusal in what /dev/klog delivers.  The kernel's message
  is `pty: cannot place' since 59684ff took ` in the module bank' off it to
  make room in the core bank; the probe still looked for the longer text,
  so its "fresh kernel line was delivered" case failed on every run since.

- fcc: an element of a braced struct-array initializer may elide its braces
  2.11BSD route(8)'s name list ends `{ "_rthashsize" }, "", };' and fcc
  died "expected '{' for struct-array element": it decided braced or flat
  once for the whole list, from the first element.  K&R A.8.7: "If the
  initializer for a subaggregate does not begin with a left brace, then
  only enough elements from the list are taken into account for the
  members of the subaggregate; any remaining members are left to
  initialize the next member of the aggregate of which the subaggregate is
  a part."  So the question is each element's own: one with no '{' now
  takes its leaves from the list, as the flat form does, and a short one
  before the closing '}' zero-fills the rest, as a short braced element
  already did.
  
  Fixture M46/struct_array_elide: a bare last element, and a bare element
  between two braced ones.  It did not compile before.

- libc: inet_lnaof and getnetbyaddr
  2.11BSD's usr/lib/libc/inet/inet_lnaof.c and net/getnbyaddr.c, verbatim
  and vendored, with their declarations.  route(8) names a network and a
  host part through them.  Fixture M11/lc_inetnet takes inet_lnaof in each
  address class; it did not compile before.

- route: 2.11BSD's, -f through /dev/kmem
  route is 2.11BSD's usr/sbin/route/route.c: add, delete and change of a
  host or net route through SIOCADDRT and SIOCDELRT, and -f, which flushes
  every gateway route.  The FGX route it replaces only stored a gateway in
  net.mod's interface table.
  
  -f reads the routing hash tables out of the stack.  Upstream's pdp11 arm
  takes the network's data address from /unix and the tables' offsets
  from /netnix; the __FGX__ arm beside it takes the address from sysctl
  kern.netdata, the offsets from the /netnix the build writes, and the
  bytes from /dev/kmem, and uses a pointer read from the stack as the
  24-bit address it already is.  <sys/mbuf.h> gives userland the stack's
  mbuf layout to read them with.
  
  The other deltas: XNS is compiled out; the dotted-quad formatter's C()
  takes the pdp11 arm, an int being 16 bits here too, where the other arm
  hands sprintf's %u a long; and savestr's fprintf gains the stderr
  upstream's call leaves out.
  
  ifcprobe -s says whether a datagram to an address leaves, and routecmd
  drives add, delete and -f on lo0 with it.

- dhclient: the lease goes in through ifconfig's and route's ioctls
  dhclient finds its interface and MAC through SIOCGIFCONF, the first one
  with an Ethernet link-level address or the one named, and sets a lease
  as ifconfig(8) and route(8) would: SIOCSIFNETMASK, then SIOCSIFADDR, then
  SIOCSIFBRDADDR, then the default route with SIOCADDRT.  The last lease's
  default route is deleted first, through the gateway /etc/dhcp.lease now
  keeps on its second line, since rtrequest deletes only a route whose
  gateway matches.  An interface with no address yet is given 0.0.0.0
  before the DISCOVER, as early BOOTP clients configured.  It used
  SYS_IFCONFIG, which wrote net.mod's interface table and the chip's
  address registers, and the stack read the address back from the chip.
  
  That read-back goes: w5address, w5setaddr and BNOP_IFCHANGED.  The host
  route for 255.255.255.255 they kept moves into w5ioctl's SIOCSIFADDR arm
  (deioctl's), because in_pcbconnect sends INADDR_BROADCAST to the primary
  interface's broadcast address and the primary is lo0.  MACRAW reads none
  of the chip's address registers, so nothing writes them.
  
  The netprobe's wire cases take the gateway from the default route rather
  than the chip, and case 55 is now one default route after the lease.  On
  the Uthernet (netw5) a boot lease and a second dhclient both bind, with
  one default route and the broadcast host route through the address.

- telnet_loopback: the connect needle is telnet's escape-character line
  telnet prints `Connected to 127.0.0.1.' and `Escape character is '^]'.'
  from status(), which tn() calls only after connect() succeeds
  (src/userland/telnet/telnet.c, 2.11BSD usr/ucb/telnet.c).  The
  backgrounded telnetd prints `telnetd: listening' after its listen(),
  and that line can land in the middle of the client's first one, which
  split the `Connected to' needle while the session itself reached
  `login:'.  The escape-character line is the same fact on a line of its
  own.  `telnet: connect' and `No connection.' are now asserted absent;
  aimed at a port with no listener, the test goes red on both.

- net: SYS_IFCONFIG and its interface table retire; the card is wz0
  An interface is now configured only as in 2.11BSD: through socket
  ioctls answered by ifioctl and rtioctl (net/if.c, net/route.c), on the
  struct ifnet the W5100 driver attaches as wz0.  The FGX interface
  table that stood beside it goes: syscall 70 (SYS_IFCONFIG) answers
  ENOSYS, net.mod's ifconfig op is retired with its number kept, and
  include/ifnet.s, src/kernel/ifconfig_sys.s, libfgx's ifctl(),
  jump-table slot 27 (SYS_NETKC_W5WRITEIP) and BNOP_IFCHANGED are
  removed.  The card is no longer named u2sN anywhere.
  
  The Ethernet address stays the kernel's: src/kernel/hwaddr.s derives
  00:08:DC:F6:00:<slot> at the card's probe, applies /etc/hwaddr.conf,
  and writes it to the chip's SHAR, where if_w5.c reads it at attach.
  The boot line is `net: slot N mac=...'.
  
  unixprobe finds the card through SIOCGIFCONF.  The M37 sockops fixture
  exercises a failing listen() where it called ifctl().
  tools/check_net_retired.py names every retired symbol and the word
  u2s1.
  
  The core bank has 961 bytes free, from about 520.

- libc: sendmsg and recvmsg
  2.11BSD's struct msghdr goes in <sys/socket.h>, verbatim, with the two
  calls' declarations.  The wrappers, in a member of their own
  (sendmsg.c), pass the header's bank and offset with the descriptor and
  the flags as system calls 131 and 132; the kernel reads the header
  whole, pointers and all, and recvmsg writes msg_namelen and
  msg_accrightslen back.  2.11BSD numbers them 28 and 27.
  
  Fixture M37/sockops calls both on a bad descriptor; it did not compile
  before (no struct msghdr).  Its oracle value goes from 42 to 52.

- fcc: a subscript that reads through a pointer keeps its base's bank
  K&R A.7.3.1: "The expression E1[E2] is identical (by definition) to
  *((E1)+(E2))."  The element is E1's, in E1's bank.
  
  A pointer base's bank waits in _fcc_ptr+2 while its subscript is
  evaluated, and fcc staged it again only when the subscript made a
  call.  A subscript that reads through another pointer -- fdp[ap[1]] --
  loads that pointer's bank into the same cell, so the element was read
  at the base's offset in the subscript pointer's bank.  With both in one
  bank the two agree and nothing shows; the far kernel's file table and
  the core bank's argument block are in different banks, and the
  descriptor lookup there found nothing.
  
  ir_ptr_bank_clobbered_since replaces the call-only test at the four
  restage sites: a call, a pointer local's load, or any store to
  _fcc_ptr+2 in the subscript restages the base's bank from its slot,
  and a base restaged that way stays out of the img pairs, as one after
  a call already did.
  
  Fixture M46/ptrptr_index_regptr: the table in the data bank, the index
  array a stack local in bank 0.  It returned 1 before and returns 42.
  M27/pidx_mutidx's golden changes for the same reason (its subscript
  loads p and q), and its comment says so.

- unix: descriptors pass over AF_UNIX, as 2.11BSD passes them
  sendmsg(2)'s msg_accrights carries descriptors; unp_internalize turns
  each into a reference held by the message, unp_externalize installs it
  as a new descriptor of the receiver, and unp_dispose and unp_gc close a
  file whose only reference is a message nobody will read.  The routines
  are 2.11BSD's, usr/sys/sys/uipc_usrreq.c, and the file calls they make
  are its usr/sys/sys/sys_kern.c's: fadjust, fpfetch, fpflags, unpdisc and
  unpgc1, with GETF, ufavail and ufalloc.
  
  The file table is the kernel's (src/kernel/vfs/vfs_file.c), so the
  network modules name a file by a handle, its index plus one, and a
  rights record holds handles, two bytes each, as upstream's holds
  two-byte struct file pointers.  The calls are ops of one far-bank
  routine, unp_fileop, reached through KSVC_UNPFILE and far slot 82.
  f_count counts the message's reference, and so does the FCB's
  FCB_RefCount, from which close(2) decides teardown.  struct file gains
  f_fcb, the FCB the open file is: f_data names the vnode once one is
  open.  A file the collector discards is closed by close(2)'s own path,
  on a descriptor taken for it.
  
  System calls 131 and 132 carry sendmsg and recvmsg to the stack's
  upstream bodies.  A socket call can now run inside another -- closing a
  discarded socket from within a close -- so bn_sys keeps the outer
  call's u-area state per level and hands its answer back in bn_ret.
  
  unixprobe -r passes /etc/rc's descriptor and reads it in the receiver
  after the sender has closed its own; -r gc does that 150 times with the
  receiver closed unread.  unix(4) documents descriptor passing, and its
  BUGS line says a process with every descriptor open cannot discard.

- libc: a socket name is as long as AF_UNIX's
  getsockname(2), getpeername(2), accept(2) and recvfrom(2) copy
  min(*len, the name's length) bytes and write that count back, as
  2.11BSD's uipc_syscalls.c does (getsockname, getpeername, recvit).
  A name is no longer limited to a 16-byte sockaddr, and a short
  buffer gets a short copy rather than EINVAL.
  
  - getsockname and getpeername pass the caller's length in Y; the
    kernel returns the length it wrote.  accept takes the peer's
    name through getpeername.
  - recvfrom's arg block carries the caller's `from' offset, bank and
    length (words 4-6); bn_sys.c hands them to recvit and writes the
    cut length back.  check_sock_argblk checks those three words.
  - PRU_SOCKADDR is 4.3BSD-Reno's (kern/uipc_usrreq.c): 2.11BSD's is
    an empty case, and its getsockname(2) page says an AF_UNIX name
    is inaccessible.  unp_connect gives the accepted socket a copy of
    the listener's name, as Reno's does, so the connecting side's
    getpeername answers the listener's path.
  - A datagram sender's name stays one struct sockaddr, as 2.11BSD's
    sbappendaddr stores it, so recvfrom returns at most 16 bytes of
    it.  unix(4) BUGS says so.
  
  unixprobe -n binds two stream sockets to 40-character paths.
  getsockname, getpeername and accept return the whole 42 bytes; a
  16-byte buffer gets 16 with the next byte untouched; recvfrom gets
  16 bytes, and 8 from an 8-byte buffer.  The kernel ignoring the
  caller's length fails it (`sockname16 42').  loopprobe's short-buffer
  case asserts the short copy.  getsockname(2) and getpeername(2) are
  rewritten from 2.11BSD's pages.

- loopprobe: -m knows a connection by its data, not its accept order
  The 16-connection case read connection i's bytes from the i-th
  accepted socket.  accept(2) returns connections in the order their
  handshakes complete (2.11BSD uipc_socket2.c soqinsque appends to the
  listener's queue when the final ACK arrives), and a late ACK lets a
  later connect finish first.  The faster assembly bcopy moved the
  timing, and three runs in four failed with `MANY FAIL recv i': the
  i-th accepted socket held connection i+1's pattern, byte for byte.
  
  Each connection's bytes are tfill's pattern for its index, so the
  server reads the index from the first byte, checks the whole 1 KB
  against that pattern, refuses an index it has already seen, and
  answers with the pattern the child expects on that connection.
  A server answering with the wrong pattern fails (`MANY FAIL back 0').

- fs: open(2) on a full file table answers ENFILE, not ENXIO
  _Fs_RootOpen takes a descriptor with _Fcb_Alloc before it asks the
  root, and when that failed it answered zero, its "not mine".
  _Sys_Open reads zero as "no root mounted" and turns it into ENXIO,
  so an open that met a full system file table, or a process with all
  thirty descriptors, failed with ENXIO.  It now answers _Fcb_Alloc's
  errno: ENFILE from the file table, as 4.3BSD-Reno's falloc
  (kern/kern_descrip.c), EMFILE for the process, as its ufalloc, or
  ENOMEM.  @al_full sets only A's low byte, so the answer is masked.
  
  loopprobe -m gains a round: six children open /etc/rc until the
  table is full; one must see ENFILE, the parent's own open must answer
  ENFILE, and after one child closes a file the parent's next open
  succeeds.  Before the fix every child and the parent got ENXIO
  (`FILES full -1, open -1 errno 6').

- select: a pipe is ready by its ring, not always
  select(2) answered every pipe readable and writable, so a timed
  select on an empty pipe returned 1 at once and the read after it
  blocked.  In 2.11BSD a pipe is a socket pair and soo_select answers
  from the buffer (uipc_socket2.c soreadable, sowriteable).  A pipe's
  select arm, _SelOp_Pipe, now does the same from its ring: readable
  with bytes resident or every writer gone (the read answers EOF),
  writable while the ring can grow toward PIPE_MAX_BUFSZ or has room,
  or with every reader gone (the write answers EPIPE).
  
  A pipe op that moves bytes or closes an end now also wakes a
  select(2) blocked on WCHAN_SELECT, when there is one, as pty.mod's
  _Pty_Wake does; net.mod imports _nSelSleepers for it.
  
  pipegrow gains a select part: an empty pipe times out with 0, the
  write end is writable, a resident byte is readable, and with the
  writer closed the read end is readable and the read answers EOF.
  Pipes on the old always-ready arm fail it (`FAIL sel-empty r=1').

- sched: a fork child asleep on a network resource releases its parent
  A snapshot fork child is pinned on its parent's addresses until it
  releases them (SEF_FORKREL), and _sleep releases on the way to
  blocking.  _sleepUn does not, because its waits end by themselves:
  exec's disk reads and buffer locks.  The network stack's sleep at or
  below PZERO went to _sleepUn too, and one of those waits -- m_more's
  wait for an mbuf (2.11BSD uipc_mbuf.c, SLEEP(&mfree, PZERO-1)) --
  ends only when another process frees one.
  
  Measured with loopprobe -m at NFILE 128: five children make sockets
  until the mbufs run out, two sleep in m_more, and the machine wedged.
  The task table showed pids 2, 4 and 32 READY on the address range a
  BLOCKED, unreleased child held, pick_next refusing each through
  Uimg_CanRun, and the scheduler idling.  The siblings that would have
  closed their sockets could never run.
  
  _sleepUnRel is _sleepUn that calls Img_Release first, reached as
  KSVC_SLEEPUNR through the modules' kc_sleepr; the network stack's
  uninterruptible sleep uses it.  The DP-sleep checker knows the new
  sleep and allowlists the shim.  With it the same run finishes: the
  children wait for mbufs, the parent's timed select runs out, and
  their closes wake the waiters.

- bsdnet: a socket call nests per process
  A nested socket call -- close(2) on a socket from inside another
  socket call, when unp_discard closes a descriptor a message held --
  saves the outer call's u_error, u_r, u_ap, u_qsave and getf() file.
  The depth that decided "nested" was one global count, so a process
  asleep inside a socket call (accept, recv, an mbuf wait) made the
  next process's call look nested: it saved and restored another
  process's state, and a fifth sleeper panicked `bn_sys: nested too
  deep'.
  
  bn_in[pid] says whether this process is already inside a call, and
  the save is a local of bn_nested, so only a nested call pays its
  stack: unixrights, which nests, peaks at 810 of 1024 bytes on a
  slot either way.  Only the socket of the getf() file is saved; its
  type is always DTYPE_SOCKET.

- vfs: NFILE 128, so sockets meet the mbuf pool first
  A socket is a file and takes no vnode.  An idle TCP connection is two
  file structs and eight mbufs, so the 280 mbufs hold about 33
  connections and 66 files, and at NFILE 64 the file table ran out
  first: loopprobe -m's exhaustion round stopped at 39 sockets on
  ENFILE.  At 128 the mbufs run out first, as on 2.11BSD: 90 sockets,
  then socreate waits for an mbuf (uipc_socket.c, m_getclr(M_WAIT)),
  and a second round makes 90 again.  The round now fails if ENFILE
  comes first.  VNODE_POOL stays sized for files.
  
  The file arena is 8,384 bytes of heap, from 6,592; the far bank has
  2,963 bytes free, from 3,347, for unp_bound's rows.  vfslayout's
  golden carries the new NFILE.

- libc: a resolver try ends on its deadline, not on a quiet socket
  _dns_resolve waited 1.5 s in select and started that wait again after
  every datagram that was not its answer, so a sender putting anything on
  the query's port at least every 1.5 s kept gethostbyname waiting
  forever.  Each try now ends 1.5 s after its send, select waiting only for
  what is left, as dhclient's wait_reply does.  2.11BSD's res_send
  (lib/libc/net/res_send.c) restarts its full timeout on each stray reply
  (`goto wait'); this is FGX's divergence.
  
  loopprobe -h asks for a name while a child on 127.0.0.1:53 sends a junk
  datagram every second for 12 s, and netudp runs it with resolv.conf
  naming lo0: `DNS FAIL deadline 16' before, `DNS OK' after.

- bsdnet: MSG_DONTWAIT is the call's, not the socket's
  bn_sys turned a call's MSG_DONTWAIT into SS_NBIO on the shared struct
  socket for the length of the call, so a call that slept part way -- in
  sblock behind another sender, or in sosend's M_WAIT mbuf wait -- left
  the socket non-blocking for every other process using it, and their
  plain recv or send answered EAGAIN.  sosend and soreceive
  (sys/uipc_socket.c) now test the flag beside SS_NBIO for that call
  alone, and bn_sys passes the caller's flags through.  2.11BSD has no
  MSG_DONTWAIT; socket.h carries FGX's 0x80.
  
  netudp's nbio case is the witness: soreceive ignoring the flag blocks
  it to the frame cap.

- bsdnet: printf fills in its arguments, as 2.11BSD's prf does
  The network stack's printf logged its format string alone, so its
  messages read `%s: %s'.  net_kern.c now carries 2.11BSD's printf, prf
  and printn (sys/subr_prf.c): the arguments walked from the first one's
  address, %s stepping over a pointer's two ints, numbers in upstream's
  capital digits, and %d unsigned as upstream's is.  Output goes to the
  log a line at a time through kc_printstr.  %b and the terminal argument
  are left out; nothing in the stack uses them.
  
  netprobe logs `bsdnet: printf ok 42 1F 12345678', which netprobe.json
  asserts; before, the line read `bsdnet: printf %s %d %x %X'.  netprobe6
  moves to bsdnet bank 1: bank 0 overflowed at kernel.netprobe 1.

- ntpd: a new peer starts at stratum UNSPECIFIED
  make_new_peer (2.11BSD usr.sbin/ntp/ntpd.c) set every field of a peer
  but its stratum, so until the peer answered, ntpdc's table and the
  stratum of a reference clock's packets carried whatever malloc left
  there: 32 for the never-answering 127.0.0.2 in the ntpd test.  The peer
  now starts at UNSPECIFIED, ntp.h's 0, which the selection code already
  ranks below every real stratum (STRMCMP).
  
  ntpdc.0 gains a BUGS paragraph: delay, offset and dispersion travel
  from ntpd as 32-bit milliseconds, so an offset past 24.8 days wraps.
  
  The ntpd test asserts the peer's line reads `wildcard          0';
  before, it read `wildcard         32'.

- net: a socket call waits for the stack to be up, not for bsdnetd
  net.mod's _Kso_Call found bsdnetd's vtable and called through its
  bn_sys cell, the far pointer to bn_sysent.  bsdnetd is found the moment
  it loads, but bn_sysent lives in bsdnet3 and the cell's stub is stamped
  only when the last module links, so a socket call made while bsdnet1-3
  were still loading jumped through an unstamped pointer into bank 0, and
  the BRK loop that followed wiped the machine.  Loading the network
  modules by hand from a shell crashed whenever another process's socket
  call fell in that window.
  
  The cell now starts 0 and bsdnet_init's last act, bn_ready, fills it --
  only when bsdnet_init returns 0, so a stack that logged BROKEN is not
  entered either.  _Kso_Call answers EPROTONOSUPPORT for a 0 cell, as it
  already did with no bsdnetd at all.
  
  Found with a read tap on $00:0000: the fetch came from _Kso_Call's RTL
  with bsdnetd registered and the cell unusable.  The reproducing command
  crashed 4 runs in 4 (and 2 in 2 before the S5 Task 10 commits); with the
  fix 2 in 2 pass, and the fix less _Kso_Call's check crashes again.

- netbusy: netdump holds socket 0 while the modules load
  netbusy's netdump ran with no count, so it stopped after 5000 empty
  reads -- or, with a count of 1, at the first frame the card saw -- and
  gave socket 0 back before modload ran; the driver then attached and the
  test failed on `w5: attached'.  netdump 30000 keeps capturing, and the
  wait before modload is 8 s, so the driver finds socket 0 held and says
  `w5: socket 0 busy'.

- mame_test: capture_writes can tap reads, late, at a PC
  A capture_writes entry takes "kind": "r" to tap reads, opcode fetches
  included, with its stack window starting 32 bytes below S, where an
  RTS or RTL's pulled address still sits; "from_frame" to ignore hits
  before a frame; and "pc_max" to keep only hits whose PB:PC is at most a
  value.  A read tap on address 0 with pc_max 3 catches the fetch of a
  jump through a null pointer and not the firmware's data reads there.

- net: the socket calls' comments describe the kernel stack
  loader.s's listen, accept, recvfrom, connect and shutdown entries
  described the W5100's TCP: a backlog ignored, a listener detached on
  accept, a non-blocking recvfrom, and a shutdown that could not stop
  receiving.  They now say what 2.11BSD's uipc_syscalls.c bodies do, and
  docs/userland-abi.md is regenerated from them.  libc's shutdown comment
  names soshutdown; net.s and main.s no longer mention SYS_IFCONFIG.

- kernel: the W5100 interrupt no longer wakes every select
  The interrupt handler set _kSockWakePending on each interrupt, and swtch
  turned it into a wake of WCHAN_SOCK and of WCHAN_SELECT.  That served
  the chip's own TCP sockets, where an interrupt meant a socket event.
  Socket 0 is MACRAW now, so the interrupt fires for every broadcast and
  multicast frame on the wire, and each one woke every process blocked in
  select to rescan its descriptors: syslogd, inetd and ntpd ran once per
  frame.  Nothing sleeps on WCHAN_SOCK since the chip transports went, and
  the stack wakes a selector when data reaches its socket, as 2.11BSD's
  sbwakeup does (sys/uipc_socket2.c) through selwakeup.
  
  The flag, the two swtch sites that read it and WCHAN_SOCK are removed.
  The idle loop keeps its 60 Hz rescan of block-forever selects.
  
  Under MAME with 142-byte broadcasts arriving at 20 a second, cat of 150
  lines to the console took 853 frames before and 577 after; main, and
  this tree on a quiet network, take about 385.

- wz0: a frame the stack cannot use is dropped at its header
  w5rint copied every frame from the chip's ring into mbufs and only then
  let w5input free the ones that were neither IP nor ARP.  The W5100's MAC
  filter also passes every multicast frame, which on a LAN with mDNS,
  LLMNR and IPv6 neighbors is most of what arrives, and ip_input discards
  those after the copy.
  
  A frame to a group address other than broadcast, or of a type other than
  IP or ARP, is now passed over in the ring once its 14-byte header has
  been read: no copy, no mbuf.  This is the filter 2.11BSD's interface had
  in hardware: pdpif/if_de.c leaves DE_DO_MULTI undefined and sets the
  board's mode to MOD_TPAD|MOD_HDX, so the DEUNA delivers its own address
  and broadcast only, and deread knows the type before deget.  While bpf
  is open every frame still takes the whole path, so netdump shows the
  wire.
  
  Measured under MAME with a build that also dropped the test frames,
  since multicast from the host does not reach the emulated card: with
  100 broadcasts a second, cat of 150 lines took 445 frames against 1837
  without the drop and 385 on a quiet network.  The multicast test itself
  has not run against multicast traffic.

- klog: a reader and a select are released when the kernel logs
  Nothing woke /dev/klog's reader when a message was written.  A blocked
  read slept on lbolt and saw the message up to a second later, and a
  select on the device was released only by the idle loop's 60 Hz rescan
  of every selector.
  
  _Klog_Wake is 2.11BSD's logwakeup (sys/subr_log.c), which wakes the
  reader and calls selwakeup, and which upstream calls from printf
  (sys/subr_prf.c).  The ring's writer here also runs at interrupt time,
  where the scheduler table must not be walked, so the wake is performed
  where lbolt's is, at syscall return and in the idle loop, when the
  ring's head has moved since the last one.  The reader sleeps on
  WCHAN_KLOG.  klog(4) BUGS states the remaining difference: a tick late
  at most, not at the write.

- wz0: a frame put in the bpf ring wakes a select on it
  bpf's poll answers from the tap ring, and nothing woke a selector when
  the driver added a record: the idle loop's rescan of every selector was
  what noticed.  w5_tap calls selwakeup, as a BSD bpf_wakeup does.
  netdump reads without select, so nothing shipped depended on it.

- sched: the idle loop no longer wakes every select 60 times a second
  swtch's idle arm woke WCHAN_SELECT on every pass as a net under sources
  that did not wake it themselves.  Each process blocked in a select with
  no timeout was switched in, rescanned its descriptors and slept again
  every tick: with inetd, syslogd and ntpd that was about 12.5 ms of each
  16.7 ms tick on an otherwise idle machine.
  
  Every source now wakes the channel when its state changes, as 2.11BSD's
  do through selwakeup: sockets (sowakeup, sys/uipc_socket2.c), pipes
  (sys/sys_pipe.c), tty lines (ttwakeup and ttyowake, sys/tty.c), the pty
  master (ptcwakeup, sys/tty_pty.c), the keyboard at swtch, and since the
  two previous commits /dev/klog and bpf.  The net is removed.
  
  A ping from another host to an idle machine under MAME averaged 22 ms
  with the net and 9.7 ms without.  The suite gives the same result both
  ways.

- signal: a signal posted to a sleeper wakes that process only
  A signal posted to a blocked process released every process sleeping on
  the same wait channel.  Every nanosleep shares one channel, and one that
  is released before its deadline answers EINTR, so a ^C typed on one
  terminal ended a sleep(1) running on another: an interrupt in a telnet
  session made `sleep 130' on the console exit with status 1.  A select
  or a tty read woken the same way looked again and slept again; a
  nanosleep cannot tell the wake was not its own.
  
  _Kill_Apply now marks the target runnable and clears its wait channel,
  and leaves the channel's other sleepers alone.  That is 2.11BSD's
  psignal (usr/sys/sys/kern_sig.c), whose `run:' arm is
  
  	if (p->p_pri > PUSER)
  		p->p_pri = PUSER;
  	setrun(p);
  
  for the one process the signal is for.

- pty: an ioctl on the master is the slave line's
  A pty master passed three commands to its slave's line -- TIOCGWINSZ,
  TIOCSWINSZ and TIOCFLUSH -- and refused the rest with ENOTTY.  A login
  daemon holds only the master, so it could not read or set the session's
  modes or special characters: 2.11BSD telnetd's mode(), interrupt() and
  sendbrk() all failed, and an Interrupt Process from the client put a
  DEL in the session's input instead of its interrupt character.
  
  Every command the master's own switch does not take now goes to the
  slave's line, as 2.11BSD's ptyioctl does (usr/sys/sys/tty_pty.c): it
  answers TIOCPKT, TIOCUCNTL and TIOCREMOTE for the controller and gives
  everything else to `error = ttioctl(tp, cmd, data, flag)'.
  
  kc_ttioctl is told when the controller is asking and does what ptyioctl
  does first for it:
  
  	case TIOCSETP:
  	case TIOCSETN:
  	case TIOCSETD:
  		while (getc(&tp->t_outq) >= 0)
  			;
  		break;
  
  The controller is the only reader of that queue, so the ttywait those
  commands reach would otherwise wait on the caller.
  
  kc_ttioctl also loses a second, unreachable return statement.

- telnetd: ported from 2.11BSD
  telnetd(8) is now 2.11BSD's (usr/libexec/telnetd/telnetd.c 5.20.3) in
  place of a program written after it.  What that brings:
  
  - The relay sleeps in select(2) on the connection and the pty, where it
    polled both and slept a tick.
  - Output to either side is buffered and flushed as the side accepts it;
    a short write to the pty no longer loses the rest.
  - The option machinery is upstream's: BINARY and TIMING MARK are
    answered, and BINARY puts the line in raw mode.
  - The TELNET commands are acted on: Interrupt Process, Break, Abort
    Output, Erase Character, Erase Line, Are You There, and Data Mark
    with TCP urgent data in both directions.
  - The session ends on SIGCHLD from the child, and utmp, wtmp and the
    pty's modes and owner are put back by upstream's rmut().
  
  It differs from upstream as follows, each marked in the source and
  listed in telnetd(8) BUGS.  The child is `getty -T type', not `login -h
  host -p', because login(1) here only authenticates; the peer's name is
  not looked up and upstream's banner is left to getty.  The slave is not
  revoked with vhangup(2), which does not exist here.  NAWS is negotiated
  and set with TIOCSWINSZ, which this telnetd predates.  The listener
  upstream compiles under DEBUG runs when a port is given, on every
  address, so /etc/inetd.conf starts it as plain `telnetd' and the -i
  flag is gone.  It prints nothing of its own to standard output.
  
  telnet_loopback asserts `login:', which is getty's prompt carried
  through the relay, in place of the two lines telnetd used to print.

- select: an object wakes the select that is waiting on it
  select(2) slept on one channel and every source woke the whole channel:
  a byte arriving on one socket made every selecting process runnable, and
  each one scanned its descriptors and slept again.  With inetd, syslogd
  and ntpd running, each exchange between telnetd and a shell waited
  behind three such passes, about half of the time between a keystroke
  and its echo.
  
  It is now 2.11BSD's arrangement (usr/sys/sys/sys_generic.c).  A select
  that finds an object not ready leaves its process there, and the object
  wakes that process when it becomes ready:
  
  	selwakeup(p, coll)
  		if (coll) {
  			nselcoll++;
  			wakeup((caddr_t)&selwait);
  		}
  		if (p) {
  			if (p->p_wchan == (caddr_t)&selwait)
  				setrun(p);
  			else if (p->p_flag & P_SELECT)
  				p->p_flag &= ~P_SELECT;
  		}
  
  select1's test before it sleeps is ported with it, so a wake that comes
  between the scan and the sleep is not lost:
  
  	if ((u.u_procp->p_flag & P_SELECT) == 0 || nselcoll != ncoll)
  		goto retry;
  
  The selector is recorded where upstream records it:
  
  - A socket buffer's sb_sel, by sbselqueue (sys/uipc_socket2.c), which
    was already in the tree and recorded one shared process for all.
  - A tty line's t_rsel and t_wsel, by ttyselect (sys/tty.c), whose two
    recording arms were left out; ttwakeup, ttyowake and ttyflush pass the
    selector and the collision bit again.  The console's select asks
    ttyselect too, where it asked ttnread.
  - A pty master's pt_selr and pt_selw, by ptcselect, and ptcwakeup(tp,
    flag) wakes them from ptsstart, ptsread, ptsstop and the slave's
    close (sys/tty_pty.c).
  
  A pipe, /dev/klog and bpf record no selector and wake through
  selwakeup's collision arm, which releases every select as before.
  
  The scheduler no longer wakes every select on each context switch while
  the keyboard ring holds a byte.  A key reaches its line's selector
  through ttwakeup.
  
  Measured from another host over telnet, in MAME, with inetd, syslogd,
  ntpd and cron running: the time from a keystroke to its echo, median of
  300, went from 100 ms to 67 ms.  Login to a shell prompt with TERM set
  by the client went from 33 s to 3 s.
  
  Two kernel services are added for modules, KSVC_SELWAKEUP and
  KSVC_SELWAITING.

- select: a select with a timeout sleeps until its deadline
  A select given a timeout never slept.  It scanned its descriptors,
  yielded, and scanned again until something was ready or the time had
  passed, so a daemon waiting in one (ntpd, between polls) stayed runnable
  and took a turn at every context switch.
  
  It now sleeps as an untimed select does, on the select channel, and the
  clock ends the sleep.  This is select1's sleep in 2.11BSD
  (usr/sys/sys/sys_generic.c), where the one call serves both cases:
  
  	timo = hzto(&atv);
  	if (timo == 0)
  		timo = 1;
  	...
  	error = tsleep(&selwait, PSOCK | PCATCH, timo);
  
  The deadline is kept in the sleeper's SE_WakeTime, and
  _Timer_WakeExpired, which ended nanosleep's sleeps, ends a sleep on the
  select channel as well.  A select with no timeout stores a time that
  does not come.  The sleeper scans once more when it wakes and returns 0
  when the deadline has passed.
  
  Measured from another host over telnet, in MAME, with inetd, syslogd,
  ntpd and cron running: the time from a keystroke to its echo, median of
  300, went from 67 ms to 51 ms.

- telnetd: a window size after a terminal type, and a resize, take effect
  The window size option is this port's addition to 2.11BSD's telnetd, and
  two things it needs were missing.
  
  A suboption was read from where the last one's reader had stopped.
  2.11BSD's telnetd receives one suboption in a session, the terminal
  type, so nothing came of it there.  Here a window size that followed a
  terminal type was read as that terminal type again, and a second window
  size as the first, so a client that reported its type got no window
  size and no client's resize was seen.  A suboption now starts an empty
  buffer, as in 4.3BSD-Reno's telnetd (libexec/telnetd/state.c, telrcv):
  
  	case SB:
  		state = TS_SB;
  		SB_CLEAR();
  		continue;
  
  With resizes arriving, the first one after the shell had taken the
  terminal stopped telnetd: the slave is its controlling terminal, and
  TIOCSWINSZ from a process outside the foreground group raises SIGTTOU.
  2.11BSD's rlogind sets a window size the same way and says what to do
  (libexec/rlogind/rlogind.c, protocol()):
  
  	/*
  	 * Must ignore SIGTTOU, otherwise we'll stop
  	 * when we try and set slave pty's window shape
  	 * (our controlling tty is the master pty).
  	 */
  	(void) signal(SIGTTOU, SIG_IGN);
  
  telnetd now does.  Both files are vendored with this change.

- telnetd, login: the session is `login -h host -p', as in 2.11BSD
  telnetd ran getty with the terminal type as an argument, and getty
  handed it to login the same way.  It now does what 2.11BSD's telnetd
  does (libexec/telnetd/telnetd.c, doit and telnet): looks the client up
  with gethostbyaddr, falling back to its address, puts the terminal type
  in the child's environment as TERM, runs
  
  	execl("/bin/login", "login", "-h", host,
  					terminaltype ? "-p" : 0, 0);
  
  and sends the banner "that getty never gave", which names FGX and the
  host.  /etc/issue is no longer shown to a telnet client.
  
  login takes the two options from 2.11BSD's login (bin/login/login.c):
  
  - -h host, for the super-user only, is recorded in utmp, so who(1)
    shows where a session comes from.  A name in the local domain is
    recorded without the domain.
  - -p keeps the environment.  Without it the environment is emptied.
    HOME, SHELL and USER are set either way; TERM and PATH are set only
    if not already there, which is how the client's terminal type
    survives.
  
  login also gives the terminal to the user, as upstream does after the
  utmp record:
  
  	(void)chown(ttyn, pwd->pw_uid,
  	    (gr = getgrnam(TTYGRPNAME)) ? gr->gr_gid : pwd->pw_gid);
  	(void)chmod(ttyn, 0620);
  
  telnetd sets the slave to mode 0 before the session, so without this a
  user who was not root could not open the terminal by name.
  
  The -T option of login and getty, which carried the terminal type, is
  removed.  Not taken from upstream's login: -f, lastlog, the message of
  the day and mail notice, the login timeout, and the clearing of the
  window size on a line that is not a network login.

- vhangup(2), and telnetd revokes the slave before the session gets it
  The system had no vhangup, so telnetd gave a session a pty slave that
  processes of the session before it could still have open, and left it
  that way when the session ended.
  
  vhangup is 2.11BSD's (usr/sys/sys/sys_inode.c):
  
  	vhangup()
  	{
  		if (!suser())
  			return;
  		if (u.u_ttyp == NULL)
  			return;
  		forceclose(u.u_ttyd);
  		if ((u.u_ttyp->t_state) & TS_ISOPEN)
  			gsignal(u.u_ttyp->t_pgrp, SIGHUP);
  	}
  
  and forceclose with it, which takes FREAD and FWRITE from every open
  file on the device, so that a read or write through one answers EBADF.
  It is system call 133.  The permission test is in the core kernel, the
  walk of the file table in the far bank beside the descriptor check that
  reads those bits, and the signal in the tty bank.
  
  One difference: a process's controlling terminal is kept as a line and
  not as a device number, so the files of every character device that is
  that line are revoked.
  
  telnetd calls it where 2.11BSD's does (libexec/telnetd/telnetd.c): in
  doit, between two opens of the slave,
  
  	(void)signal(SIGHUP, SIG_IGN);
  	vhangup();
  	(void)signal(SIGHUP, SIG_DFL);
  	t = open(line, O_RDWR);
  
  and in cleanup, when the session has ended.
  
  vhangup(2)'s manual page is 2.11BSD's.  A test, vhup, opens a slave as
  its controlling terminal, writes to it, calls vhangup, and requires
  EBADF from the descriptor it held and a working write from a new open.

- ROADMAP: an exec holds the machine for its load (flux-gs/fgx#49)
  execve reads the whole image inside one system call, and the kernel is not
  preempted, so neither another process nor the network's deferred input runs
  until it returns.  Under MAME the first tcsh after boot is one 5 second call.
  The issue carries the measurement.

- resolver: a negative answer from the nameserver ends the lookup
  gethostbyname(3) and gethostbyaddr(3) treated a reply that carried a
  response code, or no record of the type asked for, as if it were not a
  reply at all: they waited out the try, sent the query again, and gave up
  only after three tries of 1.5 s.  A lookup of a name or address that does
  not exist took 4.5 s to fail, though the nameserver had said so at once.
  
  telnetd looks up the client's address before it prints its banner, so a
  client with no entry in /etc/hosts and no PTR record waited about 5 s for
  "FGX (host)".  Under MAME, connect to banner for such a client is 5.5 s
  before and 0.95 s after; a client in /etc/hosts was 1.0 s throughout.
  
  A reply whose id matches the query now ends the lookup with whatever it
  says.  A reply with another id, or one too malformed to read, is still
  waited past.  This is what 2.11BSD does: res_send() in
  lib/libc/net/res_send.c discards only `id != anhp->id' ("response from
  old query, ignore it") and returns every other reply, and res_query()
  turns the response code into h_errno.
  
  FGX reports every failure as HOST_NOT_FOUND, where res_query() gives
  TRY_AGAIN for SERVFAIL and NO_DATA for a name with no such record.


### Documentation

- The 2026-10-23 whole-system profile, and performance is active again
  One tool at a time on a 93 KB input, every sampled bank attributed: the
  C library's stdio, the compiler's output and the write path, which the
  earlier exec-heavy workloads could not show.  The profile records the
  method, the baseline on v2.2.0, the ranked causes and what landed;
  ROADMAP's performance section points at it, with the 2.11BSD stdio port
  and saved text next.

- The stdio design records the compiler work that followed the port
- The stdio design records the Reno doprnt port
- The stdio design records the putc expansion work
- The stdio design records the putc codegen work
- The stdio design records the rest of the putc work
  Sections 10 and 11: the dead TAX and the member reached through Y, their sizes and frames, and why the reload of p on the line-buffered arm stays.

- The stdio design records the ls and printf profile
  Section 11: what the printf loop and ls -l spent their time on before and after the long-constant, digit and bcopy changes, and what is left. Section 12: the next levers.

- The stdio design records the callee-saved direct-page band
  Section 12: what the band is, what it bought and what it did not, and why recursive functions stay out.  Section 13: struct pointers in the band next.

- The networking-without-a-socket-limit design
  The W5100 runs TCP and UDP in four hardware sockets, so the machine can
  hold four network endpoints at once; a busy multiuser session needs 15 to
  25.  Connections cannot be swapped on and off the chip, because their TCP
  state lives inside it.  The design moves the connections into the kernel:
  2.11BSD's own networking code, with the Uthernet II as one ifnet driver on
  its MACRAW socket 0, so sockets are limited by memory and nothing above
  the driver knows which card is fitted.
  
  It records the chip's MACRAW and IPRAW behavior as the emulator implements
  it, today's measured throughput and per-byte costs, and the phases S0 to
  S5.  It replaces Track B's S1-S3 and the earlier Backend B plans; the
  ROADMAP entry points to it.

- The net-mux S0 plan, fcc prerequisites for the 2.11BSD network port
  Eight tasks: an audit of the whole port set under fcc, sorting each
  failure into the compiler's or the machine seam's; # and ## in macro
  replacement; extern of an incomplete struct; struct assignment into an
  array element; an address plus a constant in an array-of-pointers
  initializer; & of any lvalue; struct return by value through a hidden
  caller pointer; and a closing re-run of the audit with the gate.

- Net-mux S0 audit of the port set
  The 23 files the design ports, compiled as 2.11BSD's CURLY kernel
  compiles them.  Besides the known items it found two more compiler
  gaps -- a call through a function pointer at the end of a member chain,
  and a typedef of a sized array -- added as Tasks 7a and 7b, and widened
  Task 6 to the & shapes the sources use.  The rest are machine-seam gaps
  for S1.

- # and ## are no longer an open fcc gap
- Net-mux S0 is done
- A pointer to or an array of an array typedef is an open fcc gap
- Net-mux S1 plan
  Machine seam and packaging for the 2.11BSD network stack: several code banks over one shared data bank, a new fgx configuration symbol in place of pdp11, mbufs for 4-byte pointers, spl, in_cksum, netintr at the deferred-work drain, and a measured kernel stack depth.

- Net-mux S1 done
  The design records the shared data bank, the fgx configuration symbol, what splnet
  and the drain rely on, what S2 inherits, and that S0's compile claim was made
  under the wrong arm.

- Netintr's idle-loop stack is S2's first question
  netintr can run on the scheduler's 512-byte stack in the idle loop, not only on a
  task's 1024 bytes, and the deepest static chain is about 460 bytes.  The design
  states the three choices and that S2 picks one before protocol code runs from the
  drain.

- Net-mux S2 plan
  Substrate running: netintr on its own stack, callouts, lo0, the W5100 MACRAW
  driver, ARP and an ICMP echo on the wire, bpf as a tap, and a hardware image for
  the run the design requires before S3.

- The net-mux S2 heartbeat mark keeps its constant, and Task 7 measures it
- Net-mux S2 measured, and what S3 inherits
- Net-mux S2's commands for the real-hardware run
- Net-mux hardware throughput, and what MAME's numbers are worth
  On a real IIgs with an Uthernet II, hardware-socket ftp runs at 9.9 KB/s
  to /dev/null and to disk alike, on main and on this branch with the
  stack unloaded, and at 9.6 KB/s with the stack loaded.  MAME ran the same
  transfer at 99 KB/s, so the design's throughput estimates were built on
  an emulator about ten times faster than the card.

- Net-mux S3 plan, UDP on the kernel stack
  Eight tasks: the syscall path's stack depth first, then the u area,
  kernel setjmp and errno; net.mod forwarding UDP descriptors to
  2.11BSD's uipc_syscalls.c; the modules at every boot with DHCP through
  0.0.0.0 and a default route; the programs on it; the chip's UDP core
  deleted; back-to-back transmit; and a hardware image.  Seven calls the
  design leaves open are listed for review.

- Net-mux S3 plan, revised after review
  uipc_syscalls.c links whole, so u_ofile, netoff and getf stay and
  falloc/ufalloc are panics; sleep() stores EINTR before the longjmp, as
  kern_synch.c does; the kernel setjmp saves fcc's frame cells; select goes
  through soo_select so sb_sel is armed; the resolver, dhclient and
  unixprobe leave EAGAIN polling in the task that makes blocking UDP the
  default; a broadcast host route keeps a second DHCP run off the default
  route; the old gateway is remembered for SIOCDELRT; inbound ARP is
  dropped while the address is 0.0.0.0; suser() sets EPERM.

- Sendit's frame is its two stack mbufs, not an iovec array
- Net-mux S3 measured, and the real-hardware run
  The design records S3 done under MAME: the deepest process kernel slot
  under a UDP workload is 740 of 1024 bytes (474 without the modules),
  the modules take 252,325 bytes in five banks and leave 23 of the
  pool's 56 banks free at idle, and the echo round trip is 7-8 ticks
  with the transmit wait as without it.  S4 inherits the descriptor
  table, net_kso.s, bn_sys.c's falloc and ufalloc, TCP's deepest send,
  and the card's two names: wz0 to the kernel stack, u2s1 to ifconfig.
  
  The hardware page names what to check on a real IIgs: the lease, ntpd
  and ntpdc, syslogd -u from another machine, ping from another subnet,
  ftp's rate, netdump, and on the probe image the transmit wait.
  
  ntpnet's ifcprobe expects the card as wz0, the name SIOCGIFCONF gives
  it now that the interface ioctls reach the kernel stack.

- Net-mux S3 hardware results
  The S3 run on a IIgs with a TransWarp, an MDT and an Uthernet II: the
  lease, NTP, syslog over UDP, ping from another subnet and ftp all
  worked.  Two hard freezes during the first sessions did not reproduce
  on the hardware or under MAME and are recorded unexplained.

- Net-mux S3 ftp checksum matched
- Net-mux, what must land before the campaign PR
- Net-mux S4 plan
- Net-mux, the socket call's stack floor is done
- Net-mux S4 measured, and the real-hardware run
  The design records S4 done under MAME.  The deepest process kernel
  slot under TCP is 720 of 1024 bytes; the stack's five banks hold
  275,961 bytes and net.mod 2,838; the core bank has 525 bytes free.
  1 MB over lo0 takes 41.0 s, 25 KB/s, and the profile settles the
  checksum: in_cksum is 5.7% of the samples, under the 15% that would
  fold it into the copy, while the stack's C bcopy, a byte loop, is
  30.2%.  S5 inherits that copy, descriptor passing over AF_UNIX, the
  14-character sender name, and NFILE.
  
  The hardware page asks for the attach line's buffer size, telnet from
  the Mac, ftp's rate on the kernel's TCP, sixteen connections at once,
  ping both ways, syslog over /dev/log and UDP, and netdump.

- Net-mux S4 remeasured with the assembly bcopy
  The 1 MB lo0 transfer takes 28.6 s, 36 KB/s.  Its largest cost is now
  the kernel's _Img_Xchg, 41.5% of samples: the test's writer is the
  reader's forked child, so the two share an image bank and every switch
  between them exchanges the data image.  in_cksum is 7.0%, under the 15%
  at which the design would fold it into the copy.
  
  ROADMAP's Performance campaign lists the routines 2.11BSD keeps in
  machine code, to review against FGX's C counterparts.

- The net-mux S5 plan
- S5 plan takes /dev/mem, /dev/kmem and nlist, so route -f is upstream's
- Net-mux S5 measured, and the real-hardware run
  The design records S5 done under MAME and the calls its plan made, as
  built: a rights record holds handles to the VFS file table's struct
  file, which gains f_fcb, in place of the plan's FCB offsets.  Every item
  listed before the campaign PR is done.  The core bank has 630 bytes
  free and the far bank 2,963 with NFILE 128; the stack's five banks hold
  281,305 bytes, net.mod 2,514 and mem.mod 428.  1 MB over lo0 takes
  27.5 s, 37 KB/s.
  
  networking.md describes the kernel stack: sockets limited by memory,
  bpf as a tap, the interfaces wz0 and lo0, and descriptor passing.
  
  The hardware page asks for ifconfig wz0 and its ether line, route -f
  and route add, dhclient by hand, a static address from netstart's
  commented lines, descriptor passing, and S4's steps once more.

- A script for the net-mux S5 hardware run
  /root/s5run.sh runs the IIgs side of every step on the S5 hardware page,
  prompts for the Mac's side and the screen-only checks, logs everything to
  /root/s5run.log and sends the log to the Mac with nc.  syslogd is restarted
  with -u between two tee segments, outside any pipe.

- The S5 run script says why syslogd restarts outside the pipe
  Inside `( ... ) 2>&1 | tee', 2.11BSD sh keeps its own output on fd 11 as a
  dup of fd 2 (sh/xec.c, TPAR: rename(dup(2), output)), and dup2 leaves the new
  descriptor inheritable (sys/kern_descrip.c dup2: u_pofile & ~UF_EXCLOSE).  A
  daemon started there inherits the pipe's write end and the reader never sees
  its end.

- The S5 run script runs ftp on the terminal
  Inside the script's `( ... ) 2>&1 | tee', ftp's standard output is a
  pipe, and login() in ftp.c (2.11BSD usr/ucb/ftp) prints the Name prompt
  with printf and no fflush, so the prompt stayed in stdio's buffer while
  ftp waited for the answer.  ftp now writes to /dev/tty, and the script
  asks for the transfer line it printed.

- The S5 run script starts inetd before the pipe
  When inetd was not already running, the script started it inside
  `( ... ) 2>&1 | tee', where it inherited the pipe at sh's fd 11 (2.11BSD
  sh xec.c TPAR) and kept it, so tee never saw the end of its input and the
  first segment never finished.  inetd now starts before the pipe.

- The S5 run script prints each boot module line once
  Its dmesg filter matched every bsdnet module line twice, once as a
  module line and once as a bsdnet line.

- Net-mux S5 on real hardware
  Every S5 step passed on a IIgs with an Uthernet II.  Sixteen telnet
  connections give two logins: FGX has two pty pairs (include/pty.s), where
  2.11BSD's tty_pty.c has NPTY 16; the stack held all sixteen.  The run
  script's pty step now says so.  Open: ^Z in ftp under tcsh over telnet
  hangs the machine, and interactive and console speed have fallen on this
  branch.


### Tests

- tests: a scripted command may hold a double quote or a bracket
  The plugin read input_script with Lua patterns: `"([^"]*)"' stopped at
  the first \" and skipped the whole entry without a word, so under
  FGX_MAME_PRIMARY=inject a command such as `echo MARK""DONE' was never
  typed and the run went to its frame cap; and `%b[]' would miscount a
  [ or ] inside a command.  A small scanner now reads each [frame, "text"]
  entry and steps over escapes, and \" and \/ are un-escaped with the rest.
  
  run.py's account of inject mode is corrected too: the bytes go through
  the key latch one per frame, not into the ring in a single frame, and
  the profile sampler arms before the typing, so a profile carries one
  frame per character of the command.

- A manifest can boot the root as a power cut leaves it

## [2.2.0] - 2026-10-22

### Build

- The provenance check has its own stamp, over the files it reads
  check_provenance ran inside the kernel checks, whose stamp's inputs are
  the kernel listings.  A change to a userland source alone never re-ran
  it, so a new port went unregistered through a green build until the
  kernel next changed.
  
  The check now names its own inputs (--inputs: the registry, every file a
  row names, every tracked .c under the ported directories, the cited
  sources and the vendored files rows claim), and build/.provenance_checked
  is built from that list as part of `all`.  docs/PROVENANCE.md is an input
  to build.ninja, so a new row regenerates the list.


### Changed

- kernel: block devices take 2.11BSD's major and minor, through a bdevsw
  A block dev_t is now a major and a minor (2.11BSD usr/sys/h/types.h:17-23,
  in src/kernel/vfs/fsparam.h), and bio_strategy dispatches on the major
  through bdevsw[], the call 2.11BSD's bread makes (usr/sys/sys/ufs_bio.c:38).
  The SmartPort disks are major 0, so /dev/sd0-sd7 keep their numbers; the
  RAM disk is major 1, and /dev/ram0 is minted as 256.  The minor is the
  driver's unit.
  
  Every block driver reaches the disk through kc_blkio, so a bdevsw entry
  carries the driver's slice of the kernel device table -- its first row and
  unit count, include/fs.s's BDEV_* -- where upstream's carries d_strategy and
  the rest; vfs.mod's bank has 65 bytes left and no room for a strategy
  routine per driver.  A major past the table is ENXIO in bio_strategy, in
  spec_open and in getmdev, which carries Reno's check again (2.11BSD
  ufs_mount.c:346); a unit past the driver's count is ENXIO in bio_strategy.
  
  Dev_Init attaches at most BDEV_NSD (8) SmartPort disks, one per /dev/sd
  node, and the RAM disk takes row BDEV_RAM_ROW (8) outright.  It had scanned
  upward from row 8 for a free row while /dev/ram0 named row 8 alone, so a
  machine with more than eight SmartPort units put it where its node did not
  reach.
  
  ufs_devname names a mounted device by its major, so df and mount print
  /dev/ram0 for a UFS RAM disk rather than /dev/sd8.

- kernel: the boot log names each disk and bus as BSD's attach lines do
  The SmartPort scan's lines follow NetBSD's autoconfiguration shape
  (sys/scsi/cd.c: "cd%d at %s%d targ %d lun %d: %s"): the device first, then
  where it was found, then what it is.  A SmartPort bus is spN, after the
  order Dev_Init registers them; boot bus first.
  
      sp0 at slot 7
      sd0 at sp0 unit 1: 63999 blocks (31999KB)
      sp1 at slot 5
      sd1 at sp0 unit 2: 40960 blocks (20480KB)
  
  They replace "blk: dev 01: s7,d2 (attaching sd1) ..." and "bus 1: slot 5
  entry=$C50D", which led with the kernel's device-table index and named the
  unit by slot and drive.

- kernel: a SmartPort CD-ROM attaches as /dev/cd0, read-only
  The SmartPort scan reads each unit's device information block (status code
  $03, Apple IIGS Firmware Reference p.123) and attaches one whose device type
  is $05, "SCSI CD-ROM" (SmartPort Technical Note #4), as a cd unit rather
  than an sd one, as BSD attaches by the device's own type.  A unit that does
  not implement code $03 is asked code $00 and attaches as a disk, as before.
  
  cd is block major 2, its units rows 9-12 of the device table (BDEV_CD_ROW0,
  BDEV_NCD), and /dev/cd0-cd3 are minted 400.  Its bdevsw entry is read-only:
  a write is EROFS, NetBSD 0.9's cdstrategy answer (sys/scsi/cd.c).  A drive
  with no disc -- the general status byte's "disk in drive" bit clear -- is
  attached offline and logged
  
      cd0 at sp0 unit 2: empty
  
  rather than with the block count the card reports for it, 17352 on MAME's
  Apple SCSI CD-ROM.  With a disc it is logged with its size.  The Apple II
  SCSI Card presents the disc's ProDOS partition as 512-byte blocks, so a
  ProDOS CD mounts with mount_prodos -o ro /dev/cd0; ISO 9660 does not mount
  yet.
  
  mame-hd.sh -cdrom FILE loads a disc into MAME's drive on the SCSI card.

- kernel: a CD-ROM with 2048-byte sectors reads as 512-byte blocks
  The Apple II SCSI Card presents a disc with no ProDOS partition whole, in
  the drive's 2048-byte sectors, and its ReadBlock then returns the first 512
  bytes of SECTOR b rather than block b -- the card reads the whole sector
  and discards the rest (its ROM, bank 1 $CEBB).  SmartPort Technical Note #5:
  "For devices with a block size other than 512 bytes, use the SmartPort Read
  and Write calls."
  
  At attach a CD-ROM unit is asked the card's STATUS $06, the unit's block
  size (big-endian; ROM STATUS table at offset $11E1).  A 2048-byte unit is
  marked DEV_FLAG_SEC2K and its size given in 512-byte blocks, and Blk_Read
  serves it through the block cache's read-ahead with a run of one sector:
  one extended Read of 2048 bytes, addressed by sector (block >> 2, which the
  card puts into the SCSI READ unconverted), fills the four cache slots of
  blocks 4s..4s+3.  Every layer above still sees 512-byte blocks, as SunOS
  4.1.3's sr.c divides its block number by 4 (sys/sundev/sr.c:974).  A read
  the read-ahead cannot do fails with EIO rather than fall back to ReadBlock.
  
  The size is read once, at attach; an empty drive does not answer and is
  taken as 512.  The CD attach moves into its own routine, _dev_attachCd.

- kernel: isofs, the ISO 9660 filesystem type, and mount_isofs(8)
  isofs.mod mounts an ISO 9660 volume read-only: a CD on /dev/cd0, or an
  image on any block device.  It is netbsd-0-9's sys/isofs in FGX's VFS terms,
  in prodos.mod's shape -- its own module bank, vfs.mod reached through
  generated import shims, vfssw[MOUNT_ISOFS] filled at load -- with 4.4BSD-Lite2
  cd9660's node numbering, name handling and recording dates.  Both trees are
  vendored.
  
      mount_isofs /dev/cd0 /mnt
  
  Names are handed up as Lite2 hands them, "README.TXT;1" as readme.txt, and
  lookup takes either case and an optional ;version.  Every node is root's,
  mode 0555.  mount_isofs loads isofs.mod with modload when mount(2) answers
  ENODEV, as mount_prodos does.
  
  Upstream defects not carried: netbsd-0-9 numbered every node by its extent,
  so empty files were one node (Lite2's isodirino numbers a file by its
  directory record); its lookup passed iso_iget a pointer into a buffer it had
  released for `..'; it read an interleaved file's gaps as data (refused here
  with EIO); and Lite2 read a recording date's zone offset unsigned, so zones
  west of Greenwich were never applied.  Every block number, size and offset
  is a long, upstream's being int.
  
  readdir renders each 128 bytes of directory into one DIRBLKSIZ block, since
  FGX's getdirentries needs block-aligned offsets; a directory's stat size is
  that rendered length.  The module loader's bank table grows to eight
  ordinals for isofs.mod's bank.  Rock Ridge is not yet read.

- isofs: Rock Ridge names, modes, owners, times and symbolic links
  A volume whose root "." record opens with SP and carries an ER field naming
  Rock Ridge is read through its System Use fields: NM names, PX modes,
  owners and link counts, TF times, and SL symbolic links, which readlink
  returns.  A directory relocated past ISO 9660's eight levels is found where
  its CL field points, and its ".." follows PL to the parent it really has, so
  pwd climbs out of it.  CE continuation areas are followed.  This is
  4.4BSD-Lite2's cd9660_rrip.c; netbsd-0-9's read only the first NM field,
  ignored CE and assumed Rock Ridge on every volume.
  
  ER accepts RRIP 1.12's IEEE_P1282 and IEEE_1282 as well as RRIP 1.09's
  RRIP_1991A, the only identifier Lite2 knew; current mastering tools write
  the newer ones.  A Rock Ridge name longer than MAXNAMLEN (63) falls back to
  the ISO 9660 name, Lite2's own fallback for a name too long for its buffer.
  A Rock Ridge name is matched exactly, case and all.

- tools: the kernel listing parser reads the label column after the address
  parse_listing took the text after a line's LAST '|' as its label column.
  Merlin's absolute-address prefix puts a '|' in the operand, so
  `LDA |_Sys_IoctlCmd' read as a definition of _Sys_IoctlCmd at the LDA's
  address.  The first such line in listing order won: every module that bakes
  the symbol would have been given the wrong address, and the build identity
  the two generators compute disagreed ($E3F5 against the kernel's $F8A8).
  
  The label is now the first token of the column after the address, and a
  line whose column starts with white space carries no label.  A self-test
  holds both cases and runs with the other generators' self-tests.

- fcc: a scalar's initializer may sit in braces
  K&R A8.7: "The initializer for a pointer or an object of arithmetic type
  is a single expression, perhaps in braces."  fcc refused the braces at
  file scope ("brace-initializer requires int[N], ...") and failed to parse
  them in a block or as a static local.  SunOS eject.c's
  `char *default_dev = { "/dev/rfd0c" };' is the shape.
  
  All three declaration sites now take the braces off, parse the expression
  as before, and accept the trailing comma A8.7's grammar allows in a list.
  Fixture M37/bracescalar covers each site and reads the values back at run
  time.

- kernel: a CD-ROM takes another disc once it is unmounted, and ejects
  A CD-ROM row is marked DEV_FLAG_STALE when nothing holds the drive, and
  the next Blk_Read probes it again before trusting what attach recorded:
  the card is asked to rescan (CONTROL $1F, so its own partition and block
  size tables are rebuilt), then the sector size (STATUS $06) and the DIB,
  as at attach.  A drive found empty stays stale, so the read after a disc
  goes in probes once more; a drive empty at boot starts stale.  This is
  netbsd-0-9's cdopen (sys/scsi/cd.c), which checks the unit and loads its
  parameters on every open, done on the first read after the medium may
  have changed.
  
  What marks it is the block device's close.  spec_close's VBLK arm calls
  the bdevsw d_close Reno names there; netbsd-0-9's cdclose releases the
  drive (cd_prevent_unit(unit, PR_ALLOW, ...)), and FGX's half is
  KSVC_BLKSTALE, which marks the row and drops the block cache.  isofs and
  ProDOS unmounts now close their device first, as 4.4BSD-Lite2's
  cd9660_unmount and Reno's ufs_unmount do, which also drops the old disc's
  buffers.
  
  spec_ioctl gains Reno's block arm, `(*bdevsw[major(dev)].d_ioctl)', by
  the staged road kc_cdioctl uses: KSVC_BLKIOCTL carries netbsd-0-9's
  CDIOCEJECT (cdioctl, _IO('c', 24) less the size bits) to the card's
  CONTROL $04 and marks the row stale.  Anything else is ENOTTY.  A mounted
  disc cannot be ejected this way because it cannot be opened: spec_open
  answers EBUSY through mountedon.
  
  _dev_rawStatus/_dev_status gain _dev_call, the command in X, for the
  CONTROL calls.  kc_blkstale/kc_blkioctl live in modules/common/kc_blkdev.s,
  PUT by ufsdir.mod alone.
  
  The renumbering of units a rescan can cause, when a new disc has more
  ProDOS partitions than the last, is not handled.

- eject(1), from SunOS 4.1.3
  vendor/SunOS-4.1.3/usr.bin/eject.c, with its man page.  The devices are
  /dev/cd0 to /dev/cd3 (nicknames cd, cdrom, cd0-cd3) and the ioctl is
  CDIOCEJECT from a new <sys/cdio.h>.  FGX has no raw CD-ROM device, so the
  block device is opened, and try_unmount runs before the open because a
  block device with a filesystem mounted on it cannot be opened.  The mount
  table comes from getmntinfo(3) and the unmount is 2.11BSD's umount(2) on
  the special file.  -q reads the first block, since an empty drive opens
  here.  -f cannot eject a disc that will not unmount, which the man page's
  BUGS section says.

- block: an offline drive does not downgrade its bus
  A failed extended read cleared the bus's extended and multi-block flags
  for the rest of the boot, on any error, because a standard-only device
  that does not answer an unknown command times out with a bus or I/O error
  rather than BADCMD.  An empty CD-ROM answers a read with OFFLINE, so one
  read of an empty drive downgraded the card: the drive stayed unreadable
  after a disc went in, its 2048-byte sectors having no standard-call path,
  and every other device on the card fell back to single-block reads.
  
  OFFLINE ($2F, "The device is off line or no disk is in drive") and DISKSW
  ($2E, "Media has been swapped (extended calls only)") are answers only a
  device that took the call can give (Firmware Reference Table 7-6, p.156).
  Both _SP_ReadBlock's extended arm and _SP_ReadBlockN now return them as
  the read's EIO and leave the bus as it is; every other error downgrades
  it as before.

- eject(1) is registered in the provenance table
  A third-party row for src/userland/eject/eject.c, from SunOS 4.1.3
  vendor/SunOS-4.1.3/usr.bin/eject.c, and the SPDX marker the row names.

- block: an extended read that answers DISKSW is asked again
  DISKSW ($2E, "Media has been swapped (extended calls only)", Firmware
  Reference Table 7-6, p.156) reports a medium change to the first extended
  call that can see it.  The boot program reads with standard calls, so the
  kernel's first extended read -- the root mount's -- is that call.  Since
  OFFLINE and DISKSW became the read's EIO, a card giving that notice failed
  the root mount, and the boot ended with `init load failed: errno=$06'.
  Before, any extended error downgraded the bus and the standard retry read
  the block.
  
  _SP_ReadBlock now reissues an extended read that answers DISKSW, once; a
  second DISKSW in a row is taken as any other error and downgrades the bus.
  OFFLINE is the read's EIO only for a CD-ROM, whose empty drive answers it
  and whose 2048-byte sectors have no standard-call path; a disk's OFFLINE
  downgrades the bus, as every other error does.

- login(1): the login PATH carries /usr/fgx/bin
  login set PATH=:/bin:/usr/bin:/sbin, while init seeds the same default
  with /usr/fgx/bin, the system tool directory (dmesg, vmstat, slotscan,
  font, color and the rest).  A shell started by init found those tools by
  name; one started by login(1) did not, so dmesg was "not found" after a
  console login.
  
  2.11BSD's login sets PATH from _PATH_DEFPATH (usr/bin/login/pathnames.h:22,
  "/bin:/usr/ucb:/usr/bin:/usr/games:"), which names the system's own tool
  directory, /usr/ucb, beside /bin and /usr/bin.  login's PATH is now
  init's.

- rtcread: the battery clock's frame, as the kernel reads it at boot
  /testbin/rtcread prints the six bytes SYS_RTCREAD returns (Misc Tools
  ReadTimeHex): seconds, minutes, hours, the year less 1900, and the day and
  month counted from zero.  tod_init rejects a frame outside 1970-2099 with
  "Invalid time in real time clock", and this shows the frame it rejected.

- kernel: the DOC is quieted before interrupts are enabled
  The firmware's sound-interrupt vector ($E1002C) starts out at a system
  failure, $08FF unclaimedSndIntErr, until something claims it.  Sound_Init
  halted the DOC's oscillators only after the CLI in Toolbox_InstallHB, so an
  oscillator left with its interrupt enabled by whatever ran before the
  kernel could interrupt in between and stop the machine.  The boot failed
  that way intermittently on a IIgs with a TransWarp GS.
  
  Sound_Init now runs before the CLI, and after halting every oscillator,
  which clears its interrupt enable, it drains the Oscillator Interrupt
  register: an oscillator that had already reached the end of its
  wavetable keeps IRQ asserted until $E0 is read (Apple IIgs Hardware
  Reference pp.106-107, Table 5-3).

- boot: stage 1 quiets the DOC before anything can take an interrupt
  The firmware's sound-interrupt vector ($E1002C) starts out at a system
  failure, $08FF unclaimedSndIntErr.  A IIgs with a TransWarp GS stopped
  that way intermittently before the kernel was up, straight after the
  accelerator's power-on splash; a warm restart then booted normally.
  Stage 1 masks interrupts, but the firmware and Toolbox calls between it
  and the kernel run with whatever interrupt state they choose.
  
  Straight after its SEI, stage 1 now halts all 32 oscillators, which
  clears their interrupt enables, and reads the Oscillator Interrupt
  register until bit 7 says none is pending, discarding the first read as
  the DOC's one-cycle read lag requires (Apple IIgs Hardware Reference
  pp.106-107).  The Sound Control register's volume bits are kept.

- kernel: the super hi-res page is black before it is shown
  _ConfigureHardware turned on super hi-res and left the console to clear
  it at _BootScreen, so in between the display showed whatever the frame
  buffer, SCBs and palettes held.  On an unaccelerated IIgs that gap lasts
  seconds.  The page, SCBs and palettes ($E1:2000-$9FFF) are now zeroed
  first, which is black.

- dev: every SmartPort bus decides extended calls from its own card
  Blk_DetectCaps asked $CnFB and the devices' DIB subtypes of the boot bus
  alone, and _dev_registerBus left every other bus's flags at zero, so a
  second card was driven with standard calls whatever it supported.  A
  CD-ROM with 2048-byte sectors has no standard-call path, so on any card
  but the boot one it could not be read; a IIgs can hold an extended card
  and a standard one at once.
  
  _dev_enumBus now decides it for each further bus from the DIBs the walk
  reads anyway: the card's $CnFB bit 7, then every answering device's DIB
  subtype bit 7 (Firmware Reference p.142), with at least one answering
  and none lacking a DIB -- Blk_DetectCaps's rule.  A bus that qualifies
  gets BS_FLAG_EXT and BS_FLAG_MB and says so in the boot log, "spN:
  extended SmartPort".
  
  A CD-ROM's attach no longer asks for the DIB a second time: the first
  four bytes of the enumeration's DIB are kept across the block-size
  STATUS.  A card may take seconds over each STATUS to an empty drive.

- kernel: the console comes up before the storage probe
  The console started after Blk_Init and Dev_Init, so the attach lines
  reached the screen only in the ring replay, and a card that is slow to
  answer STATUS -- an empty CD-ROM drive behind an Apple High-Speed SCSI
  Card, for half a minute -- showed as a blank screen with nothing said.
  _BootScreen and the RAM floor check now run straight after the hardware
  summary, once the heap, the far bank and the boot program's font are in
  place, and each attach line appears as its device is found, as BSD's
  autoconfiguration prints them.

- kernel: the CPU speed is measured with interrupts enabled
  A TransWarp GS with its AppleTalk/IRQ option on "will slow down to the
  appropriate speed whenever the interrupts are disabled (the IRQ Disable
  flag is set)" (TransWarp GS User's Manual p.14).  _MeasureCPUSpeed ran
  under the boot SEI, so on such a card the boot line reported 2.5 MHz
  while user code, which runs with interrupts enabled, ran at 15.4; with
  the option off it read 15.4.
  
  The probe now enables interrupts for its two VBL periods and restores
  the boot's P after.  Nothing of FGX's is on the IRQ vector yet and stage
  1 has quieted the DOC; a firmware VBL interrupt, if one is armed, costs
  the count a few hundred cycles of the ~33 ms it spans.

- kernel: /dev/null reads and writes in bulk, as 2.11BSD's mmrw does
  /dev/null's chardev vtable had no d_read or d_write, so spec_chwrite
  moved every discarded byte through its own one-byte uiomove and a
  kc_cdwrite seam crossing, and a read found end of file the same way.
  Output to /dev/null cost more than output to a file: `od -c' of a 7.7 KB
  file took 27.1 s to /dev/null and 16.8 s to the root (#22).
  
  The bulk ops are 2.11BSD's mmrw minor 2 (usr/sys/pdp/mem.c:58-67): a
  read is end of file at once, and a write consumes every region whole --
  iov_base += c, iov_len -= c, uio_offset += c, uio_resid -= c -- stepping
  over an emptied region as mmrw's loop does.  A uio that runs out of
  regions with bytes still owed, mmrw's panic, is EIO.  include/chardev.s
  gains the uio_iov, uio_iovcnt and struct iovec offsets the walk reads.
  
  The same `od -c' now takes 15.8 s to /dev/null, and `cat' of the file
  0.3 s, from 3.0.

- dev: the boot log names every SmartPort device and each bus's call set
  Each attach line now carries the device's own ID string and type from its
  device information block (Firmware Reference p.123; type names from
  SmartPort Technical Note #4), as NetBSD 0.9's scsi_probe
  (sys/scsi/scsiconf.c) prints a target's inquiry strings and type:
  
      sp0 at slot 7
      sd0 at sp0 unit 1: <SEAGATEST225N1> hard disk, 63999 blocks (31999KB)
      cd0 at sp0 unit 2: <SONYCD-ROMCDU-80> CD-ROM, empty
      sp0: 2 units, extended SmartPort, multi-block reads
  
  Each bus prints its line before its units and a capability line after
  them: the unit count its port reports, and whether the block driver makes
  extended or standard calls to it. That line replaces the boot bus's
  "blk: extended SmartPort - multi-block read path" line, which only ever
  described the boot bus.
  
  A unit that answers but is not attached says why rather than vanishing:
  "sp1 unit 1: <DISK 3.5> 3.5-inch disk, no media", or "not attached,
  every unit number in use" past sd7 or cd3.
  
  The boot bus is enumerated like every other one, from unit 1; its unit 1
  is the boot disk Blk_Init registered as row 0. Blk_DetectCaps, its DIB
  walk and Blk_LogBootDev are gone, and the boot bus's extended-call
  decision is the same per-bus rule the others use.

- console: a write's full-screen scrolls move the pixels once (#27)
  Every newline at the bottom row moved the whole screen, about 30 KB of
  pixels, so output that scrolled cost one full-screen move per line.
  
  While a write(2) to the console is open (_Vc_WriteEnter, Con_WriteArm),
  a full-screen scroll now advances the cell ring and clears the new row
  as before but only counts the pixel move. Rendering skips the pixels and
  records the topmost row it would have drawn. When the write ends
  (_Vc_WriteLeave, Con_WriteDone), _Con_FlushPending moves the rows still
  on screen up by the count with one MVN and renders every row from the
  topmost exposed or dirty row down; a screenful or more renders the whole
  viewport. The other pixel writers, Con_Clear, a partial-region scroll
  and Con_ScrollRegionDown, flush first. A console with a module renderer,
  and one a task has claimed with SYS_SCREEN_CTL, are not armed.
  
  cat of a 1,100-line file takes 17.6 s in MAME instead of 68.7 s. A
  writer that sends one line per write(2) still pays a move per line.
  
  The conscroll test compares the framebuffer with the cell buffer after
  a scrolling cat, and fails when the flush moves the pixels without
  rendering the rows it exposed.

- console: a pending scroll outlives the write and is drawn 100 ms on (#27)
  A program that writes one line per write(2) -- anything on line-buffered
  stdio, which is every filter writing to a terminal -- still moved the
  whole screen once per line, because each write drew what it owed when it
  ended.
  
  Con_WriteDone now leaves a pending scroll pending, and the next write's
  scrolls add to it. _Vc_WriteLeave starts a clock the first time it sees
  one (_Con_StampScroll, _kConPendTick), and _Con_DrainScroll, called
  beside _Tty_DrainOutPend at every syscall return and in swtch's idle
  loop, draws it through the new Con_DrainPending once it is
  CON_SCROLL_TICKS (6) old. The screen is current within 100 ms of the
  last write with nothing reading the console; any other render state
  stops the clock.
  
  sed -n 1,400p of a man page takes 25.2 s in MAME instead of 40.0 s, and
  cat of 1,100 lines 16.1 s instead of 17.6 s.
  
  conscroll and conpaint both fail with the drain disabled.

- more(1): the page goes out through stdio, not a write(2) per byte
  putch() wrote every byte of the page with its own write(1, &c, 1), so a
  page cost one system call per character. It is putchar() now, as 2.11BSD
  more's putch() is (usr/ucb/more/more.c), the --More-- prompt goes through
  fputs(), and stdout is flushed before the key is read, as upstream's
  prompt() does. One 784-byte page went from 4.0 s to 1.1 s in MAME, 0.7 s of
  which is starting more and clearing the screen.

- console: erasing the whole screen does not repaint blank cells
  ESC[2J cleared the super hi-res page to the background color and then
  rendered every cell, all of them blank. A blank cell draws only its
  background unless inverse or underline marks it, so the repaint now runs
  only for those attributes, or when a module's renderer owns the screen.
  A clear(1) takes 0.2 s instead of 0.3 s in MAME.


### Documentation

- The root and fgx accounts' default password, fgx
  CONFIGURING.md gains a "Logins and passwords" section: the console is a root shell, the other consoles and telnet ask for a login, and both root and fgx have the password fgx; change them with passwd(1) before networking or telnet.  The README's first-boot note names the password.

- Mount_isofs(8), and CD-ROMs mount as ISO 9660
  mount_isofs(8) describes the command, name translation, Rock Ridge and what
  is not read: Joliet names, a disc's later sessions and interleaved files.
  CONFIGURING.md's CD-ROM paragraph says an ISO 9660 disc mounts with it, and
  modules.md lists isofs.mod in bank ordinal 7.

- The scanline console's phases 2-4 are deferred; the scroll batching is in (#27)

### Tests

- testdata: colours.ans, an 80x25 chart of every colour pair the card shows
  /testdata/colours.ans fills the Second Sight card's console with the 16 x 16
  matrix of colour pairs, each cell labelled with its VGA attribute byte
  bg<<4|fg, written as ANSI.SYS art writes them: 30-37 and 40-47, bold for a
  bright foreground and blink for a bright background (iCE colour).  Beside
  each row is its colour as a foreground in code page 437 blocks; below are the
  shade ramp in all sixteen colours, samples of SGR 7, 4, 38;5, 48;2 and
  90-107, single-line box drawing, half blocks and the high glyphs, inside a
  double-line box.
  
  Lines end in CR LF, since ansicat sets LLITOUT, and none reaches column 80;
  the last row has no line end, so the screen does not scroll.  A ^Z and a
  SAUCE record (80x25, iCE colour) follow.  tools/mkcolours_ans.py writes it.
  
      ansicat /testdata/colours.ans > /dev/ttyv3
  
  ansi.ans stays as ssansi's fixture: its rows are built so each lands on one
  attribute byte the check script can read.

- testdata: the color chart leaves the last row to the prompt and shows the graphics block
  colours.ans now ends after row 23 with a line end, so the shell's prompt
  lands on row 24 and the screen does not scroll; it had ended on row 24
  with none, the prompt began at column 79, and the title bar scrolled off.
  
  The box's second row is code page 437's whole graphics block, $B0-$DF,
  then $F0-$FE, in place of the accented letters and Greek.  The SGR samples
  are labelled in words (256-color, 24-bit, aixterm fg/bg) rather than by
  their parameters, which read as unparsed sequences.  Black's name in the
  right-hand column is shown in white, since black on black cannot be read.

- tests: isofs mounts a Rock Ridge volume and reads it
  tests/isofs mounts tools/testdata/isofs/rrtest.hdv on /dev/sd1 with
  mount_isofs and checks Rock Ridge names, a name past MAXNAMLEN falling back
  to its ISO 9660 name, a PX mode, an SL link, a directory of several blocks,
  a file across seven sectors, and a directory Rock Ridge relocated past eight
  levels, in and out again with pwd.  With Rock Ridge detection turned off,
  seven of its arms go red.
  
  The volume is written by pycdlib, an independent writer, and committed with
  the script that regenerates it.  It is padded with 16 zero sectors, as
  mkisofs and xorriso pad: a volume's last sector reads as an I/O error on
  MAME's Apple SCSI CD-ROM.

- tests: specops holds the block switch's close and ioctl to their driver
  spec_close's VBLK arm now ends in the driver close, kc_blkstale, and
  spec_ioctl's in kc_blkioctl.  The fixture stubs both with call counters:
  a last close reaches the driver with its own dev (160, 161), a close while
  an alias still holds the device does not (166), and an ioctl returns the
  driver's answer, 0 or ENOTTY, so no constant passes both (162-165).
  Section 7's note that the last-close branch was unobservable goes, now
  that the branch has a driver to call.

- tests: exit_on_prompt can settle before the final dump (#27)
  The console draws a pending scroll up to 100 ms after the last write, so
  a check that reads the framebuffer at exit could find the sentinel in
  the CharBuf before the pixels caught up. exit_on_prompt takes
  settle_frames, the frames to run on after the count is reached before
  the final dump; conscroll settles 30.


## [2.1.0] - 2026-10-20

### Build

- A zone written into .fgx_tz after the first build is used
  gen.py named .fgx_tz as a regen input only when the file existed when it
  ran, so a .fgx_tz created after the first build was never read: the
  image kept a UTC /etc/localtime until gen.py was re-run by hand.  gen.py
  now creates an empty .fgx_tz when there is none -- empty is UTC, as
  absent was -- and always names it as an input, so writing a zone into it
  regenerates build.ninja.

- /etc/version no longer reads dirty on a clean tree
  make_ufsboot.sh appends `+' to /etc/version when git sees untracked
  files, and it runs inside ninja, which holds .ninja_lock in the source
  root for the whole build.  .ninja_lock was not ignored, so every image
  was stamped dirty -- the published fgx-2.0.0.fs says `v2.0.0+'.  It is
  ignored now; a fresh clone's image reads v2.0.0-18-ge0760c4.


### Changed

- kernel: the IIgs clock is not written back unless asked
  machdep.disable_rtc_set is 1 by default.  FreeBSD 2.2.8 declares it
  `int disable_rtc_set;' (sys/i386/isa/clock.c:101), so 0, and resettodr()
  (clock.c:776) writes the battery clock from settimeofday(2) and from a
  write to machdep.adjkerntz.  On a IIgs that clock belongs to the machine
  and GS/OS reads it too: with an image in the wrong zone, a time set by
  ntpd or date(1) was written into it hours out, and adjkerntz -i wrote it
  at every boot.  Clearing the variable restores FreeBSD's write-back.
  
  At a daylight saving change, adjkerntz -a now moves the kernel's offset
  and leaves the IIgs clock as it was; adjkerntz(8), date(1) and
  settimeofday(2) state the divergence.

- boot: hardware modules, inetd and ntpd are turned on in /etc/rc.local
  /etc/rc loads what every machine needs -- ld, net (sockets and pipe(2)),
  ramdisk (it finds the Control Panel's RAM disk itself), pty, klog, fpsim
  -- and sources /etc/rc.local last, as 2.11BSD's rc ends with
  `/etc/rc.local' (usr/etc/rc).  rc.local ships with serial, bpf, sscon,
  cda, inetd and ntpd commented out, as 2.11BSD's usr/etc/rc.local ships
  `#timed'; removing the `#' turns one on at the next boot.  It is sourced
  rather than run, so it sees $INET from /etc/netstart without an export.
  inetd, which served telnet as root from /testbin on every image, now
  starts only from rc.local and only with a network.
  
  When /etc/localtime is UTC and /etc/wall_cmos_clock exists, rc says the
  zone is not set and that the IIgs clock is being read as UTC.
  
  modload.conf lists the same defaults, with the optional modules named in
  comments.  check_modload_lists.py reads rc.in followed by rc.local, as rc
  runs them, so an rc.local line turned on without its modload.conf entry
  fails the build.
  
  The suite tests the optional devices and daemons, so run.py stages
  tools/mame_test/rc.local, which turns all of them on, over /etc/rc.local
  before every test's own stage_files, and hashes it into the verdict key.
  modimage_check.py takes the modules that file loads into its roster, so
  the loaded-image comparison covers the same ten modules as before.

- ramdisk: the formatter's writes set the block latches Blk_Write would
  _RamDisk_WriteDirBuf enters _RamWrBody directly rather than through
  Blk_Write, and the body reads _blkCurHi and _blkCurBufBank, which
  Blk_Read and Blk_Write latch per call and leave set.  A UFS read before
  the module loaded had left the vfs_bio arena's bank latched, so the
  directory was copied from that bank instead of _fsDirBuf: the format
  reported success, set FormatFlag, and left block 2 all zeros, which
  mount_prodos then refused as "not a ProDOS volume".  The writes now
  clear _blkCurHi, _blkCurBufBank and _blkSrcPool first, as Blk_Write does
  for a 16-bit block in the kernel bank.

- ramdisk: battery RAM decides; the ROM's own MakeDisk on an 8 MB ROM 03
  ramdisk.mod allocated a 1 MB buffer of its own on every boot, whatever
  the Control Panel said: it read rdMinRam and then clamped to a 1 MB
  floor, so a machine with no RAM disk configured got one anyway.  It now
  follows GS/OS 6.0.1:
  
  - adopt the buffer at the bank-$E1 rendezvous (ram5.aii Startup:
    "see if there is a RAMdisk installed or not");
  - if there is none, have the ROM make it where ProBoot.src's CreateRAM5
    does -- ROM 3, no RAM5 handle, MaxDiskParm ($E102F7) non-zero and
    NumBanks ($E11624) >= $80, "a ROM 3 bug that fails to create RAM5 if
    you have 8 Megs of RAM" -- by its entry: A = $81, B = $E1, a 32-byte
    DP frame, JML $FC/14D1 with a pushed RTL and $00BC-1 for MakeDisk's
    RTS.  CreateRAM5 then resets the machine; this carries on and adopts;
  - mark an empty Pascal RAM5 unformatted (ram5.aii NukeIfEmptyPascal:
    block 2 word 0 = 0, +$006 = $5204, +$010 file count = 0);
  - otherwise log `ramdisk: none' and make nothing.
  
  The disk is formatted by RamDisk_Format, not by the ROM.  ram5.aii's
  FormatIfNeeded calls $FC/159D from inside GS/OS; called from FGX it
  writes an empty Pascal volume (measured: block 2 reads
  00 00 06 00 00 00 04 'RAM5', FormatFlag $FFFF).
  
  Measured on MAME's 8 MB ROM 03 with BRAM $36/$37 = 8: `ramdisk: 512
  blocks @ bank $38 (made)', 256 KB as asked.  With BRAM $36/$37 = 0:
  `ramdisk: none'.
  
  The disk registers at device row 8, the first row no /dev/sdN node
  names, so /dev/ram0 always names it.  Not the last row: a mount on rows
  29..31 crashes the machine (rows 1, 7, 8, 15, 16, 23, 24, 27 and 28
  mount; 29, 30 and 31 jump to $00:0000), which is a block-layer defect of
  its own.
  
  RamDisk_Create and the 1 MB floor are gone; ROMVersion joins the
  module's kernel exports and _kFgxUserID leaves them.

- boot: the RAM disk is mounted writable on /ram5 as /dev/ram0
  gen.py mints `b /dev/ram0 8', the row ramdisk.mod registers in, and the
  image carries the mount point /ram5.  /etc/rc runs
  `mount_prodos -o write /dev/ram0 /ram5' after the modules load, and says
  `ram5: /dev/ram0 mounted on /ram5' when it does; on a machine with no
  RAM disk the device row is empty, the mount fails, and nothing is said.
  mount_prodos loads prodos and prodosw itself.  CONFIGURING.md describes
  the RAM disk; modules.md gives the module's behaviour.

- ramdisk: the rows-29..31 note names its issue, flux-gs/fgx#4
- mount: the listing names each filesystem's type
  mount(8) with no arguments now prints the type first inside the
  parentheses, as the 4.4BSD-Lite2 descendants (FreeBSD, macOS) do:
  
      /dev/sd0 on / (ufs)
      /dev/sd1 on /mnt (prodos, read-only)
  
  2.11BSD's prmount (vendor/2.11BSD/usr/sbin/mount/mount.c) prints only
  the flags, which left a ProDOS mount looking like a UFS one; Reno's and
  netbsd-0-9's do the same.  The name is f_type from getmntinfo(3) through
  upstream's own INITMOUNTNAMES table, which badvfstype already used.
  mount -v prints the same line.
  
  ufsmount's needles now carry `(ufs', and pdmount lists its read-only
  ProDOS mount.

- rc: comments at 2.11BSD's density
  /etc/rc keeps every command and drops the essays, so it reads like
  2.11BSD's usr/etc/rc: a header, upstream's own fsck warning, and a
  one-line note where a step is not self-explanatory.  229 lines to 93.
  
  What the removed comments said, for the record:
  - ld.mod and ldload run first because every program but the static set
    (init, getty, login, sh, fsck, mount, ifconfig, modload, ldload,
    test, echo, hostname, mv, tar, ln) is dynamic.  ldload exiting 1 (a
    listed library failed) lets the boot go on; any other status stops rc
    before fsck, and init starts the static console shell regardless.
  - fsck runs without upstream's -t /_FSCK_TMP_FILE: that names a scratch
    file on the root, which setup() refuses, and the maps for a
    32000-block root fit in memory.
  - The root is mounted read-only by the kernel (ufs_mountroot), so the
    remount follows the check.  utmp is emptied here, as 4.3BSD-Reno's rc
    does, because 2.11BSD's init cannot do it on a read-only root.
  - rc runs with "/" as its descriptors (2.11BSD init.c runcom), so each
    visible line names /dev/console.
  - rc waits up to 15 s for /var/run/syslog.pid so syslogd's replay of the
    boot log is not delivered to the console shell a second time.

- etc: rc.local, modload.conf and netstart at 2.11BSD's density
  The same trim as /etc/rc: every command and every commented-out
  command stays, the explanations go to a line or none.
  
  What the removed comments said, for the record:
  - modload.conf is read by /etc/rc, not the kernel: Mod_LoadConf reads
    through Fs_ReadN, which answers EBADF for a root descriptor.
    tools/check_modload_lists.py holds rc's two modload lines and
    rc.local's enabled ones equal to it.  ufsprobe is last because it
    runs its cases from mod_init and some need pty.mod; the image carries
    it only in a probe build.
  - klog is /dev/klog, the kernel log ring syslogd reads; fpsim is fcc's
    soft double as one shared copy, without which a double operation
    raises SIGILL.
  - rc.local is sourced, so it sees $INET from netstart; FGX never writes
    the IIgs clock back (machdep.disable_rtc_set is 1).
  - netstart's INET mirrors 2.11BSD's; dhclient exits nonzero without a
    lease, and renewing means running dhclient again.

- ci: every push to main publishes its image on a rolling pre-release
  The build now also runs on pushes to main, and a third job publishes the
  image as fgx-main-<sha>.fs on the `main-latest' pre-release.  It moves
  that tag to the commit, and deletes all but the newest three images
  (MAIN_KEEP).  Release assets are stored outside git, so this does not
  grow the repository.  The vX.Y.Z releases are unchanged, and a
  pre-release is never GitHub's Latest, so the newest version stays the
  default download.
  
  Checkout fetches full history, so /etc/version in a main image is
  `git describe' against the v* tags (v2.0.0-5-g712de08) rather than a
  bare hash.
  
  The README links the pre-release; RELEASING.md and BUILDING.md describe it.


### Documentation

- Configuring a machine -- the clock and time zone, devices, services
  docs/CONFIGURING.md covers what a running machine starts and how to
  change it: choosing a time zone (/etc/localtime from
  /usr/share/zoneinfo), why the IIgs clock is read as UTC until then, the
  battery-clock policy and daylight saving, turning on ntpd; the serial,
  bpf, sscon and cda modules and how to load them from /etc/rc.local; and
  inetd.  The README points first-boot users at it, and BUILDING describes
  .fgx_tz and FGX_TZ for building an image with a zone already set.

- Support terms, the community channel, and a bug report form
  The README says no support is offered or implied, that questions get an
  answer where possible and contributions are welcome, and points to #fgx
  on the Apple II Infinitum Slack for discussion and to GitHub Issues for
  bugs.  A new "Reporting bugs" section lists what a report needs.
  
  .github/ISSUE_TEMPLATE/bug_report.yml is a GitHub issue form asking for
  the FGX version (image file and uname -r), where it happens, the full
  hardware description or emulator settings, a detailed explanation, the
  steps to reproduce it in Ample or MAME, and screenshots.  config.yml
  keeps blank issues and links questions to the Slack.
  
  CONTRIBUTING.md points to the form and the channel, and no longer says
  CI builds only releases: it builds release tags and main.

- The README's acknowledgements
  FGX's own code was written from scratch, almost entirely with Claude
  Code, with feedback from ChatGPT.  The section thanks those who published
  Apple IIgs source as reference material, above all the GNO Consortium;
  the developers and maintainers of 2.11BSD; the BSD heritage of
  4.3BSD-Reno and NetBSD; SunOS 4.1.3, whose shared library model FGX
  adopted; and the [cCc] crew and extended family.

- The issue templates name the Slack channel without linking its signup page
  The bug form's note says to ask questions in #fgx on the Apple II Infinitum Slack as plain text, and config.yml drops its contact link, which GitHub cannot show without a URL.

- The README and CONTRIBUTING name the Slack channel without linking its signup page

### Tests

- Per-test battery RAM, and a test for the Control Panel RAM disk
  A manifest's "bram" key sets battery-RAM parameters ({"36": 8, ...},
  the Toolbox Reference's numbers) in the test's copy of the BRAM and
  rewrites the checksum the ROM checks: the 16-bit sum of bytes 0..251,
  then the sum ^ $AAAA, as gsport's clk_calculate_bram_checksum computes
  it.  The self-test reproduces the checksum stored in a real BRAM, and
  fails when the loop steps by two.
  
  ramdisk asks for a 256 KB RAM disk and checks that it is made, mounted
  on /ram5 as /dev/ram0, and written: the staged rc.local writes /ram5/b1
  during the boot.  It does not cover keeping the disk across a soft
  reboot; a warm_reset_frame run made the disk again and stalled at the
  system logger, and that is unmeasured here.


## [2.0.0] - 2026-10-15

The first release from the GitHub repository, whose history starts here.
Earlier history is archived; references of the form `apple/fgx#N` in the tree
name issues in that earlier tracker.

### Changed

- **Breaking:** binaries and disk images from 1.x do not run unchanged.  The
  syscall ABI and the on-disk layout changed in this series; rebuild from
  source and boot `fgx-2.0.0.po`.
- The root filesystem is 2.11BSD's UFS, mounted through 4.3BSD-Reno's VFS,
  buffer cache and name cache, and checked by `fsck` at boot.
- Programs share their code, and the C library and libfgx are shared
  libraries loaded once at boot; libcurses, libtermlib and libutil load when
  a program first needs them.
- Up to 32 processes; job control and the full BSD signal set; TCP, UDP and
  Unix-domain sockets; syslogd, cron and inetd (telnet logins) start at boot.
- A Second Sight card adds a fourth virtual console (Option-4).
