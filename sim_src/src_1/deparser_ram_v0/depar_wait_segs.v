`timescale 1ns / 1ps


module depar_wait_segs #(
	parameter C_AXIS_DATA_WIDTH = 256,
	parameter C_AXIS_TUSER_WIDTH = 128,
	parameter C_NUM_SEGS = 8)
(
	input									clk,
	input									aresetn,

	// input from pkt fifo
	input [C_AXIS_DATA_WIDTH-1:0]						pkt_fifo_tdata,//该数据来的比phv快一步，且是原封不动的报文
	input [C_AXIS_TUSER_WIDTH-1:0]						pkt_fifo_tuser,
	input [C_AXIS_DATA_WIDTH/8-1:0]						pkt_fifo_tkeep,
	input												pkt_fifo_tlast,
	input												pkt_fifo_empty,
	
	input												fst_half_fifo_ready,
	input												snd_half_fifo_ready,

	// output
	output reg											pkt_fifo_rd_en,

	output reg [11:0]									o_vlan,
	output reg											o_vlan_valid,//准备2048b的vlan

	
	// output reg [C_AXIS_DATA_WIDTH*C_NUM_SEGS/2-1:0]		fst_half_tdata,
	output reg [C_AXIS_DATA_WIDTH-1:0]		                fst_half_tdata1,
	output reg [C_AXIS_DATA_WIDTH-1:0]		                fst_half_tdata2,
	output reg [C_AXIS_DATA_WIDTH-1:0]		                fst_half_tdata3,
	output reg [C_AXIS_DATA_WIDTH-1:0]		                fst_half_tdata4,
	output reg [C_AXIS_TUSER_WIDTH*C_NUM_SEGS/2-1:0]	    fst_half_tuser,
	output reg [C_AXIS_DATA_WIDTH/8*C_NUM_SEGS/2-1:0]	    fst_half_tkeep,
	output reg [C_NUM_SEGS/2-1:0]						    fst_half_tlast,
	output reg											    fst_half_valid,//在4段报文准备好后写入fifo

	// output reg [C_AXIS_DATA_WIDTH*C_NUM_SEGS/2-1:0]		snd_half_tdata,
	output reg [C_AXIS_DATA_WIDTH-1:0]					snd_half_tdata1,
	output reg [C_AXIS_DATA_WIDTH-1:0]					snd_half_tdata2,
	output reg [C_AXIS_DATA_WIDTH-1:0]					snd_half_tdata3,
	output reg [C_AXIS_DATA_WIDTH-1:0]					snd_half_tdata4,
	output reg [C_AXIS_TUSER_WIDTH*C_NUM_SEGS/2-1:0]	snd_half_tuser,
	output reg [C_AXIS_DATA_WIDTH/8*C_NUM_SEGS/2-1:0]	snd_half_tkeep,
	output reg [C_NUM_SEGS/2-1:0]						snd_half_tlast,
	output reg											snd_half_valid,//在4段报文准备好后写入fifo

	// output remaining segs to FIFO
	output reg [C_AXIS_DATA_WIDTH-1:0]					output_fifo_tdata,
	output reg [C_AXIS_TUSER_WIDTH-1:0]					output_fifo_tuser,
	output reg [C_AXIS_DATA_WIDTH/8-1:0]				output_fifo_tkeep,
	output reg											output_fifo_tlast,
	output reg											output_fifo_valid,
	input												output_fifo_ready
);


localparam	WAIT_FIRST_SEG=0,
			WAIT_SECOND_SEG=1,
			WAIT_THIRD_SEG=2,
			WAIT_FOURTH_SEG=3,
			WAIT_FIVE_SEG=4,
			WAIT_SIX_SEG=5,
			WAIT_SEVEN_SEG=6,
			WAIT_EIGHT_SEG=7,
			FLUSH_SEG=8;

reg [C_AXIS_DATA_WIDTH-1:0]					output_fifo_tdata_next;
reg [C_AXIS_TUSER_WIDTH-1:0]				output_fifo_tuser_next;
reg [C_AXIS_DATA_WIDTH/8-1:0]				output_fifo_tkeep_next;
reg											output_fifo_tlast_next;
reg											output_fifo_valid_next;

// reg [C_AXIS_DATA_WIDTH*C_NUM_SEGS/2-1:0]	fst_half_tdata_next, snd_half_tdata_next;
reg [C_AXIS_DATA_WIDTH-1:0]		fst_half_tdata1_next;
reg [C_AXIS_DATA_WIDTH-1:0]		fst_half_tdata2_next;
reg [C_AXIS_DATA_WIDTH-1:0]		fst_half_tdata3_next;
reg [C_AXIS_DATA_WIDTH-1:0]		fst_half_tdata4_next;
reg [C_AXIS_DATA_WIDTH-1:0]		snd_half_tdata1_next;
reg [C_AXIS_DATA_WIDTH-1:0]		snd_half_tdata2_next;
reg [C_AXIS_DATA_WIDTH-1:0]		snd_half_tdata3_next;
reg [C_AXIS_DATA_WIDTH-1:0]		snd_half_tdata4_next;

reg [C_AXIS_TUSER_WIDTH*C_NUM_SEGS/2-1:0]	fst_half_tuser_next, snd_half_tuser_next;
reg [C_AXIS_DATA_WIDTH/8*C_NUM_SEGS/2-1:0]	fst_half_tkeep_next, snd_half_tkeep_next;
reg [C_NUM_SEGS/2-1:0]						fst_half_tlast_next, snd_half_tlast_next;

reg											fst_half_valid_next, snd_half_valid_next;
reg vlan_valid_next;
reg [11:0] vlan_next;

reg [3:0] state, state_next;

always @(*) begin

	state_next = state;

	pkt_fifo_rd_en = 0;

	// fst_half_tdata_next = fst_half_tdata;
	fst_half_tdata1_next = fst_half_tdata1;
	fst_half_tdata2_next = fst_half_tdata2;
	fst_half_tdata3_next = fst_half_tdata3;
	fst_half_tdata4_next = fst_half_tdata4;
	fst_half_tuser_next  = fst_half_tuser ;
	fst_half_tkeep_next  = fst_half_tkeep ;
	fst_half_tlast_next  = fst_half_tlast ;

	// snd_half_tdata_next = snd_half_tdata;
	snd_half_tdata1_next = snd_half_tdata1;
	snd_half_tdata2_next = snd_half_tdata2;
	snd_half_tdata3_next = snd_half_tdata3;
	snd_half_tdata4_next = snd_half_tdata4;
	snd_half_tuser_next  = snd_half_tuser;
	snd_half_tkeep_next  = snd_half_tkeep;
	snd_half_tlast_next  = snd_half_tlast;

	fst_half_valid_next = 0;
	snd_half_valid_next = 0;
	vlan_valid_next = 0;
	vlan_next = o_vlan;

	// output remaining segs
	output_fifo_tdata_next = 0;
	output_fifo_tuser_next = 0;
	output_fifo_tkeep_next = 0;
	output_fifo_tlast_next = 0;
	output_fifo_valid_next = 0;

	case (state)
		WAIT_FIRST_SEG: begin
			if (!pkt_fifo_empty) begin
				fst_half_tdata1_next[0+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
				fst_half_tuser_next[0+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
				fst_half_tkeep_next[0+:C_AXIS_DATA_WIDTH/8] = pkt_fifo_tkeep;
				fst_half_tlast_next[0] = pkt_fifo_tlast;

				vlan_next = {pkt_fifo_tdata[115:112],pkt_fifo_tdata[127:120]};
				vlan_valid_next = 1;

				if (pkt_fifo_tlast) begin
					if (fst_half_fifo_ready && snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						fst_half_valid_next = 1;//在报文结束时候拉高说明该报文有效
						snd_half_valid_next = 1;
						state_next = WAIT_FIRST_SEG;
					end
				end
				else begin
					pkt_fifo_rd_en = 1;
					state_next = WAIT_SECOND_SEG;
				end
			end
		end
		WAIT_SECOND_SEG: begin
			if (!pkt_fifo_empty) begin
				fst_half_tdata2_next[0+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
				fst_half_tuser_next[C_AXIS_TUSER_WIDTH+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
				fst_half_tkeep_next[C_AXIS_DATA_WIDTH/8+:C_AXIS_DATA_WIDTH/8] = pkt_fifo_tkeep;
				fst_half_tlast_next[1] = pkt_fifo_tlast;


				if (pkt_fifo_tlast) begin
					if (fst_half_fifo_ready && snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						fst_half_valid_next = 1;
						snd_half_valid_next = 1;
						state_next = WAIT_FIRST_SEG;
					end
				end
				else begin
					if (fst_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						state_next = WAIT_THIRD_SEG;
					end
				end
			end
		end
		WAIT_THIRD_SEG: begin
			if (!pkt_fifo_empty) begin
				fst_half_tdata3_next[0+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
				fst_half_tuser_next[2*C_AXIS_TUSER_WIDTH+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
				fst_half_tkeep_next[2*C_AXIS_DATA_WIDTH/8+:C_AXIS_DATA_WIDTH/8] = pkt_fifo_tkeep;
				fst_half_tlast_next[2] = pkt_fifo_tlast;


				if (pkt_fifo_tlast) begin
					if (fst_half_fifo_ready && snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						fst_half_valid_next = 1;
						snd_half_valid_next = 1;
						state_next = WAIT_FIRST_SEG;
					end
				end
				else begin
					if (fst_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						state_next = WAIT_FOURTH_SEG;
					end
				end
			end
		end
		WAIT_FOURTH_SEG: begin
			if (!pkt_fifo_empty) begin
				fst_half_tdata4_next[0+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
				fst_half_tuser_next[3*C_AXIS_TUSER_WIDTH+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
				fst_half_tkeep_next[3*C_AXIS_DATA_WIDTH/8+:C_AXIS_DATA_WIDTH/8] = pkt_fifo_tkeep;
				fst_half_tlast_next[3] = pkt_fifo_tlast;


				if (pkt_fifo_tlast) begin
					if (fst_half_fifo_ready && snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						fst_half_valid_next = 1;
						snd_half_valid_next = 1;
						state_next = WAIT_FIRST_SEG;
					end
				end
				else begin
					if (fst_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						fst_half_valid_next = 1;
						state_next = WAIT_FIVE_SEG;
					end
				end
			end
		end
		WAIT_FIVE_SEG:begin
			if (!pkt_fifo_empty) begin
				snd_half_tdata1_next[0+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
				snd_half_tuser_next[0+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
				snd_half_tkeep_next[0+:C_AXIS_DATA_WIDTH/8] = pkt_fifo_tkeep;
				snd_half_tlast_next[0] = pkt_fifo_tlast;


				if (pkt_fifo_tlast) begin
					if (snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						snd_half_valid_next = 1;
						state_next = WAIT_FIRST_SEG;
					end
				end
				else begin
					pkt_fifo_rd_en = 1;
					state_next = WAIT_SIX_SEG;
				end
			end
		end
		WAIT_SIX_SEG:begin
			if (!pkt_fifo_empty) begin
				snd_half_tdata2_next[0+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
				snd_half_tuser_next[C_AXIS_TUSER_WIDTH+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
				snd_half_tkeep_next[C_AXIS_DATA_WIDTH/8+:C_AXIS_DATA_WIDTH/8] = pkt_fifo_tkeep;
				snd_half_tlast_next[1] = pkt_fifo_tlast;


				if (pkt_fifo_tlast) begin
					if (snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						snd_half_valid_next = 1; 
						state_next = WAIT_FIRST_SEG; 
					end
				end
				else begin
					if (snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						state_next = WAIT_SEVEN_SEG;
					end
				end
			end
		end
		WAIT_SEVEN_SEG:begin
			if (!pkt_fifo_empty) begin
				snd_half_tdata3_next[0+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
				snd_half_tuser_next[2*C_AXIS_TUSER_WIDTH+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
				snd_half_tkeep_next[2*C_AXIS_DATA_WIDTH/8+:C_AXIS_DATA_WIDTH/8] = pkt_fifo_tkeep;
				snd_half_tlast_next[2] = pkt_fifo_tlast;


				if (pkt_fifo_tlast) begin
					if (snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						snd_half_valid_next = 1; 
						state_next = WAIT_FIRST_SEG; 
					end
				end
				else begin
					if (snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						state_next = WAIT_EIGHT_SEG;
					end
				end
			end
		end
		WAIT_EIGHT_SEG:begin
			if (!pkt_fifo_empty) begin
				snd_half_tdata4_next[0+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
				snd_half_tuser_next[3*C_AXIS_TUSER_WIDTH+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
				snd_half_tkeep_next[3*C_AXIS_DATA_WIDTH/8+:C_AXIS_DATA_WIDTH/8] = pkt_fifo_tkeep;
				snd_half_tlast_next[3] = pkt_fifo_tlast;


				if (pkt_fifo_tlast) begin
					if (snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						snd_half_valid_next = 1; 
						state_next = WAIT_FIRST_SEG; 
					end
				end
				else begin
					if (snd_half_fifo_ready) begin
						pkt_fifo_rd_en = 1;
						snd_half_valid_next = 1;
						state_next = FLUSH_SEG;
					end
				end
			end
		end
		FLUSH_SEG: begin
			if (!pkt_fifo_empty) begin
				output_fifo_tdata_next = pkt_fifo_tdata;
				output_fifo_tuser_next = pkt_fifo_tuser;
				output_fifo_tkeep_next = pkt_fifo_tkeep;
				output_fifo_tlast_next = pkt_fifo_tlast;

				if (output_fifo_ready) begin
					output_fifo_valid_next = 1;
					pkt_fifo_rd_en = 1;
					if (pkt_fifo_tlast) begin
						state_next = WAIT_FIRST_SEG;
					end
				end
			end
		end
	endcase
end


always @(posedge clk) begin
	if (~aresetn) begin
		state <= WAIT_FIRST_SEG;

		// fst_half_tdata <= 0;
		fst_half_tdata1 <= 0;
		fst_half_tdata2 <= 0;
		fst_half_tdata3 <= 0;
		fst_half_tdata4 <= 0;
		fst_half_tuser  <= 0;
		fst_half_tkeep  <= 0;
		fst_half_tlast  <= 0;

		// snd_half_tdata <= 0;
		snd_half_tdata1 <= 0;
		snd_half_tdata2 <= 0;
		snd_half_tdata3 <= 0;
		snd_half_tdata4 <= 0;
		snd_half_tuser  <= 0;
		snd_half_tkeep  <= 0;
		snd_half_tlast  <= 0;

		fst_half_valid <= 0;
		snd_half_valid <= 0;
		o_vlan_valid <= 0;
		o_vlan <= 0;
		//
		output_fifo_tdata <= 0;
		output_fifo_tuser <= 0;
		output_fifo_tkeep <= 0;
		output_fifo_tlast <= 0;
		output_fifo_valid <= 0;
	end
	else begin
		state <= state_next;

		// fst_half_tdata <= fst_half_tdata_next;
		fst_half_tdata1 <= fst_half_tdata1_next;
		fst_half_tdata2 <= fst_half_tdata2_next;
		fst_half_tdata3 <= fst_half_tdata3_next;
		fst_half_tdata4 <= fst_half_tdata4_next;
		fst_half_tuser <= fst_half_tuser_next;
		fst_half_tkeep <= fst_half_tkeep_next;
		fst_half_tlast <= fst_half_tlast_next;

		// snd_half_tdata <= snd_half_tdata_next;
		snd_half_tdata1 <= snd_half_tdata1_next;
		snd_half_tdata2 <= snd_half_tdata2_next;
		snd_half_tdata3 <= snd_half_tdata3_next;
		snd_half_tdata4 <= snd_half_tdata4_next;
		snd_half_tuser <= snd_half_tuser_next;
		snd_half_tkeep <= snd_half_tkeep_next;
		snd_half_tlast <= snd_half_tlast_next;

		fst_half_valid <= fst_half_valid_next;
		snd_half_valid <= snd_half_valid_next;
		o_vlan_valid <= vlan_valid_next;
		o_vlan <= vlan_next;
		//
		output_fifo_tdata <= output_fifo_tdata_next;
		output_fifo_tuser <= output_fifo_tuser_next;
		output_fifo_tkeep <= output_fifo_tkeep_next;
		output_fifo_tlast <= output_fifo_tlast_next;
		output_fifo_valid <= output_fifo_valid_next;
	end
end

endmodule