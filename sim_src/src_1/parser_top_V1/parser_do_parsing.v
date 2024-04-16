`timescale 1ns / 1ps

`define DEF_MAC_ADDR	48
`define DEF_VLAN		32
`define DEF_ETHTYPE		16

`define TYPE_IPV4		16'h0008
`define TYPE_ARP		16'h0608

`define PROT_ICMP		8'h01
`define PROT_TCP		8'h06
`define PROT_UDP		8'h11

`define SUB_PARSE(idx) \
	case(sub_parse_val_out_type[idx]) \
		2'b01: val_2B_nxt[sub_parse_val_out_seq[idx]] = sub_parse_val_out[idx][15:0]; \
		2'b10: val_4B_nxt[sub_parse_val_out_seq[idx]] = sub_parse_val_out[idx][31:0]; \
		2'b11: val_8B_nxt[sub_parse_val_out_seq[idx]] = sub_parse_val_out[idx][63:0]; \
	endcase \
 
// `define SWAP_BYTE_ORDER \
// 	assign val_8B_swapped = {	val_8B[0+:8], \
// 									val_8B[8+:8], \
// 									val_8B[16+:8], \
// 									val_8B[24+:8], \
// 									val_8B[32+:8], \
// 									val_8B[40+:8], \
// 									val_8B[48+:8], \
// 									val_8B[56+:8]}; \
// 	assign val_4B_swapped = {	val_4B[0+:8], \
// 									val_4B[8+:8], \
// 									val_4B[16+:8], \
// 									val_4B[24+:8]}; \
// 	assign val_2B_swapped = {	val_2B[0+:8], \
// 									val_2B[8+:8]}; \
//how about get a conflict when the parser action is used in the same val
//由于24条指令及对应的容器要组合成一个phv，所以该模块将前步骤提取的所有有效数据输入，最终输出phv
module parser_do_parsing #(
	parameter C_AXIS_DATA_WIDTH = 256,
	parameter C_AXIS_TUSER_WIDTH = 128,
	parameter PHV_WIDTH = (8+4+2)*8*8+100+256,
	parameter PKTS_LEN = 2048,
	parameter PARSER_MOD_ID = 3'd1,
	parameter C_NUM_SEGS = 8,
	parameter C_VLANID_WIDTH = 12,
	parameter DO_PARER_GROUP = 12

)
(
	input											axis_clk,
	input											aresetn,

	input [DO_PARER_GROUP-1:0] 						sub_parse_val_valid,
	input [64*DO_PARER_GROUP-1:0] 					sub_parse_val,
	input [2*DO_PARER_GROUP-1:0] 					sub_parse_val_type, 
	input [3*DO_PARER_GROUP-1:0]                    sub_parse_val_seq,
	//in parser bram addrb_out
	input [8:0] 									i_bram_parser_addrb,
	input 											i_bram_parser_valid,
	//
	input [C_VLANID_WIDTH-1 :0]                     i_vlan,
	input                                           i_vlan_valid,
	// input [C_NUM_SEGS*C_AXIS_DATA_WIDTH-1:0]		tdata_segs,
	input [C_AXIS_TUSER_WIDTH-1:0]					tuser_1st,
	input [1*DO_PARER_GROUP-1:0] 					i_sub_seg_valid,
	// input [319:0]									bram_out,


	input											i_stg_ready,
	// output

	// phv output
	output 		     								o_phv_valid,
	output     [PHV_WIDTH-1:0]					    o_phv,

	output reg   [C_VLANID_WIDTH-1:0]				out_vlan,
	output reg  									out_vlan_valid,
	input											out_vlan_ready

);

localparam			PARSE_ACT_LEN   =5'd16;
localparam			VAL_OUT_LEN     =7'd64;

localparam			IDLE        =0,
					SUB_PARSE_1 =1,
					SUB_PARSE_2 =2,
					SUB_PARSE_3 =3,
					SUB_PARSE_4 =4,
					SUB_PARSE_5 =5,
					GET_PHV_OUTPUT  =6,
					OUTPUT          =7;
					

