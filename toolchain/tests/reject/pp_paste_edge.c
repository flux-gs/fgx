/* expect: ## */
#define bad(a) ## a
int x = bad(1);
