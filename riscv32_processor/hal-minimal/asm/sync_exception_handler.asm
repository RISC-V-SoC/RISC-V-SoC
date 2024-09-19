.global syncExceptionHandler
.option arch, +zicsr

syncExceptionHandler:
    mv a0, zero
    csrr a1, mcause
    call auxMemWrite
    li a0, 1
    csrr a1, mepc
    call auxMemWrite
end:
    j end