//
reg [PHV_WIDTH-1:0]	o_phv_next;
reg o_phv_valid_next;
reg [3:0] state, state_next;
reg [C_VLANID_WIDTH-1:0]	out_vlan_next;
reg							out_vlan_valid_next;

// // parsing actions
// wire [15:0] parse_action [0:19];		// we have 10 parse action
// reg [3:0] sub_parse_act_valid;
reg [DO_PARER_GROUP-1:0] sub_parse_act_valid;
reg [63:0] sub_parse_val_out [0:DO_PARER_GROUP-1];
reg  sub_parse_val_out_valid [0:DO_PARER_GROUP-1];
reg [1:0] sub_parse_val_out_type [0:DO_PARER_GROUP-1];
reg [2:0] sub_parse_val_out_seq [0:DO_PARER_GROUP-1];

wire [8:0] bram_parser_addrb;
always @(posedge axis_clk) begin
	if(~aresetn)begin
		sub_parse_val_out_seq[0 ] <= 3'd0;
		sub_parse_val_out_seq[1 ] <= 3'd0;
		sub_parse_val_out_seq[2 ] <= 3'd0;
		sub_parse_val_out_seq[3 ] <= 3'd0;
		sub_parse_val_out_seq[4 ] <= 3'd0;
		sub_parse_val_out_seq[5 ] <= 3'd0;
		sub_parse_val_out_seq[6 ] <= 3'd0;
		sub_parse_val_out_seq[7 ] <= 3'd0;
		sub_parse_val_out_seq[8 ] <= 3'd0;
		sub_parse_val_out_seq[9 ] <= 3'd0;
		sub_parse_val_out_seq[10] <= 3'd0;
		sub_parse_val_out_seq[11] <= 3'd0;
	end
	else begin 
    	sub_parse_val_out_seq[0 ] <= sub_parse_val_seq[35:33];
    	sub_parse_val_out_seq[1 ] <= sub_parse_val_seq[32:30];
    	sub_parse_val_out_seq[2 ] <= sub_parse_val_seq[29:27];
    	sub_parse_val_out_seq[3 ] <= sub_parse_val_seq[26:24];
    	sub_parse_val_out_seq[4 ] <= sub_parse_val_seq[23:21];
    	sub_parse_val_out_seq[5 ] <= sub_parse_val_seq[20:18];
    	sub_parse_val_out_seq[6 ] <= sub_parse_val_seq[17:15];
    	sub_parse_val_out_seq[7 ] <= sub_parse_val_seq[14:12];
    	sub_parse_val_out_seq[8 ] <= sub_parse_val_seq[11:9 ];
    	sub_parse_val_out_seq[9 ] <= sub_parse_val_seq[8 :6 ];
    	sub_parse_val_out_seq[10] <= sub_parse_val_seq[5 :3 ];
    	sub_parse_val_out_seq[11] <= sub_parse_val_seq[2 :0 ];
	end
end

always @(posedge axis_clk) begin
	if(~aresetn) begin
		sub_parse_val_out[0 ] <= 64'd0;
		sub_parse_val_out[1 ] <= 64'd0;
		sub_parse_val_out[2 ] <= 64'd0;
		sub_parse_val_out[3 ] <= 64'd0;
		sub_parse_val_out[4 ] <= 64'd0;
		sub_parse_val_out[5 ] <= 64'd0;
		sub_parse_val_out[6 ] <= 64'd0;
		sub_parse_val_out[7 ] <= 64'd0;
		sub_parse_val_out[8 ] <= 64'd0;
		sub_parse_val_out[9 ] <= 64'd0;
		sub_parse_val_out[10] <= 64'd0;
		sub_parse_val_out[11] <= 64'd0;	
	end
	else begin
		sub_parse_val_out[0 ] <= sub_parse_val[767:704];
		sub_parse_val_out[1 ] <= sub_parse_val[703:640];
		sub_parse_val_out[2 ] <= sub_parse_val[639:576];
		sub_parse_val_out[3 ] <= sub_parse_val[575:512];
		sub_parse_val_out[4 ] <= sub_parse_val[511:448];
		sub_parse_val_out[5 ] <= sub_parse_val[447:384];
		sub_parse_val_out[6 ] <= sub_parse_val[383:320];
		sub_parse_val_out[7 ] <= sub_parse_val[319:256];
		sub_parse_val_out[8 ] <= sub_parse_val[255:192];
		sub_parse_val_out[9 ] <= sub_parse_val[191:128];
		sub_parse_val_out[10] <= sub_parse_val[127:64 ];
		sub_parse_val_out[11] <= sub_parse_val[63 :0  ];
	end
