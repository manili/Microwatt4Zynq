ARCH = $(shell uname -m)
ifneq ("$(ARCH)", "ppc64")
ifneq ("$(ARCH)", "ppc64le")
	CROSS_COMPILE ?= powerpc64le-linux-
endif
endif

CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy

CFLAGS = -Os -g -Wall -std=c99 -msoft-float -mno-string -mno-multiple -mno-vsx -mno-altivec -mlittle-endian -fno-stack-protector -mstrict-align -ffreestanding -fdata-sections -ffunction-sections -I.
ASFLAGS = $(CFLAGS)
LDFLAGS = -T powerpc.lds

all: mw_welcome.hex

mw_welcome.elf: mw_welcome.o head.o console.o print.o
	$(LD) $(LDFLAGS) -o $@ $^

mw_welcome.bin: mw_welcome.elf
	$(OBJCOPY) -O binary $^ $@

mw_welcome.hex: mw_welcome.bin
	./bin2hex.py $^ > mw_welcome.hex
	./bin2hex_for_c.py $^ > mw_welcome_c_ver.hex
	
clean:
	@rm -f *.o mw_welcome.elf mw_welcome.bin mw_welcome.hex mw_welcome_c_ver.hex
distclean: clean
	rm -f *~

