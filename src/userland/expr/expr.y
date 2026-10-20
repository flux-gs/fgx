%{
/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD expr(1)
 *   Ported from expr(1) (usr/bin/expr.y), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *
 * yacc grammar for expr(1).  FGX2.  Every value is a STRING (YYSTYPE char *);
 * arith() parses operands to long, computes, and reformats.
 *
 * INCREMENT 1 (this file): arithmetic (+ - * / %, long), relational
 * (= > >= < <= !=), logical (| &), and length/index/substr.  The regex match
 * operators (`:` / `match`) are deferred to increment 2 — they need expr's
 * ed-style BRE engine; tracked, not silently dropped.  The numeric test that
 * upstream did with ematch("[0-9]*$") is hand-rolled here as numeric() so the
 * arithmetic path needs no regex. */
/* Every value is a char* (a string).  The value-stack type is a pointer
 * typedef: `YYSTYPE yylval, yyval;` then makes BOTH char* (a typedef is a
 * single type token, unlike `#define YYSTYPE char *` where the '*' would bind
 * only to the first declarator).  Needs fcc pointer-typedef support (v0.11.0+). */
typedef char *YYSTYPE_t;
#define YYSTYPE YYSTYPE_t
#define YYMAXDEPTH 64
/* strncpy + malloc + atol PROTOTYPES (M-4): the old K&R `char *malloc();`
 * pushed 16-bit args where the wide malloc reads a 32-bit size, and an
 * implicit strncpy assumed an int return (bank-lost char*). */
#include <string.h>
#include <stdlib.h>
int   yylex();
int   printf();
char *conj();
char *rel();
char *arith();
char *substr();
char *length();
char *idx();
char *match();
%}
%token OR AND ADD SUBT MULT DIV REM EQ GT GEQ LT LEQ NEQ
%token A_STRING SUBSTR LENGTH INDEX NOARG MATCH

/* operators in increasing precedence: */
%left OR
%left AND
%left EQ LT GT GEQ LEQ NEQ
%left ADD SUBT
%left MULT DIV REM
%left MCH
%left MATCH
%left SUBSTR
%left LENGTH INDEX
%%

expression : expr NOARG = {
		printf("%s\n", $1);
		exit((!strcmp($1, "0") || !strcmp($1, "")) ? 1 : 0);
		}
	;

expr : '(' expr ')'         = { $$ = $2; }
	| expr OR expr      = { $$ = conj(OR, $1, $3); }
	| expr AND expr     = { $$ = conj(AND, $1, $3); }
	| expr EQ expr      = { $$ = rel(EQ, $1, $3); }
	| expr GT expr      = { $$ = rel(GT, $1, $3); }
	| expr GEQ expr     = { $$ = rel(GEQ, $1, $3); }
	| expr LT expr      = { $$ = rel(LT, $1, $3); }
	| expr LEQ expr     = { $$ = rel(LEQ, $1, $3); }
	| expr NEQ expr     = { $$ = rel(NEQ, $1, $3); }
	| expr ADD expr     = { $$ = arith(ADD, $1, $3); }
	| expr SUBT expr    = { $$ = arith(SUBT, $1, $3); }
	| expr MULT expr    = { $$ = arith(MULT, $1, $3); }
	| expr DIV expr     = { $$ = arith(DIV, $1, $3); }
	| expr REM expr     = { $$ = arith(REM, $1, $3); }
	| expr MCH expr     = { $$ = match($1, $3); }
	| MATCH expr expr   = { $$ = match($2, $3); }
	| SUBSTR expr expr expr = { $$ = substr($2, $3, $4); }
	| LENGTH expr       = { $$ = length($2); }
	| INDEX expr expr   = { $$ = idx($2, $3); }
	| A_STRING
	;
%%

/* expr's `:` (MCH) and `match` operators use the shared ed-style BRE engine
 * (re_comp + the anchored re_amatch added for expr) — not a private copy. */
#include "../lib/regexp.c"

char **Av;
int   Ac;
int   Argi;

char *operators[] = { "|", "&", "+", "-", "*", "/", "%", ":",
	"=", "==", "<", "<=", ">", ">=", "!=",
	"match", "substr", "length", "index", "" };
int   op[] = { OR, AND, ADD, SUBT, MULT, DIV, REM, MCH,
	EQ, EQ, LT, LEQ, GT, GEQ, NEQ,
	MATCH, SUBSTR, LENGTH, INDEX };

int main(argc, argv) char **argv;
{
	Ac = argc;
	Argi = 1;
	Av = argv;
	yyparse();
	return 0;
}

int yylex()
{
	char *p;
	int i;

	if (Argi >= Ac)
		return NOARG;
	p = Av[Argi++];
	if (*p == '(' || *p == ')')
		return (int)*p;
	for (i = 0; *operators[i]; ++i)
		if (!strcmp(operators[i], p))
			return op[i];
	yylval = p;
	return A_STRING;
}

