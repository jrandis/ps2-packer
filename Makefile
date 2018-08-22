PREFIX = $(PS2DEV)

MAKE = make
SUBMAKE = MAKE=$(MAKE) $(MAKE) -C
SHELL = /bin/sh
SYSTEM = $(shell uname)
LIBZA = -lz
LIBUCLA = -lucl
VERSION = 0.4.6
CC = gcc
BIN2O = ld -r -b binary
CPPFLAGS = -O3 -Wall -I. -DVERSION=\"$(VERSION)\" -DPREFIX=\"$(PREFIX)\"
INSTALL = install

ifeq ($(SYSTEM),Darwin)
CPPFLAGS += -D__APPLE__
SHARED = -dynamiclib
SHAREDSUFFIX = .dylib
CC = /usr/bin/gcc
CPPFLAGS += -I/opt/local/include -L/opt/local/lib
BIN2O = /usr/bin/ld -r -arch x86_64
else ifeq ($(OS),Windows_NT)
SHARED = -shared
SHAREDSUFFIX = .dll
else
SHARED = -shared
SHAREDSUFFIX = .so
endif

PACKERS = zlib-packer lzo-packer n2b-packer n2d-packer n2e-packer null-packer

all: ps2-packer packers stubs

install: all
	$(INSTALL) -d $(PREFIX)/bin
	$(INSTALL) -d $(PREFIX)/share/ps2-packer/module
	$(INSTALL) -d $(PREFIX)/share/ps2-packer/stub
	$(INSTALL) -m 755 ps2-packer $(PREFIX)/bin
	$(INSTALL) -m 755 $(addsuffix $(SHAREDSUFFIX),$(PACKERS)) $(PREFIX)/share/ps2-packer/module
	$(INSTALL) -m 755 ps2-packer $(PREFIX)/bin
	PREFIX=$(PREFIX) $(SUBMAKE) stub install

ps2-packer: ps2-packer.c dlopen.c
	$(CC) $(CPPFLAGS) ps2-packer.c dlopen.c -o ps2-packer

ps2-packer-lite: ps2-packer.c builtin_stub_one.o builtin_stub.o
	$(CC) $(CPPFLAGS) -DPS2_PACKER_LITE ps2-packer.c n2e-packer.c $(LIBUCLA) builtin_stub_one.o builtin_stub.o -o ps2-packer-lite

builtin_stub_one.o: stubs-tag.stamp
	cp stub/n2e-asm-one-1d00-stub ./b_stub_one
	$(BIN2O) b_stub_one -o builtin_stub_one.o
	rm b_stub_one

builtin_stub.o: stubs-tag.stamp
	cp stub/n2e-asm-1d00-stub ./b_stub
	$(BIN2O) b_stub -o builtin_stub.o
	rm b_stub

stubs: stubs-tag.stamp

stubs-tag.stamp:
	$(SUBMAKE) stub
	touch stubs-tag.stamp

packers: $(addsuffix $(SHAREDSUFFIX),$(PACKERS))

zlib-packer$(SHAREDSUFFIX): zlib-packer.c
	$(CC) -fPIC $(CPPFLAGS) zlib-packer.c $(SHARED) -o zlib-packer$(SHAREDSUFFIX) $(LIBZA)

lzo-packer$(SHAREDSUFFIX): lzo-packer.c minilzo.c
	$(CC) -fPIC $(CPPFLAGS) lzo-packer.c minilzo.c $(SHARED) -o lzo-packer$(SHAREDSUFFIX)

n2b-packer$(SHAREDSUFFIX): n2b-packer.c
	$(CC) -fPIC $(CPPFLAGS) n2b-packer.c $(SHARED) -o n2b-packer$(SHAREDSUFFIX) $(LIBUCLA)

n2d-packer$(SHAREDSUFFIX): n2d-packer.c
	$(CC) -fPIC $(CPPFLAGS) n2d-packer.c $(SHARED) -o n2d-packer$(SHAREDSUFFIX) $(LIBUCLA)

n2e-packer$(SHAREDSUFFIX): n2e-packer.c
	$(CC) -fPIC $(CPPFLAGS) n2e-packer.c $(SHARED) -o n2e-packer$(SHAREDSUFFIX) $(LIBUCLA)

null-packer$(SHAREDSUFFIX): null-packer.c
	$(CC) -fPIC $(CPPFLAGS) null-packer.c $(SHARED) -o null-packer$(SHAREDSUFFIX)


#
# This target will produce stripped stubs loaders.
#
stubs-dist:
	$(SUBMAKE) stub dist

clean:
	rm -f ps2-packer ps2-packer-lite ps2-packer.exe ps2-packer-lite.exe *.zip *.gz *.dll *$(SHAREDSUFFIX) *.o
	$(SUBMAKE) stub clean
	rm -f stubs-tag.stamp

rebuild: clean all



#
# Everything below is for me, building the distribution packages.
#

dist: all COPYING stubs-dist README.txt ps2-packer.c $(addsuffix .c,$(PACKERS))
	strip ps2-packer ps2-packer-lite $(addsuffix $(SHAREDSUFFIX),$(PACKERS))
	upx-nrv --best ps2-packer ps2-packer-lite ps2-packer.exe ps2-packer-lite.exe $(addsuffix .dll,$(PACKERS))
	tar cvfz ps2-packer-$(VERSION)-linux.tar.gz ps2-packer $(addsuffix $(SHAREDSUFFIX),$(PACKERS)) COPYING stub/*stub README.txt
	zip -9 ps2-packer-$(VERSION)-win32.zip ps2-packer.exe $(addsuffix .dll,$(PACKERS)) COPYING stub/*stub README.txt
	tar cvfz ps2-packer-lite-$(VERSION)-linux.tar.gz ps2-packer-lite COPYING README.txt README-lite.txt
	zip -9 ps2-packer-lite-$(VERSION)-win32.zip ps2-packer-lite.exe COPYING README.txt README-lite.txt
	tar cvfz ps2-packer-$(VERSION)-src.tar.gz *.{c,h} Makefile COPYING stub/{Makefile,crt0.s,dummy.s,linkfile,*.{c,h,S}} stub/ucl/*.S stub/{zlib,lzo,ucl}/{Makefile,*.{c,h}} README.txt README-lite.txt

redist: clean dist

release: redist
	rm -f /var/www/softwares/ps2-packer/*
	cp *.gz *.zip COPYING README.txt README-lite.txt /var/www/softwares/ps2-packer
