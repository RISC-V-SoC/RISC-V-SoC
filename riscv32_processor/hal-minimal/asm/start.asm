.section .text.startup
.global __start
.option arch, +zicsr

__start:
        # Load stackpointer
        lui     sp,%hi(_stack_start)
        addi    sp,sp,%lo(_stack_start)
        # Load global pointer
        lui     gp,%hi(_global_pointer)
        addi    gp,gp,%lo(_global_pointer)
        # Setup the trap vector
        lui     a0,%hi(syncExceptionHandler)
        addi    a0,a0,%lo(syncExceptionHandler)
        csrw    mtvec,a0
        li      s0, 0x05040302
        jr s0
