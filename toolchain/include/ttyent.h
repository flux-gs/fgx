/* ttyent.h - /etc/ttys database, 2.11BSD shape.
 *
 * FGX notes: there is no ty_window (no window system) and no quoted-getty
 * syntax; ty_getty is a single command path.  Both fields exist for API
 * compatibility, matching how pwd.h keeps pw_class/pw_change/pw_expire.
 */
#ifndef _TTYENT_H_
#define _TTYENT_H_

#define _PATH_TTYS "/etc/ttys"

#define TTY_ON     0x01    /* enable logins (init runs ty_getty) */
#define TTY_SECURE 0x02    /* root may log in on this line */

struct ttyent {
    char *ty_name;      /* line name, e.g. "ttyv0" */
    char *ty_getty;     /* command init runs on the line */
    char *ty_type;      /* terminal type -> TERM */
    int   ty_status;    /* TTY_ON | TTY_SECURE */
    char *ty_window;    /* always "" on FGX */
    char *ty_comment;   /* always "" on FGX */
};

struct ttyent *getttyent();
struct ttyent *getttynam();
int setttyent();
int endttyent();

#endif
