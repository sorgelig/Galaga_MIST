//
// scandoubler.v
// 
// Copyright (c) 2015 Till Harbaum <till@harbaum.org> 
// Copyright (c) 2017 Sorgelig
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 

// TODO: Delay vsync one line

module scandoubler
(
	// system interface
	input            clk_sys,
	input            ce_pix,
	input            hq2x,

	// shifter video interface
	input            hs_in,
	input            vs_in,
	input            line_start,

	input      [7:0] r_in,
	input      [7:0] g_in,
	input      [7:0] b_in,

	// output interface
	output reg       hs_out,
	output           vs_out,
	output     [7:0] r_out,
	output     [7:0] g_out,
	output     [7:0] b_out
);

parameter LENGTH = 768;

assign vs_out = vs_in;

reg ce_x1, ce_x4;
always @(negedge clk_sys) begin
	reg old_ce;
	reg [7:0] cnt   = 0;
	reg [7:0] pixsz2, pixsz4 = 0;

	old_ce <= ce_pix;
	if(~&cnt) cnt <= cnt + 1'd1;

	ce_x4 <= 0;
	ce_x1 <= 0;
	if(~old_ce & ce_pix) begin
		pixsz2 <= {1'b0,  cnt[7:1]};
		pixsz4 <= {2'b00, cnt[7:2]};
		ce_x1 <= 1;
		ce_x4 <= 1;
		cnt   <= 0;
	end

	if(cnt == pixsz4)          ce_x4 <= 1;
	if(cnt == pixsz2)          ce_x4 <= 1;
	if(cnt == (pixsz2+pixsz4)) ce_x4 <= 1;
end

wire [5:0] r,g,b;
assign r_out = {r, r[5:4]};
assign g_out = {g, g[5:4]};
assign b_out = {b, b[5:4]};

localparam AWIDTH = `BITS_TO_FIT(LENGTH);
Hq2x #(.LENGTH(LENGTH)) Hq2x
(
	.clk(clk_sys),
	.ce_x4(ce_x4),
	.inputpixel({r_in[7:2],g_in[7:2],b_in[7:2]}),
	.disable_hq2x(~hq2x),
	.reset_frame(vs_in),
	.reset_line(hs_in | line_start),
	.read_y(sd_line),
	.read_x(sd_h[AWIDTH+1:0]),
	.outpixel({r,g,b})
);

reg [10:0] sd_h;
reg  [1:0] sd_line;
wire       ls_in = hs_in | line_start;

always @(posedge clk_sys) begin

	reg [11:0] hs_max,hs_rise,hs_ls;
	reg [10:0] hcnt;
	reg [11:0] sd_hcnt;

	reg hs, hs2, vs, ls;

	if(ce_x1) begin
		hs <= hs_in;
		ls <= ls_in;

		if(ls && !ls_in) hs_ls <= {hcnt,1'b1};

		// falling edge of hsync indicates start of line
		if(hs && !hs_in) begin
			hs_max <= {hcnt,1'b1};
			hcnt <= 0;
			if(ls && !ls_in) hs_ls <= {10'd0,1'b1};
		end else begin
			hcnt <= hcnt + 1'd1;
		end

		// save position of rising edge
		if(!hs && hs_in) hs_rise <= {hcnt,1'b1};

		vs <= vs_in;
		if(vs && ~vs_in) sd_line <= 0;
	end

	if(ce_x4) begin
		hs2 <= hs_in;

		// output counter synchronous to input and at twice the rate
		sd_hcnt <= sd_hcnt + 1'd1;
		sd_h    <= sd_h    + 1'd1;
		if(hs2 && !hs_in)     sd_hcnt <= hs_max;
		if(sd_hcnt == hs_max) sd_hcnt <= 0;

		// replicate horizontal sync at twice the speed
		if(sd_hcnt == hs_max)  hs_out <= 0;
		if(sd_hcnt == hs_rise) hs_out <= 1;

		if(sd_hcnt == hs_ls)   sd_h    <= 0;
		if(sd_hcnt == hs_ls)   sd_line <= sd_line + 1'd1;
	end
end

endmodule
