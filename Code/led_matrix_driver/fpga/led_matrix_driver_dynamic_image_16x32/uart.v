/////////////////////////////////////////////////////////////////////
// File Downloaded from http://www.nandland.com
/////////////////////////////////////////////////////////////////////
// This file contains the UART Receiver.  This receiver is able to
// receive 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When receive is complete o_rx_dv will be
// driven high for one clock cycle.
// 
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_clk)/(Frequency of UART)
// Example: 25 MHz Clock, 115200 baud UART
// (50000000)/(921600) = 54
// (25000000)/(256000) = 97
// (25000000)/(115200) = 217
// (25000000)/(9600) = 2604
// Example: 10 MHz Clock, 9600 baud UART
// (10000000)/(9600) = 1041

module uart
  (
   input 	    i_clk,
   input 	    i_Rx_Serial,
   input wire 	    rst_n, 
   output reg [7:0] r_Rx_Byte,
   output reg 	    r_Rx_Complete
   );

   parameter CLKS_PER_BIT = 54;
   parameter s_IDLE         = 3'b000;
   parameter s_RX_START_BIT = 3'b001;
   parameter s_RX_DATA_BITS = 3'b010;
   parameter s_RX_STOP_BIT  = 3'b011;
   parameter s_CLEANUP      = 3'b100;
   
   reg 		    r_Rx_Data_R = 1'b1;
   reg 		    r_Rx_Data   = 1'b1;

   reg [11:0] 	    r_Clock_Count = 0;
   reg [2:0] 	    r_Bit_Index   = 0; //8 bits total
   reg 		    r_Rx_DV       = 0;
   reg [2:0] 	    r_SM_Main     = 0;

   // Purpose: Double-register the incoming data.
   // This allows it to be used in the UART RX Clock Domain.
   // (It removes problems caused by metastability)
   always @(posedge i_clk)
     begin
	r_Rx_Data_R <= i_Rx_Serial;
	r_Rx_Data   <= r_Rx_Data_R;
     end

   //---------------------------------------------------------------------------------------------

   // Purpose: Control RX state machine
   always @(posedge i_clk or negedge rst_n)
     begin
	if(!rst_n)
	  begin
	     r_SM_Main <= s_IDLE;
	     r_Rx_Complete <= 0;
	     r_Rx_Byte <= 0;
	  end
	else
	  begin
	     case (r_SM_Main)
               s_IDLE :
		 begin
		    r_Rx_DV       <= 1'b0;
		    r_Clock_Count <= 0;
		    r_Bit_Index   <= 0;

		    if (r_Rx_Data == 1'b0)          // Start bit detected
		      r_SM_Main <= s_RX_START_BIT;
		    else
		      r_SM_Main <= s_IDLE;
		 end

	       // Check middle of start bit to make sure it's still low
               s_RX_START_BIT :
		 begin
		    if (r_Clock_Count == (CLKS_PER_BIT-1)/16'd2)
		      begin
			 if (r_Rx_Data == 1'b0)
			   begin
			      r_Clock_Count <= 0;  // reset counter, found the middle
			      r_SM_Main     <= s_RX_DATA_BITS;
			      r_Rx_Complete <= 0;
			   end
			 else
			   r_SM_Main <= s_IDLE;
		      end
		    else
		      begin
			 r_Clock_Count <= r_Clock_Count + 1;
			 r_SM_Main     <= s_RX_START_BIT;
		      end
		 end // case: s_RX_START_BIT


	       // Wait CLKS_PER_BIT-1 clock cycles to sample serial data
               s_RX_DATA_BITS :
		 begin
		    if (r_Clock_Count < CLKS_PER_BIT-1)
		      begin
			 r_Clock_Count <= r_Clock_Count + 1;
			 r_SM_Main     <= s_RX_DATA_BITS;
		      end
		    else
		      begin
			 r_Clock_Count          <= 0;
			 r_Rx_Byte[r_Bit_Index] <= r_Rx_Data;

			 // Check if we have received all bits
			 if (r_Bit_Index < 7)
			   begin
			      r_Bit_Index <= r_Bit_Index + 1;
			      r_SM_Main   <= s_RX_DATA_BITS;
			   end
			 else
			   begin
			      r_Bit_Index <= 0;
			      r_SM_Main   <= s_RX_STOP_BIT;
			   end
		      end
		 end // case: s_RX_DATA_BITS


	       // Receive Stop bit.  Stop bit = 1
               s_RX_STOP_BIT :
		 begin
		    // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
		    if (r_Clock_Count < CLKS_PER_BIT-1)
		      begin
			 r_Clock_Count <= r_Clock_Count + 1;
			 r_SM_Main     <= s_RX_STOP_BIT;
		      end
		    else
		      begin
			 r_Rx_DV       <= 1'b1;
			 r_Clock_Count <= 0;
			 r_SM_Main     <= s_CLEANUP;
			 r_Rx_Complete <= 1'b1;
		      end
		 end // case: s_RX_STOP_BIT


	       // Stay here 1 clock
               s_CLEANUP :
		 begin
		    r_SM_Main <= s_IDLE;
		    r_Rx_DV   <= 1'b0;
		 end


	       default :
		 r_SM_Main <= s_IDLE;

	     endcase // case (r_SM_Main)
	  end // else: !if(!rst_n)
     end // always @ (posedge i_clk or negedge rst_n)
   
   
   
endmodule // UART


