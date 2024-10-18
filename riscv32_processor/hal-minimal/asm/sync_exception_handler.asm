.global syncExceptionHandler
.option arch, +zicsr

exceptionReturn:
    auipc a1, 0
    li a0, 2
    call auxMemWrite
end:
    j end

syncExceptionHandler:
    mv a0, zero
    csrr a1, mcause
    call auxMemWrite
    li a0, 1
    csrr a1, mepc
    call auxMemWrite
    la a0, exceptionReturn
    csrw mepc, a0
    mret
