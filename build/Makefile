BOARD:=tf530
BUSSOURCES="../rtl/bus_top.v  ../rtl/m6800.v ../rtl/ata.v"
RAMSOURCES="../rtl/ram_top.v ../rtl/fastram.v ../rtl/gayle.v ../rtl/zxmmc.v ../rtl/autoconfig.v"

all: rev2 rev3 
rev2: clean
	make -f Makefile.cpld BOARD=$(BOARD) SOURCES=$(RAMSOURCES) SUBPROJ=ram REVISION=rev2 OPTIMIZE=density 
	make -f Makefile.cpld BOARD=$(BOARD) SOURCES=$(BUSSOURCES) SUBPROJ=bus REVISION=rev2 OPTMODE=speed OPTIMISE=speed
rev3: clean
	make -f Makefile.cpld BOARD=$(BOARD) SOURCES=$(RAMSOURCES) SUBPROJ=ram REVISION=rev3 OPTIMIZE=density
	make -f Makefile.cpld BOARD=$(BOARD) SOURCES=$(BUSSOURCES) SUBPROJ=bus REVISION=rev3 OPTMODE=speed OPTIMISE=speed
clean:	
	rm -rf work _xmsgs
distclean: clean
	rm -f *.jed *~ *.svf
