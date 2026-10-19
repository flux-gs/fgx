/* ---- /etc/ttys database ---------------------------------------------------
 * Same shape as the pwent block above: one static FILE, one line buffer, one
 * returned struct.  Whitespace-separated rather than colon-separated, and the
 * status column is a word list ("on secure") rather than a single token, so
 * the field splitter differs from _pw_field.
 */
#define _TTY_LINEMAX 128

static FILE         *_tty_fp;
static struct ttyent _tty_ent;
static char          _tty_line[_TTY_LINEMAX];

/* Split off the next whitespace-delimited token, NUL-terminate it in place,
 * and advance *bp past it.  Returns NULL at end of line. */
static char *_tty_field(bp)
    char **bp;
{
    char *s, *p;

    p = *bp;
    while (*p == ' ' || *p == '\t')
        p++;
    if (*p == '\0')
        return (char *)0;
    s = p;
    while (*p != '\0' && *p != ' ' && *p != '\t')
        p++;
    if (*p != '\0')
        *p++ = '\0';
    *bp = p;
    return s;
}

int setttyent()
{
    if (_tty_fp != (FILE *)0)
        rewind(_tty_fp);
    else
        _tty_fp = fopen(_PATH_TTYS, "r");
    return _tty_fp != (FILE *)0;
}

int endttyent()
{
    if (_tty_fp != (FILE *)0) {
        fclose(_tty_fp);
        _tty_fp = (FILE *)0;
    }
    return 1;
}

struct ttyent *getttyent()
{
    char *bp, *cp;

    if (_tty_fp == (FILE *)0 && !setttyent())
        return (struct ttyent *)0;
    for (;;) {
        if (fgets(_tty_line, _TTY_LINEMAX, _tty_fp) == (char *)0)
            return (struct ttyent *)0;
        cp = strchr(_tty_line, '\n');
        if (cp != (char *)0)
            *cp = '\0';
        bp = _tty_line;
        _tty_ent.ty_name = _tty_field(&bp);
        if (_tty_ent.ty_name == (char *)0
         || _tty_ent.ty_name[0] == '#')
            continue;                  /* blank or comment */
        _tty_ent.ty_getty = _tty_field(&bp);
        if (_tty_ent.ty_getty == (char *)0)
            continue;                  /* short line: skip it */
        _tty_ent.ty_type = _tty_field(&bp);
        if (_tty_ent.ty_type == (char *)0)
            _tty_ent.ty_type = "";
        _tty_ent.ty_status = 0;
        while ((cp = _tty_field(&bp)) != (char *)0) {
            if (strcmp(cp, "on") == 0)
                _tty_ent.ty_status |= TTY_ON;
            else if (strcmp(cp, "secure") == 0)
                _tty_ent.ty_status |= TTY_SECURE;
            /* "off" and unknown words simply leave the bit clear */
        }
        _tty_ent.ty_window = "";
        _tty_ent.ty_comment = "";
        return &_tty_ent;
    }
}

struct ttyent *getttynam(nam)
    char *nam;
{
    struct ttyent *t;

    if (!setttyent())
        return (struct ttyent *)0;
    while ((t = getttyent()) != (struct ttyent *)0)
        if (strcmp(nam, t->ty_name) == 0)
            break;
    endttyent();              /* the line buffer outlives the close */
    return t;
}

