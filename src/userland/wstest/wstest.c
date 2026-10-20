/* wstest.c — TIOCGWINSZ probe (2026-07-06 quick-win).
 *
 * ioctl(0, TIOCGWINSZ, &ws) into a SOFT-STACK local struct winsize: the
 * kernel writes through _Sys_CallerBank (the arg's bank, swapped in by
 * c_ioctl), so a wrong-bank write leaves the poison intact.  Console
 * viewport is fixed 25x80 (CON_VIS_ROWS/COLS).  Also proves the generic
 * c_ioctl shim marshalling (fd/cmd/arg from the fcc stack).
 *
 * rc=42 pass; 2..5 identify the failing stage.
 */
#include <sys/ioctl.h>

int main()
{
	struct winsize ws;

	ws.ws_row = -1;
	ws.ws_col = -1;
	ws.ws_xpixel = -1;
	ws.ws_ypixel = -1;
	if (ioctl(0, TIOCGWINSZ, &ws) != 0) return 2;
	if (ws.ws_row != 25) return 3;
	if (ws.ws_col != 80) return 4;
	if (ws.ws_xpixel != 0 || ws.ws_ypixel != 0) return 5;
	return 42;
}
