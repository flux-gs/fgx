/* C-3: static local persists across calls — 3 calls -> returns 3. */
int next_id(){ static int c; c=c+1; return c; }
int main(){ next_id(); next_id(); return next_id(); }
