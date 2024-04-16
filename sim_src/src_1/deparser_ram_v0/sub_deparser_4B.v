//1，5，3，3，2
//[15] tvalid
//[12:8] Bytes offset 0-255,0-111:11111
//[7:5] Byte_in_seg
//[4:2] val_index
//[1:0] val_type,01:2B;10:4B;11:8B

//[12:5] Bytes by 32 bit
`timescale 1ns / 1ps


module sub_deparser_4B #(
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
	output reg [15:0]							val_out1,//here we can get nuturely get the val_by parser_index
	output reg [15:0]							val_out2,//here we can get nuturely get the val_by parser_index
	output reg [1:0]							val_out_type,
	output reg [7:0]                            val_out_offset1,
	output reg [7:0]                            val_out_offset2,
	output reg                                  val_out_end,
	output reg                                  val_out_ready
);

// localparam PHV_2B_START_POS = 100+256;
// localparam PHV_4B_START_POS = 100+256+2*8*8;
// localparam PHV_6B_START_POS = 100+256+2*8*8+4*8*8;


// reg			val_out_valid_nxt;
// reg [63:0]	val_out_nxt;
// reg [1:0]	val_out_type_nxt;
// reg [7:0]   val_out_offset_nxt;
// reg         val_out_end_nxt;

// always @(*) begin
// 	val_out_valid_nxt = 0;
// 	val_out_end_nxt = 0;
// 	val_out_ready = 1'b1;
// 	val_out_nxt = val_out;
// 	val_out_type_nxt = val_out_type;
// 	val_out_offset_nxt = val_out_offset;
// 	if (parse_act_srt) begin
// 		val_out_valid_nxt = parse_act[15];
// 		val_out_offset_nxt = parse_act[12:5];
// 		val_out_end_nxt = 1'b1;
// 		val_out_ready   = 0;
// 		case({parse_act[1:0], parse_act[15]})
// 			// 2B
// 			3'b011: begin
// 				val_out_type_nxt = 2'b01;
// 				case(parse_act[4:2])
// 					3'd0: val_out_nxt[15:0] = i_2B_val[16*0 +: 16];
// 					3'd1: val_out_nxt[15:0] = i_2B_val[16*1 +: 16];
// 					3'd2: val_out_nxt[15:0] = i_2B_val[16*2 +: 16];
// 					3'd3: val_out_nxt[15:0] = i_2B_val[16*3 +: 16];
// 					3'd4: val_out_nxt[15:0] = i_2B_val[16*4 +: 16];
// 					3'd5: val_out_nxt[15:0] = i_2B_val[16*5 +: 16];
// 					3'd6: val_out_nxt[15:0] = i_2B_val[16*6 +: 16];
// 					3'd7: val_out_nxt[15:0] = i_2B_val[16*7 +: 16];
// 				endcase
// 			end
// 			// 4B
// 			3'b101: begin
// 				val_out_type_nxt = 2'b10;
// 				case(parse_act[4:2])
// 					3'd0: val_out_nxt[31:0] = i_4B_val[32*0 +: 32];
// 					3'd1: val_out_nxt[31:0] = i_4B_val[32*1 +: 32];
// 					3'd2: val_out_nxt[31:0] = i_4B_val[32*2 +: 32];
// 					3'd3: val_out_nxt[31:0] = i_4B_val[32*3 +: 32];
// 					3'd4: val_out_nxt[31:0] = i_4B_val[32*4 +: 32];
// 					3'd5: val_out_nxt[31:0] = i_4B_val[32*5 +: 32];
// 					3'd6: val_out_nxt[31:0] = i_4B_val[32*6 +: 32];
// 					3'd7: val_out_nxt[31:0] = i_4B_val[32*7 +: 32];
// 				endcase
// 			end
// 			// 6B
// 			3'b111: begin
// 				val_out_type_nxt = 2'b11;
// 				case(parse_act[4:2])
// 					3'd0: val_out_nxt[63:0] = i_8B_val[64*0 +: 64];
// 					3'd1: val_out_nxt[63:0] = i_8B_val[64*1 +: 64];
// 					3'd2: val_out_nxt[63:0] = i_8B_val[64*2 +: 64];
// 					3'd3: val_out_nxt[63:0] = i_8B_val[64*3 +: 64];
// 					3'd4: val_out_nxt[63:0] = i_8B_val[64*4 +: 64];
// 					3'd5: val_out_nxt[63:0] = i_8B_val[64*5 +: 64];
// 					3'd6: val_out_nxt[63:0] = i_8B_val[64*6 +: 64];
// 					3'd7: val_out_nxt[63:0] = i_8B_val[64*7 +: 64];
// 				endcase
// 			end
// 			default: begin
// 				val_out_type_nxt = 0;
// 				val_out_nxt = 0;
// 				val_out_offset_nxt = 0;
// 				val_out_end_nxt = 0;
// 			end
// 		endcase
// 	end
// end


// always @(posedge clk) begin
// 	if (~aresetn) begin
// 		val_out_valid <= 0;
// 		val_out <= 0;
// 		val_out_type <= 0;
// 		val_out_offset <= 8'd0;
// 		val_out_end <= 1'b0;
// 	end
// 	else begin
// 		val_out_valid <= val_out_valid_nxt;
// 		val_out <= val_out_nxt;
// 		val_out_type <= val_out_type_nxt;
// 		val_out_offset <= val_out_offset_nxt;
// 		val_out_end <= val_out_end_nxt;
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
			val_out_type <= 2'b10;
			case(parse_act[5])
				0:begin
					val_out_offset1 <= parse_act[12:6];//偶地址
					val_out_offset2 <= parse_act[12:6];//奇地址
					case(parse_act[4:2])
						3'd0: begin
							val_out1[15:0] <= {i_4B_val[8*2 +: 8],i_4B_val[8*0 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*3 +: 8],i_4B_val[8*1 +: 8]};
						end
						3'd1: begin
							val_out1[15:0] <= {i_4B_val[8*6 +: 8],i_4B_val[8*4 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*7 +: 8],i_4B_val[8*5 +: 8]};
						end
						3'd2: begin 
							val_out1[15:0] <= {i_4B_val[8*10 +: 8],i_4B_val[8*8 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*11 +: 8],i_4B_val[8*9 +: 8]};
						end
						3'd3: begin 
							val_out1[15:0] <= {i_4B_val[8*14 +: 8],i_4B_val[8*12 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*15 +: 8],i_4B_val[8*13 +: 8]};
						end
						3'd4: begin 
							val_out1[15:0] <= {i_4B_val[8*18 +: 8],i_4B_val[8*16 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*19 +: 8],i_4B_val[8*17 +: 8]};
						end
						3'd5: begin 
							val_out1[15:0] <= {i_4B_val[8*22 +: 8],i_4B_val[8*20 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*23 +: 8],i_4B_val[8*21 +: 8]};
						end
						3'd6: begin 
							val_out1[15:0] <= {i_4B_val[8*26 +: 8],i_4B_val[8*24 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*27 +: 8],i_4B_val[8*25 +: 8]};
						end
						3'd7: begin 
							val_out1[15:0] <= {i_4B_val[8*30 +: 8],i_4B_val[8*28 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*31 +: 8],i_4B_val[8*29 +: 8]};
						end
					endcase
				end
				1:begin
					val_out_offset1 <= parse_act[12:6]+1'b1;//偶地址
					val_out_offset2 <= parse_act[12:6];//奇地址
					case(parse_act[4:2])
						3'd0: begin
							val_out1[15:0] <= {i_4B_val[8*3 +: 8],i_4B_val[8*1 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*2 +: 8],i_4B_val[8*0 +: 8]};
						end
						3'd1: begin
							val_out1[15:0] <= {i_4B_val[8*7 +: 8],i_4B_val[8*5 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*6 +: 8],i_4B_val[8*4 +: 8]};
						end
						3'd2: begin 
							val_out1[15:0] <= {i_4B_val[8*11 +: 8],i_4B_val[8*9 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*10 +: 8],i_4B_val[8*8 +: 8]};
						end
						3'd3: begin 
							val_out1[15:0] <= {i_4B_val[8*15 +: 8],i_4B_val[8*13 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*14 +: 8],i_4B_val[8*12 +: 8]};
						end
						3'd4: begin 
							val_out1[15:0] <= {i_4B_val[8*19 +: 8],i_4B_val[8*17 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*18 +: 8],i_4B_val[8*16 +: 8]};
						end
						3'd5: begin 
							val_out1[15:0] <= {i_4B_val[8*23 +: 8],i_4B_val[8*21 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*22 +: 8],i_4B_val[8*20 +: 8]};
						end
						3'd6: begin 
							val_out1[15:0] <= {i_4B_val[8*27 +: 8],i_4B_val[8*25 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*26 +: 8],i_4B_val[8*24 +: 8]};
						end
						3'd7: begin 
							val_out1[15:0] <= {i_4B_val[8*31 +: 8],i_4B_val[8*29 +: 8]};
							val_out2[15:0] <= {i_4B_val[8*30 +: 8],i_4B_val[8*28 +: 8]};
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