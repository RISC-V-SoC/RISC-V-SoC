#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

static void swap_int32(int32_t* xp, int32_t* yp)
{
    int32_t temp = *xp;
    *xp = *yp;
    *yp = temp;
}

static void swap_int16(int16_t* xp, int16_t* yp)
{
    int16_t temp = *xp;
    *xp = *yp;
    *yp = temp;
}

static void swap_int8(int8_t* xp, int8_t* yp)
{
    int8_t temp = *xp;
    *xp = *yp;
    *yp = temp;
}

void bubbleSort_int32(int32_t arr[], size_t n)
{
    int i, j;
    bool swapped;
    for (i = 0; i < n - 1; i++) {
        swapped = false;
        for (j = 0; j < n - i - 1; j++) {
            if (arr[j] > arr[j + 1]) {
                swap_int32(&arr[j], &arr[j + 1]);
                swapped = true;
            }
        }
        if (swapped == false)
            break;
    }
}

void bubbleSort_int16(int16_t arr[], size_t n)
{
    int i, j;
    bool swapped;
    for (i = 0; i < n - 1; i++) {
        swapped = false;
        for (j = 0; j < n - i - 1; j++) {
            if (arr[j] > arr[j + 1]) {
                swap_int16(&arr[j], &arr[j + 1]);
                swapped = true;
            }
        }
        if (swapped == false)
            break;
    }
}

void bubbleSort_int8(int8_t arr[], size_t n)
{
    int i, j;
    bool swapped;
    for (i = 0; i < n - 1; i++) {
        swapped = false;
        for (j = 0; j < n - i - 1; j++) {
            if (arr[j] > arr[j + 1]) {
                swap_int8(&arr[j], &arr[j + 1]);
                swapped = true;
            }
        }
        if (swapped == false)
            break;
    }
}
