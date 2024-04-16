//1，5，3，3，2
//[15] tvalid
//[12:8] Bytes offset 0-255,0-111:11111
//[7:5] Byte_in_seg
//[4:2] val_index
//[1:0] val_type,01:2B;10:4B;11:8B

//[12:5] Bytes by 32 bit
`timescale 1ns / 1ps


module sub_deparser_2B #(
	parameter C_PKT_VEC_WIDTH = (8+4+2)*8*8+256,
	parameter C_PARSE_ACT_LEN = 16						// only 6 bits are used here
)
(
	input										clk,
	input										aresetn,

	input										parse_act_srt,//start parse_act
	input [C_PARSE_ACT_LEN-1:0]					parse_act,
	// input [C_PKT_VEC_WIDTH-1:0]					phv_in,
	
	input [511:0]                               i_8B_val,
	input [255:0]                               i_4B_val,
	input [127:0]                               i_2B_val,

	output reg									val_out_valid,
	output reg [7:0]							val_out1,//here we can get nuturely get the val_by parser_index
	output reg [7:0]							val_out2,
	output reg [1:0]							val_out_type,
	output reg [7:0]                            val_out_offset1,
	output reg [7:0]                            val_out_offset2,
	output reg                                  val_out_end,
	output reg                                  val_out_ready
);

//val_out1是偶数，val_out_offset1是偶数地址
//val_out2是奇数，val_out_offset2是奇数地址
always @(posedge clk) begin
	if (~aresetn) begin
		val_out_valid <= 0;
		val_out_end <= 0;
		val_out_ready <= 1'b1;
		val_out1 <= 0;
		val_out2 <= 0;
		val_out_type <= 0;
		val_out_offset1 <= 0;
		val_out_offset2 <= 0;
	end
	else begin
		if (parse_act_srt) begin
			val_out_valid <= parse_act[15];
			val_out_end <= 1'b1;
			val_out_ready <= 1'b0;
			val_out_type <= 2'b01;
			case(parse_act[5])
				0:begin
					val_out_offset1 <= parse_act[12:6];
					val_out_offset2 <= parse_act[12:6];
					case(parse_act[4:2])
						3'd0: begin
							val_out1[7:0] <= i_2B_val[8*0 +: 8];//7:0 
							val_out2[7:0] <= i_2B_val[8*1 +: 8];//15:8
							
						end
						3'd1: begin
							val_out1[7:0] <= i_2B_val[8*2 +: 8];//16:23
							val_out2[7:0] <= i_2B_val[8*3 +: 8];//31:24
						end
						3'd2: begin
							val_out1[7:0] <= i_2B_val[8*4 +: 8];
							val_out2[7:0] <= i_2B_val[8*5 +: 8];//31:24
						end
						3'd3: begin
							val_out1[7:0] <= i_2B_val[8*6 +: 8];
							val_out2[7:0] <= i_2B_val[8*7 +: 8];//31:24
						end
						3'd4: begin
							val_out1[7:0] <= i_2B_val[8*8 +: 8];
							val_out2[7:0] <= i_2B_val[8*9 +: 8];//31:24
						end
						3'd5: begin
							val_out1[7:0] <= i_2B_val[8*10 +: 8];
							val_out2[7:0] <= i_2B_val[8*11 +: 8];//31:24
						end
						3'd6: begin
							val_out1[7:0] <= i_2B_val[8*12 +: 8];
							val_out2[7:0] <= i_2B_val[8*13 +: 8];//31:24
						end
						3'd7: begin
							val_out1[7:0] <= i_2B_val[8*14 +: 8];
							val_out2[7:0] <= i_2B_val[8*15 +: 8];//31:24
						end
					endcase
				end
				1:begin
					val_out_offset1 <= parse_act[12:6]+1'b1;
					val_out_offset2 <= parse_act[12:6];
					case(parse_act[4:2])
						3'd0: begin
							val_out1[7:0] <= i_2B_val[8*1 +: 8];//7:0
							val_out2[7:0] <= i_2B_val[8*0 +: 8];//15:8
						end
						3'd1: begin
							val_out1[7:0] <= i_2B_val[8*3 +: 8];//16:23
							val_out2[7:0] <= i_2B_val[8*2 +: 8];//31:24
						end
						3'd2: begin
							val_out1[7:0] <= i_2B_val[8*5 +: 8];
							val_out2[7:0] <= i_2B_val[8*4 +: 8];//31:24
						end
						3'd3: begin
							val_out1[7:0] <= i_2B_val[8*7 +: 8];
							val_out2[7:0] <= i_2B_val[8*6 +: 8];//31:24
						end
						3'd4: begin
							val_out1[7:0] <= i_2B_val[8*9 +: 8];
							val_out2[7:0] <= i_2B_val[8*8 +: 8];//31:24
						end
						3'd5: begin
							val_out1[7:0] <= i_2B_val[8*11 +: 8];
							val_out2[7:0] <= i_2B_val[8*10 +: 8];//31:24
						end
						3'd6: begin
							val_out1[7:0] <= i_2B_val[8*13 +: 8];
							val_out2[7:0] <= i_2B_val[8*12 +: 8];//31:24
						end
						3'd7: begin
							val_out1[7:0] <= i_2B_val[8*15 +: 8];
							val_out2[7:0] <= i_2B_val[8*14 +: 8];//31:24
						end
					endcase
				end
			endcase
		end
		else begin
			val_out_type <= 0;
			val_out_end <= 1'b0;
			val_out_ready <= 1'b1;
			val_out_offset1 <= val_out_offset1;
			val_out_offset2 <= val_out_offset2;
			val_out_valid <= 1'b0;
			val_out1 <= val_out1;
			val_out2 <= val_out2;
		end
	end
end

endmodule
