/* Forward reference to a file-scope STATIC function — call BEFORE its
 * definition.  The single-pass emitter used to write the bare name at the call
 * (implicit forward ref: is_static not yet seen) but the mangled `<tu>_name` at
 * the definition, so the FARCALL never resolved (2.11BSD telnet's Dump()).
 * prescan_static_funcs() now registers file-scope static names up front so the
 * forward call mangles to match.  Two forward statics (one calling the other,
 * itself a forward ref) + an after-definition call.  -> 42. */
int early(void)
{
    return helper(3) + tail();      /* both forward: defined below */
}

static helper(x) int x; { return x * 12; }   /* 36 */

static tail(void) { return again(); }         /* again is another forward static */

static again(void) { return 6; }

int main(void)
{
    int a = early();                /* 36 + 6 = 42 */
    int b = helper(0);              /* after-def call: must hit the same label */
    return a + b;                   /* 42 + 0 = 42 */
}
