/* ---- str* family (C4 batch 3) — __asm loops over the staged cells ------- */

int strlen(char *s)
{
    __asm_p0 = s;
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDY #0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "@lccsln_lp",
        "LDA [c_strcmp_a],Y",
        "BEQ @lccsln_done",
        "INY",
        "BRA @lccsln_lp",
        "@lccsln_done",
        "REP #$20",
        "MX %00",
        "STY __asm_w0"
    );
    return __asm_w0;
}

int strcmp(char *a, char *b)
{
    __asm_p0 = a;
    __asm_p1 = b;
    /* the M8 CMP's carry survives REP/LDA #1 to pick the sign */
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDA __asm_p1",
        "STA c_strcmp_b",
        "LDY #0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "LDA __asm_p1+2",
        "STA c_strcmp_b+2",
        "@lccscm_lp",
        "LDA [c_strcmp_a],Y",
        "CMP [c_strcmp_b],Y",
        "BNE @lccscm_diff",
        "CMP #0",
        "BEQ @lccscm_eq",
        "INY",
        "BRA @lccscm_lp",
        "@lccscm_diff",
        "REP #$20",
        "MX %00",
        "LDA #1",
        "BCS @lccscm_set",
        "LDA #$FFFF",
        "@lccscm_set",
        "STA __asm_w0",
        "BRA @lccscm_out",
        "@lccscm_eq",
        "REP #$20",
        "MX %00",
        "STZ __asm_w0",
        "@lccscm_out",
        "MX %00"
    );
    return __asm_w0;
}

int strncmp(char *a, char *b, int n)
{
    __asm_p0 = a;
    __asm_p1 = b;
    __asm_w1 = n;
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDA __asm_p1",
        "STA c_strcmp_b",
        "LDX __asm_w1",
        "LDY #0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "LDA __asm_p1+2",
        "STA c_strcmp_b+2",
        "@lccsnm_lp",
        "CPX #0",
        "BEQ @lccsnm_eq",
        "DEX",
        "LDA [c_strcmp_a],Y",
        "CMP [c_strcmp_b],Y",
        "BNE @lccsnm_diff",
        "CMP #0",
        "BEQ @lccsnm_eq",
        "INY",
        "BRA @lccsnm_lp",
        "@lccsnm_diff",
        "REP #$20",
        "MX %00",
        "LDA #1",
        "BCS @lccsnm_set",
        "LDA #$FFFF",
        "@lccsnm_set",
        "STA __asm_w0",
        "BRA @lccsnm_out",
        "@lccsnm_eq",
        "REP #$20",
        "MX %00",
        "STZ __asm_w0",
        "@lccsnm_out",
        "MX %00"
    );
    return __asm_w0;
}

int memcmp(void *a, void *b, int n)
{
    __asm_p0 = (char *)a;
    __asm_p1 = (char *)b;
    __asm_w1 = n;
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDA __asm_p1",
        "STA c_strcmp_b",
        "LDX __asm_w1",
        "LDY #0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "LDA __asm_p1+2",
        "STA c_strcmp_b+2",
        "@lccmcm_lp",
        "CPX #0",
        "BEQ @lccmcm_eq",
        "DEX",
        "LDA [c_strcmp_a],Y",
        "CMP [c_strcmp_b],Y",
        "BNE @lccmcm_diff",
        "INY",
        "BRA @lccmcm_lp",
        "@lccmcm_diff",
        "REP #$20",
        "MX %00",
        "LDA #1",
        "BCS @lccmcm_set",
        "LDA #$FFFF",
        "@lccmcm_set",
        "STA __asm_w0",
        "BRA @lccmcm_out",
        "@lccmcm_eq",
        "REP #$20",
        "MX %00",
        "STZ __asm_w0",
        "@lccmcm_out",
        "MX %00"
    );
    return __asm_w0;
}

char *strcpy(char *d, char *s)
{
    __asm_p0 = d;
    __asm_p1 = s;
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDA __asm_p1",
        "STA c_strcmp_b",
        "LDY #0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "LDA __asm_p1+2",
        "STA c_strcmp_b+2",
        "@lccscp_lp",
        "LDA [c_strcmp_b],Y",
        "STA [c_strcmp_a],Y",
        "BEQ @lccscp_done",
        "INY",
        "BRA @lccscp_lp",
        "@lccscp_done",
        "REP #$20",
        "MX %00"
    );
    return d;
}

