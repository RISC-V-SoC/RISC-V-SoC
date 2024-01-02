ENTRY(__start)

MEMORY
{
    SRAM (rwx) : ORIGIN = 0x100000, LENGTH = 0x400
}

SECTIONS
{
    .text :
    {
        *(.text.startup)
        *(.text)
    } > SRAM

    .data :
    {
        *(vtable)
        *(.data)
        *(.rodata)
    } > SRAM

    .bss :
    {
        *(.bss)
    } > SRAM

    .heap :
    {
        . = ALIGN(8);
        _heap_start = .;
    } > SRAM

    _stack_start = ORIGIN(SRAM) + LENGTH(SRAM);
    _global_pointer = ORIGIN(SRAM) + LENGTH(SRAM)/2;
}
