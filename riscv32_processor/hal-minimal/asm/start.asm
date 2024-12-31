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

    li      a0, -1
    li      a1, 5
    mulh    s0, a0, a1
    mul     s1, a0, a1
    mulhu   s2, a0, a1
    li      a0, 0
    mv      a1, s0
    call    auxMemWrite
    li      a0, 1
    mv      a1, s1
    call    auxMemWrite
    li      a0, 2
    mv      a1, s2
    call    auxMemWrite

back_stop:
    j back_stop
