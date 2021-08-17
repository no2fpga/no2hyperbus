/*
 * hbus_dline.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module hbus_dline #(
	parameter integer N = 3
)(
	input  wire di,
	output reg  do,
	input  wire [N-1:0] delay,
	input  wire clk
);

	genvar i;

	// Signals
	wire [N:0] stage;

	// First stage input
	assign stage[0] = di;

	// Generate delays
	generate
		for (i=0; i<N; i=i+1)
		begin
			// Delay line
			reg [(1<<i)-1:0] d;

			if (i == 0)
				always @(posedge clk)
					d <= stage[i];
			else
				always @(posedge clk)
					d <= { stage[i], d[(1<<i)-1:1] };

			// Mux
			assign stage[i+1] = delay[i] ? d[0] : stage[i];
		end
	endgenerate

	// Final register
	always @(posedge clk)
		do <= stage[N];

endmodule
