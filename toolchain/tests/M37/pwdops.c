/* The passwd database: getpwnam/getpwuid/getpwent over the REAL /etc/passwd.
 *
 * pwd.h used to describe a synthetic single entry ("FGX is single-user with no
 * /etc/passwd").  That is no longer true: struct passwd is now the 2.11BSD shape
 * and libc parses the classic seven-field file, because login/getty want the
 * real fields rather than a stub.
 *
 * What this pins, beyond "it returns something":
 *   - the FIELD SPLIT is right, not just field 0.  A parser that mis-counted
 *     colons would still return an entry, so uid, dir AND shell are all checked
 *     -- dir and shell are the last two fields, so an off-by-one anywhere in the
 *     split shows up here.
 *   - a MISSING user yields NULL.  Easy to get wrong by returning the last line
 *     read, and callers branch on NULL.
 *   - getpwent() enumerates exactly the real entries: the shipped file carries
 *     '#' comments (an FGX tolerance) and they must NOT surface as users.
 *   - the returned struct survives endpwent(), which closes the file -- the BSD
 *     contract is that it stays valid until the next call, and it points into a
 *     static line buffer to make that true.
 *
 * FGX-only (MAME oracle): reads the boot disk's /etc/passwd.  8+6+6+6+8+4+4 = 42.
 */
#include <pwd.h>

int main()
{
    struct passwd *pw;
    int r = 0, n = 0;

    pw = getpwnam("root");
    if (pw != (struct passwd *)0)                      r += 8;
    /* checked AFTER endpwent() ran inside getpwnam -- the struct must outlive it */
    if (pw != (struct passwd *)0 && pw->pw_uid == 0)   r += 6;
    if (pw != (struct passwd *)0 &&
        strcmp(pw->pw_dir, "/root") == 0)              r += 6;
    if (pw != (struct passwd *)0 &&
        strcmp(pw->pw_shell, "/bin/sh") == 0)          r += 6;

    pw = getpwuid(0);
    if (pw != (struct passwd *)0 &&
        strcmp(pw->pw_name, "root") == 0)              r += 8;

    if (getpwnam("nosuchuser") == (struct passwd *)0)  r += 4;

    setpwent();
    while (getpwent() != (struct passwd *)0)
        n++;
    endpwent();
    if (n == 1)                                        r += 4;

    return r;
}
