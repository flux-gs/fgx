/* c08_strlit.c — construct 8: a string literal (data seg) read via char*.  The
 * literal's pointer bank must be the data seg. */
int c08_check(void)
{
	char *s = "MB08";
	return s[0] == 'M' && s[1] == 'B' && s[2] == '0' && s[3] == '8';
}
