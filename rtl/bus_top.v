`timescale 1ns / 1ps

/*
Copyright (c) 2016, Stephen J. Leary
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. All advertising materials mentioning features or use of this software
   must display the following acknowledgement:
   This product includes software developed by the <organization>.
4. Neither the name of the <organization> nor the
   names of its contributors may be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

module bus_top(

           input 	CLKCPU,
           input 	CLK7M,

           output HALT,
           output RESET,

           input 	BG20,
           input 	AS20,
           input 	DS20,
           input 	RW20,
           output 	RW,


           input [2:0] 	FC,
           input [1:0] 	SIZ,

           input [23:0] A,

           input 	BGACK,
           input 	VPA,
           input 	DTACK,

           output 	BG,
           output 	LDS,
           output 	UDS,
           output 	VMA,
           output 	E,
           output 	AS,
           output 	BERR,

           input 	IDEWAIT,
           input 	INTCYCLE,

           output [1:0] DSACK,
           output 	AVEC,
           output 	CPCS,
           input 	CPSENSE,

           output [2:0] IPL,

           output 	IOR,
           output 	IOW,
           output [1:0] IDECS
       );


/* Timing Diagram
                 S0 S1 S2 S3 S4 S5  W  W S6 S7
         __    __    __    __    __    __    __    __    __    __    __    __   
CLK     |  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__
        ________________                       _____________________________
AS20                    \_____________________/
        ___________________                      _____________________________
AS20DLY                    \_____________________/
        ____________________                     _____________________________
INTCYCLE                    \___________________/

*/

reg DS20DLY = 1'b1;
reg AS20DLY = 1'b1;
reg AS20DLY2 = 1'b1;
reg RW20DLY = 1'b1;
reg FASTCYCLE = 1'b1;

reg CLK7MB2 = 1'b1;
reg BGACKD1 = 1'b1;
reg BGACKD2 = 1'b1;

reg AS_INT = 1'b1;
reg LDS_INT = 1'b1;
reg UDS_INT = 1'b1;

wire CPUSPACE = &FC;

wire FPUOP = CPUSPACE & ({A[19:16]} === {4'b0010});
wire BKPT = CPUSPACE & ({A[19:16]} === {4'b0000});
wire IACK = CPUSPACE & ({A[19:16]} === {4'b1111});
wire HIGHZ = ~BGACK | ~INTCYCLE;

wire DSACK1_SYNC;
wire VMA_SYNC;

// module to control the 6800 bus timings
m6800 M6800BUS(
          .CLK7M	( CLK7M			),
          .FC     ( FC           ),
          .AS20	( AS20			),
          .VPA		( VPA				),
          .VMA		( VMA_SYNC		),
          .E		( E				),
          .DSACK1	( DSACK1_SYNC 	)
      );

// module to control IDE timings.
ata ATA (

        .CLK	( CLKCPU	),
        .AS	( AS20	),
        .RW	( RW20	),
        .A		( A		),
        .WAIT	( IDEWAIT),

        .IDECS( IDECS	),
        .IOR	( IOR		),
        .IOW	( IOW		),
        .DTACK( DTACK_IDE	),
        .ACCESS( GAYLE_IDE )

    );


wire FASTCYCLE_INT = AS20DLY2 | ~IDEWAIT | INTCYCLE;

reg S4MASK = 1'b1;
reg CPCS_INT = 1'b1;
reg AVEC_INT = 1'b1;

always @(posedge CLK7M or posedge AS20) begin

    if (AS20 == 1'b1) begin

        AS_INT <= 1'b1;
        LDS_INT <= 1'b1;
        UDS_INT <= 1'b1;
        S4MASK <= 1'b1;

    end else begin

        // assert these lines in S2
        // the 68030 assert them one half clock early.
        AS_INT <= AS20 | FPUOP | ~GAYLE_IDE | ~INTCYCLE;

        if (RW20 == 1'b1) begin

            // reading when reading the signals are asserted in 7Mhz S2
            UDS_INT <= DS20 | A[0];
            LDS_INT <= DS20 | ({A[0], SIZ[1:0]} == 3'b001);

        end else begin

            // when writing the the signals are asserted in 7Mhz S4
            UDS_INT <= DS20 | AS_INT | A[0];
            LDS_INT <= DS20 | AS_INT  | ({A[0], SIZ[1:0]} == 3'b001);

        end

        S4MASK <= (AS_INT | DTACK) & DTACK_IDE;


    end

end

always @(posedge CLKCPU or posedge AS20) begin

    if (AS20 == 1'b1) begin

        AS20DLY <= 1'b1;
        AS20DLY2 <= 1'b1;
        RW20DLY <= 1'b1;
        DS20DLY <= 1'b1;
        FASTCYCLE <= 1'b1;
        CPCS_INT <= 1'b1;
        AVEC_INT <= 1'b1;

    end else begin

        // Delayed Address Strobes
        AS20DLY <= AS20 | FPUOP;
        CPCS_INT <= ~FPUOP | AS20;
        AVEC_INT <= ~IACK | VPA;
        AS20DLY2 <= AS20DLY;
        RW20DLY <= RW20 | FPUOP;
        DS20DLY <= DS20 | FPUOP;
        FASTCYCLE <= FASTCYCLE_INT;

    end

end


wire VMA_INT = VMA_SYNC;

assign RW =   HIGHZ ? 1'bz : RW20;
assign AS =   HIGHZ ? 1'bz : AS_INT;
assign UDS =  HIGHZ ? 1'bz : UDS_INT;
assign LDS =  HIGHZ ? 1'bz : LDS_INT;
assign VMA =  HIGHZ ? 1'bz : VMA_INT;

assign DSACK[1] = FPUOP | (S4MASK | ~INTCYCLE) & DSACK1_SYNC & FASTCYCLE;
assign DSACK[0] = 1'bz;

assign BG = AS ?  BG20 : 1'bz;
assign AVEC = AVEC_INT;
assign IPL = 3'bzzz;
assign HALT = 1'bZ;
assign RESET = 1'bZ;

assign BERR = (CPCS_INT | ~CPSENSE) ? 1'bz : 1'b0;
assign CPCS = CPCS_INT;

endmodule
