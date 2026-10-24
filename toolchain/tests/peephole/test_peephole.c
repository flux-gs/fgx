#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../../src/cc/peephole.h"

static int g_tests = 0, g_fails = 0;

static void check(const char *name, const char *in, const char *want)
{
    char *got = peephole_optimize(in);
    g_tests++;
    if (got == NULL || strcmp(got, want) != 0) {
        g_fails++;
        printf("FAIL %s\n  in:   [%s]\n  want: [%s]\n  got:  [%s]\n",
               name, in, want, got ? got : "(null)");
    } else {
        printf("ok   %s\n", name);
    }
    free(got);
}

int main(void)
{
    check("noop_empty",       "",                "");
    check("noop_passthrough", "                LDA     #5\n",
                              "                LDA     #5\n");

    /* render must reproduce input exactly when nothing is deleted */
    check("render_label_only", "fn_main            ENT\n",
                               "fn_main            ENT\n");
    check("render_multi",
          "                MX      %00\n                LDA     #5\n; tail\n",
          "                MX      %00\n                LDA     #5\n; tail\n");
    check("render_no_trailing_nl",
          "                LDA     #5",
          "                LDA     #5");

    /* BRA to the very next label is a no-op jump -> drop it */
    check("bra_to_next_label",
          "                BRA     L7\nL7                 ENT\n",
          "L7                 ENT\n");
    /* BRA to a non-adjacent label must be kept */
    check("bra_to_far_label_kept",
          "                BRA     L7\n                NOP\nL7                 ENT\n",
          "                BRA     L7\n                NOP\nL7                 ENT\n");
    /* BRL behaves the same */
    check("brl_to_next_label",
          "                BRL     L9\nL9                 ENT\n",
          "L9                 ENT\n");

    /* a lone STA then RTL: nothing to delete; classifier must not misfire */
    check("classify_no_false_delete",
          "                STA     5,s\n                RTL\n",
          "                STA     5,s\n                RTL\n");

    /* LDA then LDA: first LDA's NZ overwritten by second -> dead */
    if (ph_test_nz_dead_after(
            "                LDA     1,s\n                LDA     2,s\n", 0) != 1)
        { g_fails++; g_tests++; printf("FAIL nz_dead_overwritten\n"); }
    else { g_tests++; printf("ok   nz_dead_overwritten\n"); }

    /* LDA then BEQ: NZ read by the branch -> live */
    if (ph_test_nz_dead_after(
            "                LDA     1,s\n                BEQ     L1\n", 0) != 0)
        { g_fails++; g_tests++; printf("FAIL nz_live_branch\n"); }
    else { g_tests++; printf("ok   nz_live_branch\n"); }

    /* LDA then RTL: flags dead at return */
    if (ph_test_nz_dead_after(
            "                LDA     1,s\n                RTL\n", 0) != 1)
        { g_fails++; g_tests++; printf("FAIL nz_dead_return\n"); }
    else { g_tests++; printf("ok   nz_dead_return\n"); }

    /* STA m ; LDA m  with NZ dead (overwritten next) -> drop the LDA */
    check("staload_forward",
          "                STA     5,s\n                LDA     5,s\n                LDA     #0\n",
          "                STA     5,s\n                LDA     #0\n");
    /* STA m ; LDA m  but NZ live (branch follows) -> keep the LDA */
    check("staload_keep_when_nz_live",
          "                STA     5,s\n                LDA     5,s\n                BEQ     L1\n",
          "                STA     5,s\n                LDA     5,s\n                BEQ     L1\n");
    /* different operand -> staload-forward must keep the LDA.  (Trailing store
     * keeps the loaded value LIVE so the option-C dead-LDA pass doesn't remove it
     * for an unrelated reason -- this test isolates staload operand discrimination.) */
    check("staload_keep_diff_operand",
          "                STA     5,s\n                LDA     6,s\n                STA     7,s\n",
          "                STA     5,s\n                LDA     6,s\n                STA     7,s\n");

    /* duplicate REP -> drop the second */
    check("rep_dup",
          "                REP     #$20\n                REP     #$20\n                LDA     #0\n",
          "                REP     #$20\n                LDA     #0\n");
    /* SEP then REP, same operand, adjacent -> cancel both */
    check("sep_rep_cancel",
          "                SEP     #$20\n                REP     #$20\n                LDA     #0\n",
          "                LDA     #0\n");
    /* different operands -> keep both */
    check("sep_rep_diff_kept",
          "                SEP     #$20\n                REP     #$10\n",
          "                SEP     #$20\n                REP     #$10\n");
    /* an instruction between -> keep (something ran in the changed mode) */
    check("rep_nonadjacent_kept",
          "                REP     #$20\n                NOP\n                REP     #$20\n",
          "                REP     #$20\n                NOP\n                REP     #$20\n");

    /* --- Task 1.2: CLC;ADC #k -> INC*k / SEC;SBC #k -> DEC*k (carry dead) ---
     * INC/DEC are the implied-accumulator forms (Merlin32 rejects INA/DEA). */
    check("clcadc_to_ina",
          "                CLC\n                ADC     #1\n                STA     5,s\n                RTL\n",
          "                INC\n                STA     5,s\n                RTL\n");
    check("clcadc_to_ina2",
          "                CLC\n                ADC     #2\n                RTL\n",
          "                INC\n                INC\n                RTL\n");
    check("secsbc_to_dea",
          "                SEC\n                SBC     #1\n                RTL\n",
          "                DEC\n                RTL\n");
    /* carry consumed by a following ADC -> the add's carry is LIVE; keep */
    check("clcadc_keep_carry_live",
          "                CLC\n                ADC     #1\n                ADC     7,s\n                RTL\n",
          "                CLC\n                ADC     #1\n                ADC     7,s\n                RTL\n");
    /* immediate out of {1,2} -> keep */
    check("clcadc_keep_large_imm",
          "                CLC\n                ADC     #100\n                RTL\n",
          "                CLC\n                ADC     #100\n                RTL\n");
    /* labelled CLC is a branch target -> never fold */
    check("clcadc_keep_labeled",
          "L1                 CLC\n                ADC     #1\n                RTL\n",
          "L1                 CLC\n                ADC     #1\n                RTL\n");
    /* carry read across a width toggle must NOT fold: REP/SEP are carry-neutral
     * (M/X width only), so the ADC's carry survives the SEP to the 8-bit ADC. */
    check("clcadc_keep_carry_across_sep",
          "                CLC\n                ADC     #1\n                SEP     #$20\n                ADC     7,s\n                RTL\n",
          "                CLC\n                ADC     #1\n                SEP     #$20\n                ADC     7,s\n                RTL\n");
    /* hook: ADC then BCC reads carry -> carry live (0) */
    if (ph_test_carry_dead_after("                ADC     #1\n                BCC     L1\n", 0) != 0)
        { g_fails++; g_tests++; printf("FAIL carry_live_bcc\n"); }
    else { g_tests++; printf("ok   carry_live_bcc\n"); }

    /* dead store: STA loc then STA loc, no read between -> drop the first */
    check("deadstore_basic",
          "                STA     _fcc_ptr+2\n                LDA     #0\n                STA     _fcc_ptr+2\n",
          "                LDA     #0\n                STA     _fcc_ptr+2\n");
    /* LIVE: [_fcc_ptr] derefs the bank between the two stores -> keep the first */
    check("deadstore_live_indirect_load",
          "                STA     _fcc_ptr+2\n                LDA     [_fcc_ptr]\n                STA     _fcc_ptr+2\n",
          "                STA     _fcc_ptr+2\n                LDA     [_fcc_ptr]\n                STA     _fcc_ptr+2\n");
    /* LIVE: STA [_fcc_ptr],Y stores THROUGH the pointer = reads the bank -> keep */
    check("deadstore_live_indirect_store",
          "                STA     _fcc_ptr+2\n                STA     [_fcc_ptr],Y\n                STA     _fcc_ptr+2\n",
          "                STA     _fcc_ptr+2\n                STA     [_fcc_ptr],Y\n                STA     _fcc_ptr+2\n");
    /* LIVE: indexed deref [_fcc_ptr],Y read -> keep */
    check("deadstore_live_indirect_ldy",
          "                STA     _fcc_ptr+2\n                LDA     [_fcc_ptr],Y\n                STA     _fcc_ptr+2\n",
          "                STA     _fcc_ptr+2\n                LDA     [_fcc_ptr],Y\n                STA     _fcc_ptr+2\n");
    /* different scratch: [_fcc_ptr2] must NOT count as a read of _fcc_ptr -> drop */
    check("deadstore_other_scratch_dropped",
          "                STA     _fcc_ptr\n                LDA     [_fcc_ptr2]\n                STA     _fcc_ptr\n",
          "                LDA     [_fcc_ptr2]\n                STA     _fcc_ptr\n");
    /* offset dead despite interleaved bank store (STA _fcc_ptr+2 != loc) -> drop */
    check("deadstore_offset_across_bank",
          "                STA     _fcc_ptr\n                STA     _fcc_ptr+2\n                STA     _fcc_ptr\n",
          "                STA     _fcc_ptr+2\n                STA     _fcc_ptr\n");
    /* LIVE across a call (callee may read _fcc_ptr) -> keep */
    check("deadstore_live_across_call",
          "                STA     _fcc_ptr+2\n                JSR     foo\n                STA     _fcc_ptr+2\n",
          "                STA     _fcc_ptr+2\n                JSR     foo\n                STA     _fcc_ptr+2\n");
    /* LIVE across a label (branch target) -> keep */
    check("deadstore_live_across_label",
          "                STA     _fcc_ptr+2\nL1                 LDA     #0\n                STA     _fcc_ptr+2\n",
          "                STA     _fcc_ptr+2\nL1                 LDA     #0\n                STA     _fcc_ptr+2\n");
    /* direct LDA loc read -> keep */
    check("deadstore_live_direct_read",
          "                STA     _fcc_ptr+2\n                LDA     _fcc_ptr+2\n                STA     _fcc_ptr+2\n",
          "                STA     _fcc_ptr+2\n                LDA     _fcc_ptr+2\n                STA     _fcc_ptr+2\n");
    /* merlin32 DO/ELSE/FIN: an overwrite inside a conditional-assembly branch is
     * not guaranteed to assemble -> keep the preceding store */
    check("deadstore_keep_across_do",
          "                STA     _fcc_ptr+2\n                DO      1\n                STA     _fcc_ptr+2\n                FIN\n",
          "                STA     _fcc_ptr+2\n                DO      1\n                STA     _fcc_ptr+2\n                FIN\n");
    /* overwrite AFTER the FIN is unconditional (depth 0) -> the first IS dead
     * (scan through the DO/ELSE/FIN block to reach it).  No deref between. */
    check("deadstore_drop_after_fin",
          "                STA     _fcc_ptr+2\n                DO      1\n                NOP\n                FIN\n                STA     _fcc_ptr+2\n",
          "                DO      1\n                NOP\n                FIN\n                STA     _fcc_ptr+2\n");
    /* FGX2 far call (--far-calls): callee may read loc -> barrier, keep the store */
    check("deadstore_keep_across_farcall",
          "                STA     g\n                FGX2_FARCALL foo\n                STA     g\n",
          "                STA     g\n                FGX2_FARCALL foo\n                STA     g\n");
    /* a labeled (branch-target) store must never be dropped (would drop its label) */
    check("deadstore_keep_labeled",
          "L5              STA     g\n                STA     g\n",
          "L5              STA     g\n                STA     g\n");

    /* --- option C, pattern 1: dead LDA --- */
    /* adjacent LDA/LDA: first A is overwritten unread -> drop the first */
    check("dead_lda_basic",
          "                LDA     #0\n                LDA     #3\n",
          "                LDA     #3\n");
    /* width directives between are A-neutral -> still dead (the bank-setup cascade) */
    check("dead_lda_skip_width",
          "                LDA     #1\n                REP     #$20\n                MX      %00\n                LDA     #2\n",
          "                REP     #$20\n                MX      %00\n                LDA     #2\n");
    /* memory RMW (operand form) is A-neutral -> skipped */
    check("dead_lda_skip_mem_inc",
          "                LDA     #5\n                INC     _fcc_img0\n                LDA     #2\n",
          "                INC     _fcc_img0\n                LDA     #2\n");
    /* a store READS A -> live -> keep */
    check("dead_lda_keep_stored",
          "                LDA     #5\n                STA     5,s\n                LDA     #2\n",
          "                LDA     #5\n                STA     5,s\n                LDA     #2\n");
    /* A-ALU reads A -> keep */
    check("dead_lda_keep_alu",
          "                LDA     #5\n                ADC     7,s\n                RTL\n",
          "                LDA     #5\n                ADC     7,s\n                RTL\n");
    /* implied INC = INC A reads A -> keep */
    check("dead_lda_keep_implied_inc",
          "                LDA     #5\n                INC\n                STA     5,s\n",
          "                LDA     #5\n                INC\n                STA     5,s\n");
    /* a branch is a barrier (N/Z may be read) -> keep */
    check("dead_lda_keep_branch",
          "                LDA     #5\n                BEQ     L1\n",
          "                LDA     #5\n                BEQ     L1\n");
    /* the redefining LDA is a branch target (labeled) -> keep (A live-in from elsewhere) */
    check("dead_lda_keep_labeled_redef",
          "                LDA     #5\nL1                 LDA     #2\n",
          "                LDA     #5\nL1                 LDA     #2\n");
    /* TXA redefines A without reading it -> first LDA dead */
    check("dead_lda_redef_txa",
          "                LDA     #5\n                TXA\n",
          "                TXA\n");
    /* PLA redefines A -> first LDA dead */
    check("dead_lda_redef_pla",
          "                LDA     #5\n                PLA\n",
          "                PLA\n");
    /* a labeled LDA is itself a branch target -> never drop */
    check("dead_lda_keep_self_labeled",
          "L9                 LDA     #5\n                LDA     #2\n",
          "L9                 LDA     #5\n                LDA     #2\n");
    /* width NARROWING (SEP): a later 8-bit redefine is a PARTIAL overwrite, so a
     * prior 16-bit LDA's high byte is live -> KEEP across the SEP (review lens A). */
    check("dead_lda_keep_across_sep",
          "                LDA     #$1234\n                SEP     #$20\n                MX      %10\n                LDA     #$56\n                STA     g\n",
          "                LDA     #$1234\n                SEP     #$20\n                MX      %10\n                LDA     #$56\n                STA     g\n");
    /* TSB (memory form) READS A (M |= A) -> the feeding LDA #mask is live -> KEEP
     * (review lens C): TSB/TRB must not be treated as A-neutral. */
    check("dead_lda_keep_before_tsb",
          "                LDA     #$0001\n                TSB     _flag\n                LDA     #5\n",
          "                LDA     #$0001\n                TSB     _flag\n                LDA     #5\n");
    /* hook: LDA then LDA -> dead (1) */
    if (ph_test_dead_a_after("                LDA     #0\n                LDA     #3\n", 0) != 1)
        { g_fails++; g_tests++; printf("FAIL dead_a_overwritten\n"); }
    else { g_tests++; printf("ok   dead_a_overwritten\n"); }
    /* hook: LDA then STA (reads A) -> live (0) */
    if (ph_test_dead_a_after("                LDA     #0\n                STA     5,s\n", 0) != 0)
        { g_fails++; g_tests++; printf("FAIL dead_a_live_store\n"); }
    else { g_tests++; printf("ok   dead_a_live_store\n"); }

    /* --- option C, pattern 2: empty width round-trip --- */
    /* SEP/MX .. REP/MX wrapper, nothing real between, entry MX == exit MX -> drop all 4 */
    check("ewr_drop_wrapper",
          "                MX      %00\n                SEP     #$20\n                MX      %10\n                REP     #$20\n                MX      %00\n                LDA     #1\n",
          "                MX      %00\n                LDA     #1\n");
    /* a real instruction inside the wrapper -> keep (something ran at 8-bit) */
    check("ewr_keep_nonempty",
          "                MX      %00\n                SEP     #$20\n                MX      %10\n                STA     g\n                REP     #$20\n                MX      %00\n",
          "                MX      %00\n                SEP     #$20\n                MX      %10\n                STA     g\n                REP     #$20\n                MX      %00\n");
    /* entry MX (%10) != exit MX (%00) -> NET width change -> keep (unsafe to drop).
     * MX-separated so this exercises pattern 2 (not the adjacent pat_repsep). */
    check("ewr_keep_net_change",
          "                MX      %10\n                SEP     #$20\n                MX      %10\n                REP     #$20\n                MX      %00\n",
          "                MX      %10\n                SEP     #$20\n                MX      %10\n                REP     #$20\n                MX      %00\n");
    /* no prevailing entry MX in the BB (ENT boundary) -> can't prove net-zero -> keep */
    check("ewr_keep_no_entry_mx",
          "main               ENT\n                SEP     #$20\n                MX      %10\n                REP     #$20\n                MX      %00\n",
          "main               ENT\n                SEP     #$20\n                MX      %10\n                REP     #$20\n                MX      %00\n");
    /* TWO interior MX -> BOTH must be deleted (review lens B), else the survivor
     * desyncs the assembler width.  Drop SEP/REP + both interior MX + exit MX. */
    check("ewr_drop_two_interior_mx",
          "                MX      %00\n                SEP     #$20\n                MX      %10\n                MX      %10\n                REP     #$20\n                MX      %00\n                LDA     #1\n",
          "                MX      %00\n                LDA     #1\n");
    /* a LABELED interior MX is a branch target -> bail, keep the whole block (lens C) */
    check("ewr_keep_labeled_mx",
          "                MX      %00\n                SEP     #$20\nL1                 MX      %10\n                REP     #$20\n                MX      %00\n",
          "                MX      %00\n                SEP     #$20\nL1                 MX      %10\n                REP     #$20\n                MX      %00\n");
    /* pat_repsep_adjacent cancel must NOT drop a LABELED first line (lens B): the
     * label would be lost.  Keep both. */
    check("repsep_keep_labeled_cancel",
          "L1                 SEP     #$20\n                REP     #$20\n                LDA     #0\n",
          "L1                 SEP     #$20\n                REP     #$20\n                LDA     #0\n");


    /* pat_neg_const: a negated literal is loaded directly */
    check("neg_const_fold",
          "                LDA     #1\n                EOR     #$FFFF\n                INC\n                STA     x\n", "                LDA     #$FFFF\n                STA     x\n");
    /* ...but never a LABELED load, whose label is a branch target */
    check("neg_const_keep_labeled",
          "L1                 LDA     #1\n                EOR     #$FFFF\n                INC\n                STA     x\n", "L1                 LDA     #1\n                EOR     #$FFFF\n                INC\n                STA     x\n");

    /* pat_tmpb_const: the reader takes the literal; the store and the dead
     * load go */
    check("tmpb_cmp_const",
          "                LDA     #10\n                STA     _fcc_tmp_b\n                TXA\n                CMP     _fcc_tmp_b\n                BEQ     L2\n", "                TXA\n                CMP     #10\n                BEQ     L2\n");
    /* a stacked constant: PHA / LDA #k / STA / PLA / CMP -> CMP #k */
    check("tmpb_cmp_stacked",
          "                PHA\n                LDA     #5\n                STA     _fcc_tmp_b\n                PLA\n                CMP     _fcc_tmp_b\n                BNE     L2\n", "                CMP     #5\n                BNE     L2\n");
    /* SEC between the transfer and the reader */
    check("tmpb_sbc_const",
          "                LDA     #0\n                STA     _fcc_tmp_b\n                TXA\n                SEC\n                SBC     _fcc_tmp_b\n                BVC     L4\n", "                TXA\n                SEC\n                SBC     #0\n                BVC     L4\n");
    /* A is still read (ASL works on the loaded k): the load stays */
    check("tmpb_keep_live_load",
          "                LDA     #3\n                STA     _fcc_tmp_b\n                ASL\n                CLC\n                ADC     _fcc_tmp_b\n                STA     y\n", "                LDA     #3\n                ASL\n                CLC\n                ADC     #3\n                STA     y\n");
    /* _fcc_tmp_b read again later in the block: nothing changes */
    check("tmpb_keep_live_after",
          "                LDA     #10\n                STA     _fcc_tmp_b\n                TXA\n                CMP     _fcc_tmp_b\n                LDA     _fcc_tmp_b\n                STA     y\n", "                LDA     #10\n                STA     _fcc_tmp_b\n                TXA\n                CMP     _fcc_tmp_b\n                LDA     _fcc_tmp_b\n                STA     y\n");
    /* a width change between the store and the reader: nothing changes */
    check("tmpb_keep_width_change",
          "                LDA     #10\n                STA     _fcc_tmp_b\n                SEP     #$20\n                TXA\n                CMP     _fcc_tmp_b\n", "                LDA     #10\n                STA     _fcc_tmp_b\n                SEP     #$20\n                TXA\n                CMP     _fcc_tmp_b\n");
    /* a unit that reads _fcc_tmp_b with no store in the same block breaks
     * the invariant the rules rest on: none of them run */
    check("tmpb_invariant_off",
          "                LDA     _fcc_tmp_b\n                STA     y\n                LDA     #10\n                STA     _fcc_tmp_b\n                TXA\n                CMP     _fcc_tmp_b\n                BEQ     L2\n", "                LDA     _fcc_tmp_b\n                STA     y\n                LDA     #10\n                STA     _fcc_tmp_b\n                TXA\n                CMP     _fcc_tmp_b\n                BEQ     L2\n");

    /* the INC fold keeps an ADC whose V a BVC reads */
    check("clcadc_keep_v_read",
          "                CLC\n                ADC     #1\n                BVC     L5\n", "                CLC\n                ADC     #1\n                BVC     L5\n");

    /* a far conditional within reach becomes the inverse short branch */
    check("relax_pair",
          "                BNE     *+5\n                BRL     L1\n                NOP\nL1                 ENT\n",
          "                BEQ     L1\n                NOP\nL1                 ENT\n");
    /* backward, and a lone BRL becomes BRA */
    check("relax_back_brl",
          "L2                 ENT\n                NOP\n                BRL     L2\n",
          "L2                 ENT\n                NOP\n                BRA     L2\n");
    /* 43 four-byte stores put L3 at 172, beyond +127: the pair stays */
    {
        static char in[4096];
        size_t k;
        strcpy(in, "                BMI     *+5\n                BRL     L3\n");
        for (k = 0; k < 43; k++)
            strcat(in, "                STA     far\n");
        strcat(in, "L3                 ENT\n");
        check("relax_out_of_reach", in, in);
    }
    /* a line it cannot size refuses every branch across it */
    check("relax_unknown_line",
          "                BRL     L4\n                HEX     0102\nL4                 ENT\n",
          "                BRL     L4\n                HEX     0102\nL4                 ENT\n");
    /* a BRL inside the reach of a `*+7' keeps its 3 bytes */
    check("relax_pinned_by_skip",
          "                BEQ     *+7\n                LDA     #0\n                BRL     L5\n                NOP\nL5                 ENT\n",
          "                BEQ     *+7\n                LDA     #0\n                BRL     L5\n                NOP\nL5                 ENT\n");

    /* CMP #0 after LDA: N and Z are already A's, and no path reads C */
    check("cmp0_after_lda",
          "                LDA     x\n                CMP     #0\n                BNE     L6\n                RTL\nL6                 CLC\n                RTL\n",
          "                LDA     x\n                BNE     L6\n                RTL\nL6                 CLC\n                RTL\n");
    /* the taken path reads the compare's carry: kept */
    check("cmp0_keep_carry_at_label",
          "                LDA     x\n                CMP     #0\n                BNE     L7\n                RTL\nL7                 ADC     #1\n                RTL\n",
          "                LDA     x\n                CMP     #0\n                BNE     L7\n                RTL\nL7                 ADC     #1\n                RTL\n");
    /* a DO whose one arm writes C and the other does not: kept */
    check("cmp0_keep_do_one_arm",
          "                LDA     x\n                CMP     #0\n                DO      k\n                CLC\n                ELSE\n                NOP\n                FIN\n                ROL\n",
          "                LDA     x\n                CMP     #0\n                DO      k\n                CLC\n                ELSE\n                NOP\n                FIN\n                ROL\n");
    /* STA leaves N and Z from an earlier value: kept */
    check("cmp0_keep_after_sta",
          "                STA     x\n                CMP     #0\n                BEQ     L8\nL8                 RTL\n",
          "                STA     x\n                CMP     #0\n                BEQ     L8\nL8                 RTL\n");
    /* a store between leaves A, N and Z as DEC set them */
    check("cmp0_after_store",
          "                DEC\n                STA     [_fcc_fpr0]\n                CMP     #0\n                BMI     L9\n                RTL\nL9                 RTL\n",
          "                DEC\n                STA     [_fcc_fpr0]\n                BMI     L9\n                RTL\nL9                 RTL\n");
    /* TAX ; TXA puts back what A holds */
    check("tax_txa",
          "                TAX\n                TXA\n                AND     #128\n",
          "                TAX\n                AND     #128\n");

    /* (option C pattern 3 redundant-restore was dropped: 0 corpus yield.) */

    printf("\n%d/%d passed\n", g_tests - g_fails, g_tests);
    return g_fails ? 1 : 0;
}
