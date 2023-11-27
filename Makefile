EXE=demovampira
PREC=4

CC=vc
CPU=040
VASM=vasmm68k_mot -quiet

AR=ar
RM=delete all quiet

DEFINES=-DPREC=$(PREC)

OFLAGS=-O1295 -speed -maxoptpasses=99
CFLAGS=$(OFLAGS) -cpu=68$(CPU) -c99 $(DEFINES) -Iinclude/vbcc -Iinclude

AFLAGS=-m68$(CPU) -Faout -phxass -nowarn=62 -opt-speed $(DEFINES)

LDFLAGS=
LIBS=-lamiga -lmieee

OBJ=main.o demovampira.o demovampira.0b.o demovampira.8b.o demovampira.16b.o

test: $(EXE)
	$< -bilinear -win

all: $(EXE)

.phony: lha
lha: all
	lha -r u $(EXE).lha $(EXE) #?.c #?.s #?.dds c2p 256x256.bmp Makefile #?.txt include

clean:
	delete demovampira #?.o
	
$(EXE): $(OBJ)
	$(CC) $(LDFLAGS) $^ -o $@  $(LIBS)

%.o: %.c Makefile
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.s Makefile
#	$(CC) $(CFLAGS) -c -o $@ $<
	$(VASM) $(AFLAGS) -o $@ $<