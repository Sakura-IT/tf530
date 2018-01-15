all: mntsd.device mntsdtest
mntsd.device:
	./build.sh
mntsdtest:
	./build_test.sh
clean:
	rm -f *.device tf530sdtest
distclean: clean
	rm -f *~