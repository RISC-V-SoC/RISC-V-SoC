#include "bubbleSort.h"

#define ARRAY_LENGTH(array) (sizeof((array))/sizeof((array)[0]))

int32_t array_int32[] = {2, -4, 1, -3, 0, -2, -5, 3, 5, 4, -1, -6};
int16_t array_int16[] = {2, -4, 1, -3, 0, -2, -5, 3, 5, 4, -1, -6};
int8_t array_int8[] = {2, -4, 1, -3, 0, -2, -5, 3, 5, 4, -1, -6};

void main() {
    bubbleSort_int32(array_int32, ARRAY_LENGTH(array_int32));
    bubbleSort_int16(array_int16, ARRAY_LENGTH(array_int16));
    bubbleSort_int8(array_int8, ARRAY_LENGTH(array_int8));
}
