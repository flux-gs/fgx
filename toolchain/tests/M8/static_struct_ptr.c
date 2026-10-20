/* static_struct_ptr: a static-local struct POINTER, initialised to 0 -- tcsh
 * tw.parse `static DIR *dir_fd = 0`.  parse_static_local rejected struct-array
 * AND struct-pointer locals; the pointer case is just a 4-byte global (the
 * struct id is recorded for later deref typing, and the struct may be opaque).
 * -> 42. */
struct D { int x; int y; };
struct D gd;

int
get()
{
    static struct D *dp = 0;      /* static struct-ptr, NULL-initialised */
    if (dp == 0) dp = &gd;        /* first call: bind to gd */
    dp->x = 40;
    dp->y = 2;
    return dp->x + dp->y;         /* 42 */
}

int
main()
{
    return get();
}
