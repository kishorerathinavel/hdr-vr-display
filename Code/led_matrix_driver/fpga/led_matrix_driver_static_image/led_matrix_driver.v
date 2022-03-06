//=============================================================================================
// SparkFun / Adafruit 32x32 LED Panel Driver
// Copyright 2014 by Glen Akins.
// All rights reserved.
// 
// Set editor width to 96 and tab stop to 4.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//=============================================================================================

`default_nettype none

module led_matrix_driver
  (
   input wire 	     clk_in,
   input wire 	     rst_n,
   output wire [7:0] led,
   output wire [7:0] JA,
   output wire [7:0] JB
   );

   // reset wires and assignments
   wire 	     mtrx_r0, mtrx_g0, mtrx_b0, mtrx_r1, mtrx_g1, mtrx_b1;
   wire 	     mtrx_blank, mtrx_latch, mtrx_sclk;
   wire [3:0] 	     mtrx_a;
   wire [7:0]	     mtrx_led;
	     

   // pmod 1 connection assignments
   assign JA[0] = mtrx_r0;
   assign JA[1] = mtrx_g0;
   assign JA[2] = mtrx_b0;
   assign JA[3] = 0;
   assign JA[4] = mtrx_r1;
   assign JA[5] = mtrx_g1;
   assign JA[6] = mtrx_b1;
   assign JA[7] = 0;

   // pmod 2 connection assignments
   assign JB[0] = mtrx_a[0];
   assign JB[1] = mtrx_a[1];
   assign JB[2] = mtrx_a[2];
   assign JB[3] = mtrx_a[3];
   assign JB[4] = mtrx_blank;
   assign JB[5] = mtrx_latch;
   assign JB[6] = mtrx_sclk;
   assign JB[7] = 0;

   assign led[0] = mtrx_led[0];
   assign led[1] = mtrx_led[1];
   assign led[2] = mtrx_led[2];
   assign led[3] = mtrx_led[3];
   assign led[4] = mtrx_led[4];
   assign led[5] = mtrx_led[5];
   assign led[6] = mtrx_led[6];
   assign led[7] = mtrx_led[7];
   

   // Using button as a clock
   wire 	     mtrx_clk;
   // assign mtrx_clk = counter50[0];
   assign mtrx_clk = clk50;

   //---------------------------------------------------------------------------------------------
   // clock generator
   //

   wire 	     clk100, clk50, clk20, clk_X;

	wire reset = ~rst_n;
	wire pll_locked;

   clkgen clkgen
     (
      .CLK_IN1			   (clk_in), // 100 MHz
      .CLK_OUT1			(clk100), // 100 MHz
      .CLK_OUT2			(clk50), // 50 MHz
      .CLK_OUT3			(clk20), // 20 MHz 
      .CLK_OUT4			(clk_X), // 10 MHz,
		.RESET				(reset),
		.LOCKED				(pll_locked)
      );
		
	wire intern_reset = reset | ~pll_locked;
	wire intern_reset_n = ~intern_reset;

// //---------------------------------------------------------------------------------------------
// // blink the LEDs

   reg [23:0] 	     counter50;

   always @ (posedge clk_in or negedge rst_n)
     begin
	if (!rst_n)
	  begin
	     counter50 <= 0;
	  end
	else
	  begin
	     counter50 <= counter50 + 1;
	  end
     end

   // assign led = counter50[23];

   //---------------------------------------------------------------------------------------------
   // 32 x 32 LED Matrix Registers
   //
   // always @ (posedge mtrx_clk or negedge rst_n)

   matrix matrix
     (
      .rst_n					(intern_reset_n),
      .clk					(mtrx_clk),
      .led              (mtrx_led),
      .r0					(mtrx_r0),
      .g0					(mtrx_g0),
      .b0					(mtrx_b0),
      .r1					(mtrx_r1),
      .g1					(mtrx_g1),
      .b1					(mtrx_b1),
      .a					(mtrx_a),
      .blank					(mtrx_blank),
      .sclk					(mtrx_sclk),
      .latch					(mtrx_latch)
      );


endmodule
