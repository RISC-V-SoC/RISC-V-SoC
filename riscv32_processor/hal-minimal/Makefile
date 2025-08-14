AS:=riscv-none-elf-as
GCC:=riscv-none-elf-gcc
LD:=riscv-none-elf-ld
OBJCOPY:=riscv-none-elf-objcopy
OBJDUMP:=riscv-none-elf-objdump
ASMDIR:=asm/
SRCDIR:=src/
ODIR=obj/
OFILES := $(patsubst %.asm,%.asm.o,$(wildcard $(ASMDIR)*.asm))
OFILES += $(patsubst %.c,%.c.o,$(wildcard $(SRCDIR)*.c))
OFILES := $(patsubst $(ASMDIR)%,$(ODIR)%,$(OFILES))
OFILES := $(patsubst $(SRCDIR)%,$(ODIR)%,$(OFILES))
TARGET:=final
TARGETBIN:=final.bin
TARGETTXT:=final.txt
TARGETASMDUMP := final.disas
LDFLAGS := -Wl,--gc-sections
ARCHFLAGS := -march=rv32im -mabi=ilp32
.PHONY: all release clean

all: release
release: $(TARGETTXT) $(TARGETASMDUMP)

$(ODIR):
	mkdir -p $(@)

$(ODIR)%.asm.o: $(ASMDIR)%.asm | $(ODIR)
	$(AS) $(ARCHFLAGS) $< -o $@

$(ODIR)%.c.o: $(SRCDIR)%.c | $(ODIR)
	$(GCC) $(ARCHFLAGS) -Iinc -mbranch-cost=2 -O3 -c $< -o $@

$(TARGET): $(OFILES)
	$(GCC) -o $@ $^ $(LDFLAGS) -Tlinker_script.ld $(ARCHFLAGS)

$(TARGETBIN): $(TARGET)
	$(OBJCOPY) -j .text -j .data -j .bss -O binary $^ $@

$(TARGETTXT): $(TARGETBIN)
	od --address-radix=n --output-duplicates --width=4 --format=x4 $^ | tr -d ' ' > $@

$(TARGETASMDUMP): $(TARGET)
	$(OBJDUMP) -D $< > $@

clean:
	rm -rf $(ODIR) $(TARGET) $(TARGETBIN) $(TARGETTXT) $(TARGETASMDUMP)
