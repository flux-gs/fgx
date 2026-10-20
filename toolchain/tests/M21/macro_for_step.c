/* A function-like macro whose BODY is a for-loop with a step (elvis's
 * BeforeAfter = for((b),bavar=1;bavar;(a),bavar=0), reached via ChangeText).
 * The for-step is replayed AFTER the body by rewinding to the step's source
 * span; when that span lives in the macro-expansion frame, the frame's buffer
 * must survive the body parse (G39b) instead of being freed on pop.  Exercises
 * init, comma clauses, and the step running once per iteration.  -> 42. */
int gbefore;
int gafter;
int gbody;
int gv;

#define BA(b, a) for ((b), gv = 1; gv && gbody < 3; (a), gv = 1)

int main(void)
{
	gbefore = 0;
	gafter  = 0;
	gbody   = 0;

	BA(gbefore = gbefore + 1, gafter = gafter + 1) {
		gbody = gbody + 1;
	}
	/* init runs once (gbefore=1); body runs while gbody<3 (3x); step runs
	 * after each body (gafter=3). */
	if (gbefore != 1) return 1;
	if (gbody   != 3) return 2;
	if (gafter  != 3) return 3;
	return 42;
}
