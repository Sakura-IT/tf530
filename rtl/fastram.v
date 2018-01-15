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

           input 	     RESET,
           input         ACCESS,

           input [23:0]  A,
           input [1:0]   SIZ,

           input 	      AS20,
           input 	      RW20,
           input 	      DS20,

           // cache and burst control
           //input 	      CBREQ,
           output 	      CBACK,
           output 	      CIIN,

           // ram chip control
           output [3:0]  RAMCS,
           output 	     RAMOE

       );

// ram control lines
wire RAMCS3n = A[1] | A[0]; //
wire RAMCS2n = (~SIZ[1] & SIZ[0] & ~A[0]) | A[1];
wire RAMCS1n = (SIZ[1] & ~SIZ[0] & ~A[1] & ~A[0]) | (~SIZ[1] & SIZ[0] & ~A[1]) |(A[1] & A[0]);
wire RAMCS0n = (~SIZ[1] & SIZ[0] & ~A[1] ) | (~SIZ[1] & SIZ[0] & ~A[0] ) | (SIZ[1] & ~A[1] & ~A[0] ) | (SIZ[1] & ~SIZ[0] & ~A[1] );

// disable all the RAM.
assign RAMOE = ACCESS;
assign RAMCS = {4{ACCESS}} | ({ RAMCS3n, RAMCS2n, RAMCS1n , RAMCS0n} & {4{~RW20}});

assign CBACK = 1'b1; //STERM_D | CBREQ;


endmodule
