.section .text.startup
.global __start
.option arch, +zicsr

__start:
.option push
.option norelax
    # Load stackpointer
    la      sp, _stack_start
    # Load global pointer
    la      gp, __global_pointer$
.option pop
    # Setup the trap vector
    la      a0, syncExceptionHandler
    csrw    mtvec,a0
    li      s0, 0x100001
    jr s0
