# DOCVu 2.0 -- a classic desk accessory, vendored as a BINARY

DOCVu 2.0 by Brian Ballweber (1993-94) shows the Ensoniq DOC's 32
oscillators live, in Super Hi-Res, from the Ctrl-OA-Esc menu.  FGX ships it
in /usr/fgx/cda, where /etc/rc installs it with loadcda(8), so it can watch
ntpplay(1) play.

Its terms, from its own documentation (`DOCVu.Dox`, verbatim):

    DOCVu is -FREEWARE- distribute freely, but do not sell...

No source was published.  Nothing here is built; the files are staged onto
the disk image as they are.

## What is here

| File | What | SHA-256 |
|------|------|---------|
| `docvu2.shk` | the ShrinkIt archive as distributed | `524f74a73d5a361b7b8ace0cb9329ea737b440ce3defa8840a239b64e59ad7e4` |
| `DOCVu.CDA` | the archive's DOCVu.CDA data fork, ProDOS type $B9 aux $00DE | `7b36c769e6703a9b725b58c263e32c38e8586c60249969e2d5db556af29349b7` |
| `._DOCVu.CDA` | its resource fork, 45,801 bytes, in an AppleDouble file | `9b704b148516a2752b3f6418794773e881ce6534d86bae2be6d85fe5bc56ddee` |
| `DOCVu.Dox` | the archive's documentation, CR line endings | `da291edc8fb20b423eca1e53d5f4646591ea49368160b13ae48a199c1999dac1` |

The two forks came out of `docvu2.shk` identically through two extractions
(a raw `_rsrc_` file and a CiderPress-style `#b900der` name, which is also
where the type and aux type come from).  The resource fork inside
`._DOCVu.CDA`, from byte 82 on, hashes to
`62b8908a262f684b511648cb7b9bb3acdfdb442731ef8ccff3e9b2ac92acf132`, the
same as the extracted fork.

`._DOCVu.CDA` is the RFC 1740 AppleDouble form FGX's ProDOS filesystem
presents for a forked file (src/kernel/vfs/prodos.h): magic $00051607,
version $00020000, Finder Info (entry 9, 32 bytes at offset 50) and then the
Resource Fork (entry 2 at offset 82).  The Finder info is what GS/OS's HFS
FST makes of a ProDOS type its table does not name: type `p` $B9 $00 $DE,
creator `pdos`.
