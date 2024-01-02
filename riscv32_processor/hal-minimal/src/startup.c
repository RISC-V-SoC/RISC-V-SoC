#include <string.h>
#include <stdlib.h>

void main(void);

void startup(void) __attribute__ ((noreturn));

__attribute__((section(".text.startup"))) void startup(void);
void startup(void) {

    main();

    while(1);
}
