/* Static pointer initialised to another global's address — `T *p = arr;`
 * (bare array decay) and `T *q = &global;` — the 2.11BSD sed idiom
 * `struct label *labtab = ltab;`.  parse_stmt records the target global
 * (init_global_idx) and emit_globals_section emits a relocated 4-byte long
 * pointer: single-bank (this harness) bakes DA target / DFB ^target /
 * DFB $00; multi-bank emits FGX2_EXPORT target + FGX2_LONG_PTR (loader-
 * patched bank), exercised by the sed port.  Matches clang: ret 55. */
int arr[4];
int *p = arr;
int second;
int *q = &second;
int main(){
	p[0] = 30;
	p[1] = 11;
	*q = 7;
	return p[0] + p[1] + *q + second;   /* 30 + 11 + 7 + 7 = 55 */
}
