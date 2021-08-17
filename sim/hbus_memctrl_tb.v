/*
 * hbus_memctrl_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`timescale 1ns / 100ps

module hbus_memctrl_tb;

	// Signals
	// -------

	// HyperRAM pins
	wire  [7:0] hbus_dq;
	wire        hbus_rwds;
	wire        hbus_ck;
	wire  [3:0] hbus_cs_n;
	wire        hbus_rst_n;

	// PHY interface
	wire [ 1:0] phy_ck_en;

	wire [ 3:0] phy_rwds_in;
	wire [ 3:0] phy_rwds_out;
	wire [ 1:0] phy_rwds_oe;

	wire [31:0] phy_dq_in;
	wire [31:0] phy_dq_out;
	wire [ 1:0] phy_dq_oe;

	wire [ 3:0] phy_cs_n;
	wire        phy_rst_n;

	// PHY configuration
	wire [ 7:0] phy_cfg_wdata;
	wire [ 7:0] phy_cfg_rdata;
	wire        phy_cfg_stb;

	// Memory interface
	wire [ 1:0] mi_addr_cs;
	reg  [31:0] mi_addr;
	reg  [ 6:0] mi_len;
	reg         mi_rw;
	wire        mi_linear;
	reg         mi_valid;
	wire        mi_ready;

	reg  [31:0] mi_wdata;
	wire [ 3:0] mi_wmsk;
	wire        mi_wack;
	wire        mi_wlast;

	wire [31:0] mi_rdata;
	wire        mi_rstb;
	wire        mi_rlast;

	// Wishbone interface
	reg  [31:0] wb_wdata;
	wire [31:0] wb_rdata;
	reg  [ 3:0] wb_addr;
	reg         wb_we;
	reg         wb_cyc;
	wire        wb_ack;

	// Clocks / Sync
	wire [3:0] clk_read_delay;

	reg  pll_lock = 1'b0;
	wire clk_1x;
	reg  clk_4x = 1'b0;
	reg  clk_rd = 1'b0;
	reg  sync_4x;
	wire sync_rd;
	wire rst;

	reg        rst_div;
	reg  [1:0] clk_div;
	reg  [3:0] rst_cnt = 4'h8;


	// Recording setup
	// ---------------

	initial begin
		$dumpfile("hbus_memctrl_tb.vcd");
		$dumpvars(0,hbus_memctrl_tb);
	end


	// DUT
	// ---

	// Controller
	hbus_memctrl dut_I (
		.phy_ck_en     (phy_ck_en),
		.phy_rwds_in   (phy_rwds_in),
		.phy_rwds_out  (phy_rwds_out),
		.phy_rwds_oe   (phy_rwds_oe ),
		.phy_dq_in     (phy_dq_in),
		.phy_dq_out    (phy_dq_out),
		.phy_dq_oe     (phy_dq_oe),
		.phy_cs_n      (phy_cs_n),
		.phy_rst_n     (phy_rst_n),
		.phy_cfg_wdata (phy_cfg_wdata),
		.phy_cfg_rdata (phy_cfg_rdata),
		.phy_cfg_stb   (phy_cfg_stb),
		.mi_addr_cs    (mi_addr_cs),
		.mi_addr       (mi_addr),
		.mi_len        (mi_len),
		.mi_rw         (mi_rw),
		.mi_linear     (mi_linear),
		.mi_valid      (mi_valid),
		.mi_ready      (mi_ready),
		.mi_wdata      (mi_wdata),
		.mi_wmsk       (mi_wmsk),
		.mi_wack       (mi_wack),
		.mi_wlast      (mi_wlast),
		.mi_rdata      (mi_rdata),
		.mi_rstb       (mi_rstb),
		.mi_rlast      (mi_rlast),
		.wb_wdata      (wb_wdata),
		.wb_rdata      (wb_rdata),
		.wb_addr       (wb_addr),
		.wb_we         (wb_we),
		.wb_cyc        (wb_cyc),
		.wb_ack        (wb_ack),
		.clk           (clk_1x),
		.rst           (rst)
	);

	// PHY
	hbus_phy_ice40 phy_I (
		.hbus_dq       (hbus_dq),
		.hbus_rwds     (hbus_rwds),
		.hbus_ck       (hbus_ck),
		.hbus_cs_n     (hbus_cs_n),
		.hbus_rst_n    (hbus_rst_n),
		.phy_ck_en     (phy_ck_en),
		.phy_rwds_in   (phy_rwds_in),
		.phy_rwds_out  (phy_rwds_out),
		.phy_rwds_oe   (phy_rwds_oe ),
		.phy_dq_in     (phy_dq_in),
		.phy_dq_out    (phy_dq_out),
		.phy_dq_oe     (phy_dq_oe),
		.phy_cs_n      (phy_cs_n),
		.phy_rst_n     (phy_rst_n),
		.phy_cfg_wdata (phy_cfg_wdata),
		.phy_cfg_rdata (phy_cfg_rdata),
		.phy_cfg_stb   (phy_cfg_stb),
		.clk_rd_delay  (),
		.clk_1x        (clk_1x),
		.clk_4x        (clk_4x),
		.clk_rd        (clk_rd),
		.sync_4x       (sync_4x),
		.sync_rd       (sync_rd)
	);

	// RAM model
	s27kl0642 ram_I (
		.DQ7      (hbus_dq[7]),
		.DQ6      (hbus_dq[6]),
		.DQ5      (hbus_dq[5]),
		.DQ4      (hbus_dq[4]),
		.DQ3      (hbus_dq[3]),
		.DQ2      (hbus_dq[2]),
		.DQ1      (hbus_dq[1]),
		.DQ0      (hbus_dq[0]),
		.RWDS     (hbus_rwds),
		.CSNeg    (&hbus_cs_n),	// Any CS
		.CK       ( hbus_ck),
		.CKn      (~hbus_ck),
		.RESETNeg (hbus_rst_n)
	);


	// Mem interface
	// -------------

	// Fixed values
	assign mi_addr_cs = 2'b01;
	assign mi_linear  = 1'b0;
	assign mi_wmsk    = 4'h0;

	always @(posedge clk_1x)
		if (rst)
			mi_wdata <= 32'h00010203;
		else if (mi_wack)
			mi_wdata <= mi_wdata + 32'h04040404;

	// Stimulus
	// --------

	task wb_write;
		input [ 3:0] addr;
		input [31:0] data;
		begin
			wb_addr  <= addr;
			wb_wdata <= data;
			wb_we    <= 1'b1;
			wb_cyc   <= 1'b1;

			while (~wb_ack)
				@(posedge clk_1x);

			wb_addr  <= 4'hx;
			wb_wdata <= 32'hxxxxxxxx;
			wb_we    <= 1'bx;
			wb_cyc   <= 1'b0;

			@(posedge clk_1x);
		end
	endtask

	task mi_burst_write;
		input [31:0] addr;
		input [ 6:0] len;
		begin
			mi_addr  <= addr;
			mi_len   <= len;
			mi_rw    <= 1'b0;
			mi_valid <= 1'b1;

			@(posedge clk_1x);
			while (~mi_ready)
				@(posedge clk_1x);

			mi_valid <= 1'b0;

			@(posedge clk_1x);
		end
	endtask

	task mi_burst_read;
		input [31:0] addr;
		input [ 6:0] len;
		begin
			mi_addr  <= addr;
			mi_len   <= len;
			mi_rw    <= 1'b1;
			mi_valid <= 1'b1;

			@(posedge clk_1x);
			while (~mi_ready)
				@(posedge clk_1x);

			mi_valid <= 1'b0;

			@(posedge clk_1x);
		end
	endtask

	initial begin
		// Defaults
		wb_addr  <= 4'hx;
		wb_wdata <= 32'hxxxxxxxx;
		wb_we    <= 1'bx;
		wb_cyc   <= 1'b0;

		mi_addr  <= 32'hxxxxxxxx;
		mi_len   <= 7'hx;
		mi_rw    <= 1'bx;
		mi_valid <= 1'b0;

		@(negedge rst);
		@(posedge clk_1x);

		// Reset pulse
		wb_write(4'h0, 32'h00001102);
		wb_write(4'h0, 32'h00001100);

		// Queue CR0 write
		wb_write(4'h3, 32'h00000030);
		wb_write(4'h2, 32'h60000100);
		wb_write(4'h2, 32'h00008fef);
		wb_write(4'h2, 32'h00000000);

		wb_write(4'h1, 32'h0000000e);

		// Wait
		#200
		@(posedge clk_1x);

		// Queue Memory write
		wb_write(4'h3, 32'h00000030);
		wb_write(4'h2, 32'h00000246);
		wb_write(4'h3, 32'h00000020);
		wb_write(4'h2, 32'h00040000);
		wb_write(4'h3, 32'h00000030);
		wb_write(4'h2, 32'hcafebabe);

		wb_write(4'h1, 32'h0000021c);

		// Wait
		#200
		@(posedge clk_1x);

		// Queue Memory read
		wb_write(4'h3, 32'h00000030);
		wb_write(4'h2, 32'h80000246);
		wb_write(4'h3, 32'h00000020);
		wb_write(4'h2, 32'h00040000);
		wb_write(4'h3, 32'h00000000);
		wb_write(4'h2, 32'h00000000);

		wb_write(4'h1, 32'h0000021d);

		// Wait
		#200
		@(posedge clk_1x);

		// Switch to run-time mode
		wb_write(4'h0, 32'h00003101);

		// Execute 32 byte burst
		mi_burst_write(32'h00002000, 7'd31);
		mi_burst_read (32'h00002000, 7'd15);
		mi_burst_write(32'h00003000, 7'd31);
	end


	// Clock / Reset
	// -------------

	// Native clocks
	initial begin
		# 200 pll_lock = 1'b1;
		# 100000 $finish;
	end

	always #4 clk_4x = ~clk_4x;		// 125 MHz
	always #4 clk_rd = ~clk_rd;		// 125 MHz

	// Clock Divider & Sync
	always @(negedge clk_4x or negedge pll_lock)
		if (~pll_lock)
			rst_div <= 1'b1;
		else
			rst_div <= 1'b0;

	always @(posedge clk_4x or posedge rst_div)
		if (rst_div)
			{ sync_4x, clk_div } <= 3'b000;
		else
			case (clk_div)
				2'b00: { sync_4x, clk_div } <= 3'b001;
				2'b01: { sync_4x, clk_div } <= 3'b010;
				2'b10: { sync_4x, clk_div } <= 3'b011;
				2'b11: { sync_4x, clk_div } <= 3'b100;
			endcase

	assign clk_1x = clk_div[1];
	assign sync_rd = sync_4x;

	// Reset
	always @(posedge clk_1x or negedge pll_lock)
		if (~pll_lock)
			rst_cnt <= 4'h8;
		else if (rst_cnt[3])
			rst_cnt <= rst_cnt + 1;

	assign rst = rst_cnt[3];

endmodule
