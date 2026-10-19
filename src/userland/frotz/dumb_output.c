/* SPDX-License-Identifier: GPL-2.0-or-later
 * FGX-Provenance: frotz 2.44 (vendor/frotz-2.44/src/dumb/dumb_output.c)
 *   Ported from Stefan Jokisch's Frotz 2.44 (the Unix maintenance
 *   line), if-archive infocom/interpreters/frotz/old/frotz-2.44.tar.gz.
 *   The upstream copyright header follows.  See docs/PROVENANCE.md.
 */
/* dumb-output.c
 * $Id: dumb-output.c,v 1.2 2002/03/26 22:52:31 feedle Exp $
 *
 * Copyright 1997,1998 Alfresco Petrofsky <alfresco@petrofsky.berkeley.edu>.
 * Any use permitted provided this notice stays intact.
 */

#include "dumb_frotz.h"

extern f_setup_t f_setup;   /* FGX delta: ONE definition (dumb_init.c) --
                             * no common-block merge in this linker */

/* FGX delta: the teletype render toggles (line numbers/types, picture
 * boxes, reverse-video method, output compression) are gone with the
 * teletype realize path.  visual_bell (os_beep) and plain_ascii
 * (os_char_width / os_display_char) still apply on a VT102. */
static bool visual_bell = TRUE;
static bool plain_ascii = FALSE;

static char latin1_to_ascii[] =
  "    !   c   L   >o< Y   |   S   ''  C   a   <<  not -   R   _   "
  "^0  +/- ^2  ^3  '   my  P   .   ,   ^1  o   >>  1/4 1/2 3/4 ?   "
  "A   A   A   A   Ae  A   AE  C   E   E   E   E   I   I   I   I   "
  "Th  N   O   O   O   O   Oe  *   O   U   U   U   Ue  Y   Th  ss  "
  "a   a   a   a   ae  a   ae  c   e   e   e   e   i   i   i   i   "
  "th  n   o   o   o   o   oe  :   o   u   u   u   ue  y   th  y   "
;

/* h_screen_rows * h_screen_cols */
static int screen_cells;

/* The in-memory state of the screen.  */
/* FGX delta: the dumb interface packed [style|char] in a short and
 * teletyped the grid.  The FGX console is a VT102, so a cell also
 * carries a frotz colour pair and the grid is realized by a full-screen
 * ANSI repaint (screen_paint) with absolute cursor motion and coalesced
 * SGR -- see the block above screen_paint.  Layout: char 0-7, Z-machine
 * style bits 8-11 (REVERSE/BOLDFACE/EMPHASIS/FIXED_WIDTH), fg 16-19,
 * bg 20-23; a long holds it. */
typedef unsigned long cell;
static cell *screen_data;

static cell make_cell(int style, int fg, int bg, char c) {
    return ((unsigned long)(bg & 15) << 20) | ((unsigned long)(fg & 15) << 16)
         | ((unsigned long)(style & 15) << 8) | (unsigned long)(0xff & c);
}
static char cell_char(cell c)  { return c & 0xff; }
static int  cell_style(cell c) { return (c >> 8) & 15; }
static int  cell_fg(cell c)    { return (c >> 16) & 15; }
static int  cell_bg(cell c)    { return (c >> 20) & 15; }

static int current_style = 0;
static int current_fg = DEFAULT_COLOUR, current_bg = DEFAULT_COLOUR;

/* Which cells have changed (1 byte per cell).  */
static char *screen_changes;

static int cursor_row = 0, cursor_col = 0;

static cell *dumb_row(int r) {return screen_data + r * h_screen_cols;}

static char *dumb_changes_row(int r)
{
    return screen_changes + r * h_screen_cols;
}

int os_char_width (zchar z)
{
    if (plain_ascii && z >= ZC_LATIN1_MIN && z <= ZC_LATIN1_MAX) {
	char *p = latin1_to_ascii + 4 * (z - ZC_LATIN1_MIN);
	return strchr(p, ' ') - p;
    }
    return 1;
}

int os_string_width (const zchar *s)
{
    int width = 0;
    zchar c;

    while ((c = *s++) != 0) {
	if (c == ZC_NEW_STYLE || c == ZC_NEW_FONT)
	    s++;
	else
	    width += os_char_width(c);
    }
    return width;
}

