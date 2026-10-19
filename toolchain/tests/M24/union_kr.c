/* K&R / anonymous-union member access: a union of two layout-identical
 * structs whose fields are reached BARE through the union pointer — the way
 * 2.11BSD sed accesses `union reptr` (rep->command / rep->re1 / rep->lb1),
 * never rep->A.command.  struct_field_lookup falls back to the union's
 * struct arms (each at offset 0), so rep->field resolves to the arm field's
 * offset.  Pure fallback: ANSI direct-member access is unchanged.
 *
 * Layout (int=2, ptr=4): first@0, p/lb@2, command@6.
 *   rep->first=2 (offset 0, in both arms); rep->command=6 (offset 6, arm A);
 *   rep->lb (arm B pointer, offset 2) exercises the second-arm search.
 *   return first + command = 2 + 6 = 8. */
struct a { int first; char *p;       int command; };
struct b { int first; union reptr *lb; int command; };
union reptr { struct a A; struct b B; } pool[3], *rep;
int main(){
	rep = pool;
	rep->first = 2;          /* in both arms -> found in arm A */
	rep->command = 6;        /* arm A, offset 6 */
	rep->lb = 0;             /* arm B pointer, offset 2 */
	return rep->first + rep->command;
}
