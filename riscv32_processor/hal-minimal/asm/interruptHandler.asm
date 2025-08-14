.global machineTimerInterruptHandler
.global machineExternalInterruptHandler
.option arch, +zicsr

machineTimerInterruptHandler:
    addi    sp,sp,-64
    # Push all caller-saves, since we are an interrupt
    sw      ra,60(sp)
    sw      t0,56(sp)
    sw      t1,52(sp)
    sw      t2,48(sp)
    sw      a0,44(sp)
    sw      a1,40(sp)
    sw      a2,36(sp)
    sw      a3,32(sp)
    sw      a4,28(sp)
    sw      a5,24(sp)
    sw      a6,20(sp)
    sw      a7,16(sp)
    sw      t3,12(sp)
    sw      t4,8(sp)
    sw      t5,4(sp)
    sw      t6,0(sp)

    li      a0,0
    jal     auxMemRead
    addi    a1,a0,1
    li      a0,0
    jal     auxMemWrite
    # Disable the timer interrupt
    li      a0, 0x80
    csrc    mie, a0
    # Restore registers to their original state before returning
    lw      ra,60(sp)
    lw      t0,56(sp)
    lw      t1,52(sp)
    lw      t2,48(sp)
    lw      a0,44(sp)
    lw      a1,40(sp)
    lw      a2,36(sp)
    lw      a3,32(sp)
    lw      a4,28(sp)
    lw      a5,24(sp)
    lw      a6,20(sp)
    lw      a7,16(sp)
    lw      t3,12(sp)
    lw      t4,8(sp)
    lw      t5,4(sp)
    lw      t6,0(sp)
    addi    sp,sp,64
    mret

machineExternalInterruptHandler:
    addi    sp,sp,-64
    # Push all caller-saves, since we are an interrupt
    sw      ra,60(sp)
    sw      t0,56(sp)
    sw      t1,52(sp)
    sw      t2,48(sp)
    sw      a0,44(sp)
    sw      a1,40(sp)
    sw      a2,36(sp)
    sw      a3,32(sp)
    sw      a4,28(sp)
    sw      a5,24(sp)
    sw      a6,20(sp)
    sw      a7,16(sp)
    sw      t3,12(sp)
    sw      t4,8(sp)
    sw      t5,4(sp)
    sw      t6,0(sp)

    li      a0,1
    jal     auxMemRead
    addi    a1,a0,1
    mv      t3, a1
    li      a0,1
    jal     auxMemWrite
    li      t4, 2
    blt     t3, t4, L1
    # Disable the machine external interrupt
    li      a0, 0x800
    csrc    mie, a0
L1:
    # Restore registers to their original state before returning
    lw      ra,60(sp)
    lw      t0,56(sp)
    lw      t1,52(sp)
    lw      t2,48(sp)
    lw      a0,44(sp)
    lw      a1,40(sp)
    lw      a2,36(sp)
    lw      a3,32(sp)
    lw      a4,28(sp)
    lw      a5,24(sp)
    lw      a6,20(sp)
    lw      a7,16(sp)
    lw      t3,12(sp)
    lw      t4,8(sp)
    lw      t5,4(sp)
    lw      t6,0(sp)
    addi    sp,sp,64
    mret
