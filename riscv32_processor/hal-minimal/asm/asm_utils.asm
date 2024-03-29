.global getCycleCount
.global getSystemTime
.global getInstructionsRetiredCount

getCycleCount:
    rdcycleh a1
    rdcycle a0
    rdcycleh a4
    bne a1, a4, getCycleCount
    ret

getSystemTime:
    rdtimeh a1
    rdtime a0
    rdtimeh a4
    bne a1, a4, getSystemTime
    ret

getInstructionsRetiredCount:
    rdinstreth a1
    rdinstret a0
    rdinstreth a4
    bne a1, a4, getInstructionsRetiredCount
    ret
