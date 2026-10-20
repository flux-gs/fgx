/* main(int argc, char **argv) binding.
 *
 *   argc -> auto-bound to args_argc global by the prologue
 *           (LDA args_argc; STA <argc_slot>,S right after frame setup).
 *   argv -> magic param; argv[i] rewrites to a c_argv_get(i) call;
 *           bare argv (without []) errors at parse time.
 *
 * Returns 42 when invoked as `dblstar` (argc==1, 1 * 42 = 42).
 */
int main(int argc, char **argv)
{
    return argc * 42;            /* 1 * 42 = 42 when run with no args */
}
