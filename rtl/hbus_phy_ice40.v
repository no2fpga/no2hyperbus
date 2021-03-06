/*
 * hbus_phy_ice40.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module hbus_phy_ice40 #(
	parameter integer SERDES_GRP_BASE = 0
)(
	// HyperRAM pins
	inout  wire [7:0] hbus_dq,
	inout  wire       hbus_rwds,
	output wire       hbus_ck,
	output wire [3:0] hbus_cs_n,
	output wire       hbus_rst_n,

	// PHY interface
	input  wire [ 1:0] phy_ck_en,

	output wire [ 3:0] phy_rwds_in,
	input  wire [ 3:0] phy_rwds_out,
	input  wire [ 1:0] phy_rwds_oe,

	output wire [31:0] phy_dq_in,
	input  wire [31:0] phy_dq_out,
	input  wire [ 1:0] phy_dq_oe,

	input  wire [ 3:0] phy_cs_n,
	input  wire        phy_rst_n,

	// PHY configuration
	input  wire [ 7:0] phy_cfg_wdata,
	output wire [ 7:0] phy_cfg_rdata,
	input  wire        phy_cfg_stb,

	// Clocks / Sync
	output reg  [ 3:0] clk_rd_delay,

	input  wire clk_1x,
	input  wire clk_4x,
	input  wire clk_rd,
	input  wire sync_4x,
	input  wire sync_rd
);

	// Signals
	// -------

	reg        phy_edge;
	reg  [1:0] phy_phase;

	wire [1:0] serdes_ck_dout;

	wire [1:0] serdes_rwds_din;
	wire [1:0] serdes_rwds_dout;
	wire [1:0] serdes_rwds_oe;

	wire [1:0] serdes_dq_din[0:8];
	wire [1:0] serdes_dq_dout[0:8];
	wire [1:0] serdes_dq_oe[0:8];

	reg  [3:0] iob_cs_n;


	// Config
	// ------

	always @(posedge clk_1x)
		if (phy_cfg_stb) begin
			phy_edge     <= phy_cfg_wdata[6];
			phy_phase    <= phy_cfg_wdata[5:4];
			clk_rd_delay <= phy_cfg_wdata[3:0];
		end


	assign phy_cfg_rdata = {
		1'b0,
		phy_edge,
		phy_phase,
		clk_rd_delay
	};


	// Clock
	// -----

	ice40_oserdes #(
		.MODE       ("CLK90_2X"),
		.SERDES_GRP (SERDES_GRP_BASE + 'h90)
	) oserdes_ck_I (
		.d      ({2'b00, phy_ck_en}),
		.q      (serdes_ck_dout),
		.sync   (sync_4x),
		.clk_1x (clk_1x),
		.clk_4x (clk_4x)
	);

	SB_IO #(
		.PIN_TYPE(6'b1100_01)
	) io_ck_I (
		.PACKAGE_PIN   (hbus_ck),
		.OUTPUT_ENABLE (1'b1),
		.D_OUT_0       (serdes_ck_dout[0]),
		.D_OUT_1       (serdes_ck_dout[1]),
		.OUTPUT_CLK    (clk_4x)
	);


	// RWDS
	// ----

	ice40_oserdes #(
		.MODE       ("DATA"),
		.SERDES_GRP (SERDES_GRP_BASE + 'h80)
	) oserdes_rwds_o_I (
		.d      (phy_rwds_out),
		.q      (serdes_rwds_dout),
		.sync   (sync_4x),
		.clk_1x (clk_1x),
		.clk_4x (clk_4x)
	);

	ice40_oserdes #(
		.MODE       ("DATA"),
		.SERDES_GRP (SERDES_GRP_BASE + 'h81)
	) oserdes_rwds_oe_I (
		.d      ({phy_rwds_oe[1], phy_rwds_oe[1], phy_rwds_oe[0], phy_rwds_oe[0]}),
		.q      (serdes_rwds_oe),
		.sync   (sync_4x),
		.clk_1x (clk_1x),
		.clk_4x (clk_4x)
	);

	ice40_iserdes #(
		.EDGE_SEL   ("DUAL_POS_POS"),
		.PHASE_SEL  ("DYNAMIC"),
		.SERDES_GRP (SERDES_GRP_BASE + 'h80)
	) iserdes_rwds_I (
		.d         (serdes_rwds_din),
		.q         (phy_rwds_in),
		.edge_sel  (phy_edge),
		.phase_sel (phy_phase),
		.sync      (sync_rd),
		.clk_1x    (clk_1x),
		.clk_4x    (clk_rd)
	);

	SB_IO #(
		.PIN_TYPE(6'b 1101_00)
	) io_rwds_I (
		.PACKAGE_PIN   (hbus_rwds),
		.OUTPUT_ENABLE (serdes_rwds_oe[0]),
		.D_OUT_0       (serdes_rwds_dout[0]),
		.D_IN_0        (serdes_rwds_din[0]),
		.D_IN_1        (serdes_rwds_din[1]),
		.OUTPUT_CLK    (clk_4x),
		.INPUT_CLK     (clk_rd)
	);


	// DQ
	// --

	generate
		genvar i;

		for (i=0; i<8; i=i+1)
		begin

			ice40_oserdes #(
				.MODE       ("DATA"),
				.SERDES_GRP (SERDES_GRP_BASE + (i<<4))
			) oserdes_dq_o_I (
				.d      ({phy_dq_out[24+i], phy_dq_out[16+i], phy_dq_out[8+i], phy_dq_out[i]}),
				.q      (serdes_dq_dout[i]),
				.sync   (sync_4x),
				.clk_1x (clk_1x),
				.clk_4x (clk_4x)
			);

			ice40_oserdes #(
				.MODE       ("DATA"),
				.SERDES_GRP (SERDES_GRP_BASE + (i<<4) + 1)
			) oserdes_dq_oe_I (
				.d      ({phy_dq_oe[1], phy_dq_oe[1], phy_dq_oe[0], phy_dq_oe[0]}),
				.q      (serdes_dq_oe[i]),
				.sync   (sync_4x),
				.clk_1x (clk_1x),
				.clk_4x (clk_4x)
			);

			ice40_iserdes #(
				.EDGE_SEL   ("DUAL_POS_POS"),
				.PHASE_SEL  ("DYNAMIC"),
				.SERDES_GRP (SERDES_GRP_BASE + (i<<4))
			) iserdes_dq_I (
				.d          (serdes_dq_din[i]),
				.q          ({phy_dq_in[24+i], phy_dq_in[16+i], phy_dq_in[8+i], phy_dq_in[i]}),
				.edge_sel   (phy_edge),
				.phase_sel  (phy_phase),
				.sync       (sync_rd),
				.clk_1x     (clk_1x),
				.clk_4x     (clk_rd)
			);

			SB_IO #(
				.PIN_TYPE(6'b 1101_00)
			) io_dq_I (
				.PACKAGE_PIN   (hbus_dq[i]),
				.OUTPUT_ENABLE (serdes_dq_oe[i][0]),
				.D_OUT_0       (serdes_dq_dout[i][0]),
				.D_IN_0        (serdes_dq_din[i][0]),
				.D_IN_1        (serdes_dq_din[i][1]),
				.OUTPUT_CLK    (clk_4x),
				.INPUT_CLK     (clk_rd)
			);

		end
	endgenerate


	// Aux signals
	// -----------

	always @(posedge clk_1x)
		iob_cs_n <= phy_cs_n;

	SB_IO #(
		.PIN_TYPE(6'b 1101_01)
	) io_cs_n_I[3:0] (
		.PACKAGE_PIN   (hbus_cs_n),
		.OUTPUT_ENABLE (1'b1),
		.D_OUT_0       (iob_cs_n),
		.OUTPUT_CLK    (clk_4x)
	);

	assign hbus_rst_n = phy_rst_n;

endmodule
