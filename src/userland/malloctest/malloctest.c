/*
 * malloctest - regression for libc's sbrk-backed allocator.
 *
 * Guards the allocator that replaced the SYS_MALLOC32 kernel-arena backing
 * (issue #4).  The last case is the defect itself: the heap used to live in
 * the SHARED kernel arena, which snapshot-fork deliberately does not copy, so
 * a fork child's heap writes leaked into the parent.  tcsh hit that as a job
 * ring whose leader had p_pid zeroed by the child's pflushall(), and spun
 * forever in pendjob after any pipeline.
 *
 * Self-checking: prints "ok"/"FAIL" per case and a final MALLOCTEST line.
 * Exit status is the failure count, so a harness can gate on it.
 */
#include <stdio.h>

char *malloc(unsigned long size);
char *realloc(char *p, unsigned long size);
void free(char *p);
int fork(void);
void _exit(int st);
int wait(int *status);

int fails;

void ck(int cond, char *what)
{
	if (cond)
		printf("ok   %s\n", what);
	else {
		printf("FAIL %s\n", what);
		fails++;
	}
}

int main()
{
	char *a, *b, *c, *p, *q;
	int i, pid, bad;

	fails = 0;

	/* 1. basic malloc + the memory is actually writable/readable */
	p = malloc(100L);
	ck(p != (char *)0, "malloc returns non-null");
	for (i = 0; i < 100; i++)
		p[i] = (char)(i & 0x7F);
	bad = 0;
	for (i = 0; i < 100; i++)
		if (p[i] != (char)(i & 0x7F))
			bad++;
	ck(bad == 0, "malloc block holds its contents");

	/* 2. first-fit reuse: the freed block is handed straight back */
	free(p);
	q = malloc(100L);
	ck(q == p, "free then malloc reuses the block");
	free(q);

	/* 3. coalesce: two adjacent frees must merge into one hole big enough
	 *    for a block neither could satisfy alone.
	 *    The check is "the hole was REUSED", not "the hole starts at a":
	 *    an earlier freed block sitting just below a legitimately coalesces
	 *    with it, so the merged hole can start lower than a.  Asserting
	 *    p == a caught exactly that and was the test being wrong, not the
	 *    allocator.  c sits above b and stays allocated, so a result below
	 *    c proves the merged hole was used rather than the break grown. */
	a = malloc(200L);
	b = malloc(200L);
	c = malloc(64L);            /* barrier: keeps the heap from shrinking */
	ck(a != (char *)0 && b != (char *)0 && c != (char *)0, "three blocks");
	free(a);
	free(b);
	p = malloc(380L);           /* fits only if a+b merged */
	ck(p != (char *)0, "post-coalesce malloc succeeds");
	ck(p <= a, "adjacent frees coalesce (hole reused, not break grown)");
	free(p);
	free(c);

	/* 4. realloc preserves the old contents (the arena version could not
	 *    see the old length; the header-carried size now makes this work) */
	p = malloc(50L);
	for (i = 0; i < 50; i++)
		p[i] = (char)('A' + (i % 26));
	q = realloc(p, 400L);
	ck(q != (char *)0, "realloc grows");
	bad = 0;
	for (i = 0; i < 50; i++)
		if (q[i] != (char)('A' + (i % 26)))
			bad++;
	ck(bad == 0, "realloc preserves contents");
	free(q);

	/* 5. free(NULL) is a no-op, not a crash */
	free((char *)0);
	ck(1, "free(NULL) survives");

	/* 6. THE ISSUE #4 CASE: fork must isolate the heap.  The child writes
	 *    through a pointer the parent also holds; after the child is gone
	 *    the parent must still see its own value.  With the heap in the
	 *    shared kernel arena this read back 'Z'. */
	p = malloc(64L);
	p[0] = 'A';
	pid = fork();
	if (pid == 0) {
		p[0] = 'Z';         /* must NOT be visible to the parent */
		_exit(0);
	}
	wait((int *)0);
	ck(p[0] == 'A', "fork isolates the heap from the child");
	free(p);

	printf("MALLOCTEST fails=%d\n", fails);
	return fails;
}