/* numeric(s, allowneg): 1 if s is a (optionally '-'-prefixed) run of digits.
 * Replaces upstream ematch("-*[0-9]*$") / ematch("[0-9]*$"). */
int numeric(s, allowneg) char *s;
{
	char *p;

	p = s;
	if (allowneg)
		while (*p == '-')
			p++;
	if (*p == 0)
		return 0;
	while (*p) {
		if (*p < '0' || *p > '9')
			return 0;
		p++;
	}
	return 1;
}

/* ltoa: format a signed long into buf (avoids sprintf %ld). Returns buf. */
char *ltoa(n, buf) long n; char *buf;
{
	char tmp[16];
	char *t;
	char *b;
	long q;
	int neg;

	t = tmp;
	b = buf;
	neg = 0;
	if (n < 0) {
		neg = 1;
		n = -n;
	}
	if (n == 0)
		*t++ = '0';
	while (n != 0) {
		q = n / 10;
		*t++ = (int)(n - q * 10) + '0';
		n = q;
	}
	if (neg)
		*b++ = '-';
	while (t != tmp) {
		t--;
		*b++ = *t;
	}
	*b = 0;
	return buf;
}

char *rel(rop, r1, r2) int rop; char *r1, *r2;
{
	long i;

	if (numeric(r1, 1) && numeric(r2, 1)) {
		long a;
		long b;
		a = atol(r1);
		b = atol(r2);
		if (a < b)
			i = -1;
		else if (a > b)
			i = 1;
		else
			i = 0;
	} else {
		i = strcmp(r1, r2);
	}
	switch (rop) {
	case EQ:  i = i == 0; break;
	case GT:  i = i > 0;  break;
	case GEQ: i = i >= 0; break;
	case LT:  i = i < 0;  break;
	case LEQ: i = i <= 0; break;
	case NEQ: i = i != 0; break;
	}
	return i ? "1" : "0";
}

char *arith(aop, r1, r2) int aop; char *r1, *r2;
{
	long i1;
	long i2;
	char *rv;

	if (!(numeric(r1, 0) && numeric(r2, 0)))
		yyerror("non-numeric argument");
	i1 = atol(r1);
	i2 = atol(r2);
	switch (aop) {
	case ADD:  i1 = i1 + i2; break;
	case SUBT: i1 = i1 - i2; break;
	case MULT: i1 = i1 * i2; break;
	case DIV:  i1 = i1 / i2; break;
	case REM:  i1 = i1 % i2; break;
	}
	rv = malloc(16);
	return ltoa(i1, rv);
}

char *conj(cop, r1, r2) int cop; char *r1, *r2;
{
	char *rv;

	rv = "0";
	switch (cop) {
	case OR:
		if (!strcmp(r1, "0") || !strcmp(r1, "")) {
			if (!strcmp(r2, "0") || !strcmp(r2, ""))
				rv = "0";
			else
				rv = r2;
		} else {
			rv = r1;
		}
		break;
	case AND:
		if (!strcmp(r1, "0") || !strcmp(r1, ""))
			rv = "0";
		else if (!strcmp(r2, "0") || !strcmp(r2, ""))
			rv = "0";
		else
			rv = r1;
		break;
	}
	return rv;
}

char *substr(v, s, w) char *v, *s, *w;
{
	int si;
	int wi;
	char *res;

	si = atol(s);
	wi = atol(w);
	while (--si)
		if (*v)
			++v;
	res = v;
	while (wi--)
		if (*v)
			++v;
	*v = 0;
	return res;
}

char *length(s) char *s;
{
	int i;
	char *rv;

	i = 0;
	while (*s++)
		++i;
	rv = malloc(8);
	sprintf(rv, "%d", i);
	return rv;
}

char *idx(s, t) char *s, *t;
{
	int i;
	int j;
	char *rv;

	for (i = 0; s[i]; ++i)
		for (j = 0; t[j]; ++j)
			if (s[i] == t[j]) {
				rv = malloc(8);
				sprintf(rv, "%d", i + 1);
				return rv;
			}
	return "0";
}

/* match(s, p): expr's ':' (MCH) / match operator.  Anchored BRE match of the
 * pattern p against the string s.  With a \(...\) group -> the captured
 * substring; otherwise the number of chars matched ("0" on no match). */
char *match(s, p) char *s, *p;
{
	char *err;
	char *rv;
	int n;

	err = re_comp(p);
	if (err)
		yyerror(err);
	if (re_nbra > 1)
		yyerror("Too many \\(\\)'s");
	if (re_amatch(s)) {
		if (re_nbra == 1) {
			n = braelist[0] - braslist[0];
			rv = malloc(n + 1);
			strncpy(rv, braslist[0], n);
			rv[n] = 0;
			return rv;
		}
		n = re_loc2 - s;
		rv = malloc(8);
		sprintf(rv, "%d", n);
		return rv;
	}
	if (re_nbra == 1)
		return "";
	return "0";
}

yyerror(msg) char *msg;
{
	printf("expr: %s\n", msg);
	exit(2);
}
