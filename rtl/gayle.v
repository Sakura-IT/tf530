`timescale 1ns / 1ps
/*
    Copyright (C) 2016-2017, Stephen J. Leary
    All rights reserved.
    
    This file is part of  TF530 (Terrible Fire 030 Accelerator).

    TF530 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    TF530 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty     You should have received a copy of the GNU General Public Licenseof
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.


    along with TF530. If not, see <http://www.gnu.org/licenses/>.
*/

module gayle(
           input 	        CLKCPU,
           input 	        RESET,
           input 			  DS20,
           input          AS20,
           input 	        RW,
           input 	        IDE_INT,
           output 	     INT2,
           input [23:0]    A,
           input          D7,
           output		     DOUT7,
           output         ACCESS
       );

parameter GAYLE_ID_VAL = 4'hd;

// $DE0000 or $DA8000 (Ignores A18)
wire GAYLE_REGS = (A[23:15] != {8'hDA, 1'b1});
wire GAYLE_ID   = (A[23:15] != {8'hDE, 1'b0});
wire GAYLE_ACCESS = (GAYLE_ID & GAYLE_REGS);

reg data_out = 1'b0;

reg [3:0] gayleid = GAYLE_ID_VAL;

reg 	  intena = 1'b0;
reg 	  intlast = 1'b0;

// $DE1000
localparam GAYLE_ID_RD = {1'b1,2'h1,1'b1};
localparam GAYLE_ID_WR = {1'b1,2'h1,1'b0};

// $DA8000
localparam GAYLE_STAT_RD = {3'h0,1'b1};
localparam GAYLE_STAT_WR = {3'h0,4'h0,1'b0};

// $DA9000
localparam GAYLE_INTCHG_RD = {3'h1,1'b1};
localparam GAYLE_INTCHG_WR = {3'h1,1'b0};

// $DAA000
localparam GAYLE_INTENA_RD = {3'h2,1'b1};
localparam GAYLE_INTENA_WR = {3'h2,1'b0};

wire INT_CHNG;
wire INT_CHNG_ACCESS = {(GAYLE_ACCESS | AS20),A[18],{A[13:12]},RW} != {1'b0,GAYLE_INTCHG_WR};

wire DS = DS20 | GAYLE_ACCESS | AS20;

FDCPE #(.INIT(1'b1))
      INT_CHNG_FF (
          .Q(INT_CHNG), // Data output
          .C(~DS), // Clock input
          .CE(~INT_CHNG_ACCESS), // CLOCK ENABLE
          .CLR(~RESET), // Asynchronous clear input
          .D(D7 & INT_CHNG), // Data input
          .PRE((IDE_INT != intlast) & intena) // Asynchronous set input
      );


always @(posedge CLKCPU) begin

    intlast <= IDE_INT;

end

always @(negedge DS or negedge RESET) begin

    if (RESET == 1'b0) begin
        // resetting to low ensures that the next cycle
        // after reset is disasserted is not a bus cycle.
        intena <= 1'b0;
        gayleid <= 4'hD;

    end else begin

        case ({A[18],{A[13:12]},RW})
            GAYLE_STAT_RD: data_out <= IDE_INT;
            GAYLE_INTCHG_RD: data_out <= INT_CHNG;
            GAYLE_ID_RD: begin
                data_out <=  gayleid[3];
                gayleid <= {gayleid[2:0],1'b1};
            end
            GAYLE_ID_WR: gayleid <= 4'hD;
            GAYLE_INTENA_RD: data_out <= intena;
            GAYLE_INTENA_WR: intena <= D7;
            default: data_out <= 'b0;
        endcase

    end
end

assign INT2 = ~(INT_CHNG & intena);
assign DOUT7 = data_out;
assign ACCESS = GAYLE_ACCESS;

endmodule
