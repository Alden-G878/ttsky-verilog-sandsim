/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`define ROW 36
`define COL 48
// updates sand line
module update
    #(parameter COL = 48)
    (input  logic           clk, rst_b,
     input  logic [COL-1:0] c_in_src, c_in_dest,
     output logic [COL-1:0] c_out_src, c_out_dest,
     input logic            make_sand);
    logic [COL-1:0] c_in_src_int0, c_in_src_int1;
    logic [COL-1:0] c_in_dest_int0, c_in_dest_int1;
    always_ff @(posedge clk) begin
	generate
	    for(genvar i=0;i<COL;i++) begin
		if(i==COL/2) begin
		    c_in_src_int0[i] <= (c_in_dest[i]==1'b0) ? (1'b0) : (c_in_src[i]);
		    c_in_dest_int0[i] <= (c_in_dest[i]==1'b0) ? (make_sand) : (c_in_dest[i]);
		end
		c_in_src_int0[i] <= (c_in_dest[i]==1'b0) ? (1'b0) : (c_in_src[i]);
		c_in_dest_int0[i] <= (c_in_dest[i]==1'b0) ? (c_in_src[i]) : (c_in_dest[i]);
	    end
	    for(genvar j=0;j<COL;j++) begin
		case(j)
		    0: begin
			c_in_src_int1[i] <= (c_in_dest_int0[i+1]==1'b0) ? (1'b0) : (c_in_src_int0[i]);
			c_in_dest_int1[i] <= c_in_dest_int0[i];
		    end
		    COL-1: begin
			c_in_src_int1[i] <= c_in_src_int0[i];
			c_in_dest_int1[i] <= (c_in_dest_int0[i]==1'b0) ? (c_in_src_int0[i-1]) : (c_in_dest_int0[i]);
		    end
		    default: begin
			c_in_src_int1[i] <= (c_in_dest_int0[i+1]==1'b0) ? (1'b0) : (c_in_src_int0[i]);
			c_in_dest_int1[i] <= (c_in_dest_int0[i]==1'b0) ? (c_in_src_int0[i-1]) : (c_in_dest_int0[i]);
		    end
		endcase
	    end
	    for(genvar k=0;k<COL;k++) begin
		case(k)
		    0: begin
			c_out_src[i] <= c_in_dest_int1[i];
			c_out_dest[i] <= (c_in_dest_int1[i]==1'b0) ? (c_in_src_int1[i+1]) : (c_in_dest_int1[i]);
		    end
		    COL-1: begin
			c_out_src[i] <= (c_in_dest_int1[i-1]==1'b0) ? (1'b0) : (c_in_src_int1[i]);
			c_out_dest[i] <= c_in_dest_int1[i];
		    end
		    default: begin
			c_out_src[i] <= (c_in_dest_int1[i-1]==1'b0) ? (1'b0) : (c_in_src_int1[i]);
			c_out_dest[i] <= (c_in_dest_int1[i]==1'b0) ? (c_in_src_int1[i+1]) : (c_in_dest_int1[i]);
		    end
		endcase
	    end
	endgenerate
    end
endmodule: update

// VGA controller
module vga_controller
    (input  logic clk, rst_b,
     input  logic pix, pix_valid,
     output logic [$clog2(800)-1:0] x_pos,
     output logic [$clog2(524)-1:0] y_pos,
     output logic                   vga_r, vga_g, vga_b, vga_hsync, vga_vsync);
    always_ff @(posedge clk) begin
	if(rst_b==1'b0) begin
	    x_pos <= 'b0;
	    y_pos <= 'b0;
	end
	else begin
	    if(x_pos > 10'd800 && y_pos > 9'd524) begin
		x_pos <= 'b0;
		y_pos <= 'b0;
	    end
	    else if(y_pos > 9'd524) begin
		x_pos <= 'b0;
		y_pos <= 'b0;
	    end
	    else if(x_pos > 10'd800) begin
		x_pos <= 'b0;
		y_pos <= y_pos + 9'b1;
	    end
	    else begin
		x_pos <= x_pos + 10'b1;
	    end
	end
    end
    assign vga_r = (pix_valid==1'b1) ? (1'b1) : (1'b1);
    assign vga_g = (pix_valid==1'b1) ? (pix) : (1'b0);
    assign vga_b = (pix_valid==1'b1) ? (pix) : (1'b0);
    assign vga_hsync = (x_pos >= 10'd656 && x_pos <= 10'd751) ? (1'b0) : (1'b1);
    assign vga_vsync = (y_pos >= 9'd491  && y_pos <= 9'd492)  ? (1'b0) : (1'b1);
endmodule: vga_controller

module spi
    #(parameter ROW=36,
      parameter COL=48)
    (input  logic                     rst_b, read, write, init,// control signals
     input  logic                     clk,
     output logic                     read_done, write_done, init_done,// control signals
     input  logic [$clog2(COL/8)-1:0] col,
     input  logic [$clog2(ROW)-1:0]   row,
     input  logic [7:0]               data_in,
     output logic [7:0]               data_out,
     output logic                     spi_clk, spi_ceb, spi_sio0_out, spi_sio1_out, spi_sio2_out, spi_sio3_out, spi_highz,
     input  logic                     spi_sio0_in, spi_sio1_in, spi_sio2_in, spi_sio3_in);
    // address generation
    //logic [$clog2(COL)-1:0] col_int;
    //logic [$clog2(ROW)-1:0] row_int;
    logic [$clog2(ROW)-1 + 3:0] row_shifted;
    logic [23:0] addr;
    assign row_shifted = row << 3;
    assign addr = col + row_shifted;
    logic addr_load;
    // shift register and control signals
    logic sio_out_init_load, sio_out_read_load, sio_out_write_load, sio_read_inout_counter_en;
    logic [23:0] sio0_out_reg;
    logic [23:0] sio1_out_reg;
    logic [23:0] sio2_out_reg;
    logic [23:0] sio3_out_reg;
    /*logic [23:0] sio0_in_reg;
    logic [23:0] sio1_in_reg;
    logic [23:0] sio2_in_reg;
    logic [23:0] sio3_in_reg;*/
    logic [23:0] sio_highz_reg;
    logic [23:0] sio0_out_inp;
    logic [23:0] sio1_out_inp;
    logic [23:0] sio2_out_inp;
    logic [23:0] sio3_out_inp;
    logic [23:0] sio0_in_inp;
    logic [23:0] sio1_in_inp;
    logic [23:0] sio2_in_inp;
    logic [23:0] sio3_in_inp;
    logic [23:0] sio_highz_inp;
    assign spi_sio0_out = sio0_out_reg[23];
    assign spi_sio1_out = sio1_out_reg[23];
    assign spi_sio2_out = sio2_out_reg[23];
    assign spi_sio3_out = sio3_out_reg[23];
    /*assign spi_sio0_in = sio0_in_reg[32];
    assign spi_sio1_in = sio1_in_reg[32];
    assign spi_sio2_in = sio2_in_reg[32];
    assign spi_sio3_in = sio3_in_reg[32];*/
    logic [4:0] shift_count;
    logic [4:0] shift_max;
    logic sio_out_en, sio_read_en;
    enum logic [1:0] {
	wt,
	write_load,
	write_wait, 
	read_addr_load, 
	read_addr_wait,
	read_data_wait, 
	init_rst_en_load,
	init_rst_en_wait,
	init_rst_load,
	init_rts_wait,
	init_spi_qmen_load,
	init_spi_qmen_wait} currState, nextState;
    logic [7:0] sio_read_inout_counter;
    logic [4:0] shift_count, shift_count_inp;
    logic [1:0] read_buf[3:0];
    logic sr_out_en_inp;
    always_ff @(posedge clk) begin
	currState <= nextState;
	sio0_out_reg <= sio0_out_inp;
	sio1_out_reg <= sio1_out_inp;
	sio2_out_reg <= sio2_out_inp;
	sio3_out_reg <= sio3_out_inp;
	/*sio0_in_reg <= sio0_in_inp;
	sio1_in_reg <= sio0_in_inp;
	sio2_in_reg <= sio0_in_inp;
	sio3_in_reg <= sio0_in_inp;*/
	sr_out_en <= sr_out_en_inp;
	shift_count <= shift_count_inp;
    end
    assign spi_clk = (sr_out_en==1'b1) ? (clk) : (1'b0);
    assign spi_ceb = ~sr_out_en;
    always_comb begin
	sio0_out_inp = 'b0;
	sio1_out_inp = 'b0;
	sio2_out_inp = 'b0;
	sio3_out_inp = 'b0;
	sio0_in_inp = 'b0;
	sio1_in_inp = 'b0;
	sio2_in_inp = 'b0;
	sio3_in_inp = 'b0;
	sio_highz_inp = 'b0;
	sr_out_en_inp = 1'b0;
	shift_count_inp = 5'b0;
	if(nextState==write_load) begin
	    sio0_out_inp = {8'b00111000, addr[20], addr[16], addr[12], addr[8], addr[4], addr[0], 'b0};
            sio1_out_inp = {8'b0, addr[21], addr[17], addr[13], addr[9], addr[5], addr[1], 'b0};
            sio2_out_inp = {8'b0, addr[22], addr[18], addr[14], addr[10], addr[6], addr[2], 'b0};
            sio3_out_inp = {8'b0, addr[23], addr[19], addr[15], addr[11], addr[7], addr[3], 'b0};
            sio_highz_inp = 'b0; 
	    sr_out_en_inp = 1'b0;
	end
	if(nextState==write_wait) begin
	    sio0_out_inp = {sio0_out_reg[22:0], 1'b0};
	    sio1_out_inp = {sio1_out_reg[22:0], 1'b0};
	    sio2_out_inp = {sio2_out_reg[22:0], 1'b0};
	    sio3_out_inp = {sio3_out_reg[22:0], 1'b0};
	    sr_out_en_inp = 1'b1;
	    shift_count_inp = shift_count + 5'b1;
	end
	if(nextState==read_addr_load) begin
	    sio0_out_inp = {8'b11101011, addr[20], addr[16], addr[12], addr[8], addr[4], addr[0], 'b0};
            sio1_out_inp = {8'b0, addr[21], addr[17], addr[13], addr[9], addr[5], addr[1], 'b0};
            sio2_out_inp = {8'b0, addr[22], addr[18], addr[14], addr[10], addr[6], addr[2], 'b0};
            sio3_out_inp = {8'b0, addr[23], addr[19], addr[15], addr[11], addr[7], addr[3], 'b0};
            sio_highz_inp = {14'b0, 11'b000_0000_1111};
	    sr_out_en_inp = 1'b0;
	end
	if(nextState==read_addr_wait) begin
	    sio0_out_inp = {sio0_out_reg[22:0], 1'b0};
	    sio1_out_inp = {sio1_out_reg[22:0], 1'b0};
	    sio2_out_inp = {sio2_out_reg[22:0], 1'b0};
	    sio3_out_inp = {sio3_out_reg[22:0], 1'b0};
	    sio_highz_inp = {sio_highz_inp[22:0], 1'b0};
	    sr_out_en_inp = 1'b1;
	    shift_count_inp = shift_count + 5'b1;
	end
	if(nextSate==read_data_wait) begin
	    sio0_out_inp = {spi_sio0_in, sio0_out_reg[23:1]};
	    sio1_out_inp = {spi_sio1_in, sio1_out_reg[23:1]};
	    sio2_out_inp = {spi_sio2_in, sio2_out_reg[23:1]};
	    sio3_out_inp = {spi_sio3_in, sio3_out_reg[23:1]};
	    sr_out_en_inp = 1'b1;
	    shift_count_inp = shift_count + 5'b1;
	end
	if(nextState==init_rst_en_load) begin
	    sio0_out_inp = {8'h66, 'b0};
	    sio1_out_inp = {'b0};
	    sio2_out_inp = {'b0};
	    sio3_out_inp = {'b0};
	    so_out_en_inp = 1'b0;
	    sio_highz_inp = 'b0;
	end
	if(nextState==init_rst_en_wait) begin
	    sio0_out_inp = {spi_sio0_in, sio0_out_reg[23:1]};
	    sio1_out_inp = {spi_sio1_in, sio1_out_reg[23:1]};
	    sio2_out_inp = {spi_sio2_in, sio2_out_reg[23:1]};
	    sio3_out_inp = {spi_sio3_in, sio3_out_reg[23:1]};
	    sr_out_en_inp = 1'b1;
	    shift_count_inp = shift_count + 5'b1;
	end
	if(nextState==init_rst_load) begin
	    sio0_out_inp = {8'h99, 'b0};
	    sio1_out_inp = {'b0};
	    sio2_out_inp = {'b0};
	    sio3_out_inp = {'b0};
	    so_out_en_inp = 1'b0;
	    sio_highz_inp = 'b0;
	end
	if(nextState==init_rst_wait) begin
	    sio0_out_inp = {spi_sio0_in, sio0_out_reg[23:1]};
	    sio1_out_inp = {spi_sio1_in, sio1_out_reg[23:1]};
	    sio2_out_inp = {spi_sio2_in, sio2_out_reg[23:1]};
	    sio3_out_inp = {spi_sio3_in, sio3_out_reg[23:1]};
	    sr_out_en_inp = (shift_count>=5'd8) ? (1'b0) : (1'b1);
	    shift_count_inp = shift_count + 5'b1;
	end
	if(nextState==init_spi_qmen_load) begin
	    sio0_out_inp = {8'h35, 'b0};
	    sio1_out_inp = {'b0};
	    sio2_out_inp = {'b0};
	    sio3_out_inp = {'b0};
	    so_out_en_inp = 1'b0;
	    sio_highz_inp = 'b0;
	end
	if(nextState==init_spi_qmen_wait) begin
	    sio0_out_inp = {spi_sio0_in, sio0_out_reg[23:1]};
	    sio1_out_inp = {spi_sio1_in, sio1_out_reg[23:1]};
	    sio2_out_inp = {spi_sio2_in, sio2_out_reg[23:1]};
	    sio3_out_inp = {spi_sio3_in, sio3_out_reg[23:1]};
	    sr_out_en_inp = 1'b1;
	    shift_count_inp = shift_count + 5'b1;
	end
    end
    
    always_comb begin
	sio_out_init_load = 1'b0;
	sio_out_read_load = 1'b0;
	sio_out_read_store = 1'b0;
	write_en = 1'b0;
	nextState = wt;
	case(currState)
	    wt: // wait for read or write command
		begin
		    if(init==1'b1) begin
			nextState = init_rst_en_load;
		    end
		    else if(write==1'b1) begin
			nextState = write_load;
		    end
		    else if(read==1'b1) begin
			nextState = read_addr_load;
		    end
		end
	    write_load: // load write command into out registers
		begin
		    nextState = write_wait;
		end
	    write_wait: // wait for write command to be shifted out
		begin
		    if(shift_count>=5'd24) nextState = wt;
		    else nextState = write_wait;
		end
	    read_addr_load: // load first read state, to shift out address
		begin
		    nextState = read_addr_wait;
		end
	    read_addr_wait: // shift out address
		begin
		    if(shift_count>=5'd20) nextState = read_data_load;
		    else nextState = read_addr_wait;
		end
	    read_data_wait: 
		begin
		    if(shift_count>=5'd24) nextState = wt;
		    else nextState = read_data_wait;
		end
	    init_rst_en_load: // init, load command to reset SPI
		begin
		    nextState = init_rst_en_wait;
		end
	    init_rst_en_wait:
		begin
		    if(shift_count>=5'd8) nextState = init_rst_load;
		    else nextState = init_rst_en_wait;
		end
	    init_rst_load:
		begin
		    nextState = init_rst_wait;
		end
	    init_rst_wait:
		begin
		    if(shift_count>=5'd10) nextState = init_spi_qmen_load;
		    else nextState = init_rst_wait;
		end
	    init_spi_qmen_load:
		begin
		    nextState = init_spi_qmen_wait;
		end
	    init_spi_qmen_wait:
		begin
		    if(shift_count>=5'd8) nextState = wt;
		    else nextState = init_spi_qmen_wait;
		end
	endcase
    end
    endmodule: spi

module tt_um_sandsim_Alden_G878 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
  // uio constants
  assign uio_oe[0] = 1'b1; // flash chip enable output en
  assign uio_out[0] = 1'b1; // flash chip enable
  assign uio_oe[3] = 1'b1; // clock enable
  assign uio_oe[6] = 1'b1; // used RAM chip enable
  assign uio_oe[7] = 1'b1; // unused RAM chip enable output en
  assign uio_out[7] = 1'b1; // unused RAM chip enable
  
  // uio pin assignments
  // uio[0]: unused, const high
  // uio[1]: SD0
  // uio[2]: SD1
  // uio[3]: SCK
  // uio[4]: SD2
  // uio[5]: SD3
  // uio[6]: CS#
  // uio[7]: unused, const high
  
  // uo pin assignmnets
  // uo[0]: R1
  // uo[1]: G1
  // uo[2]: B1
  // uo[3]: vsync
  // uo[4]: R0
  // uo[5]: G0
  // uo[6]: B0
  // uo[7]: hsync

  

  /*// All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};*/

endmodule