void os_set_cursor(int row, int col)
{
    cursor_row = row - 1; cursor_col = col - 1;
    if (cursor_row >= h_screen_rows)
	cursor_row = h_screen_rows - 1;
}

/* Set a cell and update screen_changes.  */
static void dumb_set_cell(int row, int col, cell c)
{
    dumb_changes_row(row)[col] = (c != dumb_row(row)[col]);
    dumb_row(row)[col] = c;
}

void dumb_set_picture_cell(int row, int col, char c)
{
    /* FGX delta: no PICTURE_STYLE plane -- FGX has no graphics, so the
     * ascii outline-box chars store as ordinary cells (only reached when
     * a story actually has picture data, which text games do not). */
    dumb_set_cell(row, col, make_cell(0, current_fg, current_bg, c));
}

/* Copy a cell and copy its changedness state.
 * This is used for scrolling.  */
static void dumb_copy_cell(int dest_row, int dest_col,
			   int src_row, int src_col)
{
    dumb_row(dest_row)[dest_col] = dumb_row(src_row)[src_col];
    dumb_changes_row(dest_row)[dest_col] = dumb_changes_row(src_row)[src_col];
}

void os_set_text_style(int x)
{
    /* FGX delta: keep all four Z-machine style bits (was REVERSE only) --
     * bold, underline (from EMPHASIS) and reverse all render on the SHR
     * console; FIXED_WIDTH is a no-op on a mono font but carried so a
     * later proportional font could honour it. */
    current_style = x & (REVERSE_STYLE | BOLDFACE_STYLE |
                         EMPHASIS_STYLE | FIXED_WIDTH_STYLE);
}

/* put a character in the cell at the cursor and advance the cursor.  */
static void dumb_display_char(char c)
{
    dumb_set_cell(cursor_row, cursor_col,
                  make_cell(current_style, current_fg, current_bg, c));
    if (++cursor_col == h_screen_cols) {
	if (cursor_row == h_screen_rows - 1)
	    cursor_col--;
	else {
	    cursor_row++;
	    cursor_col = 0;
	}
    }
}

void dumb_display_user_input(char *s)
{
    /* copy to screen without marking it as a change.  */
    while (*s)
	dumb_row(cursor_row)[cursor_col++] =
	    make_cell(0, current_fg, current_bg, *s++);
}

void dumb_discard_old_input(int num_chars)
{
  /* Weird discard stuff.  Grep spec for 'pain in my butt'.  */
  /* The old characters should be on the screen just before the cursor.
   * Erase them.  */
    cursor_col -= num_chars;

    if (cursor_col < 0)
	cursor_col = 0;
    os_erase_area(cursor_row + 1, cursor_col + 1,
	cursor_row + 1, cursor_col + num_chars, -1);
}

void os_display_char (zchar c)
{
    if (c >= ZC_LATIN1_MIN && c <= ZC_LATIN1_MAX) {
	if (plain_ascii) {
	    char *ptr = latin1_to_ascii + 4 * (c - ZC_LATIN1_MIN);
	    do
		dumb_display_char(*ptr++);
	    while (*ptr != ' ');
	} else
	    dumb_display_char(c);
    } else if (c >= 32 && c <= 126) {
	dumb_display_char(c);
    } else if (c == ZC_GAP) {
	dumb_display_char(' '); dumb_display_char(' ');
    } else if (c == ZC_INDENT) {
	dumb_display_char(' '); dumb_display_char(' '); dumb_display_char(' ');
    }
  return;
}


/* Haxor your boxor? */
void os_display_string (const zchar *s)
{
    zchar c;

    while ((c = *s++) != 0) {
	if (c == ZC_NEW_FONT)
	    s++;
	else if (c == ZC_NEW_STYLE)
	    os_set_text_style(*s++);
	else {
	    os_display_char (c);
	}
    }
}

void os_erase_area (int top, int left, int bottom, int right, int win)
{
    int row, col;
    top--; left--; bottom--; right--;
    for (row = top; row <= bottom; row++) {
	for (col = left; col <= right; col++)
	    dumb_set_cell(row, col,
			  make_cell(current_style, current_fg, current_bg, ' '));
    }
}

