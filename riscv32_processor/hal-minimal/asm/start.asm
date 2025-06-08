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

# Actual code
    beq zero, zero, L1
L1:
    beq zero, zero, L2
L2:
    blt zero, zero, back_stop
    mv a0, zero
    li a1, 1
    call auxMemWrite
back_stop:
    j back_stop
