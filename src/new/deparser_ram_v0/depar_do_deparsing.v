`timescale 1ns / 1ps

// `define SUB_DEPARSE_1P(idx) \
// 	if(parse_action[idx][0]) begin \
// 		case(sub_val_out_type[idx]) \
// 			2'b01: pkts_tdata_stored_1p_next[parse_action_ind_10b[idx]<<3 +: 16] = sub_val_out_swapped[idx][32+:16]; \
// 			2'b10: pkts_tdata_stored_1p_next[parse_action_ind_10b[idx]<<3 +: 32] = sub_val_out_swapped[idx][16+:32]; \
// 			2'b11: pkts_tdata_stored_1p_next[parse_action_ind_10b[idx]<<3 +: 63] = sub_val_out_swapped[idx][0+:63]; \
// 		endcase \
// 	end \

// `define SUB_DEPARSE_2P(idx) \
// 	if(parse_action[idx][0]) begin \
// 		case(sub_val_out_type[idx]) \
// 			2'b01: pkts_tdata_stored_2p_next[parse_action_ind_10b[idx]<<3 +: 16] = sub_val_out_swapped[idx][32+:16]; \
// 			2'b10: pkts_tdata_stored_2p_next[parse_action_ind_10b[idx]<<3 +: 32] = sub_val_out_swapped[idx][16+:32]; \
// 			2'b11: pkts_tdata_stored_2p_next[parse_action_ind_10b[idx]<<3 +: 63] = sub_val_out_swapped[idx][0+:63]; \
// 		endcase \
// 	end \

