TOP_LEVEL=tf530_sim
.PHONY: $(TOP_LEVEL)
RTLFOLDER=../rtl/
SOURCES=$(TOP_LEVEL).v $(RTLFOLDER)/bus_top.v $(RTLFOLDER)/m6800.v $(RTLFOLDER)/gayle.v $(RTLFOLDER)/ram_top.v $(RTLFOLDER)/fastram.v $(RTLFOLDER)/spiport.v $(RTLFOLDER)/ata.v
$(TOP_LEVEL): prj
	fuse -lib uni9000_ver -lib aim_ver -lib cpld_ver -lib xilinxcorelib_v -prj $(TOP_LEVEL)_beh.prj -top $(TOP_LEVEL) -o $(TOP_LEVEL) work.glbl
run: $(TOP_LEVEL) cmd
	./$(TOP_LEVEL) < $(TOP_LEVEL).cmd
clean:
	rm -fr $(TOP_LEVEL) *.prj *.vcd isim* ise* fuse* *.cmd *~ 
prj: 
	@echo "Generating $(TOP_LEVEL).prj..."
	@rm -rf $(TOP_LEVEL)_beh.prj;
	@for i in $(SOURCES); do \
		echo "verilog work $$i" >> $(TOP_LEVEL)_beh.prj; \
	done
	@for i in `ls ../model/WF68K00IP/*.VHD`; do \
		echo "vhdl work $$i" >> $(TOP_LEVEL)_beh.prj; \
	done
	@echo "verilog work $(XILINX)/verilog/src/glbl.v" >> $(TOP_LEVEL)_beh.prj
cmd:
	@echo "Generating $(TOP_LEVEL).cmd..."
	@rm -rf $(TOP_LEVEL).cmd;
	@echo "onerror {resume}" >> $(TOP_LEVEL).cmd;
	@echo "wave add /" >> $(TOP_LEVEL).cmd;
	@echo "run 10000000000 ns;" >> $(TOP_LEVEL).cmd;