void os_scroll_area (int top, int left, int bottom, int right, int units)
{
    int row, col;

    top--; left--; bottom--; right--;

    if (units > 0) {
	for (row = top; row <= bottom - units; row++) {
	    for (col = left; col <= right; col++)
		dumb_copy_cell(row, col, row + units, col);
	}
	os_erase_area(bottom - units + 2, left + 1, bottom + 1, right + 1, -1 );
    } else if (units < 0) {
	for (row = bottom; row >= top - units; row--) {
	    for (col = left; col <= right; col++)
		dumb_copy_cell(row, col, row + units, col);
	}
	os_erase_area(top + 1, left + 1, top - units, right + 1 , -1);
    }
}

int os_font_data(int font, int *height, int *width)
{
    if (font == TEXT_FONT) {
	*height = 1; *width = 1; return 1;
    }
    return 0;
}

/* FGX delta: record the frotz colour pair; screen_paint folds it to SGR.
 * frotz passes DEFAULT..WHITE (1..9); 0 means "leave unchanged". */
void os_set_colour (int fg, int bg)
{
    if (fg != 0) current_fg = fg;
    if (bg != 0) current_bg = bg;
}
void os_set_font (int x) {}

/* ==========================================================================
 * FGX delta: full-screen ANSI realize path (replaces the teletype
 * show_cell/show_row/compression machinery of the dumb interface).
 *
 * The FGX console is a VT102 (see the investigation in this port's commit).
 * screen_paint redraws the WHOLE grid every call with absolute cursor
 * motion and clear-to-EOL, coalescing SGR runs.  Repainting all rows
 * (not just changed ones) is what keeps it correct across a cooked-mode
 * Enter that scrolls the physical console: the next paint restores every
 * row from the authoritative grid.  Autowrap is off for the session
 * (os_init_screen) so a full-width row cannot itself scroll.
 * ========================================================================== */

/* SGR the paint has already emitted; -1 forces the next emit_sgr. */
static int painted_style = -1, painted_fg = -1, painted_bg = -1;

/* Move the emitted attributes to (style, fg, bg).  Reset-then-reapply:
 * games change attributes rarely, so the extra bytes cost nothing and the
 * console never carries a stale attribute into the next run. */
static void emit_sgr(int style, int fg, int bg)
{
    if (style == painted_style && fg == painted_fg && bg == painted_bg)
	return;
    fputs("\033[0m", stdout);
    if (style & REVERSE_STYLE)  fputs("\033[7m", stdout);
    if (style & BOLDFACE_STYLE) fputs("\033[1m", stdout);
    if (style & EMPHASIS_STYLE) fputs("\033[4m", stdout);   /* italic->underline */
    /* frotz BLACK_COLOUR(2)..WHITE_COLOUR(9) -> ANSI 0..7 (SGR 30/40 + n). */
    if (fg >= BLACK_COLOUR && fg <= WHITE_COLOUR)
	printf("\033[%dm", 30 + (fg - BLACK_COLOUR));
    if (bg >= BLACK_COLOUR && bg <= WHITE_COLOUR)
	printf("\033[%dm", 40 + (bg - BLACK_COLOUR));
    painted_style = style; painted_fg = fg; painted_bg = bg;
}

/* Repaint one row: position, emit cells up to the last significant one,
 * clear the rest of the line. */
static void paint_row(int r)
{
    int c, last;
    cell cel;

    printf("\033[%d;1H", r + 1);          /* CUP, 1-based, column 1 */
    painted_style = painted_fg = painted_bg = -1;   /* force SGR at row start */
    /* Last cell worth emitting: a non-blank glyph, or any styled/coloured
     * blank (a reverse-video status bar is blanks that must show). */
    for (last = h_screen_cols - 1; last >= 0; last--) {
	cel = dumb_row(r)[last];
	if (cell_char(cel) != ' ' || cell_style(cel) != 0
	    || cell_bg(cel) != DEFAULT_COLOUR)
	    break;
    }
    for (c = 0; c <= last; c++) {
	cel = dumb_row(r)[c];
	emit_sgr(cell_style(cel), cell_fg(cel), cell_bg(cel));
	putchar(cell_char(cel));
    }
    emit_sgr(0, DEFAULT_COLOUR, DEFAULT_COLOUR);
    fputs("\033[K", stdout);              /* EL: wipe stale tail */
}

static void mark_all_unchanged(void)
{
    memset(screen_changes, 0, screen_cells);
}

/* Realize the grid.  FGX delta: a full-screen VT102 repaint of every row,
 * ending with the hardware cursor parked at frotz's input position when
 * show_cursor.  The compression/line-number/line-type machinery of the
 * dumb interface (built for a scrolling teletype) is gone -- a fixed
 * console does not scroll under us, and repainting from the grid is both
 * simpler and correct after a cooked-mode Enter perturbs the display. */
