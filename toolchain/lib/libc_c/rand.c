/* rand/srand + random/srandom — ONE 32-bit LCG (the classic BSD/K&R
 * rand constants: seed = seed*1103515245 + 12345, wrap mod 2^32).
 * rand() returns bits 30..16 (15-bit, 0..32767) like historical rand;
 * random() takes two steps and splices 31 bits (hi15 << 16 | lo16) so
 * `random() % n` works for the larger n the bsdgames ports use (dict
 * offsets, deck shuffles).  NOT the BSD additive-feedback random(3) —
 * game-grade only; both share the one seed (srand == srandom). */
static long _rnd_next = 1;

void srand(int seed)
{
    _rnd_next = (long)seed;
}

int rand(void)
{
    _rnd_next = _rnd_next * 1103515245L + 12345L;
    return (int)((_rnd_next >> 16) & 0x7FFFL);
}

void srandom(int seed)
{
    _rnd_next = (long)seed;
}

long random(void)
{
    long hi, lo;

    _rnd_next = _rnd_next * 1103515245L + 12345L;
    hi = (_rnd_next >> 16) & 0x7FFFL;
    _rnd_next = _rnd_next * 1103515245L + 12345L;
    lo = (_rnd_next >> 16) & 0xFFFFL;
    return (hi << 16) | lo;
}