end

always @(posedge axis_clk) begin
	if(~aresetn) begin
		sub_parse_val_out_valid[0 ] <= 1'b0;
		sub_parse_val_out_valid[1 ] <= 1'b0;
		sub_parse_val_out_valid[2 ] <= 1'b0;
		sub_parse_val_out_valid[3 ] <= 1'b0;
		sub_parse_val_out_valid[4 ] <= 1'b0;
		sub_parse_val_out_valid[5 ] <= 1'b0;
		sub_parse_val_out_valid[6 ] <= 1'b0;
		sub_parse_val_out_valid[7 ] <= 1'b0;
		sub_parse_val_out_valid[8 ] <= 1'b0;
		sub_parse_val_out_valid[9 ] <= 1'b0;
		sub_parse_val_out_valid[10] <= 1'b0;
		sub_parse_val_out_valid[11] <= 1'b0;
	end
	else begin
		sub_parse_val_out_valid[0 ] <= sub_parse_val_valid[11];
		sub_parse_val_out_valid[1 ] <= sub_parse_val_valid[10];
		sub_parse_val_out_valid[2 ] <= sub_parse_val_valid[9 ];
		sub_parse_val_out_valid[3 ] <= sub_parse_val_valid[8 ];
		sub_parse_val_out_valid[4 ] <= sub_parse_val_valid[7 ];
		sub_parse_val_out_valid[5 ] <= sub_parse_val_valid[6 ];
		sub_parse_val_out_valid[6 ] <= sub_parse_val_valid[5 ];
		sub_parse_val_out_valid[7 ] <= sub_parse_val_valid[4 ];
		sub_parse_val_out_valid[8 ] <= sub_parse_val_valid[3 ];
		sub_parse_val_out_valid[9 ] <= sub_parse_val_valid[2 ];
		sub_parse_val_out_valid[10] <= sub_parse_val_valid[1 ];
		sub_parse_val_out_valid[11] <= sub_parse_val_valid[0 ];
	end
end

always @(posedge axis_clk) begin
	if(~aresetn) begin
		sub_parse_val_out_type[0 ] <= 2'd0;
		sub_parse_val_out_type[1 ] <= 2'd0;
		sub_parse_val_out_type[2 ] <= 2'd0;
		sub_parse_val_out_type[3 ] <= 2'd0;
		sub_parse_val_out_type[4 ] <= 2'd0;
		sub_parse_val_out_type[5 ] <= 2'd0;
		sub_parse_val_out_type[6 ] <= 2'd0;
		sub_parse_val_out_type[7 ] <= 2'd0;
		sub_parse_val_out_type[8 ] <= 2'd0;
		sub_parse_val_out_type[9 ] <= 2'd0;
		sub_parse_val_out_type[10] <= 2'd0;
		sub_parse_val_out_type[11] <= 2'd0;
	end
	else begin
		sub_parse_val_out_type[0 ] <= sub_parse_val_type[23:22];
		sub_parse_val_out_type[1 ] <= sub_parse_val_type[21:20];
		sub_parse_val_out_type[2 ] <= sub_parse_val_type[19:18];
		sub_parse_val_out_type[3 ] <= sub_parse_val_type[17:16];
		sub_parse_val_out_type[4 ] <= sub_parse_val_type[15:14];
		sub_parse_val_out_type[5 ] <= sub_parse_val_type[13:12];
		sub_parse_val_out_type[6 ] <= sub_parse_val_type[11:10];
		sub_parse_val_out_type[7 ] <= sub_parse_val_type[9 :8 ];
		sub_parse_val_out_type[8 ] <= sub_parse_val_type[7 :6 ];
		sub_parse_val_out_type[9 ] <= sub_parse_val_type[5 :4 ];
		sub_parse_val_out_type[10] <= sub_parse_val_type[3 :2 ];
		sub_parse_val_out_type[11] <= sub_parse_val_type[1 :0 ];
	end
