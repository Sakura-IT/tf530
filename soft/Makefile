TARGET=testziii
VBCC=/opt/vbcc/
CC=vc
CFLAGS=-c99 +aos68k -I${VBCC}/NDK_3.9/Include/include_h/
LDFLAGS= +aos68k -lamiga

all: $(TARGET)
$(TARGET): $(TARGET).o
$(TARGET).o: $(TARGET).c
clean:
	rm -f *.o $(TARGET)
