/* Walking skeleton for the software stack (--soft-stack): one scalar local.
 * f() has a single int local x; under --soft-stack the frame lives on the
 * per-task software stack ([_fcc_ssp],Y), not the bank-0 hardware stack. -> 42 */
int f(void) { int x; x = 42; return x; }
int main(void) { return f(); }
