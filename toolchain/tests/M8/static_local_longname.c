/* static_local_longname: a static-local whose mangled `func_sl_var` label
 * exceeds a Merlin symbol (>= 31 chars) -- tcsh tc.prompt `print_prompt` +
 * `print_prompt_did_ding`.  The label is only the emitted global name (use
 * sites resolve via the static-alias table), so fcc now falls back to a
 * compact unique `func(trunc)_slN` instead of dying.  -> 42. */
int
print_prompt_function_longname()
{
    static int print_prompt_function_did_ding = 42;
    return print_prompt_function_did_ding;
}

int
main()
{
    return print_prompt_function_longname();
}
