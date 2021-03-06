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

module matrix
  (
   input wire 	     rst_n,
   input wire 	     clk,
   output reg [7:0] led,
   output reg 	     r0,
   output reg 	     g0,
   output reg 	     b0,
   output reg 	     r1,
   output reg 	     g1,
   output reg 	     b1,
   output reg [3:0]  a,
   output reg 	     blank,
   output reg 	     sclk,
   output reg 	     latch
   );


   //---------------------------------------------------------------------------------------------
   // state machine states
   //

   localparam WAIT = 0,
     BLANK = 1,
     LATCH = 2,
     UNBLANK = 3,
     READ = 4,
     SHIFT1 = 5,
     SHIFT2 = 6;


   //---------------------------------------------------------------------------------------------
   // registers and wires
   //

   reg [2:0] 	     state;
   reg [10:0] 	     timer;
   reg [3:0] 	     delay;
   reg [3:0] 	     rd_row;
   reg [1:0] 	     rd_bit;
   reg [4:0] 	     rd_col;
   reg 		     rd_buffer;
   wire [9:0] 	     rd_addr; 	// 10 bits can address 1024 physical addresses
   wire [23:0] 	     rd_data; 	// 3 colors x 4 bits each color x 2 rows = 24 bits
   wire [3:0] 	     rd_r1, rd_g1, rd_b1, rd_r0, rd_g0, rd_b0; // Each color is represented by a 4 bit value
   wire 	     rd_r1_bit, rd_g1_bit, rd_b1_bit, rd_r0_bit, rd_g0_bit, rd_b0_bit; // This is the current bit that is being serially pushed and latched

   //---------------------------------------------------------------------------------------------
   // memories
   // not the most efficient use of block RAM but good enough for 1 to 16 panels in an LX9
   //
   // words   0 to  511 are display buffer 0
   // words 512 to 1024 are display buffer 1
   // bits [23:12] are rows 16 to 31  => r1, g1, b1 and in _hi memory
   // bits [11: 0] are rows  0 to 15  => r0, g0, b0 and in _lo memory
   //
   wire [11:0] 	     wr_data;
   wire 	     wr_hi, wr_lo;
   
   dpram1024x12_hi dpram1024x12_hi
     (
      // .clka 			(wr_clk),
      .wea				(wr_hi),
      // .addra				({wr_addr[10], wr_addr[8:0]}),
      .dina				(wr_data),
      .clka				(clk),
      .addra				(rd_addr),
      .douta				(rd_data[23:12])
      );

   dpram1024x12_lo dpram1024x12_lo
     (
      // .clka				(wr_clk),
      .wea				(wr_lo),
      // .addra				({wr_addr[10], wr_addr[8:0]}),
      .dina				(wr_data),
      .clka				(clk),
      .addra				(rd_addr),
      .douta				(rd_data[11:0])
      );

   assign rd_addr = { rd_row[3:0], rd_col[4:0] };

   // turn read data into individual pixel bits
   assign rd_r1 = rd_data[23:20];
   assign rd_g1 = rd_data[19:16];
   assign rd_b1 = rd_data[15:12];
   assign rd_r0 = rd_data[11: 8];
   assign rd_g0 = rd_data[ 7: 4];
   assign rd_b0 = rd_data[ 3: 0];

   assign rd_r1_bit = rd_r1[rd_bit];
   assign rd_g1_bit = rd_g1[rd_bit];
   assign rd_b1_bit = rd_b1[rd_bit];
   assign rd_r0_bit = rd_r0[rd_bit];
   assign rd_g0_bit = rd_g0[rd_bit];
   assign rd_b0_bit = rd_b0[rd_bit];


   //---------------------------------------------------------------------------------------------
   // clocked logic
   //


   // rst_n is LOW when the button is at rest and is HIGH when the button is pressed
   always @ (posedge clk or negedge rst_n)
     begin
	if (!rst_n)  // When the button is at rest
	  begin
	     r0 <= 0;
	     g0 <= 0;
	     b0 <= 0;
	     r1 <= 0;
	     g1 <= 0;
	     b1 <= 0;
	     a <= 0;
	     blank <= 1;
	     sclk <= 0;
	     latch <= 0;
	     state <= READ;
	     timer <= 0;
	     delay <= 0;

	     rd_row <= 0;
	     rd_bit <= 0;
	     rd_col <= 0;
	  end
	else    // When the button is pressed
	  begin
	     // implemnt timer for binary coded modulation
	     // bit plane 0 is displayed for ~192 clock cycles
	     // each succesfive bit plane is displayed for 2x the clocks of the previous bit plane
	     if (timer == 0)
	       begin
		  case (rd_bit)
		    0: timer <= 191;
		    1: timer <= 383;
		    2: timer <= 767;
		    3: timer <= 1535;
		  endcase
	       end
	     else
	       begin
		  timer <= timer - 1;
	       end

	     // state machine
	     case (state)

	       // wait for timer to expire then blank the display
	       WAIT: begin
		  sclk <= 0;
		  if (timer == 0)
		    begin
		       blank <= 1;
		       delay <= 8;
		       state <= BLANK;
		    end
		  led[0] <= 1;
		  led[1] <= 0;
		  led[2] <= 0;
		  led[3] <= 0;
		  led[4] <= 0;
		  led[5] <= 0;
		  led[6] <= 0;
		  led[7] <= 0;
	       end

	       // wait a while then latch in data previosly shifted into display
	       BLANK: begin
		  if (delay == 0)
		    begin
		       latch <= 1;
		       delay <= 8;
		       state <= LATCH;
		       a <= rd_row;
		    end
		  else
		    begin
		       delay <= delay - 1;
		    end
		  led[0] <= 0;
		  led[1] <= 1;
		  led[2] <= 0;
		  led[3] <= 0;
		  led[4] <= 0;
		  led[5] <= 0;
		  led[6] <= 0;
		  led[7] <= 0;
	       end

	       // wait a while then unblank the display to display the latched data
	       LATCH: begin
		  if (delay == 0)
		    begin
		       blank <= 0;
		       latch <= 0;
		       state <= UNBLANK;
		    end
		  else
		    begin
		       delay <= delay - 1;
		    end
		  led[0] <= 0;
		  led[1] <= 0;
		  led[2] <= 1;
		  led[3] <= 0;
		  led[4] <= 0;
		  led[5] <= 0;
		  led[6] <= 0;
		  led[7] <= 0;
	       end

	       // find the next bit, row, column, and buffer to display
	       // this is converted to a read address using combinatorial logic above
	       UNBLANK: begin
		  if (rd_bit == 3)
		    begin
		       rd_bit <= 0;
		       if (rd_row == 15)
			 begin
			    rd_row <= 0;
			 end
		       else
			 begin
			    rd_row <= rd_row + 1;
			 end
		    end
		  else
		    begin
		       rd_bit <= rd_bit + 1;
		    end
		  rd_col <= 0;
		  state <= READ;
		  led[0] <= 0;
		  led[1] <= 0;
		  led[2] <= 0;
		  led[3] <= 1;
		  led[4] <= 0;
		  led[5] <= 0;
		  led[6] <= 0;
		  led[7] <= 0;
	       end
	       
	       // the read, shift1, and shift2 states could be reduced to two states
	       // if I knew which edge of sclk latched the data into the shift registers
	       // this is good enough for one panel but for more than about four panels
	       // it'd be worth reducing to two clocks instead of three clocks.

	       // wait for read data to be output from RAM
	       READ: begin
		  state <= SHIFT1;
		  sclk <= 0;
		  led[0] <= 0;
		  led[1] <= 0;
		  led[2] <= 0;
		  led[3] <= 0;
		  led[4] <= 1;
		  led[5] <= 0;
		  led[6] <= 0;
		  led[7] <= 0;
	       end

	       // drive the column data out the outputs
	       SHIFT1: begin
		  r0 <= rd_r0_bit;
		  g0 <= rd_g0_bit;
		  b0 <= rd_b0_bit;
		  r1 <= rd_r1_bit;
		  g1 <= rd_g1_bit;
		  b1 <= rd_b1_bit;
		  // // r0 <= rd_row[3];
		  // // g0 <= rd_row[3];
		  // // b0 <= rd_row[3];
		  // // r1 <= rd_row[3];
		  // // g1 <= rd_row[3];
		  // // b1 <= rd_row[3];
		  // r0 <= 1;
		  // g0 <= 1;
		  // b0 <= 1;
		  // r1 <= 1;
		  // g1 <= 1;
		  // b1 <= 1;
		  state <= SHIFT2;
		  led[0] <= 0;
		  led[1] <= 0;
		  led[2] <= 0;
		  led[3] <= 0;
		  led[4] <= 0;
		  led[5] <= 1;
		  led[6] <= 0;
		  led[7] <= 0;
	       end
	       // clock the data into the RAM, move to next column, repeat 32x
	       SHIFT2: 
		 begin
		    sclk <= 1;
		    if (rd_col == 31)
		      begin
			 rd_col <= 0;
			 state <= WAIT;
		      end
		    else
		      begin
			 rd_col <= rd_col + 1;
			 state <= READ;
		      end
		  led[0] <= 0;
		  led[1] <= 0;
		  led[2] <= 0;
		  led[3] <= 0;
		  led[4] <= 0;
		  led[5] <= 0;
		  led[6] <= 1;
		  led[7] <= 0;
		 end // case: SHIFT2
	     endcase // case (state)
	  end // else: !if(!rst_n)
     end // always @ (posedge clk or negedge rst_n)

   // assign led[0] = timer[3];
   // assign led[1] = timer[4];
   // assign led[2] = timer[5];
   // assign led[3] = timer[6];
   // assign led[4] = timer[7];
   // assign led[5] = timer[8];
   // assign led[6] = timer[9];
   // assign led[7] = timer[10];
endmodule
