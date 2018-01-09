`timescale 1ns / 1ps

module tf530_sim;


reg CLK50M;
reg CLK40M;
reg CLK32M;
reg CLK25M;
reg CLK20M;
reg CLK16M;
reg CLK7M;
reg CLK7D;
   
integer k;   
parameter MEM_SIZE = (1<<19)-1;


   wire LDS;
   wire UDS;
   

reg [15:0] cram [0:MEM_SIZE];   
reg[15:0] memory[0:(1<<19)-1];


	// Inputs
wire CLK;
	reg RESET_COREn;
	wire BERRn;
	reg AVECn;
	reg [2:0] IPLn;
	reg DTACKn;
	reg VPAn;
	reg BRn;
	reg BGACKn;

	// Outputs
	wire [23:0] ADR;
	wire [2:0] FC;
	wire ASn;
	wire RWn;
	wire RW20;
	wire UDSn;
	wire LDSn;
	wire E;
	wire E_REAL;
	wire VMAn;
	wire BGn;

	// Bidirs
	wire [15:0] DATA;
	wire RESETn;
	wire  HALTn;
	wire  AS20;
	wire  DS20 = UDSn & LDSn;
wire [1:0] SIZ = (LDSn | UDSn) ? 'b01 : 'b10;

	// Instantiate the Unit Under Test (UUT)
	WF68K00IP_TOP uut (
		.CLK(CLK), 
		.RESET_COREn(RESET_COREn), 
		.ADR(ADR), 
		.DATA(DATA), 
		.BERRn(BERRn), 
		.RESETn(RESETn), 
		.HALTn(HALTn), 
		.FC(FC), 
		.AVECn(AVECn), 
		.IPLn(IPLn), 
		.DTACKn(DSACK1 & STERM), 
		.ASn(AS20), 
		.RWn(RW20), 
		.UDSn(UDSn), 
		.LDSn(LDSn), 
		.E(E_REAL), 
		.VMAn(VMAn), 
		.VPAn(1'b1), 
		.BRn(BRn), 
		.BGn(BG20), 
		.BGACKn(BGACKn)
	);
	
		// Instantiate the Unit Under Test (UUT)
	bus_top uut2 (
		.CLKCPU(CLK), 
		.CLK7M(CLK7M),
		.INTCYCLE(INTCYCLE),
		.IDEWAIT(IDEWAIT),
		.CPSENSE(1'b1), 
		.BG20(BG20), 
		.AS20(AS20), 
		.DS20(DS20), 
		.RW20(RW20), 
		.RW(RWn), 
		.FC(FC), 
		.SIZ(SIZ),
		//.OVR(OVR),	
		.A({ADR[23:0]}), 
		.BGACK(BGACKn), 
		.VPA(VPAn), 
		.DTACK(DTACKn), 
		.BG(BG), 
		.LDS(LDS), 
		.UDS(UDS), 
		.VMA(VMA), 
		.E(E), 
		.AS(ASn), 
		.BERR(BERRn), 
		.DSACK({DSACK1,DSACK0}), 
		.AVEC(AVEC),
		.IPL(IPLn)
	);

		// Instantiate the Unit Under Test (UUT)
	ram_top uut3 (
		.CLKCPU(CLK), 
		.RESET(RESET_COREn),
			
                .INTCYCLE(INTCYCLE),
		.IDEWAIT (IDEWAIT),

		.AS20(AS20), 
		.DS20(DS20), 
		.RW20(RW20), 

		.STERM (STERM),
		.SIZ(SIZ), 
		.A({ADR[23:0]}), 
			
		.D (DATA[15:8]),
		.IDEINT ( 1'b0 )
	);

	initial begin
	   
		$readmemh("16bit.mif", memory);
	        $readmemh("ram.mif", cram);
		$dumpfile("sim.vcd");
		$dumpvars(0, uut);
	        $dumpvars(0, uut2);
		$dumpvars(0, uut3);
		RESET_COREn = 1;
	        #10;
	   
		// Initialize Inputs
		CLK50M = 0;
		CLK40M = 0;
		CLK32M = 0;
	   CLK25M = 0;
	   CLK20M = 0;
		CLK16M = 0;
		CLK7M = 0;
		RESET_COREn = 0;
	
		AVECn = 1;
		IPLn = 'b111;
		DTACKn = 1;
		VPAn = 1;
		BRn = 1;
		BGACKn = 1;
		
		// Wait 100 ns for global reset to finish
		#100;
		
		RESET_COREn = 1;
       
		// Add stimulus here

	end
	
assign HALTn = 1;
assign CLK = CLK50M;

always 	begin
    #10; CLK50M = ~CLK50M;
end

always 	begin
    #13; CLK40M = ~CLK40M;
end

always 	begin
    #15; CLK32M = ~CLK32M;
end

always 	begin
    #20; CLK25M = ~CLK25M;
end

always 	begin
    #25; CLK20M = ~CLK20M;
end

always 	begin
    #31; CLK16M = ~CLK16M;
end

always 	begin
    #71; CLK7M = ~CLK7M;
end

always begin
   #5; CLK7D = CLK7M;
end
   
reg latch = 1;
reg [7:0] C;   
reg [15:0] DATA_IN = 'd0;   
	
reg [3:0] Q = 3; 

reg 	  overlay = 1'b1;

wire   OVR = 1'b1;
wire   RAM_ACCESS = ({ADR[23:19]} == 5'd0);
wire   ROM_ACCESS = ({ADR[23:20]} == 4'hF) || (({ADR[23:20]} == 4'h0) & overlay) ;
   
   reg DS_D;
   
   
always @(negedge CLK7M) begin

   DS_D <= (UDS & LDS);
   

   if (latch == 1) begin 
      DATA_IN <= 16'hBEEF;
   end
   
   DTACKn <= 1;
   VPAn <=   1;

   if (ASn == 1'b0) begin
      C <= C + 'd1;
   end else begin
      C <= 'd0;
   end

	Q <= Q + 1;
   
   if ((ASn == 1'b0) && ((UDS & LDS) == 1'b0)) begin   

    if (ROM_ACCESS) begin 
      		       
	   DATA_IN <= memory[{ADR[18:1]}];
	   DTACKn <= 0;
    
    end else if (RAM_ACCESS) begin
       
       DTACKn <= 0;
        
       if (RWn) begin 
           
	   DATA_IN <= cram[{ADR[18:1]}];
	   
        end else if (DS_D == 1'b1) begin 

	   //$write("%06x: %04x %b %b DB: %04x\n", ADR[23:0], {(UDS ? cram[{ADR[18:1]}][15:8] : DATA[15:8]) , (LDS ? cram[{ADR[18:1]}][7:0]: DATA[7:0])}, UDS, LDS, DATA[15:0]);
           cram[{ADR[18:1]}] <=  {(UDS ? cram[{ADR[18:1]}][15:8] : DATA[15:8]) , (LDS ? cram[{ADR[18:1]}][7:0]: DATA[7:0])};
                          
        end
    
      end else if ({ADR[23:16]} == 8'hDF) begin



			if (latch == 1) begin 
				
				latch <= (LDSn & UDSn);

				case ({ADR[11:0]})

					'h018: begin 
						DATA_IN <= 'h7000;
					end
					
					'h030: begin 
					       #10;
					   
						if ((LDSn | RWn) == 1'b0) begin
							$write("%c", DATA[7:0]);
						end
						
					end
					
					'h09c: begin 
						DATA_IN <= 'h3000;
					end
					
					'h180: begin 
						DATA_IN <= 'h0000;
					end
					
					default: begin 
						DATA_IN <= 'd0;
					end 
				
				endcase 

			end
			
			
			DTACKn <= 0;
      end else if (({ADR[23:20]} == 4'hE) & OVR) begin // if ({ADR[23:16]} == 8'hDF)
	 
	 DTACKn <= 0;
	 DATA_IN <= 'd0;			
	 
      end else if ({ADR[23:20]} == 4'hD) begin
	 DTACKn <= 0;
	 DATA_IN <= 'd0;			
      end else if ({ADR[23:20]} == 4'hB) begin
		 if ({ADR[23:4]} == {20'hBFE00}) begin
			 overlay <= 1'b0;
		 end
	 
	 case ({ADR[11:0]})
	   'h001: begin 
	      DATA_IN <= 'hff;			
	   end
	   
	   default: DATA_IN <= 'd0;			

	 endcase 
	   
	   VPAn <= 0;
	   DTACKn <= 1;
	 
      end else if (OVR) begin
	 
		 DTACKn <= 0;
		 DATA_IN <= 'hFFFF;			
	 
      end 
      
   end else begin 	
		latch <= 1'b1;
      
	end
   
end

assign DATA = RWn & ~ASn ? DATA_IN : 16'bZ;
PULLUP IDEWAIT_pullup (
.O(IDEWAIT) // Pullup output (connect directly to top-level port)
);

PULLUP RESETn_pullup (
.O(RESETn) // Pullup output (connect directly to top-level port)
);

PULLUP BERRn_pullup (
.O(BERRn) // Pullup output (connect directly to top-level port)
);

PULLUP DSACK1n_pullup (
.O(DSACK1) // Pullup output (connect directly to top-level port)
);

PULLUP DSACK0n_pullup (
.O(DSACK0) // Pullup output (connect directly to top-level port)
);

PULLUP IPL0_pullup (
.O(IPLn[0]) // Pullup output (connect directly to top-level port)
);

PULLUP IPL1_pullup (
.O(IPLn[1]) // Pullup output (connect directly to top-level port)
);

PULLUP IPL2_pullup (
.O(IPLn[2]) // Pullup output (connect directly to top-level port)
);

PULLUP FC0_pullup (
.O(FC[0]) // Pullup output (connect directly to top-level port)
);

PULLUP FC1_pullup (
.O(FC[1]) // Pullup output (connect directly to top-level port)
);

PULLUP FC2_pullup (
.O(FC[2]) // Pullup output (connect directly to top-level port)
);

PULLUP BG_pullup (
.O(BG) // Pullup output (connect directly to top-level port)
);

PULLUP ASn_pullup (
.O(ASn) // Pullup output (connect directly to top-level port)
);

PULLUP AS20_pullup (
.O(AS20) // Pullup output (connect directly to top-level port)
);

PULLUP LDS_pullup (
.O(LDS) // Pullup output (connect directly to top-level port)
);

PULLUP UDS_pullup (
.O(UDS) // Pullup output (connect directly to top-level port)
);


genvar    c;
generate
   
   for (c = 0; c < 16; c = c + 1) begin: data_pullup
      PULLUP D_pullup (
	.O(DATA[c]) 
      );
    end
endgenerate

//assign DATA[7:0] = OVR & RW20 ? 8'bzzzzzzzz : 8'hff;         
endmodule

