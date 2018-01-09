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
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TF530. If not, see <http://www.gnu.org/licenses/>.
*/


module fastram(

           input 	      RESET,

           input [7:4]   D,
           output[7:4]   DOUT,

           output        ACCESS,

           input [23:0] A,
           input [1:0]   SIZ,

           input 	      AS20,
           input 	      RW20,
           input 	      DS20,

           // zorro control
           input 	      CFG_IN,
           output 	      CFG_OUT,

           // cache and burst control
           //input 	      CBREQ,
           output 	      CBACK,
           output 	      CIIN,

           // ram chip control
           output [3:0]  RAMCS,
           output 	      RAMOE

       );

wire [5:0] zaddr = {A[6:1]};

reg config_out;   
reg configured = 'b0;
reg shutup		= 'b0;
reg [7:4] data_out;
reg [7:5] base_address;

// 0xE80000
wire Z2_ACCESS = ({A[23:16]} != {8'hE8}) | AS20 | config_out | ~CFG_IN;
wire Z2_WRITE = (Z2_ACCESS | RW20);

wire RAM_ACCESS = ({A[23:21]} != {base_address[7:5]}) | AS20 | DS20 | ~configured;

always @(posedge AS20 or negedge RESET) begin

   if (RESET == 1'b0) begin

      config_out <= 1'b0;

   end else begin

      config_out <= configured | shutup;

   end

end
   
always @(negedge DS20 or negedge RESET) begin

    if (RESET == 1'b0) begin

        configured <= 1'b0;
        shutup <= 1'b0;

    end else begin

        if (Z2_WRITE == 1'b0) begin

            case (zaddr)
                'h24: begin
                    base_address[7:5] <= D[7:5];
                    configured <= 1'b1;
                end
                //'h25: base_address[3:0] <= D[7:4];
                'h26: shutup <= 1'b1;
            endcase
        end

        case (zaddr)
            'h00: data_out[7:4] <= 4'he;
            'h01: data_out[7:4] <= 4'h6;
            'h03: data_out[7:4] <= 4'he;
            'h04: data_out[7:4] <= 4'h7;
            'h08: data_out[7:4] <= 4'he;
            'h09: data_out[7:4] <= 4'hc;
            'h0a: data_out[7:4] <= 4'h2;
            'h0b: data_out[7:4] <= 4'h7;
            'h11: data_out[7:4] <= 4'hd;
            'h12: data_out[7:4] <= 4'he;
            'h13: data_out[7:4] <= 4'hd;
            default: data_out[7:4] <= 4'hf;
        endcase

    end

end


// ram control lines
wire RAMCS3n = A[1] | A[0]; //
wire RAMCS2n = (~SIZ[1] & SIZ[0] & ~A[0]) | A[1];
wire RAMCS1n = (SIZ[1] & ~SIZ[0] & ~A[1] & ~A[0]) | (~SIZ[1] & SIZ[0] & ~A[1]) |(A[1] & A[0]);
wire RAMCS0n = (~SIZ[1] & SIZ[0] & ~A[1] ) | (~SIZ[1] & SIZ[0] & ~A[0] ) | (SIZ[1] & ~A[1] & ~A[0] ) | (SIZ[1] & ~SIZ[0] & ~A[1] );

// disable all the RAM.
assign RAMOE = RAM_ACCESS;
assign RAMCS = {4{RAM_ACCESS}} | ({ RAMCS3n, RAMCS2n, RAMCS1n , RAMCS0n} & {4{~RW20}});

assign CBACK = 1'b1; //STERM_D | CBREQ;


assign CFG_OUT = config_out;
   
assign ACCESS  = Z2_ACCESS;
assign DOUT[7:4] = data_out[7:4];

endmodule