void dumb_show_screen(bool show_cursor)
{
    int r;
    for (r = 0; r < h_screen_rows; r++)
	paint_row(r);
    emit_sgr(0, DEFAULT_COLOUR, DEFAULT_COLOUR);
    if (show_cursor)
	printf("\033[%d;%dH", cursor_row + 1, cursor_col + 1);
    fflush(stdout);
    mark_all_unchanged();
}

/* Park the hardware cursor at frotz's input position.  FGX delta: the
 * dumb interface teletyped the cursor row's prefix here; the full-screen
 * paint already drew that row, so this only positions the cursor (and the
 * line_type prompt char is dropped -- there is no teletype margin). */
void dumb_show_prompt(bool show_cursor, char line_type)
{
    if (show_cursor)
	printf("\033[%d;%dH", cursor_row + 1, cursor_col + 1);
    fflush(stdout);
}

/* Unconditionally show whole screen.  For \s user command.  */
void dumb_dump_screen(void)
{
    dumb_show_screen(FALSE);
}

/* Called when it's time for a more prompt but user has them turned off.  */
void dumb_elide_more_prompt(void)
{
    dumb_show_screen(FALSE);
}

void os_reset_screen(void)
{
    /* Called once at game exit (frotz.c main, after interpret()).  Paint
     * the final screen, then FGX delta: leave full-screen mode -- reset
     * SGR, autowrap back on, drop to the last row and a fresh line so the
     * shell prompt returns cleanly below the final display. */
    dumb_show_screen(FALSE);
    printf("\033[0m\033[?7h\033[%d;1H\n", h_screen_rows);
    fflush(stdout);
}

void os_beep (int volume)
{
    if (visual_bell)
	printf("[%s-PITCHED BEEP]\n", (volume == 1) ? "HIGH" : "LOW");
    else
	putchar('\a'); /* so much for dumb.  */
}


/* To make the common code happy */

void os_prepare_sample (int a) {}
void os_finish_with_sample (int a) {}
void os_start_sample (int a, int b, int c, zword d) {}
void os_stop_sample (int a) {}


/* if val is '0' or '1', set *var accordingly, else toggle it.  */
static void toggle(bool *var, char val)
{
    *var = val == '1' || (val != '0' && !*var);
}

bool dumb_output_handle_setting(const char *setting, bool show_cursor,
				bool startup)
{
    /* FGX delta: the dumb interface's teletype render settings (reverse-
     * video METHOD, output compression, line numbers/types, picture boxes)
     * are gone with the teletype realize path -- a VT102 renders styles
     * natively.  Only the visual bell survives; `\set` reports it. */
    if (!strncmp(setting, "vb", 2)) {
	toggle(&visual_bell, setting[2]);
	printf("Visual bell %s\n", visual_bell ? "ON" : "OFF");
	os_beep(1); os_beep(2);
    } else if (!strcmp(setting, "set")) {
	printf("Visual Bell %s\n", visual_bell ? "ON" : "OFF");
    } else
	return FALSE;
    return TRUE;
}

void dumb_init_output(void)
{
    if (h_version == V3) {
	h_config |= CONFIG_SPLITSCREEN;
	h_flags &= ~OLD_SOUND_FLAG;
    }

    if (h_version >= V5) {
	h_flags &= ~SOUND_FLAG;
	/* FGX delta: the SHR console has 8 ANSI colours (screen_paint folds
	 * them to SGR), so advertise colour to v5+ games -- the dumb
	 * interface, being a teletype, never did.  Defaults match the
	 * console's native white-on-blue; os_set_colour seeds current_*. */
	h_config |= CONFIG_COLOUR;
	h_default_foreground = WHITE_COLOUR;
	h_default_background = BLUE_COLOUR;
	os_set_colour(h_default_foreground, h_default_background);
    }

    h_screen_height = h_screen_rows;
    h_screen_width = h_screen_cols;
    screen_cells = h_screen_rows * h_screen_cols;

    h_font_width = 1; h_font_height = 1;

    screen_data = malloc(screen_cells * sizeof(cell));
    screen_changes = malloc(screen_cells);
    os_erase_area(1, 1, h_screen_rows, h_screen_cols, -2);
    memset(screen_changes, 0, screen_cells);
}
