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
   input wire 	     fpga_clk,
   input wire 	     fpga_reset,
   input wire 	     i_serial, 
   output wire [7:0] led,
   output wire [7:0] JA,
   output wire [7:0] JB
   );

   // reset wires and assignments
   wire 	     mtrx_r0, mtrx_g0, mtrx_b0, mtrx_r1, mtrx_g1, mtrx_b1;
   wire 	     mtrx_blank, mtrx_latch, mtrx_sclk;
   wire [3:0] 	     mtrx_a;
   wire [7:0] 	     mtrx_led;
   
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
   
   // assign led = mtrx_led;
   // assign led = uart_rx_data;
   
   // Using button as a clock
   wire 	     mtrx_clk;
   //---------------------------------------------------------------------------------------------
   // clock generator
   //

   wire 	     clk100, clk50, clk25, clk20, clk10;
   wire 	     reset = ~fpga_reset;
   wire 	     pll_locked;

   clkgen clkgen
     (
      .CLK_IN1			   (fpga_clk), // 100 MHz
      .CLK_OUT1		           (clk100), // 100 MHz
      .CLK_OUT2		           (clk50), // 50 MHz
      .CLK_OUT3		           (clk25), // 25 MHz
      .CLK_OUT4		           (clk20), // 20 MHz
      .CLK_OUT5		           (clk10), // 10 MHz
      .RESET				(reset),
      .LOCKED				(pll_locked)
      );
   
   wire 	     intern_reset = reset | ~pll_locked;
   wire 	     intern_reset_n = ~intern_reset;

   //---------------------------------------------------------------------------------------------
   // 32 x 16 LED Matrix Registers
   //
   // always @ (posedge mtrx_clk or negedge fpga_reset)

   wire [7:0] 	     uart_rx_data;
   reg [7:0] 	     previos_uart_rx_data;
   reg 		     process_uart_data = 1;
   reg 		     mtrx_wr = 0;
   reg [9:0] 	     mtrx_addr;
   reg [11:0] 	     mtrx_data;
   wire		     uart_rx_complete;
   reg [1:0] 	     modulo_3_frame = 0;

   assign led = modulo_3_frame;
   
   // inputs: 
   //   uart_rx_data:      from uart interface
   //   uart_rx_complete:  high when new data has arrived
   // outputs:
   //   mtrx_addr:         address to write. wraps around 10 bits for 32x32
   //   mtrx_data:         12 bit value to write.
   //   mtrx_wr:           assert to enable writing mtrx_data to mtrx_addr
   
   always @ (posedge clk100 or negedge intern_reset_n)
     begin
     	if (!intern_reset_n)  // When the button is at rest
	  begin
	     process_uart_data <= 1;
	     mtrx_wr <= 0;
	     modulo_3_frame <= 0;
	     mtrx_addr <= 0;
	     previos_uart_rx_data <= 0;
	  end // if (!intern_reset_n)
	else    // When the button is pressed
	  begin
	     if(uart_rx_complete)
	       begin
		  if(process_uart_data)
		    begin
		       case (modulo_3_frame)
			 0:
			   begin
			      mtrx_wr <= 0;
			   end
			 1:
			   begin
			      mtrx_data[11:4] <= previos_uart_rx_data;
			      mtrx_data[3:0] <= uart_rx_data[7:4];
			      mtrx_addr <= mtrx_addr + 1;
			      mtrx_wr <= 1;
			   end
			 2:
			   begin
			      mtrx_data[11:8] <= previos_uart_rx_data[3:0];
			      mtrx_data[7:0] <= uart_rx_data;
			      mtrx_addr <= mtrx_addr + 1;
			      mtrx_wr <= 1;
			   end
		       endcase // case (modulo_3_frame)
		       
		       previos_uart_rx_data <= uart_rx_data;
		       modulo_3_frame <= modulo_3_frame + 1;
		       if(modulo_3_frame == 2)
			 modulo_3_frame <= 0;
		       process_uart_data <= 0;
		    end // if (process_uart_data)
	       end // if (uart_rx_complete)
	     else
	       begin
		  process_uart_data <= 1;
		  mtrx_wr <= 0;
	       end // else: !if(uart_rx_complete)
	  end // else: !if(!intern_reset_n)
     end // always @ (posedge clk100 or negedge intern_reset_n)
   
   
   matrix matrix
     (
      .rst_n		(intern_reset_n),
      .clk		(clk10),
      .wr_clk		(clk100),
      .wr		(mtrx_wr),
      .wr_addr		(mtrx_addr),
      .wr_data		(mtrx_data),
      .led   	  	(mtrx_led),
      .r0		(mtrx_r0),
      .g0		(mtrx_g0),
      .b0		(mtrx_b0),
      .r1		(mtrx_r1),
      .g1		(mtrx_g1),
      .b1		(mtrx_b1),
      .a		(mtrx_a),
      .blank		(mtrx_blank),
      .sclk		(mtrx_sclk),
      .latch		(mtrx_latch)
      );

   uart uart
     (
      .i_clk			(clk50),
      .i_Rx_Serial 		(i_serial),
      .rst_n			(intern_reset_n),
      .r_Rx_Byte		(uart_rx_data),
      .r_Rx_Complete		(uart_rx_complete)
      // .o_RX_Byte		(uart_rx_data),
      );
   
endmodule
