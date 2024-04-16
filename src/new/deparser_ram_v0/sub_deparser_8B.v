//1，5，3，3，2
//[15] tvalid
//[12:8] Bytes offset 0-255,0-111:11111
//[7:5] Byte_in_seg
//[4:2] val_index
//[1:0] val_type,01:2B;10:4B;11:8B

//[12:5] Bytes by 32 bit
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/12/06 16:59:12
// Design Name: 
// Module Name: sub_deparser_8B
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sub_deparser_8B #(
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
	// output reg [63:0]							val_out,//here we can get nuturely get the val_by parser_index
	output reg [31:0]                           val_out1,
	output reg [31:0]                           val_out2,
	output reg [1:0]							val_out_type,
	output reg [7:0]                            val_out_offset1,
	output reg [7:0]                            val_out_offset2,
	output reg                                  val_out_end,
	output reg                                  val_out_ready
);

// always @(posedge clk) begin
// 	if (~aresetn) begin
// 		val_out_valid <= 0;
// 		val_out_end <= 0;
// 		val_out_ready <= 1'b1;
// 		val_out <= 0;
// 		val_out_type <= 0;
// 		val_out_offset <= 0;
// 	end
// 	else begin
// 		if (parse_act_srt) begin
// 			val_out_valid <= parse_act[15];
// 			val_out_offset <= parse_act[12:5];
// 			val_out_end <= 1'b1;
// 			val_out_ready <= 1'b0;
// 			val_out_type <= 2'b11;
// 			case(parse_act[4:2])
// 				3'd0: val_out[63:0] <= i_8B_val[64*0 +: 64];
// 				3'd1: val_out[63:0] <= i_8B_val[64*1 +: 64];
// 				3'd2: val_out[63:0] <= i_8B_val[64*2 +: 64];
// 				3'd3: val_out[63:0] <= i_8B_val[64*3 +: 64];
// 				3'd4: val_out[63:0] <= i_8B_val[64*4 +: 64];
// 				3'd5: val_out[63:0] <= i_8B_val[64*5 +: 64];
// 				3'd6: val_out[63:0] <= i_8B_val[64*6 +: 64];
// 				3'd7: val_out[63:0] <= i_8B_val[64*7 +: 64];
// 			endcase
// 		end
// 		else begin
// 			val_out_type <= 0;
// 			val_out_end <= 1'b0;
// 			val_out_ready <= 1'b1;
// 			val_out_offset <= val_out_offset;
// 			val_out_valid <= 1'b0;
// 			val_out <= val_out;
// 		end
// 	end
// end

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
			val_out_type <= 2'b11;
			case(parse_act[5])
				0:begin
					val_out_offset1 <= parse_act[12:6];//偶地址
					val_out_offset2 <= parse_act[12:6];//奇地址
					case(parse_act[4:2])//在这里给容器奇偶分组
						3'd0: begin
							val_out1[31:0] <= {i_8B_val[8*6 +: 8],i_8B_val[8*4 +: 8],i_8B_val[8*2 +: 8],i_8B_val[8*0 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*7 +: 8],i_8B_val[8*5 +: 8],i_8B_val[8*3 +: 8],i_8B_val[8*1 +: 8]};
						end
						3'd1: begin
							val_out1[31:0] <= {i_8B_val[8*14 +: 8],i_8B_val[8*12 +: 8],i_8B_val[8*10 +: 8],i_8B_val[8*8 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*15 +: 8],i_8B_val[8*13 +: 8],i_8B_val[8*11 +: 8],i_8B_val[8*9 +: 8]};
						end
						3'd2: begin 
							val_out1[31:0] <= {i_8B_val[8*22 +: 8],i_8B_val[8*20 +: 8],i_8B_val[8*18 +: 8],i_8B_val[8*16 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*23 +: 8],i_8B_val[8*21 +: 8],i_8B_val[8*19 +: 8],i_8B_val[8*17 +: 8]};
						end
						3'd3: begin 
							val_out1[31:0] <= {i_8B_val[8*30 +: 8],i_8B_val[8*28 +: 8],i_8B_val[8*26 +: 8],i_8B_val[8*24 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*31 +: 8],i_8B_val[8*29 +: 8],i_8B_val[8*27 +: 8],i_8B_val[8*25 +: 8]};
						end
						3'd4: begin 
							val_out1[31:0] <= {i_8B_val[8*38 +: 8],i_8B_val[8*36 +: 8],i_8B_val[8*34 +: 8],i_8B_val[8*32 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*39 +: 8],i_8B_val[8*37 +: 8],i_8B_val[8*35 +: 8],i_8B_val[8*33 +: 8]};
						end
						3'd5: begin 
							val_out1[31:0] <= {i_8B_val[8*46 +: 8],i_8B_val[8*44 +: 8],i_8B_val[8*42 +: 8],i_8B_val[8*40 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*47 +: 8],i_8B_val[8*45 +: 8],i_8B_val[8*43 +: 8],i_8B_val[8*41 +: 8]};
						end
						3'd6: begin 
							val_out1[31:0] <= {i_8B_val[8*54 +: 8],i_8B_val[8*52 +: 8],i_8B_val[8*50 +: 8],i_8B_val[8*48 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*55 +: 8],i_8B_val[8*53 +: 8],i_8B_val[8*51 +: 8],i_8B_val[8*49 +: 8]};
						end
						3'd7: begin 
							val_out1[31:0] <= {i_8B_val[8*62 +: 8],i_8B_val[8*60 +: 8],i_8B_val[8*58 +: 8],i_8B_val[8*56 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*63 +: 8],i_8B_val[8*61 +: 8],i_8B_val[8*59 +: 8],i_8B_val[8*57 +: 8]};
						end
					endcase
				end
				1:begin
					val_out_offset1 <= parse_act[12:6]+1'b1;//偶地址
					val_out_offset2 <= parse_act[12:6];//奇地址
					case(parse_act[4:2])
						3'd0: begin
							val_out1[31:0] <= {i_8B_val[8*7 +: 8],i_8B_val[8*5 +: 8],i_8B_val[8*3 +: 8],i_8B_val[8*1 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*6 +: 8],i_8B_val[8*4 +: 8],i_8B_val[8*2 +: 8],i_8B_val[8*0 +: 8]};
						end
						3'd1: begin
							val_out1[31:0] <= {i_8B_val[8*15 +: 8],i_8B_val[8*13 +: 8],i_8B_val[8*11 +: 8],i_8B_val[8*9 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*14 +: 8],i_8B_val[8*12 +: 8],i_8B_val[8*10 +: 8],i_8B_val[8*8 +: 8]};
						end
						3'd2: begin 
							val_out1[31:0] <= {i_8B_val[8*23 +: 8],i_8B_val[8*21 +: 8],i_8B_val[8*19 +: 8],i_8B_val[8*17 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*22 +: 8],i_8B_val[8*20 +: 8],i_8B_val[8*18 +: 8],i_8B_val[8*16 +: 8]};
						end
						3'd3: begin 
							val_out1[31:0] <= {i_8B_val[8*31 +: 8],i_8B_val[8*29 +: 8],i_8B_val[8*27 +: 8],i_8B_val[8*25 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*30 +: 8],i_8B_val[8*28 +: 8],i_8B_val[8*26 +: 8],i_8B_val[8*24 +: 8]};
						end
						3'd4: begin 
							val_out1[31:0] <= {i_8B_val[8*39 +: 8],i_8B_val[8*37 +: 8],i_8B_val[8*35 +: 8],i_8B_val[8*33 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*38 +: 8],i_8B_val[8*36 +: 8],i_8B_val[8*34 +: 8],i_8B_val[8*32 +: 8]};
						end
						3'd5: begin 
							val_out1[31:0] <= {i_8B_val[8*47 +: 8],i_8B_val[8*45 +: 8],i_8B_val[8*43 +: 8],i_8B_val[8*41 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*46 +: 8],i_8B_val[8*44 +: 8],i_8B_val[8*42 +: 8],i_8B_val[8*40 +: 8]};
						end
						3'd6: begin 
							val_out1[31:0] <= {i_8B_val[8*55 +: 8],i_8B_val[8*53 +: 8],i_8B_val[8*51 +: 8],i_8B_val[8*49 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*54 +: 8],i_8B_val[8*52 +: 8],i_8B_val[8*50 +: 8],i_8B_val[8*48 +: 8]};
						end
						3'd7: begin 
							val_out1[31:0] <= {i_8B_val[8*63 +: 8],i_8B_val[8*61 +: 8],i_8B_val[8*59 +: 8],i_8B_val[8*57 +: 8]};
							val_out2[31:0] <= {i_8B_val[8*62 +: 8],i_8B_val[8*60 +: 8],i_8B_val[8*58 +: 8],i_8B_val[8*56 +: 8]};
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