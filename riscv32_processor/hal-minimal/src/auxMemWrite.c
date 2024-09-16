#include "auxMemWrite.h"

#include <stdint.h>
#include <stddef.h>  

static volatile uint32_t* auxMem = (uint32_t*)0x200000;

void auxMemWrite(size_t index, uint32_t data) {
    auxMem[index] = data;
}
