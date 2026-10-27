PROJ  := Lab0_ArrayMultiply
CC    := arm-none-eabi-gcc
BUILD := build
ELF   := $(BUILD)/$(PROJ).elf

CPUFLAGS := -mcpu=cortex-a8 -marm
ASFLAGS  := $(CPUFLAGS) -g -Wa,-adhlns=$(BUILD)/$(PROJ).lst
# -nostdlib implies the tutorial's -nostartfiles and also drops libc/libgcc,
# which pure assembly never calls: main.S owns reset, vectors and SP.
# AM335x.lds is the course template's, which sizes the stack and heap from
# these symbols; the values are the wizard's (its .cproject DEFSYM list).
LDFLAGS  := -nostdlib -T AM335x.lds -Wl,-Map=$(BUILD)/$(PROJ).map \
            -Wl,--defsym=STACKSIZE=0x1C000 -Wl,--defsym=HEAPSIZE=0x400

.PHONY: all clean

all: $(ELF)

$(ELF): main.S AM335x.lds | $(BUILD)
	$(CC) $(ASFLAGS) $(LDFLAGS) -o $@ main.S

$(BUILD):
	mkdir -p $@

clean:
	rm -rf $(BUILD)
