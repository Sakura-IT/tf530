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


module ram_top(

           input CLKCPU,
           input	RESET,

           input	[23:0] A,
           inout	[7:0] D,
           input   [1:0] SIZ,

           input   IDEINT,
           output   IDEWAIT,
           output  INT2,

           input   AS20,
           input   RW20,
           input   DS20,

           // cache and burst control
           input  CBREQ,
           output  CBACK,
           output  CIIN,
           output 	STERM,
           // 32 bit internal cycle.
           // i.e. assert OVR
           output  INTCYCLE,

           // ram chip control
           output reg [3:0] RAMCS,
           output reg  RAMOE,

           // SPI Port
			  output				EXTINT,
           output          SPI_CLK,
           output [1:0]    SPI_CS,
           input	          SPI_MISO,
           output           SPI_MOSI

       );

reg STERM_D = 1'b1;
reg STERM_D2 = 1'b1;
wire ROM_ACCESS = (A[23:19] != {4'hF, 1'b1}) | AS20;
// produce an internal data strobe
wire GAYLE_INT2;

reg gayle_access = 1'b1;
wire gayle_decode;
wire gayle_dout;

gayle GAYLE(

          .CLKCPU ( CLKCPU        ),
          .RESET  ( RESET         ),
          .AS20   ( AS20          ),
          .DS20   ( DS20          ),
          .RW     ( RW20          ),
          .A      ( A             ),
          .IDE_INT( IDEINT        ),
          .INT2   ( GAYLE_INT2    ),
          .D7	  ( D[7]          ),
          .DOUT7  ( gayle_dout    ),
          .ACCESS ( gayle_decode  )

      );


reg spi_access = 1'b1;
wire spi_decode;
wire [7:0] spi_dout;

reg ram_access = 1'b1;
wire ram_decode;

reg zii_access = 1'b1;
wire zii_decode;
wire [7:4] zii_dout;

autoconfig AUTOCONFIG(

               .RESET  ( RESET         ),

               .AS20   ( AS20          ),
               .DS20   ( DS20          ),
               .RW20   ( RW20          ),

               .A      ( A             ),

               .D	    ( D[7:4]        ),
               .DOUT	( zii_dout[7:4]),

	       .ACCESS ( zii_decode	),
	       .DECODE ({ram_decode, spi_decode})
           );

wire RAMOE_INT;
wire [3:0] RAMCS_INT;

fastram RAMCONTROL (

            .RESET  ( RESET         ),

            .A      ( A             ),
            .SIZ    ( SIZ           ),

            .ACCESS ( ram_access | DS20 ),

            .AS20   ( AS20    	    ),
            .DS20   ( DS20          ),
            .RW20   ( RW20          ),

            // ram chip control
            .RAMCS  ( RAMCS_INT	    ),
            .RAMOE  ( RAMOE_INT     )

        );


reg CLKB2 = 1'b0;
reg CLKB4 = 1'b0;

always @(posedge CLKCPU) begin 
	
	CLKB2 <= ~CLKB2;
	
end

zxmmc SPIPORT (
   .CLOCK  ( CLKB2     ),
   .nRESET ( RESET      ),
   .CLKEN  ( 1'b1       ),
   .ENABLE ( ~(spi_access | DS20) ),
   .RS     ( A[2]       ),
   .nWR    ( RW20       ),
   .DI     ( D          ),
   .DO     ( spi_dout   ),
   .SD_CS0 ( SPI_CS[0]  ),
   .SD_CS1 ( SPI_CS[1]  ),
   .SD_CLK ( SPI_CLK    ),
   .SD_MOSI( SPI_MOSI   ),
   .SD_MISO( SPI_MISO   )
);

reg CIIN_D;
reg AS20_D;
reg CBACK_D;
reg INTCYCLE_INT = 1'b1;
reg intcycle_dout = 1'b1;
reg WAITSTATE;

always @(AS20) begin 

  if (AS20 == 1'b1) begin 
      
      zii_access <= 1'b1;
      spi_access <= 1'b1;
      gayle_access <= 1'b1;
      ram_access <= 1'b1;
      
  end else begin 
  
      zii_access <= zii_decode;
      spi_access <= spi_decode;
      gayle_access <= gayle_decode;
      ram_access <= ram_decode;
      
  end 
  
end 
always @(negedge CLKCPU) begin

    WAITSTATE <= AS20 | DS20 | RAMOE_INT;

end

always @(negedge CLKCPU, posedge AS20) begin

    if (AS20 == 1'b1) begin

        RAMCS <= 4'b1111;
        RAMOE <= 1'b1;

    end else begin

        RAMCS <= RAMCS_INT;
        RAMOE <= RAMOE_INT;

    end

end

// a general access to something this module controls is happening.
wire db_access = spi_access & gayle_access & zii_access;

always @(posedge CLKCPU or posedge AS20) begin

    if (AS20 == 1'b1) begin

        AS20_D <= 1'b1;

        STERM_D <=  1'b1;
        CIIN_D <=   1'b0;
        CBACK_D <= 1'b1;
        intcycle_dout <= 1'b1;

        STERM_D2 <= 1'b1;

    end else begin

        AS20_D <= AS20;

        STERM_D <=  ~STERM_D | WAITSTATE;
        STERM_D2 <= STERM_D | ~STERM_D2;
        CIIN_D <=  ~(ROM_ACCESS & RAMOE_INT);
        CBACK_D <= 1'b1; //CBREQ | AS20 | &AC;
        intcycle_dout <= db_access | ~RW20;

    end

end

// this triggers the internal override (TF_OVR) signal.

assign INTCYCLE = ram_access & db_access;
assign IDEWAIT = RAMOE ? 1'bz : 1'b0;

// disable all burst control.
assign STERM = STERM_D;
assign CBACK = CBACK_D ;
assign CIIN = CIIN_D;

assign INT2 = GAYLE_INT2 ? 1'bz : 1'b0;

wire [7:0] data_out;
assign data_out[7:4] = spi_access ? (zii_access ? {gayle_dout,3'b000} : zii_dout ) : spi_dout[7:4];
assign data_out[3:0] = spi_access ? 4'd0 : spi_dout[3:0];

assign D[7:0] = ~intcycle_dout ? data_out : 8'bzzzzzzzz;
assign EXTINT = CLKCPU;

endmodule

