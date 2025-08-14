.global trapVector

trapVector:
    # Offset 0*4, synchronous exception handler
    j syncExceptionHandler
    # Offset 1*4, Supervisor software interrupt
    nop
    # Offset 2*4, reserved
    nop
    # Offset 3*4, Machine software interrupt
    nop
    # Offset 4*4, reserved
    nop
    # Offset 5*4, supervisor timer interrupt
    nop
    # Offset 6*4, reserved
    nop
    # Offset 7*4, machine timer interrupt
    j machineTimerInterruptHandler
    # Offset 8*4, reserved
    nop
    # Offset 9*4, supervisor external interrupt
    nop
    # Offset 10*4, reserved
    nop
    # Offset 11*4, machine external interrupt
    j machineExternalInterruptHandler
