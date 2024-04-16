`timescale 1ns / 1ps
//1，5，3，3，2
//[15] tvalid
//[12:8] Bytes offset 0-255,0-111:11111
//[7:5] Byte_in_seg
//[4:2] val_index
//[1:0] val_type,01:2B;10:4B;11:8B
//将第一步取的128b数据进一步按容器类型提取，同时解析出该容器数据的序号。
module sub1_bit #(
	parameter SUB_PKTS_LEN = 8,
	parameter L_BIT_ACT_LEN = 3,
	parameter O_BIT_LEN = 1
)
(
	input				clk,
	input				aresetn,

	input						    i_bit_act_valid,
	input [L_BIT_ACT_LEN-1:0]	    i_bit_act,
	input [SUB_PKTS_LEN-1:0]	    i_bit_hdr,
	input                           i_bit_mask,

	output reg					    o_bit_out_valid,
	output reg 						o_bit_out,
	output reg                      o_bit_mask
	// output reg 						o_bit_seg_valid
);

//雪潭定义字节高低位的顺序与我定义字节高低位的顺序不一样
always @(posedge clk) begin
	if(~aresetn) begin
		o_bit_out_valid <= 1'b0;
		o_bit_out <= 1'd0;
		o_bit_mask <= 1'b0;
		// o_bit_seg_valid <= 1'd0;
	end
	else if (i_bit_act_valid) begin
		o_bit_out_valid <= 1'b1;
		o_bit_mask <= i_bit_mask; 
		case({i_bit_act[2:0]})
			// 2B 在这里3c按0，1，2，3，4，5，6，7来算
			3'b000: begin
				o_bit_out <= i_bit_hdr[7];
			end
			3'b001: begin
				o_bit_out <= i_bit_hdr[6];
			end
			// 4B
			3'b010: begin
				o_bit_out <= i_bit_hdr[5];
			end
			// 8B
			3'b011: begin
				o_bit_out <= i_bit_hdr[4];
			end
			3'b100: begin
				o_bit_out <= i_bit_hdr[3];
			end
			3'b101: begin
				o_bit_out <= i_bit_hdr[2];
			end
			// 4B
			3'b110: begin
				o_bit_out <= i_bit_hdr[1];
			end
			// 8B
			3'b111: begin
				o_bit_out <= i_bit_hdr[0];
			end
			// default: begin
			// 	o_bit_out_valid <= 1'b0;
			// 	o_bit_out <= 0;
			// 	o_bit_mask <= 1'b0;
			// end
		endcase
	end
	else begin
		o_bit_out_valid <= 1'b0;
		o_bit_out       <= 0;
		// o_bit_seg_valid <= 1'b0;
	end
end


endmodule
