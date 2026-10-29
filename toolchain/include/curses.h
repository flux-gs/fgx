/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 *
 *	@(#)curses.h	5.1.1 (2.11BSD GTE) 12/9/94
 */

# ifndef WINDOW

# include	<stdio.h>
 
# include	<sgtty.h>

# define	bool	char
# define	reg	register

# define	TRUE	(1)
# define	FALSE	(0)
# define	ERR	(0)
# define	OK	(1)

# define	_ENDLINE	001
# define	_FULLWIN	002
# define	_SCROLLWIN	004
# define	_FLUSH		010
# define	_FULLLINE	020
# define	_IDLINE		040
# define	_KEYPAD		0100	/* keypad(win, TRUE): wgetch returns KEY_ values */
# define	_STANDOUT	0200
# define	_NOCHANGE	-1

# define	_puts(s)	tputs(s, 0, _putchar)

/*
 * keypad mode, from NetBSD 1.5 lib/libcurses/curses.h: the values wgetch
 * returns for a key whose termcap sequence (ku kd kl kr kh k0-k9) arrives
 * while the window is in keypad mode.
 */
/* symbols for values returned by getch in keypad mode */
#define    KEY_MIN        0x101    /* minimum extended key value */
#define    KEY_BREAK      0x101    /* break key */
#define    KEY_DOWN       0x102    /* down arrow */
#define    KEY_UP         0x103    /* up arrow */
#define    KEY_LEFT       0x104    /* left arrow */
#define    KEY_RIGHT      0x105    /* right arrow*/
#define    KEY_HOME       0x106    /* home key */
#define    KEY_BACKSPACE  0x107    /* Backspace */

/* First function key (block of 64 follow) */
#define    KEY_F0         0x108
/* Function defining other function key values*/
#define    KEY_F(n)       (KEY_F0+(n))

#define    KEY_DL         0x148    /* Delete Line */
#define    KEY_IL         0x149    /* Insert Line*/
#define    KEY_DC         0x14A    /* Delete Character */
#define    KEY_IC         0x14B    /* Insert Character */
#define    KEY_EIC        0x14C    /* Exit Insert Char mode */
#define    KEY_CLEAR      0x14D    /* Clear screen */
#define    KEY_EOS        0x14E    /* Clear to end of screen */
#define    KEY_EOL        0x14F    /* Clear to end of line */
#define    KEY_SF         0x150    /* Scroll one line forward */
#define    KEY_SR         0x151    /* Scroll one line back */
#define    KEY_NPAGE      0x152    /* Next Page */
#define    KEY_PPAGE      0x153    /* Prev Page */
#define    KEY_STAB       0x154    /* Set Tab */
#define    KEY_CTAB       0x155    /* Clear Tab */
#define    KEY_CATAB      0x156    /* Clear All Tabs */
#define    KEY_ENTER      0x157    /* Enter or Send */
#define    KEY_SRESET     0x158    /* Soft Reset */
#define    KEY_RESET      0x159    /* Hard Reset */
#define    KEY_PRINT      0x15A    /* Print */
#define    KEY_LL         0x15B    /* Home Down */

/*
 * "Keypad" keys arranged like this:
 *
 *  A1   up  A3
 * left  B2 right
 *  C1  down C3
 *
 */
#define    KEY_A1         0x15C    /* Keypad upper left */
#define    KEY_A3         0x15D    /* Keypad upper right */
#define    KEY_B2         0x15E    /* Keypad center key */
#define    KEY_C1         0x15F    /* Keypad lower left */
#define    KEY_C3         0x160    /* Keypad lower right */

#define    KEY_BTAB       0x161    /* Back Tab */
#define    KEY_BEG        0x162    /* Begin key */
#define    KEY_CANCEL     0x163    /* Cancel key */
#define    KEY_CLOSE      0x164    /* Close Key */
#define    KEY_COMMAND    0x165    /* Command Key */
#define    KEY_COPY       0x166    /* Copy key */
#define    KEY_CREATE     0x167    /* Create key */
#define    KEY_END        0x168    /* End key */
#define    KEY_EXIT       0x169    /* Exit key */
#define    KEY_FIND       0x16A    /* Find key */
#define    KEY_HELP       0x16B    /* Help key */
#define    KEY_MARK       0x16C    /* Mark key */
#define    KEY_MESSAGE    0x16D    /* Message key */
#define    KEY_MOVE       0x16E    /* Move key */
#define    KEY_NEXT       0x16F    /* Next Object key */
#define    KEY_OPEN       0x170    /* Open key */
#define    KEY_OPTIONS    0x171    /* Options key */
#define    KEY_PREVIOUS   0x172    /* Previous Object key */
#define    KEY_REDO       0x173    /* Redo key */
#define    KEY_REFERENCE  0x174    /* Ref Key */
#define    KEY_REFRESH    0x175    /* Refresh key */
#define    KEY_REPLACE    0x176    /* Replace key */
#define    KEY_RESTART    0x177    /* Restart key */
#define    KEY_RESUME     0x178    /* Resume key */
#define    KEY_SAVE       0x179    /* Save key */
#define    KEY_SBEG       0x17A    /* Shift begin key */
#define    KEY_SCANCEL    0x17B    /* Shift Cancel key */
#define    KEY_SCOMMAND   0x17C    /* Shift Command key */
#define    KEY_SCOPY      0x17D    /* Shift Copy key */
#define    KEY_SCREATE    0x17E    /* Shift Create key */
#define    KEY_SDC        0x17F    /* Shift Delete Character */
#define    KEY_SDL        0x180    /* Shift Delete Line */
#define    KEY_SELECT     0x181    /* Select key */
#define    KEY_SEND       0x182    /* Send key */
#define    KEY_SEOL       0x183    /* Shift Clear Line key */
#define    KEY_SEXIT      0x184    /* Shift Exit key */
#define    KEY_SFIND      0x185    /* Shift Find key */
#define    KEY_SHELP      0x186    /* Shift Help key */
#define    KEY_SHOME      0x187    /* Shift Home key */
#define    KEY_SIC        0x188    /* Shift Input key */
#define    KEY_SLEFT      0x189    /* Shift Left Arrow key */
#define    KEY_SMESSAGE   0x18A    /* Shift Message key */
#define    KEY_SMOVE      0x18B    /* Shift Move key */
#define    KEY_SNEXT      0x18C    /* Shift Next key */
#define    KEY_SOPTIONS   0x18D    /* Shift Options key */
#define    KEY_SPREVIOUS  0x18E    /* Shift Previous key */
#define    KEY_SPRINT     0x18F    /* Shift Print key */
#define    KEY_SREDO      0x190    /* Shift Redo key */
#define    KEY_SREPLACE   0x191    /* Shift Replace key */
#define    KEY_SRIGHT     0x192    /* Shift Right Arrow key */
#define    KEY_SRSUME     0x193    /* Shift Resume key */
#define    KEY_SSAVE      0x194    /* Shift Save key */
#define    KEY_SSUSPEND   0x195    /* Shift Suspend key */
#define    KEY_SUNDO      0x196    /* Shift Undo key */
#define    KEY_SUSPEND    0x197    /* Suspend key */
#define    KEY_UNDO       0x198    /* Undo key */
#define    KEY_MOUSE      0x199    /* Mouse event has occurred */
#define    KEY_MAX        0x199    /* maximum extended key value */

typedef	struct sgttyb	SGTTY;

/*
 * Capabilities from termcap
 */

extern bool     AM, BS, CA, DA, DB, EO, HC, HZ, IN, MI, MS, NC, NS, OS, UL,
		XB, XN, XT, XS, XX;
extern char	*AL, *BC, *BT, *CD, *CE, *CL, *CM, *CR, *CS, *DC, *DL,
		*DM, *DO, *ED, *EI, *K0, *K1, *K2, *K3, *K4, *K5, *K6,
		*K7, *K8, *K9, *HO, *IC, *IM, *IP, *KD, *KE, *KH, *KL,
		*KR, *KS, *KU, *LL, *MA, *ND, *NL, *RC, *SC, *SE, *SF,
		*SO, *SR, *TA, *TE, *TI, *UC, *UE, *UP, *US, *VB, *VS,
		*VE, *AL_PARM, *DL_PARM, *UP_PARM, *DOWN_PARM,
		*LEFT_PARM, *RIGHT_PARM;
extern char	PC;

/*
 * From the tty modes...
 */

extern bool	GT, NONL, normtty, _pfast;

struct _win_st {
	short		_cury, _curx;
	short		_maxy, _maxx;
	short		_begy, _begx;
	short		_flags;
	short		_ch_off;
	bool		_clear;
	bool		_leave;
	bool		_scroll;
	char		**_y;
	short		*_firstch;
	short		*_lastch;
	struct _win_st	*_nextp, *_orig;
};

# define	WINDOW	struct _win_st

extern bool	My_term, _echoit, _rawmode, _endwin;

extern char	*Def_term, ttytype[];

extern int	LINES, COLS, _tty_ch, _res_flg;

extern SGTTY	_tty;

extern WINDOW	*stdscr, *curscr;

/*
 *	Define VOID to stop lint from generating "null effect"
 * comments.
 */
# ifdef lint
int	__void__;
# define	VOID(x)	(__void__ = (int) (x))
# else
# define	VOID(x)	(x)
# endif

/*
 * psuedo functions for standard screen
 */
# define	addch(ch)	VOID(waddch(stdscr, ch))
# define	getch()		VOID(wgetch(stdscr))
# define	addstr(str)	VOID(waddstr(stdscr, str))
# define	getstr(str)	VOID(wgetstr(stdscr, str))
# define	move(y, x)	VOID(wmove(stdscr, y, x))
# define	clear()		VOID(wclear(stdscr))
# define	erase()		VOID(werase(stdscr))
# define	clrtobot()	VOID(wclrtobot(stdscr))
# define	clrtoeol()	VOID(wclrtoeol(stdscr))
# define	insertln()	VOID(winsertln(stdscr))
# define	deleteln()	VOID(wdeleteln(stdscr))
# define	refresh()	VOID(wrefresh(stdscr))
# define	inch()		VOID(winch(stdscr))
# define	insch(c)	VOID(winsch(stdscr,c))
# define	delch()		VOID(wdelch(stdscr))
# define	standout()	VOID(wstandout(stdscr))
# define	standend()	VOID(wstandend(stdscr))

/*
 * mv functions
 */
#define	mvwaddch(win,y,x,ch)	VOID(wmove(win,y,x)==ERR?ERR:waddch(win,ch))
#define	mvwgetch(win,y,x)	VOID(wmove(win,y,x)==ERR?ERR:wgetch(win))
#define	mvwaddstr(win,y,x,str)	VOID(wmove(win,y,x)==ERR?ERR:waddstr(win,str))
#define mvwgetstr(win,y,x,str)  VOID(wmove(win,y,x)==ERR?ERR:wgetstr(win,str))
#define	mvwinch(win,y,x)	VOID(wmove(win,y,x) == ERR ? ERR : winch(win))
#define	mvwdelch(win,y,x)	VOID(wmove(win,y,x) == ERR ? ERR : wdelch(win))
#define	mvwinsch(win,y,x,c)	VOID(wmove(win,y,x) == ERR ? ERR:winsch(win,c))
#define	mvaddch(y,x,ch)		mvwaddch(stdscr,y,x,ch)
#define	mvgetch(y,x)		mvwgetch(stdscr,y,x)
#define	mvaddstr(y,x,str)	mvwaddstr(stdscr,y,x,str)
#define mvgetstr(y,x,str)       mvwgetstr(stdscr,y,x,str)
#define	mvinch(y,x)		mvwinch(stdscr,y,x)
#define	mvdelch(y,x)		mvwdelch(stdscr,y,x)
#define	mvinsch(y,x,c)		mvwinsch(stdscr,y,x,c)

/*
 * psuedo functions
 */

#define	clearok(win,bf)	 (win->_clear = bf)
#define	leaveok(win,bf)	 (win->_leave = bf)
#define	scrollok(win,bf) (win->_scroll = bf)
#define flushok(win,bf)	 (bf ? (win->_flags |= _FLUSH):(win->_flags &= ~_FLUSH))
#define	getyx(win,y,x)	 y = win->_cury, x = win->_curx
#define	winch(win)	 (win->_y[win->_cury][win->_curx] & 0177)

#define raw()	 (_tty.sg_flags|=RAW, _pfast=_rawmode=TRUE, stty(_tty_ch,&_tty))
#define noraw()	 (_tty.sg_flags&=~RAW,_rawmode=FALSE,_pfast=!(_tty.sg_flags&CRMOD),stty(_tty_ch,&_tty))
#define cbreak() (_tty.sg_flags |= CBREAK, _rawmode = TRUE, stty(_tty_ch,&_tty))
#define nocbreak() (_tty.sg_flags &= ~CBREAK,_rawmode=FALSE,stty(_tty_ch,&_tty))
#define crmode() cbreak()	/* backwards compatability */
#define nocrmode() nocbreak()	/* backwards compatability */
#define echo()	 (_tty.sg_flags |= ECHO, _echoit = TRUE, stty(_tty_ch, &_tty))
#define noecho() (_tty.sg_flags &= ~ECHO, _echoit = FALSE, stty(_tty_ch, &_tty))
#define nl()	 (_tty.sg_flags |= CRMOD,_pfast = _rawmode,stty(_tty_ch, &_tty))
#define nonl()	 (_tty.sg_flags &= ~CRMOD, _pfast = TRUE, stty(_tty_ch, &_tty))
#define	savetty() ((void) gtty(_tty_ch, &_tty), _res_flg = _tty.sg_flags)
#define	resetty() (_tty.sg_flags = _res_flg, (void) stty(_tty_ch, &_tty))
/*
 * fixterm(): System V's return to program mode after a shell escape
 * (FreeBSD 2.2.8 ncurses: reset_prog_mode()).  4.3BSD curses saves no
 * program mode, so this re-applies the modes _tty holds; a caller sets the
 * rest with raw(), noecho() and nonl(), as ee does on the next lines.
 */
#define	fixterm() ((void) stty(_tty_ch, &_tty))
/*
 * wnoutrefresh(): System V's half of wrefresh that copies the window to a
 * virtual screen for a later doupdate() (NetBSD 1.5 refresh.c).  4.3BSD
 * curses has no virtual screen, so the window is refreshed now.
 */
#define	wnoutrefresh(win) wrefresh(win)

#define	erasechar()	(_tty.sg_erase)
#define	killchar()	(_tty.sg_kill)
#define baudrate()	(_tty.sg_ospeed)

WINDOW	*initscr(), *newwin(), *subwin();
char	*longname(), *getcap();

/*
 * Used to be in unctrl.h.
 */
#define	unctrl(c)	_unctrl[(c) & 0177]
extern char *_unctrl[];
# endif