end

reg [63:0] val_8B [0:7];
reg [31:0] val_4B [0:7];
reg [15:0] val_2B [0:7];
reg [63:0] val_8B_nxt [0:7];
reg [31:0] val_4B_nxt [0:7];
reg [15:0] val_2B_nxt [0:7];

// wire [63:0] val_8B_swapped [0:7];
// wire [31:0] val_4B_swapped [0:7];
// wire [15:0] val_2B_swapped [0:7];

// `SWAP_BYTE_ORDER
//get the val with o_parser_act_low_valid
always @(*) begin
	state_next = state;
	//
	o_phv_valid_next = 0;
	o_phv_next       = o_phv;
	//
	out_vlan_next       = out_vlan;
	out_vlan_valid_next = out_vlan_valid;
	//
	val_2B_nxt[0] = val_2B[0];
	val_2B_nxt[1] = val_2B[1];
	val_2B_nxt[2] = val_2B[2];
	val_2B_nxt[3] = val_2B[3];
	val_2B_nxt[4] = val_2B[4];
	val_2B_nxt[5] = val_2B[5];
	val_2B_nxt[6] = val_2B[6];
	val_2B_nxt[7] = val_2B[7];
	val_4B_nxt[0] = val_4B[0];
	val_4B_nxt[1] = val_4B[1];
	val_4B_nxt[2] = val_4B[2];
	val_4B_nxt[3] = val_4B[3];
	val_4B_nxt[4] = val_4B[4];
	val_4B_nxt[5] = val_4B[5];
	val_4B_nxt[6] = val_4B[6];
	val_4B_nxt[7] = val_4B[7];
	val_8B_nxt[0] = val_8B[0];
	val_8B_nxt[1] = val_8B[1];
	val_8B_nxt[2] = val_8B[2];
	val_8B_nxt[3] = val_8B[3];
	val_8B_nxt[4] = val_8B[4];
	val_8B_nxt[5] = val_8B[5];
	val_8B_nxt[6] = val_8B[6];
	val_8B_nxt[7] = val_8B[7];
	//
	sub_parse_act_valid = 12'd0;
	//

	case (state)
		IDLE: begin
			if (i_sub_seg_valid == 12'hfff) begin
				if (out_vlan_ready && i_vlan_valid) begin
					out_vlan_valid_next = 1'b1;
					out_vlan_next = i_vlan;
				end
				else begin
					out_vlan_valid_next = 1'b0;
					out_vlan_next = 12'd0;
				end
				state_next = SUB_PARSE_1;
			end
			else begin
				state_next = IDLE;
				out_vlan_valid_next = 1'b0;
				out_vlan_next = 12'd0;
			end
		end

		SUB_PARSE_1: begin
			`SUB_PARSE(0 )
			`SUB_PARSE(1 )
			`SUB_PARSE(2 )
			`SUB_PARSE(3 )
			`SUB_PARSE(4 )
			`SUB_PARSE(5 )
			`SUB_PARSE(6 )
			`SUB_PARSE(7 )
			`SUB_PARSE(8 )
			`SUB_PARSE(9 )
			`SUB_PARSE(10)
			`SUB_PARSE(11)
			sub_parse_act_valid = 12'hfff;
			state_next = SUB_PARSE_2;
		end

		SUB_PARSE_2: begin
			state_next = GET_PHV_OUTPUT;

			`SUB_PARSE(0 )
			`SUB_PARSE(1 )
			`SUB_PARSE(2 )
			`SUB_PARSE(3 )
			`SUB_PARSE(4 )
			`SUB_PARSE(5 )
			`SUB_PARSE(6 )
			`SUB_PARSE(7 )
			`SUB_PARSE(8 )
			`SUB_PARSE(9 )
			`SUB_PARSE(10)
			`SUB_PARSE(11)
			sub_parse_act_valid = 12'hfff;
	
		end

		GET_PHV_OUTPUT: begin
			if(i_stg_ready) begin
				state_next = IDLE;
				// o_phv_next ={val_8B_swapped[7], val_8B_swapped[6], val_8B_swapped[5], val_8B_swapped[4], val_8B_swapped[3], val_8B_swapped[2], val_8B_swapped[1], val_8B_swapped[0],
				// 				val_4B_swapped[7], val_4B_swapped[6], val_4B_swapped[5], val_4B_swapped[4], val_4B_swapped[3], val_4B_swapped[2], val_4B_swapped[1], val_4B_swapped[0],
				// 				val_2B_swapped[7], val_2B_swapped[6], val_2B_swapped[5], val_2B_swapped[4], val_2B_swapped[3], val_2B_swapped[2], val_2B_swapped[1], val_2B_swapped[0],
				// 				// Tao: manually set output port to 1 for eazy test
				// 				// {115{1'b0}}, vlan_id, 1'b0, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
				// 				{115{1'b0}}, out_vlan, 1'b0, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
				// 				// {115{1'b0}}, vlan_id, 1'b0, tuser_1st};
				// 				// {128{1'b0}}, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
				o_phv_valid_next = 1'b1;
				// o_phv_next ={val_8B[7], val_8B[6], val_8B[5], val_8B[4], val_8B[3], val_8B[2], val_8B[1], val_8B[0],
				// 			 val_4B[7], val_4B[6], val_4B[5], val_4B[4], val_4B[3], val_4B[2], val_4B[1], val_4B[0],
				// 			 val_2B[7], val_2B[6], val_2B[5], val_2B[4], val_2B[3], val_2B[2], val_2B[1], val_2B[0],
				// 				// Tao: manually set output port to 1 for eazy test
				// 				// {115{1'b0}}, vlan_id, 1'b0, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
				// 				{100{1'b0}},{116{1'b0}}, out_vlan, 1'b0, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
				o_phv_next ={val_8B[7], val_8B[6], val_8B[5], val_8B[4], val_8B[3], val_8B[2], val_8B[1], val_8B[0],
							 val_4B[7], val_4B[6], val_4B[5], val_4B[4], val_4B[3], val_4B[2], val_4B[1], val_4B[0],
							 val_2B[7], val_2B[6], val_2B[5], val_2B[4], val_2B[3], val_2B[2], val_2B[1], val_2B[0],
								// Tao: manually set output port to 1 for eazy test
								// {115{1'b0}}, vlan_id, 1'b0, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
								{100{1'b0}},{118{1'b0}}, bram_parser_addrb, 1'b0, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
								// {115{1'b0}}, vlan_id, 1'b0, tuser_1st};
								// {128{1'b0}}, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
				// zero out
				val_2B_nxt[0]=0;
				val_2B_nxt[1]=0;
				val_2B_nxt[2]=0;
				val_2B_nxt[3]=0;
				val_2B_nxt[4]=0;
				val_2B_nxt[5]=0;
				val_2B_nxt[6]=0;
				val_2B_nxt[7]=0;
				val_4B_nxt[0]=0;
				val_4B_nxt[1]=0;
				val_4B_nxt[2]=0;
				val_4B_nxt[3]=0;
				val_4B_nxt[4]=0;
				val_4B_nxt[5]=0;
				val_4B_nxt[6]=0;
				val_4B_nxt[7]=0;
				val_8B_nxt[0]=0;
				val_8B_nxt[1]=0;
				val_8B_nxt[2]=0;
				val_8B_nxt[3]=0;
				val_8B_nxt[4]=0;
				val_8B_nxt[5]=0;
				val_8B_nxt[6]=0;
				val_8B_nxt[7]=0;
			end
			else begin
				state_next = GET_PHV_OUTPUT;
			end
		end
		// OUTPUT: begin
		// 	if (i_stg_ready) begin
		
		// 		state_next = IDLE;
				
				
		// 	end
		// end
	endcase
end
reg [PHV_WIDTH-1:0] r_phv      ;
reg                 r_phv_valid;
always @(posedge axis_clk) begin
	if (~aresetn) begin
		state <= IDLE;
		//
		r_phv <= 0;
		r_phv_valid <= 0;
		//
		out_vlan <= 0;
		out_vlan_valid <= 0;
		//
		val_2B[0] <= 0;
		val_2B[1] <= 0;
		val_2B[2] <= 0;
		val_2B[3] <= 0;
		val_2B[4] <= 0;
		val_2B[5] <= 0;
		val_2B[6] <= 0;
		val_2B[7] <= 0;
		val_4B[0] <= 0;
		val_4B[1] <= 0;
		val_4B[2] <= 0;
		val_4B[3] <= 0;
		val_4B[4] <= 0;
		val_4B[5] <= 0;
		val_4B[6] <= 0;
		val_4B[7] <= 0;
		val_8B[0] <= 0;
		val_8B[1] <= 0;
		val_8B[2] <= 0;
		val_8B[3] <= 0;
		val_8B[4] <= 0;
		val_8B[5] <= 0;
		val_8B[6] <= 0;
		val_8B[7] <= 0;
	end
	else begin
		state <= state_next;
		//
		r_phv <= o_phv_next;
		r_phv_valid <= o_phv_valid_next;
		//
		out_vlan <= out_vlan_next;
		out_vlan_valid <= out_vlan_valid_next;
		//
		val_2B[0] <= val_2B_nxt[0];
		val_2B[1] <= val_2B_nxt[1];
		val_2B[2] <= val_2B_nxt[2];
		val_2B[3] <= val_2B_nxt[3];
		val_2B[4] <= val_2B_nxt[4];
		val_2B[5] <= val_2B_nxt[5];
		val_2B[6] <= val_2B_nxt[6];
		val_2B[7] <= val_2B_nxt[7];
		val_4B[0] <= val_4B_nxt[0];
		val_4B[1] <= val_4B_nxt[1];
		val_4B[2] <= val_4B_nxt[2];
		val_4B[3] <= val_4B_nxt[3];
		val_4B[4] <= val_4B_nxt[4];
		val_4B[5] <= val_4B_nxt[5];
		val_4B[6] <= val_4B_nxt[6];
		val_4B[7] <= val_4B_nxt[7];
		val_8B[0] <= val_8B_nxt[0];
		val_8B[1] <= val_8B_nxt[1];
		val_8B[2] <= val_8B_nxt[2];
		val_8B[3] <= val_8B_nxt[3];
		val_8B[4] <= val_8B_nxt[4];
		val_8B[5] <= val_8B_nxt[5];
		val_8B[6] <= val_8B_nxt[6];
		val_8B[7] <= val_8B_nxt[7];
	end
end
assign o_phv = {r_phv[1251:356],100'd0,118'd0,bram_parser_addrb,r_phv[128:0]};
assign o_phv_valid = r_phv_valid;


// fallthrough_small_fifo #(
// 	.WIDTH(9),
// 	.MAX_DEPTH_BITS(512)
// )
// parser_addrb_fifo
// (
// 	.din									(i_bram_parser_addrb),
// 	.wr_en									(i_bram_parser_valid),
// 	.rd_en									(o_phv_valid_next),
// 	.dout									(bram_parser_addrb),
// 	.full									(),
// 	.prog_full								(),
// 	.nearly_full							(pkt_fifo_nearly_full),
// 	.empty									(pkt_fifo_empty),
// 	.reset									(~aresetn),
// 	.clk									(axis_clk)
// );

//----------- Begin Cut here for INSTANTIATION Template ---// INST_TAG
parser_addrb_fifo parser_addrb_fifo (
  .clk         (axis_clk           ),           // input wire clk
  .srst        (~aresetn           ),           // input wire srst
  .din         (i_bram_parser_addrb),           // input wire [8 : 0] din
  .wr_en       (i_bram_parser_valid),           // input wire wr_en
  .rd_en       (o_phv_valid_next   ),           // input wire rd_en
  .dout        (bram_parser_addrb  ),           // output wire [8 : 0] dout
  .full        (                   ),           // output wire full
  .almost_full (                   ),           // output wire almost_full
  .empty       (                   ),           // output wire empty
  .almost_empty(                   )            // output wire almost_empty
);
// INST_TAG_END ------ End INSTANTIATION Template ---------

endmodule
