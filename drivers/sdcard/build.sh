export CROSSPATH=/media/storage2/amiga-code/m68k-amigaos
export GCCLIBPATH=$CROSSPATH/lib/gcc-lib/m68k-amigaos/2.95.3
export PATH=$CROSSPATH/bin:$GCCLIBPATH:$PATH
export GCC_EXEC_PREFIX=m68k-amigaos
export LIBS=$CROSSPATH/lib

m68k-amigaos-gcc -m68000 -O0 -g -o tf530sd.device -ramiga-dev -noixemul -fbaserel -I$CROSSPATH/m68k-amigaos/sys-include -I$CROSSPATH/os-include -L$LIBS -L$LIBS/gcc-lib/m68k-amigaos/2.95.3/ -L$CROSSPATH -L$LIBS/libnix tf530sd_device.c tf530sd_cmd.c -s -ldebug

