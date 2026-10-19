/* for_step_global_ptr: a for-loop STEP `Cursor++` where Cursor is a GLOBAL
 * pointer (tcsh ed.inputl `for (Cursor = argptr; ...; Cursor++)`, Cursor a
 * Char*).  build_for_init_or_step rejected a global pointer step ("only
 * int/char/long supported") though a LOCAL pointer step already worked and the
 * S_POSTINC_VAR_STMT G36 path already bumps a global pointer.  Lifted the gate
 * (stride = sizeof(*g)) and mirrored the G36 offset-bump-in-home into the
 * S_PREINC_STMT walk (bank preserved via emit_store_global_int).  -> 42. */
char  str[6];
char *Cursor;

int
main()
{
    int r;

    str[0] = 1; str[1] = 1; str[2] = 1; str[3] = 0;   /* 3 non-zero */
    r = 0;

    for (Cursor = str; *Cursor != 0; Cursor++)
        r += 14;                                       /* 3 * 14 == 42 */

    return r;                                          /* 42 */
}
