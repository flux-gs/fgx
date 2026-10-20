/* In-struct pointer mechanics (single-bank / FGX1): the uniform 4-byte
 * struct* field plus the `ptr->field = ...` STORE path
 * (emit_deref_ptr_field_store) and chained '->' load.  Targets are
 * program-bank globals (reached via pointers), which the FGX1 PHK convention
 * resolves — a single-bank chain deref banks through PHK, so the targets must
 * be same-(program-)bank, not stack/heap.  Complements forward_struct (a
 * '.'-field store + local-pointer load).
 *   pa->next = pb      ptr->field store of an in-struct struct* (4-byte)
 *   pa->next->v = 42   chain STORE through the in-struct pointer
 *   pb->v              read back the OTHER way -> chain store hit b
 *   pa->next->v        chain LOAD -> 42
 *
 * NOTE: CROSS-bank in-struct pointers (e.g. to the $07+ heap) need the
 * loader-patched bank of MULTI-BANK builds; single-bank PHK reaches the
 * program bank only.  Cross-bank runtime proof is deferred to SP5 (vi
 * multi-bank); multi-bank codegen is covered by the multibank sweep
 * (toolchain/tests/multibank). */

struct N { struct N *next; int v; };

struct N a;
struct N b;

int main(void) {
    struct N *pa;
    struct N *pb;
    pa = &a;
    pb = &b;
    pa->next = pb;            /* ptr->field store: in-struct struct* (4-byte) */
    pa->next->v = 42;         /* chain STORE through the in-struct pointer    */
    if (pb->v != 42)          /* read back the OTHER way                      */
        return 7;
    return pa->next->v;       /* chain LOAD -> 42 */
}
