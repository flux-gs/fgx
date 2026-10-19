/* ---- crypt(3) -------------------------------------------------------------
 * NOT DES.  A 25-round DES crypt at 2.8 MHz would make login visibly pause and
 * buys close to nothing on a single-user IIgs (2026-07-31).  This is an
 * FNV-1a over salt+key, printed as "$f$<salt>$<8 hex>".
 *
 * The "$f$" TAG is the forward-compatibility seam: a real DES crypt can be
 * added later and coexist, because a 13-character untagged DES hash cannot be
 * confused with a tagged one.  Callers must dispatch on the tag, never assume
 * a length.
 *
 * Being explicit about the threat model: this stops a shoulder-surfer and a
 * casual reader of /etc/passwd.  It is not a defence against an attacker who
 * has the file and wants the password.  Say so in passwd(1) too.
 */
static char _crypt_buf[16];

/* crypt_salt -- the salt that produced a stored hash.
 *
 * BESIDE crypt AND NOT IN ITS CALLERS, because the tag is crypt's contract and
 * every reader of a stored hash needs the same three lines.  crypt(3) already
 * tells them to "dispatch on the tag, not on length"; this is what they
 * dispatch WITH.
 *
 * A "$f$xy$........" hash carries its salt after the tag.  An untagged
 * (DES-shaped) hash is its own salt -- its first two characters -- which is
 * why upstream code passes the stored hash straight to crypt() and is right to.
 *
 * PASSING THE WHOLE TAGGED HASH IS THE TRAP, and it is silent: crypt() folds
 * "$f" instead of "xy" and returns "$f$$f$........", which can never equal any
 * stored hash, so the comparison fails for every password including the
 * correct one.  su(1) did exactly that and could not authenticate anybody
 * (apple/fgx#414); login(1) carried these lines as a static and was fine. */
char *crypt_salt(hash)
	char *hash;
{
	if (hash == (char *)0)
		return (hash);
	if (hash[0] == '$' && hash[1] != '\0' && hash[2] == '$')
		return (hash + 3);
	return (hash);
}

static char _crypt_hexd(v)
	int v;
{
	return (char)(v < 10 ? '0' + v : 'a' + (v - 10));
}

char *crypt(key, salt)
	char *key;
	char *salt;
{
	unsigned long h;
	char *p;
	int i, nyb;

	/* FNV-1a, 32-bit.  fcc has real 32-bit longs; the multiply is the
	 * expensive part and runs 2 + strlen(key) times, which is nothing. */
	h = 2166136261L;
	for (p = salt; p != (char *)0 && *p != '\0' && p < salt + 2; p++) {
		h = h ^ (unsigned long)(unsigned char)*p;
		h = h * 16777619L;
	}
	for (p = key; p != (char *)0 && *p != '\0'; p++) {
		h = h ^ (unsigned long)(unsigned char)*p;
		h = h * 16777619L;
	}

	_crypt_buf[0] = '$';
	_crypt_buf[1] = 'f';
	_crypt_buf[2] = '$';
	_crypt_buf[3] = (salt != (char *)0 && salt[0] != '\0') ? salt[0] : '.';
	_crypt_buf[4] = (salt != (char *)0 && salt[0] != '\0'
	              && salt[1] != '\0') ? salt[1] : '.';
	_crypt_buf[5] = '$';
	for (i = 0; i < 8; i++) {
		nyb = (int)((h >> ((7 - i) * 4)) & 0x0FL);
		_crypt_buf[6 + i] = _crypt_hexd(nyb);
	}
	_crypt_buf[14] = '\0';
	return _crypt_buf;
}
void cfree(void *p)                    { free(p); }