`define SWAP_BYTE_ORDER(idx) \
	assign sub_val_out_swapped[idx] = {	sub_val_out[idx][0+:8], \
												sub_val_out[idx][8+:8], \
												sub_val_out[idx][16+:8], \
												sub_val_out[idx][24+:8], \
												sub_val_out[idx][32+:8], \
												sub_val_out[idx][40+:8], \
												sub_val_out[idx][48+:8], \
												sub_val_out[idx][56+:8]}; \

//1.通过wait模块的vlan，查找deparser指令表，得到deparser指令。
//2.sub_deparser取经过parser的phv和deparser指令，初步将phv分解成容器val和对应的指令val_act。
//3.ram将来自wait模块的整个2048bit数据存成256个8b寄存器形式，并取sub_deparser模块分解的val和val_act，将val数据按照val_act的指令，按8b放回2048bit数据中。
//4.flush将2048b数据按256bit输出。
//以上几个功能并行
//此次架构修改，只是在sub_deparser模块中间加了个ram模块，另外将数据放回固定成0-7是2B，8-15是4B，16-23是8B
//每条指令可以在2048b中灵活放回数据
//将原来需要逆解析完成才读入新的数据状态逻辑改为2048b解析完就可以进入新的数据逻辑
//如果指令本身就对应0-7是2B，8-15是4B，16-23是8B的规律，是否能满足最初架构修改，否，最初架构只是调整了查询字段

module depar_do_deparsing #(
	parameter	C_AXIS_DATA_WIDTH = 256,
	parameter	C_AXIS_TUSER_WIDTH = 128,
	parameter	C_PKT_VEC_WIDTH = (8+4+2)*8*8+100+256,
	parameter	DEPARSER_MOD_ID = 3'b101,
	parameter	C_NUM_SEGS = 8,
	parameter	C_VLANID_WIDTH = 12,
	parameter   C_PARSER_RAM_WIDTH = 384
)
(
	input													clk,
	input													aresetn,

	// phv
	input [C_PKT_VEC_WIDTH-1:0]								phv_fifo_out,
	input													phv_fifo_empty,
	output reg												phv_fifo_rd_en,

	//
	input [C_VLANID_WIDTH-1:0]								vlan_id,
	input													vlan_fifo_empty,
	output reg												vlan_fifo_rd_en,
	// 
	// input [C_AXIS_DATA_WIDTH*C_NUM_SEGS/2-1:0]				fst_half_fifo_tdata,
	input [C_AXIS_DATA_WIDTH-1:0]				            fst_half_fifo_tdata1,
	input [C_AXIS_DATA_WIDTH-1:0]				            fst_half_fifo_tdata2,
	input [C_AXIS_DATA_WIDTH-1:0]				            fst_half_fifo_tdata3,
	input [C_AXIS_DATA_WIDTH-1:0]				            fst_half_fifo_tdata4,
	input [C_AXIS_TUSER_WIDTH*C_NUM_SEGS/2-1:0]				fst_half_fifo_tuser,
	input [C_AXIS_DATA_WIDTH/8*C_NUM_SEGS/2-1:0]			fst_half_fifo_tkeep,
	input [C_NUM_SEGS/2-1:0]								fst_half_fifo_tlast,
	input													fst_half_fifo_empty,
	output reg												fst_half_fifo_rd_en,
	// 
	input 													snd_half_fifo_valid_in,
	input [C_AXIS_DATA_WIDTH-1:0]				            snd_half_fifo_tdata1,
	input [C_AXIS_DATA_WIDTH-1:0]				            snd_half_fifo_tdata2,
	input [C_AXIS_DATA_WIDTH-1:0]				            snd_half_fifo_tdata3,
	input [C_AXIS_DATA_WIDTH-1:0]				            snd_half_fifo_tdata4,
	input [C_AXIS_TUSER_WIDTH*C_NUM_SEGS/2-1:0]				snd_half_fifo_tuser,
	input [C_AXIS_DATA_WIDTH/8*C_NUM_SEGS/2-1:0]			snd_half_fifo_tkeep,
	input [C_NUM_SEGS/2-1:0]								snd_half_fifo_tlast,
	input													snd_half_fifo_empty,
	output reg												snd_half_fifo_rd_en,
	output reg                                              o_tuser_fifo_rd_en,
	//
	input [C_AXIS_DATA_WIDTH-1:0]							pkt_fifo_tdata,
	input [C_AXIS_TUSER_WIDTH-1:0]							pkt_fifo_tuser,
	input [C_AXIS_DATA_WIDTH/8-1:0]							pkt_fifo_tkeep,
	input													pkt_fifo_tlast,
	input													pkt_fifo_empty,
	output reg												pkt_fifo_rd_en,//读余下字段

	// output
	output reg [C_AXIS_DATA_WIDTH-1:0]						depar_out_tdata ,
	output reg [C_AXIS_DATA_WIDTH/8-1:0]					depar_out_tkeep ,
	output reg [C_AXIS_TUSER_WIDTH-1:0]						depar_out_tuser ,
	output reg												depar_out_tvalid,
	output reg												depar_out_tlast ,
	input													depar_out_tready,

	// control path
	input [C_AXIS_DATA_WIDTH-1:0]							ctrl_s_axis_tdata,
	input [C_AXIS_TUSER_WIDTH-1:0]							ctrl_s_axis_tuser,
	input [C_AXIS_DATA_WIDTH/8-1:0]							ctrl_s_axis_tkeep,
	input													ctrl_s_axis_tvalid,
	input													ctrl_s_axis_tlast
);

wire [383:0]                bram_out;
reg	 [23:0]					sub_depar_act_valid;
wire [7:0]                  val2B_o_ready;
// wire [15:0]					sub_val2B_o [0:7];
wire [7:0]					sub_val2B1_o [0:7];
wire [7:0]					sub_val2B2_o [0:7];
// wire [63:0]					sub_val_out_swapped [0:7];
wire [1:0]					sub_val2B_o_type [0:7];
wire [7:0]					sub_val2B_o_valid;
wire [7:0]                  sub_val2B_o_end;
wire [7:0]                  sub_val2B_o_offset1[0:7];
wire [7:0]                  sub_val2B_o_offset2[0:7];

wire [7:0]                  val4B_o_ready;
wire [15:0]					sub_val4B1_o [0:7];
wire [15:0]					sub_val4B2_o [0:7];
// wire [63:0]					sub_val_out_swapped [0:7];
wire [1:0]					sub_val4B_o_type [0:7];
wire [7:0]					sub_val4B_o_valid;
wire [7:0]                  sub_val4B_o_end;
wire [7:0]                  sub_val4B_o_offset1[0:7];
wire [7:0]                  sub_val4B_o_offset2[0:7];

wire [7:0]                  val8B_o_ready;
// wire [63:0]					sub_val8B_o [0:7];
wire [31:0]					sub_val8B1_o [0:7];
wire [31:0]					sub_val8B2_o [0:7];
// wire [63:0]					sub_val_out_swapped [0:7];
wire [1:0]					sub_val8B_o_type [0:7];
wire [7:0]					sub_val8B_o_valid;
wire [7:0]                  sub_val8B_o_end;
wire [7:0]                  sub_val8B_o_offset1[0:7];
wire [7:0]                  sub_val8B_o_offset2[0:7];


wire   w_pkt_data_valid,w_pkt_data_valid1,w_pkt_data_valid2;
wire   w_pkt_data_valid3,w_pkt_data_valid4,w_pkt_data_valid5;
wire   w_fifo_data_valid; //切换fifo的数据
reg    r_fifo_data_valid;
assign w_fifo_data_valid = (~fst_half_fifo_empty && ~snd_half_fifo_empty);
wire   bram_out_valid   ;
deparser_bram_cfg#(
	.C_AXIS_DATA_WIDTH (C_AXIS_DATA_WIDTH ),
	.C_AXIS_TUSER_WIDTH(C_AXIS_TUSER_WIDTH),
	.DEPARSER_MOD_ID   (DEPARSER_MOD_ID   ),
	.C_PARSER_RAM_WIDTH(C_PARSER_RAM_WIDTH)
) 
deparser_bram_cfg(
	.axis_clk			(clk	),
	.aresetn			(aresetn),

	.i_deparser_addrb	(phv_fifo_out[137:129]),
	.i_phv_fifo_empty_n (!phv_fifo_empty      ),
	.ctrl_s_axis_tdata	(ctrl_s_axis_tdata    ),
	.ctrl_s_axis_tuser	(ctrl_s_axis_tuser    ),
	.ctrl_s_axis_tkeep	(ctrl_s_axis_tkeep    ),
	.ctrl_s_axis_tvalid	(ctrl_s_axis_tvalid   ),
	.ctrl_s_axis_tlast	(ctrl_s_axis_tlast    ),

	.bram_out			(bram_out             ),
	.o_bram_out_valid   (bram_out_valid       )
);
wire [15:0] parse_action_2B [0:7];		// we have 10 parse action
wire [15:0] parse_action_4B [0:7];		// we have 10 parse action
wire [15:0] parse_action_8B [0:7];		// we have 10 parse action

assign parse_action_8B[ 7] = bram_out[0+:16];
assign parse_action_8B[ 6] = bram_out[16+:16];
assign parse_action_8B[ 5] = bram_out[32+:16];
assign parse_action_8B[ 4] = bram_out[48+:16];
assign parse_action_8B[ 3] = bram_out[64+:16];
assign parse_action_8B[ 2] = bram_out[80+:16];
assign parse_action_8B[ 1] = bram_out[96+:16];
assign parse_action_8B[ 0] = bram_out[112+:16];
assign parse_action_4B[ 7] = bram_out[128+:16];
assign parse_action_4B[ 6] = bram_out[144+:16];
assign parse_action_4B[ 5] = bram_out[160+:16];
assign parse_action_4B[ 4] = bram_out[176+:16];
assign parse_action_4B[ 3] = bram_out[192+:16];
assign parse_action_4B[ 2] = bram_out[208+:16];
assign parse_action_4B[ 1] = bram_out[224+:16];
assign parse_action_4B[ 0] = bram_out[240+:16];
assign parse_action_2B[ 7] = bram_out[256+:16];
assign parse_action_2B[ 6] = bram_out[272+:16];
assign parse_action_2B[ 5] = bram_out[288+:16];
assign parse_action_2B[ 4] = bram_out[304+:16];
assign parse_action_2B[ 3] = bram_out[320+:16];
assign parse_action_2B[ 2] = bram_out[336+:16];
assign parse_action_2B[ 1] = bram_out[352+:16];
assign parse_action_2B[ 0] = bram_out[368+:16];


//===================== sub deparser===========================
generate
	genvar index;
	for (index=0; index<8; index=index+1) 
	begin: sub_op
		sub_deparser_2B #(
			.C_PKT_VEC_WIDTH(),
			.C_PARSE_ACT_LEN()
		)
		sub_deparser_2B (
			.clk				(clk),
			.aresetn			(aresetn),
			.parse_act_srt	    (bram_out_valid        ),
			.parse_act			(parse_action_2B[index]),
			.i_8B_val			(phv_fifo_out[1251:740]),
			.i_4B_val			(phv_fifo_out[739:484]),
			.i_2B_val			(phv_fifo_out[483:356]),
			.val_out_valid		(sub_val2B_o_valid[index]),
			.val_out1			(sub_val2B1_o[index]),//偶数
			.val_out2           (sub_val2B2_o[index]),//奇数
			.val_out_type		(sub_val2B_o_type[index]),
			.val_out_offset1    (sub_val2B_o_offset1[index]),//偶数
			.val_out_offset2    (sub_val2B_o_offset2[index]),//奇数
			.val_out_end        (sub_val2B_o_end[index]),
			.val_out_ready      (val2B_o_ready[index])
		);

		sub_deparser_4B #(
			.C_PKT_VEC_WIDTH(),
			.C_PARSE_ACT_LEN()
		)
		sub_deparser_4B (
			.clk				(clk),
			.aresetn			(aresetn),
			.parse_act_srt	    (bram_out_valid        ),
			.parse_act			(parse_action_4B[index]),
			.i_8B_val			(phv_fifo_out[1251:740]),
			.i_4B_val			(phv_fifo_out[739:484]),
			.i_2B_val			(phv_fifo_out[483:356]),
			.val_out_valid		(sub_val4B_o_valid[index]),
			.val_out1			(sub_val4B1_o[index]),
			.val_out2			(sub_val4B2_o[index]),
			.val_out_type		(sub_val4B_o_type[index]),
			.val_out_offset1    (sub_val4B_o_offset1[index]),
			.val_out_offset2    (sub_val4B_o_offset2[index]),
			.val_out_end        (sub_val4B_o_end[index]),
			.val_out_ready      (val4B_o_ready[index])
		);

		sub_deparser_8B #(
			.C_PKT_VEC_WIDTH(),
			.C_PARSE_ACT_LEN()
		)
		sub_deparser_8B (
			.clk				(clk),
			.aresetn			(aresetn),
			.parse_act_srt	    (bram_out_valid        ),
			.parse_act			(parse_action_8B[index]),
			.i_8B_val			(phv_fifo_out[1251:740]),
			.i_4B_val			(phv_fifo_out[739:484]),
			.i_2B_val			(phv_fifo_out[483:356]),
			.val_out_valid		(sub_val8B_o_valid[index]),
			// .val_out			(sub_val8B_o[index]),
			.val_out1			(sub_val8B1_o[index]),
			.val_out2			(sub_val8B2_o[index]),
			.val_out_type		(sub_val8B_o_type[index]),
			// .val_out_offset     (sub_val8B_o_offset[index]),
			.val_out_offset1    (sub_val8B_o_offset1[index]),
			.val_out_offset2    (sub_val8B_o_offset2[index]),
			.val_out_end        (sub_val8B_o_end[index]),
			.val_out_ready      (val8B_o_ready[index])
		);

	end
endgenerate
//=============================================================
//当有vlan时候，得到deparser指令
always @(posedge clk) begin
	if(~aresetn)begin
		vlan_fifo_rd_en <= 1'b0;	
	end
	else begin
		if (!vlan_fifo_empty)//在wait进入新一包报文的时候它非空
			vlan_fifo_rd_en <= 1'b1;
		else
			vlan_fifo_rd_en <= 1'b0;
	end
end

//在phv不空的时候，将数据得到bram_out，一直到解析出sub_val2B,最后再更换数据
always @(posedge clk) begin
	if(~aresetn)begin
		phv_fifo_rd_en <= 1'b0;
		sub_depar_act_valid <= 24'h0;
	end
	else begin
		if (!phv_fifo_empty && sub_val2B_o_end == 8'hff) begin //当phv_fifo不空且该信号sub_val在空闲状态时候，取新一包的数据
		
			phv_fifo_rd_en <= 1;
		    sub_depar_act_valid <= 24'hffffff;//启动容器指令匹配,该信号仅一拍，如果是积累下的连续两拍呢？
		end
		else begin
			phv_fifo_rd_en <= 0;
		    sub_depar_act_valid <= 24'd0;
		end
	end
end

//得到逆解析模块所需所有数据
reg [1:0] rd_pkt_state;
localparam RD_PKT_IDLE = 0,
		   SUB_VAL_END = 1,
           RD_PKT      = 2;

always @(posedge clk) begin
	if(~aresetn)begin
		fst_half_fifo_rd_en <= 1'b0;
		snd_half_fifo_rd_en <= 1'b0;
		rd_pkt_state <= RD_PKT_IDLE;
	end
	else begin
		case(rd_pkt_state) 
			RD_PKT_IDLE:begin
				fst_half_fifo_rd_en <= 1'd0;
				snd_half_fifo_rd_en <= 1'd0;
				if (phv_fifo_rd_en) begin //fifo不空，数据报文写入fifo了
					rd_pkt_state <= SUB_VAL_END;
				end
				else begin
					rd_pkt_state <= RD_PKT_IDLE;
				end
			end
			SUB_VAL_END:begin
				if(val2B_o_ready == 8'hff) begin
					rd_pkt_state <= RD_PKT;
				end
				else begin
					rd_pkt_state <= SUB_VAL_END;
				end
			end
			RD_PKT:begin
					fst_half_fifo_rd_en <= 1'b1;
			    	snd_half_fifo_rd_en <= 1'b1;
					rd_pkt_state <= RD_PKT_IDLE;
			end
		endcase
	end
end
wire w_reg_end; //该信号在数据逆解析出来的前一拍出，用于指示启动数据输出状态机
// reg [63:0 ] r_sub_val0;//2B
// reg [127:0] r_sub_val1;//4B+8B
// reg [255:0] r_sub_val2;//4B+8B
// reg [63:0 ] r_sub_val3;//2B
// reg [127:0] r_sub_val4;//4B+8B
// reg [255:0] r_sub_val5;//4B+8B

reg [7:0] r_sub_val0_type;
reg [7:0] r_sub_val1_type;
reg [7:0] r_sub_val2_type;
reg [7:0] r_sub_val3_type;
reg [7:0] r_sub_val4_type;
reg [7:0] r_sub_val5_type;

// reg [31:0] r_sub_val_offset0;
// reg [31:0] r_sub_val_offset1;
// reg [31:0] r_sub_val_offset2;
// reg [31:0] r_sub_val_offset3;
// reg [31:0] r_sub_val_offset4;
// reg [31:0] r_sub_val_offset5;

reg [3:0] r_sub_val_out_valid0;
reg [3:0] r_sub_val_out_valid1;
reg [3:0] r_sub_val_out_valid2;
reg [3:0] r_sub_val_out_valid3;
reg [3:0] r_sub_val_out_valid4;
reg [3:0] r_sub_val_out_valid5;

reg [3:0] r_sub_val_out_end0;
reg [3:0] r_sub_val_out_end1;
reg [3:0] r_sub_val_out_end2;
reg [3:0] r_sub_val_out_end3;
reg [3:0] r_sub_val_out_end4;
reg [3:0] r_sub_val_out_end5;

reg [31 :0] r_sub_val0_odd  ;
reg [31 :0] r_sub_val0_even ;
reg [31 :0] r_sub_val3_odd  ;
reg [31 :0] r_sub_val3_even ;
reg [63 :0] r_sub_val1_odd  ;
reg [63 :0] r_sub_val1_even ;
reg [63 :0] r_sub_val4_odd  ;
reg [63 :0] r_sub_val4_even ;
reg [127:0] r_sub_val2_odd  ;
reg [127:0] r_sub_val2_even ;
reg [127:0] r_sub_val5_odd  ;
reg [127:0] r_sub_val5_even ;

always @(posedge clk) begin
    if(~aresetn) begin
        r_sub_val0_odd    <= 0;
		r_sub_val0_even   <= 0;
        r_sub_val1_odd    <= 0;
		r_sub_val1_even   <= 0;
        // r_sub_val2        <= 0;
		r_sub_val2_odd    <= 0;
		r_sub_val2_even   <= 0;
        r_sub_val3_odd    <= 0;
		r_sub_val3_even   <= 0;
        r_sub_val4_odd    <= 0;
		r_sub_val4_even   <= 0;
        // r_sub_val5        <= 0;
		r_sub_val5_odd    <= 0;
		r_sub_val5_even   <= 0;
    end
    else begin
        r_sub_val0_odd    <= {sub_val2B2_o[0],sub_val2B2_o[1],sub_val2B2_o[2],sub_val2B2_o[3]}; //2B
		r_sub_val0_even   <= {sub_val2B1_o[0],sub_val2B1_o[1],sub_val2B1_o[2],sub_val2B1_o[3]}; //2B
        r_sub_val1_odd    <= {sub_val4B2_o[0],sub_val4B2_o[1],sub_val4B2_o[2],sub_val4B2_o[3]}; //4B
		r_sub_val1_even   <= {sub_val4B1_o[0],sub_val4B1_o[1],sub_val4B1_o[2],sub_val4B1_o[3]}; //4B
        // r_sub_val2        <= {sub_val8B_o[0],sub_val8B_o[1],sub_val8B_o[2],sub_val8B_o[3]}; //8B
		r_sub_val2_odd    <= {sub_val8B2_o[0],sub_val8B2_o[1],sub_val8B2_o[2],sub_val8B2_o[3]}; //8B
		r_sub_val2_even   <= {sub_val8B1_o[0],sub_val8B1_o[1],sub_val8B1_o[2],sub_val8B1_o[3]}; //8B
        r_sub_val3_odd    <= {sub_val2B2_o[4],sub_val2B2_o[5],sub_val2B2_o[6],sub_val2B2_o[7]};
		r_sub_val3_even   <= {sub_val2B1_o[4],sub_val2B1_o[5],sub_val2B1_o[6],sub_val2B1_o[7]};
        r_sub_val4_odd    <= {sub_val4B2_o[4],sub_val4B2_o[5],sub_val4B2_o[6],sub_val4B2_o[7]};
		r_sub_val4_even   <= {sub_val4B1_o[4],sub_val4B1_o[5],sub_val4B1_o[6],sub_val4B1_o[7]};
        // r_sub_val5        <= {sub_val8B_o[4],sub_val8B_o[5],sub_val8B_o[6],sub_val8B_o[7]};
		r_sub_val5_odd    <= {sub_val8B2_o[4],sub_val8B2_o[5],sub_val8B2_o[6],sub_val8B2_o[7]};
		r_sub_val5_even   <= {sub_val8B1_o[4],sub_val8B1_o[5],sub_val8B1_o[6],sub_val8B1_o[7]};
    end
end

always @(posedge clk) begin
    if(~aresetn) begin
        r_sub_val0_type   <= 0;
        r_sub_val1_type   <= 0;
        r_sub_val2_type   <= 0;
        r_sub_val3_type   <= 0;
        r_sub_val4_type   <= 0;
        r_sub_val5_type   <= 0;
    end
    else begin
        r_sub_val0_type   <= {sub_val2B_o_type[0],sub_val2B_o_type[1],sub_val2B_o_type[2],sub_val2B_o_type[3]};
        r_sub_val1_type   <= {sub_val4B_o_type[0],sub_val4B_o_type[1],sub_val4B_o_type[2],sub_val4B_o_type[3]};
        r_sub_val2_type   <= {sub_val8B_o_type[0],sub_val8B_o_type[1],sub_val8B_o_type[2],sub_val8B_o_type[3]};
        r_sub_val3_type   <= {sub_val2B_o_type[4],sub_val2B_o_type[5],sub_val2B_o_type[6],sub_val2B_o_type[7]};
        r_sub_val4_type   <= {sub_val4B_o_type[4],sub_val4B_o_type[5],sub_val4B_o_type[6],sub_val4B_o_type[7]};
        r_sub_val5_type   <= {sub_val8B_o_type[4],sub_val8B_o_type[5],sub_val8B_o_type[6],sub_val8B_o_type[7]};
    end
end

reg [31:0] r_sub_val_offset0_odd;
reg [31:0] r_sub_val_offset0_even;
reg [31:0] r_sub_val_offset3_odd;
reg [31:0] r_sub_val_offset3_even;
reg [31:0] r_sub_val_offset1_odd;
reg [31:0] r_sub_val_offset1_even;
reg [31:0] r_sub_val_offset4_odd;
reg [31:0] r_sub_val_offset4_even;
reg [31:0] r_sub_val_offset2_odd;
reg [31:0] r_sub_val_offset2_even;
reg [31:0] r_sub_val_offset5_odd;
reg [31:0] r_sub_val_offset5_even;
always @(posedge clk)begin
    if(~aresetn) begin
        r_sub_val_offset0_odd  <= 0;
		r_sub_val_offset0_even <= 0;
        r_sub_val_offset1_odd  <= 0;
		r_sub_val_offset1_even <= 0;
        r_sub_val_offset2_odd  <= 0;
		r_sub_val_offset2_even <= 0;
        r_sub_val_offset3_odd  <= 0;
		r_sub_val_offset3_even <= 0;
        r_sub_val_offset4_odd  <= 0;
		r_sub_val_offset4_even <= 0;
        r_sub_val_offset5_odd  <= 0;
		r_sub_val_offset5_even <= 0;
    end
    else begin
        r_sub_val_offset0_odd  <= {sub_val2B_o_offset2[0],sub_val2B_o_offset2[1],sub_val2B_o_offset2[2],sub_val2B_o_offset2[3]};
        r_sub_val_offset0_even <= {sub_val2B_o_offset1[0],sub_val2B_o_offset1[1],sub_val2B_o_offset1[2],sub_val2B_o_offset1[3]};
		r_sub_val_offset1_odd  <= {sub_val4B_o_offset2[0],sub_val4B_o_offset2[1],sub_val4B_o_offset2[2],sub_val4B_o_offset2[3]};
		r_sub_val_offset1_even <= {sub_val4B_o_offset1[0],sub_val4B_o_offset1[1],sub_val4B_o_offset1[2],sub_val4B_o_offset1[3]};
        // r_sub_val_offset2 <= {sub_val8B_o_offset[0],sub_val8B_o_offset[1],sub_val8B_o_offset[2],sub_val8B_o_offset[3]};
		r_sub_val_offset2_odd  <= {sub_val8B_o_offset2[0],sub_val8B_o_offset2[1],sub_val8B_o_offset2[2],sub_val8B_o_offset2[3]};
		r_sub_val_offset2_even <= {sub_val8B_o_offset1[0],sub_val8B_o_offset1[1],sub_val8B_o_offset1[2],sub_val8B_o_offset1[3]};
        r_sub_val_offset3_odd  <= {sub_val2B_o_offset2[4],sub_val2B_o_offset2[5],sub_val2B_o_offset2[6],sub_val2B_o_offset2[7]};
		r_sub_val_offset3_even <= {sub_val2B_o_offset1[4],sub_val2B_o_offset1[5],sub_val2B_o_offset1[6],sub_val2B_o_offset1[7]};
        r_sub_val_offset4_odd  <= {sub_val4B_o_offset2[4],sub_val4B_o_offset2[5],sub_val4B_o_offset2[6],sub_val4B_o_offset2[7]};
		r_sub_val_offset4_even <= {sub_val4B_o_offset1[4],sub_val4B_o_offset1[5],sub_val4B_o_offset1[6],sub_val4B_o_offset1[7]};
        // r_sub_val_offset5 <= {sub_val8B_o_offset[4],sub_val8B_o_offset[5],sub_val8B_o_offset[6],sub_val8B_o_offset[7]};
		r_sub_val_offset5_odd  <= {sub_val8B_o_offset2[4],sub_val8B_o_offset2[5],sub_val8B_o_offset2[6],sub_val8B_o_offset2[7]};
		r_sub_val_offset5_even <= {sub_val8B_o_offset1[4],sub_val8B_o_offset1[5],sub_val8B_o_offset1[6],sub_val8B_o_offset1[7]};
    end
end

always @(posedge clk)begin
    if(~aresetn) begin
        r_sub_val_out_valid0 <=0;
        r_sub_val_out_valid1 <=0;
        r_sub_val_out_valid2 <=0;
        r_sub_val_out_valid3 <=0;
        r_sub_val_out_valid4 <=0;
        r_sub_val_out_valid5 <=0;
    end
    else begin
        r_sub_val_out_valid0 <= {sub_val2B_o_valid[0],sub_val2B_o_valid[1],sub_val2B_o_valid[2],sub_val2B_o_valid[3]};
        r_sub_val_out_valid1 <= {sub_val4B_o_valid[0],sub_val4B_o_valid[1],sub_val4B_o_valid[2],sub_val4B_o_valid[3]};
        r_sub_val_out_valid2 <= {sub_val8B_o_valid[0],sub_val8B_o_valid[1],sub_val8B_o_valid[2],sub_val8B_o_valid[3]};
        r_sub_val_out_valid3 <= {sub_val2B_o_valid[4],sub_val2B_o_valid[5],sub_val2B_o_valid[6],sub_val2B_o_valid[7]};
        r_sub_val_out_valid4 <= {sub_val4B_o_valid[4],sub_val4B_o_valid[5],sub_val4B_o_valid[6],sub_val4B_o_valid[7]};
        r_sub_val_out_valid5 <= {sub_val8B_o_valid[4],sub_val8B_o_valid[5],sub_val8B_o_valid[6],sub_val8B_o_valid[7]};
    end
end

always @(posedge clk)begin
    if(~aresetn) begin
        r_sub_val_out_end0 <=0;
        r_sub_val_out_end1 <=0;
        r_sub_val_out_end2 <=0;
        r_sub_val_out_end3 <=0;
        r_sub_val_out_end4 <=0;
        r_sub_val_out_end5 <=0;
    end
    else begin
        r_sub_val_out_end0 <= {sub_val2B_o_end[0],sub_val2B_o_end[1],sub_val2B_o_end[2],sub_val2B_o_end[3]};
        r_sub_val_out_end1 <= {sub_val4B_o_end[0],sub_val4B_o_end[1],sub_val4B_o_end[2],sub_val4B_o_end[3]};      
        r_sub_val_out_end2 <= {sub_val8B_o_end[0],sub_val8B_o_end[1],sub_val8B_o_end[2],sub_val8B_o_end[3]};     
        r_sub_val_out_end3 <= {sub_val2B_o_end[4],sub_val2B_o_end[5],sub_val2B_o_end[6],sub_val2B_o_end[7]};        
        r_sub_val_out_end4 <= {sub_val4B_o_end[4],sub_val4B_o_end[5],sub_val4B_o_end[6],sub_val4B_o_end[7]};     
        r_sub_val_out_end5 <= {sub_val8B_o_end[4],sub_val8B_o_end[5],sub_val8B_o_end[6],sub_val8B_o_end[7]};     
    end
end


wire [C_AXIS_DATA_WIDTH-1:0] w_pkt_data0,w_pkt1_data0,w_pkt2_data0,w_pkt3_data0,w_pkt4_data0,w_pkt5_data0;
wire [C_AXIS_DATA_WIDTH-1:0] w_pkt_data1,w_pkt1_data1,w_pkt2_data1,w_pkt3_data1,w_pkt4_data1,w_pkt5_data1;
wire [C_AXIS_DATA_WIDTH-1:0] w_pkt_data2,w_pkt1_data2,w_pkt2_data2,w_pkt3_data2,w_pkt4_data2,w_pkt5_data2;
wire [C_AXIS_DATA_WIDTH-1:0] w_pkt_data3,w_pkt1_data3,w_pkt2_data3,w_pkt3_data3,w_pkt4_data3,w_pkt5_data3;
wire [C_AXIS_DATA_WIDTH-1:0] w_pkt_data4,w_pkt1_data4,w_pkt2_data4,w_pkt3_data4,w_pkt4_data4,w_pkt5_data4;
wire [C_AXIS_DATA_WIDTH-1:0] w_pkt_data5,w_pkt1_data5,w_pkt2_data5,w_pkt3_data5,w_pkt4_data5,w_pkt5_data5;
wire [C_AXIS_DATA_WIDTH-1:0] w_pkt_data6,w_pkt1_data6,w_pkt2_data6,w_pkt3_data6,w_pkt4_data6,w_pkt5_data6;
wire [C_AXIS_DATA_WIDTH-1:0] w_pkt_data7,w_pkt1_data7,w_pkt2_data7,w_pkt3_data7,w_pkt4_data7,w_pkt5_data7;

reg [C_AXIS_DATA_WIDTH-1:0] r_fst_half_fifo_tdata1,r_fst_half_fifo_tdata2,r_fst_half_fifo_tdata3,r_fst_half_fifo_tdata4;
reg [C_AXIS_DATA_WIDTH-1:0] r_snd_half_fifo_tdata1,r_snd_half_fifo_tdata2,r_snd_half_fifo_tdata3,r_snd_half_fifo_tdata4;

always @(posedge clk)begin
    if(~aresetn) begin
        r_fst_half_fifo_tdata1 <=0;
        r_fst_half_fifo_tdata2 <=0;
        r_fst_half_fifo_tdata3 <=0;
        r_fst_half_fifo_tdata4 <=0;
        r_snd_half_fifo_tdata1 <=0;
        r_snd_half_fifo_tdata2 <=0;
        r_snd_half_fifo_tdata3 <=0;
        r_snd_half_fifo_tdata4 <=0;
        r_fifo_data_valid      <=1'b0;
    end
    else begin 
		if(snd_half_fifo_rd_en) begin
        	r_fst_half_fifo_tdata1 <= fst_half_fifo_tdata1;
        	r_fst_half_fifo_tdata2 <= fst_half_fifo_tdata2;
        	r_fst_half_fifo_tdata3 <= fst_half_fifo_tdata3;
        	r_fst_half_fifo_tdata4 <= fst_half_fifo_tdata4;
        	r_snd_half_fifo_tdata1 <= snd_half_fifo_tdata1;
        	r_snd_half_fifo_tdata2 <= snd_half_fifo_tdata2;
        	r_snd_half_fifo_tdata3 <= snd_half_fifo_tdata3;
        	r_snd_half_fifo_tdata4 <= snd_half_fifo_tdata4; 
			r_fifo_data_valid      <= 1'b1;
		end
		else begin
			r_fst_half_fifo_tdata1 <= fst_half_fifo_tdata1;
        	r_fst_half_fifo_tdata2 <= fst_half_fifo_tdata2;
        	r_fst_half_fifo_tdata3 <= fst_half_fifo_tdata3;
        	r_fst_half_fifo_tdata4 <= fst_half_fifo_tdata4;
        	r_snd_half_fifo_tdata1 <= snd_half_fifo_tdata1;
        	r_snd_half_fifo_tdata2 <= snd_half_fifo_tdata2;
        	r_snd_half_fifo_tdata3 <= snd_half_fifo_tdata3;
        	r_snd_half_fifo_tdata4 <= snd_half_fifo_tdata4; 
			r_fifo_data_valid      <=1'b0;
    	end
	end
end

ram ram(
    .clk    (clk),
    .aresetn(aresetn),
    .i_ini_pkt_data0	(r_fst_half_fifo_tdata1),
    .i_ini_pkt_data1	(r_fst_half_fifo_tdata2),
    .i_ini_pkt_data2	(r_fst_half_fifo_tdata3),
    .i_ini_pkt_data3	(r_fst_half_fifo_tdata4),
    .i_ini_pkt_data4	(r_snd_half_fifo_tdata1),
    .i_ini_pkt_data5	(r_snd_half_fifo_tdata2),
    .i_ini_pkt_data6	(r_snd_half_fifo_tdata3),
    .i_ini_pkt_data7	(r_snd_half_fifo_tdata4), 
    .i_reg_ini_str  	(r_fifo_data_valid  ), //如果fifo非空，说明有有效数据可以写入

    .i_val_odd       	(r_sub_val0_odd),
	.i_val_even       	(r_sub_val0_even),
    .i_val_type  		(r_sub_val0_type),
    .i_val_offset_odd	(r_sub_val_offset0_odd),//0-255Byte偏移放回
	.i_val_offset_even	(r_sub_val_offset0_even),//0-255Byte偏移放回
	.i_val_end			(r_sub_val_out_end0),
	.i_val_valid  		(r_sub_val_out_valid0),//指令有效

    .o_pkt_data0  		(w_pkt_data0),
    .o_pkt_data1  		(w_pkt_data1),
    .o_pkt_data2  		(w_pkt_data2),
    .o_pkt_data3  		(w_pkt_data3),
    .o_pkt_data4  		(w_pkt_data4),
    .o_pkt_data5  		(w_pkt_data5),
    .o_pkt_data6  		(w_pkt_data6),
    .o_pkt_data7  		(w_pkt_data7),
	.o_pkt_data_valid   (w_pkt_data_valid)
);

ram1 ram1(
    .clk    (clk),
    .aresetn(aresetn),
    .i_ini_pkt_data0(w_pkt_data0),
    .i_ini_pkt_data1(w_pkt_data1),
    .i_ini_pkt_data2(w_pkt_data2),
    .i_ini_pkt_data3(w_pkt_data3),
    .i_ini_pkt_data4(w_pkt_data4),
    .i_ini_pkt_data5(w_pkt_data5),
    .i_ini_pkt_data6(w_pkt_data6),
    .i_ini_pkt_data7(w_pkt_data7), 
	.i_reg_ini_str  (w_pkt_data_valid), //容器输出完成，可以启动写回ram操作


    .i_val_odd       	(r_sub_val1_odd),
	.i_val_even       	(r_sub_val1_even),
    .i_val_type  		(r_sub_val1_type),
    .i_val_offset_odd	(r_sub_val_offset1_odd),//0-255Byte偏移放回
	.i_val_offset_even	(r_sub_val_offset1_even),//0-255Byte偏移放回
	.i_val_end			(r_sub_val_out_end1),
	.i_val_valid  		(r_sub_val_out_valid1),//指令有效
  
    .o_pkt_data0    (w_pkt1_data0),
    .o_pkt_data1    (w_pkt1_data1),
    .o_pkt_data2    (w_pkt1_data2),
    .o_pkt_data3    (w_pkt1_data3),
    .o_pkt_data4    (w_pkt1_data4),
    .o_pkt_data5    (w_pkt1_data5),
    .o_pkt_data6    (w_pkt1_data6),
    .o_pkt_data7    (w_pkt1_data7),
	.o_pkt_data_valid (w_pkt_data_valid1)

    );
    
ram2 ram2(
 	.clk    			(clk),
 	.aresetn			(aresetn),
 	.i_ini_pkt_data0	(w_pkt1_data0),
 	.i_ini_pkt_data1	(w_pkt1_data1),
 	.i_ini_pkt_data2	(w_pkt1_data2),
 	.i_ini_pkt_data3	(w_pkt1_data3),
 	.i_ini_pkt_data4	(w_pkt1_data4),
 	.i_ini_pkt_data5	(w_pkt1_data5),
 	.i_ini_pkt_data6	(w_pkt1_data6),
 	.i_ini_pkt_data7	(w_pkt1_data7), 
 	.i_reg_ini_str  	(w_pkt_data_valid1   ), //容器输出完成，可以启动写回ram操作

 	
	// .i_val       		(r_sub_val2       ),
	// .i_val_type  		(r_sub_val2_type  ),
	// .i_val_offset		(r_sub_val_offset2),
	// .i_val_end   		(r_sub_val_out_end2  ),
	// .i_val_valid  		(r_sub_val_out_valid2),

	.i_val_odd       	(r_sub_val2_odd        ),
	.i_val_even       	(r_sub_val2_even       ),
	.i_val_type  		(r_sub_val2_type       ),
	.i_val_offset_odd	(r_sub_val_offset2_odd ),//0-255Byte偏移放回
	.i_val_offset_even	(r_sub_val_offset2_even),//0-255Byte偏移放回
	.i_val_end			(r_sub_val_out_end2    ),
	.i_val_valid  		(r_sub_val_out_valid2  ),//指令有效
	
	.o_pkt_data0  		(w_pkt2_data0),
	.o_pkt_data1  		(w_pkt2_data1),
	.o_pkt_data2  		(w_pkt2_data2),
	.o_pkt_data3  		(w_pkt2_data3),
	.o_pkt_data4  		(w_pkt2_data4),
	.o_pkt_data5  		(w_pkt2_data5),
	.o_pkt_data6  		(w_pkt2_data6),
	.o_pkt_data7  		(w_pkt2_data7),
	.o_pkt_data_valid   (w_pkt_data_valid2)

);


ram3 ram3(
    .clk    (clk),
    .aresetn(aresetn),
    .i_ini_pkt_data0(w_pkt2_data0),
    .i_ini_pkt_data1(w_pkt2_data1),
    .i_ini_pkt_data2(w_pkt2_data2),
    .i_ini_pkt_data3(w_pkt2_data3),
    .i_ini_pkt_data4(w_pkt2_data4),
    .i_ini_pkt_data5(w_pkt2_data5),
    .i_ini_pkt_data6(w_pkt2_data6),
    .i_ini_pkt_data7(w_pkt2_data7), 
    .i_reg_ini_str  (w_pkt_data_valid2  ), //如果fifo非空，说明有有效数据可以写入

    .i_val_odd       	(r_sub_val3_odd),
	.i_val_even       	(r_sub_val3_even),
    .i_val_type  		(r_sub_val3_type),
    .i_val_offset_odd	(r_sub_val_offset3_odd),//0-255Byte偏移放回
	.i_val_offset_even	(r_sub_val_offset3_even),//0-255Byte偏移放回
	.i_val_end			(r_sub_val_out_end3),
	.i_val_valid  		(r_sub_val_out_valid3),//指令有效

    .o_pkt_data0  	(w_pkt3_data0),
    .o_pkt_data1  	(w_pkt3_data1),
    .o_pkt_data2  	(w_pkt3_data2),
    .o_pkt_data3  	(w_pkt3_data3),
    .o_pkt_data4  	(w_pkt3_data4),
    .o_pkt_data5  	(w_pkt3_data5),
    .o_pkt_data6  	(w_pkt3_data6),
    .o_pkt_data7  	(w_pkt3_data7),
	.o_pkt_data_valid    (w_pkt_data_valid3)

);

ram4 ram4(
    .clk    (clk),
    .aresetn(aresetn),
    .i_ini_pkt_data0(w_pkt3_data0),
    .i_ini_pkt_data1(w_pkt3_data1),
    .i_ini_pkt_data2(w_pkt3_data2),
    .i_ini_pkt_data3(w_pkt3_data3),
    .i_ini_pkt_data4(w_pkt3_data4),
    .i_ini_pkt_data5(w_pkt3_data5),
    .i_ini_pkt_data6(w_pkt3_data6),
    .i_ini_pkt_data7(w_pkt3_data7), 
	.i_reg_ini_str  (w_pkt_data_valid3), //容器输出完成，可以启动写回ram操作


    .i_val_odd       	(r_sub_val4_odd),
	.i_val_even       	(r_sub_val4_even),
    .i_val_type  		(r_sub_val4_type),
    .i_val_offset_odd	(r_sub_val_offset4_odd),//0-255Byte偏移放回
	.i_val_offset_even	(r_sub_val_offset4_even),//0-255Byte偏移放回
	.i_val_end			(r_sub_val_out_end4),
	.i_val_valid  		(r_sub_val_out_valid4),//指令有效
  
    .o_pkt_data0    (w_pkt4_data0),
    .o_pkt_data1    (w_pkt4_data1),
    .o_pkt_data2    (w_pkt4_data2),
    .o_pkt_data3    (w_pkt4_data3),
    .o_pkt_data4    (w_pkt4_data4),
    .o_pkt_data5    (w_pkt4_data5),
    .o_pkt_data6    (w_pkt4_data6),
    .o_pkt_data7    (w_pkt4_data7),
	.o_pkt_data_valid (w_pkt_data_valid4)

    );


ram5 ram5(
 	.clk    			(clk),
 	.aresetn			(aresetn),
 	.i_ini_pkt_data0	(w_pkt4_data0),
 	.i_ini_pkt_data1	(w_pkt4_data1),
 	.i_ini_pkt_data2	(w_pkt4_data2),
 	.i_ini_pkt_data3	(w_pkt4_data3),
 	.i_ini_pkt_data4	(w_pkt4_data4),
 	.i_ini_pkt_data5	(w_pkt4_data5),
 	.i_ini_pkt_data6	(w_pkt4_data6),
 	.i_ini_pkt_data7	(w_pkt4_data7), 
 	.i_reg_ini_str  	(w_pkt_data_valid4   ), //容器输出完成，可以启动写回ram操作


	// .i_val       		(r_sub_val5       ),
	// .i_val_type  		(r_sub_val5_type  ),
	// .i_val_offset		(r_sub_val_offset5),
	// .i_val_end   		(r_sub_val_out_end5  ),
	// .i_val_valid  		(r_sub_val_out_valid5),

	.i_val_odd       	(r_sub_val5_odd        ),
	.i_val_even       	(r_sub_val5_even       ),
	.i_val_type  		(r_sub_val5_type       ),
	.i_val_offset_odd	(r_sub_val_offset5_odd ),//0-255Byte偏移放回
	.i_val_offset_even	(r_sub_val_offset5_even),//0-255Byte偏移放回
	.i_val_end			(r_sub_val_out_end5    ),
	.i_val_valid  		(r_sub_val_out_valid5  ),//指令有效

	.o_pkt_data0  		(w_pkt5_data0),
	.o_pkt_data1  		(w_pkt5_data1),
	.o_pkt_data2  		(w_pkt5_data2),
	.o_pkt_data3  		(w_pkt5_data3),
	.o_pkt_data4  		(w_pkt5_data4),
	.o_pkt_data5  		(w_pkt5_data5),
	.o_pkt_data6  		(w_pkt5_data6),
	.o_pkt_data7  		(w_pkt5_data7),
	.o_pkt_data_valid   (w_pkt_data_valid5),
	.o_reg_end          (w_reg_end)    

);
    
wire discard_signal;
assign discard_signal = phv_fifo_out[128];

//-------------------------------FLUSH_DATA_OUT-----------------------------------------//
localparam		IDLE              = 0 ,
         		FLUSH_PKT_0       = 1 ,
				FLUSH_PKT_1       = 2 ,
				FLUSH_PKT_2       = 3 ,
				FLUSH_PKT_3       = 4 ,
				FLUSH_PKT_4       = 5 ,
				FLUSH_PKT_5       = 6 ,
				FLUSH_PKT_6       = 7 ,
				FLUSH_PKT_7       = 8 ,
				FLUSH_PKT         = 9 ,
				DROP_PKT          = 10,
				DROP_PKT_REMAINING= 11;
				
reg [4*C_AXIS_TUSER_WIDTH-1:0]		pkts_tuser_stored_1p     , pkts_tuser_stored_2p     ;
reg [4*(C_AXIS_DATA_WIDTH/8)-1:0]	pkts_tkeep_stored_1p     , pkts_tkeep_stored_2p     ;
reg [3:0]							pkts_tlast_stored_1p     , pkts_tlast_stored_2p     ;
// reg [4*C_AXIS_DATA_WIDTH-1:0]		pkts_tdata_stored_1p_next, pkts_tdata_stored_2p_next;
reg [4*C_AXIS_TUSER_WIDTH-1:0]		pkts_tuser_stored_1p_next, pkts_tuser_stored_2p_next;
reg [4*(C_AXIS_DATA_WIDTH/8)-1:0]	pkts_tkeep_stored_1p_next, pkts_tkeep_stored_2p_next;
reg [3:0]							pkts_tlast_stored_1p_next, pkts_tlast_stored_2p_next;

reg [4:0] depar_flush_state;
wire [7:0] dst_addr;
wire [7:0] src_addr;
assign dst_addr = (src_addr== 8'h40)?8'h01:(src_addr == 8'h01)?8'h40:8'h04; //从cpu到nf0输出，nf0出之后从nf3  dst 00000000  src 00000000
assign src_addr = fst_half_fifo_tuser[23:16];

always @(posedge clk) begin
	// pkts_tdata_stored_1p_next = fst_half_fifo_tdata;
	if(!aresetn)begin
		depar_flush_state <= 5'd0;
		depar_out_tdata <= 0;
		depar_out_tkeep <= 0;
		depar_out_tuser <= 0;
		depar_out_tlast <= 0;
		depar_out_tvalid <= 0;
		o_tuser_fifo_rd_en <= 0;
		pkt_fifo_rd_en <= 1'b0;
	end
	else begin
	case (depar_flush_state) 
		IDLE: begin
			depar_flush_state <= 5'd0;
			depar_out_tdata <= 0;
			depar_out_tkeep <= 0;
			depar_out_tuser <= 0;
			depar_out_tlast <= 0;
			depar_out_tvalid <= 0;
			o_tuser_fifo_rd_en <= 0;
			pkt_fifo_rd_en <= 1'b0;
			if(w_reg_end) begin//在该信号的下一拍，reg数据输出
				depar_flush_state <= FLUSH_PKT_0;
			end
			else begin
				depar_flush_state <= IDLE;
			end
		end

		FLUSH_PKT_0: begin //
			// depar_out_tdata_next = pkts_tdata_stored_1p[(C_AXIS_DATA_WIDTH*0)+:C_AXIS_DATA_WIDTH];
			depar_out_tdata <= w_pkt5_data0;
//			depar_out_tuser <= fst_half_fifo_tuser[(C_AXIS_TUSER_WIDTH*0)+:C_AXIS_TUSER_WIDTH];
            depar_out_tuser <= {fst_half_fifo_tuser[127:32],dst_addr,fst_half_fifo_tuser[23:0]};
//            depar_out_tuser_next = 128'h00000000000000000000000040800100;
			depar_out_tkeep <= fst_half_fifo_tkeep[(C_AXIS_DATA_WIDTH/8*0)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast <= fst_half_fifo_tlast[0];
			
			if (depar_out_tready) begin
				depar_out_tvalid <= 1;
				if (fst_half_fifo_tlast[0]) begin
					depar_flush_state <= IDLE;
				end
				else begin
					depar_flush_state = FLUSH_PKT_1;
				end
			end
		end
		FLUSH_PKT_1: begin
			// depar_out_tdata_next = pkts_tdata_stored_1p[(C_AXIS_DATA_WIDTH*1)+:C_AXIS_DATA_WIDTH];
			depar_out_tdata <= w_pkt5_data1;
			depar_out_tuser <= fst_half_fifo_tuser[(C_AXIS_TUSER_WIDTH*1)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep <= fst_half_fifo_tkeep[(C_AXIS_DATA_WIDTH/8*1)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast <= fst_half_fifo_tlast[1];
			
			if (depar_out_tready) begin
				depar_out_tvalid <= 1;
				if (fst_half_fifo_tlast[1]) begin
					depar_flush_state <= IDLE;
				end
				else begin
					depar_flush_state <= FLUSH_PKT_2;
				end
			end
		end
		FLUSH_PKT_2: begin
			// depar_out_tdata_next = pkts_tdata_stored_1p[(C_AXIS_DATA_WIDTH*2)+:C_AXIS_DATA_WIDTH];
			depar_out_tdata <= w_pkt5_data2;
			depar_out_tuser <= fst_half_fifo_tuser[(C_AXIS_TUSER_WIDTH*2)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep <= fst_half_fifo_tkeep[(C_AXIS_DATA_WIDTH/8*2)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast <= fst_half_fifo_tlast[2];

			if (depar_out_tready) begin
				depar_out_tvalid <= 1;
				if (fst_half_fifo_tlast[2]) begin
					depar_flush_state <= IDLE;
				end
				else begin
					depar_flush_state <= FLUSH_PKT_3;
				end
			end
		end
		FLUSH_PKT_3: begin
			// depar_out_tdata_next = pkts_tdata_stored_1p[(C_AXIS_DATA_WIDTH*3)+:C_AXIS_DATA_WIDTH];
			depar_out_tdata <= w_pkt5_data3;
			depar_out_tuser <= fst_half_fifo_tuser[(C_AXIS_TUSER_WIDTH*3)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep <= fst_half_fifo_tkeep[(C_AXIS_DATA_WIDTH/8*3)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast <= fst_half_fifo_tlast[3];

			if (depar_out_tready) begin
				depar_out_tvalid <= 1;
				if (fst_half_fifo_tlast[3]) begin
					depar_flush_state <= IDLE;
				end
				else begin
					depar_flush_state <= FLUSH_PKT_4;
				end
			end
		end
		FLUSH_PKT_4: begin
			// depar_out_tdata_next = pkts_tdata_stored_2p[(C_AXIS_DATA_WIDTH*0)+:C_AXIS_DATA_WIDTH];
			depar_out_tdata <= w_pkt5_data4;
			depar_out_tuser <= snd_half_fifo_tuser[(C_AXIS_TUSER_WIDTH*0)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep <= snd_half_fifo_tkeep[(C_AXIS_DATA_WIDTH/8*0)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast <= snd_half_fifo_tlast[0];

			if (depar_out_tready) begin
				depar_out_tvalid <= 1;
				if (snd_half_fifo_tlast[0]) begin
					depar_flush_state <= IDLE;
				end
				else begin
					depar_flush_state <= FLUSH_PKT_5;
				end
			end
		end
		FLUSH_PKT_5: begin
			// depar_out_tdata_next = pkts_tdata_stored_2p[(C_AXIS_DATA_WIDTH*1)+:C_AXIS_DATA_WIDTH];
			depar_out_tdata <= w_pkt5_data5;
			depar_out_tuser <= snd_half_fifo_tuser[(C_AXIS_TUSER_WIDTH*1)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep <= snd_half_fifo_tkeep[(C_AXIS_DATA_WIDTH/8*1)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast <= snd_half_fifo_tlast[1];

			if (depar_out_tready) begin
				depar_out_tvalid <= 1;
				if (snd_half_fifo_tlast[1]) begin
					depar_flush_state <= IDLE;
				end
				else begin
					depar_flush_state <= FLUSH_PKT_6;
				end
			end
		end
		FLUSH_PKT_6: begin
			// depar_out_tdata_next = pkts_tdata_stored_2p[(C_AXIS_DATA_WIDTH*2)+:C_AXIS_DATA_WIDTH];
			depar_out_tdata <= w_pkt5_data6;
			depar_out_tuser <= snd_half_fifo_tuser[(C_AXIS_TUSER_WIDTH*2)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep <= snd_half_fifo_tkeep[(C_AXIS_DATA_WIDTH/8*2)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast <= snd_half_fifo_tlast[2];

			if (depar_out_tready) begin
				depar_out_tvalid <= 1;
				if (snd_half_fifo_tlast[2]) begin
					depar_flush_state <= IDLE;
				end
				else begin
					depar_flush_state <= FLUSH_PKT_7;
				end
			end
		end
		FLUSH_PKT_7: begin
			// depar_out_tdata_next = pkts_tdata_stored_2p[(C_AXIS_DATA_WIDTH*3)+:C_AXIS_DATA_WIDTH];

			depar_out_tdata <= w_pkt5_data7;
			depar_out_tuser <= snd_half_fifo_tuser[(C_AXIS_TUSER_WIDTH*3)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep <= snd_half_fifo_tkeep[(C_AXIS_DATA_WIDTH/8*3)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast <= snd_half_fifo_tlast[3];

			if (depar_out_tready) begin
				depar_out_tvalid<= 1;
				o_tuser_fifo_rd_en <= 1'b1; //有效报文出去了，可以取下一包的tuser数据
				if (snd_half_fifo_tlast[3] ) begin //正好连续2048b的数据报文
					if(w_reg_end)
						depar_flush_state <= FLUSH_PKT_0;
					else 
						depar_flush_state <= IDLE;//这包数据完成，但是还没有出第二包数据
				end
				else begin
					depar_flush_state <= FLUSH_PKT;
					pkt_fifo_rd_en <= 1'b1; //在这里就要开始取数据
				end
			end
		end
		FLUSH_PKT: begin //出超过2048b部分的数据
			o_tuser_fifo_rd_en <=1'b0;
			if (!pkt_fifo_empty) begin
				depar_out_tdata <=  pkt_fifo_tdata;
				depar_out_tuser <=  pkt_fifo_tuser;
				depar_out_tkeep <=  pkt_fifo_tkeep;
				depar_out_tlast <=  pkt_fifo_tlast;
				if (depar_out_tready) begin
					pkt_fifo_rd_en <= 1'b1;//如果上一拍数据可以出，那么就读下一拍数据
					depar_out_tvalid <= 1;
					if (pkt_fifo_tlast) begin
						if(w_reg_end)
							depar_flush_state <= FLUSH_PKT_0;
						else
							depar_flush_state <= IDLE;
					end
					else begin
						depar_flush_state <= FLUSH_PKT;
					end
				end
				else begin
					depar_flush_state <= FLUSH_PKT;
					depar_out_tvalid <= 1'b0;
					pkt_fifo_rd_en <= 0;
				end
			end
			else begin
				depar_out_tvalid <= 1'b0;
				depar_flush_state <= FLUSH_PKT;
				pkt_fifo_rd_en <= 0;
			end
		end
		DROP_PKT: begin //在报文指示为丢弃指令时，丢弃报文
			if (fst_half_fifo_tlast[0]==1 
				|| fst_half_fifo_tlast[1]==1
				|| fst_half_fifo_tlast[2]==1
				|| fst_half_fifo_tlast[3]==1
				|| snd_half_fifo_tlast[0]==1
				|| snd_half_fifo_tlast[1]==1
				|| snd_half_fifo_tlast[2]==1
				|| snd_half_fifo_tlast[3]==1) begin
				depar_flush_state <= IDLE;
			end
			else begin
				depar_flush_state <= DROP_PKT_REMAINING;
			end
		end
		DROP_PKT_REMAINING: begin
			pkt_fifo_rd_en <= 1;
			if (pkt_fifo_tlast) begin
				depar_flush_state <= IDLE;
			end
		end
	endcase
	end
end
ila_5 ila_deparsering (
	.clk   (clk                    ), // input wire clk

	.probe0(depar_flush_state      ),// input wire [4:0]  probe0  
	.probe1(depar_out_tdata        ),
	.probe2(depar_out_tkeep        ),
	.probe3(depar_out_tuser        ),
	.probe4(depar_out_tlast        ),
	.probe5(depar_out_tvalid       ),
	.probe6(bram_out               ),
	.probe7(bram_out_valid         )

);
endmodule

