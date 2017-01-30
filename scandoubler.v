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

	// shifter video interface
	input            hs_in,
	input            vs_in,
	input      [7:0] r_in,
	input      [7:0] g_in,
	input      [7:0] b_in,

	// output interface
	output reg       hs_out,
	output           vs_out,
	output reg [7:0] r_out,
	output reg [7:0] g_out,
	output reg [7:0] b_out
);

assign vs_out = vs_in;

reg ce_x1, ce_x2;
always @(negedge clk_sys) begin
	reg old_ce;
	reg [7:0] cnt   = 0;
	reg [7:0] pixsz = 0;
	old_ce <= ce_pix;

	if(~&cnt) cnt <= cnt + 1'd1;

	ce_x2 <= 0;
	ce_x1 <= 0;
	if(~old_ce & ce_pix) begin
		pixsz <= {1'b0, cnt[7:1]};
		ce_x1 <= 1;
		ce_x2 <= 1;
		cnt   <= 0;
	end

	if(cnt == pixsz) ce_x2 <= 1;
end

always @(posedge clk_sys) begin
	// 2 lines of 1024 pixels 3*4 bit RGB
	(* ramstyle = "no_rw_check" *) reg [23:0] sd_buffer[2047:0];

	// use alternating sd_buffers when storing/reading data   
	reg        line_toggle;

	reg  [9:0] hs_max;
	reg  [9:0] hs_rise;
	reg  [9:0] hcnt;

	reg hs, hs2, vs;
	reg [9:0] sd_hcnt;

	if(ce_x1) begin
		hs <= hs_in;

		// falling edge of hsync indicates start of line
		if(hs && !hs_in) begin
			hs_max <= hcnt;
			hcnt <= 0;
		end else begin
			hcnt <= hcnt + 1'd1;
		end

		// save position of rising edge
		if(!hs && hs_in) hs_rise <= hcnt;

		vs <= vs_in;
		if(vs != vs_in) line_toggle <= 0;

		// begin of incoming hsync
		if(hs && !hs_in) line_toggle <= !line_toggle;

		sd_buffer[{line_toggle, hcnt}] <= {r_in, g_in, b_in};
	end

	if(ce_x2) begin
		hs2 <= hs_in;

		// output counter synchronous to input and at twice the rate
		sd_hcnt <= sd_hcnt + 1'd1;
		if(hs2 && !hs_in)     sd_hcnt <= hs_max;
		if(sd_hcnt == hs_max) sd_hcnt <= 0;

		// replicate horizontal sync at twice the speed
		if(sd_hcnt == hs_max)  hs_out <= 0;
		if(sd_hcnt == hs_rise) hs_out <= 1;

		// read data from line sd_buffer
		{r_out, g_out, b_out}  <= sd_buffer[{~line_toggle, sd_hcnt}];
	end
end

endmodule
