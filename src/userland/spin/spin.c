/* spin - preemption P2 test vehicle: a pure userland busy loop.  Never
 * syscalls after startup, so ONLY user-context IRQ preemption (the P2
 * trampoline) can ever take the CPU back from it.  Also the frame-RE
 * target: with spin in the foreground, every heartbeat fires with the
 * firmware's stacked IRQ frame pointing into spin's code bank. */
int main(int argc, char **argv)
{
    for (;;) ;
    return 0;
}
