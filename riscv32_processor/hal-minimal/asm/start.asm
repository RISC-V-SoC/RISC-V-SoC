.section .text.startup
.global __start

__start:
        # Load stackpointer
        lui     sp,%hi(_stack_start)
        addi    sp,sp,%lo(_stack_start)
        # Load global pointer
        lui     gp,%hi(_global_pointer)
        addi    gp,gp,%lo(_global_pointer)
        # Jump to the startup function, which is a noreturn
        j startup
