.section .text.startup
.global __start
.option arch, +zicsr

__start:
.option push
.option norelax
    # Load stackpointer
    la      sp, _stack_start
    # Set gp to this value to detect if instructions after exception have no effect
    la      gp, 0xffffffff
.option pop
    # Setup the trap vector
    la      a0, syncExceptionHandler
    csrw    mtvec,a0
    # load some data from address 0 to trigger an exception
    li      a0, 0
    lw      a2, 0(a0)
    # This instruction cannot be hit
    li      gp, 0
back_stop:
    j back_stop
