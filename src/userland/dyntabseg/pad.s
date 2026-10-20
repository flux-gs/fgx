* Fills dyntabseg's code segment 0 to within a few bytes of 64 KB, so the
* binder's tables cannot fit there.  build_dynso.sh replaces PADSIZE with a
* size measured from a first link.
_dyntab_pad     DS      PADSIZE
