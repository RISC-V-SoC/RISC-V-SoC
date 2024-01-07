.global getSystemTime

getSystemTime:
    rdtimeh a1
    rdtime a0
    rdtimeh a4
    bne a1, a4, getSystemTime
    ret
