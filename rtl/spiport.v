`timescale 1ns / 1ps
/*
    Copyright (C) 2017, Stephen J. Leary
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


module spiport(

           input	RESET,

           input	[23:0] A,

           input	[7:4] D,
           output[7:4] DOUT,

           output  ACCESS,

           input 	AS20,
           input	RW20,
           input 	DS20,

           // zorro control
           input   CFG_IN,
           output  CFG_OUT,

           // spi outputs
           output       SPI_CLK,
           output reg [1:0]    SPI_CS,
           input          SPI_MISO,
           output reg          SPI_MOSI
       );




reg config_out = 'b0;   
reg configured = 'b0;
reg shutup = 'b0;
reg [7:4] data_out;
reg [7:0] base_address;

// 0xE80000
wire Z2_ACCESS = ({A[23:16]} != {8'hE8}) | AS20 |config_out | ~CFG_IN;
wire Z2_WRITE = (Z2_ACCESS | RW20);

// do not access the MMC card when A3 is high.
wire MMC_ACCESS = ({A[23:16]} != {base_address}) | AS20 | ~configured | shutup;
wire [6:0] zaddr = {MMC_ACCESS, {A[6:1]}};

FDCPE #(.INIT(1'b1))
      SPI_CLK_FF (
          .Q(SPI_CLK), // Data output
          .C(~DS20), // Clock input
          .CE(~MMC_ACCESS), // CLOCK ENABLE
          .CLR(1'b0), // Asynchronous clear input
          .D(A[2]), // Data input
          .PRE(AS20) // Asynchronous set input
      );

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
        SPI_CS <= 2'b11;

    end else begin
        
      data_out[7:4] <= {SPI_MISO,3'b010};
          if ((config_out) == 1'b0) begin  
              // zorro config ROM
              case (zaddr)
                    7'h40: data_out[7:4] <= 4'hc;
                    7'h41: data_out[7:4] <= 4'h1;
                    7'h42: data_out[7:4] <= 4'h7;
                    7'h43: data_out[7:4] <= 4'he;
                    7'h44: data_out[7:4] <= 4'h7;
                    7'h48: data_out[7:4] <= 4'he;
                    7'h49: data_out[7:4] <= 4'hc;
                    7'h4a: data_out[7:4] <= 4'h2;
                    7'h4b: data_out[7:4] <= 4'h7;
                    7'h51: data_out[7:4] <= 4'hd;
                    7'h52: data_out[7:4] <= 4'he;
                    7'h53: data_out[7:4] <= 4'hd;
                    // mmc access
                    default: data_out[7:4] <= 4'hf;

              endcase
          end 

        if (Z2_WRITE == 1'b0) begin

            case (zaddr)

                'h64: begin
                    base_address[7:4] <= D[7:4];
                    configured <= 1'b1;
                end

                'h65: base_address[3:0] <= D[7:4];
                'h66: shutup <= 1'b1;

            endcase

        end

        if (MMC_ACCESS == 1'b0)	begin

            // pulse the spi clock on an access.
            // latch the MISO data always..
            // its ignored on a read.

            if (RW20 == 1'b0) begin

                SPI_MOSI <= D[7];

            end 
                

            if (A[2] == 1'b1) begin

                // pick the active device.
                SPI_CS[0] <= D[7];
                SPI_CS[1] <= D[6];

            end

        end

    end

end

assign CFG_OUT = config_out;
assign ACCESS  = MMC_ACCESS & Z2_ACCESS;
assign DOUT[7:4] = data_out[7:4];

endmodule
