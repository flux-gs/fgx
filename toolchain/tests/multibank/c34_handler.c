/* c34_handler.c — cross-bank handler for c34.  Deliberately returns poison
 * (its return value rides A back through the trampoline) so an
 * unpreserving trampoline cannot hand the shim a lucky 0. */
int c34_count = 0;

int c34_handler(sig)
int sig;
{
	c34_count++;
	return 0x5A5A;               /* poison A on the way out */
}
