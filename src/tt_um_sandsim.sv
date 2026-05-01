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
    generate
	int i, j, k;
        always_ff @(posedge clk) begin
	    for(i=0;i<COL;i++) begin
		if(i==COL/2) begin
		    c_in_src_int0[i] <= (c_in_dest[i]==1'b0) ? (1'b0) : (c_in_src[i]);
		    c_in_dest_int0[i] <= (c_in_dest[i]==1'b0) ? (make_sand) : (c_in_dest[i]);
		end
		else begin
		    c_in_src_int0[i] <= (c_in_dest[i]==1'b0) ? (1'b0) : (c_in_src[i]);
		    c_in_dest_int0[i] <= (c_in_dest[i]==1'b0) ? (c_in_src[i]) : (c_in_dest[i]);
		end
	    end
	    for(j=0;j<COL;j++) begin
		case(j)
		    0: begin
			c_in_src_int1[j] <= (c_in_dest_int0[j+1]==1'b0) ? (1'b0) : (c_in_src_int0[j]);
			c_in_dest_int1[j] <= c_in_dest_int0[j];
		    end
		    COL-1: begin
			c_in_src_int1[j] <= c_in_src_int0[j];
			c_in_dest_int1[j] <= (c_in_dest_int0[j]==1'b0) ? (c_in_src_int0[j-1]) : (c_in_dest_int0[j]);
		    end
		    default: begin
			c_in_src_int1[j] <= (c_in_dest_int0[j+1]==1'b0) ? (1'b0) : (c_in_src_int0[j]);
			c_in_dest_int1[j] <= (c_in_dest_int0[j]==1'b0) ? (c_in_src_int0[j-1]) : (c_in_dest_int0[j]);
		    end
		endcase
	    end
	    for(k=0;k<COL;k++) begin
		case(k)
		    0: begin
			c_out_src[k] <= c_in_dest_int1[k];
			c_out_dest[k] <= (c_in_dest_int1[k]==1'b0) ? (c_in_src_int1[k+1]) : (c_in_dest_int1[k]);
		    end
		    COL-1: begin
			c_out_src[k] <= (c_in_dest_int1[k-1]==1'b0) ? (1'b0) : (c_in_src_int1[k]);
			c_out_dest[k] <= c_in_dest_int1[k];
		    end
		    default: begin
			c_out_src[k] <= (c_in_dest_int1[k-1]==1'b0) ? (1'b0) : (c_in_src_int1[k]);
			c_out_dest[k] <= (c_in_dest_int1[k]==1'b0) ? (c_in_src_int1[k+1]) : (c_in_dest_int1[k]);
		    end
		endcase
	    end
        end
    endgenerate
endmodule: update

// VGA controller
module vga_controller
    (input  logic clk, rst_b,
     input  logic pix, pix_valid,
     output logic [$clog2(800)-1:0] x_pos,
     output logic [$clog2(524)-1:0] y_pos,
     output logic [1:0]             vga_r, vga_g, vga_b,
     output logic                   vga_hsync, vga_vsync);
    always_ff @(posedge clk) begin
	if(rst_b==1'b0) begin
	    x_pos <= 'b0;
	    y_pos <= 'b0;
	end
	else begin
	    if(x_pos > 10'd800 && y_pos > 10'd524) begin
		x_pos <= 'b0;
		y_pos <= 'b0;
	    end
	    else if(y_pos > 10'd524) begin
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
     input  logic                     spi_sio0_in, spi_sio1_in, spi_sio2_in, spi_sio3_in,
     output logic                     spi_read_en);
    assign data_out = {sio3_out_inp[24], sio2_out_inp[24], sio1_out_inp[24], sio0_out_inp[24], sio3_out_inp[23], sio2_out_inp[23], sio1_out_inp[23], sio0_out_inp[23]};
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
    /*logic [23:0] sio0_in_inp;
    logic [23:0] sio1_in_inp;
    logic [23:0] sio2_in_inp;
    logic [23:0] sio3_in_inp;*/
    logic [23:0] sio_highz_inp;
    assign spi_sio0_out = sio0_out_reg[23];
    assign spi_sio1_out = sio1_out_reg[23];
    assign spi_sio2_out = sio2_out_reg[23];
    assign spi_sio3_out = sio3_out_reg[23];
    assign spi_highz = sio_highz_reg[23];
    /*assign spi_sio0_in = sio0_in_reg[32];
    assign spi_sio1_in = sio1_in_reg[32];
    assign spi_sio2_in = sio2_in_reg[32];
    assign spi_sio3_in = sio3_in_reg[32];*/
    logic sr_out_en, sio_read_en;
    enum logic [3:0] {
	wt,
	write_load,
	write_wait, 
	read_addr_load, 
	read_addr_wait,
	read_data_wait, 
	init_rst_en_load,
	init_rst_en_wait,
	init_rst_load,
	init_rst_wait,
	init_spi_qmen_load,
	init_spi_qmen_wait} currState, nextState;
    logic [7:0] sio_read_inout_counter;
    logic [4:0] shift_count, shift_count_inp;
    logic [1:0] read_buf[3:0];
    logic sr_out_en_inp, spi_read_inp;
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
        sio_highz_reg <= sio_highz_inp;
	spi_read_en <= spi_read_inp;
    end
    assign spi_clk = (sr_out_en==1'b1) ? (clk) : (1'b0);
    assign spi_ceb = ~sr_out_en;
    always_comb begin
	sio0_out_inp = sio0_out_reg;
	sio1_out_inp = sio1_out_reg;
	sio2_out_inp = sio2_out_reg;
	sio3_out_inp = sio3_out_reg;
	/*sio0_in_inp = sio0_in_reg;
	sio1_in_inp = sio1_in_reg;
	sio2_in_inp = sio2_in_reg;
	sio3_in_inp = sio3_in_reg;*/
	sio_highz_inp = 24'b0;
	sr_out_en_inp = 1'b0;
	shift_count_inp = 5'b0;
        spi_read_inp = 1'b0;
	if(nextState==write_load) begin
	    sio0_out_inp = {8'b00111000, addr[20], addr[16], addr[12], addr[8], addr[4], addr[0], data_in[4], data_in[0], data_in[4], data_in[0], data_in[4], data_in[0], data_in[4], data_in[0]};
            sio1_out_inp = {8'b00000000, addr[21], addr[17], addr[13], addr[9], addr[5], addr[1], data_in[5], data_in[1], data_in[5], data_in[1], data_in[5], data_in[1], data_in[5], data_in[1]};
            sio2_out_inp = {8'b00000000, addr[22], addr[18], addr[14], addr[10], addr[6], addr[2], data_in[6], data_in[2], data_in[6], data_in[2], data_in[6], data_in[2], data_in[6], data_in[2]};
            sio3_out_inp = {8'b00000000, addr[23], addr[19], addr[15], addr[11], addr[7], addr[3], data_in[7], data_in[3], data_in[7], data_in[3], data_in[7], data_in[3], data_in[7], data_in[3]};
            sio_highz_inp = 24'b0; 
	    sr_out_en_inp = 1'b0;
	end
	if(nextState==write_wait) begin
	    sio0_out_inp = {sio0_out_reg[22:0], 23'b0};
	    sio1_out_inp = {sio1_out_reg[22:0], 23'b0};
	    sio2_out_inp = {sio2_out_reg[22:0], 23'b0};
	    sio3_out_inp = {sio3_out_reg[22:0], 23'b0};
	    sr_out_en_inp = 1'b1;
	    shift_count_inp = shift_count + 5'b1;
	end
	if(nextState==read_addr_load) begin
	    sio0_out_inp = {8'b11101011, addr[20], addr[16], addr[12], addr[8], addr[4], addr[0], 10'b0};
            sio1_out_inp = {8'b0, addr[21], addr[17], addr[13], addr[9], addr[5], addr[1], 10'b0};
            sio2_out_inp = {8'b0, addr[22], addr[18], addr[14], addr[10], addr[6], addr[2], 10'b0};
            sio3_out_inp = {8'b0, addr[23], addr[19], addr[15], addr[11], addr[7], addr[3], 10'b0};
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
	if(nextState==read_data_wait) begin
	    sio0_out_inp = {spi_sio0_in, sio0_out_reg[23:1]};
	    sio1_out_inp = {spi_sio1_in, sio1_out_reg[23:1]};
	    sio2_out_inp = {spi_sio2_in, sio2_out_reg[23:1]};
	    sio3_out_inp = {spi_sio3_in, sio3_out_reg[23:1]};
	    sr_out_en_inp = 1'b1;
	    shift_count_inp = shift_count + 5'b1;
	    spi_read_inp  = 1'b1;
	end
	if(nextState==init_rst_en_load) begin
	    sio0_out_inp = {8'h66, 16'b0};
	    sio1_out_inp = {24'b0};
	    sio2_out_inp = {24'b0};
	    sio3_out_inp = {24'b0};
	    sr_out_en_inp = 1'b0;
	    sio_highz_inp = 24'b0;
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
	    sio0_out_inp = {8'h99, 16'b0};
	    sio1_out_inp = {24'b0};
	    sio2_out_inp = {24'b0};
	    sio3_out_inp = {24'b0};
	    sr_out_en_inp = 1'b0;
	    sio_highz_inp = 24'b0;
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
	    sio0_out_inp = {8'h35, 16'b0};
	    sio1_out_inp = {24'b0};
	    sio2_out_inp = {24'b0};
	    sio3_out_inp = {24'b0};
	    sr_out_en_inp = 1'b0;
	    sio_highz_inp = 24'b0;
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
	nextState = wt;
	read_done = 1'b0;
	write_done = 1'b0;
	init_done = 1'b0;
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
		    if(shift_count>=5'd24) begin
			nextState = wt;
			write_done = 1'b1;
		    end
		    else nextState = write_wait;
		end
	    read_addr_load: // load first read state, to shift out address
		begin
		    nextState = read_addr_wait;
		end
	    read_addr_wait: // shift out address
		begin
		    if(shift_count>=5'd20) nextState = read_data_wait;
		    else nextState = read_addr_wait;
		end
	    read_data_wait: 
		begin
		    if(shift_count>=5'd24) begin
			nextState = wt;
			read_done = 1'b1;
		    end
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
		    if(shift_count>=5'd8) begin
			nextState = wt;
			init_done = 1'b0;
		    end
		    else nextState = init_spi_qmen_wait;
		end
	endcase
	if(rst_b==1'b0) nextState = init_rst_en_load;
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
  logic rst_b;
  assign rst_b = rst_n;
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

  // vga controller
  logic pix, pix_valid;
  logic [$clog2(800)-1:0] vga_x_pos;
  logic [$clog2(524)-1:0] vga_y_pos;
  logic [1:0] vga_r, vga_g, vga_b;
  logic vga_hsync, vga_vsync;
  assign uo_out[0] = vga_r[1];
  assign uo_out[1] = vga_g[1];
  assign uo_out[2] = vga_b[1];
  assign uo_out[3] = vga_vsync;
  assign uo_out[4] = vga_r[0];
  assign uo_out[5] = vga_g[0];
  assign uo_out[6] = vga_b[0];
  assign uo_out[7] = vga_hsync;
  assign pix_valid = 1'b1;
  
  vga_controller vga
    (.clk, .rst_b,
     .pix, .pix_valid,
     .x_pos(vga_x_pos), .y_pos(vga_y_pos),
     .vga_r, .vga_g, .vga_b,
     .vga_hsync, .vga_vsync);


  // SPI module
  logic spi_read, spi_write, spi_init, spi_read_done, spi_write_done, spi_init_done;
  logic [$clog2(`COL/8)-1:0] spi_col;
  logic [$clog2(`ROW)-1:0]   spi_row;
  logic [7:0] spi_din, spi_dout;
  logic spi_sck, spi_csb;
  logic spi_sd0_out, spi_sd1_out, spi_sd2_out, spi_sd3_out;
  logic spi_sd0_in, spi_sd1_in, spi_sd2_in, spi_sd3_in;
  assign uio_out[1] = spi_sd0_out;
  assign uio_out[2] = spi_sd1_out;
  assign spi_sd0_in = uio_in[1];
  assign spi_sd1_in = uio_in[2];
  assign uio_out[3] = spi_sck;
  assign uio_out[4] = spi_sd2_out;
  assign uio_out[5] = spi_sd3_out;
  assign spi_sd2_in = uio_in[4];
  assign spi_sd3_in = uio_in[5];
  assign uio_out[6] = spi_csb;
  logic spi_highz, spi_read_en;
  assign uio_oe[1] = ~(spi_highz | spi_read_en);
  assign uio_oe[2] = ~(spi_highz | spi_read_en);
  assign uio_oe[4] = ~(spi_highz | spi_read_en);
  assign uio_oe[5] = ~(spi_highz | spi_read_en);
  
  spi spi_cont
    (.clk, .rst_b,
     .read(spi_read), .write(spi_write), .init(spi_init),
     .read_done(spi_read_done), .write_done(spi_write_done), .init_done(spi_init_done),
     .col(spi_col), .row(spi_row),
     .spi_clk(spi_sck), .spi_ceb(spi_csb),
     .spi_sio0_out(spi_sd0_out), .spi_sio1_out(spi_sd1_out), .spi_sio2_out(spi_sd2_out), .spi_sio3_out(spi_sd3_out),
     .spi_sio0_in(spi_sd0_in), .spi_sio1_in(spi_sd1_in), .spi_sio2_in(spi_sd2_in), .spi_sio3_in(spi_sd3_in),
     .spi_highz, .spi_read_en,
     .data_in(spi_din), .data_out(spi_dout));

  // update kernel
  logic [`COL-1:0] kern_in_src, kern_in_dest;
  logic [`COL-1:0] kern_out_src, kern_out_dest;
  logic make_sand;
  assign make_sand = 
    ui_in[0] | 
    ui_in[1] | 
    ui_in[2] | 
    ui_in[3] | 
    ui_in[4] | 
    ui_in[5] | 
    ui_in[6] | 
    ui_in[7]; 
  // temporary assignments
  assign kern_in_src = line_src;
  assign kern_in_dest = line_dest;
  update kernel
    (.clk, .rst_b, 
     .c_in_src(kern_in_src), .c_in_dest(kern_in_dest),
     .c_out_src(kern_out_src), .c_out_dest(kern_out_dest),
     .make_sand);

  logic [47:0] line_disp_wb, line_src, line_dest, line_in;
  logic [5:0] col_counter, row_counter, prev_row_counter;
  logic [5:0] time_since_shift, prev_vga_y_pos;
  assign pix = line_disp_wb[col_counter];
  logic [31:0] since_init;
  always_ff @(posedge clk) begin
    since_init <= (since_init >= 32'd10000) ? (32'd10000) : (since_init <= since_init + 32'd1);
    if(rst_b==1'b0) since_init <= 32'b0;
    if(since_init == 1'b0) spi_init <= 1'b1;
    else spi_init <= 1'b0;
  end
 
  always_ff @(posedge clk) begin
    if(since_init >= 32'd1000) begin
    prev_row_counter <= row_counter;
    prev_vga_y_pos <= vga_y_pos;
    spi_write <= 1'b0;
    spi_read <= 1'b0;
    if(prev_vga_y_pos!=vga_y_pos) begin
      time_since_shift <= time_since_shift + 6'b1;
      if(time_since_shift<=6'd1 && time_since_shift <= 6'd6) begin
	spi_write <= 1'b1;
      end
    end
    if(vga_x_pos==405) spi_read <= 1'b1;
    if(prev_row_counter != row_counter) begin
      time_since_shift <= 7'b0;
      line_disp_wb <= line_src;
      line_src <= line_dest;
      line_dest <= line_in;
    end
    if(time_since_shift==6'd1) begin
      spi_din <= line_disp_wb[47:40];
      spi_col <= (col_counter >> 3'd3);
      spi_row <= row_counter;
      if(vga_x_pos >=10'd400 && vga_y_pos <= 10'd410) begin
	spi_col <= ((col_counter + 3'd3) >> (3'd3));
        spi_row <= row_counter;
      end
      if(vga_x_pos==10'd429) line_in[47:40] <= spi_dout;
    end
    if(time_since_shift==6'd2) begin
      spi_din <= line_disp_wb[39:32];
      spi_col <= (col_counter >> 3'd3);
      spi_row <= row_counter;
      if(vga_x_pos >=10'd400 && vga_y_pos <= 10'd410) begin
	spi_col <= ((col_counter + 3'd3) >> (3'd3));
        spi_row <= row_counter;
      end
      if(vga_x_pos==10'd429) line_in[39:32] <= spi_dout;
    end
    if(time_since_shift==6'd3) begin
      spi_din <= line_disp_wb[31:24];
      spi_col <= (col_counter >> 3'd3);
      spi_row <= row_counter;
      line_src <= kern_out_src;
      line_dest <= kern_out_dest;
      if(vga_x_pos >=10'd400 && vga_y_pos <= 10'd410) begin
	spi_col <= ((col_counter + 3'd3) >> (3'd3));
        spi_row <= row_counter;
      end
      if(vga_x_pos==10'd429) line_in[31:24] <= spi_dout;
    end
    if(time_since_shift==6'd4) begin
      spi_din <= line_disp_wb[23:16];
      spi_col <= (col_counter >> 3'd3);
      spi_row <= row_counter;
      if(vga_x_pos >=10'd400 && vga_y_pos <= 10'd410) begin
	spi_col <= ((col_counter + 3'd3) >> (3'd3));
        spi_row <= row_counter;
      end
      if(vga_x_pos==10'd429) line_in[23:16] <= spi_dout;
    end
    if(time_since_shift==6'd5) begin
      spi_din <= line_disp_wb[15:8];
      spi_col <= (col_counter >> 3'd3);
      spi_row <= row_counter;
      if(vga_x_pos >=10'd400 && vga_y_pos <= 10'd410) begin
	spi_col <= ((col_counter + 3'd3) >> (3'd3));
        spi_row <= row_counter;
      end
      if(vga_x_pos==10'd429) line_in[15:8] <= spi_dout;
    end
    if(time_since_shift==6'd6) begin
      spi_din <= line_disp_wb[7:0];
      spi_col <= (col_counter >> 3'd3);
      spi_row <= row_counter;
      if(vga_x_pos >=10'd400 && vga_y_pos <= 10'd410) begin
	spi_col <= ((col_counter + 3'd3) >> (3'd3));
        spi_row <= row_counter;
      end
      if(vga_x_pos==10'd429) line_in[7:0] <= spi_dout;
    end
    if(time_since_shift==6'd2) begin
      spi_din <= line_disp_wb[39:32];
      spi_col <= (col_counter >> 3'd3);
      spi_row <= row_counter;
    end
    end
  end
  always_comb begin
    if      (  0 <= vga_x_pos && vga_x_pos <=   9) col_counter = 6'd0;
    else if ( 10 <= vga_x_pos && vga_x_pos <=  19) col_counter = 6'd1;
    else if ( 20 <= vga_x_pos && vga_x_pos <=  29) col_counter = 6'd2;
    else if ( 30 <= vga_x_pos && vga_x_pos <=  39) col_counter = 6'd3;
    else if ( 40 <= vga_x_pos && vga_x_pos <=  49) col_counter = 6'd4;
    else if ( 50 <= vga_x_pos && vga_x_pos <=  59) col_counter = 6'd5;
    else if ( 60 <= vga_x_pos && vga_x_pos <=  69) col_counter = 6'd6;
    else if ( 70 <= vga_x_pos && vga_x_pos <=  79) col_counter = 6'd7;
    else if ( 80 <= vga_x_pos && vga_x_pos <=  89) col_counter = 6'd8;
    else if ( 90 <= vga_x_pos && vga_x_pos <=  99) col_counter = 6'd9;
    else if (100 <= vga_x_pos && vga_x_pos <= 109) col_counter = 6'd10;
    else if (110 <= vga_x_pos && vga_x_pos <= 119) col_counter = 6'd11;
    else if (120 <= vga_x_pos && vga_x_pos <= 129) col_counter = 6'd12;
    else if (130 <= vga_x_pos && vga_x_pos <= 139) col_counter = 6'd13;
    else if (140 <= vga_x_pos && vga_x_pos <= 149) col_counter = 6'd14;
    else if (150 <= vga_x_pos && vga_x_pos <= 159) col_counter = 6'd15;
    else if (160 <= vga_x_pos && vga_x_pos <= 169) col_counter = 6'd16;
    else if (170 <= vga_x_pos && vga_x_pos <= 179) col_counter = 6'd17;
    else if (180 <= vga_x_pos && vga_x_pos <= 189) col_counter = 6'd18;
    else if (190 <= vga_x_pos && vga_x_pos <= 199) col_counter = 6'd19;
    else if (200 <= vga_x_pos && vga_x_pos <= 209) col_counter = 6'd20;
    else if (210 <= vga_x_pos && vga_x_pos <= 219) col_counter = 6'd21;
    else if (220 <= vga_x_pos && vga_x_pos <= 229) col_counter = 6'd22;
    else if (230 <= vga_x_pos && vga_x_pos <= 239) col_counter = 6'd23;
    else if (240 <= vga_x_pos && vga_x_pos <= 249) col_counter = 6'd24;
    else if (250 <= vga_x_pos && vga_x_pos <= 259) col_counter = 6'd25;
    else if (260 <= vga_x_pos && vga_x_pos <= 269) col_counter = 6'd26;
    else if (270 <= vga_x_pos && vga_x_pos <= 279) col_counter = 6'd27;
    else if (280 <= vga_x_pos && vga_x_pos <= 289) col_counter = 6'd28;
    else if (290 <= vga_x_pos && vga_x_pos <= 299) col_counter = 6'd29;
    else if (300 <= vga_x_pos && vga_x_pos <= 309) col_counter = 6'd30;
    else if (310 <= vga_x_pos && vga_x_pos <= 319) col_counter = 6'd31;
    else if (320 <= vga_x_pos && vga_x_pos <= 329) col_counter = 6'd32;
    else if (330 <= vga_x_pos && vga_x_pos <= 339) col_counter = 6'd33;
    else if (340 <= vga_x_pos && vga_x_pos <= 349) col_counter = 6'd34;
    else if (350 <= vga_x_pos && vga_x_pos <= 359) col_counter = 6'd35;
    else if (360 <= vga_x_pos && vga_x_pos <= 369) col_counter = 6'd36;
    else if (370 <= vga_x_pos && vga_x_pos <= 379) col_counter = 6'd37;
    else if (380 <= vga_x_pos && vga_x_pos <= 389) col_counter = 6'd38;
    else if (390 <= vga_x_pos && vga_x_pos <= 399) col_counter = 6'd39;
    else if (400 <= vga_x_pos && vga_x_pos <= 409) col_counter = 6'd40;
    else if (410 <= vga_x_pos && vga_x_pos <= 419) col_counter = 6'd41;
    else if (420 <= vga_x_pos && vga_x_pos <= 429) col_counter = 6'd42;
    else if (430 <= vga_x_pos && vga_x_pos <= 439) col_counter = 6'd43;
    else if (440 <= vga_x_pos && vga_x_pos <= 449) col_counter = 6'd44;
    else if (450 <= vga_x_pos && vga_x_pos <= 459) col_counter = 6'd45;
    else if (460 <= vga_x_pos && vga_x_pos <= 469) col_counter = 6'd46;
    else if (470 <= vga_x_pos && vga_x_pos <= 800) col_counter = 6'd47;

    if      (  0 <= vga_y_pos && vga_y_pos <=   9) row_counter = 6'd0;
    else if ( 10 <= vga_y_pos && vga_y_pos <=  19) row_counter = 6'd1;
    else if ( 20 <= vga_y_pos && vga_y_pos <=  29) row_counter = 6'd2;
    else if ( 30 <= vga_y_pos && vga_y_pos <=  39) row_counter = 6'd3;
    else if ( 40 <= vga_y_pos && vga_y_pos <=  49) row_counter = 6'd4;
    else if ( 50 <= vga_y_pos && vga_y_pos <=  59) row_counter = 6'd5;
    else if ( 60 <= vga_y_pos && vga_y_pos <=  69) row_counter = 6'd6;
    else if ( 70 <= vga_y_pos && vga_y_pos <=  79) row_counter = 6'd7;
    else if ( 80 <= vga_y_pos && vga_y_pos <=  89) row_counter = 6'd8;
    else if ( 90 <= vga_y_pos && vga_y_pos <=  99) row_counter = 6'd9;
    else if (100 <= vga_y_pos && vga_y_pos <= 109) row_counter = 6'd10;
    else if (110 <= vga_y_pos && vga_y_pos <= 119) row_counter = 6'd11;
    else if (120 <= vga_y_pos && vga_y_pos <= 129) row_counter = 6'd12;
    else if (130 <= vga_y_pos && vga_y_pos <= 139) row_counter = 6'd13;
    else if (140 <= vga_y_pos && vga_y_pos <= 149) row_counter = 6'd14;
    else if (150 <= vga_y_pos && vga_y_pos <= 159) row_counter = 6'd15;
    else if (160 <= vga_y_pos && vga_y_pos <= 169) row_counter = 6'd16;
    else if (170 <= vga_y_pos && vga_y_pos <= 179) row_counter = 6'd17;
    else if (180 <= vga_y_pos && vga_y_pos <= 189) row_counter = 6'd18;
    else if (190 <= vga_y_pos && vga_y_pos <= 199) row_counter = 6'd19;
    else if (200 <= vga_y_pos && vga_y_pos <= 209) row_counter = 6'd20;
    else if (210 <= vga_y_pos && vga_y_pos <= 219) row_counter = 6'd21;
    else if (220 <= vga_y_pos && vga_y_pos <= 229) row_counter = 6'd22;
    else if (230 <= vga_y_pos && vga_y_pos <= 239) row_counter = 6'd23;
    else if (240 <= vga_y_pos && vga_y_pos <= 249) row_counter = 6'd24;
    else if (250 <= vga_y_pos && vga_y_pos <= 259) row_counter = 6'd25;
    else if (260 <= vga_y_pos && vga_y_pos <= 269) row_counter = 6'd26;
    else if (270 <= vga_y_pos && vga_y_pos <= 279) row_counter = 6'd27;
    else if (280 <= vga_y_pos && vga_y_pos <= 289) row_counter = 6'd28;
    else if (290 <= vga_y_pos && vga_y_pos <= 299) row_counter = 6'd29;
    else if (300 <= vga_y_pos && vga_y_pos <= 309) row_counter = 6'd30;
    else if (310 <= vga_y_pos && vga_y_pos <= 319) row_counter = 6'd31;
    else if (320 <= vga_y_pos && vga_y_pos <= 329) row_counter = 6'd32;
    else if (330 <= vga_y_pos && vga_y_pos <= 339) row_counter = 6'd33;
    else if (340 <= vga_y_pos && vga_y_pos <= 349) row_counter = 6'd34;
    else if (350 <= vga_y_pos && vga_y_pos <= 359) row_counter = 6'd35;
    else if (360 <= vga_y_pos && vga_y_pos <= 600) row_counter = 6'd36;
  end
  /*// All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};*/

endmodule
