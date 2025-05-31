.section .text.startup
.global __start
.option arch, +zicsr

__start:
.option push
.option norelax
    # Load stackpointer
    la      sp, _stack_start
    # Set gp to this value to detect if instructions after exception have no effect
    li      gp, 0xffffffff
.option pop
    # Setup the trap vector
    la      a0, syncExceptionHandler
    csrw    mtvec,a0
    li      s1, 0
    li      s2, 10
.L1:
    li      a0, 0
    mv      a1, s1
    addi    s1, s1, 1
    call    auxMemWrite
    bge     s2, s1, .L1
back_stop:
    j back_stop