char *strncpy(char *d, char *s, int n)
{
    __asm_p0 = d;
    __asm_p1 = s;
    __asm_w1 = n;
    /* copies at most n bytes; on early NUL the remainder is zero-padded */
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDA __asm_p1",
        "STA c_strcmp_b",
        "LDX __asm_w1",
        "LDY #0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "LDA __asm_p1+2",
        "STA c_strcmp_b+2",
        "@lccsnp_lp",
        "CPX #0",
        "BEQ @lccsnp_done",
        "DEX",
        "LDA [c_strcmp_b],Y",
        "STA [c_strcmp_a],Y",
        "BEQ @lccsnp_pad",
        "INY",
        "BRA @lccsnp_lp",
        "@lccsnp_pad",
        "INY",
        "CPX #0",
        "BEQ @lccsnp_done",
        "DEX",
        "LDA #0",
        "STA [c_strcmp_a],Y",
        "BRA @lccsnp_pad",
        "@lccsnp_done",
        "REP #$20",
        "MX %00"
    );
    return d;
}

char *strncat(char *d, char *s, int n)
{
    char *p = d;

    while (*p)
        p++;
    while (n-- > 0 && *s)
        *p++ = *s++;
    *p = 0;
    return d;
}

char *strcat(char *d, char *s)
{
    __asm_p0 = d;
    __asm_p1 = s;
    /* walk d to its NUL, advance the DP dst pointer, then strcpy s */
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDA __asm_p1",
        "STA c_strcmp_b",
        "LDY #0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "LDA __asm_p1+2",
        "STA c_strcmp_b+2",
        "@lccsct_endl",
        "LDA [c_strcmp_a],Y",
        "BEQ @lccsct_at",
        "INY",
        "BRA @lccsct_endl",
        "@lccsct_at",
        "REP #$20",
        "MX %00",
        "TYA",
        "CLC",
        "ADC c_strcmp_a",
        "STA c_strcmp_a",
        "LDY #0",
        "SEP #$20",
        "MX %10",
        "@lccsct_cp",
        "LDA [c_strcmp_b],Y",
        "STA [c_strcmp_a],Y",
        "BEQ @lccsct_done",
        "INY",
        "BRA @lccsct_cp",
        "@lccsct_done",
        "REP #$20",
        "MX %00"
    );
    return d;
}

char *strchr(char *s, int c)
{
    __asm_p0 = s;
    __asm_w1 = c & 0xFF;
    /* w0 = index of first match ($FFFF = none); c==0 finds the NUL */
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDY #0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "@lccsch_lp",
        "LDA [c_strcmp_a],Y",
        "CMP __asm_w1",
        "BEQ @lccsch_found",
        "CMP #0",
        "BEQ @lccsch_none",
        "INY",
        "BRA @lccsch_lp",
        "@lccsch_found",
        "REP #$20",
        "MX %00",
        "STY __asm_w0",
        "BRA @lccsch_out",
        "@lccsch_none",
        "REP #$20",
        "MX %00",
        "LDA #$FFFF",
        "STA __asm_w0",
        "@lccsch_out",
        "MX %00"
    );
    if (__asm_w0 == -1)
        return (char *)0;
    return s + __asm_w0;
}

char *strrchr(char *s, int c)
{
    __asm_p0 = s;
    __asm_w1 = c & 0xFF;
    /* X tracks the LAST match index; the match test runs before the NUL
     * stop, so c==0 records the terminator (standard) */
    __asm(
        "LDA __asm_p0",
        "STA c_strcmp_a",
        "LDX #$FFFF",
        "LDY #0",
        "SEP #$20",
        "MX %10",
        "LDA __asm_p0+2",
        "STA c_strcmp_a+2",
        "@lccsrr_lp",
        "LDA [c_strcmp_a],Y",
        "CMP __asm_w1",
        "BNE @lccsrr_no",
        "TYX",
        "@lccsrr_no",
        "CMP #0",
        "BEQ @lccsrr_done",
        "INY",
        "BRA @lccsrr_lp",
        "@lccsrr_done",
        "REP #$20",
        "MX %00",
        "STX __asm_w0"
    );
    if (__asm_w0 == -1)
        return (char *)0;
    return s + __asm_w0;
}

/* strspn - length of the initial run of s made up of chars from `set`.
 * (stty(1) uses it to tell an option like -a from a mode arg like -echo.) */
int strspn(char *s, char *set)
{
    char *p;

    for (p = s; *p; p++)
        if (!strchr(set, *p))
            break;
    return p - s;
}
