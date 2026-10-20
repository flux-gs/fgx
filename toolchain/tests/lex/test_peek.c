/* Unit test for the non-destructive peek_tok() lookahead (T1.2 enabler).
 * Built via `make -C toolchain test-lex` (links lex_pp.c + globals.c with
 * -DFCC_LEX_TEST; no main()/file needed thanks to lex_init_buffer). */
#include <stdio.h>
#include "../../src/cc/fcc.h"

int main(int argc, char **argv)   /* fcc.h prototypes main(int,char**) */
{
    int fails = 0;
    (void)argc; (void)argv;
    lex_init_buffer("1 << 2 + x;");
    next_tok();
    if (g_cur.kind != TOK_INT_LIT || g_cur.value != 1) { printf("FAIL cur1\n"); fails++; }
    if (peek_tok().kind != TOK_LSHIFT) { printf("FAIL peek<<\n"); fails++; }
    if (peek_tok().kind != TOK_LSHIFT) { printf("FAIL idempotent\n"); fails++; }  /* idempotent */
    next_tok(); if (g_cur.kind != TOK_LSHIFT) { printf("FAIL consume peek\n"); fails++; }
    next_tok(); if (g_cur.kind != TOK_INT_LIT || g_cur.value != 2) { printf("FAIL cur2\n"); fails++; }
    if (peek_tok().kind != TOK_PLUS) { printf("FAIL peek+\n"); fails++; }
    next_tok(); if (g_cur.kind != TOK_PLUS) { printf("FAIL consume peek2\n"); fails++; }
    next_tok(); if (g_cur.kind != TOK_IDENT) { printf("FAIL ident\n"); fails++; }
    printf(fails ? "\n%d FAIL\n" : "\nok\n", fails);
    return fails ? 1 : 0;
}
