.global syncExceptionHandler
.option arch, +zicsr

syncExceptionHandler:
    mv a0, zero
    csrr a1, mcause
    call auxMemWrite
end:
    j end
