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
    la      a0, trapVector
    csrw    mtvec,a0
    # Zero out relevant parts of the aux mem
    li      a0, 0
    li      a1, 0
    call    auxMemWrite
    li      a0, 1
    li      a1, 0
    call    auxMemWrite
    li      a0, 2
    li      a1, 0
    call    auxMemWrite
    # Enable both timer and external interrupt
    li      a0, 0x880
    csrs    mie, a0
    # Enable machine interrupts
    li      a0, 0x8
    csrs    mstatus, a0

back_stop:
    j back_stop
